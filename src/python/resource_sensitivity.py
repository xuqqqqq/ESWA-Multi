from __future__ import annotations

import math
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from plot_style import (
    CASE_COLORS,
    CASE_LABELS,
    CASE_MARKERS,
    OKABE_ITO,
    apply_paper_style,
    save_pdf_png,
    style_axes,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
RESULTS = ROOT / "results"
LATEX = ROOT / "latex"
FIGURES = LATEX / "figures"
FILES = [
    SOURCE_DIR / "controlled_resources_old_v2_C.csv",
    SOURCE_DIR / "controlled_resources_old_v2_R.csv",
    SOURCE_DIR / "controlled_resources_old_v2_RC.csv",
]
CASES = ["C101-25", "r101-25", "rc101-25"]
LABELS = CASE_LABELS
PROFILE_LABELS = {
    "front_loaded": "Front-loaded",
    "uniform": "Uniform",
    "back_loaded": "Back-loaded",
}


def load() -> pd.DataFrame:
    frames = [pd.read_csv(path) for path in FILES]
    data = pd.concat(frames, ignore_index=True)
    if not (data["totalSupply"].astype(int) == data["totalDemand"].astype(int)).all():
        raise ValueError("Total supply is not held exactly equal to total demand.")
    if set(data["totalDispatchSlots"].astype(int)) != {60}:
        raise ValueError("Total dispatch slots are not fixed at 60.")
    horizon = data["numPeriods"].astype(float) * data["Tshift"].astype(float)
    if not ((horizon - 1440.0).abs() < 1e-9).all():
        raise ValueError("The final horizon is not fixed at 1440.")
    expected = {"period_count": 25, "release_profile": 15}
    for case in CASES:
        part = data[data["caseName"].eq(case)]
        for experiment, count in expected.items():
            actual = len(part[part["experiment"].eq(experiment)])
            if actual != count:
                raise ValueError(f"{case}/{experiment}: expected {count}, got {actual}")
    return data


def summarize(data: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    period = data[data["experiment"].eq("period_count")].copy()
    period_summary = (
        period.groupby(
            ["caseName", "setting", "numPeriods", "carNumPerPeriod", "QpProfile", "totalSupply"],
            as_index=False,
        )
        .agg(meanLoss=("bestFitness", "mean"), stdLoss=("bestFitness", "std"), runs=("bestFitness", "count"))
        .sort_values(["caseName", "numPeriods"])
    )
    # Student's t critical value for the five-run paper profile (df=4).
    period_summary["ci95"] = 2.776 * period_summary["stdLoss"] / period_summary["runs"].map(math.sqrt)
    baseline = period_summary[period_summary["numPeriods"].eq(1)].set_index("caseName")["meanLoss"]
    period_summary["increaseVsP1Pct"] = period_summary.apply(
        lambda row: 100 * (row["meanLoss"] / baseline.loc[row["caseName"]] - 1), axis=1
    )

    release = data[data["experiment"].eq("release_profile")].copy()
    release_summary = (
        release.groupby(["caseName", "setting", "QpProfile", "totalSupply"], as_index=False)
        .agg(meanLoss=("bestFitness", "mean"), stdLoss=("bestFitness", "std"), runs=("bestFitness", "count"))
    )
    release_summary["ci95"] = 2.776 * release_summary["stdLoss"] / release_summary["runs"].map(math.sqrt)
    front = release_summary[release_summary["setting"].eq("front_loaded")].set_index("caseName")["meanLoss"]
    release_summary["increaseVsFrontPct"] = release_summary.apply(
        lambda row: 100 * (row["meanLoss"] / front.loc[row["caseName"]] - 1), axis=1
    )
    order = {"front_loaded": 0, "uniform": 1, "back_loaded": 2}
    release_summary["order"] = release_summary["setting"].map(order)
    release_summary = release_summary.sort_values(["caseName", "order"]).drop(columns="order")
    return period_summary, release_summary


def write_rows(period: pd.DataFrame, release: pd.DataFrame) -> None:
    lines = []
    for case in CASES:
        part = period[period["caseName"].eq(case)].sort_values("numPeriods")
        for _, row in part.iterrows():
            resource = "Aggregate" if int(row["numPeriods"]) == 1 else "Staged"
            lines.append(
                f"{LABELS[case]} & {int(row['numPeriods'])} & {resource} & "
                f"{int(row['carNumPerPeriod'])} & {str(row['QpProfile']).replace('|', '/')} & "
                f"{row['meanLoss']:.3f} & {row['increaseVsP1Pct']:.2f}\\% \\\\"
            )
        if case != CASES[-1]:
            lines.append(r"\midrule")
    lines.append(r"\bottomrule")
    (LATEX / "generated_controlled_period_rows.tex").write_text("\n".join(lines) + "\n", encoding="utf-8")

    lines = []
    for case in CASES:
        part = release[release["caseName"].eq(case)]
        for _, row in part.iterrows():
            lines.append(
                f"{LABELS[case]} & {PROFILE_LABELS[row['setting']]} & "
                f"{str(row['QpProfile']).replace('|', '/')} & {int(row['totalSupply'])} & "
                f"{row['meanLoss']:.3f} & {row['increaseVsFrontPct']:.2f}\\% \\\\"
            )
        if case != CASES[-1]:
            lines.append(r"\midrule")
    lines.append(r"\bottomrule")
    (LATEX / "generated_controlled_release_rows.tex").write_text("\n".join(lines) + "\n", encoding="utf-8")


def plot_period(period: pd.DataFrame) -> None:
    apply_paper_style(9.2)
    fig, axes = plt.subplots(1, 2, figsize=(8.4, 3.45), constrained_layout=True)
    for ax in axes:
        ax.set_xticks([1, 2, 3, 4, 5])
        style_axes(ax)
    for case in CASES:
        part = period[period["caseName"].eq(case)].sort_values("numPeriods")
        x = part["numPeriods"].to_numpy(dtype=float)
        mean = part["meanLoss"].to_numpy(dtype=float)
        ci = part["ci95"].to_numpy(dtype=float)
        axes[0].plot(x, mean, marker=CASE_MARKERS[case], color=CASE_COLORS[case], label=LABELS[case])
        axes[0].fill_between(x, mean - ci, mean + ci, color=CASE_COLORS[case], alpha=0.14, linewidth=0)
        axes[1].plot(
            x,
            part["increaseVsP1Pct"],
            marker=CASE_MARKERS[case],
            color=CASE_COLORS[case],
            label=LABELS[case],
        )
    axes[0].set_title("(a) Total affected-node loss")
    axes[0].set_xlabel("Number of dispatch periods")
    axes[0].set_ylabel("Mean total loss")
    axes[0].legend(loc="upper left")
    axes[1].set_title("(b) Increase over aggregate baseline")
    axes[1].set_xlabel("Number of dispatch periods")
    axes[1].set_ylabel("Increase (%)")
    axes[1].axhline(0, color=OKABE_ITO["black"], linewidth=0.8)
    save_pdf_png(
        fig,
        FIGURES / "period_sensitivity_eswa.pdf",
        FIGURES / "period_sensitivity_eswa.png",
    )


def main() -> None:
    data = load()
    period, release = summarize(data)
    data.to_csv(RESULTS / "controlled_resources_old_v2_authoritative.csv", index=False, encoding="utf-8-sig")
    period.to_csv(RESULTS / "controlled_period_old_v2_summary.csv", index=False, encoding="utf-8-sig")
    release.to_csv(RESULTS / "controlled_release_old_v2_summary.csv", index=False, encoding="utf-8-sig")
    write_rows(period, release)
    plot_period(period)
    print(period.to_string(index=False))
    print(release.to_string(index=False))


if __name__ == "__main__":
    main()
