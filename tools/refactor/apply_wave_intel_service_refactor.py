#!/usr/bin/env python3
"""Apply Stage 5E-2: rewire main.gd to WaveIntelService.

This script is intentionally local-first because scripts/main/main.gd is large.
It performs conservative text edits with backups and fails closed if expected
blocks are not found.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts" / "main" / "main.gd"
BACKUP = ROOT / "scripts" / "main" / "main.gd.stage5e2.bak"
SERVICE_CONST = 'const WAVE_INTEL_SERVICE_SCRIPT = preload("res://scripts/main/wave_intel_service.gd")'
INSERT_AFTER = 'const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")'
FUNCTIONS_TO_REMOVE = [
    "func derive_wave_traits(",
    "func recommend_roles_for_wave(",
    "func _get_preview_wave_groups(",
]
NEXT_FUNC_MARKER = "\nfunc "


def remove_function(text: str, signature_prefix: str) -> tuple[str, bool]:
    start = text.find(signature_prefix)
    if start == -1:
        return text, False

    next_start = text.find(NEXT_FUNC_MARKER, start + len(signature_prefix))
    if next_start == -1:
        raise RuntimeError(f"Cannot find end of function block for {signature_prefix}")

    # Keep one clean blank line before the next function.
    new_text = text[:start].rstrip() + "\n\n" + text[next_start + 1:]
    return new_text, True


def replace_direct_calls(text: str) -> str:
    # If any remaining call sites use the old local functions, redirect them to the service.
    replacements = {
        "derive_wave_traits(": "WaveIntelService.derive_wave_traits(",
        "recommend_roles_for_wave(": "WaveIntelService.recommend_roles_for_wave(",
        "_get_preview_wave_groups(": "WaveIntelService.get_preview_wave_groups(",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    if not MAIN.exists():
        raise SystemExit(f"main.gd not found: {MAIN}")

    text = MAIN.read_text()
    original = text

    if SERVICE_CONST not in text:
        if INSERT_AFTER not in text:
            raise SystemExit("Cannot find preload insertion point")
        text = text.replace(INSERT_AFTER, INSERT_AFTER + "\n" + SERVICE_CONST, 1)

    removed = []
    for signature in FUNCTIONS_TO_REMOVE:
        text, did_remove = remove_function(text, signature)
        if did_remove:
            removed.append(signature)

    if not removed:
        raise SystemExit("No wave intel functions removed; aborting to avoid a no-op/incorrect patch")

    text = replace_direct_calls(text)

    # Fix accidental self-prefix inside the newly removed function call sites if script is run twice.
    text = text.replace("WaveIntelService.WaveIntelService.", "WaveIntelService.")

    BACKUP.write_text(original)
    MAIN.write_text(text)

    print("Stage 5E-2 applied")
    print(f"backup: {BACKUP.relative_to(ROOT)}")
    print("removed functions:")
    for item in removed:
        print(f"- {item}")
    print("next checks:")
    print('grep -n "func derive_wave_traits\\|func recommend_roles_for_wave\\|func _get_preview_wave_groups" scripts/main/main.gd')
    print('grep -n "WAVE_INTEL_SERVICE_SCRIPT\\|WaveIntelService" scripts/main/main.gd')


if __name__ == "__main__":
    main()
