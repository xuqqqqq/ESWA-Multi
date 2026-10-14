"""Strictly merge the five archived seeds and fifteen new seeds per objective."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
CASES = {"C101-25": 17600, "r101-25": 18600, "rc101-25": 19600}
MODES = {"distance": "CVRP objective", "cumulative_arrival": "CCVRP objective", "dynamic_damage": "MP-DDVRP objective"}
LABELS = {"C101-25":"C101", "r101-25":"R101", "rc101-25":"RC101"}


def validate(data: pd.DataFrame, repeats: int = 20) -> pd.DataFrame:
    keys = ["caseName", "objectiveMode", "seed"]
    if data.duplicated(keys).any():
        raise ValueError("Duplicate experimental keys; do not silently select last or best values")
    if set(data.caseName) != set(CASES) or set(data.objectiveMode) != set(MODES):
        raise ValueError("Unexpected case/objective catalog")
    for case, base in CASES.items():
        for mode, label in MODES.items():
            group = data[data.caseName.eq(case) & data.objectiveMode.eq(mode)]
            expected = set(range(base + 1, base + repeats + 1))
            if len(group) != repeats or set(group.seed.astype(int)) != expected:
                raise ValueError(f"Incomplete or wrong-seed grid: {case}/{mode}")
            if set(group.modelName) != {label}:
                raise ValueError("Objective labels do not match modes")
            if set(group.iterMax.astype(int)) != {300} or set(group.popsize.astype(int)) != {8}:
                raise ValueError("Generation/population budget changed")
            if set(group.algorithmVersion) != {"critical_damage_v2_full"}:
                raise ValueError("Solver version changed")
            numeric = group[["totalAffectedNodeLoss", "searchObjective", "capacityViolation", "inventoryViolation"]]
            if not np.isfinite(numeric.to_numpy(dtype=float)).all():
                raise ValueError("Nonfinite metrics or missing feasibility evidence")
            feasible = group.isFeasible.astype(str).str.lower().isin(["1", "1.0", "true"])
            if not feasible.all() or (group.capacityViolation.abs() > 1e-9).any() or (group.inventoryViolation.abs() > 1e-9).any():
                raise ValueError("Infeasible final solutions are present; investigate before reporting")
    return data.sort_values(keys).reset_index(drop=True)


def summarize(data: pd.DataFrame) -> pd.DataFrame:
    return data.groupby(["caseName", "modelName"], as_index=False).agg(
        runs=("totalAffectedNodeLoss", "size"), meanLoss=("totalAffectedNodeLoss", "mean"),
        bestLoss=("totalAffectedNodeLoss", "min"), stdLoss=("totalAffectedNodeLoss", "std"),
    ).sort_values(["caseName", "modelName"])


def write_latex(summary: pd.DataFrame, latex: Path) -> None:
    rows = []
    for case in CASES:
        part = summary[summary.caseName.eq(case)].set_index("modelName")
        values = []
        for mode in ("dynamic_damage", "cumulative_arrival", "distance"):
            row = part.loc[MODES[mode]]
            cell = f"{row['meanLoss']:.3f} ({row['stdLoss']:.3f})"
            if float(row.meanLoss) == float(part.meanLoss.min()):
                cell = rf"\textbf{{{cell}}}"
            values.append(cell)
        rows.append(f"{LABELS[case]} & {' & '.join(values)} " + r"\\")
    rows.append(r"\bottomrule")
    (latex / "generated_shared_model_rows.tex").write_text("\n".join(rows)+"\n",encoding="utf-8")


def write_outputs(data: pd.DataFrame, output: Path, latex: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    latex.mkdir(parents=True, exist_ok=True)
    summary = summarize(data)
    write_latex(summary, latex)
    data.to_csv(output / "shared_framework_model_authoritative.csv", index=False, encoding="utf-8-sig")
    summary.to_csv(output / "shared_framework_model_summary.csv", index=False, encoding="utf-8-sig")
    rows = []
    for case in CASES:
        wide = data[data.caseName.eq(case)].pivot(index="seed", columns="objectiveMode", values="totalAffectedNodeLoss")
        for baseline in ("distance", "cumulative_arrival"):
            differences = wide[baseline] - wide.dynamic_damage
            rows.append({"caseName": case, "baseline": baseline, "pairs": len(wide),
                         "meanReduction": float(differences.mean()),
                         "relativeReductionPct": float(100 * differences.mean() / wide[baseline].mean()),
                         "wins": int((differences > 1e-9).sum()), "ties": int((differences.abs() <= 1e-9).sum()),
                         "losses": int((differences < -1e-9).sum())})
    wide_all = data.pivot(index=["caseName","seed"], columns="objectiveMode", values="totalAffectedNodeLoss")
    lowest_count = int((wide_all.dynamic_damage <= wide_all[["distance","cumulative_arrival"]].min(axis=1)+1e-9).sum())
    report = {"total_runs": len(data), "pairs": len(data)//3, "all_feasible": True, "lowest_loss_pairs": lowest_count,
              "runs_per_configuration": 20, "comparisons": rows}
    (output / "shared_framework_model_20run_audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    pd.DataFrame(rows).to_csv(output / "shared_framework_model_effects.csv", index=False)
    (output / "shared_framework_model_report.md").write_text(
        "# Shared-framework objective comparison (20 paired seeds per instance)\n\n"
        + summary.to_string(index=False) + "\n\nAll 180 solutions are inventory/capacity feasible.\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--job", type=Path)
    args = parser.parse_args()
    if args.job is None:
        source = ROOT / "tmp/old_v2_combined_ablation/results"
        data = validate(pd.concat([pd.read_csv(path) for path in sorted(source.glob("shared_framework_models_*.csv"))],ignore_index=True))
        report = write_outputs(data,ROOT / "results",ROOT / "latex")
        print(json.dumps(report,indent=2))
        return
    originals = sorted((args.job / "archived").glob("shared_framework_models_*.csv"))
    additions = sorted((args.job / "workers").glob("*/runs.csv"))
    if len(originals) != 3 or len(additions) != 9:
        raise ValueError("Expected three archived files and nine completed isolated shards")
    data = validate(pd.concat([pd.read_csv(path) for path in originals + additions], ignore_index=True))
    report = write_outputs(data, args.job / "results", args.job / "latex")
    merged = args.job / "merged_raw"
    merged.mkdir(exist_ok=True)
    for case in CASES:
        tag = case.lower().replace("-", "_")
        data[data.caseName.eq(case)].to_csv(merged / f"shared_framework_models_{tag}.csv", index=False)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
