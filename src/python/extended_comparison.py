from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
RESULTS = ROOT / "results"
LATEX = ROOT / "latex"
CASES = ["HC1-100", "HR1-100", "HRC1-100"]
LABELS = {"HC1-100": "HC1", "HR1-100": "HR1", "HRC1-100": "HRC1"}
ALGORITHMS = ["VNS", "IMA", "PDR-HGA"]


def load() -> pd.DataFrame:
    files = []
    for case in CASES:
        tag = case.lower().replace("-", "_")
        files.extend(SOURCE.glob(f"algorithm_comparison_paper_lite_{tag}_*.csv"))
    if not files:
        raise FileNotFoundError("No frozen external-comparison files found")
    data = pd.concat([pd.read_csv(path) for path in sorted(files)], ignore_index=True)
    data["algorithm"] = data["algorithm"].replace({"IHGA": "PDR-HGA"})
    data = data.drop_duplicates(["caseName", "algorithm", "seed"], keep="last")
    for case in CASES:
        for algorithm in ALGORITHMS:
            part = data[data["caseName"].eq(case) & data["algorithm"].eq(algorithm)]
            if len(part) != 5 or part["seed"].nunique() != 5:
                raise ValueError(f"Incomplete five-seed grid for {case}/{algorithm}")
            penalty = part["bestFitness"].astype(float) - part["nodeDamage"].astype(float)
            if (penalty.abs() > 1e-7).any():
                raise ValueError(f"Penalized final solution for {case}/{algorithm}")
    return data[data["caseName"].isin(CASES)].copy()


def summarize(data: pd.DataFrame) -> pd.DataFrame:
    return (
        data.groupby(["caseName", "algorithm"], as_index=False)
        .agg(
            runs=("bestFitness", "size"),
            mean=("bestFitness", "mean"),
            best=("bestFitness", "min"),
            std=("bestFitness", "std"),
        )
        .sort_values(["caseName", "algorithm"])
    )


def write_latex(summary: pd.DataFrame) -> None:
    rows: list[str] = []
    for case_index, case in enumerate(CASES):
        part = summary[summary["caseName"].eq(case)].set_index("algorithm")
        for algorithm_index, algorithm in enumerate(ALGORITHMS):
            row = part.loc[algorithm]
            values = [f"{row['mean']:.3f}", f"{row['best']:.3f}", f"{row['std']:.3f}"]
            if algorithm == "PDR-HGA":
                values = [rf"\textbf{{{value}}}" for value in values]
            label = LABELS[case] if algorithm_index == 0 else ""
            rows.append(f"{label} & {algorithm} & {values[0]} & {values[1]} & {values[2]} \\\\")
        if case_index < len(CASES) - 1:
            rows.append(r"\midrule")
    rows.append(r"\bottomrule")
    (LATEX / "generated_frozen_external_rows.tex").write_text("\n".join(rows) + "\n", encoding="utf-8")


def write_report(summary: pd.DataFrame) -> None:
    lines = ["# Frozen critical_damage_v2 external comparison", ""]
    for case in CASES:
        part = summary[summary["caseName"].eq(case)].set_index("algorithm")
        pdr = part.loc["PDR-HGA", "mean"]
        ima = part.loc["IMA", "mean"]
        vns = part.loc["VNS", "mean"]
        lines.append(
            f"- {LABELS[case]}: PDR-HGA mean={pdr:.6f}; "
            f"reduction vs IMA={100 * (ima - pdr) / ima:.3f}%; "
            f"reduction vs VNS={100 * (vns - pdr) / vns:.3f}%."
        )
    lines.extend(["", "All 45 final solutions are penalty-free.", ""])
    (RESULTS / "frozen_external_comparison_report.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    data = load()
    summary = summarize(data)
    data.to_csv(RESULTS / "frozen_external_comparison_authoritative.csv", index=False, encoding="utf-8-sig")
    summary.to_csv(RESULTS / "frozen_external_comparison_summary.csv", index=False, encoding="utf-8-sig")
    write_latex(summary)
    write_report(summary)
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
