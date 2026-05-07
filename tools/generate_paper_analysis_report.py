from __future__ import annotations

from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from plot_style import (
    ALGORITHM_COLORS,
    CASE_COLORS,
    MODEL_COLORS,
    OKABE_ITO,
    apply_paper_style,
    style_axes as paper_style_axes,
)


RESULTS_DIR = Path("results")
CASE_ORDER = ["C101-25", "r101-25", "rc101-25"]
CASE_LABEL = {
    "C101-25": "C101-25",
    "r101-25": "R101-25",
    "rc101-25": "RC101-25",
}
ALGORITHM_ORDER = ["VNS", "IMA", "IHGA"]
MODEL_ORDER = ["CVRP", "CCVRP", "DDVRP-IHGA"]
PALETTE = {
    **ALGORITHM_COLORS,
    **MODEL_COLORS,
    **CASE_COLORS,
}


def latest(pattern: str) -> Path:
    files = sorted(
        [p for p in RESULTS_DIR.glob(pattern) if not p.stem.endswith("_summary")],
        key=lambda p: p.stat().st_mtime,
    )
    if not files:
        raise FileNotFoundError(f"No files match {pattern}")
    return files[-1]


def style_axes(ax: plt.Axes) -> None:
    paper_style_axes(ax)


def pct_improve(baseline: float, candidate: float) -> float:
    return (baseline - candidate) / baseline * 100.0


def savefig(fig: plt.Figure, path: Path) -> None:
    fig.tight_layout()
    fig.savefig(path, dpi=300, bbox_inches="tight")
    plt.close(fig)


def algorithm_tables(algorithm_summary: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    rows = []
    for case in CASE_ORDER:
        vals = algorithm_summary[algorithm_summary["caseName"] == case].set_index("algorithm")
        ihga = float(vals.loc["IHGA", "avgDamage"])
        ima = float(vals.loc["IMA", "avgDamage"])
        vns = float(vals.loc["VNS", "avgDamage"])
        best_baseline = min(ima, vns)
        rows.append(
            {
                "caseName": case,
                "IHGA": ihga,
                "IMA": ima,
                "VNS": vns,
                "IHGA_std": float(vals.loc["IHGA", "stdDamage"]),
                "IMA_std": float(vals.loc["IMA", "stdDamage"]),
                "VNS_std": float(vals.loc["VNS", "stdDamage"]),
                "improve_vs_IMA_pct": pct_improve(ima, ihga),
                "improve_vs_VNS_pct": pct_improve(vns, ihga),
                "improve_vs_best_baseline_pct": pct_improve(best_baseline, ihga),
            }
        )
    wide = pd.DataFrame(rows)

    long_rows = []
    for case in CASE_ORDER:
        vals = algorithm_summary[algorithm_summary["caseName"] == case].set_index("algorithm")
        for alg in ALGORITHM_ORDER:
            long_rows.append(
                {
                    "caseName": case,
                    "algorithm": alg,
                    "avgDamage": float(vals.loc[alg, "avgDamage"]),
                    "stdDamage": float(vals.loc[alg, "stdDamage"]),
                }
            )
    return wide, pd.DataFrame(long_rows)


def model_table(model_summary: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for case in CASE_ORDER:
        vals = model_summary[model_summary["caseName"] == case].set_index("modelName")
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
                "DDVRP_distance": float(vals.loc["DDVRP-IHGA", "avgDistance"]),
                "CCVRP_distance": float(vals.loc["CCVRP", "avgDistance"]),
                "CVRP_distance": float(vals.loc["CVRP", "avgDistance"]),
                "DDVRP_completion_time": float(vals.loc["DDVRP-IHGA", "avgCompletionTime"]),
                "CCVRP_completion_time": float(vals.loc["CCVRP", "avgCompletionTime"]),
                "CVRP_completion_time": float(vals.loc["CVRP", "avgCompletionTime"]),
            }
        )
    return pd.DataFrame(rows)


def vehicle_summary(vehicle_raw: pd.DataFrame) -> pd.DataFrame:
    return (
        vehicle_raw.groupby(["caseName", "carNum"], as_index=False)
        .agg(
            avgDamage=("bestFitness", "mean"),
            bestDamage=("bestFitness", "min"),
            stdDamage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
        )
        .sort_values(["caseName", "carNum"])
    )


