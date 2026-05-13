#!/usr/bin/env python3
"""Stage 5N-2: route core HUD stats through HUDStatePresenter.

This is a small boundary cleanup. It keeps main.gd as the owner of the presenter
binding, but moves gold/lives/wave refresh calls behind HUDStatePresenter.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5n2.bak"
NEXT_FUNC = "\nfunc "

TARGET_SIG = "func _refresh_hud_stats() -> void:"
TARGET_BODY = '''func _refresh_hud_stats() -> void:
	if game_hud == null or game_manager == null:
		return
	_bind_hud_state_presenter()
	var total_waves := 0
	if wave_manager:
		total_waves = wave_manager.get_total_waves()
	hud_state_presenter.refresh_core_stats(
		int(game_manager.gold),
		int(game_manager.lives),
		int(game_manager.current_wave),
		total_waves
	)
'''


def replace_func(text: str, sig: str, body: str) -> str:
	start = text.find(sig)
	if start == -1:
		raise SystemExit(f"missing {sig}")
	end = text.find(NEXT_FUNC, start + len(sig))
	if end == -1:
		raise SystemExit(f"missing end for {sig}")
	return text[:start] + body.rstrip() + "\n\n" + text[end + 1:]


def main() -> None:
	text = MAIN.read_text()
	old = text
	text = replace_func(text, TARGET_SIG, TARGET_BODY)
	if "game_hud.set_gold(game_manager.gold)" in text:
		raise SystemExit("direct set_gold call remains in _refresh_hud_stats")
	if "game_hud.set_lives(game_manager.lives)" in text:
		raise SystemExit("direct set_lives call remains in _refresh_hud_stats")
	if "game_hud.set_wave(game_manager.current_wave)" in text:
		raise SystemExit("direct set_wave call remains in _refresh_hud_stats")
	if "hud_state_presenter.refresh_core_stats" not in text:
		raise SystemExit("core stats were not rewired to HUDStatePresenter")
	BACKUP.write_text(old)
	MAIN.write_text(text)
	print("Stage 5N-2 applied")
	print("Run: python3 tools/refactor/audit_hud_presenter_boundary.py")
	print("Run: godot --headless --path . --quit")


if __name__ == "__main__":
	main()
