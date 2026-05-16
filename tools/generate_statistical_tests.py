from __future__ import annotations

import argparse
import itertools
import random
from pathlib import Path

import pandas as pd


RESULTS_DIR = Path("results")
LATEX_DIR = Path("latex")

ALGORITHM_BASELINE_RAW = RESULTS_DIR / "algorithm_comparison_paper_20260429_144733.csv"
ALGORITHM_IHGA_RAW = RESULTS_DIR / "algorithm_comparison_pair_paper_ihga_latest.csv"
ABLATION_RAW = RESULTS_DIR / "ablation_paper_lite_20260506_105855.csv"


def mean(values: list[float]) -> float:
    return sum(values) / len(values)


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return float("nan")
    ordered = sorted(values)
    pos = (len(ordered) - 1) * pct / 100.0
    lo = int(pos)
    hi = min(lo + 1, len(ordered) - 1)
    frac = pos - lo
    return ordered[lo] * (1.0 - frac) + ordered[hi] * frac


def sign_randomization_p_value(diffs: list[float]) -> float:
    """Exact two-sided sign-randomization p-value for paired mean differences."""
    if not diffs:
        return float("nan")
    observed = abs(mean(diffs))
    count = 0
    total = 0
    for signs in itertools.product((-1.0, 1.0), repeat=len(diffs)):
        total += 1
        signed_mean = abs(mean([d * s for d, s in zip(diffs, signs)]))
        if signed_mean >= observed - 1e-12:
            count += 1
    return count / total


def bootstrap_ci(diffs: list[float], iterations: int = 10000, seed: int = 20260516) -> tuple[float, float]:
    if not diffs:
        return (float("nan"), float("nan"))
    rng = random.Random(seed)
    boot_means = []
    for _ in range(iterations):
        sample = [diffs[rng.randrange(len(diffs))] for _ in diffs]
        boot_means.append(mean(sample))
    return (percentile(boot_means, 2.5), percentile(boot_means, 97.5))


def paired_diffs(df: pd.DataFrame, group_cols: list[str], baseline: str, candidate: str) -> list[float]:
    wide = df.pivot_table(
        index=group_cols,
        columns="method",
        values="damage",
        aggfunc="mean",
    ).reset_index()
    wide = wide.dropna(subset=[baseline, candidate])
    return (wide[baseline] - wide[candidate]).astype(float).tolist()


def algorithm_rows() -> list[dict[str, object]]:
    baseline = pd.read_csv(ALGORITHM_BASELINE_RAW)
    baseline = baseline[baseline["algorithm"].isin(["VNS", "IMA"])].copy()
    ihga = pd.read_csv(ALGORITHM_IHGA_RAW).copy()
    ihga = ihga[ihga["algorithm"].eq("IHGA")]

    data = pd.concat(
        [
            baseline[["caseName", "seed", "algorithm", "bestFitness"]].rename(
                columns={"algorithm": "method", "bestFitness": "damage"}
            ),
            ihga[["caseName", "seed", "algorithm", "bestFitness"]].rename(
                columns={"algorithm": "method", "bestFitness": "damage"}
            ),
        ],
        ignore_index=True,
    )

    rows: list[dict[str, object]] = []
    for case in sorted(data["caseName"].unique()):
        case_df = data[data["caseName"].eq(case)]
        for baseline_method in ["IMA", "VNS"]:
            diffs = paired_diffs(case_df, ["caseName", "seed"], baseline_method, "IHGA")
            if not diffs:
                continue
            ci_low, ci_high = bootstrap_ci(diffs)
            rows.append(
                {
                    "experiment": "algorithm",
                    "caseName": case,
                    "comparison": f"IHGA vs {baseline_method}",
                    "pairs": len(diffs),
                    "meanDifference": mean(diffs),
                    "ciLow": ci_low,
                    "ciHigh": ci_high,
                    "pValue": sign_randomization_p_value(diffs),
                    "positivePairs": sum(1 for d in diffs if d > 0),
                    "interpretation": "positive means IHGA has lower dynamic damage",
                }
            )
    return rows


def ablation_rows() -> list[dict[str, object]]:
    raw = pd.read_csv(ABLATION_RAW)
    raw = raw.rename(columns={"variant": "method", "bestFitness": "damage"})
    raw["method"] = raw["method"].replace({"MP-IHGA": "IHGA"})
    rows: list[dict[str, object]] = []
    for case in sorted(raw["caseName"].unique()):
        case_df = raw[raw["caseName"].eq(case)]
        for variant in ["Base HGA", "w/o damage-critical", "w/o period relocation", "w/o route restructuring"]:
            diffs = paired_diffs(case_df, ["caseName", "seed"], variant, "IHGA")
            if not diffs:
                continue
            ci_low, ci_high = bootstrap_ci(diffs)
            rows.append(
                {
                    "experiment": "ablation",
                    "caseName": case,
                    "comparison": f"IHGA vs {variant}",
                    "pairs": len(diffs),
                    "meanDifference": mean(diffs),
                    "ciLow": ci_low,
                    "ciHigh": ci_high,
                    "pValue": sign_randomization_p_value(diffs),
                    "positivePairs": sum(1 for d in diffs if d > 0),
                    "interpretation": "positive means removing the component increases dynamic damage",
                }
            )
    return rows


def fmt(value: float) -> str:
    return f"{value:.3f}"


def write_latex_rows(rows: list[dict[str, object]], output: Path) -> None:
    selected = [
        row
        for row in rows
        if row["experiment"] == "algorithm" and row["comparison"] == "IHGA vs IMA"
    ]
    lines = []
    for row in selected:
        lines.append(
            f"{row['caseName']} & {row['pairs']} & {fmt(float(row['meanDifference']))} & "
            f"[{fmt(float(row['ciLow']))}, {fmt(float(row['ciHigh']))}] & "
            f"{float(row['pValue']):.4f} \\\\"
        )
    lines.append(r"\bottomrule")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_report(rows: list[dict[str, object]], output: Path) -> None:
    lines = [
        "# Paired Statistical Checks",
        "",
        "Positive mean differences indicate lower dynamic damage for IHGA.",
        "The p-values are exact two-sided sign-randomization p-values; with 3--5 paired runs they should be interpreted as diagnostic evidence rather than strong significance claims.",
        "",
        "| Experiment | Case | Comparison | Pairs | Mean diff. | 95% bootstrap CI | p-value | Positive pairs |",
        "|---|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| {row['experiment']} | {row['caseName']} | {row['comparison']} | {row['pairs']} | "
            f"{fmt(float(row['meanDifference']))} | [{fmt(float(row['ciLow']))}, {fmt(float(row['ciHigh']))}] | "
            f"{float(row['pValue']):.4f} | {row['positivePairs']}/{row['pairs']} |"
        )
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", default=RESULTS_DIR / "statistical_tests_summary.csv", type=Path)
    parser.add_argument("--report", default=RESULTS_DIR / "statistical_tests_report.md", type=Path)
    parser.add_argument("--latex", default=LATEX_DIR / "generated_statistical_test_rows.tex", type=Path)
    args = parser.parse_args()

    rows = algorithm_rows() + ablation_rows()
    df = pd.DataFrame(rows)
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    args.latex.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.csv, index=False, encoding="utf-8-sig")
    write_latex_rows(rows, args.latex)
    write_report(rows, args.report)
    print(f"csv={args.csv}")
    print(f"latex={args.latex}")
    print(f"report={args.report}")


if __name__ == "__main__":
    main()
