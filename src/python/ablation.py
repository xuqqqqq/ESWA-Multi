from __future__ import annotations

import itertools
import random
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
WORKTREE_RESULTS = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
HISTORICAL = RESULTS / "ablation_paper_lite_10run_combined.csv"
FORMAL_RUN_FILES = [
    WORKTREE_RESULTS / "ablation_paper_lite_20260804_085742.csv",
    WORKTREE_RESULTS / "ablation_paper_lite_20260804_085748.csv",
    WORKTREE_RESULTS / "ablation_paper_lite_20260804_085740.csv",
]

CASES = ["C101-25", "r101-25", "rc101-25"]
CASE_LABELS = {"C101-25": "C101", "r101-25": "R101", "rc101-25": "RC101"}
SEEDS = {
    "C101-25": range(10701, 10711),
    "r101-25": range(11701, 11711),
    "rc101-25": range(12701, 12711),
}
PROFILES = [
    ("base_hga", "Base HGA"),
    ("damage_critical_only", "Damage-critical repair"),
    ("period_relocate_only", "Period-aware relocation"),
    ("damage_period_coupled", "Coupled repair"),
]


def exact_sign_flip_pvalue(differences: list[float]) -> float:
    observed = abs(sum(differences) / len(differences))
    extreme = 0
    total = 0
    for signs in itertools.product((-1.0, 1.0), repeat=len(differences)):
        statistic = abs(sum(value * sign for value, sign in zip(differences, signs)) / len(differences))
        extreme += statistic >= observed - 1e-12
        total += 1
    return extreme / total


def bootstrap_mean_ci(values: list[float], iterations: int = 20_000) -> tuple[float, float]:
    rng = random.Random(20260804)
    means = []
    for _ in range(iterations):
        sample = [values[rng.randrange(len(values))] for _ in values]
        means.append(sum(sample) / len(sample))
    means.sort()
    return means[int(0.025 * iterations)], means[int(0.975 * iterations) - 1]


def holm_adjust(pvalues: list[float]) -> list[float]:
    order = sorted(range(len(pvalues)), key=pvalues.__getitem__)
    adjusted = [0.0] * len(pvalues)
    running = 0.0
    for rank, index in enumerate(order):
        running = max(running, (len(pvalues) - rank) * pvalues[index])
        adjusted[index] = min(1.0, running)
    return adjusted


def load_new_standalone_runs() -> pd.DataFrame:
    files = FORMAL_RUN_FILES
    missing_files = [path for path in files if not path.exists()]
    if missing_files:
        raise FileNotFoundError(f"Missing formal standalone run files: {missing_files}")

    frames = []
    for path in files:
        frame = pd.read_csv(path)
        frame["sourceFile"] = path.name
        frames.append(frame)
    data = pd.concat(frames, ignore_index=True)
    data = data[data["operatorProfile"].isin(["damage_critical_only", "period_relocate_only"])]
    data = data.sort_values("sourceFile").drop_duplicates(
        ["caseName", "seed", "operatorProfile"], keep="last"
    )
    return data


def build_authoritative_grid() -> pd.DataFrame:
    historical = pd.read_csv(HISTORICAL)
    base = historical[historical["operatorProfile"].eq("base_hga")].copy()
    coupled = historical[historical["operatorProfile"].eq("no_route_structure")].copy()
    coupled["variant"] = "Coupled repair"
    coupled["operatorProfile"] = "damage_period_coupled"
    coupled["algorithmVersion"] = "critical_damage_v2_damage_period_coupled"

    standalone = load_new_standalone_runs().copy()
    labels = dict(PROFILES)
    standalone["variant"] = standalone["operatorProfile"].map(labels)
    data = pd.concat([base, standalone, coupled], ignore_index=True)
    data = data.drop(columns=["sourceFile"], errors="ignore")
    data = data.drop_duplicates(["caseName", "seed", "operatorProfile"], keep="last")

    expected = {
        (case, seed, profile)
        for case in CASES
        for seed in SEEDS[case]
        for profile, _ in PROFILES
    }
    actual = set(zip(data["caseName"], data["seed"].astype(int), data["operatorProfile"]))
    if actual != expected:
        raise ValueError(
            "Incomplete old-v2 combined ablation grid: "
            f"missing={sorted(expected - actual)}, extra={sorted(actual - expected)}"
        )

    return data.sort_values(["caseName", "seed", "operatorProfile"]).reset_index(drop=True)


