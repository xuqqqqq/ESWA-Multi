# Experimental data

## Instances

| Paper label | MATLAB identifier | Original benchmark |
| --- | --- | --- |
| C101 | `C101-25` | Solomon C101 |
| R101 | `r101-25` | Solomon R101 |
| RC101 | `rc101-25` | Solomon RC101 |
| HC1 | `HC1-100` | Homberger C1_2_1, first 100 customers |
| HR1 | `HR1-100` | Homberger R1_2_1, first 100 customers |
| HRC1 | `HRC1-100` | Homberger RC1_2_1, first 100 customers |

For each case, `*-para.txt` contains node index, x coordinate, y coordinate,
demand and service duration. Customer rows have indices 1-100; row 101 is the
depot. The three `*-Dshort.txt`, `*-D.txt` and `*-Dlong.txt` files are 101 by
101 road-length matrices.

`nodeRate.txt` contains initial node loss, deterioration rate and recovery rate.
The `initialD*`, `deteriorationRateD*` and `recoveryRateD.txt` files contain the
road-damage parameters. These files are the inputs used by the archived runs;
do not regenerate random damage arrays when checking those runs.

## Results

Each experiment has its own directory. `runs.csv` contains individual saved
observations, not averaged or selected best runs. `summary.csv` contains the
reported descriptive statistics. `paired_tests.csv` contains paired statistical
comparisons where applicable. Convergence observations are in `traces.csv`.
The ablation trace includes a post-search Final point encoded at x=320 for
plotting; the search loop itself has 300 generations.

Important columns are:

- `caseName`, `algorithm`, `operatorProfile`, `modelName`: case and configuration.
- `seed`, `repeat`, `iterMax`, `popsize`, `algorithmVersion`: recorded run settings.
- `bestFitness`: penalized search objective; `nodeDamage`: affected-node loss.
- `totalAffectedNodeLoss`: affected-node loss used to reevaluate routing objectives.
- `generation`, `bestFitness`: best-so-far convergence observation.
- `numPeriods`, `carNumPerPeriod`, `QpProfile`: resource and dispatch settings.
- `node`, `arrivalTime`, `initialDamage`, `deteriorationRate`: node-level records.

In `dispatch/runs.csv`, each row describes a served node, its route position,
period, road type and arrival time. The route table does not contain a separate
depot-return row. Numerical figures accompanying the saved results are in
`results/figures/`.

New optimization and analysis results are saved under `output/`.
