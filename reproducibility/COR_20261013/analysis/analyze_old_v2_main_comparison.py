from __future__ import annotations

import itertools
import math
import random
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
RESULTS = ROOT / "results"
LATEX = ROOT / "latex"
SOURCE_PATTERN = "algorithm_comparison_paper_lite_*.csv"
TARGET_RUNS = 20
CASES = ["C101-25", "r101-25", "rc101-25"]
LABELS = {"C101-25": "C101", "r101-25": "R101", "rc101-25": "RC101"}


def sign_flip_p(differences: list[float]) -> float:
    observed = abs(sum(differences) / len(differences))
    extreme = 0
    total = 0
    for signs in itertools.product((-1.0, 1.0), repeat=len(differences)):
        statistic = abs(sum(d * s for d, s in zip(differences, signs)) / len(differences))
        extreme += statistic >= observed - 1e-12
        total += 1
    return extreme / total


def bootstrap_ci(values: list[float], iterations: int = 20_000) -> tuple[float, float]:
    rng = random.Random(20260804)
    samples = []
    for _ in range(iterations):
        samples.append(sum(values[rng.randrange(len(values))] for _ in values) / len(values))
    samples.sort()
    return samples[int(0.025 * iterations)], samples[int(0.975 * iterations) - 1]


def holm(pvalues: list[float]) -> list[float]:
    order = sorted(range(len(pvalues)), key=pvalues.__getitem__)
    adjusted = [0.0] * len(pvalues)
    running = 0.0
    for rank, index in enumerate(order):
        running = max(running, (len(pvalues) - rank) * pvalues[index])
        adjusted[index] = min(1.0, running)
    return adjusted


def load() -> pd.DataFrame:
    source_files = sorted(SOURCE_DIR.glob(SOURCE_PATTERN))
    if not source_files:
        raise FileNotFoundError(f"No files match {SOURCE_DIR / SOURCE_PATTERN}")
    frames = [pd.read_csv(path) for path in source_files]
    data = pd.concat(frames, ignore_index=True)
    data["algorithm"] = data["algorithm"].replace({"IHGA": "PDR-HGA"})
    data = data[data["caseName"].isin(CASES)].copy()
    data = data.drop_duplicates(["caseName", "algorithm", "seed"], keep="last")
    expected_seeds = set(range(7301, 7301 + TARGET_RUNS))
    for case in CASES:
        for algorithm in ("PDR-HGA", "IMA", "VNS"):
            part = data[data["caseName"].eq(case) & data["algorithm"].eq(algorithm)]
            seeds = set(part["seed"].astype(int))
            if seeds != expected_seeds or len(part) != TARGET_RUNS:
                raise ValueError(f"Incomplete grid for {case}/{algorithm}: {sorted(seeds)}")
            if set(part["iterMax"].astype(int)) != {300} or set(part["popsize"].astype(int)) not in ({8}, {1}):
                raise ValueError(f"Unexpected run profile for {case}/{algorithm}")
            penalty = part["bestFitness"].astype(float) - part["nodeDamage"].astype(float)
            if (penalty.abs() > 1e-7).any():
                raise ValueError(f"Penalized final solutions detected for {case}/{algorithm}")
    return data.sort_values(["caseName", "seed", "algorithm"]).reset_index(drop=True)


