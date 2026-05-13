#!/usr/bin/env python3
"""Audit top bar HUD label ownership after controller/binder refactors."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
PRESENTER = ROOT / "scripts/main/hud_state_presenter.gd"
HUD = ROOT / "scripts/ui/game_hud.gd"
INTEREST = ROOT / "scripts/main/element_td_interest_service.gd"

FUNC_RE_TEMPLATE = r"func\s+{name}\s*\([^)]*\)\s*(?:->\s*[A-Za-z0-9_\[\], ]+\s*)?:([\s\S]*?)(?=\nfunc\s+|\Z)"


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
    presenter_text = read(PRESENTER)
    hud_text = read(HUD)
    interest_text = read(INTEREST)

    refresh_body = function_body(main_text, "_refresh_start_wave_ui")
    current_wave_body = function_body(hud_text, "set_current_wave")
    next_wave_body = function_body(hud_text, "set_next_wave_preview")
    status_body = function_body(hud_text, "set_gameplay_status")
    action_body = function_body(hud_text, "set_start_wave_action_state")
    interest_body = function_body(hud_text, "set_interest_status")
    presenter_body = function_body(presenter_text, "refresh_start_wave_button")

    for method in [
        "set_current_wave",
        "set_next_wave_preview",
        "set_gameplay_status",
        "set_start_wave_action_state",
        "set_interest_status",
    ]:
        require(errors, f"func {method}" in hud_text, f"GameHUD missing {method}")

    for token in [
        "current_wave",
        "total_waves",
        "next_wave_number",
        "next_wave_name",
        "gameplay_status",
        "countdown_active",
        "countdown_remaining",
        "interest_status_text",
    ]:
        require(errors, token in refresh_body, f"_refresh_start_wave_ui missing {token}")

    for token in [
        "hud.set_current_wave",
        "hud.set_next_wave_preview",
        "hud.set_gameplay_status",
        "hud.set_start_wave_action_state",
        "hud.set_interest_status",
    ]:
        require(errors, token in presenter_body, f"HUDStatePresenter does not call {token}")

    require(errors, "wave_label.text" in current_wave_body, "set_current_wave must own wave_label")
    require(errors, "Wave: %d/%d" in current_wave_body, "current wave label should show progress only")
    require(errors, "wave_name" not in current_wave_body, "current wave label must not include wave name")

    require(errors, "next_wave_label.text" in next_wave_body, "set_next_wave_preview must own next_wave_label")
    require(errors, "Next: Wave %d" in next_wave_body, "next wave label should preview next wave")
    require(errors, "Next: None" in next_wave_body, "next wave label should handle no next wave")
    require(errors, "active" not in next_wave_body.lower(), "next wave label must not show active-wave status")

    require(errors, "func set_gameplay_status" in hud_text and "set_status(message" in hud_text, "set_gameplay_status should delegate to status label")
    require(errors, 'game_hud.set_status("Wave %d:' not in main_text, "main.gd must not put wave preview text in status label")
    require(errors, 'game_hud.set_status("Wave %d cleared' not in main_text, "main.gd must not put reward preview text in status label")

    require(errors, "start_wave_button.text" in action_body, "set_start_wave_action_state must own StartWaveButton text")
    require(errors, "Auto %ds" in action_body, "StartWaveButton should show auto countdown action")
    require(errors, "In Progress" in action_body, "StartWaveButton should show running state")
    require(errors, "StartWaveCountdownBadge" in hud_text, "countdown badge support missing")
    require(errors, "_set_start_wave_countdown_badge(true" in action_body, "countdown badge must be shown during auto-next countdown")

    require(errors, "InterestStatusLabel" in hud_text, "interest status label support missing")
    require(errors, "interest_status_label.text" in interest_body, "set_interest_status must write interest label")
    for method in [
        "get_current_rate_percent_label",
        "get_interval_seconds",
        "estimate_interest_gold",
        "format_status",
    ]:
        require(errors, f"func {method}" in interest_text, f"ElementTDInterestService missing {method}")

    print("Top Bar HUD Boundary Audit")
    print("==========================")
    print(f"GameHUD explicit current wave method: {'func set_current_wave' in hud_text}")
    print(f"GameHUD explicit next wave method: {'func set_next_wave_preview' in hud_text}")
    print(f"GameHUD interest status method: {'func set_interest_status' in hud_text}")
    print(f"Countdown badge support: {'StartWaveCountdownBadge' in hud_text}")
    print(f"Presenter uses explicit HUD boundary: {'hud.set_next_wave_preview' in presenter_body}")

    print("\nResult")
    print("------")
    if errors:
        for item in errors:
            print(f"FAIL: {item}")
        return 1
    print("PASS: top bar labels have separated wave, status, action, and interest responsibilities.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
