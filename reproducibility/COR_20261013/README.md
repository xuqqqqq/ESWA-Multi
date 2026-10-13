# COR 20261013: frozen code and archived-statistics subset

This directory publishes a bounded subset of the frozen PDR-HGA
`PDR_HGA_COR_repro_v3_synced` archive. It is not the entire submission archive,
a new solver version, a manuscript release, or a fully reproducible fresh
benchmark experiment. The repository outside this directory predates this
snapshot and was not changed or audited as part of this publication.

## Run the archived computations

Python 3.12 and the existing pinned dependencies in `requirements.txt` are
required. From **this directory**, not the repository root:

```sh
python -m pip install -r requirements.txt
python -B reproduce.py verify
python -B -m unittest discover -s tests -v
python -B reproduce.py audit
python -B reproduce.py rebuild --output generated
```

`generated/` must be new or empty. The adapter refuses overlapping source or
evidence destinations. It computes only CSV/JSON statistics; it does not read
benchmark input matrices, manuscript files, bibliography, or figure assets.
`verification_report.json` records grid/seed checks and comparisons with the
published `evidence/` CSVs (absolute tolerance 1e-9, relative tolerance 1e-10).
Rebuilding does not run optimization or generate new observations.

Available archived computations:

| Computation | Published observations and checks |
| --- | --- |
| Main algorithm comparison | 3 instances x 3 methods x 20 matched seeds; means, sample SD, exact paired sign-flip tests, deterministic bootstrap intervals, Holm correction |
| External comparison | 3 adapted instances x 3 methods x 5 seeds; descriptive statistics |
| Combined ablation | 3 instances x 4 profiles x 10 matched seeds; paired tests, bootstrap intervals, interaction diagnostics |
| Objective comparison | 3 instances x 3 objectives x 20 matched seeds; budget, solver version and recorded capacity/inventory feasibility checked; original 45 observations retained |
| Resource experiments | Fixed total supply, 60 dispatch slots and horizon 1440; five runs per setting |
| Node associations | 10 runs x 100 nodes per instance; rank correlations summarized/tested at the seeded-run level, not treating nodes as independent runs |
| Convergence | 180 traces x 300 generations; full grid, monotonic best-so-far values and median/interquartile summaries |
| Fleet sensitivity | Historical `warmstart_v1`, 600 generations/population 10; descriptive statistics only |

`analysis/` preserves the frozen numerical functions. Their historical standalone
`main()` routines also contain legacy table/plot writers and directory layouts;
they are **not** the supported public entrypoints. `reproduce.py` retargets their
input paths and invokes only the numerical functions, never those writers.
`plot_style.py` is retained solely as an import dependency; no artwork is bundled.
The old manuscript-dependent rebuild/audit scripts, manifest, result index, and
environment/log files are deliberately not copied.

## Frozen MATLAB solver

`matlab/*.m` is copied byte-for-byte from the frozen archive except
`run_paper_experiment.m`. That wrapper now checks excluded inputs before creating
outputs, accepts an explicit fourth `inputDir` argument, and uses the published
convergence evidence instead of a manuscript-archive path. Core search,
objective, initialization, and operators are unchanged. The baseline wrappers
are the project's unified implementations, not claims of byte-identical
third-party author implementations.

With MATLAB and **separately obtained authorized adapted inputs**:

```matlab
addpath(fullfile(pwd,'matlab'));
run_paper_experiment('smoke',[], 'C101-25', inputDir);
run_paper_experiment('comparison',1, 'C101-25', inputDir);
run_paper_experiment('objectives',1, 'C101-25', inputDir);
```

See [INPUTS.md](INPUTS.md) for exact filenames and access limitations. The wrapper
also supports ablation, convergence, external, resources, nodes, dispatch and
archived_seed phases when their inputs are supplied. Outputs go to ignored,
isolated `new_runs/` directories. Never run experiments concurrently in one
MATLAB process: the frozen solver uses globals. Direct low-level convenience
functions do not provide the wrapper's input isolation.

For a **non-benchmark**, wholly synthetic smoke test requiring no external data:

```matlab
addpath(fullfile(pwd,'tests'));
smoke_synthetic();
```

This generates an artificial grid locally and tests deterministic two-generation
PDR-HGA/IMA/VNS solves, customer coverage, capacity/inventory feasibility, the
missing-input guard and adapted wrapper. It is not performance evidence and does
not establish exact benchmark reruns or full experimental replication.

## Evidence boundaries

- Main runs use 300 generations/population 8; VNS uses one incumbent. These are
  not equal CPU-time or objective-evaluation budgets.
- Main comparison and convergence use different seed cohorts. Preserve the
  recorded seeds in `EXPERIMENT_CONFIGS.json`.
- Ablation polishing is enabled for repair configurations but not Base HGA.
  The interaction diagnostic is not a polish-controlled factorial causal test.
  Ablation generation curves and route-plan exports are outside this subset.
- A post-loop Final point drawn at x=320 in historical plots is not generation
  320. Convergence here contains observed generations 1-300 only.
- `bestFitness == nodeDamage` indicates zero recorded penalty, not a separate
  saved-route constraint audit. Some historical schemas omit feasibility fields.
- Objective-comparison feasibility checks cover recorded capacity/inventory
  columns. The frozen solver does not add a new depot-return-before-period-end
  constraint. Model time and loss are not calibrated earthquake measurements.
- Fleet data used historical warm starts and wall-clock-derived recorded seeds;
  publishing them does not promise fresh exact replication by this frozen solver.

## Contents and rights

- `source_data/`: author-generated per-run metrics, convergence traces, synthetic
  node-association outputs, and the original five-run objective cohort.
- `evidence/`: selected archived numerical CSVs, not manuscript tables or images.
- `EXPERIMENT_CONFIGS.json`: budgets and seeds; dispatch groups were removed and
  every retained source refers to an included CSV.
- `MANIFEST.json`: regenerated checksums for **only this public subset**, with no
  excluded-file references or absolute local paths.
- `.gitattributes`: disables newline conversion within this snapshot so frozen
  bytes and manifest hashes survive checkouts on different operating systems.
- `tests/`: regression and synthetic smoke tests.
- `VALIDATION.json`: bounded validation results, including any static advisories.

No manuscript source/PDF, author metadata/contact emails, bibliography, cover
letter, graphical artwork, chat/automation logs, credentials, or raw/converted
benchmark matrices were added. Benchmark redistribution permission remains
unresolved. Existing upstream files and any applicable notices remain unchanged.
No software license file was present in the remote checkout; **no new license
or third-party redistribution grant is invented**. Public visibility is not an
open-source license. MATLAB requires the user's own license; Python dependencies
are named, not bundled, and retain their own terms.
