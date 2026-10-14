from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

from plot_style import OKABE_ITO, apply_paper_style, save_pdf_png, style_axes


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
WORKTREE_RESULTS = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
FIGURES = ROOT / "latex" / "figures"
HISTORICAL_TRACE = RESULTS / "ablation_paper_lite_10run_combined_trace.csv"
AUTHORITATIVE_RESULTS = RESULTS / "ablation_old_v2_combined_10run_authoritative.csv"

CASES = ["C101-25", "r101-25", "rc101-25"]
CASE_LABELS = {"C101-25": "C101", "r101-25": "R101", "rc101-25": "RC101"}
CASE_FILES = {"C101-25": "c101", "r101-25": "r101", "rc101-25": "rc101"}
PROFILES = ["base_hga", "damage_critical_only", "period_relocate_only", "damage_period_coupled"]
PROFILE_LABELS = {
    "base_hga": "Base HGA",
    "damage_critical_only": "Damage-critical repair",
    "period_relocate_only": "Period-aware relocation",
    "damage_period_coupled": "Coupled repair",
}
PROFILE_STYLES = {
    "base_hga": (OKABE_ITO["gray"], "o", "--"),
    "damage_critical_only": (OKABE_ITO["blue"], "s", "-"),
    "period_relocate_only": (OKABE_ITO["orange"], "^", "-."),
    "damage_period_coupled": (OKABE_ITO["green"], "D", "-"),
}


def find_complete_standalone_files() -> list[Path]:
    selected = []
    for case in CASES:
        candidates = sorted(
            WORKTREE_RESULTS.glob(f"ablation_old_v2_trace_{case.lower().replace('-', '_')}_*.csv"),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
        complete = None
        for path in candidates:
            data = pd.read_csv(path)
            if (
                len(data) == 6000
                and set(data["caseName"]) == {case}
                and set(data["operatorProfile"]) == {"damage_critical_only", "period_relocate_only"}
                and data.groupby(["seed", "operatorProfile"])["generation"].max().eq(300).all()
            ):
                complete = path
                break
        if complete is None:
            raise ValueError(f"No complete standalone trace file found for {case}")
        selected.append(complete)
    return selected


def load_authoritative_trace() -> tuple[pd.DataFrame, list[Path]]:
    historical = pd.read_csv(HISTORICAL_TRACE)
    historical = historical[historical["operatorProfile"].isin(["base_hga", "no_route_structure"])].copy()
    historical.loc[historical["operatorProfile"].eq("no_route_structure"), "operatorProfile"] = (
        "damage_period_coupled"
    )
    historical["variant"] = historical["operatorProfile"].map(PROFILE_LABELS)

    files = find_complete_standalone_files()
    standalone = pd.concat([pd.read_csv(path) for path in files], ignore_index=True)
    standalone["variant"] = standalone["operatorProfile"].map(PROFILE_LABELS)
    columns = [
        "mode",
        "variant",
        "operatorProfile",
        "caseName",
        "carNum",
        "seed",
        "iterMax",
        "popsize",
        "numPeriods",
        "generation",
        "bestFitness",
    ]
    trace = pd.concat([historical[columns], standalone[columns]], ignore_index=True)
    trace = trace.drop_duplicates(["caseName", "seed", "operatorProfile", "generation"], keep="last")

    expected_rows = len(CASES) * 10 * len(PROFILES) * 300
    if len(trace) != expected_rows:
        raise ValueError(f"Trace grid has {len(trace)} rows; expected {expected_rows}")
    counts = trace.groupby(["caseName", "seed", "operatorProfile"])["generation"].nunique()
    if not counts.eq(300).all():
        raise ValueError("At least one trace does not contain all 300 generations")

    final_trace = (
        trace[trace["generation"].eq(300)]
        .set_index(["caseName", "seed", "operatorProfile"])["bestFitness"]
        .sort_index()
    )
    final_results = (
        pd.read_csv(AUTHORITATIVE_RESULTS)
        .set_index(["caseName", "seed", "operatorProfile"])["bestFitness"]
        .sort_index()
    )
    polishing_gain = final_trace - final_results
    if (polishing_gain < -1e-9).any():
        raise ValueError("Final polishing made at least one authoritative result worse than its generation-300 trace")

    final_rows = trace[trace["generation"].eq(300)].copy()
    final_rows["generation"] = 320
    final_rows = final_rows.set_index(["caseName", "seed", "operatorProfile"])
    final_rows["bestFitness"] = final_results
    final_rows = final_rows.reset_index()
    trace = pd.concat([trace, final_rows], ignore_index=True)

    return trace.sort_values(["caseName", "operatorProfile", "seed", "generation"]), files


def summarize_trace(trace: pd.DataFrame) -> pd.DataFrame:
    return (
        trace.groupby(["caseName", "operatorProfile", "generation"], as_index=False)
        .agg(meanBest=("bestFitness", "mean"), stdBest=("bestFitness", "std"))
        .sort_values(["caseName", "operatorProfile", "generation"])
    )


def draw_curves(ax: plt.Axes, case_data: pd.DataFrame, *, inset: bool) -> None:
    target = inset_axes(ax, width="42%", height="42%", loc="upper right") if inset else ax
    for profile in PROFILES:
        curve = case_data[case_data["operatorProfile"].eq(profile)]
        color, marker, linestyle = PROFILE_STYLES[profile]
        markevery = 45 if not inset else 25
        target.plot(
            curve["generation"],
            curve["meanBest"],
            color=color,
            linestyle=linestyle,
            linewidth=1.3 if not inset else 1.0,
            marker=marker,
            markersize=3.2 if not inset else 2.4,
            markerfacecolor="white",
            markeredgewidth=0.7,
            markevery=markevery,
            label=PROFILE_LABELS[profile],
        )
    style_axes(target)
    if inset:
        target.set_xlim(220, 320)
        late = case_data[case_data["generation"].ge(220)]["meanBest"]
        padding = max(0.25, 0.08 * (late.max() - late.min()))
        target.set_ylim(late.min() - padding, late.max() + padding)
        target.set_xticks([220, 260, 300, 320], ["220", "260", "300", "Final"])
        target.tick_params(labelsize=6.2)
        target.set_title("Late stage", fontsize=6.8, pad=2)


def plot_case(summary: pd.DataFrame, case: str) -> tuple[Path, Path]:
    apply_paper_style(8.7)
    fig, ax = plt.subplots(figsize=(5.4, 3.55), constrained_layout=True)
    case_data = summary[summary["caseName"].eq(case)]
    draw_curves(ax, case_data, inset=False)
    draw_curves(ax, case_data, inset=True)
    ax.set_xlabel("Generation")
    ax.set_ylabel("Mean best total loss")
    ax.set_title(CASE_LABELS[case])
    ax.set_xticks([1, 50, 100, 150, 200, 250, 300, 320], ["1", "50", "100", "150", "200", "250", "300", "Final"])
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2, fontsize=7.0)

    stem = f"ablation_combined_{CASE_FILES[case]}_eswa"
    pdf_path = FIGURES / f"{stem}.pdf"
    png_path = FIGURES / f"{stem}.png"
    save_pdf_png(fig, pdf_path, png_path)
    return pdf_path, png_path


