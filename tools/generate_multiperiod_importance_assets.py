from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from plot_style import CASE_COLORS, CASE_MARKERS, OKABE_ITO, apply_paper_style, save_pdf_png, style_axes


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
FIGURES = ROOT / "latex" / "figures"

CASE_ORDER = ["C101-25", "r101-25", "rc101-25"]
CASE_LABEL = {
    "C101-25": "C101-25",
    "r101-25": "R101-25",
    "rc101-25": "RC101-25",
}
def load_combined() -> pd.DataFrame:
    period_summary = pd.read_csv(RESULTS / "sensitivity_revised_paper_20260429_160237_summary.csv")
    period_summary = period_summary[period_summary["experiment"] == "period_fixed_fleet"].copy()
    period_summary["scenario"] = "staged"

    single = pd.read_csv(RESULTS / "multiperiod_importance_paper_single_period_summary.csv")
    single = single.copy()
    single["scenario"] = "optimistic aggregate"
    single["QpPerPeriod"] = single["QpProfile"].astype(int)
    single["inventoryFactor"] = 1.0

    keep = [
        "scenario",
        "caseName",
        "numPeriods",
        "carNumPerPeriod",
        "totalVehicles",
        "QpPerPeriod",
        "totalSupply",
        "totalDemand",
        "avgDamage",
        "bestDamage",
        "stdDamage",
        "runs",
    ]
    combined = pd.concat([single[keep], period_summary[keep]], ignore_index=True)
    combined = combined.sort_values(["caseName", "numPeriods"]).reset_index(drop=True)

    baseline = combined[combined["numPeriods"] == 1].set_index("caseName")["avgDamage"]
    combined["increaseVsAggregatePct"] = combined.apply(
        lambda row: (row["avgDamage"] / baseline.loc[row["caseName"]] - 1.0) * 100.0,
        axis=1,
    )
    return combined


def save_combined_summary(combined: pd.DataFrame) -> Path:
    out = RESULTS / "multiperiod_importance_period_combined_summary.csv"
    combined.to_csv(out, index=False)
    return out


def plot_period_importance(combined: pd.DataFrame) -> tuple[Path, Path]:
    apply_paper_style(9.2)

    fig, axes = plt.subplots(1, 2, figsize=(8.4, 3.45), constrained_layout=True)
    ax0, ax1 = axes

    for ax in axes:
        ax.axvspan(0.85, 1.15, color=OKABE_ITO["panel"], zorder=0)
        ax.set_xlim(0.8, 5.2)
        ax.set_xticks([1, 2, 3, 4, 5])
        style_axes(ax)

    for case in CASE_ORDER:
        g = combined[combined["caseName"] == case].sort_values("numPeriods")
        ax0.errorbar(
            g["numPeriods"],
            g["avgDamage"],
            yerr=g["stdDamage"],
            marker=CASE_MARKERS[case],
            markersize=4.8,
            markerfacecolor="white",
            markeredgewidth=1.0,
            color=CASE_COLORS[case],
            linewidth=1.55,
            capsize=2.5,
            label=CASE_LABEL[case],
        )
        ax1.plot(
            g["numPeriods"],
            g["increaseVsAggregatePct"],
            marker=CASE_MARKERS[case],
            markersize=4.8,
            markerfacecolor="white",
            markeredgewidth=1.0,
            color=CASE_COLORS[case],
            linewidth=1.55,
            label=CASE_LABEL[case],
        )

    ax0.set_title("(a) Total dynamic damage")
    ax0.set_xlabel("Number of dispatch periods")
    ax0.set_ylabel("Average damage")
    ax0.legend(frameon=False, loc="upper left")

    ax1.set_title("(b) Increase over aggregate baseline")
    ax1.set_xlabel("Number of dispatch periods")
    ax1.set_ylabel("Increase (%)")
    ax1.axhline(0, color=OKABE_ITO["black"], linewidth=0.8)

    pdf_out = FIGURES / "period_sensitivity_eswa.pdf"
    png_out = FIGURES / "period_sensitivity_eswa.png"
    save_pdf_png(fig, pdf_out, png_out)
    return pdf_out, png_out


def write_latex_rows(combined: pd.DataFrame) -> Path:
    out = ROOT / "latex" / "generated_period_sensitivity_rows.tex"
    lines = []
    for case in CASE_ORDER:
        g = combined[combined["caseName"] == case].sort_values("numPeriods")
        for _, row in g.iterrows():
            scenario = "Aggregate" if row["numPeriods"] == 1 else "Staged"
            lines.append(
                f"{row['caseName']} & {int(row['numPeriods'])} & {scenario} & "
                f"{int(row['carNumPerPeriod'])} & {int(row['totalVehicles'])} & "
                f"{int(row['QpPerPeriod'])} & {int(row['totalSupply'])} & "
                f"{int(row['totalDemand'])} & {row['avgDamage']:.3f} & "
                f"{row['increaseVsAggregatePct']:.2f}\\% \\\\"
            )
        if case != CASE_ORDER[-1]:
            lines.append(r"\midrule")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def main() -> None:
    combined = load_combined()
    summary_path = save_combined_summary(combined)
    pdf_path, png_path = plot_period_importance(combined)
    rows_path = write_latex_rows(combined)
    print(f"Saved {summary_path}")
    print(f"Saved {pdf_path}")
    print(f"Saved {png_path}")
    print(f"Saved {rows_path}")
    print(combined.to_string(index=False))


if __name__ == "__main__":
    main()
