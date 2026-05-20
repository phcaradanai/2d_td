#!/usr/bin/env python3
"""Audit tower draw firewall symbols."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
UTILS = ROOT / "scripts/towers/visuals/common/tower_visual_draw_utils.gd"


def main() -> int:
    failures: list[str] = []
    text = UTILS.read_text(encoding="utf-8")

    required_symbols = [
        "MAX_POLYLINE_POINTS_PER_SHAPE",
        "MAX_CIRCLE_SEGMENTS",
        "MAX_DETAIL_SEGMENTS",
        "MAX_DRAW_CALLS_PER_TOWER_VISUAL",
        "MAX_DRAW_CALLS_PER_CATALOG_CARD",
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
    ]
    for symbol in required_symbols:
        if symbol not in text:
            failures.append(f"missing symbol: {symbol}")

    required_behaviors = [
        ("is_instance_valid", "firewall must fail closed for invalid CanvasItem targets"),
        ("is_nan", "firewall must reject NaN values"),
        ("is_inf", "firewall must reject INF values"),
        ("ABSURD_COORDINATE_LIMIT", "firewall must reject absurd coordinates"),
        ("_draw_budget_cache", "firewall must track per-visual draw budgets"),
        ("Engine.get_frames_drawn()", "firewall must reset budgets per frame"),
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
