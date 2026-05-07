from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


def latest_csv(results_dir: Path) -> Path:
    files = sorted(results_dir.glob("vehicle_sensitivity_*.csv"), key=lambda p: p.stat().st_mtime)
    if not files:
        raise FileNotFoundError(f"No vehicle_sensitivity_*.csv files found in {results_dir}")
    return files[-1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=None)
    parser.add_argument("--results-dir", type=Path, default=Path("results"))
    parser.add_argument("--metric", default="bestFitness", choices=["bestFitness", "nodeDamage", "roadDamage"])
    args = parser.parse_args()

    input_file = args.input or latest_csv(args.results_dir)
    df = pd.read_csv(input_file)
    if "algorithmVersion" not in df.columns:
        df["algorithmVersion"] = "legacy"
    summary = (
        df.groupby(["caseName", "carNum"], as_index=False)
        .agg(
            algorithmVersion=("algorithmVersion", "first"),
            avg=(args.metric, "mean"),
            best=(args.metric, "min"),
            std=(args.metric, "std"),
            runs=(args.metric, "count"),
            Qp=("Qp", "first"),
        )
        .sort_values(["caseName", "carNum"])
    )
    summary["std"] = summary["std"].fillna(0.0)

    out_summary = input_file.with_name(input_file.stem + "_summary.csv")
    summary.to_csv(out_summary, index=False, encoding="utf-8-sig")

    cases = list(summary["caseName"].unique())
    fig, axes = plt.subplots(len(cases), 1, figsize=(10, 4 * len(cases)), squeeze=False)
    for ax, case in zip(axes[:, 0], cases):
        part = summary[summary["caseName"] == case]
        ax.errorbar(part["carNum"], part["avg"], yerr=part["std"], fmt="o--", color="#d62728", capsize=4, label="Average")
        ax.plot(part["carNum"], part["best"], "o-", color="#1f4fff", label="Best")
        best_row = part.loc[part["avg"].idxmin()]
        ax.scatter([best_row["carNum"]], [best_row["avg"]], s=90, color="#111111", zorder=5)
        ax.set_title(f"{case} vehicle sensitivity (Qp={best_row['Qp']})")
        ax.set_xlabel("Number of Vehicles")
        ax.set_ylabel(args.metric)
        ax.grid(True, linestyle="--", alpha=0.45)
        ax.legend()

    fig.tight_layout()
    out_png = input_file.with_name(input_file.stem + f"_{args.metric}.png")
    fig.savefig(out_png, dpi=180)
    print(f"input={input_file}")
    print(f"summary={out_summary}")
    print(f"plot={out_png}")


if __name__ == "__main__":
    main()
