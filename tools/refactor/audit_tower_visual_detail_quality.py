#!/usr/bin/env python3
"""Audit tower visual detail-quality forwarding."""

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
    renderer = read("scripts/towers/tower_visual_renderer.gd")

    require(
        "_resolve_detail_quality(t: Node2D) -> int" in renderer,
        "renderer must expose a detail-quality resolver",
        failures,
    )
    require(
        "TowerVisualDrawUtilsScript.DetailQuality.LOW" in renderer
        and "TowerVisualDrawUtilsScript.DetailQuality.MEDIUM" in renderer
        and "TowerVisualDrawUtilsScript.DetailQuality.HIGH" in renderer,
        "renderer resolver must use the shared DetailQuality enum",
        failures,
    )
    require(
        "visual_script.draw_contour(t, detail_quality)" in renderer,
        "renderer must forward detail quality into contour drawing",
        failures,
    )
    require(
        "visual_script.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors, detail_quality)" in renderer,
        "renderer must forward detail quality into top drawing",
        failures,
    )

    targets = {
        "scripts/towers/visuals/by_id/nature_t1_visual.gd",
        "scripts/towers/visuals/by_id/ice_t1_visual.gd",
        "scripts/towers/visuals/by_id/fire_t1_visual.gd",
        "scripts/towers/visuals/by_id/light_t1_visual.gd",
        "scripts/towers/visuals/by_id/blacksmith_t1_visual.gd",
    }
    for path in sorted(targets):
        text = read(path)
        require(
            "detail_quality: int = TowerVisualDrawUtils.DetailQuality.MEDIUM" in text,
            f"{path} must default detail_quality to MEDIUM",
            failures,
        )
        require(
            "TowerVisualDrawUtils.DetailQuality.LOW" in text,
            f"{path} must gate LOW detail",
            failures,
        )
        require(
            "TowerVisualDrawUtils.DetailQuality.MEDIUM" in text,
            f"{path} must reference MEDIUM detail",
            failures,
        )
        require(
            "TowerVisualDrawUtils.DetailQuality.HIGH" not in text or "detail_quality" in text,
            f"{path} must keep the enum threaded through the updated signatures",
            failures,
        )

    if failures:
        print("Tower visual detail-quality audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Tower visual detail-quality audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
