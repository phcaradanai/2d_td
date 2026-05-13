#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5h2.bak"

PRELOAD = 'const AUTO_NEXT_WAVE_SERVICE_SCRIPT = preload("res://scripts/main/auto_next_wave_service.gd")'
PRELOAD_AFTER = 'const ELEMENT_TD_INTEREST_SERVICE_SCRIPT = preload("res://scripts/main/element_td_interest_service.gd")'
PRELOAD_FALLBACK = 'const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")'
VAR_LINE = 'var auto_next_wave_service: RefCounted = null'
VAR_AFTER = 'var element_td_interest_service: ElementTDInterestService = null'
VAR_FALLBACK = 'var element_progression_manager = null'
NEXT_FUNC = "\nfunc "

BLOCKS = {
"func _configure_auto_next_wave_from_level() -> void:": '''func _configure_auto_next_wave_from_level() -> void:
	if auto_next_wave_service == null:
		auto_next_wave_service = AUTO_NEXT_WAVE_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	auto_next_wave_service.configure_from_level(level_data)
	_sync_auto_next_wave_state_from_service()
''',
"func _is_waiting_for_manual_first_wave() -> bool:": '''func _is_waiting_for_manual_first_wave() -> bool:
	if auto_next_wave_service == null or wave_manager == null:
		return false
	return auto_next_wave_service.is_waiting_for_manual_first_wave(
		wave_manager.get_next_wave_number(),
		wave_manager.is_wave_running
	)
''',
"func _maybe_start_auto_next_wave_countdown() -> void:": '''func _maybe_start_auto_next_wave_countdown() -> void:
	if auto_next_wave_service == null:
		return
	auto_next_wave_service.maybe_start_countdown(
		_can_auto_next_wave_countdown(),
		_is_waiting_for_manual_first_wave()
	)
	_sync_auto_next_wave_state_from_service()
	_refresh_start_wave_ui()
''',
"func _stop_auto_next_wave_countdown() -> void:": '''func _stop_auto_next_wave_countdown() -> void:
	if auto_next_wave_service:
		auto_next_wave_service.stop_countdown()
	_sync_auto_next_wave_state_from_service()
	_refresh_start_wave_ui()
''',
"func _update_auto_next_wave_countdown(delta: float) -> void:": '''func _update_auto_next_wave_countdown(delta: float) -> void:
	if auto_next_wave_service == null:
		return
	var should_start: bool = bool(auto_next_wave_service.tick(
		delta,
		_can_auto_next_wave_countdown(),
		get_tree().paused or _has_pending_element_pick() or current_state == GameState.PAUSED
	))
	_sync_auto_next_wave_state_from_service()
	if should_start:
		_on_start_wave_requested()
	else:
		_refresh_start_wave_ui()
'''
}

SYNC = '''func _sync_auto_next_wave_state_from_service() -> void:
	if auto_next_wave_service == null:
		return
	auto_next_wave_enabled = auto_next_wave_service.enabled
	auto_next_wave_delay_sec = auto_next_wave_service.delay_sec
	auto_next_wave_remaining = auto_next_wave_service.remaining
	auto_next_wave_countdown_active = auto_next_wave_service.countdown_active
	has_started_first_wave = auto_next_wave_service.has_started_first_wave
'''

CAN = '''func _can_auto_next_wave_countdown() -> bool:
	if current_state != GameState.BUILD and current_state != GameState.WAVE_COMPLETE:
		return false
	if wave_manager == null or wave_manager.is_wave_running or not wave_manager.has_next_wave():
		return false
	if _has_pending_element_pick():
		return false
	return true
'''

def add_after(text, marker, line):
	if line in text:
		return text
	if marker in text:
		return text.replace(marker, marker + "\n" + line, 1)
	return text

def replace_func(text, sig, body):
	start = text.find(sig)
	if start == -1:
		raise SystemExit(f"missing {sig}")
	end = text.find(NEXT_FUNC, start + len(sig))
	if end == -1:
		raise SystemExit(f"missing end for {sig}")
	return text[:start] + body.rstrip() + "\n\n" + text[end + 1:]

def insert_before(text, marker, body):
	if body.split("(", 1)[0].replace("func ", "func ") in text:
		return text
	idx = text.find(marker)
	if idx == -1:
		raise SystemExit(f"missing insertion marker {marker}")
	return text[:idx] + body.rstrip() + "\n\n" + text[idx:]

def main():
	text = MAIN.read_text()
	old = text
	text = add_after(text, PRELOAD_AFTER, PRELOAD)
	if PRELOAD not in text:
		text = add_after(text, PRELOAD_FALLBACK, PRELOAD)
	text = add_after(text, VAR_AFTER, VAR_LINE)
	if VAR_LINE not in text:
		text = add_after(text, VAR_FALLBACK, VAR_LINE)
	if 'auto_next_wave_service = AUTO_NEXT_WAVE_SERVICE_SCRIPT.new()' not in text:
		text = text.replace('_ensure_element_progression_manager()', '_ensure_element_progression_manager()\n\tif auto_next_wave_service == null:\n\t\tauto_next_wave_service = AUTO_NEXT_WAVE_SERVICE_SCRIPT.new()', 1)
	for sig, body in BLOCKS.items():
		text = replace_func(text, sig, body)
	text = insert_before(text, 'func _configure_auto_next_wave_from_level() -> void:', SYNC)
	text = insert_before(text, 'func _maybe_start_auto_next_wave_countdown() -> void:', CAN)
	BACKUP.write_text(old)
	MAIN.write_text(text)
	print('Stage 5H-2 applied')
	print('Run: godot --headless --path . --quit')

if __name__ == '__main__':
	main()
