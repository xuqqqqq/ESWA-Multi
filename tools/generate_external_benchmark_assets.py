from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
LATEX = ROOT / "latex"

CASE_ORDER = ["HC1-100", "HR1-100", "HRC1-100"]
ALGORITHM_ORDER = ["VNS", "IMA", "IHGA"]
MODEL_ORDER = ["DDVRP-IHGA", "CCVRP", "CVRP"]
PRIORITY_ORDER = ["PRIORITY-INITIAL", "PRIORITY-DETERIORATION"]


def latest_external_algorithm_file() -> Path:
    candidates: list[Path] = []
    for path in RESULTS.glob("algorithm_comparison_paper_lite_*.csv"):
        try:
            data = pd.read_csv(path)
        except Exception:
            continue
        if set(CASE_ORDER).issubset(set(data.get("caseName", []))):
            candidates.append(path)
    if not candidates:
        raise FileNotFoundError("No completed external algorithm comparison CSV found")
    return sorted(candidates, key=lambda item: item.stat().st_mtime)[-1]


def latest_external_file(pattern: str, case_column: str) -> Path:
    candidates: list[Path] = []
    for path in RESULTS.glob(pattern):
        try:
            data = pd.read_csv(path)
        except Exception:
            continue
        if set(CASE_ORDER).issubset(set(data.get(case_column, []))):
            candidates.append(path)
    if not candidates:
        raise FileNotFoundError(f"No completed external CSV found for {pattern}")
    return sorted(candidates, key=lambda item: item.stat().st_mtime)[-1]


def summarize_algorithm(path: Path) -> pd.DataFrame:
    data = pd.read_csv(path)
    data = data[data["caseName"].isin(CASE_ORDER)].copy()
    summary = (
        data.groupby(["caseName", "algorithm"], as_index=False)
        .agg(
            avg_damage=("bestFitness", "mean"),
            best_damage=("bestFitness", "min"),
            std_damage=("bestFitness", "std"),
            runs=("bestFitness", "count"),
        )
    )
    summary["std_damage"] = summary["std_damage"].fillna(0.0)
    summary["caseName"] = pd.Categorical(summary["caseName"], CASE_ORDER, ordered=True)
    summary["algorithm"] = pd.Categorical(summary["algorithm"], ALGORITHM_ORDER, ordered=True)
    return summary.sort_values(["caseName", "algorithm"])


def summarize_model(path: Path) -> pd.DataFrame:
    data = pd.read_csv(path)
    data = data[data["caseName"].isin(CASE_ORDER)].copy()
    summary = (
        data.groupby(["caseName", "modelName"], as_index=False)
        .agg(avg_damage=("dynamicDamageObjective", "mean"))
    )
    summary["caseName"] = pd.Categorical(summary["caseName"], CASE_ORDER, ordered=True)
    summary["modelName"] = pd.Categorical(summary["modelName"], MODEL_ORDER, ordered=True)
    return summary.sort_values(["caseName", "modelName"])


def summarize_priority(path: Path) -> pd.DataFrame:
    data = pd.read_csv(path)
    data = data[data["caseName"].isin(CASE_ORDER)].copy()
    summary = (
        data.groupby(["caseName", "strategyName"], as_index=False)
        .agg(avg_damage=("dynamicDamageObjective", "mean"))
    )
    summary["caseName"] = pd.Categorical(summary["caseName"], CASE_ORDER, ordered=True)
    summary["strategyName"] = pd.Categorical(summary["strategyName"], PRIORITY_ORDER, ordered=True)
    return summary.sort_values(["caseName", "strategyName"])


