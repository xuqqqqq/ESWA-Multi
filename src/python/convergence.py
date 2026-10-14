from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from plot_style import CASE_LABELS, OKABE_ITO, apply_paper_style, save_pdf_png, style_axes


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
FIGURES = ROOT / "latex" / "figures"

CASE_ORDER = ["C101-25", "r101-25", "rc101-25"]
CASE_LABEL = CASE_LABELS
ALGORITHM_ORDER = ["VNS", "IMA", "PDR-HGA"]
ALGORITHM_STYLE = {
    "VNS": {"color": OKABE_ITO["vermillion"], "marker": "s", "label": "VNS"},
    "IMA": {"color": OKABE_ITO["orange"], "marker": "o", "label": "IMA"},
    "PDR-HGA": {"color": OKABE_ITO["green"], "marker": "^", "label": "PDR-HGA"},
}
OLD_V2_TRACE = RESULTS / "convergence_trace_paper_lite_20260502_153456.csv"
FROZEN_TRACE = RESULTS / "convergence_old_v2_frozen_authoritative.csv"
FROZEN_TRACE_20RUN = RESULTS / "convergence_old_v2_20run_authoritative.csv"


def latest_trace_file(mode_hint: str | None = None) -> Path:
    if mode_hint is None and FROZEN_TRACE_20RUN.exists():
        return FROZEN_TRACE_20RUN
    if mode_hint is None and FROZEN_TRACE.exists():
        return FROZEN_TRACE
    if mode_hint is None and OLD_V2_TRACE.exists():
        return OLD_V2_TRACE
    files = []
    for path in RESULTS.glob("convergence_trace_*.csv"):
        if path.stem.endswith("_summary"):
            continue
        if mode_hint and mode_hint.lower() not in path.stem.lower():
            continue
        files.append(path)
    if not files:
        raise FileNotFoundError("No convergence_trace_*.csv file found")
    return sorted(files, key=lambda item: item.stat().st_mtime)[-1]


def summarize_trace(data: pd.DataFrame) -> pd.DataFrame:
    run_keys = ["caseName", "algorithm", "seed"]
    has_time_trace = (
        "elapsedSeconds" in data.columns
        and data.groupby(run_keys)["elapsedSeconds"].nunique().min() > 1
    )
    if has_time_trace:
        progress_column = "elapsedSeconds"
    elif "evaluationCount" in data.columns:
        progress_column = "evaluationCount"
    else:
        progress_column = "generation"
    if progress_column == "generation":
        summary = (
            data.groupby(["caseName", "algorithm", progress_column], as_index=False)
            .agg(
                avgBest=("bestFitness", "mean"),
                stdBest=("bestFitness", "std"),
                medianBest=("bestFitness", "median"),
                q25Best=("bestFitness", lambda values: values.quantile(0.25)),
                q75Best=("bestFitness", lambda values: values.quantile(0.75)),
                runs=("bestFitness", "count"),
            )
            .sort_values(["caseName", "algorithm", progress_column])
        )
        return summary.rename(columns={progress_column: "searchProgress"}).fillna({"stdBest": 0.0})

    if progress_column == "elapsedSeconds":
        grouped_time = data.groupby(["caseName", "algorithm", "seed"])[progress_column]
        common_start = int(np.ceil(grouped_time.min().max()))
        common_limit = int(np.floor(grouped_time.max().min()))
        if common_start > common_limit:
            raise ValueError(
                "No common computation-time interval exists across all convergence runs"
            )
        grid = np.arange(common_start, common_limit + 1, 1)
    else:
        grid = np.arange(500, 30001, 500)
    aligned = []
    for (case_name, algorithm, seed), run in data.groupby(["caseName", "algorithm", "seed"]):
        run = run.sort_values(progress_column)
        evaluations = run[progress_column].to_numpy()
        values = run["bestFitness"].to_numpy()
        indices = np.searchsorted(evaluations, grid, side="right") - 1
        indices = np.clip(indices, 0, len(values) - 1)
        aligned.extend(
            (case_name, algorithm, seed, int(evaluation), float(values[index]))
            for evaluation, index in zip(grid, indices)
        )
    aligned_frame = pd.DataFrame(
        aligned, columns=["caseName", "algorithm", "seed", "searchProgress", "bestFitness"]
    )
    return (
        aligned_frame.groupby(["caseName", "algorithm", "searchProgress"], as_index=False)
        .agg(
            avgBest=("bestFitness", "mean"),
            stdBest=("bestFitness", "std"),
            medianBest=("bestFitness", "median"),
            q25Best=("bestFitness", lambda values: values.quantile(0.25)),
            q75Best=("bestFitness", lambda values: values.quantile(0.75)),
            runs=("bestFitness", "count"),
        )
        .fillna({"stdBest": 0.0})
        .sort_values(["caseName", "algorithm", "searchProgress"])
    )


