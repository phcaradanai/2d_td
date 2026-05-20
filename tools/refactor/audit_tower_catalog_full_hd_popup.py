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
    require("var current_preview: Node = null" in tower_catalog, "tower_catalog.gd must store a single popup preview reference", failures)
    require("func _open_preview_popup(tower_id: String)" in tower_catalog, "tower_catalog.gd must expose _open_preview_popup()", failures)
    require("func _close_preview_popup()" in tower_catalog, "tower_catalog.gd must expose _close_preview_popup()", failures)
    require("popup_open" in tower_catalog, "tower_catalog.gd must track popup_open state", failures)

    require('node name="RootMargin" type="MarginContainer"' in scene, "tower_catalog.tscn must define a safe-area RootMargin", failures)
    require('node name="MainPanel" type="PanelContainer"' in scene, "tower_catalog.tscn must define a centered MainPanel shell", failures)
    require('node name="MainVBox" type="VBoxContainer"' in scene, "tower_catalog.tscn must use a bounded vertical shell", failures)
    require('node name="Header" type="HBoxContainer"' in scene, "tower_catalog.tscn must define a Header container", failures)
    require('node name="Toolbar" type="HBoxContainer"' in scene, "tower_catalog.tscn must define a Toolbar container", failures)
    require('node name="BodySplit" type="HSplitContainer"' in scene, "tower_catalog.tscn must define a BodySplit container", failures)
    require('node name="TowerListPanel" type="PanelContainer"' in scene, "tower_catalog.tscn must define a TowerListPanel", failures)
    require('node name="TowerNameList" type="ItemList"' in scene, "tower_catalog.tscn must expose an ItemList tower browser", failures)
    require('node name="DetailPanel" type="PanelContainer"' in scene, "tower_catalog.tscn must define a DetailPanel", failures)
    require('node name="SelectedTowerName" type="Label"' in scene, "tower_catalog.tscn must expose the selected tower name label", failures)
    require('node name="SelectedTowerStats" type="Label"' in scene, "tower_catalog.tscn must expose the selected tower stats label", failures)
    require("SelectedTowerPanel" not in scene, "tower_catalog.tscn must not expose the old selected preview panel", failures)
    require("TowerCatalogPreview.new()" not in scene and "_populate_side_panel" not in tower_catalog, "tower_catalog.gd and tower_catalog.tscn must not instantiate tower previews in the shell", failures)
    require("TowerPreviewPopupScene" in tower_catalog, "tower_catalog.gd must preload the popup scene", failures)
    require("func _fit_popup_to_viewport" not in tower_catalog and "_preview_popup_host" not in tower_catalog, "tower_catalog.gd must let the popup controller own sizing and centering", failures)
    require("item_activated.connect(_on_item_activated)" in tower_catalog, "tower_catalog.gd must open the popup from row activation", failures)
    require("Open Selected" in tower_catalog, "tower_catalog.gd must expose an Open Selected action", failures)
    popup_script = read("scripts/debug/tower_preview_popup.gd")
    popup_scene = read("scenes/debug/tower_preview_popup.tscn")
    preview_script = read("scripts/towers/tower_catalog_preview.gd")
    require("extends Control" in popup_script, "tower_preview_popup.gd must extend Control for the full-rect overlay", failures)
    require('node name="TowerPreviewPopup" type="Control"' in popup_scene, "tower_preview_popup.tscn must use a full-rect Control root", failures)
    require('node name="DimOverlay" type="ColorRect"' in popup_scene, "tower_preview_popup.tscn must include a dim overlay", failures)
    require("func open_for_tower" in popup_script, "tower_preview_popup.gd must define open_for_tower()", failures)
    require("func close_popup" in popup_script, "tower_preview_popup.gd must define close_popup()", failures)
    require("TowerPreviewResolverScript" in preview_script, "TowerCatalogPreview must resolve real preview sources", failures)
    require("TowerEffectPreviewServiceScript" in preview_script, "TowerCatalogPreview must spawn real effect preview sources", failures)
    require("_draw_fake_target" not in preview_script and "_draw_projectile_preview" not in preview_script, "TowerCatalogPreview must not draw fake effect placeholders", failures)

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
