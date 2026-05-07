from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt


OKABE_ITO = {
    "orange": "#E69F00",
    "sky": "#56B4E9",
    "green": "#009E73",
    "yellow": "#F0E442",
    "blue": "#0072B2",
    "vermillion": "#D55E00",
    "purple": "#CC79A7",
    "black": "#1F1F1F",
    "gray": "#7A7A7A",
    "light_gray": "#D9D9D9",
    "panel": "#F7F7F3",
}

CASE_COLORS = {
    "C101-25": OKABE_ITO["blue"],
    "r101-25": OKABE_ITO["vermillion"],
    "rc101-25": OKABE_ITO["green"],
}

CASE_MARKERS = {
    "C101-25": "o",
    "r101-25": "s",
    "rc101-25": "^",
}

ALGORITHM_COLORS = {
    "VNS": OKABE_ITO["gray"],
    "IMA": OKABE_ITO["orange"],
    "IHGA": OKABE_ITO["green"],
}

MODEL_COLORS = {
    "CVRP": OKABE_ITO["gray"],
    "CCVRP": OKABE_ITO["orange"],
    "DDVRP-IHGA": OKABE_ITO["green"],
}


def apply_paper_style(font_size: float = 9.5) -> None:
    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Times", "DejaVu Serif"],
            "mathtext.fontset": "cm",
            "font.size": font_size,
            "axes.labelsize": font_size,
            "axes.titlesize": font_size + 0.5,
            "axes.titleweight": "normal",
            "axes.edgecolor": OKABE_ITO["black"],
            "axes.linewidth": 0.8,
            "xtick.labelsize": font_size - 0.5,
            "ytick.labelsize": font_size - 0.5,
            "xtick.direction": "out",
            "ytick.direction": "out",
            "legend.fontsize": font_size - 0.5,
            "legend.frameon": False,
            "figure.dpi": 150,
            "savefig.dpi": 300,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )


def style_axes(ax: plt.Axes, *, grid_axis: str = "y") -> None:
    ax.grid(axis=grid_axis, color=OKABE_ITO["light_gray"], linestyle="--", linewidth=0.55, alpha=0.8)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.tick_params(width=0.8, length=3.2, color=OKABE_ITO["black"])


def save_pdf_png(fig: plt.Figure, pdf_path: Path, png_path: Path | None = None) -> None:
    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(pdf_path, bbox_inches="tight")
    if png_path is not None:
        png_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(png_path, dpi=300, bbox_inches="tight")
    plt.close(fig)
