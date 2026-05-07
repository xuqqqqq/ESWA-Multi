# ESWA-Multi

MATLAB implementation and manuscript assets for a multi-period emergency vehicle-routing study with dynamic node-road damage.

## Main MATLAB entry points

- `runIHGAOnce.m`: run the proposed IHGA on one instance.
- `runAlgorithmComparison.m`: compare IHGA with VNS and IMA baselines.
- `runAblationStudy.m`: run operator-ablation experiments.
- `runModelComparison.m`: compare the damage-oriented model with CVRP/CCVRP-style baselines.
- `runMultiPeriodImportance.m`: evaluate staged multi-period dispatch effects.
- `runVehicleSensitivity.m`: run vehicle-number sensitivity experiments.

## Quick smoke test

```matlab
r = runIHGAOnce('C101-25', 18, 10701, 20, 6);
disp(r.algorithmVersion);
disp(r.bestFitness);
```

## Manuscript

The LaTeX manuscript is under `latex/`:

```powershell
cd latex
latexmk -pdf -interaction=nonstopmode -halt-on-error manuscript.tex
```

Generated experiment outputs and local agent/runtime files are intentionally ignored by git. Re-run the scripts above to regenerate result CSV files.