def write_latex_rows() -> Path:
    summary = pd.read_csv(RESULTS / "ablation_old_v2_combined_10run_summary.csv")
    lines = []
    for case_index, case in enumerate(["C101", "R101", "RC101"]):
        if case_index:
            lines.append(r"\midrule")
        part = summary[summary["caseName"].eq(case)].reset_index(drop=True)
        best_mean = part["mean"].min()
        best_best = part["best"].min()
        best_std = part["std"].min()
        for row_index, row in part.iterrows():
            values = []
            for column, best_value in (("mean", best_mean), ("best", best_best), ("std", best_std)):
                value = f"{row[column]:.3f}"
                values.append(rf"\textbf{{{value}}}" if abs(row[column] - best_value) < 1e-10 else value)
            case_text = case if row_index == 0 else ""
            lines.append(
                f"{case_text} & {row['variant']} & {values[0]} & {values[1]} & {values[2]} & "
                f"{row['reductionVsBasePct']:.3f}\\% \\\\"
            )
    lines.append(r"\bottomrule")
    output = ROOT / "latex" / "generated_ablation_combined_rows.tex"
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def main() -> None:
    trace, source_files = load_authoritative_trace()
    summary = summarize_trace(trace)
    trace_path = RESULTS / "ablation_old_v2_combined_10run_trace_authoritative.csv"
    summary_path = RESULTS / "ablation_old_v2_combined_10run_trace_summary.csv"
    trace.to_csv(trace_path, index=False, encoding="utf-8-sig")
    summary.to_csv(summary_path, index=False, encoding="utf-8-sig")
    rows_path = write_latex_rows()
    print(f"sources={[path.name for path in source_files]}")
    print(f"trace={trace_path}")
    print(f"summary={summary_path}")
    print(f"latex_rows={rows_path}")
    for case in CASES:
        pdf_path, png_path = plot_case(summary, case)
        print(f"figure={pdf_path}; preview={png_path}")


if __name__ == "__main__":
    main()
