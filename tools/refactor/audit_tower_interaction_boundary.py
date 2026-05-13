#!/usr/bin/env python3
"""Read-only audit for tower interaction extraction from main.gd."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
CONTROLLER = ROOT / "scripts/main/tower_interaction_controller.gd"
BINDER = ROOT / "scripts/main/gameplay_controller_binder.gd"

TOWER_KEYWORDS = [
    "selected_tower",
    "show_tower_info",
    "hide_tower_info",
    "Upgrade unavailable",
    "Tower Upgraded!",
    "Not enough gold!",
    "Tower sold",
    "_locked_upgrade_reason",
]

EXPECTED_CONTROLLER_METHODS = [
    "bind",
    "clear",
    "is_bound",
    "has_selected_tower",
    "set_selected_tower",
    "clear_selected_tower",
    "get_selected_tower",
    "get_selected_tower_info",
    "can_show_selected_tower_info",
    "can_hide_selected_tower_info",
    "get_selected_tower_display_name",
    "can_upgrade_selected_tower",
    "can_sell_selected_tower",
    "get_selected_tower_sell_value",
    "get_selected_tower_upgrade_cost",
    "get_current_gold",
    "can_afford_selected_tower_upgrade",
    "get_selected_tower_upgrade_missing_gold",
    "get_selected_tower_upgrade_preview",
    "get_selected_tower_action_state",
    "has_refresh_hud_callback",
    "has_refresh_tower_shop_callback",
    "has_show_wave_feedback_callback",
]

EXPECTED_MAIN_BINDING_MARKERS = [
    "_get_tower_interaction_controller",
]

EXPECTED_BINDER_MARKERS = [
    "TOWER_INTERACTION_CONTROLLER_SCRIPT",
    "tower_interaction_controller",
    "get_tower_interaction_controller",
]

FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.MULTILINE)
DIRECT_TOWER_INFO_RE = re.compile(r"\bgame_hud\.(show_tower_info|hide_tower_info)\s*\(")
DIRECT_TOWER_STATUS_RE = re.compile(r"\bgame_hud\.set_build_status\s*\((.*(?:Tower|Upgrade|gold|Selected|None).*)")
TOWER_INFO_METHOD_RE = re.compile(r"func\s+get_selected_tower_info\s*\(\)\s*->\s*Dictionary")
ACTION_STATE_METHOD_RE = re.compile(r"func\s+get_selected_tower_action_state\s*\(\)\s*->\s*Dictionary")


def read(path: Path) -> str:
    return path.read_text(errors="replace")


def function_names(text: str) -> set[str]:
    return {match.group(1) for match in FUNC_RE.finditer(text)}


def lines_matching(text: str, predicate) -> list[str]:
    matches: list[str] = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if predicate(line):
            matches.append(f"main.gd:{idx}: {line.strip()}")
    return matches


def print_group(title: str, items: list[str], limit: int = 40) -> None:
    print("\n" + title)
    print("-" * len(title))
    if not items:
        print("  none")
        return
    for item in items[:limit]:
        print(f"  {item}")
    if len(items) > limit:
        print(f"  ... {len(items) - limit} more")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    main_text = read(MAIN)
    controller_text = read(CONTROLLER)
    controller_funcs = function_names(controller_text)
    binder_text = read(BINDER) if BINDER.exists() else ""

    missing_methods = [name for name in EXPECTED_CONTROLLER_METHODS if name not in controller_funcs]
    for name in missing_methods:
        errors.append(f"TowerInteractionController missing method: {name}")

    if not TOWER_INFO_METHOD_RE.search(controller_text):
        errors.append("TowerInteractionController get_selected_tower_info() must return Dictionary")

    if not ACTION_STATE_METHOD_RE.search(controller_text):
        errors.append("TowerInteractionController get_selected_tower_action_state() must return Dictionary")

    missing_main_markers = [marker for marker in EXPECTED_MAIN_BINDING_MARKERS if marker not in main_text]
    for marker in missing_main_markers:
        warnings.append(f"main.gd has not bound TowerInteractionController yet: {marker}")

    missing_binder_markers = [marker for marker in EXPECTED_BINDER_MARKERS if marker not in binder_text]
    for marker in missing_binder_markers:
        warnings.append(f"gameplay_controller_binder.gd is missing tower interaction marker: {marker}")

    keyword_lines = lines_matching(
        main_text,
        lambda line: any(keyword in line for keyword in TOWER_KEYWORDS),
    )
    direct_info_lines = lines_matching(
        main_text,
        lambda line: DIRECT_TOWER_INFO_RE.search(line) is not None,
    )
    direct_status_lines = lines_matching(
        main_text,
        lambda line: DIRECT_TOWER_STATUS_RE.search(line) is not None,
    )

    if len(direct_info_lines) > 0:
        warnings.append("direct tower info HUD calls still exist in main.gd")
    if len(direct_status_lines) > 0:
        warnings.append("direct tower status HUD calls still exist in main.gd")

    print("Tower Interaction Boundary Audit")
    print("================================")
    print(f"Controller methods: {len(controller_funcs)}")
    print(f"Tower info helpers present: {all(name in controller_funcs for name in EXPECTED_CONTROLLER_METHODS[-7:])}")
    print(f"Tower action state helper present: {'get_selected_tower_action_state' in controller_funcs}")
    print(f"Main binding markers present: {len(EXPECTED_MAIN_BINDING_MARKERS) - len(missing_main_markers)}/{len(EXPECTED_MAIN_BINDING_MARKERS)}")
    print(f"Binder tower interaction markers present: {len(EXPECTED_BINDER_MARKERS) - len(missing_binder_markers)}/{len(EXPECTED_BINDER_MARKERS)}")
    print(f"Tower keyword lines in main.gd: {len(keyword_lines)}")
    print(f"Direct tower info HUD calls: {len(direct_info_lines)}")
    print(f"Direct tower status HUD calls: {len(direct_status_lines)}")

    print_group("Tower-related main.gd lines", keyword_lines)
    print_group("Direct tower info HUD calls", direct_info_lines)
    print_group("Direct tower status HUD calls", direct_status_lines)

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
    print("  PASS: tower interaction controller boundary is ready.")
    print("  NEXT: migrate tower action methods (upgrade, sell, placement) out of main.gd into TowerInteractionController.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
