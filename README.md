# PDR-HGA: code and results for review

Supporting code and archived numerical results for:

**A Multi-Period Dynamic Road Damage Vehicle Routing Problem for
Post-Earthquake Emergency-Supply Delivery**

## Reviewer entry point

The submission's frozen code and archived-statistics package is in
**[reproducibility/COR_20261013](reproducibility/COR_20261013/README.md)**.
It is available on the repository's single branch, `main`.
Use that directory for review, rather than the older development files at
the repository root. Earlier commits and files are retained as project history;
the root-level MATLAB and LaTeX files are not the frozen submission package.

| Material | Location |
| --- | --- |
| Frozen solver and experiment wrappers | [matlab/](reproducibility/COR_20261013/matlab) |
| Archived per-run results | [source_data/](reproducibility/COR_20261013/source_data) |
| Numerical summaries and statistical comparisons | [evidence/](reproducibility/COR_20261013/evidence) |
| Analysis scripts | [analysis/](reproducibility/COR_20261013/analysis) |
| Experiment budgets and random seeds | [EXPERIMENT_CONFIGS.json](reproducibility/COR_20261013/EXPERIMENT_CONFIGS.json) |
| Validation and regression tests | [VALIDATION.json](reproducibility/COR_20261013/VALIDATION.json), [tests/](reproducibility/COR_20261013/tests) |

## Verify and recompute archived statistics

From the repository root, with Python 3.12:

```sh
cd reproducibility/COR_20261013
python -m pip install -r requirements.txt
python -B reproduce.py verify
python -B -m unittest discover -s tests -v
python -B reproduce.py audit
python -B reproduce.py rebuild --output generated
```

`generated/` must be new or empty. These commands validate the published files
and recompute statistics from archived observations; they do not rerun the
optimization experiments.

## MATLAB runs and input access

The package includes a synthetic smoke test that requires no benchmark inputs.
Fresh benchmark runs require MATLAB and separately obtained authorized adapted
input matrices. See the package's [README](reproducibility/COR_20261013/README.md)
for commands and [INPUTS.md](reproducibility/COR_20261013/INPUTS.md) for input
requirements and access limitations. This public package is a code/statistics
subset, not the complete local submission archive.

The frozen package's source, results, seeds and checksum manifest are unchanged
from its initial publication. No additional software license or third-party
data redistribution permission is granted by this branch consolidation.
