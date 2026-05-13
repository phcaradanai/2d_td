#!/usr/bin/env python3
"""Stage 5J-2: remove Auto Next Wave legacy sync state from main.gd.

This pass keeps the AutoNextWaveService as the single runtime owner for:
- enabled/delay/countdown state
- first-wave-started state

It intentionally does not touch Element TD interest legacy state.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5j2.bak"
NEXT_FUNC = "\nfunc "

LEGACY_VAR_LINES = [
	"var auto_next_wave_enabled: bool = true\n",
	"var auto_next_wave_delay_sec: float = 15.0\n",
	"var auto_next_wave_remaining: float = 0.0\n",
	"var auto_next_wave_countdown_active: bool = false\n",
	"var has_started_first_wave: bool = false\n",
]

SYNC_SIGNATURE = "func _sync_auto_next_wave_state_from_service() -> void:"

REFRESH_SIGNATURE = "func _refresh_start_wave_ui() -> void:"
REFRESH_BODY = '''func _refresh_start_wave_ui() -> void:
	if game_hud == null or wave_manager == null:
		return
	_bind_hud_state_presenter()
	var can_start := current_state == GameState.BUILD or current_state == GameState.WAVE_COMPLETE
	can_start = can_start and wave_manager.has_next_wave()
	can_start = can_start and not wave_manager.is_wave_running
	can_start = can_start and not _has_pending_element_pick()
	var countdown_active := false
	var countdown_remaining := 0.0
	if auto_next_wave_service:
		countdown_active = bool(auto_next_wave_service.countdown_active)
		countdown_remaining = float(auto_next_wave_service.remaining)
	hud_state_presenter.refresh_start_wave_button(
		can_start,
		_is_waiting_for_manual_first_wave(),
		countdown_active,
		countdown_remaining,
		wave_manager.get_next_wave_number()
	)
'''

CONFIGURE_SIGNATURE = "func _configure_auto_next_wave_from_level() -> void:"
CONFIGURE_BODY = '''func _configure_auto_next_wave_from_level() -> void:
	if auto_next_wave_service == null:
		auto_next_wave_service = AUTO_NEXT_WAVE_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	auto_next_wave_service.configure_from_level(level_data)
'''

MAYBE_SIGNATURE = "func _maybe_start_auto_next_wave_countdown() -> void:"
MAYBE_BODY = '''func _maybe_start_auto_next_wave_countdown() -> void:
	if auto_next_wave_service == null:
		return
	auto_next_wave_service.maybe_start_countdown(
		_can_auto_next_wave_countdown(),
		_is_waiting_for_manual_first_wave()
	)
	_refresh_start_wave_ui()
'''

STOP_SIGNATURE = "func _stop_auto_next_wave_countdown() -> void:"
STOP_BODY = '''func _stop_auto_next_wave_countdown() -> void:
	if auto_next_wave_service:
		auto_next_wave_service.stop_countdown()
	_refresh_start_wave_ui()
'''

UPDATE_SIGNATURE = "func _update_auto_next_wave_countdown(delta: float) -> void:"
UPDATE_BODY = '''func _update_auto_next_wave_countdown(delta: float) -> void:
	if auto_next_wave_service == null:
		return
	var should_start: bool = bool(auto_next_wave_service.tick(
		delta,
		_can_auto_next_wave_countdown(),
		get_tree().paused or _has_pending_element_pick() or current_state == GameState.PAUSED
	))
	if should_start:
		_on_start_wave_requested()
	else:
		_refresh_start_wave_ui()
'''


def replace_func(text: str, sig: str, body: str) -> str:
	start = text.find(sig)
	if start == -1:
		raise SystemExit(f"missing {sig}")
	end = text.find(NEXT_FUNC, start + len(sig))
	if end == -1:
		raise SystemExit(f"missing end for {sig}")
	return text[:start] + body.rstrip() + "\n\n" + text[end + 1:]


def remove_func(text: str, sig: str) -> str:
	start = text.find(sig)
	if start == -1:
		return text
	end = text.find(NEXT_FUNC, start + len(sig))
	if end == -1:
		raise SystemExit(f"missing end for {sig}")
	return text[:start].rstrip() + "\n\n" + text[end + 1:]


def main() -> None:
	text = MAIN.read_text()
	old = text

	for line in LEGACY_VAR_LINES:
		text = text.replace(line, "")

	text = remove_func(text, SYNC_SIGNATURE)
	text = replace_func(text, REFRESH_SIGNATURE, REFRESH_BODY)
	text = replace_func(text, CONFIGURE_SIGNATURE, CONFIGURE_BODY)
	text = replace_func(text, MAYBE_SIGNATURE, MAYBE_BODY)
	text = replace_func(text, STOP_SIGNATURE, STOP_BODY)
	text = replace_func(text, UPDATE_SIGNATURE, UPDATE_BODY)

	text = text.replace("has_started_first_wave = false", "auto_next_wave_service.reset() if auto_next_wave_service else null")
	text = text.replace("has_started_first_wave = true", "auto_next_wave_service.mark_first_wave_started() if auto_next_wave_service else null")

	if "auto_next_wave_enabled" in text or "auto_next_wave_delay_sec" in text:
		raise SystemExit("cleanup incomplete: enabled/delay legacy names still present")
	if "auto_next_wave_remaining" in text or "auto_next_wave_countdown_active" in text:
		raise SystemExit("cleanup incomplete: countdown legacy names still present")
	if "has_started_first_wave" in text:
		raise SystemExit("cleanup incomplete: has_started_first_wave still present")

	BACKUP.write_text(old)
	MAIN.write_text(text)
	print("Stage 5J-2 applied")
	print("Run: godot --headless --path . --quit")
	print("Run: python3 tools/refactor/audit_legacy_migration_state.py")


if __name__ == "__main__":
	main()