def plot_convergence(summary: pd.DataFrame, x_label: str) -> tuple[Path, Path]:
    apply_paper_style(8.8)
    available_cases = [case for case in CASE_ORDER if case in set(summary["caseName"])]
    if not available_cases:
        available_cases = sorted(summary["caseName"].unique())
    width = 2.75 * len(available_cases)
    fig, axes = plt.subplots(1, len(available_cases), figsize=(width, 2.65), constrained_layout=True, sharey=False)
    if len(available_cases) == 1:
        axes = [axes]

    legend_handles = []
    legend_labels = []
    for ax, case in zip(axes, available_cases):
        case_data = summary[summary["caseName"] == case]
        for algorithm in ALGORITHM_ORDER:
            curve = case_data[case_data["algorithm"] == algorithm].sort_values("searchProgress")
            if curve.empty:
                continue
            style = ALGORITHM_STYLE[algorithm]
            step = max(1, len(curve) // 8)
            markevery = list(range(0, len(curve), step))
            if markevery[-1] != len(curve) - 1:
                markevery.append(len(curve) - 1)
            (line,) = ax.plot(
                curve["searchProgress"],
                curve["medianBest"],
                color=style["color"],
                linewidth=1.45,
                marker=style["marker"],
                markersize=3.7,
                markerfacecolor="white",
                markeredgewidth=0.9,
                markevery=markevery,
                label=style["label"],
            )
            run_count = int(curve["runs"].max())
            if run_count > 1:
                ax.fill_between(
                    curve["searchProgress"].to_numpy(),
                    curve["q25Best"].to_numpy(),
                    curve["q75Best"].to_numpy(),
                    color=style["color"],
                    alpha=0.12,
                    linewidth=0,
                )
            if style["label"] not in legend_labels:
                legend_handles.append(line)
                legend_labels.append(style["label"])
        ax.set_title(CASE_LABEL.get(case, case))
        ax.set_xlabel(x_label)
        style_axes(ax)

    axes[0].set_ylabel("Median best damage")
    axes[-1].legend(legend_handles, legend_labels, loc="upper right", fontsize=7.4, frameon=True)

    pdf_out = FIGURES / "convergence_trace_eswa.pdf"
    png_out = FIGURES / "convergence_trace_eswa.png"
    save_pdf_png(fig, pdf_out, png_out)
    return pdf_out, png_out


def main() -> None:
    trace_path = latest_trace_file()
    data = pd.read_csv(trace_path)
    data["algorithm"] = data["algorithm"].replace({"IHGA": "PDR-HGA"})
    has_time_trace = (
        "elapsedSeconds" in data.columns
        and data.groupby(["caseName", "algorithm", "seed"])["elapsedSeconds"].nunique().min() > 1
    )
    if has_time_trace:
        x_label = "Computation time (s)"
    elif "evaluationCount" in data.columns:
        x_label = "Objective evaluations"
    else:
        x_label = "Generation"
    summary = summarize_trace(data)
    summary_path = RESULTS / "convergence_trace_manuscript_summary.csv"
    summary.to_csv(summary_path, index=False, encoding="utf-8-sig")
    pdf_path, png_path = plot_convergence(summary, x_label)
    print(f"source={trace_path}")
    print(f"summary={summary_path}")
    print(f"convergence_pdf={pdf_path}")
    print(f"convergence_png={png_path}")


if __name__ == "__main__":
    main()
