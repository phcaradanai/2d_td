#!/usr/bin/env python3
"""Audit the current small main.gd split patch."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BINDER = ROOT / "scripts/main/gameplay_controller_binder.gd"
TOWER_CONTROLLER = ROOT / "scripts/main/tower_interaction_controller.gd"

MAX_BINDER_LINES = 180
MAX_GETTER_LINES = 5

GETTERS = {
    "_get_gameplay_layout_controller": "_get_gameplay_controller_binder().get_gameplay_layout_controller",
    "_get_elemental_pick_controller": "_get_gameplay_controller_binder().get_elemental_pick_controller",
    "_get_wave_flow_controller": "_get_gameplay_controller_binder().get_wave_flow_controller",
}

GENERIC_DUMP_NAMES = {
    "utils.gd",
    "helpers.gd",
    "controller_utils.gd",
    "main_utils.gd",
}

FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
MAIN_PRIVATE_CALL_RE = re.compile(r"\bmain\._[A-Za-z][A-Za-z0-9_]*\s*\(")


def read_lines(path: Path) -> list[str]:
    return path.read_text(errors="replace").splitlines()


def collect_functions(lines: list[str]) -> dict[str, list[str]]:
    funcs: dict[str, list[str]] = {}
    current_name = ""
    current_lines: list[str] = []
    for line in lines:
        match = FUNC_RE.match(line)
        if match:
            if current_name:
                funcs[current_name] = current_lines
            current_name = match.group(1)
            current_lines = [line]
        elif current_name:
            current_lines.append(line)
    if current_name:
        funcs[current_name] = current_lines
    return funcs


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    print("Main Small Split Audit")
    print("======================")

    main_lines = read_lines(MAIN)
    main_funcs = collect_functions(main_lines)
    for getter, delegate in GETTERS.items():
        block = main_funcs.get(getter, [])
        non_empty = [line for line in block if line.strip()]
        has_delegate = delegate in "\n".join(block)
        print(f"{getter}: lines={len(non_empty)} delegate={has_delegate}")
        if not block:
            errors.append(f"missing main.gd getter: {getter}")
        if len(non_empty) > MAX_GETTER_LINES:
            errors.append(f"{getter} has {len(non_empty)} non-empty lines; expected <= {MAX_GETTER_LINES}")
        if not has_delegate:
            errors.append(f"{getter} does not delegate through GameplayControllerBinder")

    if not BINDER.exists():
        errors.append("missing gameplay_controller_binder.gd")
    else:
        binder_lines = read_lines(BINDER)
        print(f"gameplay_controller_binder.gd lines={len(binder_lines)}")
        if len(binder_lines) > MAX_BINDER_LINES:
            errors.append(f"gameplay_controller_binder.gd has {len(binder_lines)} lines; expected <= {MAX_BINDER_LINES}")
        private_calls = []
        for idx, line in enumerate(binder_lines, start=1):
            if MAIN_PRIVATE_CALL_RE.search(line):
                private_calls.append(f"{idx}: {line.strip()}")
        print(f"binder direct main private calls={len(private_calls)}")
        for item in private_calls:
            warnings.append(f"binder direct private call: {item}")

    tower_status = subprocess.run(
        ["git", "status", "--short", "--", str(TOWER_CONTROLLER.relative_to(ROOT))],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    ).stdout.strip()
    if tower_status:
        errors.append("tower_interaction_controller.gd changed in this patch; this small split must not extract TowerInteractionController")

    generic_files = sorted(path.name for path in (ROOT / "scripts/main").glob("*.gd") if path.name in GENERIC_DUMP_NAMES)
    if generic_files:
        errors.append("generic dumping-ground helper file(s) found: " + ", ".join(generic_files))

    print("\nWarnings")
    print("--------")
    if warnings:
        for item in warnings:
            print(f"WARN: {item}")
    else:
        print("none")

    print("\nResult")
    print("------")
    if errors:
        for item in errors:
            print(f"FAIL: {item}")
        return 1
    print("PASS: small split remains focused and TowerInteractionController was not extracted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
