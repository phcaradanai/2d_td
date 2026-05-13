#!/usr/bin/env python3
"""Stage 5K-1: safely rewire Element TD interest logic to ElementTDInterestService.

This pass makes the service the source of truth, but keeps legacy fields synced
for old HUD/detail panel call sites that still read them. Cleanup happens in a
later stage after audit confirms those legacy reads are gone.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5k1.bak"
NEXT_FUNC = "\nfunc "

PRELOAD = 'const ELEMENT_TD_INTEREST_SERVICE_SCRIPT = preload("res://scripts/main/element_td_interest_service.gd")'
PRELOAD_AFTER = 'const ELEMENTAL_SHOP_SERVICE_SCRIPT = preload("res://scripts/main/elemental_shop_service.gd")'
PRELOAD_FALLBACK = 'const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")'
VAR_LINE = 'var element_td_interest_service: RefCounted = null'
VAR_AFTER = 'var auto_next_wave_service: RefCounted = null'
VAR_FALLBACK = 'var element_progression_manager = null'

SYNC_FUNC = '''func _sync_interest_state_from_service() -> void:
	if element_td_interest_service == null:
		return
	element_td_interest_enabled = bool(element_td_interest_service.enabled)
	element_td_interest_base_rate = float(element_td_interest_service.base_rate)
	element_td_interest_rate = float(element_td_interest_service.rate)
	element_td_interest_upgrade_step = float(element_td_interest_service.upgrade_step)
	element_td_interest_upgrade_count = int(element_td_interest_service.upgrade_count)
	element_td_interest_max_upgrades = int(element_td_interest_service.max_upgrades)
	element_td_interest_interval_sec = float(element_td_interest_service.interval_sec)
	element_td_interest_elapsed = float(element_td_interest_service.elapsed)
	element_td_interest_disabled_for_wave = bool(element_td_interest_service.disabled_for_wave)
'''

CONFIGURE_SIG = "func _configure_element_td_interest_from_level() -> void:"
CONFIGURE_BODY = '''func _configure_element_td_interest_from_level() -> void:
	if element_td_interest_service == null:
		element_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	element_td_interest_service.configure_from_level(level_data)
	_sync_interest_state_from_service()
'''

RECALC_SIG = "func _recalculate_element_td_interest_rate() -> void:"
RECALC_BODY = '''func _recalculate_element_td_interest_rate() -> void:
	if element_td_interest_service == null:
		element_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()
	element_td_interest_service.recalculate_rate()
	_sync_interest_state_from_service()
'''

FORMAT_SIG = "func _format_interest_rate_percent() -> String:"
FORMAT_BODY = '''func _format_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_rate_percent()
	return "%.0f%%" % (element_td_interest_rate * 100.0)
'''

FORMAT_NEXT_SIG = "func _format_next_interest_rate_percent() -> String:"
FORMAT_NEXT_BODY = '''func _format_next_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_next_rate_percent()
	return "%.0f%%" % ((element_td_interest_rate + element_td_interest_upgrade_step) * 100.0)
'''

CAN_SIG = "func _can_choose_interest_upgrade() -> bool:"
CAN_BODY = '''func _can_choose_interest_upgrade() -> bool:
	if element_td_interest_service:
		return element_td_interest_service.can_choose_upgrade()
	return element_td_interest_enabled and element_td_interest_upgrade_step > 0.0 and element_td_interest_upgrade_count < element_td_interest_max_upgrades
'''

UPDATE_SIG = "func _update_element_td_interest(delta: float) -> void:"
UPDATE_BODY = '''func _update_element_td_interest(delta: float) -> void:
	if element_td_interest_service == null:
		return
	var active_enemy_count := 0
	if enemy_manager:
		active_enemy_count = enemy_manager.get_active_enemy_count()
	var interest_gold: int = int(element_td_interest_service.tick(
		delta,
		game_manager.gold if game_manager else 0,
		active_enemy_count,
		current_state == GameState.WAVE and not get_tree().paused
	))
	_sync_interest_state_from_service()
	if interest_gold <= 0:
		return
	if game_manager:
		game_manager.add_gold(interest_gold)
	if game_hud:
		game_hud.show_floating_text("+%d interest" % interest_gold)
'''


def add_after(text: str, marker: str, line: str) -> str:
	if line in text:
		return text
	if marker in text:
		return text.replace(marker, marker + "\n" + line, 1)
	return text


def insert_before(text: str, marker: str, body: str) -> str:
	name = body.split("(", 1)[0].strip()
	if name in text:
		return text
	idx = text.find(marker)
	if idx == -1:
		raise SystemExit(f"missing insertion marker {marker}")
	return text[:idx] + body.rstrip() + "\n\n" + text[idx:]


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

	text = add_after(text, PRELOAD_AFTER, PRELOAD)
	if PRELOAD not in text:
		text = add_after(text, PRELOAD_FALLBACK, PRELOAD)
	text = add_after(text, VAR_AFTER, VAR_LINE)
	if VAR_LINE not in text:
		text = add_after(text, VAR_FALLBACK, VAR_LINE)

	text = insert_before(text, CONFIGURE_SIG, SYNC_FUNC)
	text = replace_func(text, CONFIGURE_SIG, CONFIGURE_BODY)
	text = replace_func(text, RECALC_SIG, RECALC_BODY)
	text = replace_func(text, FORMAT_SIG, FORMAT_BODY)
	text = replace_func(text, FORMAT_NEXT_SIG, FORMAT_NEXT_BODY)
	text = replace_func(text, CAN_SIG, CAN_BODY)
	text = replace_func(text, UPDATE_SIG, UPDATE_BODY)

	# Keep service state in sync for existing wave/reset call sites without removing
	# the legacy assignments yet. A later cleanup pass will replace those directly.
	text = text.replace("element_td_interest_elapsed = 0.0", "element_td_interest_service.elapsed = 0.0 if element_td_interest_service else element_td_interest_elapsed = 0.0")
	text = text.replace("element_td_interest_disabled_for_wave = false", "element_td_interest_service.disabled_for_wave = false if element_td_interest_service else element_td_interest_disabled_for_wave = false")
	text = text.replace("element_td_interest_disabled_for_wave = true", "element_td_interest_service.disable_for_current_wave() if element_td_interest_service else element_td_interest_disabled_for_wave = true")

	if "func _sync_interest_state_from_service" not in text:
		raise SystemExit("interest sync helper was not inserted")
	if "element_td_interest_service.tick" not in text:
		raise SystemExit("interest tick was not rewired")

	BACKUP.write_text(old)
	MAIN.write_text(text)
	print("Stage 5K-1 applied")
	print("Run: godot --headless --path . --quit")
	print("Run: python3 tools/refactor/audit_legacy_migration_state.py")


if __name__ == "__main__":
	main()
