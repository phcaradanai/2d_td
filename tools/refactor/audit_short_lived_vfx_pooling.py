#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


REQUIRED_FILES = [
    "scripts/services/visual_effect_pool_service.gd",
]


FORBIDDEN_SNIPPETS = {
    "scripts/effects/tower_attack_vfx.gd": [
        "Node2D.new()",
    ],
    "scripts/vfx/core/tower_attack_vfx_service.gd": [
        "Node2D.new()",
    ],
    "scripts/effects/attack_vfx.gd": [
        "queue_free()",
    ],
    "scripts/vfx/core/base_tower_attack_vfx.gd": [
        "queue_free()",
    ],
    "scripts/effects/damage_number.gd": [
        "queue_free()",
    ],
    "scripts/effects/death_pop_effect.gd": [
        "queue_free",
    ],
    "scripts/effects/splash_effect.gd": [
        "queue_free()",
    ],
    "scripts/effects/enemy_impact_vfx.gd": [
        "queue_free()",
    ],
    "scripts/effects/enemy_vfx_controller.gd": [
        "StatusIconScript.new()",
        "create_timer(",
    ],
}


REQUIRED_SNIPPETS = {
    "project.godot": [
        'VisualEffectPoolService="*res://scripts/services/visual_effect_pool_service.gd"',
    ],
    "scripts/services/visual_effect_pool_service.gd": [
        "func prewarm_level_pools()",
        "func acquire_scene(",
        "func acquire_script(",
        "func release(",
        "func get_cap(",
    ],
    "scripts/effects/tower_attack_vfx.gd": [
        "/root/VisualEffectPoolService",
        "acquire_script",
    ],
    "scripts/vfx/core/tower_attack_vfx_service.gd": [
        "/root/VisualEffectPoolService",
        "acquire_script",
    ],
    "scripts/effects/damage_number.gd": [
        "VisualEffectPoolService",
        "_begin_pooled_lifecycle",
    ],
    "scripts/effects/death_pop_effect.gd": [
        "VisualEffectPoolService",
        "_begin_pooled_lifecycle",
    ],
    "scripts/effects/splash_effect.gd": [
        "VisualEffectPoolService",
        "_begin_pooled_lifecycle",
    ],
    "scripts/effects/enemy_impact_vfx.gd": [
        "VisualEffectPoolService",
        "_begin_pooled_lifecycle",
    ],
    "scripts/effects/enemy_vfx_controller.gd": [
        "_acquire_status_icon",
        "_release_status_icon",
        'acquire_script(StatusIconScript, parent, "status_icon", "status_icon")',
    ],
}


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    errors: list[str] = []
    for rel_path in REQUIRED_FILES:
        if not (ROOT / rel_path).exists():
            errors.append(f"Missing required file: {rel_path}")

    for rel_path, snippets in REQUIRED_SNIPPETS.items():
        path = ROOT / rel_path
        if not path.exists():
            errors.append(f"Missing file for snippet check: {rel_path}")
            continue
        text = read(rel_path)
        for snippet in snippets:
            if snippet not in text:
                errors.append(f"{rel_path} missing required snippet: {snippet}")

    for rel_path, snippets in FORBIDDEN_SNIPPETS.items():
        path = ROOT / rel_path
        if not path.exists():
            continue
        text = read(rel_path)
        for snippet in snippets:
            if snippet in text:
                errors.append(f"{rel_path} still contains active-wave allocation/free snippet: {snippet}")

    if errors:
        print("short-lived VFX pooling audit failed:")
        for error in errors:
            print(f" - {error}")
        return 1

    print("short-lived VFX pooling audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
