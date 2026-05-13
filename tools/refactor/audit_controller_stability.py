#!/usr/bin/env python3
"""Read-only stability audit for extracted main.gd controllers."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
ELEMENTAL = ROOT / "scripts/main/elemental_pick_controller.gd"
LAYOUT = ROOT / "scripts/main/gameplay_layout_controller.gd"
WAVE_FLOW = ROOT / "scripts/main/wave_flow_controller.gd"
TOWER_INTERACTION = ROOT / "scripts/main/tower_interaction_controller.gd"

MOVED_WRAPPERS = [
    "_update_world_layout",
    "_fit_map_to_playfield",
    "_get_map_content_bounds",
    "_cells_from_level_arrays",
    "_has_pending_element_pick",
    "_can_choose_interest_upgrade",
    "_format_interest_rate_percent",
    "_format_next_interest_rate_percent",
    "_on_element_choice_requested",
    "_choose_interest_upgrade_pick",
    "_is_waiting_for_manual_first_wave",
    "_can_auto_next_wave_countdown",
    "_maybe_start_auto_next_wave_countdown",
    "_stop_auto_next_wave_countdown",
    "_update_auto_next_wave_countdown",
]

FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.MULTILINE)
AMBIGUOUS_CALL_RE = re.compile(r"func\s+_call\s*\([^)]*arg1\s*:\s*Variant\s*=\s*null")
CALLV_HELPER_RE = re.compile(r"func\s+_callv\s*\(\s*callback\s*:\s*Callable\s*,\s*args\s*:\s*Array\s*=\s*\[\]")
ONE_LINE_RETURN_RE = re.compile(r"^\s*if\s+.+:\s*return(?:\s+.+)?\s*$")
PRIVATE_MAIN_CALL_RE = re.compile(r"\bmain\._[A-Za-z][A-Za-z0-9_]*\s*\(")


def read(path: Path) -> str:
    return path.read_text(errors="replace")


def function_names(text: str) -> set[str]:
    return {match.group(1) for match in FUNC_RE.finditer(text)}


def print_items(title: str, items: list[str]) -> None:
    print("\n" + title)
    print("-" * len(title))
    if not items:
        print("  none")
        return
    for item in items:
        print(f"  {item}")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    main_text = read(MAIN)
    elemental_text = read(ELEMENTAL)
    layout_lines = read(LAYOUT).splitlines()
    wave_flow_text = read(WAVE_FLOW)

    print("Controller Stability Audit")
    print("==========================")

    main_funcs = function_names(main_text)
    missing_wrappers = [name for name in MOVED_WRAPPERS if name not in main_funcs]
    for name in missing_wrappers:
        errors.append(f"missing main.gd compatibility wrapper: {name}")

    if AMBIGUOUS_CALL_RE.search(elemental_text):
        errors.append("ElementalPickController still has ambiguous _call(callback, arg1=null, arg2=null)")
    if not CALLV_HELPER_RE.search(elemental_text):
        errors.append("ElementalPickController is missing _callv(callback: Callable, args: Array = [])")
    if ".callv(" not in elemental_text:
        errors.append("ElementalPickController does not use Callable.callv")

    one_line_guards: list[str] = []
    for idx, line in enumerate(layout_lines, start=1):
        if ONE_LINE_RETURN_RE.match(line):
            one_line_guards.append(f"{LAYOUT.relative_to(ROOT)}:{idx}: {line.strip()}")
    for item in one_line_guards:
        warnings.append(f"one-line return guard remains: {item}")

    wave_funcs = function_names(wave_flow_text)
    if "has_required_dependencies" not in wave_funcs:
        warnings.append("WaveFlowController does not expose has_required_dependencies()")
    if "is_bound" not in wave_funcs:
        warnings.append("WaveFlowController does not expose is_bound()")

    tower_text = read(TOWER_INTERACTION)
    tower_funcs = function_names(tower_text)
    if "is_bound" not in tower_funcs:
        warnings.append("TowerInteractionController does not expose is_bound()")

    direct_private_calls: list[str] = []
    for path in [ELEMENTAL, LAYOUT, WAVE_FLOW, TOWER_INTERACTION]:
        for idx, line in enumerate(read(path).splitlines(), start=1):
            if PRIVATE_MAIN_CALL_RE.search(line):
                direct_private_calls.append(f"{path.relative_to(ROOT)}:{idx}: {line.strip()}")
    for item in direct_private_calls:
        warnings.append(f"direct main private call from controller: {item}")

    print(f"Main wrappers checked: {len(MOVED_WRAPPERS)}")
    print(f"ElementalPickController uses callv: {'.callv(' in elemental_text}")
    print(f"GameplayLayoutController one-line return guards: {len(one_line_guards)}")
    print(f"WaveFlowController has_required_dependencies: {'has_required_dependencies' in wave_funcs}")
    print(f"WaveFlowController is_bound: {'is_bound' in wave_funcs}")
    print(f"Direct main private calls: {len(direct_private_calls)}")

    print_items("Warnings", [f"WARN: {item}" for item in warnings])

    print("\nResult")
    print("------")
    if errors:
        for item in errors:
            print(f"  FAIL: {item}")
        return 1
    print("  PASS: controller stability checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
