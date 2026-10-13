"""Recompute archived statistics without manuscript assets or benchmark inputs."""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "analysis"))
os.environ.setdefault("MPLBACKEND", "Agg")


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_path(root: Path, relative: str) -> Path:
    path = (root / relative).resolve()
    if Path(relative).is_absolute() or not path.is_relative_to(root.resolve()):
        raise ValueError("Manifest path escapes the public subset")
    return path


def verify_package(root: Path = ROOT) -> dict:
    manifest = json.loads((root / "MANIFEST.json").read_text(encoding="utf-8"))
    failures = []
    paths = [item["path"] for item in manifest["files"]]
    if len(paths) != len(set(paths)):
        raise ValueError("Duplicate manifest entries")
    for item in manifest["files"]:
        path = safe_path(root, item["path"])
        if not path.is_file() or path.stat().st_size != item["bytes"] or file_hash(path) != item["sha256"]:
            failures.append(item["path"])
    if failures:
        raise ValueError(f"Missing or modified public files: {failures}")
    for path in [root / "reproduce.py", *(root / "analysis").glob("*.py"), *(root / "tests").glob("*.py")]:
        ast.parse(path.read_text(encoding="utf-8"), filename=path.name)
    return {"integrity_passed": True, "files_checked": len(paths), "python_syntax_passed": True}


def prepare_output(destination: Path, root: Path = ROOT) -> Path:
    destination = destination.resolve()
    protected = [root / name for name in ("matlab", "analysis", "source_data", "tests", "evidence")]
    if destination == root.resolve() or any(
        destination.is_relative_to(p.resolve()) or p.resolve().is_relative_to(destination) for p in protected
    ):
        raise ValueError("Output must not overlap the immutable public files")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("Output must be a new or empty directory")
    destination.mkdir(parents=True, exist_ok=True)
    return destination


def audit_data() -> list[dict]:
    import pandas as pd

    rows = []
    for path in sorted((ROOT / "source_data").rglob("*.csv")):
        data = pd.read_csv(path)
        rows.append({"file": path.relative_to(ROOT).as_posix(), "rows": len(data), "columns": len(data.columns)})
    return rows


def analyzer(name: str):
    # Retarget only I/O; the frozen statistical functions remain unchanged.
    module = importlib.import_module(name)
    frozen = ROOT / "source_data" / "frozen"
    historical = ROOT / "source_data" / "historical"
    for attr in ("SOURCE", "SOURCE_DIR", "WORKTREE_RESULTS", "PART_DIR"):
        if hasattr(module, attr):
            setattr(module, attr, frozen)
    if hasattr(module, "FILES"):
        module.FILES = [frozen / path.name for path in module.FILES]
    if hasattr(module, "FORMAL_RUN_FILES"):
        module.FORMAL_RUN_FILES = [frozen / path.name for path in module.FORMAL_RUN_FILES]
        module.HISTORICAL = historical / module.HISTORICAL.name
    return module


def check_configurations(output: Path) -> int:
    import pandas as pd

    config = json.loads((ROOT / "EXPERIMENT_CONFIGS.json").read_text(encoding="utf-8"))
    cache = {}
    for group in config["groups"]:
        source = group["source"]
        path = output / Path(source).name if source.startswith("evidence/") else safe_path(ROOT, source)
        if path not in cache:
            cache[path] = pd.read_csv(path)
        data = cache[path]
        for key in ("caseName", "algorithm", "operatorProfile", "modelName", "setting", "carNum", "metric"):
            if key in group:
                data = data[data[key].eq(group[key])]
        if group["experiment"] in ("period_count", "release_profile"):
            data = data[data.experiment.eq(group["experiment"])]
        expected = set(group["seeds"])
        if set(data.seed.astype(int)) != expected or len(expected) != group["runs"]:
            raise ValueError(f"Configuration seed mismatch: {group['experiment']}/{group['caseName']}")
    return len(config["groups"])


