#!/usr/bin/env python3
"""Guarded patcher for the main.gd tower upgrade execution path.

Default mode is dry-run. The script only writes when --write is provided and it
finds exactly one upgrade execution candidate that is missing an element gate.
It is designed to avoid risky whole-file manual edits of main.gd.
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
EXECUTION_LINE_RE = re.compile(r"(?P<prefix>^(?P<indent>[\t ]*).*(?:selected_tower|tower)\.upgrade\s*\(.*\)\s*$)")
ANY_UPGRADE_LINE_RE = re.compile(r"(?P<prefix>^(?P<indent>[\t ]*).*\.upgrade\s*\(.*\)\s*$)")
ELEMENT_GATE_RE = re.compile(
    r"element_progression_manager.*can_build_tower|can_build_tower.*element_progression_manager|"
    r"_config_unlocked_for_upgrade\s*\(|can_upgrade_selected_tower\s*\(|"
    r"is_selected_tower_next_upgrade_element_unlocked\s*\(",
    re.DOTALL,
)
SPEND_OR_MUTATE_RE = re.compile(r"\.upgrade\s*\(.*\)\s*$", re.MULTILINE)

GUARD_TEMPLATE = """{indent}# Element TD regression guard: target tower tier must be unlocked by element level.
{indent}# This intentionally checks the target upgrade config through TowerInteractionController,
{indent}# not just the current tower's can_upgrade() flag.
{indent}if not can_upgrade_selected_tower():
{indent}\tvar upgrade_preview := get_selected_tower_upgrade_preview()
{indent}\tvar locked_reason := str(upgrade_preview.get(\"locked_reason\", \"\"))
{indent}\tif locked_reason.is_empty():
{indent}\t\tlocked_reason = \"Upgrade unavailable\"
{indent}\tif game_hud and game_hud.has_method(\"set_build_status\"):
{indent}\t\tgame_hud.set_build_status(locked_reason)
{indent}\tif has_method(\"show_wave_feedback\"):
{indent}\t\tshow_wave_feedback(locked_reason, Color(1.0, 0.55, 0.2))
{indent}\treturn
"""


@dataclass(frozen=True)
class FunctionBlock:
    name: str
    start_line: int
    start_offset: int
    end_offset: int
    text: str

    @property
    def end_line(self) -> int:
        return self.start_line + len(self.text.splitlines()) - 1


def extract_functions(text: str) -> list[FunctionBlock]:
    matches = list(FUNC_RE.finditer(text))
    blocks: list[FunctionBlock] = []
    for idx, match in enumerate(matches):
        start = match.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        start_line = text.count("\n", 0, start) + 1
        blocks.append(FunctionBlock(match.group("name"), start_line, start, end, text[start:end]))
    return blocks


def is_execution_candidate(block: FunctionBlock) -> bool:
    if "upgrade" not in block.text.lower():
        return False
    if not SPEND_OR_MUTATE_RE.search(block.text):
        return False
    if EXECUTION_LINE_RE.search(block.text, re.MULTILINE):
        return True
    if ANY_UPGRADE_LINE_RE.search(block.text, re.MULTILINE):
        return True
    return False


def has_element_gate(block: FunctionBlock) -> bool:
    return ELEMENT_GATE_RE.search(block.text) is not None


def find_upgrade_line(block: FunctionBlock) -> tuple[int, str, str] | None:
    for offset, line in enumerate(block.text.splitlines()):
        exact = EXECUTION_LINE_RE.match(line)
        if exact:
            return offset, exact.group("indent"), line
    for offset, line in enumerate(block.text.splitlines()):
        generic = ANY_UPGRADE_LINE_RE.match(line)
        if generic:
            return offset, generic.group("indent"), line
    return None


def patch_block(block: FunctionBlock) -> str:
    target = find_upgrade_line(block)
    if target is None:
        raise RuntimeError(f"No upgrade line found in {block.name}")
    target_offset, indent, _line = target
    lines = block.text.splitlines()
    guard = GUARD_TEMPLATE.format(indent=indent).rstrip("\n").splitlines()
    patched = lines[:target_offset] + guard + lines[target_offset:]
    return "\n".join(patched) + ("\n" if block.text.endswith("\n") else "")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Patch main.gd upgrade execution with an element-level gate.")
    parser.add_argument("--write", action="store_true", help="Write the patch. Default is dry-run only.")
    parser.add_argument("--allow-multiple", action="store_true", help="Patch all missing-gate candidates instead of requiring exactly one.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if not MAIN.exists():
        print(f"main.gd not found: {MAIN}", file=sys.stderr)
        return 2

    text = MAIN.read_text(errors="replace")
    blocks = extract_functions(text)
    candidates = [block for block in blocks if is_execution_candidate(block)]
    missing_gate = [block for block in candidates if not has_element_gate(block)]

    print("Guarded Main Element Upgrade Gate Patcher")
    print("=========================================")
    print(f"File: {MAIN.relative_to(ROOT)}")
    print(f"Upgrade execution candidates: {len(candidates)}")
    print(f"Candidates missing element gate: {len(missing_gate)}")
    for block in candidates:
        status = "MISSING_GATE" if block in missing_gate else "has_gate"
        target = find_upgrade_line(block)
        upgrade_line = target[2].strip() if target else "<no upgrade line>"
        print(f"- {block.name} ({block.start_line}-{block.end_line}) {status}: {upgrade_line}")

    if not missing_gate:
        print("\nNo patch needed: all upgrade execution candidates already have an element gate.")
        return 0

    if len(missing_gate) != 1 and not args.allow_multiple:
        print("\nRefusing to patch: expected exactly one missing-gate candidate.")
        print("Re-run with --allow-multiple only after manually reviewing the listed candidates.")
        return 1

    patched_text = text
    for block in sorted(missing_gate, key=lambda item: item.start_offset, reverse=True):
        patched_block = patch_block(block)
        patched_text = patched_text[:block.start_offset] + patched_block + patched_text[block.end_offset:]

    if not args.write:
        print("\nDry-run only. Re-run with --write to update main.gd.")
        return 1

    MAIN.write_text(patched_text)
    print(f"\nPatched {len(missing_gate)} function(s) in {MAIN.relative_to(ROOT)}")
    print("Next checks:")
    print("- python3 tools/refactor/audit_main_tower_upgrade_flow.py")
    print("- godot --headless --path . --quit")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
