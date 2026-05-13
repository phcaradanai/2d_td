#!/usr/bin/env python3
"""Audit extracted main.gd controller wrappers and controller boundaries.

This script is intentionally read-only. It fails for missing or bloated
compatibility wrappers, and reports transitional owner/main usage so the next
refactor pass can tighten boundaries without guessing.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
CONTROLLERS = [
    ROOT / "scripts/main/gameplay_layout_controller.gd",
    ROOT / "scripts/main/elemental_pick_controller.gd",
    ROOT / "scripts/main/wave_flow_controller.gd",
]

MAX_WRAPPER_LINES = 8
WARN_CONTROLLER_LINES = 400
FAIL_CONTROLLER_LINES = 700

WRAPPERS = {
    "_update_world_layout": "_get_gameplay_layout_controller().update_world_layout",
    "_fit_map_to_playfield": "_get_gameplay_layout_controller().fit_map_to_playfield",
    "_get_map_content_bounds": "_get_gameplay_layout_controller().get_map_content_bounds",
    "_cells_from_level_arrays": "_get_gameplay_layout_controller().cells_from_level_arrays",
    "_has_pending_element_pick": "_get_elemental_pick_controller().has_pending_element_pick",
    "_can_choose_interest_upgrade": "_get_elemental_pick_controller().can_choose_interest_upgrade",
    "_format_interest_rate_percent": "_get_elemental_pick_controller().format_interest_rate_percent",
    "_format_next_interest_rate_percent": "_get_elemental_pick_controller().format_next_interest_rate_percent",
    "_on_element_choice_requested": "_get_elemental_pick_controller().on_element_choice_requested",
    "_choose_interest_upgrade_pick": "_get_elemental_pick_controller().choose_interest_upgrade_pick",
    "_is_waiting_for_manual_first_wave": "_get_wave_flow_controller().is_waiting_for_manual_first_wave",
    "_can_auto_next_wave_countdown": "_get_wave_flow_controller().can_auto_next_wave_countdown",
    "_maybe_start_auto_next_wave_countdown": "_get_wave_flow_controller().maybe_start_auto_next_wave_countdown",
    "_stop_auto_next_wave_countdown": "_get_wave_flow_controller().stop_auto_next_wave_countdown",
    "_update_auto_next_wave_countdown": "_get_wave_flow_controller().update_auto_next_wave_countdown",
}

FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
MAIN_PRIVATE_CALL_RE = re.compile(r"\bmain\._[A-Za-z][A-Za-z0-9_]*\s*\(")
MAIN_PRIVATE_CALLABLE_RE = re.compile(r"Callable\s*\(\s*main\s*,\s*\"_[A-Za-z][A-Za-z0-9_]*\"")
MAIN_ACCESS_RE = re.compile(r"\bmain\.")


@dataclass(frozen=True)
class FunctionBlock:
    name: str
    start_line: int
    lines: list[str]

    @property
    def non_empty_lines(self) -> list[str]:
        return [line for line in self.lines if line.strip()]


def read_lines(path: Path) -> list[str]:
    return path.read_text(errors="replace").splitlines()


def collect_functions(lines: list[str]) -> dict[str, FunctionBlock]:
    funcs: dict[str, FunctionBlock] = {}
    current_name = ""
    current_start = 0
    current_lines: list[str] = []

    for idx, line in enumerate(lines, start=1):
        match = FUNC_RE.match(line)
        if match:
            if current_name:
                funcs[current_name] = FunctionBlock(current_name, current_start, current_lines)
            current_name = match.group(1)
            current_start = idx
            current_lines = [line]
        elif current_name:
            current_lines.append(line)

    if current_name:
        funcs[current_name] = FunctionBlock(current_name, current_start, current_lines)
    return funcs


def audit_wrappers() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    funcs = collect_functions(read_lines(MAIN))

    print("Wrapper audit")
    print("-------------")
    for wrapper, expected_delegate in WRAPPERS.items():
        block = funcs.get(wrapper)
        if block is None:
            errors.append(f"missing wrapper: {wrapper}")
            print(f"  FAIL {wrapper}: missing")
            continue

        body_text = "\n".join(block.lines)
        non_empty_count = len(block.non_empty_lines)
        has_delegate = expected_delegate in body_text
        status = "PASS" if non_empty_count <= MAX_WRAPPER_LINES and has_delegate else "FAIL"
        print(f"  {status} {wrapper}: lines={non_empty_count} delegate={has_delegate}")
        if non_empty_count > MAX_WRAPPER_LINES:
            errors.append(f"{wrapper} has {non_empty_count} non-empty lines; expected <= {MAX_WRAPPER_LINES}")
        if not has_delegate:
            errors.append(f"{wrapper} does not delegate to {expected_delegate}")

    return errors, warnings


def audit_controllers() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    print("\nController boundary audit")
    print("-------------------------")
    for path in CONTROLLERS:
        rel = path.relative_to(ROOT)
        lines = read_lines(path)
        line_count = len(lines)
        if line_count > FAIL_CONTROLLER_LINES:
            errors.append(f"{rel} has {line_count} lines; split before continuing")
        elif line_count > WARN_CONTROLLER_LINES:
            warnings.append(f"{rel} has {line_count} lines; watch for dumping-ground growth")

        private_calls: list[str] = []
        private_callables: list[str] = []
        main_accesses: list[str] = []
        for idx, line in enumerate(lines, start=1):
            stripped = line.strip()
            if MAIN_PRIVATE_CALL_RE.search(line):
                private_calls.append(f"{rel}:{idx}: {stripped}")
            if MAIN_PRIVATE_CALLABLE_RE.search(line):
                private_callables.append(f"{rel}:{idx}: {stripped}")
            if MAIN_ACCESS_RE.search(line):
                main_accesses.append(f"{rel}:{idx}: {stripped}")

        print(f"  {rel}: lines={line_count} main_access={len(main_accesses)} private_calls={len(private_calls)} private_callables={len(private_callables)}")
        for item in private_calls:
            warnings.append(f"direct private main call: {item}")
        for item in private_callables:
            warnings.append(f"private main Callable binding: {item}")
        if main_accesses and not private_calls and not private_callables:
            warnings.append(f"{rel} still has transitional main access; prefer explicit bind deps")

    return errors, warnings


def main() -> int:
    print("Main Thin Wrapper Audit")
    print("=======================")
    wrapper_errors, wrapper_warnings = audit_wrappers()
    controller_errors, controller_warnings = audit_controllers()
    errors = wrapper_errors + controller_errors
    warnings = wrapper_warnings + controller_warnings

    print("\nWarnings")
    print("--------")
    if warnings:
        for item in warnings:
            print(f"  WARN: {item}")
    else:
        print("  none")

    print("\nResult")
    print("------")
    if errors:
        for item in errors:
            print(f"  FAIL: {item}")
        return 1
    print("  PASS: wrappers are thin and required compatibility methods remain.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
