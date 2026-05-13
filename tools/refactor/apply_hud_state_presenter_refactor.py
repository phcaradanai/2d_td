#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5i2.bak"

PRELOAD = 'const HUD_STATE_PRESENTER_SCRIPT = preload("res://scripts/main/hud_state_presenter.gd")'
PRELOAD_AFTER = 'const AUTO_NEXT_WAVE_SERVICE_SCRIPT = preload("res://scripts/main/auto_next_wave_service.gd")'
PRELOAD_FALLBACK = 'const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")'
VAR_LINE = 'var hud_state_presenter: RefCounted = null'
VAR_AFTER = 'var auto_next_wave_service: RefCounted = null'
VAR_FALLBACK = 'var element_progression_manager = null'
NEXT_FUNC = "\nfunc "

BIND_FUNC = '''func _bind_hud_state_presenter() -> void:
	if hud_state_presenter == null:
		hud_state_presenter = HUD_STATE_PRESENTER_SCRIPT.new()
	if game_hud:
		hud_state_presenter.bind(game_hud)
'''

REFRESH_START = '''func _refresh_start_wave_ui() -> void:
	if game_hud == null or wave_manager == null:
		return
	_bind_hud_state_presenter()
	var can_start := current_state == GameState.BUILD or current_state == GameState.WAVE_COMPLETE
	can_start = can_start and wave_manager.has_next_wave()
	can_start = can_start and not wave_manager.is_wave_running
	can_start = can_start and not _has_pending_element_pick()
	hud_state_presenter.refresh_start_wave_button(
		can_start,
		_is_waiting_for_manual_first_wave(),
		auto_next_wave_countdown_active,
		auto_next_wave_remaining,
		wave_manager.get_next_wave_number()
	)
'''

SHOW_FEEDBACK = '''func show_wave_feedback(message: String, color: Color = Color(0.85, 0.95, 1.0)) -> void:
	_bind_hud_state_presenter()
	if hud_state_presenter:
		hud_state_presenter.show_wave_feedback(message, color)
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
	name = body.split("(", 1)[0].strip()
	if name in text:
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
	text = insert_before(text, 'func _refresh_start_wave_ui() -> void:', BIND_FUNC)
	text = replace_func(text, 'func _refresh_start_wave_ui() -> void:', REFRESH_START)
	if 'func show_wave_feedback(message: String' in text:
		text = replace_func(text, 'func show_wave_feedback(message: String', SHOW_FEEDBACK)
	BACKUP.write_text(old)
	MAIN.write_text(text)
	print('Stage 5I-2 applied')
	print('Run: godot --headless --path . --quit')

if __name__ == '__main__':
	main()
