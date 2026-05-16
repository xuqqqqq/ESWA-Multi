from __future__ import annotations

import re
from pathlib import Path

import pandas as pd


MANUSCRIPT = Path("latex/manuscript.tex")
RESULTS_DIR = Path("results")
SUMMARY = RESULTS_DIR / "algorithm_comparison_pair_paper_summary.csv"
REPORT = RESULTS_DIR / "manuscript_result_audit.md"


ROW_RE = re.compile(
    r"^(?P<case>[^&]+)&\s*(?P<algorithm>[^&]+)&\s*(?P<avg>[0-9.]+)\s*&\s*"
    r"(?P<best>[0-9.]+)\s*&\s*(?P<std>[0-9.]+)\s*\\\\"
)


def parse_algorithm_table(text: str) -> dict[tuple[str, str], tuple[float, float, float]]:
    start = text.index(r"\label{tab:algorithm-comparison}")
    end = text.index(r"\end{table}", start)
    table = text[start:end]
    parsed: dict[tuple[str, str], tuple[float, float, float]] = {}
    for raw_line in table.splitlines():
        line = raw_line.strip()
        match = ROW_RE.match(line)
        if not match:
            continue
        case = match.group("case").strip()
        algorithm = match.group("algorithm").strip()
        parsed[(case, algorithm)] = (
            float(match.group("avg")),
            float(match.group("best")),
            float(match.group("std")),
        )
    return parsed


def main() -> None:
    manuscript = MANUSCRIPT.read_text(encoding="utf-8")
    table_values = parse_algorithm_table(manuscript)
    summary = pd.read_csv(SUMMARY)

    failures: list[str] = []
    lines = [
        "# Manuscript Result Audit",
        "",
        f"- Manuscript: `{MANUSCRIPT}`",
        f"- Authoritative algorithm summary: `{SUMMARY}`",
        "",
        "## Algorithm Table Check",
        "",
        "| Instance | Algorithm | Manuscript avg/best/std | Summary avg/best/std | Status |",
        "|---|---|---:|---:|---|",
    ]

    for _, row in summary.iterrows():
        key = (str(row["caseName"]), str(row["algorithm"]))
        expected = (
            round(float(row["avgDamage"]), 3),
            round(float(row["bestDamage"]), 3),
            round(float(row["stdDamage"]), 3),
        )
        actual = table_values.get(key)
        status = "ok" if actual == expected else "mismatch"
        if status != "ok":
            failures.append(f"{key}: manuscript={actual}, summary={expected}")
        lines.append(
            f"| {key[0]} | {key[1]} | {actual} | {expected} | {status} |"
        )

    forbidden_terms = ["MP-IHGA", "DDVRP-IHGA"]
    found_terms = [term for term in forbidden_terms if term in manuscript]
    lines.extend(["", "## Naming Check", ""])
    if found_terms:
        failures.append(f"Forbidden mixed method names remain: {', '.join(found_terms)}")
        lines.append(f"- Mixed method names remain: {', '.join(found_terms)}")
    else:
        lines.append("- No `MP-IHGA` or `DDVRP-IHGA` strings remain in the manuscript.")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"report={REPORT}")
    if failures:
        print("Audit failed:")
        for failure in failures:
            print(f"- {failure}")
        raise SystemExit(1)
    print("Audit passed")


if __name__ == "__main__":
    main()
