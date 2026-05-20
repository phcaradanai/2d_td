#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(rel_path: str) -> str:
    return (ROOT / rel_path).read_text(encoding="utf-8")


def require(path: str) -> str:
    full = ROOT / path
    if not full.exists():
        raise AssertionError(f"missing file: {path}")
    return read(path)


def main() -> int:
    errors: list[str] = []

    try:
        project = require("project.godot")
        if 'SpatialTargetCache="*res://scripts/services/spatial_target_cache.gd"' not in project:
            errors.append("project.godot missing SpatialTargetCache autoload")
    except AssertionError as exc:
        errors.append(str(exc))

    try:
        cache = require("scripts/services/spatial_target_cache.gd")
        for snippet in [
            "func set_bucket_size(size: float) -> void:",
            "func register_enemy(enemy: Node2D) -> void:",
            "func unregister_enemy(enemy: Node2D) -> void:",
            "func update_enemy_bucket(enemy: Node2D) -> void:",
            "func get_candidates_in_radius(center: Vector2, radius: float) -> Array[Node2D]:",
        ]:
            if snippet not in cache:
                errors.append(f"spatial_target_cache.gd missing: {snippet}")
    except AssertionError as exc:
        errors.append(str(exc))

    try:
        enemy = require("scripts/enemies/enemy.gd")
        for snippet in [
            "_sync_spatial_target_cache(true)",
            "func _exit_tree() -> void:",
            "cache.call(\"update_enemy_bucket\", self)",
            "cache.call(\"unregister_enemy\", self)",
        ]:
            if snippet not in enemy:
                errors.append(f"enemy.gd missing: {snippet}")
    except AssertionError as exc:
        errors.append(str(exc))

    try:
        grid = require("scripts/navigation/grid_pathfinding_manager.gd")
        if 'set_bucket_size", float(grid_size)' not in grid:
            errors.append("grid_pathfinding_manager.gd missing bucket-size sync")
    except AssertionError as exc:
        errors.append(str(exc))

    if errors:
        print("targeting cache audit failed:")
        for error in errors:
            print(f" - {error}")
        return 1

    print("targeting cache audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
