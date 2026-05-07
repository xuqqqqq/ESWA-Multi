# Experiment Pipeline

This workspace now uses one unified experiment pipeline for the dynamic multi-period damage-routing study.

## Core logic

- `runIHGAOnce.m`: improved IHGA runner with adaptive multi-period inventory, warm-start support, and extra operators for clustered/RC cases.
- `runBaselineOnce.m`: fair VNS and IMA wrappers using the same cases, periods, vehicle limits, inventory constraints, and dynamic damage objective as IHGA.
- `runObjectiveBaselineOnce.m`: constructive CVRP and CCVRP baselines, evaluated by the dynamic damage objective.

## Experiment entry points

- `runVehicleSensitivity('quick')`: vehicle-number sensitivity for C, R, and RC instances.
- `runAlgorithmComparison('quick')`: VNS vs IMA vs IHGA.
- `runAblationStudy('quick')`: operator ablation for the proposed IHGA components.
- `runAdditionalSensitivity('quick')`: planning-period and inventory-supply sensitivity.
- `runModelComparison('quick')`: CVRP, CCVRP, and dynamic-damage IHGA comparison.
- `runPriorityAnalysis('quick')`: low/medium/high priority node service order and damage analysis.

Each entry point also supports `smoke`, `quick`, and `full`.

## Automation

- Start the 5-minute rotating loop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\start_5min_research_loop.ps1 -Mode quick
```

- Stop the loop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\stop_5min_research_loop.ps1
```

- Run one phase manually:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_research_experiment.ps1 -Phase algorithm -Mode quick
```

The loop runs one phase per trigger in this order:

```text
algorithm -> ablation -> sensitivity -> model -> priority -> vehicle
```

A lock file prevents overlapping MATLAB runs. If a phase takes longer than five minutes, the next trigger is skipped until the current phase finishes.

## Result files

Raw CSVs, summaries, plots, and GPT-image prompts are written to `results/`.

- `*_summary.csv`: aggregated means, best values, standard deviations, and run counts.
- `*_summary.png`: basic diagnostic plots.
- `figure_prompts_*.md`: prompts for redrawing polished manuscript-quality figures.

## Comparison principle

The original comparison folders are preserved as source references, but the paper experiments should use the unified wrappers. This avoids unfair differences from hard-coded cases, fixed `Qp`, fixed vehicle counts, or inconsistent multi-period time offsets.
