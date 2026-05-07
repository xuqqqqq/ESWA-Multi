from __future__ import annotations

import re
from pathlib import Path


LATEX_DIR = Path("latex")
MANUSCRIPT = LATEX_DIR / "manuscript.tex"


def replace_table_rows(text: str, label: str, rows: str) -> str:
    pattern = re.compile(
        rf"(\\label\{{{re.escape(label)}\}}.*?\\midrule\s*\n)(.*?)(\n\\bottomrule)",
        re.DOTALL,
    )
    new_text, count = pattern.subn(lambda match: match.group(1) + rows.rstrip() + match.group(3), text, count=1)
    if count != 1:
        raise RuntimeError(f"Could not update table rows for {label}")
    return new_text


def main() -> None:
    text = MANUSCRIPT.read_text(encoding="utf-8")
    text = replace_table_rows(
        text,
        "tab:algorithm-comparison-extended",
        (LATEX_DIR / "generated_extended_algorithm_rows.tex").read_text(encoding="utf-8"),
    )
    text = replace_table_rows(
        text,
        "tab:model-comparison-extended",
        (LATEX_DIR / "generated_extended_model_rows.tex").read_text(encoding="utf-8"),
    )
    text = replace_table_rows(
        text,
        "tab:priority-strategy",
        (LATEX_DIR / "generated_priority_strategy_rows.tex").read_text(encoding="utf-8"),
    )
    MANUSCRIPT.write_text(text, encoding="utf-8")
    print(f"updated={MANUSCRIPT}")


if __name__ == "__main__":
    main()
