#!/usr/bin/env python3
"""Stage 5N-10A: review HUDStatePresenter boundary usage.

This read-only audit helps decide whether hud_state_presenter is still an active
dependency owned by main.gd, or whether more UI calls should move behind
HUDStatePresenter in a later cleanup pass.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
PRESENTER = ROOT / "scripts/main/hud_state_presenter.gd"

ALLOWED_MAIN_PATTERNS = [
    r"const\s+HUD_STATE_PRESENTER_SCRIPT\b",
    r"var\s+hud_state_presenter\b",
    r"func\s+_bind_hud_state_presenter\b",
    r"_bind_hud_state_presenter\s*\(\)",
    r"hud_state_presenter\s*==\s*null",
    r"hud_state_presenter\s*=\s*HUD_STATE_PRESENTER_SCRIPT\.new\(\)",
    r"hud_state_presenter\.bind\(game_hud\)",
]

EXPECTED_MAIN_PRESENTER_METHODS = {
    "refresh_start_wave_button",
    "refresh_core_stats",
    "refresh_tower_shop",
    "set_build_status",
}

RECOMMENDED_PRESENTER_METHODS = {
    "set_status",
    "show_status",
    "show_wave_feedback",
    "refresh_tower_shop",
    "set_selected_tower",
    "refresh_selected_tower",
    "set_element_pick_status",
}

DIRECT_HUD_PATTERN = re.compile(r"\bgame_hud\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
PRESENTER_CALL_PATTERN = re.compile(r"\bhud_state_presenter\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
FUNC_PATTERN = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")


@dataclass(frozen=True)
class Match:
    line_no: int
    line: str
    method: str = ""


def read_lines(path: Path) -> list[str]:
    return path.read_text(errors="replace").splitlines()


def is_allowed_main_presenter_line(line: str) -> bool:
    stripped = line.strip()
    return any(re.search(pattern, stripped) for pattern in ALLOWED_MAIN_PATTERNS)


def collect_presenter_lines(lines: list[str]) -> tuple[list[Match], list[Match]]:
    allowed: list[Match] = []
    review: list[Match] = []
    for idx, line in enumerate(lines, start=1):
        if "hud_state_presenter" not in line and "HUD_STATE_PRESENTER_SCRIPT" not in line and "_bind_hud_state_presenter" not in line:
            continue
        call = PRESENTER_CALL_PATTERN.search(line)
        method = call.group(1) if call else ""
        match = Match(idx, line.strip(), method)
        if is_allowed_main_presenter_line(line) or method in EXPECTED_MAIN_PRESENTER_METHODS:
            allowed.append(match)
        else:
            review.append(match)
    return allowed, review


def collect_direct_hud_calls(lines: list[str]) -> list[Match]:
    calls: list[Match] = []
    for idx, line in enumerate(lines, start=1):
        m = DIRECT_HUD_PATTERN.search(line)
        if not m:
            continue
        calls.append(Match(idx, line.strip(), m.group(1)))
    return calls


def collect_presenter_api(lines: list[str]) -> set[str]:
    api: set[str] = set()
    for line in lines:
        m = FUNC_PATTERN.match(line.strip())
        if m:
            api.add(m.group(1))
    return api


def print_matches(title: str, matches: list[Match], limit: int = 30) -> None:
    print("\n" + title)
    print("-" * len(title))
    if not matches:
        print("  none")
        return
    for m in matches[:limit]:
        suffix = f" [{m.method}]" if m.method else ""
        print(f"  main.gd:{m.line_no}: {m.line}{suffix}")
    if len(matches) > limit:
        print(f"  ... {len(matches) - limit} more")


def main() -> None:
    main_lines = read_lines(MAIN)
    presenter_lines = read_lines(PRESENTER)
    presenter_api = collect_presenter_api(presenter_lines)

    allowed, needs_review = collect_presenter_lines(main_lines)
    direct_hud_calls = collect_direct_hud_calls(main_lines)
    direct_methods = {m.method for m in direct_hud_calls}
    move_candidate_methods = sorted(direct_methods & RECOMMENDED_PRESENTER_METHODS)
    missing_presenter_methods = sorted(set(move_candidate_methods) - presenter_api)

    print("HUD Presenter Boundary Audit")
    print("============================")
    print(f"Presenter API methods: {len(presenter_api)}")
    print(f"Allowed main presenter binding/calls: {len(allowed)}")
    print(f"Presenter lines needing review: {len(needs_review)}")
    print(f"Direct game_hud calls in main.gd: {len(direct_hud_calls)}")
    print(f"Direct game_hud methods that presenter already covers or should cover: {len(move_candidate_methods)}")

    print_matches("Allowed presenter boundary lines", allowed)
    print_matches("Presenter lines needing review", needs_review)
    print_matches("Direct game_hud calls still in main.gd", direct_hud_calls, limit=60)

    print("\nMove candidate methods")
    print("----------------------")
    if move_candidate_methods:
        for method in move_candidate_methods:
            coverage = "covered" if method in presenter_api else "missing presenter method"
            print(f"  {method}: {coverage}")
    else:
        print("  none")

    print("\nRecommendation")
    print("--------------")
    if needs_review:
        print("  REVIEW: unexpected hud_state_presenter usage remains in main.gd.")
    else:
        print("  PASS: hud_state_presenter usage is limited to active binding and expected refresh calls.")
    if move_candidate_methods:
        print("  NEXT: migrate small direct game_hud calls that are already covered by HUDStatePresenter.")
    if missing_presenter_methods:
        print("  NEXT: add presenter wrapper methods before moving these calls:")
        for method in missing_presenter_methods:
            print(f"    - {method}")


if __name__ == "__main__":
    main()
