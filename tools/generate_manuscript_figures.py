from __future__ import annotations

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


def latest_vehicle_file() -> Path:
    files = sorted(
        [
            path
            for path in RESULTS.glob("vehicle_sensitivity_paper_*.csv")
            if not path.stem.endswith("_summary")
        ],
        key=lambda path: path.stat().st_mtime,
    )
    if not files:
        raise FileNotFoundError("No vehicle_sensitivity_paper_*.csv file found")
    return files[-1]


def vehicle_summary(path: Path) -> pd.DataFrame:
    data = pd.read_csv(path)
    summary = (
        data.groupby(["caseName", "carNum"], as_index=False)
        .agg(
            avgDamage=("bestFitness", "mean"),
            bestDamage=("bestFitness", "min"),
            stdDamage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
        )
        .sort_values(["caseName", "carNum"])
    )
    summary["stdDamage"] = summary["stdDamage"].fillna(0.0)
    return summary


def vehicle_marginal(summary: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for case in CASE_ORDER:
        g = summary[summary["caseName"] == case].sort_values("carNum").reset_index(drop=True)
        for idx in range(1, len(g)):
            prev = g.iloc[idx - 1]
            cur = g.iloc[idx]
            rows.append(
                {
                    "caseName": case,
                    "fromCar": int(prev["carNum"]),
                    "toCar": int(cur["carNum"]),
                    "damageDrop": float(prev["avgDamage"] - cur["avgDamage"]),
                }
            )
    return pd.DataFrame(rows)


def plot_vehicle_sensitivity(summary: pd.DataFrame, marginal: pd.DataFrame) -> tuple[Path, Path]:
    apply_paper_style(9.2)
    fig, axes = plt.subplots(1, 2, figsize=(7.9, 3.15), constrained_layout=True)
    ax0, ax1 = axes

    for case in CASE_ORDER:
        g = summary[summary["caseName"] == case].sort_values("carNum")
        ax0.errorbar(
            g["carNum"],
            g["avgDamage"],
            yerr=g["stdDamage"],
            marker=CASE_MARKERS[case],
            markersize=4.7,
            markerfacecolor="white",
            markeredgewidth=1.0,
            linewidth=1.55,
            capsize=2.4,
            color=CASE_COLORS[case],
            label=CASE_LABEL[case],
        )

        m = marginal[marginal["caseName"] == case].sort_values("toCar")
        ax1.plot(
            m["toCar"],
            m["damageDrop"],
            marker=CASE_MARKERS[case],
            markersize=4.7,
            markerfacecolor="white",
            markeredgewidth=1.0,
            linewidth=1.55,
            color=CASE_COLORS[case],
            label=CASE_LABEL[case],
        )

    ax0.set_title("(a) Total dynamic damage")
    ax0.set_xlabel("Vehicles per period")
    ax0.set_ylabel("Average damage")
    ax0.legend(loc="upper right")
    style_axes(ax0)

    ax1.axhline(0, color=OKABE_ITO["black"], linewidth=0.75)
    ax1.set_title("(b) Marginal damage reduction")
    ax1.set_xlabel("Vehicles after increment")
    ax1.set_ylabel("Damage reduction")
    style_axes(ax1)

    pdf_out = FIGURES / "vehicle_sensitivity_eswa.pdf"
    png_out = FIGURES / "vehicle_sensitivity_eswa.png"
    save_pdf_png(fig, pdf_out, png_out)
    return pdf_out, png_out


def main() -> None:
    vehicle_path = latest_vehicle_file()
    summary = vehicle_summary(vehicle_path)
    marginal = vehicle_marginal(summary)
    summary.to_csv(RESULTS / "vehicle_sensitivity_manuscript_summary.csv", index=False, encoding="utf-8-sig")
    marginal.to_csv(RESULTS / "vehicle_sensitivity_manuscript_marginal.csv", index=False, encoding="utf-8-sig")
    pdf_path, png_path = plot_vehicle_sensitivity(summary, marginal)
    print(f"source={vehicle_path}")
    print(f"vehicle_pdf={pdf_path}")
    print(f"vehicle_png={png_path}")


if __name__ == "__main__":
    main()
