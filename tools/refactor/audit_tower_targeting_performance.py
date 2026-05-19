#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOWER = ROOT / "scripts" / "towers" / "tower.gd"


def read() -> str:
    return TOWER.read_text(encoding="utf-8")


def body(text: str, name: str) -> str:
    match = re.search(rf"^func {re.escape(name)}\([^)]*\).*?(?=^func |\Z)", text, re.M | re.S)
    return match.group(0) if match else ""


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    text = read()
    errors: list[str] = []

    process_body = body(text, "_process")
    cached_body = body(text, "_is_valid_cached_target")
    find_body = body(text, "find_target")
    range_body = body(text, "get_enemies_in_range")

    require(errors, "var retarget_interval" in text, "tower.gd must define per-tower retarget_interval")
    require(errors, "var retarget_timer" in text, "tower.gd must define per-tower retarget_timer")
    require(errors, "var range_sq" in text, "tower.gd must cache range_sq")
    require(errors, "var target_update_phase" in text, "tower.gd must define target_update_phase for staggered scans")
    require(errors, "_configure_targeting_cache" in text, "tower.gd must configure cached targeting flags/range")
    require(errors, "_reset_retarget_timer" in text, "tower.gd must reset retarget timer with jitter")
    require(errors, cached_body != "", "tower.gd must define _is_valid_cached_target")
    require(errors, "distance_squared_to" in cached_body, "_is_valid_cached_target must use distance_squared_to")
    require(errors, "distance_to(" not in cached_body, "_is_valid_cached_target must not use distance_to")
    require(errors, "can_target_enemy" not in cached_body, "_is_valid_cached_target must avoid can_target_enemy hot-path call")
    require(errors, "_should_retarget" in process_body, "_process must use _should_retarget gate")
    require(errors, "update_target()" in process_body, "_process must still update targets through update_target")
    require(errors, "is_valid_target(current_target)" not in process_body, "_process must not call expensive is_valid_target(current_target)")
    require(errors, "distance_to(" not in range_body, "get_enemies_in_range must not use distance_to")
    require(errors, "sort_custom" not in find_body, "find_target must not sort candidates")
    require(errors, ".filter(" not in find_body and ".map(" not in find_body, "find_target must not filter/map allocate candidates")

    print("Tower targeting performance audit")
    print("=================================")
    if errors:
        for item in errors:
            print(f"FAIL: {item}")
        print("\nResult: FAIL")
        return 1
    print("Result: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
