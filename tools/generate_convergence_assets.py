from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from plot_style import OKABE_ITO, apply_paper_style, save_pdf_png, style_axes


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
FIGURES = ROOT / "latex" / "figures"

CASE_ORDER = ["C101-25", "r101-25", "rc101-25"]
CASE_LABEL = {"C101-25": "C101-25", "r101-25": "R101-25", "rc101-25": "RC101-25"}
ALGORITHM_ORDER = ["VNS", "IMA", "IHGA"]
ALGORITHM_STYLE = {
    "VNS": {"color": OKABE_ITO["vermillion"], "marker": "s", "label": "Omega-VNS"},
    "IMA": {"color": OKABE_ITO["orange"], "marker": "o", "label": "ESWA-IMA"},
    "IHGA": {"color": OKABE_ITO["green"], "marker": "^", "label": "IHGA"},
}


def latest_trace_file(mode_hint: str | None = None) -> Path:
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
    summary = (
        data.groupby(["caseName", "algorithm", "generation"], as_index=False)
        .agg(avgBest=("bestFitness", "mean"), stdBest=("bestFitness", "std"), runs=("bestFitness", "count"))
        .sort_values(["caseName", "algorithm", "generation"])
    )
    summary["stdBest"] = summary["stdBest"].fillna(0.0)
    return summary


def plot_convergence(summary: pd.DataFrame) -> tuple[Path, Path]:
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
            curve = case_data[case_data["algorithm"] == algorithm].sort_values("generation")
            if curve.empty:
                continue
            style = ALGORITHM_STYLE[algorithm]
            step = max(1, len(curve) // 8)
            markevery = list(range(0, len(curve), step))
            if markevery[-1] != len(curve) - 1:
                markevery.append(len(curve) - 1)
            (line,) = ax.plot(
                curve["generation"],
                curve["avgBest"],
                color=style["color"],
                linewidth=1.45,
                marker=style["marker"],
                markersize=3.7,
                markerfacecolor="white",
                markeredgewidth=0.9,
                markevery=markevery,
                label=style["label"],
            )
            if style["label"] not in legend_labels:
                legend_handles.append(line)
                legend_labels.append(style["label"])
        ax.set_title(CASE_LABEL.get(case, case))
        ax.set_xlabel("Generation")
        style_axes(ax)

    axes[0].set_ylabel("Best damage")
    axes[-1].legend(legend_handles, legend_labels, loc="upper right", fontsize=7.4, frameon=True)

    pdf_out = FIGURES / "convergence_trace_eswa.pdf"
    png_out = FIGURES / "convergence_trace_eswa.png"
    save_pdf_png(fig, pdf_out, png_out)
    return pdf_out, png_out


def main() -> None:
    trace_path = latest_trace_file()
    data = pd.read_csv(trace_path)
    summary = summarize_trace(data)
    summary_path = RESULTS / "convergence_trace_manuscript_summary.csv"
    summary.to_csv(summary_path, index=False, encoding="utf-8-sig")
    pdf_path, png_path = plot_convergence(summary)
    print(f"source={trace_path}")
    print(f"summary={summary_path}")
    print(f"convergence_pdf={pdf_path}")
    print(f"convergence_png={png_path}")


if __name__ == "__main__":
    main()
