from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


def main() -> None:
    results_dir = Path("results")
    files = sorted(results_dir.glob("vehicle_sensitivity_quick_*.csv"))
    files = [p for p in files if not p.name.endswith("_summary.csv")]
    if not files:
        raise FileNotFoundError("No quick CSV files found")

    frames = []
    for path in files:
        df = pd.read_csv(path)
        if "algorithmVersion" not in df.columns:
            df["algorithmVersion"] = "legacy"
        else:
            df["algorithmVersion"] = df["algorithmVersion"].fillna("legacy").astype(str)
        df["sourceFile"] = path.name
        frames.append(df)
    data = pd.concat(frames, ignore_index=True)
    versions = sorted(v for v in data["algorithmVersion"].unique() if v != "legacy")
    selected_version = versions[-1] if versions else "legacy"
    data = data[data["algorithmVersion"] == selected_version].copy()
    if {"caseName", "carNum", "seed"}.issubset(data.columns):
        data = data.drop_duplicates(subset=["caseName", "carNum", "seed"], keep="last")

    aggregations = {
        "algorithmVersion": ("algorithmVersion", "first"),
        "avg": ("bestFitness", "mean"),
        "best": ("bestFitness", "min"),
        "std": ("bestFitness", "std"),
        "runs": ("bestFitness", "count"),
        "Qp": ("Qp", "first"),
    }
    optional_columns = [
        "nonEmptyRoutes",
        "maxRouteLength",
        "avgRouteLength",
        "avgArrivalTime",
        "maxArrivalTime",
    ]
    for column in optional_columns:
        if column in data.columns:
            aggregations[column] = (column, "mean")

    summary = (
        data.groupby(["caseName", "carNum"], as_index=False)
        .agg(**aggregations)
        .sort_values(["caseName", "carNum"])
    )
    summary["std"] = summary["std"].fillna(0.0)

    out_csv = results_dir / "vehicle_sensitivity_quick_aggregate_summary.csv"
    summary.to_csv(out_csv, index=False, encoding="utf-8-sig")

    cases = list(summary["caseName"].unique())
    fig, axes = plt.subplots(len(cases), 1, figsize=(10, 4 * len(cases)), squeeze=False)
    for ax, case in zip(axes[:, 0], cases):
        part = summary[summary["caseName"] == case]
        ax.errorbar(part["carNum"], part["avg"], yerr=part["std"], fmt="o--", capsize=4, label="Average")
        ax.plot(part["carNum"], part["best"], "o-", label="Best")
        ax.set_title(f"{case} aggregate quick runs")
        ax.set_xlabel("Number of Vehicles")
        ax.set_ylabel("bestFitness")
        ax.grid(True, linestyle="--", alpha=0.45)
        ax.legend()
    fig.tight_layout()

    out_png = results_dir / "vehicle_sensitivity_quick_aggregate.png"
    fig.savefig(out_png, dpi=180)

    print(f"files={len(files)}")
    print(f"algorithmVersion={selected_version}")
    print(f"summary={out_csv}")
    print(f"plot={out_png}")


if __name__ == "__main__":
    main()
