# PDR-HGA

Source code and experimental data for **A Multi-Period Dynamic Road Damage
Vehicle Routing Problem for Post-Earthquake Emergency-Supply Delivery**.

```text
src/
  matlab/          Routing algorithms and experiment scripts
  python/          Statistical analysis and plotting
data/
  instances/       Six adapted cases and node/road damage parameters
  results/         Run-level results, convergence traces and summaries
README.md
requirements.txt
```

## Run the algorithms

Open MATLAB in the repository root. The instance files are included.

```matlab
addpath(fullfile(pwd, 'src', 'matlab'));
run_experiment('smoke', [], 'C101-25');
```

The smoke test runs two generations to check loading and execution. To run
the experiments, use the following commands. Omitting the second argument
runs all recorded repeat numbers; use `1` to run just the first repeat.

```matlab
run_experiment('comparison', 1);       % PDR-HGA, IMA and VNS
run_experiment('external', 1);         % Extended cases
run_experiment('ablation', 1);         % Four ablation configurations
run_experiment('convergence', 1);      % Algorithm convergence curves
run_experiment('objectives', 1);       % Three routing objectives
run_experiment('resources', 1);        % Period counts and release schedules
run_experiment('nodes', 1);            % Node-parameter associations
run_experiment('dispatch');           % Route and road-choice export
run_experiment('fleet');              % Vehicle-number sensitivity
```

Each call writes new files to its own directory under `output/`. The saved
paper results in `data/results/` are not overwritten. Run separate MATLAB
processes for parallel jobs because the solver uses global arrays.

To select one case, provide a third argument, for example:

```matlab
run_experiment('comparison', 1, 'r101-25');
run_experiment('external', 1, 'HC1-100');
```

## Analyze the saved results

With Python 3.12:

```sh
python -m pip install -r requirements.txt
python src/python/analyze_results.py
```

This recomputes statistics and numerical plots from the supplied observations.
It does not run the routing algorithms. Output is saved under `output/analysis/`.
Use `--output another_directory` for another analysis run; an existing nonempty
output directory is not overwritten.

## Experiments and data

| Experiment | Results directory | Runs per case and configuration |
| --- | --- | --- |
| Main algorithm comparison | `data/results/comparison/` | 20 |
| Extended algorithm comparison | `data/results/extended_comparison/` | 5 |
| Ablation | `data/results/ablation/` | 10 |
| Algorithm convergence | `data/results/convergence/` | 20 |
| Routing-objective comparison | `data/results/model_comparison/` | 20 |
| Vehicle sensitivity | `data/results/fleet_sensitivity/` | 5 |
| Period and inventory-release sensitivity | `data/results/resource_sensitivity/` | 5 |
| Node-parameter associations | `data/results/node_parameters/` | 10 solutions, 100 nodes each |
| Dispatch illustration | `data/results/dispatch/` | One saved plan per case |

The principal experiments use 300 generations and a population of eight;
VNS uses one incumbent. Vehicle sensitivity uses the recorded 600-generation,
population-10 warm-start setting. Seeds, solver versions, budgets and resource
settings are recorded in the result CSVs. The convergence and main-comparison
experiments use their respective saved seed cohorts.

The six cases adapt the [Solomon benchmarks](https://www.sintef.no/projectweb/top/vrptw/solomon-benchmark/)
and [Gehring and Homberger benchmarks](https://www.sintef.no/projectweb/top/vrptw/homberger-benchmark/).
Each adapted case has 100 affected nodes. The `-25` suffix in three file names
is a historical identifier, not the node count. Node and road damage parameters
are synthetic model inputs, not earthquake measurements. Input formats and
result columns are described in [data/README.md](data/README.md).

The MATLAB code includes PDR-HGA and the IMA/VNS implementations used for
the comparisons.
