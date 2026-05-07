from __future__ import annotations

import hashlib
from collections import defaultdict
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"

CASES = [
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
SUFFIXES = ["-para.txt", "-Dshort.txt", "-D.txt", "-Dlong.txt"]


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    RESULTS.mkdir(exist_ok=True)
    rows = []
    signatures: dict[tuple[str, ...], list[str]] = defaultdict(list)
    for case in CASES:
        case_hashes = []
        row = {"caseName": case}
        for suffix in SUFFIXES:
            path = ROOT / f"{case}{suffix}"
            key = suffix.strip("-").replace(".txt", "")
            if path.exists():
                value = digest(path)
                row[key] = value[:12]
                case_hashes.append(value)
            else:
                row[key] = "MISSING"
                case_hashes.append("MISSING")
        signature = tuple(case_hashes)
        signatures[signature].append(case)
        row["inputGroup"] = ""
        rows.append(row)

    group_names = {}
    for idx, (_, cases) in enumerate(sorted(signatures.items(), key=lambda item: item[1][0]), start=1):
        group = f"G{idx}"
        for case in cases:
            group_names[case] = group

    for row in rows:
        row["inputGroup"] = group_names[row["caseName"]]

    table = pd.DataFrame(rows)
    csv_path = RESULTS / "case_data_hash_audit.csv"
    table.to_csv(csv_path, index=False, encoding="utf-8-sig")

    lines = ["# Case Data Hash Audit", ""]
    grouped: dict[str, list[str]] = defaultdict(list)
    for case, group in group_names.items():
        grouped[group].append(case)
    for group, cases in sorted(grouped.items()):
        status = "duplicate group" if len(cases) > 1 else "unique"
        lines.append(f"- {group}: {', '.join(cases)} ({status})")
    lines.append("")
    lines.append("Hashes use para, Dshort, D, and Dlong files. Cases in the same group are byte-identical for these inputs.")
    md_path = RESULTS / "case_data_hash_audit.md"
    md_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"csv={csv_path}")
    print(f"report={md_path}")


if __name__ == "__main__":
    main()
