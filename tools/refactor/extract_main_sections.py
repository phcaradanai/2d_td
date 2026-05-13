#!/usr/bin/env python3
"""Extract focused function sections from scripts/main/main.gd.

Usage examples:
  python3 tools/refactor/extract_main_sections.py upgrade selected_tower
  python3 tools/refactor/extract_main_sections.py --context 8 spend_gold upgrade

This is read-only and exists to avoid reviewing huge main.gd responses that are
truncated by external tools.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
FUNC_RE = re.compile(r"^func\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(", re.MULTILINE)


@dataclass(frozen=True)
class FunctionBlock:
    name: str
    start_line: int
    end_line: int
    lines: list[str]

    @property
    def text(self) -> str:
        return "\n".join(self.lines)


def extract_functions(text: str) -> list[FunctionBlock]:
    matches = list(FUNC_RE.finditer(text))
    all_lines = text.splitlines()
    blocks: list[FunctionBlock] = []
    for idx, match in enumerate(matches):
        start_index = match.start()
        end_index = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        start_line = text.count("\n", 0, start_index) + 1
        end_line = text.count("\n", 0, end_index) + 1
        block_lines = text[start_index:end_index].rstrip("\n").splitlines()
        blocks.append(FunctionBlock(match.group("name"), start_line, min(end_line, len(all_lines)), block_lines))
    return blocks


def matches_terms(block: FunctionBlock, terms: list[str]) -> bool:
    if not terms:
        return False
    haystack = (block.name + "\n" + block.text).lower()
    return any(term.lower() in haystack for term in terms)


def print_block(block: FunctionBlock, context: int, terms: list[str]) -> None:
    print(f"\n# {block.name} ({block.start_line}-{block.end_line})")
    print("#" + "-" * (len(block.name) + len(str(block.start_line)) + len(str(block.end_line)) + 4))
    if context <= 0:
        for offset, line in enumerate(block.lines):
            print(f"{block.start_line + offset}: {line}")
        return

    matched_offsets: set[int] = set()
    lowered_terms = [term.lower() for term in terms]
    for offset, line in enumerate(block.lines):
        line_text = line.lower()
        if any(term in line_text for term in lowered_terms):
            for selected in range(max(0, offset - context), min(len(block.lines), offset + context + 1)):
                matched_offsets.add(selected)

    previous_offset: int | None = None
    for offset in sorted(matched_offsets):
        if previous_offset is not None and offset > previous_offset + 1:
            print("...")
        print(f"{block.start_line + offset}: {block.lines[offset]}")
        previous_offset = offset


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract focused main.gd function sections.")
    parser.add_argument("terms", nargs="*", help="Terms to search for inside function bodies.")
    parser.add_argument("--context", type=int, default=0, help="Print only N lines around matching terms. Default 0 prints full matching functions.")
    parser.add_argument("--names-only", action="store_true", help="Print only matching function names and line ranges.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if not MAIN.exists():
        print(f"main.gd not found: {MAIN}", file=sys.stderr)
        return 2
    if not args.terms:
        print("Please provide at least one search term.", file=sys.stderr)
        return 2

    text = MAIN.read_text(errors="replace")
    blocks = extract_functions(text)
    matched = [block for block in blocks if matches_terms(block, args.terms)]

    print("Main Section Extractor")
    print("======================")
    print(f"File: {MAIN.relative_to(ROOT)}")
    print(f"Functions scanned: {len(blocks)}")
    print(f"Search terms: {', '.join(args.terms)}")
    print(f"Matching functions: {len(matched)}")

    if args.names_only:
        for block in matched:
            print(f"{block.name} ({block.start_line}-{block.end_line})")
        return 0

    for block in matched:
        print_block(block, args.context, args.terms)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
