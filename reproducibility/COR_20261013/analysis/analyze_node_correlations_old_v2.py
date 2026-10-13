from __future__ import annotations

import itertools
import random
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
RESULTS = ROOT / "results"
LATEX = ROOT / "latex"
FILES = [
    SOURCE_DIR / "node_correlation_old_v2_C.csv",
    SOURCE_DIR / "node_correlation_old_v2_R.csv",
    SOURCE_DIR / "node_correlation_old_v2_RC.csv",
]
CASES = ["C101-25", "r101-25", "rc101-25"]
CASE_LABELS = {"C101-25": "C101", "r101-25": "R101", "rc101-25": "RC101"}
METRICS = {
    "initialDamage": "Initial damage",
    "deteriorationRate": "Deterioration rate",
    "sustainedPressure": "Sustained pressure",
    "urgency": "Composite urgency",
}
# Service rank is the deterministic rank transform of arrival time, so a
# second Spearman column would duplicate the arrival-time result exactly.
OUTCOMES = ["arrivalTime"]
EXPECTED_SEEDS = 10
EXPECTED_NODES = 100


def sign_flip_p(values: list[float]) -> float:
    observed = abs(sum(values) / len(values))
    extreme = 0
    total = 0
    for signs in itertools.product((-1.0, 1.0), repeat=len(values)):
        statistic = abs(sum(value * sign for value, sign in zip(values, signs)) / len(values))
        extreme += statistic >= observed - 1e-12
        total += 1
    return extreme / total


def bootstrap_ci(values: list[float], iterations: int = 20_000) -> tuple[float, float]:
    rng = random.Random(20260804)
    means = []
    for _ in range(iterations):
        means.append(sum(values[rng.randrange(len(values))] for _ in values) / len(values))
    means.sort()
    return means[int(0.025 * iterations)], means[int(0.975 * iterations) - 1]


def holm(pvalues: list[float]) -> list[float]:
    order = sorted(range(len(pvalues)), key=pvalues.__getitem__)
    adjusted = [0.0] * len(pvalues)
    running = 0.0
    for rank, index in enumerate(order):
        running = max(running, (len(pvalues) - rank) * pvalues[index])
        adjusted[index] = min(1.0, running)
    return adjusted


def load() -> pd.DataFrame:
    data = pd.concat([pd.read_csv(path) for path in FILES], ignore_index=True)
    for case in CASES:
        part = data[data["caseName"].eq(case)]
        expected_rows = EXPECTED_SEEDS * EXPECTED_NODES
        if part["seed"].nunique() != EXPECTED_SEEDS or len(part) != expected_rows:
            raise ValueError(
                f"Expected {EXPECTED_SEEDS} seeds and {expected_rows} node rows for {case}."
            )
        if set(part.groupby("seed")["node"].nunique()) != {EXPECTED_NODES}:
            raise ValueError(f"Each seed must contain {EXPECTED_NODES} nodes for {case}.")
    return data


def analyze(data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    seed_rows = []
    for case in CASES:
        part = data[data["caseName"].eq(case)]
        for seed, run in part.groupby("seed"):
            for metric in METRICS:
                for outcome in OUTCOMES:
                    rho = run[metric].rank().corr(run[outcome].rank())
                    seed_rows.append({
                        "caseName": case,
                        "seed": int(seed),
                        "metric": metric,
                        "outcome": outcome,
                        "spearmanRho": rho,
                    })
    seed_frame = pd.DataFrame(seed_rows)
    summary_rows = []
    for (case, metric, outcome), part in seed_frame.groupby(["caseName", "metric", "outcome"], sort=False):
        values = part["spearmanRho"].astype(float).tolist()
        low, high = bootstrap_ci(values)
        summary_rows.append({
            "caseName": case,
            "metric": metric,
            "outcome": outcome,
            "runs": len(values),
            "meanRho": sum(values) / len(values),
            "ciLow": low,
            "ciHigh": high,
            "pValueTwoSided": sign_flip_p(values),
        })
    summary = pd.DataFrame(summary_rows)
    summary["pValueHolm"] = 1.0
    for outcome in OUTCOMES:
        mask = summary["outcome"].eq(outcome)
        summary.loc[mask, "pValueHolm"] = holm(summary.loc[mask, "pValueTwoSided"].tolist())
    return seed_frame, summary


def write_latex(summary: pd.DataFrame) -> None:
    lines = []
    for case in CASES:
        for index, metric in enumerate(METRICS):
            row = summary[
                summary["caseName"].eq(case)
                & summary["metric"].eq(metric)
                & summary["outcome"].eq("arrivalTime")
            ].iloc[0]
            case_label = CASE_LABELS[case] if index == 0 else ""
            lines.append(
                f"{case_label} & {METRICS[metric]} & {row['meanRho']:.3f} & "
                f"[{row['ciLow']:.3f}, {row['ciHigh']:.3f}] & {row['pValueHolm']:.4f} \\\\"
            )
        if case != CASES[-1]:
            lines.append(r"\midrule")
    lines.append(r"\bottomrule")
    (LATEX / "generated_node_correlation_old_v2_rows.tex").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


def main() -> None:
    data = load()
    seed_frame, summary = analyze(data)
    seed_frame.to_csv(RESULTS / "node_correlation_old_v2_seed_level.csv", index=False, encoding="utf-8-sig")
    summary.to_csv(RESULTS / "node_correlation_old_v2_summary.csv", index=False, encoding="utf-8-sig")
    write_latex(summary)
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
