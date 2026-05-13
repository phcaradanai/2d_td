#!/usr/bin/env python3
"""Audit Start Wave HUD boundary after controller/binder refactors."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
PRESENTER = ROOT / "scripts/main/hud_state_presenter.gd"
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
    presenter_text = read(PRESENTER)
    hud_text = read(HUD)

    refresh_body = function_body(main_text, "_refresh_start_wave_ui")
    presenter_body = function_body(presenter_text, "refresh_start_wave_button")
    hud_body = function_body(hud_text, "refresh_start_wave_button")

    require(errors, refresh_body != "", "main.gd missing _refresh_start_wave_ui")
    for token in [
        "can_start",
        "countdown_active",
        "countdown_remaining",
        "wave_manager.get_next_wave_number()",
        "wave_manager.get_total_waves()",
        "active_wave_number",
        "not wave_manager.has_next_wave() and not wave_manager.is_wave_running",
        "hud_state_presenter.refresh_start_wave_button",
    ]:
        require(errors, token in refresh_body, f"_refresh_start_wave_ui missing {token}")

    require(errors, "game_manager.current_wave" not in refresh_body, "_refresh_start_wave_ui must not use current wave as next wave")
    require(errors, "current_wave" not in presenter_body, "HUDStatePresenter must not derive next wave from current wave")

    require(errors, presenter_body != "", "HUDStatePresenter missing refresh_start_wave_button")
    require(errors, "hud.refresh_start_wave_button" in presenter_body, "HUDStatePresenter must call GameHUD.refresh_start_wave_button")
    for token in ["total_waves", "next_wave_number", "active_wave_number", "wave_running", "countdown_active", "countdown_remaining", "manual_first_wave"]:
        require(errors, token in presenter_body, f"HUDStatePresenter refresh_start_wave_button missing {token}")
    require(errors, "hud_wave_number = active_wave_number" in presenter_body, "HUDStatePresenter must map active wave separately while a wave is running")

    require(errors, hud_body != "", "GameHUD missing refresh_start_wave_button")
    for token in ["start_wave_button.text", "next_wave_label.text", "countdown_active", "countdown_remaining", "auto in"]:
        require(errors, token in hud_body, f"GameHUD refresh_start_wave_button missing {token}")

    print("Start Wave UI Boundary Audit")
    print("============================")
    print(f"main _refresh_start_wave_ui found: {refresh_body != ''}")
    print(f"presenter refresh_start_wave_button found: {presenter_body != ''}")
    print(f"GameHUD refresh_start_wave_button found: {hud_body != ''}")
    print(f"presenter calls GameHUD refresh: {'hud.refresh_start_wave_button' in presenter_body}")
    print(f"main uses next wave number: {'wave_manager.get_next_wave_number()' in refresh_body}")
    print(f"main uses total waves: {'wave_manager.get_total_waves()' in refresh_body}")

    print("\nResult")
    print("------")
    if errors:
        for item in errors:
            print(f"FAIL: {item}")
        return 1
    print("PASS: Start Wave HUD boundary preserves countdown and next-wave data flow.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