def write_algorithm_latex_rows(summary: pd.DataFrame) -> Path:
    lines: list[str] = []
    for idx, case in enumerate(CASE_ORDER):
        if idx:
            lines.append("\\midrule")
        case_data = summary[summary["caseName"] == case]
        for _, row in case_data.iterrows():
            lines.append(
                f"{case} & {row['algorithm']} & {row['avg_damage']:.3f} & "
                f"{row['best_damage']:.3f} & {row['std_damage']:.3f} \\\\"
            )
    out = LATEX / "generated_external_algorithm_rows.tex"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def write_model_latex_rows(summary: pd.DataFrame) -> Path:
    wide = summary.pivot(index="caseName", columns="modelName", values="avg_damage").reset_index()
    lines: list[str] = []
    for _, row in wide.iterrows():
        ihga = row["DDVRP-IHGA"]
        ccvrp = row["CCVRP"]
        cvrp = row["CVRP"]
        improve_ccvrp = (ccvrp - ihga) / ccvrp * 100.0
        improve_cvrp = (cvrp - ihga) / cvrp * 100.0
        lines.append(
            f"{row['caseName']} & {ihga:.3f} & {ccvrp:.3f} & {cvrp:.3f} & "
            f"{improve_ccvrp:.2f}\\% & {improve_cvrp:.2f}\\% \\\\"
        )
    out = LATEX / "generated_external_model_rows.tex"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def write_priority_latex_rows(priority: pd.DataFrame, algorithm: pd.DataFrame) -> Path:
    priority_wide = priority.pivot(index="caseName", columns="strategyName", values="avg_damage").reset_index()
    ihga = algorithm[algorithm["algorithm"] == "IHGA"][["caseName", "avg_damage"]].rename(
        columns={"avg_damage": "DDVRP-IHGA"}
    )
    wide = priority_wide.merge(ihga, on="caseName", how="left")
    lines: list[str] = []
    for _, row in wide.iterrows():
        ihga_value = row["DDVRP-IHGA"]
        initial = row["PRIORITY-INITIAL"]
        deterioration = row["PRIORITY-DETERIORATION"]
        improve_initial = (initial - ihga_value) / initial * 100.0
        improve_deterioration = (deterioration - ihga_value) / deterioration * 100.0
        lines.append(
            f"{row['caseName']} & {ihga_value:.3f} & {initial:.3f} & {deterioration:.3f} & "
            f"{improve_initial:.2f}\\% & {improve_deterioration:.2f}\\% \\\\"
        )
    out = LATEX / "generated_external_priority_strategy_rows.tex"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def write_summary_note(algorithm: pd.DataFrame, model: pd.DataFrame, priority: pd.DataFrame) -> Path:
    algorithm_wide = algorithm.pivot(index="caseName", columns="algorithm", values="avg_damage")
    model_wide = model.pivot(index="caseName", columns="modelName", values="avg_damage")
    priority_wide = priority.pivot(index="caseName", columns="strategyName", values="avg_damage")
    rows = [
        "# External Paper-lite Summary",
        "",
        "| Check | Mean improvement | Minimum improvement |",
        "| --- | ---: | ---: |",
    ]
    alg_vs_ima = (algorithm_wide["IMA"] - algorithm_wide["IHGA"]) / algorithm_wide["IMA"] * 100.0
    alg_vs_vns = (algorithm_wide["VNS"] - algorithm_wide["IHGA"]) / algorithm_wide["VNS"] * 100.0
    model_vs_ccvrp = (model_wide["CCVRP"] - model_wide["DDVRP-IHGA"]) / model_wide["CCVRP"] * 100.0
    model_vs_cvrp = (model_wide["CVRP"] - model_wide["DDVRP-IHGA"]) / model_wide["CVRP"] * 100.0
    priority_ihga = algorithm_wide["IHGA"]
    priority_vs_initial = (priority_wide["PRIORITY-INITIAL"] - priority_ihga) / priority_wide["PRIORITY-INITIAL"] * 100.0
    priority_vs_deterioration = (
        priority_wide["PRIORITY-DETERIORATION"] - priority_ihga
    ) / priority_wide["PRIORITY-DETERIORATION"] * 100.0
    checks = [
        ("IHGA vs IMA", alg_vs_ima),
        ("IHGA vs VNS", alg_vs_vns),
        ("DDVRP-IHGA vs CCVRP", model_vs_ccvrp),
        ("DDVRP-IHGA vs CVRP", model_vs_cvrp),
        ("IHGA vs initial-damage priority", priority_vs_initial),
        ("IHGA vs deterioration priority", priority_vs_deterioration),
    ]
    for label, values in checks:
        rows.append(f"| {label} | {values.mean():.2f}% | {values.min():.2f}% |")
    out = RESULTS / "external_paper_lite_summary.md"
    out.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return out


def main() -> None:
    algorithm_source = latest_external_algorithm_file()
    model_source = latest_external_file("model_comparison_paper_lite_*.csv", "caseName")
    priority_source = latest_external_file("priority_strategy_*.csv", "caseName")

    algorithm = summarize_algorithm(algorithm_source)
    model = summarize_model(model_source)
    priority = summarize_priority(priority_source)

    summary_out = RESULTS / "external_algorithm_paper_lite_summary.csv"
    wide_out = RESULTS / "external_algorithm_paper_lite_wide.csv"
    model_out = RESULTS / "external_model_paper_lite_summary.csv"
    model_wide_out = RESULTS / "external_model_paper_lite_wide.csv"
    priority_out = RESULTS / "external_priority_strategy_summary.csv"
    priority_wide_out = RESULTS / "external_priority_strategy_wide.csv"

    algorithm.to_csv(summary_out, index=False, encoding="utf-8-sig")
    wide = algorithm.pivot(index="caseName", columns="algorithm", values="avg_damage").reset_index()
    wide.to_csv(wide_out, index=False, encoding="utf-8-sig")
    model.to_csv(model_out, index=False, encoding="utf-8-sig")
    model.pivot(index="caseName", columns="modelName", values="avg_damage").reset_index().to_csv(
        model_wide_out, index=False, encoding="utf-8-sig"
    )
    priority.to_csv(priority_out, index=False, encoding="utf-8-sig")
    priority.pivot(index="caseName", columns="strategyName", values="avg_damage").reset_index().to_csv(
        priority_wide_out, index=False, encoding="utf-8-sig"
    )

    algorithm_rows = write_algorithm_latex_rows(algorithm)
    model_rows = write_model_latex_rows(model)
    priority_rows = write_priority_latex_rows(priority, algorithm)
    note = write_summary_note(algorithm, model, priority)

    print(f"algorithm_source={algorithm_source}")
    print(f"model_source={model_source}")
    print(f"priority_source={priority_source}")
    print(f"summary={summary_out}")
    print(f"model_summary={model_out}")
    print(f"priority_summary={priority_out}")
    print(f"wide={wide_out}")
    print(f"algorithm_latex_rows={algorithm_rows}")
    print(f"model_latex_rows={model_rows}")
    print(f"priority_latex_rows={priority_rows}")
    print(f"summary_note={note}")


if __name__ == "__main__":
    main()
