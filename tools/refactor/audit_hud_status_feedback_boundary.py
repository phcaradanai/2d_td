#!/usr/bin/env python3
"""Stage 5N-9: audit direct HUD status feedback calls in main.gd.

Read-only audit. It separates direct game_hud.set_build_status calls by rough
context so the next migration can stay conservative and indentation-safe.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"

DIRECT_STATUS_PATTERN = re.compile(r"\bgame_hud\.(set_build_status|set_status|show_status)\s*\((.*)")
PRESENTER_STATUS_PATTERN = re.compile(r"\bhud_state_presenter\.(set_build_status|set_status|set_warning|set_success|set_danger)\s*\((.*)")

SAFE_NEXT_KEYWORDS = [
	"Selected:",
	"Choose an element before starting the next wave",
]

DEFER_KEYWORDS = [
	"Tower Upgraded!",
	"Not enough gold!",
	"Tower sold",
	"Upgrade unavailable",
]


@dataclass(frozen=True)
class StatusCall:
	line_no: int
	line: str
	method: str
	message_hint: str
	category: str


def categorize(line: str) -> str:
	for keyword in DEFER_KEYWORDS:
		if keyword in line:
			return "defer_tower_action"
	for keyword in SAFE_NEXT_KEYWORDS:
		if keyword in line:
			return "safe_next_candidate"
	if "Element" in line or "Interest" in line or "element" in line:
		return "element_interest"
	return "review"


def collect(pattern: re.Pattern[str], lines: list[str]) -> list[StatusCall]:
	calls: list[StatusCall] = []
	for idx, line in enumerate(lines, start=1):
		match = pattern.search(line)
		if not match:
			continue
		calls.append(StatusCall(
			line_no=idx,
			line=line.strip(),
			method=match.group(1),
			message_hint=match.group(2).strip(),
			category=categorize(line),
		))
	return calls


def print_group(title: str, calls: list[StatusCall]) -> None:
	print("\n" + title)
	print("-" * len(title))
	if not calls:
		print("  none")
		return
	for call in calls:
		print(f"  main.gd:{call.line_no}: [{call.category}] {call.line}")


def main() -> None:
	lines = MAIN.read_text(errors="replace").splitlines()
	direct = collect(DIRECT_STATUS_PATTERN, lines)
	presenter = collect(PRESENTER_STATUS_PATTERN, lines)

	print("HUD Status Feedback Boundary Audit")
	print("==================================")
	print(f"Direct game_hud status calls: {len(direct)}")
	print(f"Presenter status calls: {len(presenter)}")

	for category in ["element_interest", "safe_next_candidate", "defer_tower_action", "review"]:
		print_group(
			f"Direct status calls: {category}",
			[call for call in direct if call.category == category],
		)

	print_group("Presenter status calls", presenter)

	print("\nRecommendation")
	print("--------------")
	if any(call.category == "safe_next_candidate" for call in direct):
		print("  NEXT: migrate only safe_next_candidate calls through HUDStatePresenter.")
	else:
		print("  PASS: no obvious low-risk direct status candidates remain.")
	if any(call.category == "defer_tower_action" for call in direct):
		print("  DEFER: tower upgrade/sell status should move in a separate pass after UI smoke test.")


if __name__ == "__main__":
	main()
