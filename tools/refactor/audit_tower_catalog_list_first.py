#!/usr/bin/env python3
"""Audit tower catalog list-first browser constraints."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}"
    start = source.find(marker)
    if start < 0:
        return ""
    next_func = source.find("\nfunc ", start + len(marker))
    return source[start:] if next_func < 0 else source[start:next_func]


def main() -> int:
    failures: list[str] = []
    tower_catalog = read("scripts/debug/tower_catalog.gd")
    scene = read("scenes/debug/tower_catalog.tscn")
    guard = read("scripts/debug/catalog_render_guard.gd")
    require(
        "func _populate_tower_name_list" in tower_catalog,
        "tower_catalog.gd must define _populate_tower_name_list()",
        failures,
    )
    require(
        "_item_list.add_item" in tower_catalog and "_item_list.set_item_metadata" in tower_catalog,
        "_populate_tower_name_list() must build an ItemList row browser",
        failures,
    )
    require(
        "TowerCatalogPreview.new()" not in tower_catalog,
        "tower_catalog.gd must not instantiate TowerCatalogPreview in the list-first startup path",
        failures,
    )
    require(
        "ItemList" in scene,
        "tower_catalog.tscn must expose an ItemList browser widget",
        failures,
    )
    require(
        "SelectedTowerPanel" not in scene,
        "tower_catalog.tscn must not expose a persistent preview panel in list-first mode",
        failures,
    )
    require(
        "catalog_list_first" in guard or "catalog_safe_mode" in guard,
        "catalog_render_guard.gd must expose list-first safe mode state",
        failures,
    )

    if failures:
        print("Tower catalog list-first audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Tower catalog list-first audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
