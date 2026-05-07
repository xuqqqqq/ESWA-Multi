# GPT Image2 Figure Prompts

Use these prompts to generate clean conceptual figures. Keep final paper labels in LaTeX whenever possible; ask the image model to use simple labels only, because small text in generated images can be unreliable.

## Global Style Prompt

Apply this style to every figure:

```text
Create a clean academic vector-style figure for an Elsevier/ESWA journal paper. White background, no decorative gradient, no 3D rendering, no realistic photos. Use a restrained color-blind-safe palette: deep blue #0072B2, vermillion #D55E00, green #009E73, warm gray #7A7A7A, light gray #D9D9D9. Use thin black outlines, simple arrows, flat icons, and enough white space. Use Times-like serif labels only if necessary; keep labels short and legible. Avoid tiny text, avoid clutter, avoid cartoon style, avoid stock-photo style. Landscape aspect ratio, publication-ready, high resolution.
```

## Figure A: Multi-Period Emergency Delivery System

Recommended use: replace or complement the original-paper-style delivery-system diagram. This is the most important conceptual figure because it highlights why multi-period planning matters.

```text
Create a clean academic vector diagram showing a multi-period post-earthquake emergency delivery system.

Scene structure:
- Left side: a central depot with relief supplies.
- Three horizontal time bands labeled Period 1, Period 2, Period 3.
- In each period, a limited number of vehicles depart from the depot.
- Each period has a small inventory box above it, showing that only part of the total relief supply is available in that period.
- Right side: affected demand nodes with different urgency levels. Use node colors or halos: high urgency in vermillion, medium in orange, low in green.
- Between depot and nodes, draw road links with different states: open road, damaged slow road, blocked road. Use simple line styles, not realistic roads.
- Show that some high-urgency nodes should be served earlier, while later-period deliveries are constrained by reduced per-period inventory and vehicle availability.

Main visual message:
Multi-period planning is necessary because all supplies and vehicles are not available at once after an earthquake.

Use simple labels only: Depot, Period 1, Period 2, Period 3, inventory, high urgency, damaged road.
No large paragraphs inside the image.
```

## Figure B: Improved IHGA Framework

Recommended use: algorithm overview. It should look like a professional flowchart, not a colorful infographic.

```text
Create a clean academic flowchart of an Improved Hybrid Genetic Algorithm for multi-period dynamic-damage vehicle routing.

Flowchart blocks:
1. Input disaster network, period inventory, vehicle capacity, dynamic node damage, dynamic road damage.
2. Urgency-aware initialization.
3. Population evaluation by total dynamic damage.
4. Route-level crossover.
5. Multi-neighborhood local search: swap, insert, 2-opt, exchange, relocate.
6. Damage-critical operators: move high-loss late nodes earlier.
7. Period-aware relocation: adjust nodes across dispatch periods under inventory constraints.
8. Route rebuilding and warm-start transfer.
9. Update population and elite solution.
10. Stop condition.
11. Output multi-period delivery plan.

Use a loop arrow from update population back to crossover. Highlight the proposed improvements with green accent boxes. Keep the baseline genetic steps in gray/blue. Use short labels only. White background, vector-style, journal-ready.
```

## Figure C: Core Operators for Multi-Period IHGA

Recommended use: one compact operator figure instead of many small operator figures. This should communicate our own algorithmic contribution.

```text
Create a three-panel academic vector diagram explaining three custom operators for a multi-period dynamic-damage routing algorithm.

Panel (a): Damage-critical relocation
- Show a route sequence with a high-damage node served late.
- Draw an arrow moving that node earlier in the route.
- Use vermillion halo for the high-damage node.

Panel (b): Period-aware relocation
- Show Period 1 and Period 2 as two separate route rows.
- Move a high-urgency node from Period 2 to Period 1.
- Include a small inventory constraint icon indicating feasibility.

Panel (c): Route rebuilding
- Show an overloaded or fragmented route set on the left.
- Show cleaner rebuilt routes on the right with fewer late high-loss nodes.

Use simple numbered nodes, thin arrows, and consistent colors. Avoid detailed numerical values. Use only short labels: before, after, Period 1, Period 2, inventory feasible.
```

