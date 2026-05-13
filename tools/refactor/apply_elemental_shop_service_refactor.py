#!/usr/bin/env python3
"""Apply Stage 5F-2: rewire main.gd to ElementalShopService.

This script performs conservative local text edits because scripts/main/main.gd is large.
It adds the service preload, rewrites _refresh_elemental_shop(), removes the local
starter helper when present, writes a backup, and fails closed if expected markers
are not found.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts" / "main" / "main.gd"
BACKUP = ROOT / "scripts" / "main" / "main.gd.stage5f2.bak"
SERVICE_CONST = 'const ELEMENTAL_SHOP_SERVICE_SCRIPT = preload("res://scripts/main/elemental_shop_service.gd")'
INSERT_AFTER = 'const WAVE_INTEL_SERVICE_SCRIPT = preload("res://scripts/main/wave_intel_service.gd")'
FALLBACK_INSERT_AFTER = 'const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")'
REFRESH_SIGNATURE = "func _refresh_elemental_shop() -> void:"
HELPER_SIGNATURES = [
    "func _ensure_starter_towers_in_shop(",
    "func ensure_starter_towers_in_shop(",
]
NEXT_FUNC_MARKER = "\nfunc "
NEW_REFRESH_FUNC = '''func _refresh_elemental_shop() -> void:
	if build_manager == null or game_hud == null:
		return

	var ids: Array[String] = ElementalShopService.get_buildable_tower_ids(
		element_progression_manager,
		build_manager.towers_config,
		STARTER_TOWER_IDS
	)

	if build_manager.has_method("set_unlocked_tower_ids"):
		build_manager.set_unlocked_tower_ids(ids)
	game_hud.refresh_tower_shop(ids)
'''


def replace_function(text: str, signature: str, replacement: str) -> tuple[str, bool]:
    start = text.find(signature)
    if start == -1:
        return text, False

    next_start = text.find(NEXT_FUNC_MARKER, start + len(signature))
    if next_start == -1:
        raise RuntimeError(f"Cannot find end of function block for {signature}")

    return text[:start] + replacement.rstrip() + "\n\n" + text[next_start + 1:], True


def remove_function(text: str, signature: str) -> tuple[str, bool]:
    start = text.find(signature)
    if start == -1:
        return text, False

    next_start = text.find(NEXT_FUNC_MARKER, start + len(signature))
    if next_start == -1:
        raise RuntimeError(f"Cannot find end of function block for {signature}")

    return text[:start].rstrip() + "\n\n" + text[next_start + 1:], True


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
    text = add_preload(original)

    text, replaced_refresh = replace_function(text, REFRESH_SIGNATURE, NEW_REFRESH_FUNC)
    if not replaced_refresh:
        raise SystemExit("Cannot find _refresh_elemental_shop(); aborting")

    removed_helpers: list[str] = []
    for signature in HELPER_SIGNATURES:
        text, did_remove = remove_function(text, signature)
        if did_remove:
            removed_helpers.append(signature)

    BACKUP.write_text(original)
    MAIN.write_text(text)

    print("Stage 5F-2 applied")
    print(f"backup: {BACKUP.relative_to(ROOT)}")
    print("rewired: _refresh_elemental_shop() -> ElementalShopService.get_buildable_tower_ids()")
    if removed_helpers:
        print("removed helper functions:")
        for item in removed_helpers:
            print(f"- {item}")
    else:
        print("removed helper functions: none found")
    print("next checks:")
    print('grep -n "ELEMENTAL_SHOP_SERVICE_SCRIPT\\|ElementalShopService" scripts/main/main.gd')
    print('grep -n "func _ensure_starter_towers_in_shop\\|func ensure_starter_towers_in_shop" scripts/main/main.gd')


if __name__ == "__main__":
    main()
