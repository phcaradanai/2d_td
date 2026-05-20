#!/usr/bin/env python3
"""Audit tower draw firewall symbols."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
UTILS = ROOT / "scripts/towers/visuals/common/tower_visual_draw_utils.gd"


def function_body(text: str, name: str) -> str:
    pattern = rf"^static func {re.escape(name)}\b.*?(?=^static func |\Z)"
    match = re.search(pattern, text, flags=re.S | re.M)
    return match.group(0) if match else ""


def main() -> int:
    failures: list[str] = []
    text = UTILS.read_text(encoding="utf-8")

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

    if failures:
        print("Tower draw safety audit FAILED:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Tower draw safety audit PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
