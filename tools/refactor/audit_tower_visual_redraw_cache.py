#!/usr/bin/env python3
"""Audit tower visual redraw/cache guardrails."""

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
    tower = read("scripts/towers/tower.gd")
    utils = read("scripts/towers/visuals/common/tower_visual_draw_utils.gd")
    preview = read("scripts/towers/tower_catalog_preview.gd")

    require(
        "_base_plate_cache" in utils and "_element_core_layout_cache" in utils,
        "tower_visual_draw_utils.gd must cache base plate and element core layout data",
        failures,
    )
    require(
        "BASE_RECT" in utils and "CORNER_TICKS" in utils,
        "tower_visual_draw_utils.gd must precompute static rect/tick geometry",
        failures,
    )
    require(
        "_tower_visual_dirty" in tower and "_tower_visual_signature" in tower,
        "tower.gd must track tower visual dirty state and signature",
        failures,
    )
    require(
        "_mark_tower_visual_dirty" in tower and "_request_tower_visual_redraw_if_dirty" in tower,
        "tower.gd must redraw through dirty-flag helpers",
        failures,
    )
    process_body = function_body(tower, "_process")
    preview_branch = process_body.split("if preview_mode or CatalogPreviewMode.is_preview_node(self):", 1)
    require(
        len(preview_branch) == 2,
        "tower.gd _process must have a preview-mode branch",
        failures,
    )
    if len(preview_branch) == 2:
        branch = preview_branch[1].split("\n\tif game_manager", 1)[0]
        require(
            "_request_tower_visual_redraw_if_dirty" in branch,
            "preview branch must use dirty redraw helper",
            failures,
        )
        require(
            "TOWER_VISUAL_PREVIEW_DEMO_REDRAW_INTERVAL" in branch,
            "selected preview demo redraw must be low-frequency",
            failures,
        )
        require(
            branch.count("queue_redraw()") == 0,
            "preview branch must not call queue_redraw() directly",
            failures,
        )
    require(
        "static_preview: bool = true" in preview or "static_preview = true" in preview,
        "TowerCatalogPreview must default catalog cards to static preview",
        failures,
    )

    if failures:
        print("Tower visual redraw/cache audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("Tower visual redraw/cache audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
