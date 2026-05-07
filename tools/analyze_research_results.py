from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


def latest(results_dir: Path, pattern: str) -> Path | None:
    files = sorted(results_dir.glob(pattern), key=lambda p: p.stat().st_mtime)
    return files[-1] if files else None


def save_algorithm_summary(path: Path) -> list[Path]:
    df = pd.read_csv(path)
    summary = (
        df.groupby(["mode", "caseName", "carNum", "algorithm"], as_index=False)
        .agg(
            avgDamage=("bestFitness", "mean"),
            bestDamage=("bestFitness", "min"),
            stdDamage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
            avgElapsed=("elapsedSeconds", "mean"),
        )
        .sort_values(["caseName", "carNum", "avgDamage"])
    )
    summary["stdDamage"] = summary["stdDamage"].fillna(0.0)
    out_csv = path.with_name(path.stem + "_summary.csv")
    summary.to_csv(out_csv, index=False, encoding="utf-8-sig")

    cases = list(summary["caseName"].unique())
    fig, axes = plt.subplots(1, len(cases), figsize=(5 * len(cases), 4), squeeze=False)
    for ax, case in zip(axes[0], cases):
        part = summary[summary["caseName"] == case].copy()
        labels = part["algorithm"].tolist()
        ax.bar(labels, part["avgDamage"], yerr=part["stdDamage"], color=["#3b82f6", "#f97316", "#16a34a"][: len(part)])
        ax.set_title(f"{case}: algorithm comparison")
        ax.set_ylabel("Total damage")
        ax.grid(axis="y", linestyle="--", alpha=0.35)
    fig.tight_layout()
    out_png = path.with_name(path.stem + "_summary.png")
    fig.savefig(out_png, dpi=180)
    plt.close(fig)
    return [out_csv, out_png]


def save_sensitivity_summary(path: Path) -> list[Path]:
    df = pd.read_csv(path)
    summary = (
        df.groupby(["mode", "experiment", "caseName", "level", "factor"], as_index=False)
        .agg(
            avgDamage=("bestFitness", "mean"),
            bestDamage=("bestFitness", "min"),
            stdDamage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
        )
        .sort_values(["experiment", "caseName", "level"])
    )
    summary["stdDamage"] = summary["stdDamage"].fillna(0.0)
    out_csv = path.with_name(path.stem + "_summary.csv")
    summary.to_csv(out_csv, index=False, encoding="utf-8-sig")

    experiments = list(summary["experiment"].unique())
    fig, axes = plt.subplots(1, len(experiments), figsize=(6 * len(experiments), 4), squeeze=False)
    for ax, experiment in zip(axes[0], experiments):
        part = summary[summary["experiment"] == experiment]
        for case, case_part in part.groupby("caseName"):
            ax.errorbar(case_part["level"], case_part["avgDamage"], yerr=case_part["stdDamage"], marker="o", label=case)
        ax.set_title(experiment.replace("_", " "))
        ax.set_xlabel("Level")
        ax.set_ylabel("Total damage")
        ax.grid(True, linestyle="--", alpha=0.35)
        ax.legend()
    fig.tight_layout()
    out_png = path.with_name(path.stem + "_summary.png")
    fig.savefig(out_png, dpi=180)
    plt.close(fig)
    return [out_csv, out_png]


def save_revised_sensitivity_summary(path: Path) -> list[Path]:
    df = pd.read_csv(path)
    group_cols = [
        "mode",
        "experiment",
        "caseName",
        "numPeriods",
        "carNumPerPeriod",
        "totalVehicles",
        "QpPerPeriod",
        "totalSupply",
        "totalDemand",
        "inventoryFactor",
    ]
    summary = (
        df.groupby(group_cols, as_index=False)
        .agg(
            avgDamage=("bestFitness", "mean"),
            bestDamage=("bestFitness", "min"),
            stdDamage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
        )
        .sort_values(["experiment", "caseName", "numPeriods", "QpPerPeriod"])
    )
    summary["stdDamage"] = summary["stdDamage"].fillna(0.0)
    out_csv = path.with_name(path.stem + "_summary.csv")
    summary.to_csv(out_csv, index=False, encoding="utf-8-sig")

    experiments = list(summary["experiment"].unique())
    fig, axes = plt.subplots(1, len(experiments), figsize=(6 * len(experiments), 4), squeeze=False)
    for ax, experiment in zip(axes[0], experiments):
        part = summary[summary["experiment"] == experiment]
        x_col = "numPeriods" if experiment == "period_fixed_fleet" else "QpPerPeriod"
        for case, case_part in part.groupby("caseName"):
            ax.errorbar(case_part[x_col], case_part["avgDamage"], yerr=case_part["stdDamage"], marker="o", label=case)
        ax.set_title(experiment.replace("_", " "))
        ax.set_xlabel("Planning periods" if x_col == "numPeriods" else "Per-period inventory Qp")
        ax.set_ylabel("Total damage")
        ax.grid(True, linestyle="--", alpha=0.35)
        ax.legend()
    fig.tight_layout()
    out_png = path.with_name(path.stem + "_summary.png")
    fig.savefig(out_png, dpi=180)
    plt.close(fig)
    return [out_csv, out_png]