def rebuild(destination: Path) -> dict:
    import numpy as np
    import pandas as pd

    integrity = verify_package()
    output = prepare_output(destination)

    def save(data, name):
        data.to_csv(output / name, index=False, encoding="utf-8-sig")

    main = analyzer("analyze_old_v2_main_comparison")
    raw = pd.concat([pd.read_csv(p) for p in sorted(main.SOURCE_DIR.glob(main.SOURCE_PATTERN))], ignore_index=True)
    raw = raw[raw.caseName.isin(main.CASES)]
    if raw.duplicated(["caseName", "algorithm", "seed"]).any():
        raise ValueError("Duplicate main-comparison observations")
    data = main.load()
    summary, tests = main.analyze(data)
    save(data, "algorithm_comparison_old_v2_20run_authoritative.csv")
    save(summary, "algorithm_comparison_old_v2_20run_summary.csv")
    save(tests, "algorithm_comparison_old_v2_20run_paired_stats.csv")
    print("Main comparison: 180 observations, 6 paired tests", flush=True)

    external = analyzer("analyze_frozen_external_comparison")
    external_data = external.load()
    save(external_data, "frozen_external_comparison_authoritative.csv")
    save(external.summarize(external_data), "frozen_external_comparison_summary.csv")

    ablation = analyzer("analyze_old_v2_combined_ablation")
    ablation_data = ablation.build_authoritative_grid()
    save(ablation_data, "ablation_old_v2_combined_10run_authoritative.csv")
    names = ("summary", "paired_stats", "interactions", "marginal_stats")
    for frame, name in zip(ablation.summarize(ablation_data), names):
        save(frame, f"ablation_old_v2_combined_10run_{name}.csv")
    print("Ablation: 120 observations; polishing is not factorial-controlled", flush=True)

    models = analyzer("analyze_shared_framework_models")
    model_data = models.validate(pd.concat([
        pd.read_csv(p) for p in sorted((ROOT / "source_data/frozen").glob("shared_framework_models_*.csv"))
    ], ignore_index=True))
    save(model_data, "shared_framework_model_authoritative.csv")
    save(models.summarize(model_data), "shared_framework_model_summary.csv")
    originals = pd.concat([pd.read_csv(p) for p in sorted((ROOT / "source_data/objective_original_5run").glob("*.csv"))])
    keys = ["caseName", "objectiveMode", "seed"]
    retained = model_data.set_index(keys).loc[originals.set_index(keys).index]
    for column in ("searchObjective", "totalAffectedNodeLoss", "capacityViolation", "inventoryViolation"):
        if not np.allclose(retained[column], originals[column], rtol=1e-12, atol=1e-9):
            raise ValueError("The original five-run observations have changed")

    resources = analyzer("analyze_controlled_resources_old_v2")
    resource_data = resources.load()
    save(resource_data, "controlled_resources_old_v2_authoritative.csv")
    period, release = resources.summarize(resource_data)
    save(period, "controlled_period_old_v2_summary.csv")
    save(release, "controlled_release_old_v2_summary.csv")

    nodes = analyzer("analyze_node_correlations_old_v2")
    node_data = nodes.load()
    seed_stats, node_summary = nodes.analyze(node_data)
    save(seed_stats, "node_correlation_old_v2_seed_level.csv")
    save(node_summary, "node_correlation_old_v2_summary.csv")

    traces = analyzer("merge_convergence_20run")
    old = traces.normalized_trace(ROOT / "source_data/historical/convergence_old_v2_frozen_authoritative.csv")
    parts = pd.concat([traces.normalized_trace(ROOT / "source_data/frozen" / p.name) for p in traces.PART_TRACES])
    trace_data = pd.concat([old[old.repeat.between(1, 5)], parts[parts.repeat.between(6, 20)]], ignore_index=True)
    traces.validate_complete_grid(trace_data)
    for _, run in trace_data.groupby(["caseName", "algorithm", "repeat"]):
        if set(run.generation) != set(range(1, 301)) or (run.sort_values("generation").bestFitness.diff().dropna() > 1e-8).any():
            raise ValueError("Invalid generations or increasing best-so-far trace")
    trace_data = trace_data.sort_values(["caseName", "algorithm", "repeat", "generation"]).reset_index(drop=True)
    save(trace_data, "convergence_old_v2_20run_authoritative.csv")
    trace_summary = trace_data.groupby(["caseName", "algorithm", "generation"], as_index=False).agg(
        runs=("bestFitness", "size"), median=("bestFitness", "median"),
        q25=("bestFitness", lambda x: x.quantile(0.25)), q75=("bestFitness", lambda x: x.quantile(0.75)))
    save(trace_summary, "convergence_summary.csv")

    fleet = pd.read_csv(ROOT / "source_data/historical/vehicle_sensitivity_paper_20260430_033532.csv")
    fleet_summary = fleet.groupby(["caseName", "carNum", "algorithmVersion"], as_index=False).agg(
        runs=("bestFitness", "size"), mean=("bestFitness", "mean"), best=("bestFitness", "min"), std=("bestFitness", "std"))
    save(fleet_summary, "fleet_summary.csv")

    configuration_groups = check_configurations(output)
    comparisons = []
    for reference in sorted((ROOT / "evidence").glob("*.csv")):
        actual = pd.read_csv(output / reference.name)
        expected = pd.read_csv(reference)
        pd.testing.assert_frame_equal(actual, expected, check_exact=False, atol=1e-9, rtol=1e-10)
        comparisons.append(reference.name)
    verify_package()
    report = dict(integrity, archived_statistics_passed=True, configuration_groups_checked=configuration_groups,
        main_observations=len(data), external_observations=len(external_data), ablation_observations=len(ablation_data),
        objective_observations=len(model_data), original_objective_observations_preserved=len(originals),
        resource_observations=len(resource_data), node_observations=len(node_data), convergence_rows=len(trace_data),
        archived_evidence_comparisons=comparisons, fresh_benchmark_optimization_run=False,
        manuscript_or_graphics_generated=False, source_data_modified=False)
    (output / "verification_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("verify", "audit", "rebuild"), nargs="?", default="verify")
    parser.add_argument("--output", type=Path, default=ROOT / "generated")
    args = parser.parse_args()
    if args.action == "rebuild":
        result = rebuild(args.output)
    else:
        result = verify_package()
        if args.action == "audit":
            result["source_files"] = audit_data()
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