## Figure D: Single-Period Aggregation vs Multi-Period Dispatch

Recommended use: conceptual support for the multi-period importance section. This is strongly aligned with our argument.

```text
Create a two-panel academic vector comparison figure.

Panel (a): Optimistic single-period aggregation
- Show all vehicles and all relief supplies available at time zero.
- Many vehicles leave the depot at once.
- Add a subtle label: all resources assumed available.
- Show this as an unrealistic but optimistic planning assumption.

Panel (b): Realistic multi-period dispatch
- Show the same total amount of supplies split into Period 1, Period 2, and Period 3.
- Show fewer vehicles and fewer supplies available in each period.
- Some demand nodes wait until later periods.
- Highlight that waiting causes dynamic damage to increase.

Main message:
The total resource amount can be the same, but the timing of availability changes the delivery loss.

Use white background, flat vector style, restrained colors. Use short labels only.
```

## Figure E: Damage-Oriented Routing vs Distance-Oriented Routing

Recommended use: route comparison figure, especially if code-generated route maps are not visually strong enough.

```text
Create a three-panel academic vector route-comparison figure for post-earthquake relief delivery.

Panel (a): Demand-node distribution
- Show a depot near the center and multiple demand nodes.
- Mark several high-damage nodes with vermillion halos.
- Mark lower-damage nodes in green.

Panel (b): Distance-oriented CVRP route
- Show compact clustered routes that minimize travel distance.
- The route mostly follows nearby clusters.
- Some high-damage nodes remain served late or indirectly.

Panel (c): Dynamic-damage-oriented route
- Show more decentralized routes.
- Vehicles go earlier to high-damage nodes even if travel distance is longer.
- Use arrows from depot to high-urgency nodes.

Keep node coordinates visually consistent across all three panels. Use thin route lines, not thick spaghetti. Add only short labels: CVRP, DDVRP-IHGA, high damage.
```

## Figure F: Dynamic Damage Mechanism

Recommended use: problem-modeling section. Use this only if the model section feels abstract.

```text
Create a clean academic conceptual figure showing dynamic damage accumulation in disaster relief routing.

Left side:
- A demand node with initial damage.
- A small curve showing damage increasing with waiting time.
- A vehicle arrives earlier, resulting in lower loss.

Right side:
- A road link with earthquake damage and recovery.
- Show two alternative roads between the same pair of nodes: one shorter but severely damaged, one longer but safer/faster.
- Indicate that road condition changes travel time and arrival time.

Center:
- Show the relationship: route choice plus arrival time determines total dynamic damage.

Use minimal labels: node damage, waiting time, damaged road, alternative road, arrival time, total loss. White background, vector style, restrained colors.
```

## Figure G: Convergence Curve Concept Template

Recommended use: only if we cannot get clean trace data. Prefer code-generated convergence curves if trace data are available.

```text
Create a clean academic convergence-curve template comparing IHGA, IMA, and VNS.

Use a white background with axes labeled Iteration and Total dynamic damage.
Draw three smooth decreasing curves:
- IHGA: green solid curve, fastest decline and lowest final value.
- IMA: orange dashed curve, moderate decline and slightly higher final value.
- VNS: blue dotted curve, slower decline and higher final value.
Include a small legend. Do not include fake numerical tick labels unless they are simple and generic. Make the figure look like a scientific plot, not a business chart.
```

## Best-Practice Notes

- Prefer code-generated figures for actual experimental data: sensitivity curves, convergence curves, route maps from coordinates, and bar charts.
- Use GPT Image2 for conceptual mechanism figures: delivery-system overview, algorithm flow, operator mechanism, and single-period vs multi-period explanation.
- Avoid asking the image model to render dense equations, tables, or long labels.
- If the generated figure has wrong text, export a text-free version and add labels in LaTeX, PowerPoint, or Illustrator.