def save_priority_summary(path: Path) -> list[Path]:
    df = pd.read_csv(path)
    summary = (
        df.groupby(["mode", "caseName", "priorityMetric", "priorityGroup"], as_index=False)
        .agg(
            avgPriorityValue=("avgPriorityValue", "mean"),
            avgArrivalTime=("avgArrivalTime", "mean"),
            avgNodeDamage=("avgNodeDamage", "mean"),
            avgServiceRank=("avgServiceRank", "mean"),
            runs=("bestFitness", "count"),
        )
        .sort_values(["caseName", "priorityMetric", "priorityGroup"])
    )
    out_csv = path.with_name(path.stem + "_summary.csv")
    summary.to_csv(out_csv, index=False, encoding="utf-8-sig")

    plot_df = summary[summary["priorityMetric"] == "urgency"].copy()
    if plot_df.empty:
        plot_df = summary.copy()
    cases = list(plot_df["caseName"].unique())
    fig, axes = plt.subplots(1, len(cases), figsize=(5 * len(cases), 4), squeeze=False)
    order = ["low", "medium", "high"]
    for ax, case in zip(axes[0], cases):
        part = plot_df[plot_df["caseName"] == case].set_index("priorityGroup").reindex(order).reset_index()
        ax.plot(part["priorityGroup"], part["avgArrivalTime"], marker="o", label="Arrival time")
        ax2 = ax.twinx()
        ax2.plot(part["priorityGroup"], part["avgNodeDamage"], marker="s", color="#dc2626", label="Node damage")
        ax.set_title(f"{case}: urgency priority")
        ax.set_ylabel("Avg arrival time")
        ax2.set_ylabel("Avg node damage")
        ax.grid(True, linestyle="--", alpha=0.35)
    fig.tight_layout()
    out_png = path.with_name(path.stem + "_summary.png")
    fig.savefig(out_png, dpi=180)
    plt.close(fig)
    return [out_csv, out_png]


def save_model_summary(path: Path) -> list[Path]:
    df = pd.read_csv(path)
    summary = (
        df.groupby(["mode", "caseName", "modelName"], as_index=False)
        .agg(
            avgDynamicDamage=("dynamicDamageObjective", "mean"),
            bestDynamicDamage=("dynamicDamageObjective", "min"),
            stdDynamicDamage=("dynamicDamageObjective", "std"),
            avgDistance=("totalDistance", "mean"),
            avgCompletionTime=("totalCompletionTime", "mean"),
            runs=("dynamicDamageObjective", "count"),
        )
        .sort_values(["caseName", "avgDynamicDamage"])
    )
    summary["stdDynamicDamage"] = summary["stdDynamicDamage"].fillna(0.0)
    out_csv = path.with_name(path.stem + "_summary.csv")
    summary.to_csv(out_csv, index=False, encoding="utf-8-sig")

    cases = list(summary["caseName"].unique())
    fig, axes = plt.subplots(1, len(cases), figsize=(5 * len(cases), 4), squeeze=False)
    for ax, case in zip(axes[0], cases):
        part = summary[summary["caseName"] == case]
        ax.bar(part["modelName"], part["avgDynamicDamage"], yerr=part["stdDynamicDamage"], color="#0f766e")
        ax.set_title(f"{case}: model comparison")
        ax.set_ylabel("Dynamic damage")
        ax.tick_params(axis="x", rotation=20)
        ax.grid(axis="y", linestyle="--", alpha=0.35)
    fig.tight_layout()
    out_png = path.with_name(path.stem + "_summary.png")
    fig.savefig(out_png, dpi=180)
    plt.close(fig)
    return [out_csv, out_png]


def write_prompt_file(results_dir: Path, generated: list[Path]) -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = results_dir / f"figure_prompts_{stamp}.md"
    lines = [
        "# Figure Prompts",
        "",
        "Use the generated CSV summaries as exact data sources. Redraw the figures in a clean ESWA-style academic format.",
        "",
        "## Algorithm Comparison",
        "Create a three-panel grouped bar chart for C101-25, R101-25, and RC101-25. X-axis: VNS, IMA, IHGA. Y-axis: total dynamic damage. Use error bars for standard deviation and annotate the percentage improvement of IHGA over the best baseline.",
        "",
        "## Period and Inventory Sensitivity",
        "Create a two-panel line chart. Panel A: number of planning periods versus total damage. Panel B: inventory supply factor versus total damage. Use separate lines for C, R, and RC instance classes, with markers and 95% confidence bands if repetitions are available.",
        "",
        "## Model Comparison",
        "Create a grouped bar chart comparing CVRP, CCVRP, and DDVRP-IHGA by dynamic damage. Add secondary callouts for total distance and total completion time to show why distance-optimal or time-optimal routes are not necessarily damage-optimal.",
        "",
        "## Priority Analysis",
        "Create a compact two-axis chart showing low, medium, and high urgency groups. Show that high-urgency nodes should be served earlier and report their node damage. Use a calm scientific palette, not decorative gradients.",
        "",
        "Generated files:",
    ]
    lines.extend(f"- {path}" for path in generated)
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results-dir", type=Path, default=Path("results"))
    args = parser.parse_args()

    results_dir = args.results_dir
    generated: list[Path] = []
    jobs = [
        ("algorithm_comparison_*.csv", save_algorithm_summary),
        ("sensitivity_revised_*.csv", save_revised_sensitivity_summary),
        ("sensitivity_period_inventory_*.csv", save_sensitivity_summary),
        ("priority_analysis_*.csv", save_priority_summary),
        ("model_comparison_*.csv", save_model_summary),
    ]
    for pattern, fn in jobs:
        candidates = sorted(
            [p for p in results_dir.glob(pattern) if not p.stem.endswith("_summary")],
            key=lambda p: p.stat().st_mtime,
        )
        if not candidates:
            continue
        path = candidates[-1]
        generated.extend(fn(path))
        print(f"analyzed={path}")

    if generated:
        prompt_file = write_prompt_file(results_dir, generated)
        generated.append(prompt_file)
        print(f"prompt_file={prompt_file}")
    else:
        print("No research result files found.")


if __name__ == "__main__":
    main()
