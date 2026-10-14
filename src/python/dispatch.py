from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.lines import Line2D

from plot_style import OKABE_ITO, apply_paper_style, save_pdf_png, style_axes


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
FIGURES = ROOT / "latex" / "figures"


PERIOD_COLORS = {
    1: OKABE_ITO["blue"],
    2: OKABE_ITO["orange"],
    3: OKABE_ITO["green"],
}
ROAD_STYLES = {
    1: ("solid", "Road type 1"),
    2: ((0, (4, 2)), "Road type 2"),
    3: ((0, (1, 2)), "Road type 3"),
}
HIGHLIGHT_ROUTE = (1, 7)


def latest_route_file() -> Path:
    files = [path for path in RESULTS.glob("route_plan_*.csv") if not path.stem.endswith("_summary")]
    if not files:
        raise FileNotFoundError("No route_plan_*.csv file found")
    return sorted(files, key=lambda item: item.stat().st_mtime)[-1]


def load_coordinates(case_name: str) -> pd.DataFrame:
    path = ROOT / f"{case_name}-para.txt"
    data = pd.read_csv(path, sep=r"\s+", header=None, names=["node", "x", "y", "demand", "service"])
    data["node"] = data["node"].astype(int)
    if 0 not in set(data["node"]):
        depot = pd.DataFrame([{"node": 0, "x": 40.0, "y": 50.0, "demand": 0.0, "service": 0.0}])
        data = pd.concat([depot, data], ignore_index=True)
    return data


def plot_basic_route_map(route_path: Path, case_name: str = "C101-25") -> tuple[Path, Path]:
    data = pd.read_csv(route_path)
    data = data[data["caseName"] == case_name].copy()
    if data.empty:
        raise ValueError(f"No rows for {case_name} in {route_path}")

    coords = load_coordinates(case_name).set_index("node")
    apply_paper_style(8.8)
    fig, ax = plt.subplots(figsize=(5.75, 5.05), constrained_layout=True)

    # Draw route segments. The route CSV stores customer sequence; depot legs are added here.
    highlighted_nodes: list[int] = []
    for (period, route_idx), group in data.groupby(["periodIdx", "routeIdx"]):
        group = group.sort_values("position")
        nodes = [0] + group["node"].astype(int).tolist() + [0]
        road_types = group["roadType"].astype(int).tolist()
        road_types = [road_types[0] if road_types else 1] + road_types + [road_types[-1] if road_types else 1]
        color = PERIOD_COLORS.get(int(period), "#666666")
        is_highlight = (int(period), int(route_idx)) == HIGHLIGHT_ROUTE
        if is_highlight:
            highlighted_nodes = group["node"].astype(int).tolist()
        for a, b, road_type in zip(nodes[:-1], nodes[1:], road_types):
            if a not in coords.index or b not in coords.index:
                continue
            xa, ya = coords.loc[a, ["x", "y"]]
            xb, yb = coords.loc[b, ["x", "y"]]
            linestyle = ROAD_STYLES.get(int(road_type), ("solid", ""))[0]
            ax.plot(
                [xa, xb],
                [ya, yb],
                color=color,
                linewidth=1.35 if is_highlight else 0.85,
                alpha=0.86 if is_highlight else 0.42,
                linestyle=linestyle,
                zorder=2 if is_highlight else 1,
            )

    first_service = (
        data.sort_values(["periodIdx", "routeIdx", "position"])
        .drop_duplicates("node", keep="first")
        [["node", "periodIdx", "arrivalTime", "nodeDamage"]]
    )
    plot_data = coords.reset_index().merge(first_service, on="node", how="left")
    for period, color in PERIOD_COLORS.items():
        group = plot_data[plot_data["periodIdx"] == period]
        ax.scatter(
            group["x"],
            group["y"],
            s=26,
            color=color,
            edgecolor="white",
            linewidth=0.6,
            alpha=0.92,
            zorder=3,
            label=f"Period {period}",
        )

    depot = coords.loc[0]
    ax.scatter(
        [depot["x"]],
        [depot["y"]],
        marker="s",
        s=76,
        color="black",
        edgecolor="white",
        linewidth=0.7,
        zorder=5,
        label="Depot",
    )

    for node in highlighted_nodes:
        x, y = coords.loc[node, ["x", "y"]]
        ax.text(
            x + 1.1,
            y + 1.1,
            str(node),
            fontsize=6.9,
            color=OKABE_ITO["black"],
            ha="left",
            va="bottom",
            bbox={"boxstyle": "round,pad=0.14", "facecolor": "white", "edgecolor": "none", "alpha": 0.82},
            zorder=6,
        )

    ax.set_title("Dispatch map: C101")
    ax.set_xlabel("x-coordinate")
    ax.set_ylabel("y-coordinate")
    ax.set_aspect("equal", adjustable="box")
    style_axes(ax, grid_axis="both")

    handles, labels = ax.get_legend_handles_labels()
    road_handles = [
        Line2D([0], [0], color="black", linewidth=1.0, linestyle=style, label=label)
        for style, label in ROAD_STYLES.values()
    ]
    ax.legend(
        handles + road_handles,
        labels + [h.get_label() for h in road_handles],
        fontsize=6.8,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.12),
        ncol=3,
        frameon=True,
    )

    pdf_out = FIGURES / "basic_route_map_c101.pdf"
    png_out = FIGURES / "basic_route_map_c101.png"
    save_pdf_png(fig, pdf_out, png_out)
    return pdf_out, png_out


def main() -> None:
    route_path = latest_route_file()
    pdf_path, png_path = plot_basic_route_map(route_path)
    print(f"source={route_path}")
    print(f"basic_route_pdf={pdf_path}")
    print(f"basic_route_png={png_path}")


if __name__ == "__main__":
    main()
