from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


RESULTS_DIR = Path("results")
LATEX_DIR = Path("latex")
CASES = [
    "C101-25",
    "C102-25",
    "C103-25",
    "r101-25",
    "r102-25",
    "r103-25",
    "rc101-25",
    "rc102-25",
    "rc103-25",
]
DISPLAY_GROUPS = [
    ("C101--C103", ["C101-25", "C102-25", "C103-25"]),
    ("R101--R103", ["r101-25", "r102-25", "r103-25"]),
    ("RC101--RC103", ["rc101-25", "rc102-25", "rc103-25"]),
]


def latest(pattern: str) -> Path:
    files = sorted(
        [
            p
            for p in RESULTS_DIR.glob(pattern)
            if not p.stem.endswith("_summary")
            and not p.stem.endswith("_wide")
            and not p.stem.endswith("_report")
        ],
        key=lambda p: p.stat().st_mtime,
    )
    if not files:
        raise FileNotFoundError(f"No files match {pattern}")
    return files[-1]


def pct_improve(baseline: float, candidate: float) -> float:
    return (baseline - candidate) / baseline * 100.0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", default="extended_quick")
    args = parser.parse_args()
    tag = args.mode.replace("extended_", "").replace("-", "_")

    strategy_path = latest("priority_strategy_extended_quick_*.csv")

    strategies = pd.read_csv(strategy_path)
    strategies = strategies[strategies["caseName"].isin(CASES)].copy()
    algorithm_wide_path = RESULTS_DIR / f"extended_algorithm_{tag}_wide.csv"
    if algorithm_wide_path.exists():
        ihga_summary = pd.read_csv(algorithm_wide_path)[["caseName", "IHGA_avg"]].rename(
            columns={"IHGA_avg": "DDVRP_IHGA"}
        )
    else:
        ihga_path = latest("extended_ihga_quick_*.csv")
        ihga = pd.read_csv(ihga_path)
        ihga = ihga[ihga["caseName"].isin(CASES)].copy()
        ihga_summary = (
            ihga.groupby("caseName", as_index=False)
            .agg(DDVRP_IHGA=("bestFitness", "mean"))
        )
    strategy_wide = strategies.pivot_table(
        index="caseName",
        columns="strategyName",
        values="dynamicDamageObjective",
        aggfunc="mean",
    ).reset_index()
    wide = ihga_summary.merge(strategy_wide, on="caseName", how="inner")
    wide = wide.rename(
        columns={
            "PRIORITY-INITIAL": "PriorityInitial",
            "PRIORITY-DETERIORATION": "PriorityDeterioration",
        }
    )
    wide["improve_vs_initial_pct"] = wide.apply(
        lambda row: pct_improve(row["PriorityInitial"], row["DDVRP_IHGA"]), axis=1
    )
    wide["improve_vs_deterioration_pct"] = wide.apply(
        lambda row: pct_improve(row["PriorityDeterioration"], row["DDVRP_IHGA"]), axis=1
    )
    wide["case_order"] = wide["caseName"].map({case: i for i, case in enumerate(CASES)})
    wide = wide.sort_values("case_order").drop(columns="case_order")

    out_csv = RESULTS_DIR / f"priority_strategy_{tag}_wide.csv"
    wide.to_csv(out_csv, index=False, encoding="utf-8-sig")

    rows = []
    for label, cases in DISPLAY_GROUPS:
        part = wide[wide["caseName"].isin(cases)]
        if part.empty:
            continue
        row = part[
            [
                "DDVRP_IHGA",
                "PriorityInitial",
                "PriorityDeterioration",
                "improve_vs_initial_pct",
                "improve_vs_deterioration_pct",
            ]
        ].mean(numeric_only=True)
        rows.append(
            f"{label} & {row['DDVRP_IHGA']:.3f} & {row['PriorityInitial']:.3f} & "
            f"{row['PriorityDeterioration']:.3f} & {row['improve_vs_initial_pct']:.2f}\\% & "
            f"{row['improve_vs_deterioration_pct']:.2f}\\% \\\\"
        )
    out_tex = LATEX_DIR / "generated_priority_strategy_rows.tex"
    out_tex.write_text("\n".join(rows) + "\n", encoding="utf-8")

    report = RESULTS_DIR / f"priority_strategy_{tag}_report.md"
    report.write_text(
        "\n".join(
            [
                "# Priority Strategy Extended Quick",
                "",
                f"- Cases: {len(wide)}",
                f"- DDVRP-IHGA beats initial-damage priority on {(wide['improve_vs_initial_pct'] > 0).sum()}/{len(wide)} cases; average improvement {wide['improve_vs_initial_pct'].mean():.2f}%.",
                f"- DDVRP-IHGA beats deterioration-rate priority on {(wide['improve_vs_deterioration_pct'] > 0).sum()}/{len(wide)} cases; average improvement {wide['improve_vs_deterioration_pct'].mean():.2f}%.",
                "",
                wide.to_string(index=False),
                "",
            ]
        ),
        encoding="utf-8",
    )

    print(f"csv={out_csv}")
    print(f"tex={out_tex}")
    print(f"report={report}")


if __name__ == "__main__":
    main()