def summarize(data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    summary_rows = []
    paired_rows = []
    interaction_rows = []
    marginal_rows = []

    for case in CASES:
        part = data[data["caseName"].eq(case)]
        wide = part.pivot(index="seed", columns="operatorProfile", values="bestFitness").astype(float)
        base = wide["base_hga"]

        for profile, label in PROFILES:
            values = wide[profile]
            summary_rows.append(
                {
                    "caseName": CASE_LABELS[case],
                    "profile": profile,
                    "variant": label,
                    "runs": len(values),
                    "mean": values.mean(),
                    "best": values.min(),
                    "std": values.std(ddof=1),
                    "reductionVsBasePct": 100.0 * (base.mean() - values.mean()) / base.mean(),
                }
            )
            if profile == "base_hga":
                continue
            differences = (base - values).tolist()
            low, high = bootstrap_mean_ci(differences)
            paired_rows.append(
                {
                    "caseName": CASE_LABELS[case],
                    "comparison": f"{label} vs Base HGA",
                    "pairs": len(differences),
                    "meanReduction": sum(differences) / len(differences),
                    "relativeReductionPct": 100.0 * sum(differences) / len(differences) / base.mean(),
                    "ciLow": low,
                    "ciHigh": high,
                    "wins": sum(value > 1e-12 for value in differences),
                    "ties": sum(abs(value) <= 1e-12 for value in differences),
                    "losses": sum(value < -1e-12 for value in differences),
                    "pValueTwoSided": exact_sign_flip_pvalue(differences),
                }
            )

        factorial_interaction = (
            wide["damage_critical_only"]
            + wide["period_relocate_only"]
            - wide["damage_period_coupled"]
            - wide["base_hga"]
        )
        low, high = bootstrap_mean_ci(factorial_interaction.tolist())
        interaction_rows.append(
            {
                "caseName": CASE_LABELS[case],
                "meanInteraction": factorial_interaction.mean(),
                "ciLow": low,
                "ciHigh": high,
                "positivePairs": int((factorial_interaction > 1e-12).sum()),
                "ties": int((factorial_interaction.abs() <= 1e-12).sum()),
                "negativePairs": int((factorial_interaction < -1e-12).sum()),
                "pValueTwoSided": exact_sign_flip_pvalue(factorial_interaction.tolist()),
            }
        )

        for standalone_profile, standalone_label in (
            ("damage_critical_only", "Damage-critical repair"),
            ("period_relocate_only", "Period-aware relocation"),
        ):
            differences = (wide[standalone_profile] - wide["damage_period_coupled"]).tolist()
            low, high = bootstrap_mean_ci(differences)
            marginal_rows.append(
                {
                    "caseName": CASE_LABELS[case],
                    "comparison": f"Coupled repair vs {standalone_label}",
                    "meanAdditionalReduction": sum(differences) / len(differences),
                    "ciLow": low,
                    "ciHigh": high,
                    "wins": sum(value > 1e-12 for value in differences),
                    "ties": sum(abs(value) <= 1e-12 for value in differences),
                    "losses": sum(value < -1e-12 for value in differences),
                    "pValueTwoSided": exact_sign_flip_pvalue(differences),
                }
            )

    paired = pd.DataFrame(paired_rows)
    paired["pValueHolm"] = holm_adjust(paired["pValueTwoSided"].tolist())
    return pd.DataFrame(summary_rows), paired, pd.DataFrame(interaction_rows), pd.DataFrame(marginal_rows)


def markdown_table(frame: pd.DataFrame) -> str:
    columns = list(frame.columns)
    lines = ["| " + " | ".join(columns) + " |", "|" + "|".join("---" for _ in columns) + "|"]
    for row in frame.itertuples(index=False, name=None):
        values = [f"{value:.6f}" if isinstance(value, float) else str(value) for value in row]
        lines.append("| " + " | ".join(values) + " |")
    return "\n".join(lines)


def main() -> None:
    data = build_authoritative_grid()
    summary, paired, interactions, marginals = summarize(data)

    data_path = RESULTS / "ablation_old_v2_combined_10run_authoritative.csv"
    summary_path = RESULTS / "ablation_old_v2_combined_10run_summary.csv"
    paired_path = RESULTS / "ablation_old_v2_combined_10run_paired_stats.csv"
    interaction_path = RESULTS / "ablation_old_v2_combined_10run_interactions.csv"
    marginal_path = RESULTS / "ablation_old_v2_combined_10run_marginal_stats.csv"
    report_path = RESULTS / "ablation_old_v2_combined_10run_report.md"

    data.to_csv(data_path, index=False, encoding="utf-8-sig")
    summary.to_csv(summary_path, index=False, encoding="utf-8-sig")
    paired.to_csv(paired_path, index=False, encoding="utf-8-sig")
    interactions.to_csv(interaction_path, index=False, encoding="utf-8-sig")
    marginals.to_csv(marginal_path, index=False, encoding="utf-8-sig")
    report_path.write_text(
        "\n".join(
            [
                "# Old critical_damage_v2 combined ablation (10 paired runs)",
                "",
                "Core 2x2 design: Base HGA, damage-critical repair only, period-aware relocation only, and both repairs coupled.",
                "Route restructuring is excluded from this core efficacy ablation.",
                "",
                "## Descriptive results",
                "",
                markdown_table(summary),
                "",
                "## Paired comparisons against Base HGA",
                "",
                markdown_table(paired),
                "",
                "## Factorial interaction diagnostic",
                "",
                markdown_table(interactions),
                "",
                "A positive interaction means the coupled reduction exceeds the sum of the two standalone reductions; it should not be interpreted as synergy unless its confidence interval and paired test support that claim.",
                "",
                "## Coupled-versus-standalone marginal contrasts",
                "",
                markdown_table(marginals),
                "",
            ]
        ),
        encoding="utf-8",
    )

    print(summary.to_string(index=False))
    print(paired.to_string(index=False))
    print(interactions.to_string(index=False))
    print(marginals.to_string(index=False))
    print(f"Saved {report_path}")


if __name__ == "__main__":
    main()
