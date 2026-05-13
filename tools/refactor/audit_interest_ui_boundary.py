#!/usr/bin/env python3
"""Audit Element/Interest choice HUD boundary after controller/binder refactors."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
ELEMENTAL = ROOT / "scripts/main/elemental_pick_controller.gd"
INTEREST_SERVICE = ROOT / "scripts/main/element_td_interest_service.gd"
BINDER = ROOT / "scripts/main/gameplay_controller_binder.gd"
HUD = ROOT / "scripts/ui/game_hud.gd"

FUNC_RE_TEMPLATE = r"func\s+{name}\s*\([^)]*\)\s*(?:->\s*[A-Za-z0-9_\[\]]+\s*)?:([\s\S]*?)(?=\nfunc\s+|\Z)"


def read(path: Path) -> str:
    return path.read_text(errors="replace")


def function_body(text: str, name: str) -> str:
    match = re.search(FUNC_RE_TEMPLATE.format(name=re.escape(name)), text)
    return match.group(1) if match else ""


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []

    main_text = read(MAIN)
    elemental_text = read(ELEMENTAL)
    interest_text = read(INTEREST_SERVICE)
    binder_text = read(BINDER)
    hud_text = read(HUD)

    show_choice_body = function_body(main_text, "_show_pending_element_choice")
    hud_choice_body = function_body(hud_text, "show_element_choice")
    binder_passes_interest_service = '"interest_service": main.element_td_interest_service' in binder_text

    for method in [
        "format_interest_rate_percent",
        "format_next_interest_rate_percent",
        "can_choose_interest_upgrade",
        "choose_interest_upgrade_pick",
    ]:
        require(errors, f"func {method}" in elemental_text, f"ElementalPickController missing {method}")

    for token in [
        "game_hud.show_element_choice",
        "_format_interest_rate_percent()",
        "_format_next_interest_rate_percent()",
        "_can_choose_interest_upgrade()",
        "upgrade_count",
        "max_upgrades",
    ]:
        require(errors, token in show_choice_body, f"_show_pending_element_choice missing {token}")

    require(errors, "func show_element_choice" in hud_text, "GameHUD missing show_element_choice")
    for token in ["Interest  %s", "interest_rate_label", "next_interest_rate_label", "interest_upgrade_count", "interest_max_upgrades", "__interest__"]:
        require(errors, token in hud_choice_body, f"GameHUD show_element_choice missing {token}")

    require(errors, "func format_rate_percent" in interest_text, "ElementTDInterestService missing format_rate_percent")
    require(errors, "func format_next_rate_percent" in interest_text, "ElementTDInterestService missing format_next_rate_percent")
    require(errors, binder_passes_interest_service, "binder must pass interest service explicitly")
    require(errors, '"interest_pick_id": INTEREST_PICK_ID' in binder_text, "binder must pass interest pick id explicitly")
    require(errors, '"default_interest_upgrade_step": DEFAULT_INTEREST_UPGRADE_STEP' in binder_text, "binder must pass default interest step explicitly")

    print("Interest UI Boundary Audit")
    print("==========================")
    print(f"main _show_pending_element_choice found: {show_choice_body != ''}")
    print(f"GameHUD show_element_choice found: {hud_choice_body != ''}")
    print(f"ElementalPickController interest formatters: {'format_interest_rate_percent' in elemental_text and 'format_next_interest_rate_percent' in elemental_text}")
    print(f"binder passes interest service: {binder_passes_interest_service}")

    print("\nResult")
    print("------")
    if errors:
        for item in errors:
            print(f"FAIL: {item}")
        return 1
    print("PASS: Interest choice HUD boundary preserves current/next rates and upgrade counts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