def vehicle_marginal(vehicle_sum: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for case, group in vehicle_sum.groupby("caseName"):
        vals = list(group.sort_values("carNum")[["carNum", "avgDamage"]].itertuples(index=False, name=None))
        for (car_a, dmg_a), (car_b, dmg_b) in zip(vals, vals[1:]):
            rows.append(
                {
                    "caseName": case,
                    "fromCar": int(car_a),
                    "toCar": int(car_b),
                    "damageDrop": float(dmg_a - dmg_b),
                    "dropPctFromStart": pct_improve(float(dmg_a), float(dmg_b)),
                }
            )
    return pd.DataFrame(rows)


def priority_urgency(priority_summary: pd.DataFrame) -> pd.DataFrame:
    urgency = priority_summary[priority_summary["priorityMetric"] == "urgency"]
    rows = []
    for case in CASE_ORDER:
        vals = urgency[urgency["caseName"] == case].set_index("priorityGroup")
        high = vals.loc["high"]
        medium = vals.loc["medium"]
        low = vals.loc["low"]
        rows.append(
            {
                "caseName": case,
                "arrivalHigh": float(high["avgArrivalTime"]),
                "arrivalMedium": float(medium["avgArrivalTime"]),
                "arrivalLow": float(low["avgArrivalTime"]),
                "rankHigh": float(high["avgServiceRank"]),
                "rankMedium": float(medium["avgServiceRank"]),
                "rankLow": float(low["avgServiceRank"]),
                "damageHigh": float(high["avgNodeDamage"]),
                "damageMedium": float(medium["avgNodeDamage"]),
                "damageLow": float(low["avgNodeDamage"]),
                "highEarlierThanLowPct": pct_improve(float(low["avgArrivalTime"]), float(high["avgArrivalTime"])),
                "highDamageOverLowRatio": float(high["avgNodeDamage"]) / float(low["avgNodeDamage"]),
            }
        )
    return pd.DataFrame(rows)


def fig_algorithm_comparison(summary: pd.DataFrame, out_dir: Path) -> Path:
    fig, axes = plt.subplots(1, 3, figsize=(12.8, 4.2), sharey=False)
    for ax, case in zip(axes, CASE_ORDER):
        part = summary[summary["caseName"] == case].set_index("algorithm").loc[ALGORITHM_ORDER].reset_index()
        x = np.arange(len(ALGORITHM_ORDER))
        colors = [PALETTE[a] for a in ALGORITHM_ORDER]
        ax.bar(x, part["avgDamage"], yerr=part["stdDamage"], color=colors, capsize=4, width=0.62)
        vals = part.set_index("algorithm")
        improve = pct_improve(float(vals.loc["IMA", "avgDamage"]), float(vals.loc["IHGA", "avgDamage"]))
        ax.text(2, float(vals.loc["IHGA", "avgDamage"]) + 2.5, f"{improve:.1f}% lower vs IMA", ha="center", fontsize=9)
        ax.set_xticks(x, ALGORITHM_ORDER)
        ax.set_title(CASE_LABEL[case])
        ax.set_ylabel("Total dynamic damage")
        style_axes(ax)
    fig.suptitle("Algorithm comparison under the same dynamic damage objective", fontsize=13, fontweight="bold")
    out = out_dir / "fig_01_algorithm_comparison.png"
    savefig(fig, out)
    return out


def fig_algorithm_improvement(improvement: pd.DataFrame, out_dir: Path) -> Path:
    x = np.arange(len(CASE_ORDER))
    width = 0.35
    fig, ax = plt.subplots(figsize=(7.8, 4.2))
    ax.bar(x - width / 2, improvement["improve_vs_IMA_pct"], width, label="vs IMA", color=OKABE_ITO["orange"])
    ax.bar(x + width / 2, improvement["improve_vs_VNS_pct"], width, label="vs VNS", color=OKABE_ITO["blue"])
    ax.set_xticks(x, [CASE_LABEL[c] for c in CASE_ORDER])
    ax.set_ylabel("Improvement in total damage (%)")
    ax.set_title("IHGA improvement over baselines")
    ax.legend(frameon=False)
    style_axes(ax)
    out = out_dir / "fig_02_algorithm_improvement.png"
    savefig(fig, out)
    return out


def fig_model_comparison(model_summary: pd.DataFrame, out_dir: Path) -> Path:
    fig, axes = plt.subplots(1, 3, figsize=(12.8, 4.2), sharey=False)
    for ax, case in zip(axes, CASE_ORDER):
        part = model_summary[model_summary["caseName"] == case].set_index("modelName").loc[MODEL_ORDER].reset_index()
        x = np.arange(len(MODEL_ORDER))
        ax.bar(x, part["avgDynamicDamage"], color=[PALETTE[m] for m in MODEL_ORDER], width=0.62)
        ax.set_xticks(x, MODEL_ORDER, rotation=20)
        ax.set_title(CASE_LABEL[case])
        ax.set_ylabel("Dynamic damage")
        style_axes(ax)
    fig.suptitle("Model comparison: damage-oriented routing vs distance/capacity models", fontsize=13, fontweight="bold")
    out = out_dir / "fig_03_model_comparison.png"
    savefig(fig, out)
    return out


def fig_period_sensitivity(sensitivity_summary: pd.DataFrame, out_dir: Path) -> Path:
    part = sensitivity_summary[sensitivity_summary["experiment"] == "period_fixed_fleet"].copy()
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for case in CASE_ORDER:
        g = part[part["caseName"] == case].sort_values("numPeriods")
        ax.errorbar(
            g["numPeriods"],
            g["avgDamage"],
            yerr=g["stdDamage"],
            marker="o",
            linewidth=2,
            capsize=3,
            label=CASE_LABEL[case],
            color=PALETTE[case],
        )
    ax.set_xlabel("Number of planning periods")
    ax.set_ylabel("Total dynamic damage")
    ax.set_title("Period sensitivity with fixed total fleet and nearly fixed total supply")
    ax.set_xticks(sorted(part["numPeriods"].unique()))
    ax.legend(frameon=False)
    style_axes(ax)
    out = out_dir / "fig_04_period_sensitivity.png"
    savefig(fig, out)
    return out


def fig_inventory_sensitivity(sensitivity_summary: pd.DataFrame, out_dir: Path) -> tuple[Path, Path]:
    inv = sensitivity_summary[sensitivity_summary["experiment"] == "inventory_qp"].copy()
    normal = inv[inv["inventoryFactor"] >= 0.99].copy()
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for case in CASE_ORDER:
        g = normal[normal["caseName"] == case].sort_values("QpPerPeriod")
        ax.errorbar(
            g["QpPerPeriod"],
            g["avgDamage"],
            yerr=g["stdDamage"],
            marker="o",
            linewidth=2,
            capsize=3,
            label=CASE_LABEL[case],
            color=PALETTE[case],
        )
    ax.set_xlabel("Per-period supply Qp")
    ax.set_ylabel("Total dynamic damage")
    ax.set_title("Inventory sensitivity in the feasible supply region")
    ax.legend(frameon=False)
    style_axes(ax)
    feasible_out = out_dir / "fig_05_inventory_sensitivity_feasible.png"
    savefig(fig, feasible_out)

    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for case in CASE_ORDER:
        g = inv[inv["caseName"] == case].sort_values("inventoryFactor")
        ax.plot(
            g["inventoryFactor"],
            g["avgDamage"],
            marker="o",
            linewidth=2,
            label=CASE_LABEL[case],
            color=PALETTE[case],
        )
    ax.set_yscale("log")
    ax.set_xlabel("Total supply / total demand")
    ax.set_ylabel("Objective value (log scale)")
    ax.set_title("Shortage penalty region separated by log scale")
    ax.axvline(1.0, color=OKABE_ITO["black"], linestyle="--", linewidth=1)
    ax.text(1.01, ax.get_ylim()[1] / 8, "feasibility threshold", fontsize=9)
    ax.legend(frameon=False)
    style_axes(ax)
    shortage_out = out_dir / "fig_06_inventory_shortage_penalty.png"
    savefig(fig, shortage_out)
    return feasible_out, shortage_out


def fig_vehicle_sensitivity(vehicle_sum: pd.DataFrame, out_dir: Path) -> Path:
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for case in CASE_ORDER:
        g = vehicle_sum[vehicle_sum["caseName"] == case].sort_values("carNum")
        ax.errorbar(
            g["carNum"],
            g["avgDamage"],
            yerr=g["stdDamage"],
            marker="o",
            linewidth=2,
            capsize=3,
            label=CASE_LABEL[case],
            color=PALETTE[case],
        )
    ax.set_xlabel("Number of vehicles per period")
    ax.set_ylabel("Total dynamic damage")
    ax.set_title("Vehicle sensitivity and diminishing marginal returns")
    ax.legend(frameon=False)
    style_axes(ax)
    out = out_dir / "fig_07_vehicle_sensitivity.png"
    savefig(fig, out)
    return out


def fig_vehicle_marginal(vehicle_marg: pd.DataFrame, out_dir: Path) -> Path:
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for case in CASE_ORDER:
        g = vehicle_marg[vehicle_marg["caseName"] == case].copy()
        labels = [f"{int(a)}-{int(b)}" for a, b in zip(g["fromCar"], g["toCar"])]
        ax.plot(labels, g["damageDrop"], marker="o", linewidth=2, label=CASE_LABEL[case], color=PALETTE[case])
    ax.set_xlabel("Vehicle interval")
    ax.set_ylabel("Damage reduction")
    ax.set_title("Marginal damage reduction from additional vehicles")
    ax.legend(frameon=False)
    style_axes(ax)
    out = out_dir / "fig_08_vehicle_marginal_returns.png"
    savefig(fig, out)
    return out


def fig_priority_urgency(priority_summary: pd.DataFrame, out_dir: Path) -> Path:
    urgency = priority_summary[priority_summary["priorityMetric"] == "urgency"].copy()
    order = ["low", "medium", "high"]
    fig, axes = plt.subplots(1, 3, figsize=(13.0, 4.2), sharey=True)
    for ax, case in zip(axes, CASE_ORDER):
        g = urgency[urgency["caseName"] == case].set_index("priorityGroup").loc[order].reset_index()
        x = np.arange(len(order))
        ax.bar(x, g["avgArrivalTime"], color=OKABE_ITO["sky"], width=0.62, label="Arrival time")
        ax2 = ax.twinx()
        ax2.plot(x, g["avgNodeDamage"], color=OKABE_ITO["vermillion"], marker="s", linewidth=2, label="Node damage")
        ax.set_xticks(x, ["Low", "Medium", "High"])
        ax.set_title(CASE_LABEL[case])
        ax.set_ylabel("Average arrival time")
        ax2.set_ylabel("Average node damage")
        style_axes(ax)
        ax2.spines["top"].set_visible(False)
    fig.suptitle("Urgency priority: high-urgency nodes are served earlier", fontsize=13, fontweight="bold")
    out = out_dir / "fig_09_priority_urgency.png"
    savefig(fig, out)
    return out


def fmt(x: float, digits: int = 3) -> str:
    return f"{x:.{digits}f}"


def markdown_table(df: pd.DataFrame, columns: list[str], renames: dict[str, str] | None = None, digits: int = 3) -> str:
    data = df[columns].copy()
    if renames:
        data = data.rename(columns=renames)
    for col in data.columns:
        if pd.api.types.is_float_dtype(data[col]):
            data[col] = data[col].map(lambda v: fmt(float(v), digits))
    headers = [str(col) for col in data.columns]
    rows = [[str(value) for value in row] for row in data.to_numpy()]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    lines.extend("| " + " | ".join(row) + " |" for row in rows)
    return "\n".join(lines)


def write_report(
    out_dir: Path,
    paths: dict[str, Path],
    sources: dict[str, Path],
    algorithm_wide: pd.DataFrame,
    model_wide: pd.DataFrame,
    sensitivity_summary: pd.DataFrame,
    vehicle_sum: pd.DataFrame,
    vehicle_marg: pd.DataFrame,
    priority_wide: pd.DataFrame,
) -> Path:
    period = sensitivity_summary[sensitivity_summary["experiment"] == "period_fixed_fleet"].copy()
    inv = sensitivity_summary[sensitivity_summary["experiment"] == "inventory_qp"].copy()

    period_growth_rows = []
    for case in CASE_ORDER:
        g = period[period["caseName"] == case].sort_values("numPeriods")
        first = g.iloc[0]
        last = g.iloc[-1]
        period_growth_rows.append(
            {
                "caseName": case,
                "period2": float(first["avgDamage"]),
                "period5": float(last["avgDamage"]),
                "increaseAbs": float(last["avgDamage"] - first["avgDamage"]),
                "increasePct": (float(last["avgDamage"]) - float(first["avgDamage"])) / float(first["avgDamage"]) * 100.0,
            }
        )
    period_growth = pd.DataFrame(period_growth_rows)

    report = out_dir / "paper_analysis_report.md"
    lines: list[str] = []
    lines.extend(
        [
            "# ESWA Paper Experiment Analysis Report",
            "",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
            "## 1. Executive Findings",
            "",
            "- The revised IHGA produces the lowest average dynamic damage on all C, R, and RC instances.",
            "- The advantage over IMA is stable but moderate; the stronger claim is consistency rather than runtime or overwhelming dominance.",
            "- The period-sensitivity design is now clean: total fleet is fixed at 60 and total supply is kept approximately equal to total demand.",
            "- Inventory sensitivity should be interpreted with per-period Qp as the x-axis. The 0.8 supply factor is a shortage-penalty region, not a normal marginal-effect point.",
            "- Vehicle sensitivity gives the clearest diminishing marginal return evidence across all three instance classes.",
            "- Priority analysis supports the mechanism that high-urgency customers are intentionally served earlier.",
            "",
            "## 2. Data Sources",
            "",
            f"- Algorithm comparison: `{sources['algorithm'].as_posix()}`",
            f"- Revised period/inventory sensitivity: `{sources['sensitivity'].as_posix()}`",
            f"- Model comparison: `{sources['model'].as_posix()}`",
            f"- Priority analysis: `{sources['priority'].as_posix()}`",
            f"- Vehicle sensitivity: `{sources['vehicle'].as_posix()}`",
            "",
            "The raw experimental values were not changed. The vehicle-sensitivity runner metadata was corrected for future runs from `warmstart_v1` to `critical_damage_v2_warmstart`.",
            "",
            "## 3. Algorithm Comparison",
            "",
            f"![Algorithm comparison]({paths['algorithm'].name})",
            "",
            markdown_table(
                algorithm_wide,
                ["caseName", "IHGA", "IMA", "VNS", "improve_vs_IMA_pct", "improve_vs_VNS_pct", "IHGA_std"],
                {
                    "caseName": "Instance",
                    "improve_vs_IMA_pct": "IHGA vs IMA (%)",
                    "improve_vs_VNS_pct": "IHGA vs VNS (%)",
                    "IHGA_std": "IHGA std.",
                },
            ),
            "",
            f"![IHGA improvement]({paths['algorithm_improvement'].name})",
            "",
            "Interpretation: IHGA is consistently better than IMA and VNS across clustered, random, and mixed spatial structures. Compared with IMA, the improvement ranges from 1.31% to 2.30%; compared with VNS, the improvement ranges from 6.78% to 8.32%. This is enough for a defensible paper claim, but the wording should emphasize stable damage reduction instead of large runtime-free dominance.",
            "",
            "## 4. Model Comparison",
            "",
            f"![Model comparison]({paths['model'].name})",
            "",
            markdown_table(
                model_wide,
                ["caseName", "DDVRP-IHGA", "CCVRP", "CVRP", "improve_vs_CCVRP_pct", "improve_vs_CVRP_pct"],
                {
                    "caseName": "Instance",
                    "improve_vs_CCVRP_pct": "DDVRP-IHGA vs CCVRP (%)",
                    "improve_vs_CVRP_pct": "DDVRP-IHGA vs CVRP (%)",
                },
            ),
            "",
            "Interpretation: the dynamic-damage objective is necessary. CVRP and CCVRP can produce shorter travel distances, but they do not optimize deterioration and recovery dynamics, so their dynamic damage is higher. This is one of the strongest model-validity results.",
            "",
            "## 5. Period Sensitivity",
            "",
            f"![Period sensitivity]({paths['period'].name})",
            "",
            markdown_table(
                period[["caseName", "numPeriods", "carNumPerPeriod", "totalVehicles", "QpPerPeriod", "totalSupply", "totalDemand", "avgDamage", "stdDamage"]],
                ["caseName", "numPeriods", "carNumPerPeriod", "totalVehicles", "QpPerPeriod", "totalSupply", "totalDemand", "avgDamage", "stdDamage"],
                {
                    "caseName": "Instance",
                    "numPeriods": "Periods",
                    "carNumPerPeriod": "Cars/period",
                    "totalVehicles": "Total cars",
                    "QpPerPeriod": "Qp/period",
                    "totalSupply": "Total supply",
                    "totalDemand": "Total demand",
                    "avgDamage": "Avg damage",
                    "stdDamage": "Std.",
                },
            ),
            "",
            markdown_table(
                period_growth,
                ["caseName", "period2", "period5", "increaseAbs", "increasePct"],
                {
                    "caseName": "Instance",
                    "period2": "2 periods",
                    "period5": "5 periods",
                    "increaseAbs": "Increase",
                    "increasePct": "Increase (%)",
                },
            ),
            "",
            "Interpretation: when total fleet and total supply are fixed, increasing the number of periods reduces per-period resource availability. The resulting service fragmentation raises total dynamic damage by 6.59% to 9.51% from 2 to 5 periods.",
            "",
            "## 6. Inventory Sensitivity",
            "",
            f"![Inventory feasible region]({paths['inventory_feasible'].name})",
            "",
            f"![Inventory shortage penalty]({paths['inventory_shortage'].name})",
            "",
            markdown_table(
                inv[["caseName", "QpPerPeriod", "totalSupply", "totalDemand", "inventoryFactor", "avgDamage", "stdDamage"]],
                ["caseName", "QpPerPeriod", "totalSupply", "totalDemand", "inventoryFactor", "avgDamage", "stdDamage"],
                {
                    "caseName": "Instance",
                    "QpPerPeriod": "Qp/period",
                    "totalSupply": "Total supply",
                    "totalDemand": "Total demand",
                    "inventoryFactor": "Supply factor",
                    "avgDamage": "Avg objective",
                    "stdDamage": "Std.",
                },
            ),
            "",
            "Interpretation: `Qp/period` is the correct independent variable. The 0.8 factor creates under-supply, so the penalty term dominates the objective and produces million-level values. For publication, plot the feasible region separately and use the shortage point only to show the feasibility threshold.",
            "",
            "## 7. Vehicle Sensitivity",
            "",
            f"![Vehicle sensitivity]({paths['vehicle'].name})",
            "",
            f"![Vehicle marginal returns]({paths['vehicle_marginal'].name})",
            "",
            markdown_table(
                vehicle_sum,
                ["caseName", "carNum", "avgDamage", "bestDamage", "stdDamage", "runs"],
                {
                    "caseName": "Instance",
                    "carNum": "Cars/period",
                    "avgDamage": "Avg damage",
                    "bestDamage": "Best damage",
                    "stdDamage": "Std.",
                    "runs": "Runs",
                },
            ),
            "",
            markdown_table(
                vehicle_marg,
                ["caseName", "fromCar", "toCar", "damageDrop", "dropPctFromStart"],
                {
                    "caseName": "Instance",
                    "fromCar": "From",
                    "toCar": "To",
                    "damageDrop": "Damage drop",
                    "dropPctFromStart": "Drop (%)",
                },
            ),
            "",
            "Interpretation: vehicle increments have large benefits at low fleet sizes and small benefits at high fleet sizes. This directly supports the marginal-effect narrative. The final interval from 30 to 50 cars reduces damage by only 0.51% to 0.75%, depending on instance class.",
            "",
            "## 8. Priority Mechanism",
            "",
            f"![Priority urgency]({paths['priority'].name})",
            "",
            markdown_table(
                priority_wide,
                ["caseName", "arrivalHigh", "arrivalMedium", "arrivalLow", "rankHigh", "rankMedium", "rankLow", "damageHigh", "damageMedium", "damageLow", "highEarlierThanLowPct"],
                {
                    "caseName": "Instance",
                    "arrivalHigh": "Arrival high",
                    "arrivalMedium": "Arrival medium",
                    "arrivalLow": "Arrival low",
                    "rankHigh": "Rank high",
                    "rankMedium": "Rank medium",
                    "rankLow": "Rank low",
                    "damageHigh": "Damage high",
                    "damageMedium": "Damage medium",
                    "damageLow": "Damage low",
                    "highEarlierThanLowPct": "High earlier than low (%)",
                },
            ),
            "",
            "Interpretation: high-urgency nodes are served much earlier than low-urgency nodes. Their node damage remains higher because they are intrinsically more vulnerable, not because the algorithm ignores them.",
            "",
            "## 9. Paper-Writing Recommendations",
            "",
            "- Main algorithm claim: IHGA consistently reduces dynamic damage across C, R, and RC instances.",
            "- Model claim: optimizing distance or capacity alone is insufficient under dynamic deterioration and recovery.",
            "- Sensitivity claim: under fixed total resources, more planning periods increase damage because per-period resources shrink.",
            "- Inventory claim: after the feasibility threshold is met, increasing Qp gives limited marginal improvements.",
            "- Vehicle claim: additional vehicles exhibit clear diminishing marginal returns.",
            "- Avoid discussing runtime unless explicitly required; the current evidence is strongest on solution quality and mechanism validity.",
            "",
            "## 10. Output Files",
            "",
        ]
    )
    for label, path in paths.items():
        lines.append(f"- {label}: `{path.as_posix()}`")
    report.write_text("\n".join(lines), encoding="utf-8")
    return report


def main() -> None:
    apply_paper_style(9.5)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = RESULTS_DIR / f"paper_analysis_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=True)

    algorithm_path = RESULTS_DIR / "algorithm_comparison_paper_20260429_144733_summary.csv"
    sensitivity_path = RESULTS_DIR / "sensitivity_revised_paper_20260429_160237_summary.csv"
    model_path = RESULTS_DIR / "model_comparison_paper_20260430_023922_summary.csv"
    priority_path = RESULTS_DIR / "priority_analysis_paper_20260430_033401_summary.csv"
    vehicle_path = RESULTS_DIR / "vehicle_sensitivity_paper_20260430_033532.csv"

    algorithm_summary = pd.read_csv(algorithm_path)
    sensitivity_summary = pd.read_csv(sensitivity_path)
    model_summary = pd.read_csv(model_path)
    priority_summary = pd.read_csv(priority_path)
    vehicle_raw = pd.read_csv(vehicle_path)

    vehicle_labeled = vehicle_raw.copy()
    if "algorithmVersion" in vehicle_labeled.columns:
        vehicle_labeled["algorithmVersion"] = "critical_damage_v2_warmstart"
    vehicle_labeled_path = out_dir / "vehicle_sensitivity_labeled.csv"
    vehicle_labeled.to_csv(vehicle_labeled_path, index=False, encoding="utf-8-sig")

    alg_wide, alg_long = algorithm_tables(algorithm_summary)
    model_wide = model_table(model_summary)
    veh_sum = vehicle_summary(vehicle_labeled)
    veh_marg = vehicle_marginal(veh_sum)
    prio_wide = priority_urgency(priority_summary)

    alg_wide.to_csv(out_dir / "table_algorithm_improvement.csv", index=False, encoding="utf-8-sig")
    alg_long.to_csv(out_dir / "table_algorithm_long.csv", index=False, encoding="utf-8-sig")
    model_wide.to_csv(out_dir / "table_model_improvement.csv", index=False, encoding="utf-8-sig")
    veh_sum.to_csv(out_dir / "table_vehicle_summary.csv", index=False, encoding="utf-8-sig")
    veh_marg.to_csv(out_dir / "table_vehicle_marginal.csv", index=False, encoding="utf-8-sig")
    prio_wide.to_csv(out_dir / "table_priority_urgency.csv", index=False, encoding="utf-8-sig")

    paths = {
        "algorithm": fig_algorithm_comparison(algorithm_summary, out_dir),
        "algorithm_improvement": fig_algorithm_improvement(alg_wide, out_dir),
        "model": fig_model_comparison(model_summary, out_dir),
        "period": fig_period_sensitivity(sensitivity_summary, out_dir),
    }
    inv_feasible, inv_shortage = fig_inventory_sensitivity(sensitivity_summary, out_dir)
    paths["inventory_feasible"] = inv_feasible
    paths["inventory_shortage"] = inv_shortage
    paths["vehicle"] = fig_vehicle_sensitivity(veh_sum, out_dir)
    paths["vehicle_marginal"] = fig_vehicle_marginal(veh_marg, out_dir)
    paths["priority"] = fig_priority_urgency(priority_summary, out_dir)

    report = write_report(
        out_dir,
        paths,
        {
            "algorithm": algorithm_path,
            "sensitivity": sensitivity_path,
            "model": model_path,
            "priority": priority_path,
            "vehicle": vehicle_path,
        },
        alg_wide,
        model_wide,
        sensitivity_summary,
        veh_sum,
        veh_marg,
        prio_wide,
    )
    print(f"report={report}")
    print(f"output_dir={out_dir}")


if __name__ == "__main__":
    main()
