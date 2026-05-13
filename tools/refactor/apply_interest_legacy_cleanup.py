#!/usr/bin/env python3
"""Stage 5L-1: remove legacy Element TD interest state from main.gd.

Prerequisite: Stage 5K rewire has made ElementTDInterestService the runtime
source of truth. This script removes the temporary mirror variables and rewires
remaining reads/writes to the service.

Stage 5L-1B hardens symbol replacement so it does not rewrite legacy symbol
substrings inside function names such as _recalculate_element_td_interest_rate.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5l1.bak"
NEXT_FUNC = "\nfunc "

LEGACY_DECL_PATTERNS = [
	r"\n# Element TD WC3-like interest: active combat only\.\n# This prevents planning-phase farming while preserving wave-time economy decisions\.\n",
	r"\nvar element_td_interest_enabled: bool = true\n",
	r"\nvar element_td_interest_base_rate: float = 0\.02\n",
	r"\nvar element_td_interest_rate: float = 0\.02\n",
	r"\nvar element_td_interest_upgrade_step: float = DEFAULT_INTEREST_UPGRADE_STEP\n",
	r"\nvar element_td_interest_upgrade_count: int = 0\n",
	r"\nvar element_td_interest_max_upgrades: int = DEFAULT_MAX_INTEREST_UPGRADES\n",
	r"\nvar element_td_interest_interval_sec: float = 15\.0\n",
	r"\nvar element_td_interest_elapsed: float = 0\.0\n",
	r"\nvar element_td_interest_disabled_for_wave: bool = false\n",
]

LEGACY_SYMBOLS = [
	"element_td_interest_enabled",
	"element_td_interest_base_rate",
	"element_td_interest_rate",
	"element_td_interest_upgrade_step",
	"element_td_interest_upgrade_count",
	"element_td_interest_max_upgrades",
	"element_td_interest_interval_sec",
	"element_td_interest_elapsed",
	"element_td_interest_disabled_for_wave",
	"_sync_interest_state_from_service",
]

SYNC_SIG = "func _sync_interest_state_from_service() -> void:"

CONFIGURE_SIG = "func _configure_element_td_interest_from_level() -> void:"
CONFIGURE_BODY = '''func _configure_element_td_interest_from_level() -> void:
	if element_td_interest_service == null:
		element_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	element_td_interest_service.configure_from_level(level_data)
'''

RECALC_SIG = "func _recalculate_element_td_interest_rate() -> void:"
RECALC_BODY = '''func _recalculate_element_td_interest_rate() -> void:
	if element_td_interest_service:
		element_td_interest_service.recalculate_rate()
'''

FORMAT_SIG = "func _format_interest_rate_percent() -> String:"
FORMAT_BODY = '''func _format_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_rate_percent()
	return "%.0f%%" % (ElementTDInterestService.DEFAULT_BASE_RATE * 100.0)
'''

FORMAT_NEXT_SIG = "func _format_next_interest_rate_percent() -> String:"
FORMAT_NEXT_BODY = '''func _format_next_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_next_rate_percent()
	return "%.0f%%" % ((ElementTDInterestService.DEFAULT_BASE_RATE + DEFAULT_INTEREST_UPGRADE_STEP) * 100.0)
'''

CAN_SIG = "func _can_choose_interest_upgrade() -> bool:"
CAN_BODY = '''func _can_choose_interest_upgrade() -> bool:
	return element_td_interest_service != null and element_td_interest_service.can_choose_upgrade()
'''

UPDATE_SIG = "func _update_element_td_interest(delta: float) -> void:"
UPDATE_BODY = '''func _update_element_td_interest(delta: float) -> void:
	if element_td_interest_service == null:
		return

	var active_enemy_count := 0
	if wave_manager and wave_manager.has_method("get_active_enemy_count"):
		active_enemy_count = int(wave_manager.call("get_active_enemy_count"))
	else:
		active_enemy_count = get_tree().get_nodes_in_group("enemies").size()

	var current_gold := 0
	if game_manager:
		current_gold = int(game_manager.gold)

	var interest_gold: int = int(element_td_interest_service.tick(
		delta,
		current_gold,
		active_enemy_count,
		current_state == GameState.WAVE and not get_tree().paused
	))

	if interest_gold <= 0:
		return

	if game_manager:
		game_manager.add_gold(interest_gold)

	if game_hud and game_hud.has_method("show_floating_text"):
		game_hud.show_floating_text("+%d interest" % interest_gold)
'''


def remove_func(text: str, sig: str) -> str:
	start = text.find(sig)
	if start == -1:
		return text
	end = text.find(NEXT_FUNC, start + len(sig))
	if end == -1:
		raise SystemExit(f"missing end for {sig}")
	return text[:start].rstrip() + "\n\n" + text[end + 1:]


def replace_func(text: str, sig: str, body: str) -> str:
	start = text.find(sig)
	if start == -1:
		raise SystemExit(f"missing {sig}")
	end = text.find(NEXT_FUNC, start + len(sig))
	if end == -1:
		raise SystemExit(f"missing end for {sig}")
	return text[:start] + body.rstrip() + "\n\n" + text[end + 1:]


def remove_legacy_declarations(text: str) -> str:
	for pattern in LEGACY_DECL_PATTERNS:
		text = re.sub(pattern, "\n", text)
	return text


def remove_sync_calls(text: str) -> str:
	return re.sub(r"^\t+_sync_interest_state_from_service\(\)\n", "", text, flags=re.MULTILINE)


def simplify_generated_reset_blocks(text: str) -> str:
	patterns = [
		(
			r"(?m)^(?P<i>\t+)if element_td_interest_service:\n(?P=i)\telement_td_interest_service\.elapsed = 0\.0\n(?P=i)\t_sync_interest_state_from_service\(\)\n(?P=i)else:\n(?P=i)\telement_td_interest_elapsed = 0\.0",
			"{i}if element_td_interest_service:\n{i}\telement_td_interest_service.elapsed = 0.0",
		),
		(
			r"(?m)^(?P<i>\t+)if element_td_interest_service:\n(?P=i)\telement_td_interest_service\.disabled_for_wave = false\n(?P=i)\t_sync_interest_state_from_service\(\)\n(?P=i)else:\n(?P=i)\telement_td_interest_disabled_for_wave = false",
			"{i}if element_td_interest_service:\n{i}\telement_td_interest_service.disabled_for_wave = false",
		),
		(
			r"(?m)^(?P<i>\t+)if element_td_interest_service:\n(?P=i)\telement_td_interest_service\.disable_for_current_wave\(\)\n(?P=i)\t_sync_interest_state_from_service\(\)\n(?P=i)else:\n(?P=i)\telement_td_interest_disabled_for_wave = true",
			"{i}if element_td_interest_service:\n{i}\telement_td_interest_service.disable_for_current_wave()",
		),
	]
	for pattern, replacement in patterns:
		text = re.sub(pattern, lambda m: replacement.format(i=m.group("i")), text)
	return text


def replace_line_with_block(text: str, target: str, block_lines: list[str]) -> str:
	out: list[str] = []
	for line in text.splitlines():
		if line.strip() == target:
			indent = line[: len(line) - len(line.lstrip())]
			out.extend(indent + block_line for block_line in block_lines)
		else:
			out.append(line)
	return "\n".join(out) + "\n"


def rewrite_remaining_legacy_writes(text: str) -> str:
	text = replace_line_with_block(
		text,
		"element_td_interest_upgrade_count += 1",
		[
			"if element_td_interest_service:",
			"\telement_td_interest_service.apply_upgrade()",
		],
	)
	text = replace_line_with_block(
		text,
		"element_td_interest_elapsed = 0.0",
		[
			"if element_td_interest_service:",
			"\telement_td_interest_service.elapsed = 0.0",
		],
	)
	text = replace_line_with_block(
		text,
		"element_td_interest_disabled_for_wave = false",
		[
			"if element_td_interest_service:",
			"\telement_td_interest_service.disabled_for_wave = false",
		],
	)
	text = replace_line_with_block(
		text,
		"element_td_interest_disabled_for_wave = true",
		[
			"if element_td_interest_service:",
			"\telement_td_interest_service.disable_for_current_wave()",
		],
	)
	return text


def replace_identifier(text: str, old: str, new: str) -> str:
	# Only replace full identifiers. This prevents rewriting function names such as
	# _recalculate_element_td_interest_rate into invalid GDScript syntax.
	return re.sub(rf"(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])", new, text)


def rewrite_remaining_legacy_reads(text: str) -> str:
	# These are used mostly in HUD/detail panel arguments. Keep expressions typed.
	replacements = {
		"element_td_interest_upgrade_count": "int(element_td_interest_service.upgrade_count if element_td_interest_service else 0)",
		"element_td_interest_max_upgrades": "int(element_td_interest_service.max_upgrades if element_td_interest_service else DEFAULT_MAX_INTEREST_UPGRADES)",
		"element_td_interest_upgrade_step": "float(element_td_interest_service.upgrade_step if element_td_interest_service else DEFAULT_INTEREST_UPGRADE_STEP)",
		"element_td_interest_rate": "float(element_td_interest_service.rate if element_td_interest_service else ElementTDInterestService.DEFAULT_BASE_RATE)",
		"element_td_interest_interval_sec": "float(element_td_interest_service.interval_sec if element_td_interest_service else ElementTDInterestService.DEFAULT_INTERVAL_SEC)",
		"element_td_interest_base_rate": "float(element_td_interest_service.base_rate if element_td_interest_service else ElementTDInterestService.DEFAULT_BASE_RATE)",
		"element_td_interest_enabled": "bool(element_td_interest_service.enabled if element_td_interest_service else true)",
	}
	for old, new in replacements.items():
		text = replace_identifier(text, old, new)
	return text


def validate_cleanup(text: str) -> None:
	remaining = [symbol for symbol in LEGACY_SYMBOLS if re.search(rf"(?<![A-Za-z0-9_]){re.escape(symbol)}(?![A-Za-z0-9_])", text)]
	if remaining:
		print("Stage 5L cleanup incomplete. Remaining legacy symbols:")
		for symbol in remaining:
			print("-", symbol)
		raise SystemExit(1)
	if "func _recalculate_float" in text:
		raise SystemExit("cleanup corrupted _recalculate_element_td_interest_rate")
	if "element_td_interest_service.apply_upgrade()" not in text:
		raise SystemExit("interest upgrade path was not rewired to service.apply_upgrade()")


def main() -> None:
	text = MAIN.read_text()
	old = text

	text = remove_legacy_declarations(text)
	text = remove_func(text, SYNC_SIG)
	text = replace_func(text, CONFIGURE_SIG, CONFIGURE_BODY)
	text = replace_func(text, RECALC_SIG, RECALC_BODY)
	text = replace_func(text, FORMAT_SIG, FORMAT_BODY)
	text = replace_func(text, FORMAT_NEXT_SIG, FORMAT_NEXT_BODY)
	text = replace_func(text, CAN_SIG, CAN_BODY)
	text = replace_func(text, UPDATE_SIG, UPDATE_BODY)
	text = simplify_generated_reset_blocks(text)
	text = remove_sync_calls(text)
	text = rewrite_remaining_legacy_writes(text)
	text = rewrite_remaining_legacy_reads(text)

	validate_cleanup(text)

	BACKUP.write_text(old)
	MAIN.write_text(text)
	print("Stage 5L-1 applied")
	print("Run: godot --headless --path . --quit")
	print("Run: python3 tools/refactor/audit_legacy_migration_state.py")


if __name__ == "__main__":
	main()
