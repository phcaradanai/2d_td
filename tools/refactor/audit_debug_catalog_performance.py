#!/usr/bin/env python3
"""Audit debug catalog/gallery performance guardrails."""

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
    controller = read("scripts/debug/tower_effect_catalog_controller.gd")
    card = read("scripts/debug/tower_effect_catalog_card.gd")
    preview = read("scripts/towers/tower_catalog_preview.gd")
    tower = read("scripts/towers/tower.gd")
    enemy = read("scripts/enemies/enemy.gd")
    enemy_gallery = read("scripts/enemies/enemy_collection.gd")
    effect_gallery = read("scripts/effects/effect_collection.gd")
    impact_effect = read("scripts/effects/impact_effect.gd")
    death_pop_effect = read("scripts/effects/death_pop_effect.gd")

    require(
        (ROOT / "scripts/debug/tower_catalog_virtual_list.gd").exists(),
        "missing tower_catalog_virtual_list.gd",
        failures,
    )
    require(
        (ROOT / "scripts/debug/catalog_performance_monitor.gd").exists(),
        "missing catalog_performance_monitor.gd",
        failures,
    )
    require(
        (ROOT / "scripts/debug/catalog_vfx_mode.gd").exists(),
        "missing catalog_vfx_mode.gd",
        failures,
    )
    require(
        (ROOT / "scripts/debug/catalog_preview_mode.gd").exists(),
        "missing catalog_preview_mode.gd",
        failures,
    )

    require(
        "TowerCatalogVirtualList" in tower_catalog,
        "tower_catalog.gd must use TowerCatalogVirtualList",
        failures,
    )
    require(
        "CatalogPerformanceMonitor" in tower_catalog,
        "tower_catalog.gd must use CatalogPerformanceMonitor",
        failures,
    )
    require(
        "CatalogVfxMode.DEFAULT_MODE" in tower_catalog
        or "CatalogVfxMode.DEFAULT_MODE" in controller,
        "catalog VFX mode must default through CatalogVfxMode.DEFAULT_MODE",
        failures,
    )
    require(
        "VFX Off" in tower_catalog
        and "Selected Only" in tower_catalog
        and "All" in tower_catalog,
        "toolbar must expose VFX Off / Selected Only / All",
        failures,
    )
    require(
        "Active:" in tower_catalog or "active_preview" in tower_catalog,
        "catalog must show active preview count",
        failures,
    )
    require(
        "bind_entry(" in card and "deactivate(" in card,
        "tower card script must support bind_entry() and deactivate()",
        failures,
    )
    require(
        "set_active(" in preview and "set_vfx_enabled(" in preview,
        "TowerCatalogPreview must expose set_active() and set_vfx_enabled()",
        failures,
    )
    require(
        "CatalogPreviewMode.mark_preview_tree" in preview,
        "TowerCatalogPreview must mark SubViewport contents as catalog preview",
        failures,
    )
    require(
        "_virtual_list" in tower_catalog and "_all_cards" not in tower_catalog,
        "tower catalog should rely on virtual list instead of keeping all live cards",
        failures,
    )
    require(
        "_pending_setup" not in enemy_gallery,
        "enemy gallery must not keep eager live enemy setup list",
        failures,
    )
    require(
        "_spawn_gallery_card_effect(preview_root" not in effect_gallery,
        "effect gallery grid must not spawn live effect previews for every card",
        failures,
    )
    require(
        "Timer.new()" not in effect_gallery.split("func _spawn_gallery()", 1)[1].split("func _build_detail_viewer()", 1)[0],
        "effect gallery grid must not create per-card autoplay timers",
        failures,
    )

    for method_name in [
        "func _process",
        "func shoot",
        "func find_target",
        "func get_enemies_in_range",
        "func _process_support_aura",
        "func _process_trickery_clone_support",
    ]:
        idx = tower.find(method_name)
        require(idx >= 0, f"tower.gd missing {method_name}", failures)
        guard_window = tower[idx : idx + 420]
        require(
            "CatalogPreviewMode.is_preview_node" in guard_window or "preview_mode" in guard_window,
            f"tower.gd {method_name} must early return in preview mode",
            failures,
        )

    enemy_process_idx = enemy.find("func _process")
    require(enemy_process_idx >= 0, "enemy.gd missing _process", failures)
    require(
        "CatalogPreviewMode.is_selected_demo" in enemy[enemy_process_idx : enemy_process_idx + 650],
        "enemy gallery preview must be static unless selected demo is enabled",
        failures,
    )
    for method_name in [
        "func take_damage",
        "func _process_tower_status_effects",
        "func _process_shield_aura",
        "func _process_healer_aura",
        "func _process_disrupt_aura",
    ]:
        idx = enemy.find(method_name)
        require(idx >= 0, f"enemy.gd missing {method_name}", failures)
        require(
            "CatalogPreviewMode.is_preview_node" in enemy[idx : idx + 420],
            f"enemy.gd {method_name} must early return in preview mode",
            failures,
        )

    require(
        "preview_static" in impact_effect and "CatalogPreviewMode.is_static_preview" in impact_effect,
        "ImpactEffect must support static preview mode",
        failures,
    )
    require(
        "preview_static" in death_pop_effect and "CatalogPreviewMode.is_static_preview" in death_pop_effect,
        "DeathPopEffect must support static preview mode",
        failures,
    )
    require(
        "GameManager" not in tower_catalog and "WaveManager" not in tower_catalog and "TargetingService" not in tower_catalog,
        "tower catalog must not activate gameplay managers, wave manager, or target service",
        failures,
    )

    if failures:
        print("Debug catalog performance audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Debug catalog performance audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
