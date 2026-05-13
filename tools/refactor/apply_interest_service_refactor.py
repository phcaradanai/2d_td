#!/usr/bin/env python3
"""Apply Stage 5G-2: rewire main.gd to ElementTDInterestService.

This script is local-first because scripts/main/main.gd is large. It adds the
service preload and instance, rewrites the interest helper functions to delegate
to the service, and keeps old variable declarations harmless until a later
cleanup pass can remove them safely.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts" / "main" / "main.gd"
BACKUP = ROOT / "scripts" / "main" / "main.gd.stage5g2.bak"
SERVICE_CONST = 'const ELEMENT_TD_INTEREST_SERVICE_SCRIPT = preload("res://scripts/main/element_td_interest_service.gd")'
INSERT_AFTER = 'const ELEMENTAL_SHOP_SERVICE_SCRIPT = preload("res://scripts/main/elemental_shop_service.gd")'
FALLBACK_INSERT_AFTER = 'const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")'
INSTANCE_VAR = 'var element_td_interest_service: ElementTDInterestService = null'
INSTANCE_INSERT_AFTER = 'var element_progression_manager = null'
READY_MARKER = '_ensure_element_progression_manager()'
NEXT_FUNC_MARKER = "\nfunc "

REPLACEMENTS = {
    "func _configure_element_td_interest_from_level() -> void:": '''func _configure_element_td_interest_from_level() -> void:
	if element_td_interest_service == null:
		element_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	element_td_interest_service.configure_from_level(level_data)
	_sync_interest_state_from_service()
''',
    "func _recalculate_element_td_interest_rate() -> void:": '''func _recalculate_element_td_interest_rate() -> void:
	if element_td_interest_service:
		element_td_interest_service.recalculate_rate()
		_sync_interest_state_from_service()
''',
    "func _format_interest_rate_percent() -> String:": '''func _format_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_rate_percent()
	return "0%"
''',
    "func _format_next_interest_rate_percent() -> String:": '''func _format_next_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_next_rate_percent()
	return "0%"
''',
    "func _can_choose_interest_upgrade() -> bool:": '''func _can_choose_interest_upgrade() -> bool:
	return element_td_interest_service != null and element_td_interest_service.can_choose_upgrade()
''',
    "func _update_element_td_interest(delta: float) -> void:": '''func _update_element_td_interest(delta: float) -> void:
	if element_td_interest_service == null:
		return

	var can_tick := true
	can_tick = can_tick and not get_tree().paused
	can_tick = can_tick and current_state != GameState.PAUSED
	can_tick = can_tick and current_state == GameState.WAVE
	can_tick = can_tick and not _has_pending_element_pick()
	can_tick = can_tick and wave_manager != null and wave_manager.is_wave_running
	can_tick = can_tick and game_manager != null and not game_manager.is_game_over and not game_manager.is_victory

	var active_enemy_count := 0
	if wave_manager:
		active_enemy_count = int(wave_manager.get("active_enemy_count"))

	var interest_gold := element_td_interest_service.tick(delta, game_manager.gold if game_manager else 0, active_enemy_count, can_tick)
	_sync_interest_state_from_service()
	if interest_gold <= 0:
		return

	game_manager.add_gold(interest_gold)
	if game_hud:
		game_hud.set_status("Interest +%d" % interest_gold)
		show_wave_feedback("Interest +%d" % interest_gold, Color(1.0, 0.85, 0.25))
''',
}

SYNC_FUNCTION = '''func _sync_interest_state_from_service() -> void:
	if element_td_interest_service == null:
		return
	element_td_interest_enabled = element_td_interest_service.enabled
	element_td_interest_base_rate = element_td_interest_service.base_rate
	element_td_interest_rate = element_td_interest_service.rate
	element_td_interest_upgrade_step = element_td_interest_service.upgrade_step
	element_td_interest_upgrade_count = element_td_interest_service.upgrade_count
	element_td_interest_max_upgrades = element_td_interest_service.max_upgrades
	element_td_interest_interval_sec = element_td_interest_service.interval_sec
	element_td_interest_elapsed = element_td_interest_service.elapsed
	element_td_interest_disabled_for_wave = element_td_interest_service.disabled_for_wave
'''


def replace_function(text: str, signature: str, replacement: str) -> tuple[str, bool]:
    start = text.find(signature)
    if start == -1:
        return text, False
    next_start = text.find(NEXT_FUNC_MARKER, start + len(signature))
    if next_start == -1:
        raise RuntimeError(f"Cannot find end of function block for {signature}")
    return text[:start] + replacement.rstrip() + "\n\n" + text[next_start + 1:], True


def add_once_after(text: str, marker: str, addition: str) -> str:
    if addition in text:
        return text
    if marker not in text:
        raise RuntimeError(f"Cannot find marker: {marker}")
    return text.replace(marker, marker + "\n" + addition, 1)


def add_preload(text: str) -> str:
    if SERVICE_CONST in text:
        return text
    if INSERT_AFTER in text:
        return text.replace(INSERT_AFTER, INSERT_AFTER + "\n" + SERVICE_CONST, 1)
    if FALLBACK_INSERT_AFTER in text:
        return text.replace(FALLBACK_INSERT_AFTER, FALLBACK_INSERT_AFTER + "\n" + SERVICE_CONST, 1)
    raise RuntimeError("Cannot find preload insertion point")


def main() -> None:
    if not MAIN.exists():
        raise SystemExit(f"main.gd not found: {MAIN}")

    original = MAIN.read_text()
    text = original
    text = add_preload(text)
    text = add_once_after(text, INSTANCE_INSERT_AFTER, INSTANCE_VAR)

    if READY_MARKER in text and 'element_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()' not in text:
        text = text.replace(
            READY_MARKER,
            READY_MARKER + "\n\tif element_td_interest_service == null:\n\t\telement_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()",
            1,
        )

    replaced: list[str] = []
    for signature, replacement in REPLACEMENTS.items():
        text, ok = replace_function(text, signature, replacement)
        if not ok:
            raise SystemExit(f"Cannot find required function: {signature}")
        replaced.append(signature)

    if "func _sync_interest_state_from_service() -> void:" not in text:
        insert_at = text.find("func _has_pending_element_pick() -> bool:")
        if insert_at == -1:
            raise SystemExit("Cannot find insertion point for _sync_interest_state_from_service()")
        text = text[:insert_at] + SYNC_FUNCTION.rstrip() + "\n\n" + text[insert_at:]

    BACKUP.write_text(original)
    MAIN.write_text(text)

    print("Stage 5G-2 applied")
    print(f"backup: {BACKUP.relative_to(ROOT)}")
    print("rewired functions:")
    for item in replaced:
        print(f"- {item}")
    print("next checks:")
    print('grep -n "ELEMENT_TD_INTEREST_SERVICE_SCRIPT\\|element_td_interest_service\\|_sync_interest_state_from_service" scripts/main/main.gd')
    print('godot --headless --path . --quit')


if __name__ == "__main__":
    main()
