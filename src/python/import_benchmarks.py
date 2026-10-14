from __future__ import annotations

import csv
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
HOMBERGER = ROOT / "external_data" / "homberger" / "homberger_200"
RESULTS = ROOT / "results"

CASE_MAP = {
    "HC1-100": "C1_2_1.TXT",
    "HR1-100": "R1_2_1.TXT",
    "HRC1-100": "RC1_2_1.TXT",
}


def parse_vrptw(path: Path) -> np.ndarray:
    rows: list[list[float]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) == 7 and parts[0].lstrip("-").isdigit():
            rows.append([float(part) for part in parts])
    if len(rows) < 101:
        raise ValueError(f"{path} contains {len(rows)} numeric rows; at least 101 required")
    return np.array(rows, dtype=float)


def service_for_project(case_name: str, raw_service: np.ndarray) -> np.ndarray:
    # The existing project data use 30 for C-type service times where Solomon/Homberger use 90.
    if case_name.startswith("HC"):
        return raw_service / 3.0
    return raw_service.copy()


def write_ascii_matrix(path: Path, matrix: np.ndarray) -> None:
    np.savetxt(path, matrix, fmt="%15.7e")


def convert_case(case_name: str, source_name: str) -> dict[str, str | int]:
    source_path = HOMBERGER / source_name
    raw = parse_vrptw(source_path)
    depot = raw[0]
    customers = raw[1:101]

    service = service_for_project(case_name, customers[:, 6])
    depot_service = -60.0 if case_name.startswith("HC") else 0.0
    para = np.vstack(
        [
            np.column_stack([np.arange(1, 101), customers[:, 1], customers[:, 2], customers[:, 3], service]),
            [101, depot[1], depot[2], 0, depot_service],
        ]
    )

    points = np.vstack([customers[:, 1:3], depot[1:3]])
    distance = np.linalg.norm(points[:, None, :] - points[None, :, :], axis=2)
    non_diag = ~np.eye(distance.shape[0], dtype=bool)
    d_short = np.zeros_like(distance)
    d_long = np.zeros_like(distance)
    d_short[non_diag] = distance[non_diag] * 0.5 + 0.5
    d_long[non_diag] = distance[non_diag] * 1.5 + 0.5

    write_ascii_matrix(ROOT / f"{case_name}-para.txt", para)
    write_ascii_matrix(ROOT / f"{case_name}-D.txt", distance)
    write_ascii_matrix(ROOT / f"{case_name}-Dshort.txt", d_short)
    write_ascii_matrix(ROOT / f"{case_name}-Dlong.txt", d_long)

    return {
        "caseName": case_name,
        "source": str(source_path.relative_to(ROOT)).replace("\\", "/"),
        "customers": 100,
        "depotX": int(depot[1]),
        "depotY": int(depot[2]),
        "totalDemand": int(customers[:, 3].sum()),
    }


def main() -> None:
    if not HOMBERGER.exists():
        raise FileNotFoundError(f"Missing Homberger data directory: {HOMBERGER}")
    RESULTS.mkdir(exist_ok=True)
    rows = [convert_case(case_name, source_name) for case_name, source_name in CASE_MAP.items()]

    csv_path = RESULTS / "external_case_import_report.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    md_path = RESULTS / "external_case_import_report.md"
    lines = [
        "# External Benchmark Case Import",
        "",
        "Source: SINTEF TOP Homberger 200-customer VRPTW benchmark archive.",
        "",
        "| Case | Source file | Customers | Depot | Total demand |",
        "| --- | --- | ---: | --- | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['caseName']} | {row['source']} | {row['customers']} | "
            f"({row['depotX']}, {row['depotY']}) | {row['totalDemand']} |"
        )
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"imported_cases={','.join(CASE_MAP)}")
    print(f"report_csv={csv_path}")
    print(f"report_md={md_path}")


if __name__ == "__main__":
    main()
