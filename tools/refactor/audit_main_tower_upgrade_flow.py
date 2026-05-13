#!/usr/bin/env python3
"""Audit selected tower upgrade flow in main.gd without modifying gameplay.

This script is intentionally read-only. It extracts function-sized sections from
scripts/main/main.gd so large-file reviews do not depend on truncated connector
responses. It fails when an upgrade execution function appears to spend gold or
mutate tower state without an element-level gate nearby.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"

FUNC_RE = re.compile(r"^(?P<indent>[\t ]*)func\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(", re.MULTILINE)

UPGRADE_TERMS = [
    "upgrade",
    "can_upgrade_selected_tower",
    "next_upgrade_ids",
    "_config_unlocked_for_upgrade",
    "_locked_upgrade_reason",
    "Upgrade unavailable",
    "Not enough gold",
]

EXECUTION_PATTERNS = [
    re.compile(r"\bselected_tower\.upgrade\s*\("),
    re.compile(r"\btower\.upgrade\s*\("),
    re.compile(r"\.upgrade\s*\("),
]

SPEND_OR_MUTATE_PATTERNS = [
    re.compile(r"\bspend_gold\s*\("),
    re.compile(r"\bgold\s*[-+*/]?="),
]

ELEMENT_GATE_PATTERNS = [
    re.compile(r"\belement_progression_manager\b.*\bcan_build_tower\b"),
    re.compile(r"\bcan_build_tower\b.*\belement_progression_manager\b"),
    re.compile(r"\b_config_unlocked_for_upgrade\s*\("),
    re.compile(r"\bcan_upgrade_selected_tower\s*\("),
    re.compile(r"\bis_selected_tower_next_upgrade_element_unlocked\s*\("),
]

LOCKED_REASON_PATTERNS = [
    re.compile(r"\b_locked_upgrade_reason\s*\("),
    re.compile(r"\bget_locked_reason\s*\("),
    re.compile(r"\bget_selected_tower_upgrade_locked_reason\s*\("),
    re.compile(r"locked_reason"),
]

REPORT_PATTERNS = {
    "upgrade": [re.compile(r"upgrade", re.IGNORECASE)],
    "upgrade execution": EXECUTION_PATTERNS,
    "gold spend/mutation": SPEND_OR_MUTATE_PATTERNS,
    "next upgrade ids": [re.compile(r"next_upgrade_ids")],
    "element gate": ELEMENT_GATE_PATTERNS,
    "locked reason": LOCKED_REASON_PATTERNS,
    "status text": [
        re.compile(r"Not enough gold"),
        re.compile(r"Upgrade unavailable"),
        re.compile(r"Requires "),
    ],
}


@dataclass(frozen=True)
class FunctionBlock:
    name: str
    start_line: int
    end_line: int
    text: str

    def contains_any(self, patterns: Iterable[re.Pattern[str]]) -> bool:
        return any(pattern.search(self.text) for pattern in patterns)

    def matching_lines(self, patterns: Iterable[re.Pattern[str]]) -> list[tuple[int, str]]:
        out: list[tuple[int, str]] = []
        lines = self.text.splitlines()
        for offset, line in enumerate(lines):
            if any(pattern.search(line) for pattern in patterns):
                out.append((self.start_line + offset, line.rstrip()))
        return out


def read_main() -> str:
    if not MAIN.exists():
        raise FileNotFoundError(f"main.gd not found: {MAIN}")
    return MAIN.read_text(errors="replace")


def extract_functions(text: str) -> list[FunctionBlock]:
    matches = list(FUNC_RE.finditer(text))
    lines = text.splitlines()
    blocks: list[FunctionBlock] = []
    for idx, match in enumerate(matches):
        start_index = match.start()
        end_index = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        start_line = text.count("\n", 0, start_index) + 1
        end_line = text.count("\n", 0, end_index) + 1
        block_text = text[start_index:end_index].rstrip("\n")
        blocks.append(FunctionBlock(match.group("name"), start_line, min(end_line, len(lines)), block_text))
    return blocks


def is_relevant(block: FunctionBlock) -> bool:
    lowered = block.text.lower()
    if any(term.lower() in lowered for term in UPGRADE_TERMS):
        return True
    if block.contains_any(EXECUTION_PATTERNS):
        return True
    if block.contains_any(SPEND_OR_MUTATE_PATTERNS) and "upgrade" in lowered:
        return True
    return False


def is_upgrade_execution(block: FunctionBlock) -> bool:
    return block.contains_any(EXECUTION_PATTERNS)


def has_element_gate(block: FunctionBlock) -> bool:
    return block.contains_any(ELEMENT_GATE_PATTERNS)


def has_locked_reason(block: FunctionBlock) -> bool:
    return block.contains_any(LOCKED_REASON_PATTERNS)


def print_function_report(block: FunctionBlock) -> None:
    flags: list[str] = []
    if is_upgrade_execution(block):
        flags.append("EXECUTES_UPGRADE")
    if has_element_gate(block):
        flags.append("HAS_ELEMENT_GATE")
    if has_locked_reason(block):
        flags.append("HAS_LOCKED_REASON")
    flags_text = ", ".join(flags) if flags else "read-only/reference"
    print(f"\n{block.name} ({block.start_line}-{block.end_line}) [{flags_text}]")
    print("-" * (len(block.name) + len(flags_text) + 16))
    for label, patterns in REPORT_PATTERNS.items():
        lines = block.matching_lines(patterns)
        if not lines:
            continue
        print(f"  {label}:")
        for line_no, line in lines:
            print(f"    {line_no}: {line.strip()}")


def main() -> int:
    text = read_main()
    blocks = extract_functions(text)
    relevant = [block for block in blocks if is_relevant(block)]
    execution_blocks = [block for block in relevant if is_upgrade_execution(block)]
    failing_blocks = [block for block in execution_blocks if not has_element_gate(block)]

    print("Main Tower Upgrade Flow Audit")
    print("=============================")
    print(f"File: {MAIN.relative_to(ROOT)}")
    print(f"Functions scanned: {len(blocks)}")
    print(f"Relevant upgrade-related functions: {len(relevant)}")
    print(f"Upgrade execution candidates: {len(execution_blocks)}")
    print(f"Execution candidates missing element gate: {len(failing_blocks)}")

    for block in relevant:
        print_function_report(block)

    print("\nSuspected upgrade execution functions")
    print("-------------------------------------")
    if not execution_blocks:
        print("  none")
    for block in execution_blocks:
        gate = "gate=yes" if has_element_gate(block) else "gate=NO"
        reason = "locked_reason=yes" if has_locked_reason(block) else "locked_reason=no"
        print(f"  {block.name} ({block.start_line}-{block.end_line}) {gate} {reason}")

    print("\nResult")
    print("------")
    if failing_blocks:
        for block in failing_blocks:
            print(f"  FAIL: {block.name} ({block.start_line}-{block.end_line}) appears to execute upgrade without element gate")
        return 1
    print("  PASS: no upgrade execution candidate is missing an element-level gate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
