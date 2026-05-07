from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


RESULTS_DIR = Path("results")
LATEX_DIR = Path("latex")
REPRESENTATIVE_CASES = [
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
ALGORITHM_ORDER = ["VNS", "IMA", "IHGA"]
MODEL_ORDER = ["DDVRP-IHGA", "CCVRP", "CVRP"]


def files_for(pattern: str) -> list[Path]:
    files = sorted(
        [p for p in RESULTS_DIR.glob(pattern) if not p.stem.endswith("_summary")],
        key=lambda p: p.stat().st_mtime,
    )
    return files


def latest(pattern: str) -> Path:
    files = files_for(pattern)
    if not files:
        raise FileNotFoundError(f"No files match {pattern}")
    return files[-1]


def pct_improve(baseline: float, candidate: float) -> float:
    return (baseline - candidate) / baseline * 100.0


def summarize_algorithm(mode: str, tag: str) -> tuple[pd.DataFrame, pd.DataFrame, Path]:
    algorithm_files = files_for(f"algorithm_comparison_{mode}_*.csv")
    frames = []
    for path in algorithm_files:
        frame = pd.read_csv(path)
        frame = frame[frame["caseName"].isin(REPRESENTATIVE_CASES)].copy()
        frame = frame[frame["algorithm"].isin(ALGORITHM_ORDER)]
        if not frame.empty:
            frames.append(frame[["caseName", "algorithm", "seed", "bestFitness"]])

    # Older quick runs stored IHGA-only output separately.
    if mode == "extended_quick":
        ihga_files = files_for("extended_ihga_quick_*.csv")
        if ihga_files:
            ihga = pd.read_csv(ihga_files[-1])
            ihga = ihga[ihga["caseName"].isin(REPRESENTATIVE_CASES)].copy()
            ihga_raw = ihga[["caseName", "seed", "bestFitness"]].copy()
            ihga_raw["algorithm"] = "IHGA"
            frames.append(ihga_raw[["caseName", "algorithm", "seed", "bestFitness"]])

    if not frames:
        raise FileNotFoundError(f"No algorithm files found for mode={mode}")

    raw = pd.concat(frames, ignore_index=True)
    raw = raw.drop_duplicates(subset=["caseName", "algorithm", "seed"], keep="last")

    summary = (
        raw.groupby(["caseName", "algorithm"], as_index=False)
        .agg(
            avgDamage=("bestFitness", "mean"),
            bestDamage=("bestFitness", "min"),
            stdDamage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
        )
        .sort_values(["caseName", "algorithm"])
    )
    summary["stdDamage"] = summary["stdDamage"].fillna(0.0)

    rows = []
    for case in REPRESENTATIVE_CASES:
        vals = summary[summary["caseName"] == case].set_index("algorithm")
        if not set(ALGORITHM_ORDER).issubset(vals.index):
            continue
        ihga_avg = float(vals.loc["IHGA", "avgDamage"])
        ima_avg = float(vals.loc["IMA", "avgDamage"])
        vns_avg = float(vals.loc["VNS", "avgDamage"])
        rows.append(
            {
                "caseName": case,
                "IHGA_avg": ihga_avg,
                "IMA_avg": ima_avg,
                "VNS_avg": vns_avg,
                "IHGA_best": float(vals.loc["IHGA", "bestDamage"]),
                "IMA_best": float(vals.loc["IMA", "bestDamage"]),
                "VNS_best": float(vals.loc["VNS", "bestDamage"]),
                "IHGA_std": float(vals.loc["IHGA", "stdDamage"]),
                "IMA_std": float(vals.loc["IMA", "stdDamage"]),
                "VNS_std": float(vals.loc["VNS", "stdDamage"]),
                "improve_vs_IMA_pct": pct_improve(ima_avg, ihga_avg),
                "improve_vs_VNS_pct": pct_improve(vns_avg, ihga_avg),
            }
        )
    wide = pd.DataFrame(rows)

    summary_path = RESULTS_DIR / f"extended_algorithm_{tag}_summary.csv"
    wide_path = RESULTS_DIR / f"extended_algorithm_{tag}_wide.csv"
    summary.to_csv(summary_path, index=False, encoding="utf-8-sig")
    wide.to_csv(wide_path, index=False, encoding="utf-8-sig")
    return summary, wide, wide_path


def summarize_model(mode: str, tag: str) -> tuple[pd.DataFrame, pd.DataFrame, Path]:
    model_files = files_for(f"model_comparison_{mode}_*.csv")
    frames = []
    for path in model_files:
        frame = pd.read_csv(path)
        frame = frame[frame["caseName"].isin(REPRESENTATIVE_CASES)].copy()
        frame = frame[frame["modelName"].isin(MODEL_ORDER)]
        if not frame.empty:
            frames.append(frame[["caseName", "modelName", "seed", "dynamicDamageObjective"]])

    # Older quick runs stored DDVRP-IHGA through the IHGA-only benchmark.
    if mode == "extended_quick":
        ihga_files = files_for("extended_ihga_quick_*.csv")
        if ihga_files:
            ihga = pd.read_csv(ihga_files[-1])
            ihga = ihga[ihga["caseName"].isin(REPRESENTATIVE_CASES)].copy()
            ihga_raw = ihga[["caseName", "seed", "bestFitness"]].copy()
            ihga_raw["modelName"] = "DDVRP-IHGA"
            ihga_raw = ihga_raw.rename(columns={"bestFitness": "dynamicDamageObjective"})
            frames.append(ihga_raw[["caseName", "modelName", "seed", "dynamicDamageObjective"]])

    if not frames:
        raise FileNotFoundError(f"No model files found for mode={mode}")

    raw = pd.concat(frames, ignore_index=True)
    raw = raw.drop_duplicates(subset=["caseName", "modelName", "seed"], keep="last")
    summary = (
        raw.groupby(["caseName", "modelName"], as_index=False)
        .agg(
            avgDynamicDamage=("dynamicDamageObjective", "mean"),
            bestDynamicDamage=("dynamicDamageObjective", "min"),
            stdDynamicDamage=("dynamicDamageObjective", "std"),
            runs=("dynamicDamageObjective", "count"),
        )
        .sort_values(["caseName", "modelName"])
    )
    summary["stdDynamicDamage"] = summary["stdDynamicDamage"].fillna(0.0)

    rows = []
    for case in REPRESENTATIVE_CASES:
        vals = summary[summary["caseName"] == case].set_index("modelName")
        if not set(MODEL_ORDER).issubset(vals.index):
            continue
        dd = float(vals.loc["DDVRP-IHGA", "avgDynamicDamage"])
        ccv = float(vals.loc["CCVRP", "avgDynamicDamage"])
        cvrp = float(vals.loc["CVRP", "avgDynamicDamage"])
        rows.append(
            {
                "caseName": case,
                "DDVRP-IHGA": dd,
                "CCVRP": ccv,
                "CVRP": cvrp,
                "improve_vs_CCVRP_pct": pct_improve(ccv, dd),
                "improve_vs_CVRP_pct": pct_improve(cvrp, dd),
            }
        )
    wide = pd.DataFrame(rows)

    summary_path = RESULTS_DIR / f"extended_model_{tag}_summary.csv"
    wide_path = RESULTS_DIR / f"extended_model_{tag}_wide.csv"
    summary.to_csv(summary_path, index=False, encoding="utf-8-sig")
    wide.to_csv(wide_path, index=False, encoding="utf-8-sig")
    return summary, wide, wide_path


def write_algorithm_tex(summary: pd.DataFrame) -> Path:
    out = LATEX_DIR / "generated_extended_algorithm_rows.tex"
    lines: list[str] = []
    written = 0
    for label, cases in DISPLAY_GROUPS:
        available = [case for case in cases if case in set(summary["caseName"])]
        if not available:
            continue
        case = available[0]
        part = summary[summary["caseName"] == case].set_index("algorithm")
        if not set(ALGORITHM_ORDER).issubset(part.index):
            continue
        if written > 0:
            lines.append(r"\midrule")
        for alg in ALGORITHM_ORDER:
            row = part.loc[alg]
            lines.append(
                f"{label} & {alg} & {float(row['avgDamage']):.3f} & "
                f"{float(row['bestDamage']):.3f} & {float(row['stdDamage']):.3f} \\\\"
            )
        written += 1
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def write_model_tex(wide: pd.DataFrame) -> Path:
    out = LATEX_DIR / "generated_extended_model_rows.tex"
    lines = []
    for label, cases in DISPLAY_GROUPS:
        part = wide[wide["caseName"].isin(cases)]
        if part.empty:
            continue
        row = part.iloc[0]
        lines.append(
            f"{label} & {row['DDVRP-IHGA']:.3f} & {row['CCVRP']:.3f} & "
            f"{row['CVRP']:.3f} & {row['improve_vs_CCVRP_pct']:.2f}\\% & "
            f"{row['improve_vs_CVRP_pct']:.2f}\\% \\\\"
        )
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def write_report(algorithm_wide: pd.DataFrame, model_wide: pd.DataFrame, tag: str) -> Path:
    out = RESULTS_DIR / f"extended_benchmark_{tag}_report.md"
    alg_cases = len(algorithm_wide)
    model_cases = len(model_wide)
    alg_win_ima = int((algorithm_wide["improve_vs_IMA_pct"] > 0).sum())
    alg_win_vns = int((algorithm_wide["improve_vs_VNS_pct"] > 0).sum())
    avg_ima = algorithm_wide["improve_vs_IMA_pct"].mean()
    avg_vns = algorithm_wide["improve_vs_VNS_pct"].mean()
    model_win_cc = int((model_wide["improve_vs_CCVRP_pct"] > 0).sum())
    model_win_cv = int((model_wide["improve_vs_CVRP_pct"] > 0).sum())
    avg_cc = model_wide["improve_vs_CCVRP_pct"].mean()
    avg_cv = model_wide["improve_vs_CVRP_pct"].mean()

    lines = [
        f"# Extended Benchmark ({tag})",
        "",
        "- Display tables collapse byte-identical input labels into grouped rows.",
        f"- Algorithm cases: {alg_cases}",
        f"- IHGA beats IMA on {alg_win_ima}/{alg_cases} cases; average improvement {avg_ima:.2f}%.",
        f"- IHGA beats VNS on {alg_win_vns}/{alg_cases} cases; average improvement {avg_vns:.2f}%.",
        f"- Model cases: {model_cases}",
        f"- DDVRP-IHGA beats CCVRP on {model_win_cc}/{model_cases} cases; average improvement {avg_cc:.2f}%.",
        f"- DDVRP-IHGA beats CVRP on {model_win_cv}/{model_cases} cases; average improvement {avg_cv:.2f}%.",
        "",
        "## Algorithm Wide Table",
        algorithm_wide.to_string(index=False),
        "",
        "## Model Wide Table",
        model_wide.to_string(index=False),
        "",
    ]
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", default="extended_quick")
    args = parser.parse_args()
    tag = args.mode.replace("extended_", "").replace("-", "_")

    algorithm_summary, algorithm_wide, algorithm_path = summarize_algorithm(args.mode, tag)
    model_summary, model_wide, model_path = summarize_model(args.mode, tag)
    alg_tex = write_algorithm_tex(algorithm_summary)
    model_tex = write_model_tex(model_wide)
    report = write_report(algorithm_wide, model_wide, tag)
    print(f"algorithm={algorithm_path}")
    print(f"model={model_path}")
    print(f"algorithm_tex={alg_tex}")
    print(f"model_tex={model_tex}")
    print(f"report={report}")


if __name__ == "__main__":
    main()