def analyze(data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    summaries = []
    tests = []
    for case in CASES:
        part = data[data["caseName"].eq(case)]
        for algorithm in ("VNS", "IMA", "PDR-HGA"):
            values = part.loc[part["algorithm"].eq(algorithm), "bestFitness"].astype(float)
            summaries.append({
                "caseName": case,
                "algorithm": algorithm,
                "runs": len(values),
                "mean": values.mean(),
                "best": values.min(),
                "std": values.std(ddof=1),
            })
        wide = part.pivot(index="seed", columns="algorithm", values="bestFitness").astype(float)
        for baseline in ("IMA", "VNS"):
            differences = (wide[baseline] - wide["PDR-HGA"]).tolist()
            low, high = bootstrap_ci(differences)
            mean_difference = sum(differences) / len(differences)
            sd = pd.Series(differences).std(ddof=1)
            tests.append({
                "caseName": case,
                "comparison": f"PDR-HGA vs {baseline}",
                "pairs": len(differences),
                "meanReduction": mean_difference,
                "relativeReductionPct": 100 * mean_difference / wide[baseline].mean(),
                "ciLow": low,
                "ciHigh": high,
                "pairedEffectDz": mean_difference / sd if sd > 0 else math.inf,
                "wins": sum(value > 0 for value in differences),
                "ties": sum(abs(value) <= 1e-12 for value in differences),
                "losses": sum(value < 0 for value in differences),
                "pValueTwoSided": sign_flip_p(differences),
            })
    test_frame = pd.DataFrame(tests)
    test_frame["pValueHolm"] = holm(test_frame["pValueTwoSided"].tolist())
    return pd.DataFrame(summaries), test_frame


def write_latex(summary: pd.DataFrame, tests: pd.DataFrame) -> None:
    rows = []
    for case in CASES:
        part = summary[summary["caseName"].eq(case)].set_index("algorithm")
        for index, algorithm in enumerate(("VNS", "IMA", "PDR-HGA")):
            row = part.loc[algorithm]
            values = [f"{row['mean']:.3f}", f"{row['best']:.3f}", f"{row['std']:.3f}"]
            if algorithm == "PDR-HGA":
                values = [f"\\textbf{{{value}}}" for value in values]
            label = LABELS[case] if index == 0 else ""
            rows.append(f"{label} & {algorithm} & {values[0]} & {values[1]} & {values[2]} \\\\")
        if case != CASES[-1]:
            rows.append(r"\midrule")
    rows.append(r"\bottomrule")
    (LATEX / "generated_algorithm_comparison_old_v2_rows.tex").write_text(
        "\n".join(rows) + "\n", encoding="utf-8"
    )

    rows = []
    for row in tests.itertuples(index=False):
        baseline = row.comparison.replace("PDR-HGA vs ", "")
        p_text = r"$<0.0001$" if row.pValueHolm < 0.0001 else f"{row.pValueHolm:.4f}"
        rows.append(
            f"{LABELS[row.caseName]} & {baseline} & {row.pairs} & {row.meanReduction:.3f} & "
            f"[{row.ciLow:.3f}, {row.ciHigh:.3f}] & {row.pairedEffectDz:.3f} & {p_text} \\\\"
        )
    rows.append(r"\bottomrule")
    (LATEX / "generated_algorithm_significance_old_v2_rows.tex").write_text(
        "\n".join(rows) + "\n", encoding="utf-8"
    )


def markdown_table(frame: pd.DataFrame) -> str:
    columns = list(frame.columns)
    lines = [
        "| " + " | ".join(columns) + " |",
        "|" + "|".join("---" for _ in columns) + "|",
    ]
    for row in frame.itertuples(index=False, name=None):
        cells = [f"{value:.6f}" if isinstance(value, float) else str(value) for value in row]
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines)


def main() -> None:
    data = load()
    summary, tests = analyze(data)
    data.to_csv(RESULTS / "algorithm_comparison_old_v2_20run_authoritative.csv", index=False, encoding="utf-8-sig")
    summary.to_csv(RESULTS / "algorithm_comparison_old_v2_20run_summary.csv", index=False, encoding="utf-8-sig")
    tests.to_csv(RESULTS / "algorithm_comparison_old_v2_20run_paired_stats.csv", index=False, encoding="utf-8-sig")
    write_latex(summary, tests)
    report = "\n".join([
        "# Old critical_damage_v2 main comparison (20 paired runs)",
        "",
        markdown_table(summary),
        "",
        markdown_table(tests),
        "",
        "All 180 final solutions have zero penalty; final feasible rate is 100%.",
        "",
    ])
    (RESULTS / "algorithm_comparison_old_v2_20run_report.md").write_text(report, encoding="utf-8")
    print(summary.to_string(index=False))
    print(tests.to_string(index=False))


if __name__ == "__main__":
    main()
