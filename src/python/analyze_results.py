"""Recompute the paper's statistics and plots from data/results."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

os.environ.setdefault("MPLBACKEND", "Agg")

import pandas as pd

import ablation
import ablation_convergence
import algorithm_comparison
import convergence
import dispatch
import extended_comparison
import fleet_sensitivity
import model_comparison
import node_parameters
import resource_sensitivity


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "results"


def read(experiment: str, name: str = "runs.csv") -> pd.DataFrame:
    return pd.read_csv(DATA / experiment / name)


def prepare_output(destination: Path) -> Path:
    destination = destination.resolve()
    for protected in (ROOT / "data", ROOT / "src"):
        if destination.is_relative_to(protected) or protected.is_relative_to(destination):
            raise ValueError("Output must not overlap the supplied code or data")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("Output directory must be new or empty")
    destination.mkdir(parents=True, exist_ok=True)
    return destination


def analyze(destination: Path) -> None:
    output = prepare_output(destination)
    figures = output / "figures"
    figures.mkdir()

    def save(frame: pd.DataFrame, experiment: str, name: str) -> None:
        folder = output / experiment
        folder.mkdir(exist_ok=True)
        frame.to_csv(folder / name, index=False, encoding="utf-8-sig")

    summary, tests = algorithm_comparison.analyze(read("comparison"))
    save(summary, "comparison", "summary.csv")
    save(tests, "comparison", "paired_tests.csv")

    save(extended_comparison.summarize(read("extended_comparison")),
         "extended_comparison", "summary.csv")

    summary, paired, interactions, marginal = ablation.summarize(read("ablation"))
    for frame, name in ((summary, "summary.csv"), (paired, "paired_tests.csv"),
                        (interactions, "interactions.csv"), (marginal, "marginal_tests.csv")):
        save(frame, "ablation", name)
    traces = read("ablation", "traces.csv")
    trace_summary = ablation_convergence.summarize_trace(traces)
    save(trace_summary, "ablation", "trace_summary.csv")
    ablation_convergence.FIGURES = figures
    for case in ablation_convergence.CASES:
        ablation_convergence.plot_case(trace_summary, case)

    models = model_comparison.validate(read("model_comparison"))
    save(model_comparison.summarize(models), "model_comparison", "summary.csv")

    period, release = resource_sensitivity.summarize(read("resource_sensitivity"))
    save(period, "resource_sensitivity", "period_summary.csv")
    save(release, "resource_sensitivity", "release_summary.csv")
    resource_sensitivity.FIGURES = figures
    resource_sensitivity.plot_period(period)

    seed_statistics, node_summary = node_parameters.analyze(read("node_parameters"))
    save(seed_statistics, "node_parameters", "seed_statistics.csv")
    save(node_summary, "node_parameters", "summary.csv")

    trace_summary = convergence.summarize_trace(read("convergence", "traces.csv"))
    save(trace_summary, "convergence", "summary.csv")
    convergence.FIGURES = figures
    convergence.plot_convergence(trace_summary, "Generation")

    fleet = fleet_sensitivity.vehicle_summary(DATA / "fleet_sensitivity" / "runs.csv")
    marginal = fleet_sensitivity.vehicle_marginal(fleet)
    save(fleet, "fleet_sensitivity", "summary.csv")
    save(marginal, "fleet_sensitivity", "marginal.csv")
    fleet_sensitivity.FIGURES = figures
    fleet_sensitivity.plot_vehicle_sensitivity(fleet, marginal)

    dispatch.ROOT = ROOT / "data" / "instances"
    dispatch.FIGURES = figures
    dispatch.plot_basic_route_map(DATA / "dispatch" / "runs.csv")
    print(f"Statistics and figures: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "output" / "analysis")
    analyze(parser.parse_args().output)
