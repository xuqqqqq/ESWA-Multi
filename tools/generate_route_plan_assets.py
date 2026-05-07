from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.lines import Line2D

from plot_style import OKABE_ITO, apply_paper_style, save_pdf_png, style_axes


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
FIGURES = ROOT / "latex" / "figures"

CASE_ORDER = ["C101-25", "r101-25", "rc101-25"]
CASE_LABEL = {"C101-25": "C101-25", "r101-25": "R101-25", "rc101-25": "RC101-25"}
PERIOD_COLORS = {
    1: OKABE_ITO["blue"],
    2: OKABE_ITO["orange"],
    3: OKABE_ITO["green"],
}


def latest_route_file() -> Path:
    files = [path for path in RESULTS.glob("route_plan_*.csv") if not path.stem.endswith("_summary")]
    if not files:
        raise FileNotFoundError("No route_plan_*.csv file found")
    return sorted(files, key=lambda item: item.stat().st_mtime)[-1]


def load_coordinates(case_name: str) -> pd.DataFrame:
    path = ROOT / f"{case_name}-para.txt"
    data = pd.read_csv(path, sep=r"\s+", header=None, names=["node", "x", "y", "demand", "service"])
    data["node"] = data["node"].astype(int)
    return data


def plot_service_period_map(route_path: Path) -> tuple[Path, Path]:
    data = pd.read_csv(route_path)
    apply_paper_style(8.8)

    fig, axes = plt.subplots(1, 3, figsize=(8.8, 3.15), constrained_layout=False)
    fig.subplots_adjust(left=0.07, right=0.99, top=0.86, bottom=0.28, wspace=0.24)
    legend_handles: dict[int, object] = {}

    for ax, case in zip(axes, CASE_ORDER):
        case_routes = data[data["caseName"] == case].copy()
        coords = load_coordinates(case)
        first_service = (
            case_routes.sort_values(["periodIdx", "routeIdx", "position"])
            .drop_duplicates("node", keep="first")
            [["node", "periodIdx", "arrivalTime", "nodeDamage"]]
        )
        plot_data = coords.merge(first_service, on="node", how="left")
        max_damage = plot_data["nodeDamage"].max()
        min_damage = plot_data["nodeDamage"].min()
        span = max(max_damage - min_damage, 1e-9)
        sizes = 18 + (plot_data["nodeDamage"].fillna(min_damage) - min_damage) / span * 48

        for period in sorted(PERIOD_COLORS):
            group = plot_data[plot_data["periodIdx"] == period]
            if group.empty:
                continue
            scatter = ax.scatter(
                group["x"],
                group["y"],
                s=sizes.loc[group.index],
                color=PERIOD_COLORS[period],
                alpha=0.82,
                edgecolor="white",
                linewidth=0.55,
                label=f"Period {period}",
                zorder=3,
            )
            legend_handles.setdefault(period, scatter)

        high_damage_cut = plot_data["nodeDamage"].quantile(0.75)
        high_damage = plot_data[plot_data["nodeDamage"] >= high_damage_cut]
        ax.scatter(
            high_damage["x"],
            high_damage["y"],
            s=sizes.loc[high_damage.index] + 16,
            facecolor="none",
            edgecolor=OKABE_ITO["vermillion"],
            linewidth=0.7,
            alpha=0.85,
            zorder=4,
        )

        ax.set_title(CASE_LABEL.get(case, case))
        ax.set_xlabel("x-coordinate")
        style_axes(ax, grid_axis="both")
        ax.set_aspect("equal", adjustable="box")

    axes[0].set_ylabel("y-coordinate")
    damage_handle = Line2D(
        [0],
        [0],
        marker="o",
        color="none",
        markerfacecolor="none",
        markeredgecolor=OKABE_ITO["vermillion"],
        markeredgewidth=0.9,
        markersize=6.5,
        label="Upper-quartile damage",
    )
    fig.legend(
        [legend_handles[key] for key in sorted(legend_handles)] + [damage_handle],
        [f"Period {key}" for key in sorted(legend_handles)] + ["Upper-quartile damage"],
        loc="lower center",
        ncol=4,
        fontsize=7.2,
        frameon=True,
        bbox_to_anchor=(0.5, -0.02),
    )

    pdf_out = FIGURES / "service_period_map_eswa.pdf"
    png_out = FIGURES / "service_period_map_eswa.png"
    save_pdf_png(fig, pdf_out, png_out)
    return pdf_out, png_out


def main() -> None:
    route_path = latest_route_file()
    pdf_path, png_path = plot_service_period_map(route_path)
    print(f"source={route_path}")
    print(f"service_period_pdf={pdf_path}")
    print(f"service_period_png={png_path}")


if __name__ == "__main__":
    main()
