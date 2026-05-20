#!/usr/bin/env python3
"""Audit tower draw firewall symbols."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
UTILS = ROOT / "scripts/towers/visuals/common/tower_visual_draw_utils.gd"
RENDERER = ROOT / "scripts/towers/tower_visual_renderer.gd"
TARGET_VISUALS = [
    "scripts/towers/visuals/by_id/nature_t1_visual.gd",
    "scripts/towers/visuals/by_id/ice_t1_visual.gd",
    "scripts/towers/visuals/by_id/fire_t1_visual.gd",
    "scripts/towers/visuals/by_id/light_t1_visual.gd",
    "scripts/towers/visuals/by_id/blacksmith_t1_visual.gd",
]


def function_body(text: str, name: str) -> str:
    pattern = rf"^static func {re.escape(name)}\b.*?(?=^static func |\Z)"
    match = re.search(pattern, text, flags=re.S | re.M)
    return match.group(0) if match else ""


def main() -> int:
    failures: list[str] = []
    text = UTILS.read_text(encoding="utf-8")
    renderer_text = RENDERER.read_text(encoding="utf-8")

    required_constants = {
        "MAX_POLYLINE_POINTS_PER_SHAPE": r"const MAX_POLYLINE_POINTS_PER_SHAPE := 24\b",
        "MAX_CIRCLE_SEGMENTS": r"const MAX_CIRCLE_SEGMENTS := 16\b",
        "MAX_DETAIL_SEGMENTS": r"const MAX_DETAIL_SEGMENTS := 12\b",
        "MAX_DRAW_CALLS_PER_TOWER_VISUAL": r"const MAX_DRAW_CALLS_PER_TOWER_VISUAL := 80\b",
        "MAX_DRAW_CALLS_PER_CATALOG_CARD": r"const MAX_DRAW_CALLS_PER_CATALOG_CARD := 35\b",
    }
    for name, pattern in required_constants.items():
        if re.search(pattern, text) is None:
            failures.append(f"missing or wrong value: {name}")

    for symbol in [
        "DetailQuality",
        "safe_draw_line",
        "safe_draw_polyline",
        "safe_draw_polygon",
        "safe_draw_circle",
        "safe_draw_rect",
        "safe_draw_arc",
        "_consume_draw_budget",
        "_is_valid_number",
        "_is_valid_point",
        "_is_valid_color",
    ]:
        if symbol not in text:
            failures.append(f"missing symbol: {symbol}")

    wrappers = {
        "safe_draw_line": [
            "from.distance_squared_to(to) <= 0.000001",
            "t.draw_line(from, to, color, width, antialiased)",
        ],
        "safe_draw_polyline": [
            "points.size() < 2 or points.size() > MAX_POLYLINE_POINTS_PER_SHAPE",
            "t.draw_polyline(points, color, width, closed)",
        ],
        "safe_draw_polygon": [
            "absf(_polygon_signed_area(points)) <= 0.0001",
            "t.draw_colored_polygon(points, color)",
        ],
        "safe_draw_circle": [
            "segments < 3 or segments > MAX_CIRCLE_SEGMENTS",
            "t.draw_circle(center, radius, color)",
        ],
        "safe_draw_rect": [
            "_is_valid_rect(rect)",
            "t.draw_rect(rect, color, false, width)",
        ],
        "safe_draw_arc": [
            "point_count < 3 or point_count > MAX_DETAIL_SEGMENTS",
            "t.draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)",
        ],
    }
    for wrapper, snippets in wrappers.items():
        body = function_body(text, wrapper)
        if not body:
            failures.append(f"missing wrapper body: {wrapper}")
            continue
        for snippet in snippets:
            if snippet not in body:
                failures.append(f"{wrapper} missing clause: {snippet}")

    required_behaviors = [
        ("is_instance_valid", "firewall must fail closed for invalid CanvasItem targets"),
        ("is_nan", "firewall must reject NaN values"),
        ("is_inf", "firewall must reject INF values"),
        ("ABSURD_COORDINATE_LIMIT", "firewall must reject absurd coordinates"),
        ("_draw_budget_cache", "firewall must track per-visual draw budgets"),
        ("Engine.get_frames_drawn()", "firewall must reset budgets per frame"),
        ("safe_draw_arc(t, Vector2.ZERO, 20, 0, TAU, 12", "tier-3 ring must respect the detail-segment cap"),
    ]
    for needle, message in required_behaviors:
        if needle not in text:
            failures.append(message)

    if "_resolve_detail_quality" not in renderer_text:
        failures.append("renderer must resolve detail quality")
    if "detail_quality := _resolve_detail_quality(t)" not in renderer_text:
        failures.append("renderer must compute detail quality before dispatch")
    if "draw_contour(t, detail_quality)" not in renderer_text:
        failures.append("renderer must thread detail quality into contour drawing")
    if "draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors, detail_quality)" not in renderer_text:
        failures.append("renderer must thread detail quality into top drawing")
    if "CatalogPreviewModeScript.is_static_preview(t)" not in renderer_text:
        failures.append("renderer must keep static preview on LOW")
    if "CatalogPreviewModeScript.is_selected_demo(t)" not in renderer_text:
        failures.append("renderer must keep selected demo on HIGH")
    if "bool(t.get(\"is_hovered\"))" not in renderer_text and "bool(t.get(\"hovered\"))" not in renderer_text:
        failures.append("renderer must keep hovered previews on HIGH")
    if "PerformanceBudgetService" in renderer_text:
        failures.append("renderer must not use performance quality to downgrade gameplay visuals")

    for rel_path in TARGET_VISUALS:
        visual_text = (ROOT / rel_path).read_text(encoding="utf-8")
        if "detail_quality" not in visual_text:
            failures.append(f"missing detail_quality parameter in {rel_path}")
        if "TowerVisualDrawUtils.DetailQuality.MEDIUM" not in visual_text:
            failures.append(f"missing medium default in {rel_path}")
        if "DetailQuality.LOW" not in visual_text:
            failures.append(f"missing LOW branch in {rel_path}")

    if failures:
        print("Tower draw safety audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Tower draw safety audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
