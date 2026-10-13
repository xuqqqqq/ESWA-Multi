# Excluded benchmark inputs and access limitations

All frozen `matlab/data/*.txt` files are deliberately excluded, including shared
damage arrays whose distribution/provenance permissions have not been resolved.
The new snapshot must not silently fall back to similarly named files elsewhere
in this repository. The repository's pre-existing raw data was not republished
or relicensed by this change.

## Obtain original benchmark definitions

Use the providers' pages and comply with their applicable terms:

- [SINTEF Solomon benchmark](https://www.sintef.no/projectweb/top/vrptw/solomon-benchmark/)
  for C101/R101/RC101 in the 100-customer collection.
- [SINTEF Gehring & Homberger benchmark](https://www.sintef.no/projectweb/top/vrptw/homberger-benchmark/)
  for C1_2_1/R1_2_1/RC1_2_1 in the 200-customer collection.

These are providers' original VRPTW definitions, **not** ready-to-run inputs for
this dynamic-damage model. Permission to download does not establish permission
to redistribute. Do not add downloaded datasets to this snapshot.

The archived adaptations use all 100 Solomon customers and the first 100
customers of each listed Homberger instance. Legacy `-25` names nevertheless
contain 100 affected nodes plus depot matrix index 101. Original VRPTW objective
and time-window rules are not retained as a standard VRPTW benchmark evaluation.
Homberger conversion scales C-type service times by 1/3 and constructs normal
Euclidean, short (0.5*d+0.5), and long (1.5*d+0.5) off-diagonal distances. This
description does not certify a byte-identical reconstruction of all six cases.

## Exact adapted files required by the frozen solver

For each selected case identifier (`C101-25`, `r101-25`, `rc101-25`, `HC1-100`,
`HR1-100`, or `HRC1-100`), provide four whitespace-delimited files:

- `<case>-para.txt`: 101 rows with columns `[index, x, y, demand, service duration]`;
  affected-node rows 1-100 and depot row 101. Some archived depot service entries
  are negative conversion artifacts, so generic conversion is not necessarily exact.
- `<case>-Dshort.txt`, `<case>-D.txt`, `<case>-Dlong.txt`: three 101x101 road-length matrices.

Also provide the eight shared model-input files:

- `nodeRate.txt`: 100 rows of `[initial damage, deterioration rate, recovery rate]`.
- `initialDshort.txt`, `initialD.txt`, `initialDlong.txt`: 101x101 initial road damage.
- `deteriorationRateDshort.txt`, `deteriorationRateD.txt`, `deteriorationRateDlong.txt`:
  101x101 road-deterioration rates.
- `recoveryRateD.txt`: a 101x101 recovery-rate matrix.

The shared damage values are synthetic model inputs, not observed earthquake
measurements. Original benchmark downloads do not supply these arrays. Exact
fresh reruns require the rights holder to make the matching adaptations and
model-input arrays available through a lawful access route. **That route is not
yet established in this publication**; do not substitute freshly randomized
arrays and claim the archived results have been replicated. Arbitrary synthetic
fixtures are useful only for code checks.

Place authorized adapted inputs in an ignored local `matlab/data/` directory or
pass an explicit `inputDir` to `run_paper_experiment`. Do not commit inputs. MATLAB
is proprietary and is not included. The Python archived-statistics route works
without any of these files; it proves computations on saved metrics, not the
correctness of every underlying optimization observation.
