"""Conservative paper self-review gate for the ESWA/DDVRP manuscript.

The script does not invent results or edit the manuscript. It scans the
current manuscript, generated tables, result CSVs, figure assets, and LaTeX
logs, then writes a review report with prioritized issues and suggested next
actions.
"""

from __future__ import annotations

import csv
import hashlib
import json
import re
from collections import defaultdict
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
LATEX = ROOT / "latex"
RESULTS = ROOT / "results"
PICTURE = ROOT / "picture"


@dataclass
class Finding:
    priority: str
    title: str
    evidence: str
    recommendation: str


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def as_float(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def add(
    findings: list[Finding],
    priority: str,
    title: str,
    evidence: str,
    recommendation: str,
) -> None:
    findings.append(Finding(priority, title, evidence, recommendation))


def check_expected_files(findings: list[Finding]) -> None:
    expected = [
        LATEX / "manuscript.tex",
        LATEX / "manuscript_extended_paperlite.pdf",
        LATEX / "manuscript_extended_paperlite.log",
        RESULTS / "extended_algorithm_paper_lite_wide.csv",
        RESULTS / "extended_model_paper_lite_wide.csv",
        RESULTS / "priority_strategy_paper_lite_wide.csv",
        RESULTS / "vehicle_sensitivity_manuscript_summary.csv",
        RESULTS / "vehicle_sensitivity_manuscript_marginal.csv",
        RESULTS / "multiperiod_importance_period_combined_summary.csv",
        LATEX / "figures" / "vehicle_sensitivity_eswa.pdf",
        LATEX / "figures" / "period_sensitivity_eswa.pdf",
        LATEX / "figure_prompts_image2.md",
    ]
    missing = [rel(path) for path in expected if not path.exists()]
    if missing:
        add(
            findings,
            "P0",
            "Missing required paper artifact",
            ", ".join(missing),
            "Regenerate the missing artifact before using the manuscript as the current paper version.",
        )


def check_latex_log(findings: list[Finding]) -> dict[str, int | bool]:
    log_path = LATEX / "manuscript_extended_paperlite.log"
    text = read_text(log_path)
    if not text:
        return {"compiled": False, "errors": 0, "warnings": 0, "overfull": 0}

    errors = len(re.findall(r"(^! .+|LaTeX Error|Fatal error)", text, re.MULTILINE))
    warnings = len(re.findall(r"LaTeX Warning", text))
    overfull = len(re.findall(r"Overfull \\hbox", text))
    compiled = "Output written on manuscript_extended_paperlite.pdf" in text

    if errors:
        add(
            findings,
            "P0",
            "LaTeX compile has errors",
            f"{rel(log_path)} reports {errors} error markers.",
            "Fix LaTeX errors and recompile before reporting manuscript completion.",
        )
    elif not compiled:
        add(
            findings,
            "P1",
            "LaTeX log does not confirm PDF output",
            rel(log_path),
            "Re-run latexmk and inspect the final log tail.",
        )
    if overfull:
        add(
            findings,
            "P2",
            "Minor LaTeX overfull box remains",
            f"{rel(log_path)} contains {overfull} overfull hbox warning(s).",
            "Only fix if final visual polish is needed; the current warning is likely low severity.",
        )

    return {"compiled": compiled, "errors": errors, "warnings": warnings, "overfull": overfull}


def numeric_signature(row: dict[str, str], ignored: Iterable[str]) -> tuple[tuple[str, str], ...]:
    ignored_set = set(ignored)
    signature: list[tuple[str, str]] = []
    for key in sorted(row):
        if key in ignored_set:
            continue
        value = row[key]
        numeric = as_float(value)
        if numeric is None:
            normalized = value.strip()
        else:
            normalized = f"{numeric:.6f}"
        signature.append((key, normalized))
    return tuple(signature)


def duplicate_numeric_groups(rows: list[dict[str, str]], name_col: str) -> list[list[str]]:
    groups: dict[tuple[tuple[str, str], ...], list[str]] = defaultdict(list)
    for row in rows:
        name = row.get(name_col, "")
        groups[numeric_signature(row, ignored=[name_col])].append(name)
    return [names for names in groups.values() if len(names) > 1]


def duplicate_group_display_label(group: list[str]) -> str | None:
    normalized = [name.strip() for name in group if name.strip()]
    if not normalized:
        return None
    prefixes: list[str] = []
    numbers: list[int] = []
    suffix: str | None = None
    for name in normalized:
        match = re.match(r"^([A-Za-z]+)(\d+)(-\d+)$", name)
        if not match:
            return None
        prefixes.append(match.group(1).upper())
        numbers.append(int(match.group(2)))
        suffix = match.group(3)
    if len(set(prefixes)) != 1 or suffix is None:
        return None
    return f"{prefixes[0]}{min(numbers):03d}--{prefixes[0]}{max(numbers):03d}"


def duplicate_group_is_collapsed_in_manuscript(group: list[str]) -> bool:
    label = duplicate_group_display_label(group)
    if not label:
        return False
    return label in read_text(LATEX / "manuscript.tex")


def manuscript_uses_old_extended_checks() -> bool:
    manuscript = read_text(LATEX / "manuscript.tex")
    old_labels = ["C101--C103", "R101--R103", "RC101--RC103"]
    return any(label in manuscript for label in old_labels)


def manuscript_uses_external_checks() -> bool:
    manuscript = read_text(LATEX / "manuscript.tex")
    external_labels = ["HC1-100", "HR1-100", "HRC1-100", "Homberger-derived"]
    return any(label in manuscript for label in external_labels)


def file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_input_data_duplicates(findings: list[Finding]) -> dict[str, list[list[str]]]:
    cases = [
        "C101-25",
        "C102-25",
        "C103-25",
        "C201-25",
        "C202-25",
        "C203-25",
        "r101-25",
        "r102-25",
        "r103-25",
        "r201-25",
        "r202-25",
        "r203-25",
        "rc101-25",
        "rc102-25",
        "rc103-25",
        "rc201-25",
        "rc202-25",
        "rc203-25",
    ]
    suffixes = ["-para.txt", "-Dshort.txt", "-D.txt", "-Dlong.txt"]
    groups: dict[tuple[str, ...], list[str]] = defaultdict(list)
    missing: list[str] = []
    for case in cases:
        signature: list[str] = []
        for suffix in suffixes:
            path = ROOT / f"{case}{suffix}"
            if not path.exists():
                missing.append(rel(path))
                signature.append("missing")
            else:
                signature.append(file_digest(path))
        groups[tuple(signature)].append(case)

    duplicate_groups = [names for names in groups.values() if len(names) > 1]
    if duplicate_groups:
        priority = "P1" if manuscript_uses_old_extended_checks() else "P2"
        add(
            findings,
            priority,
            "Input 25-node data contain duplicated case files",
            "; ".join(", ".join(group) for group in duplicate_groups),
            "Do not present duplicated groups as independent benchmark instances. This is data-folder hygiene only if the manuscript uses external benchmark checks instead.",
        )
    if missing:
        add(
            findings,
            "P1",
            "Some expected case input files are missing",
            ", ".join(missing),
            "Keep the benchmark table restricted to cases with complete para/Dshort/D/Dlong files.",
        )
    return {"duplicate_input_groups": duplicate_groups, "missing_input_files": missing}


def check_duplicate_extended_rows(
    findings: list[Finding],
    input_duplicate_groups: list[list[str]] | None = None,
) -> dict[str, list[list[str]]]:
    input_sets = [set(group) for group in (input_duplicate_groups or [])]
    files = {
        "algorithm comparison": (RESULTS / "extended_algorithm_paper_lite_wide.csv", "caseName"),
        "model comparison": (RESULTS / "extended_model_paper_lite_wide.csv", "caseName"),
        "priority strategies": (RESULTS / "priority_strategy_paper_lite_wide.csv", "caseName"),
    }
    duplicate_map: dict[str, list[list[str]]] = {}
    if not manuscript_uses_old_extended_checks():
        for label, (path, name_col) in files.items():
            duplicate_map[label] = duplicate_numeric_groups(read_csv(path), name_col)
        return duplicate_map

    for label, (path, name_col) in files.items():
        groups = duplicate_numeric_groups(read_csv(path), name_col)
        duplicate_map[label] = groups
        if groups:
            uncollapsed_groups = [group for group in groups if not duplicate_group_is_collapsed_in_manuscript(group)]
            if not uncollapsed_groups:
                continue
            explained = all(any(set(group).issubset(input_group) for input_group in input_sets) for group in groups)
            priority = "P2" if explained else "P1"
            title = (
                f"Extended {label} repeats rows because input files repeat"
                if explained
                else f"Extended {label} has duplicated numerical rows"
            )
            add(
                findings,
                priority,
                title,
                "; ".join(", ".join(group) for group in uncollapsed_groups),
                "Treat these rows as same-scale robustness entries, not independent evidence. Collapse or annotate them in the manuscript table if the duplicated labels distract from the result.",
            )
    return duplicate_map


def check_performance_relationships(findings: list[Finding]) -> dict[str, object]:
    stats: dict[str, object] = {}

    use_external = manuscript_uses_external_checks()
    alg_path = (
        RESULTS / "external_algorithm_paper_lite_wide.csv"
        if use_external
        else RESULTS / "extended_algorithm_paper_lite_wide.csv"
    )
    model_path = (
        RESULTS / "external_model_paper_lite_wide.csv"
        if use_external
        else RESULTS / "extended_model_paper_lite_wide.csv"
    )
    priority_path = (
        RESULTS / "external_priority_strategy_wide.csv"
        if use_external
        else RESULTS / "priority_strategy_paper_lite_wide.csv"
    )

    alg_rows = read_csv(alg_path)
    alg_failures: list[str] = []
    ihga_vs_ima: list[float] = []
    ihga_vs_vns: list[float] = []
    for row in alg_rows:
        ihga = as_float(row.get("IHGA_avg") or row.get("IHGA"))
        ima = as_float(row.get("IMA_avg") or row.get("IMA"))
        vns = as_float(row.get("VNS_avg") or row.get("VNS"))
        case = row.get("caseName", "")
        if ihga is None or ima is None or vns is None:
            continue
        if ihga >= ima or ihga >= vns:
            alg_failures.append(case)
        ihga_vs_ima.append((ima - ihga) / ima * 100.0)
        ihga_vs_vns.append((vns - ihga) / vns * 100.0)
    if alg_failures:
        add(
            findings,
            "P0",
            "IHGA is not best on some algorithm-comparison rows",
            ", ".join(alg_failures),
            "Do not claim full algorithm dominance until the affected rows are rerun or explained.",
        )
    stats["algorithm_min_improve_vs_ima_pct"] = min(ihga_vs_ima) if ihga_vs_ima else None
    stats["algorithm_min_improve_vs_vns_pct"] = min(ihga_vs_vns) if ihga_vs_vns else None

    model_rows = read_csv(model_path)
    model_failures: list[str] = []
    for row in model_rows:
        ddvrp = as_float(row.get("DDVRP-IHGA"))
        ccvrp = as_float(row.get("CCVRP"))
        cvrp = as_float(row.get("CVRP"))
        case = row.get("caseName", "")
        if ddvrp is None or ccvrp is None or cvrp is None:
            continue
        if ddvrp >= ccvrp or ddvrp >= cvrp:
            model_failures.append(case)
    if model_failures:
        add(
            findings,
            "P0",
            "DDVRP-IHGA is not best on some model-comparison rows",
            ", ".join(model_failures),
            "Recheck objective alignment and baseline generation before using the table.",
        )

    priority_rows = read_csv(priority_path)
    priority_failures: list[str] = []
    for row in priority_rows:
        ihga = as_float(row.get("DDVRP_IHGA") or row.get("DDVRP-IHGA"))
        initial = as_float(row.get("PriorityInitial") or row.get("PRIORITY-INITIAL"))
        deterioration = as_float(row.get("PriorityDeterioration") or row.get("PRIORITY-DETERIORATION"))
        case = row.get("caseName", "")
        if ihga is None or initial is None or deterioration is None:
            continue
        if ihga >= initial or ihga >= deterioration:
            priority_failures.append(case)
    if priority_failures:
        add(
            findings,
            "P0",
            "IHGA is not best against priority-only strategies",
            ", ".join(priority_failures),
            "Do not claim priority-strategy superiority until those rows are rerun or explained.",
        )

    return stats


def check_period_resource_logic(findings: list[Finding]) -> dict[str, object]:
    rows = read_csv(RESULTS / "multiperiod_importance_period_combined_summary.csv")
    by_case: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        by_case[row.get("caseName", "")].append(row)

    resource_issues: list[str] = []
    monotonic_cases: list[str] = []
    for case, case_rows in by_case.items():
        totals = {as_float(row.get("totalVehicles")) for row in case_rows}
        totals.discard(None)
        if len(totals) > 1:
            resource_issues.append(f"{case}: totalVehicles={sorted(totals)}")

        for row in case_rows:
            periods = as_float(row.get("numPeriods"))
            car_per_period = as_float(row.get("carNumPerPeriod"))
            total_vehicles = as_float(row.get("totalVehicles"))
            total_supply = as_float(row.get("totalSupply"))
            total_demand = as_float(row.get("totalDemand"))
            if periods and car_per_period and total_vehicles:
                if round(periods * car_per_period) != round(total_vehicles):
                    resource_issues.append(
                        f"{case}: P={periods:g}, car/period={car_per_period:g}, total={total_vehicles:g}"
                    )
            if total_supply is not None and total_demand is not None:
                if abs(total_supply - total_demand) > max(2.0, periods or 1.0):
                    resource_issues.append(
                        f"{case}: totalSupply={total_supply:g}, totalDemand={total_demand:g}"
                    )

        staged = sorted(
            [
                row
                for row in case_rows
                if row.get("scenario", "").lower().startswith("staged")
            ],
            key=lambda row: as_float(row.get("numPeriods")) or 0.0,
        )
        damages = [as_float(row.get("avgDamage")) for row in staged]
        if damages and all(v is not None for v in damages):
            if all(damages[i] <= damages[i + 1] for i in range(len(damages) - 1)):
                monotonic_cases.append(case)
            else:
                add(
                    findings,
                    "P1",
                    "Period sensitivity is not monotone for one case",
                    f"{case}: {damages}",
                    "Inspect whether random noise, insufficient repetitions, or infeasible inventory rounding caused the reversal.",
                )

    if resource_issues:
        add(
            findings,
            "P1",
            "Period resource accounting needs inspection",
            "; ".join(resource_issues),
            "Keep total vehicles and total supply fixed across periods, and explain any integer rounding of per-period supply.",
        )

    return {"period_cases_with_monotone_staged_damage": monotonic_cases}


def check_manuscript_claims(
    findings: list[Finding],
    duplicate_map: dict[str, list[list[str]]],
) -> dict[str, object]:
    manuscript = read_text(LATEX / "manuscript.tex")
    line_lookup = manuscript.splitlines()

    if "Improve vs IMA" in manuscript or "Improve vs VNS" in manuscript:
        add(
            findings,
            "P2",
            "Algorithm-comparison tables still contain redundant vs columns",
            "Found 'Improve vs IMA' or 'Improve vs VNS' in manuscript.tex.",
            "Remove those columns from Tables 2 and 3 and keep improvement percentages in prose.",
        )

    has_duplicate_extended = any(duplicate_map.values())
    if has_duplicate_extended:
        risky_phrases = [
            "all nine extended instances",
            "nine extended instances",
            "additional 25-node instances",
        ]
        matched = [phrase for phrase in risky_phrases if phrase in manuscript]
        if matched:
            add(
                findings,
                "P1",
                "Extended-instance wording may overstate independence",
                f"Matched phrases: {', '.join(matched)}.",
                "Revise wording to say 'reported extended entries' or 'same-scale robustness entries' unless the duplicated C102/C103/r102/r103/rc102/rc103 rows are fixed with independent data.",
            )

    if "fixed-total" not in manuscript and "same total resources" not in manuscript:
        add(
            findings,
            "P1",
            "Multi-period fixed-total resource logic is not explicit enough",
            "Manuscript does not contain 'fixed-total' or 'same total resources'.",
            "State clearly that more periods split the same total vehicles/supply, so each period receives fewer resources.",
        )

    if re.search(r"inventory coefficient|inventory factor", manuscript, re.IGNORECASE):
        add(
            findings,
            "P1",
            "Inventory wording may imply a coefficient rather than per-period quantity",
            "Found inventory coefficient/factor wording in manuscript.tex.",
            "Use per-period inventory quantity $Q_p$ and total supply, not an abstract inventory coefficient, in the sensitivity discussion.",
        )

    graphics = re.findall(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}", manuscript)
    missing_graphics: list[str] = []
    risky_graphics: list[str] = []
    for graphic in graphics:
        candidate = LATEX / graphic
        if not candidate.exists():
            missing_graphics.append(graphic)
        normalized = graphic.replace("\\", "/")
        if any(normalized.endswith(f"picture/{i}.png") for i in [9, 10, 11]):
            risky_graphics.append(graphic)
    if missing_graphics:
        add(
            findings,
            "P0",
            "Manuscript includes missing graphics",
            ", ".join(missing_graphics),
            "Regenerate the graphics or remove those figure references before compiling the final PDF.",
        )
    if risky_graphics:
        add(
            findings,
            "P1",
            "Manuscript includes generated figures with unsupported numerical claims",
            ", ".join(risky_graphics),
            "Do not use conceptual images that contain fabricated metrics or convergence curves unless values are replaced by real experiment traces.",
        )

    stats = {
        "line_count": len(line_lookup),
        "figure_count": len(graphics),
        "included_graphics": graphics,
    }
    return stats


def check_concept_figures(findings: list[Finding]) -> dict[str, object]:
    image_files = sorted(
        PICTURE.glob("*.png"),
        key=lambda path: int(re.sub(r"\D+", "", path.stem) or 0),
    )
    if not image_files:
        return {"picture_png_count": 0}

    recommended = {
        "2.png": "usable after relabeling inventory as per-period resource availability",
        "3.png": "usable as a clean IHGA framework",
        "6.png": "usable if simplified and de-PPT-ified",
        "7.png": "strong conceptual fit for single-period vs multi-period motivation",
        "8.png": "optional conceptual route-priority figure; not an experimental route map",
    }
    discard = {
        "1.png": "sparse/confusing inventory percentages",
        "9.png": "contains fabricated metrics unless replaced by true results",
        "10.png": "mechanism/equations may not match the model",
        "11.png": "fabricated convergence curves unless generated from real trace logs",
    }

    add(
        findings,
        "P2",
        "Concept figures need curation before manuscript insertion",
        f"Found {len(image_files)} PNGs in {rel(PICTURE)}.",
        "Prefer 2, 3, 6, and 7; use 8 only as a concept figure; avoid 1, 9, 10, and 11 unless redrawn with verified content.",
    )
    return {
        "picture_png_count": len(image_files),
        "recommended_concept_figures": recommended,
        "discard_or_redraw_figures": discard,
    }


def check_experiment_gaps(findings: list[Finding]) -> None:
    convergence_files = list(RESULTS.glob("*convergence*.csv")) + list(RESULTS.glob("*trace*.csv"))
    convergence_lock = RESULTS / "convergence_paperlite.lock"
    convergence_done = RESULTS / "convergence_paperlite_done.txt"
    if not convergence_files:
        add(
            findings,
            "P1",
            "No real convergence trace is available",
            "No *convergence*.csv or *trace*.csv file found under results.",
            "Do not use convergence Figure G/11 as an experimental figure. If convergence is needed, instrument IHGA to log best/average fitness per generation and rerun 5-10 seeds.",
        )
    else:
        paper_quality = [
            path
            for path in convergence_files
            if "paper_lite" in path.stem.lower() or "paper" in path.stem.lower()
        ]
        if not paper_quality:
            add(
                findings,
                "P2",
                "Only smoke/quick convergence traces are available",
                ", ".join(rel(path) for path in sorted(convergence_files)[-3:]),
                "Use smoke/quick traces for plotting pipeline validation only. Run paper-lite or paper convergence traces before inserting the figure as experimental evidence.",
            )
        elif convergence_lock.exists() and not convergence_done.exists():
            add(
                findings,
                "P2",
                "Paper-lite convergence trace is still running",
                rel(convergence_lock),
                "Do not insert the convergence figure as final evidence until the paper-lite run completes and the generated assets are refreshed.",
            )

    route_maps = list(RESULTS.glob("*route*.csv")) + list(RESULTS.glob("*route*.json"))
    if not route_maps:
        add(
            findings,
            "P2",
            "No machine-readable route plan artifact found",
            "No route CSV/JSON detected under results.",
            "For route comparison figures, either export best routes from MATLAB/Python or label conceptual graphics clearly as schematic illustrations.",
        )


def status_counts(findings: list[Finding]) -> dict[str, int]:
    counts = {"P0": 0, "P1": 0, "P2": 0}
    for finding in findings:
        counts[finding.priority] = counts.get(finding.priority, 0) + 1
    return counts


def write_reports(findings: list[Finding], metrics: dict[str, object]) -> tuple[Path, Path]:
    RESULTS.mkdir(exist_ok=True)
    counts = status_counts(findings)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    report_path = RESULTS / "paper_autopilot_review.md"
    json_path = RESULTS / "paper_autopilot_review.json"

    lines: list[str] = [
        "# Paper Autopilot Review",
        "",
        f"Generated: {timestamp}",
        "",
        "## Status",
        "",
        f"- P0 blockers: {counts.get('P0', 0)}",
        f"- P1 paper-risk issues: {counts.get('P1', 0)}",
        f"- P2 polish/curation issues: {counts.get('P2', 0)}",
        "",
    ]

    if counts.get("P0", 0) == 0:
        lines.append("No P0 blocker was detected. The manuscript can be iterated, but P1 issues should be resolved before making strong paper claims.")
        lines.append("")

    for priority in ["P0", "P1", "P2"]:
        section_findings = [item for item in findings if item.priority == priority]
        lines.extend([f"## {priority} Findings", ""])
        if not section_findings:
            lines.extend(["None.", ""])
            continue
        for index, finding in enumerate(section_findings, start=1):
            lines.extend(
                [
                    f"{index}. **{finding.title}**",
                    f"   - Evidence: {finding.evidence}",
                    f"   - Recommendation: {finding.recommendation}",
                    "",
                ]
            )

    lines.extend(["## Metrics", "", "```json", json.dumps(metrics, ensure_ascii=False, indent=2), "```", ""])
    report_path.write_text("\n".join(lines), encoding="utf-8")

    payload = {
        "generated_at": timestamp,
        "counts": counts,
        "findings": [asdict(item) for item in findings],
        "metrics": metrics,
    }
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return report_path, json_path


def main() -> int:
    findings: list[Finding] = []
    metrics: dict[str, object] = {}

    check_expected_files(findings)
    metrics["latex_log"] = check_latex_log(findings)
    input_data_metrics = check_input_data_duplicates(findings)
    metrics["input_data"] = input_data_metrics
    duplicate_map = check_duplicate_extended_rows(findings, input_data_metrics["duplicate_input_groups"])
    metrics["duplicate_extended_rows"] = duplicate_map
    metrics["performance"] = check_performance_relationships(findings)
    metrics["period_resource_logic"] = check_period_resource_logic(findings)
    metrics["manuscript"] = check_manuscript_claims(findings, duplicate_map)
    metrics["concept_figures"] = check_concept_figures(findings)
    check_experiment_gaps(findings)

    report_path, json_path = write_reports(findings, metrics)
    counts = status_counts(findings)
    print(f"paper_autopilot_review: P0={counts['P0']} P1={counts['P1']} P2={counts['P2']}")
    print(f"report={rel(report_path)}")
    print(f"json={rel(json_path)}")
    return 1 if counts["P0"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
