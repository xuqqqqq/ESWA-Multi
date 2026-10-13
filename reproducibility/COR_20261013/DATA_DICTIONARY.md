# Public numerical data dictionary

All CSVs are author-generated solver observations or derived statistics. The
benchmark coordinate/demand matrices and route-plan demand exports are excluded.
Node-association rows contain synthetic damage parameters and calculated service
outcomes, not benchmark coordinates. CSV empty cells mean a value was not
exported in that historical schema, not zero violations. Model times/distances
and losses are model units, not verified measured minutes or physical damage.

| Field | Interpretation |
| --- | --- |
| caseName | Program identifier; legacy `-25` cases have 100 affected nodes |
| algorithm / modelName / variant | Method, objective label, or ablation profile |
| algorithmVersion / operatorProfile | Frozen implementation/profile identifiers |
| seed / repeat | Recorded MATLAB Twister seed and ordinal run index |
| iterMax / generation / popsize | Generation budget, observed generation, population size |
| carNum / carNumPerPeriod | Dispatch slots per period, not the number of distinct physical vehicles |
| numPeriods / Tshift | Number of periods and spacing between their starts |
| Qp / QpProfile / qPeriod1..5 | Released supply per period, not vehicle capacity |
| totalSupply / totalDemand / totalDispatchSlots | Controlled resource totals |
| bestFitness | Search objective including any penalties |
| nodeDamage / totalAffectedNodeLoss | Total modeled affected-node loss evaluated at service time |
| searchObjective / objectiveMode | Optimized criterion; not necessarily dynamic loss |
| capacityViolation / inventoryViolation / isFeasible | Saved violation magnitudes/flag where exported; not a fresh independent route audit |
| elapsedSeconds | Machine-specific execution duration, not a reproducible loss measure |
| periodLoad1..5 | Supply delivered in each period |
| roadDamage | Separate road-damage diagnostic, not affected-node loss |
| nonEmptyRoutes / bestNumRoutes | Saved used-route count |
| maxRouteLength / avgRouteLength | Customers per route, not geographic distance |
| totalDistance | Saved aggregate road distance in model units |
| arrivalTime / avgArrivalTime / maxArrivalTime / serviceRank | Calculated service timing and global rank |
| initialDamage / deteriorationRate / recoveryRate | Synthetic node-model parameters retained in association output |
| sustainedPressure / urgency | b/rho and a+b/rho from the synthetic node parameters |
| mean / meanLoss / std / stdLoss | Across-run mean and sample standard deviation |
| best / bestLoss | Minimum recorded loss, not proof of optimality |
| ciLow / ciHigh | Seeded-run bootstrap percentile interval endpoints |
| ci95 | t-based 95% half-width for five-run controlled resource summaries |
| pValueTwoSided / pValueHolm | Exact paired sign-flip p and Holm-adjusted p |
| pairedEffectDz | Mean paired difference divided by its sample standard deviation |
| spearmanRho / meanRho | Within-run rank correlation and average across seeded runs |
| median / q25 / q75 | Across-run convergence median and quartiles at the same generation |

The original-five-run objective cohort is nested within the twenty-run cohort,
not an independent sample or a solver upgrade comparison. Node-level observations
are nested within runs. Convergence, main-comparison and other experiment seed
cohorts must not be interchanged. See `EXPERIMENT_CONFIGS.json` for actual seeds,
budgets, and included-file references.
