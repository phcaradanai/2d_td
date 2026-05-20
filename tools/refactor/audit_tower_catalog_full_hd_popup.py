#!/usr/bin/env python3
"""Audit the tower catalog full-HD list shell and popup placeholder."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    failures: list[str] = []
    tower_catalog = read("scripts/debug/tower_catalog.gd")
    scene = read("scenes/debug/tower_catalog.tscn")
    guard = read("scripts/debug/catalog_render_guard.gd")

    require("func _fit_catalog_to_viewport" in tower_catalog, "tower_catalog.gd must fit the shell to the viewport", failures)
    require("func _populate_tower_name_list" in tower_catalog, "tower_catalog.gd must define _populate_tower_name_list()", failures)
    require("_item_list.add_item" in tower_catalog and "_item_list.set_item_metadata" in tower_catalog, "tower_catalog.gd must build a text ItemList browser", failures)
    require("TowerCatalogPreview.new()" not in tower_catalog, "tower_catalog.gd must not instantiate TowerCatalogPreview during catalog startup", failures)

    require('node name="MainPanel" type="PanelContainer"' in scene, "tower_catalog.tscn must define a centered MainPanel shell", failures)
    require('node name="Header" type="HBoxContainer"' in scene, "tower_catalog.tscn must define a Header container", failures)
    require('node name="Toolbar" type="HBoxContainer"' in scene, "tower_catalog.tscn must define a Toolbar container", failures)
    require('node name="BodySplit" type="HSplitContainer"' in scene, "tower_catalog.tscn must define a BodySplit container", failures)
    require('node name="TowerListPanel" type="PanelContainer"' in scene, "tower_catalog.tscn must define a TowerListPanel", failures)
    require('node name="TowerNameList" type="ItemList"' in scene, "tower_catalog.tscn must expose an ItemList tower browser", failures)
    require('node name="DetailPanel" type="PanelContainer"' in scene, "tower_catalog.tscn must define a DetailPanel", failures)
    require('node name="SelectedTowerName" type="Label"' in scene, "tower_catalog.tscn must expose the selected tower name label", failures)
    require('node name="SelectedTowerStats" type="Label"' in scene, "tower_catalog.tscn must expose the selected tower stats label", failures)
    require('node name="TowerPreviewPopup" type="PopupPanel" parent="."' in scene, "tower_catalog.tscn must reserve a hidden TowerPreviewPopup placeholder", failures)
    require('visible = false' in scene.split('node name="TowerPreviewPopup"', 1)[1], "tower_catalog.tscn must keep TowerPreviewPopup hidden by default", failures)
    require('node name="PopupCard" type="PanelContainer" parent="TowerPreviewPopup"' in scene, "tower_catalog.tscn must reserve a PopupCard placeholder under TowerPreviewPopup", failures)
    require("MainMargin" not in scene and "MainVBox" not in scene, "tower_catalog.tscn must not include the old nested main shell containers", failures)
    require("TowerListMargin" not in scene and "TowerListVBox" not in scene, "tower_catalog.tscn must not include the old nested list containers", failures)
    require("DetailMargin" not in scene and "DetailVBox" not in scene, "tower_catalog.tscn must not include the old nested detail containers", failures)
    require("SelectedTowerPanel" not in scene, "tower_catalog.tscn must not expose the old selected preview panel", failures)
    require("TowerCatalogPreview.new()" not in scene and "_populate_side_panel" not in tower_catalog, "tower_catalog.gd and tower_catalog.tscn must not instantiate tower previews in the shell", failures)

    require("catalog_safe_mode" in guard and "catalog_list_first" in guard, "catalog_render_guard.gd must expose safe-mode and list-first flags", failures)

    if failures:
        print("Tower catalog full HD popup audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Tower catalog full HD popup audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
