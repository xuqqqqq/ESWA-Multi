from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
OLD_TRACE = ROOT / "results" / "convergence_old_v2_frozen_authoritative.csv"
PART_DIR = ROOT / "tmp" / "old_v2_combined_ablation" / "results"
PART_TRACES = [
    PART_DIR / "convergence_20run_c101_trace.csv",
    PART_DIR / "convergence_20run_r101_trace.csv",
    PART_DIR / "convergence_20run_rc101_trace.csv",
]
OUTPUT = ROOT / "results" / "convergence_old_v2_20run_authoritative.csv"

CASES = ["C101-25", "r101-25", "rc101-25"]
ALGORITHMS = ["VNS", "IMA", "PDR-HGA"]
GENERATIONS = 300


def normalized_trace(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    data = pd.read_csv(path)
    columns = ["caseName", "algorithm", "repeat", "seed", "generation", "bestFitness"]
    missing = set(columns).difference(data.columns)
    if missing:
        raise ValueError(f"{path.name} is missing columns: {sorted(missing)}")
    data = data[columns].copy()
    data["algorithm"] = data["algorithm"].replace({"IHGA": "PDR-HGA"})
    for column in ["repeat", "seed", "generation"]:
        data[column] = pd.to_numeric(data[column], errors="raise").astype(int)
    data["bestFitness"] = pd.to_numeric(data["bestFitness"], errors="raise")
    return data


def validate_complete_grid(data: pd.DataFrame) -> None:
    key = ["caseName", "algorithm", "repeat"]
    counts = data.groupby(key).size()
    incomplete = counts[counts != GENERATIONS]
    if not incomplete.empty:
        raise ValueError(f"Incomplete run traces:\n{incomplete.to_string()}")

    expected = pd.MultiIndex.from_product(
        [CASES, ALGORITHMS, range(1, 21)], names=key
    )
    missing = expected.difference(counts.index)
    extra = counts.index.difference(expected)
    if len(missing) or len(extra):
        raise ValueError(f"Run grid mismatch: missing={list(missing)}, extra={list(extra)}")

    generation_counts = data.groupby(key)["generation"].nunique()
    if not (generation_counts == GENERATIONS).all():
        raise ValueError("At least one run does not contain 300 distinct generations")
    if data.duplicated(key + ["generation"]).any():
        raise ValueError("Duplicate case/algorithm/repeat/generation rows detected")
    if not np.isfinite(data["bestFitness"]).all():
        raise ValueError("Non-finite bestFitness values detected")
    if (data.groupby(key)["seed"].nunique() != 1).any():
        raise ValueError("At least one run contains inconsistent seeds")


def main() -> None:
    old = normalized_trace(OLD_TRACE)
    old = old[old["repeat"].between(1, 5)]
    parts = pd.concat([normalized_trace(path) for path in PART_TRACES], ignore_index=True)
    parts = parts[parts["repeat"].between(6, 20)]
    merged = pd.concat([old, parts], ignore_index=True)
    validate_complete_grid(merged)
    merged = merged.sort_values(
        ["caseName", "algorithm", "repeat", "generation"]
    ).reset_index(drop=True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    merged.to_csv(OUTPUT, index=False, encoding="utf-8-sig")
    print(f"output={OUTPUT}")
    print(f"rows={len(merged)}")
    print(merged.groupby(["caseName", "algorithm"])["repeat"].nunique())


if __name__ == "__main__":
    main()
