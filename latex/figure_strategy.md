# Figure Strategy

This manuscript should use two different figure pipelines.

## Keep As Data-Generated Figures

These figures must remain generated from experiment data, not from Image2:

- `fig:algorithm-convergence`: convergence traces for VNS, IMA, and IHGA.
- `fig:vehicle-sensitivity`: vehicle-number sensitivity and marginal returns.
- `fig:period-sensitivity`: single-period aggregate baseline versus staged multi-period dispatch.
- `fig:service-period-map`: exported route-plan service-period map.

Rationale: these figures support numerical claims. They should be reproducible from CSV/MATLAB/Python outputs.

## Use Image2 For Conceptual Figures

Image2 is appropriate for conceptual and mechanism diagrams where visual clarity matters more than exact coordinates:

- Multi-period emergency delivery system.
- Single-period aggregation versus multi-period dispatch.
- Core IHGA operator mechanism.
- Damage-oriented routing versus distance-oriented routing.
- Dynamic node-road damage mechanism.

Rationale: these figures explain the model and algorithm story. They should not contain dense numbers or long labels.

## Recommended Manuscript Placement

Priority order if we add only one Image2 figure:

1. Single-period aggregation versus multi-period dispatch.

Priority order if we add two Image2 figures:

1. Single-period aggregation versus multi-period dispatch.
2. Core operators for multi-period IHGA.

Priority order if we add three Image2 figures:

1. Single-period aggregation versus multi-period dispatch.
2. Core operators for multi-period IHGA.
3. Dynamic damage mechanism.

The algorithm flowchart is optional. The manuscript already has algorithm pseudocode, so a flowchart is less important than a mechanism figure.

## File Naming Contract

If Image2 figures are generated externally, save the final selected images under `latex/figures/` with these names:

- `concept_multiperiod_dispatch.png`
- `concept_core_operators.png`
- `concept_dynamic_damage.png`
- `concept_damage_vs_distance.png`
- `concept_delivery_system.png`

Only add them to `manuscript.tex` after visual inspection. Do not include generated images with misspelled labels or fake numerical values.

## Review Of Current Image2 Candidates

The generated candidates in `picture/` should be treated as drafts, not final evidence.

Recommended candidates:

- `picture/7.png`: best conceptual figure for single-period aggregation versus realistic multi-period dispatch. Use as the first Image2 figure if the text is cleaned or regenerated in a text-light version.
- `picture/6.png`: best operator-mechanism figure. It is clearer than the earlier operator sketches and can support the algorithm-novelty discussion.
- `picture/10.png`: useful dynamic-damage mechanism figure, but currently text-heavy. Prefer regenerating a cleaner version with short labels and move equations to the manuscript text.

Optional or redundant candidates:

- `picture/2.png`: visually cleaner than `picture/1.png` for a delivery-system overview, but it is less important than the single-vs-multi-period figure.
- `picture/8.png` and `picture/9.png`: both explain damage-oriented routing versus distance-oriented routing. Keep at most one. `picture/9.png` is more explanatory but too crowded; a simplified version would be better.
- `picture/3.png` and `picture/5.png`: algorithm flowcharts are redundant because the manuscript already has pseudocode. Use only if reviewers ask for a workflow diagram.

Do not use as final manuscript figures:

- `picture/1.png`: rough layout and inconsistent visual hierarchy.
- `picture/4.png`: rougher duplicate of the operator mechanism; replace with `picture/6.png`.
- `picture/11.png`: contains synthetic convergence curves and numbers. Convergence evidence must come from real experiment output, so this should not be used in the results section.

## Style Rules

- Use white background and a restrained color-blind-safe palette.
- Keep text short: labels only, no paragraph blocks.
- Avoid decorative gradients, 3D, photorealistic trucks, and cartoon disaster scenes.
- Prefer clean vector-like shapes and consistent line weights.
- If Image2 text is unreliable, generate a text-light version and add final labels in LaTeX or PowerPoint.
