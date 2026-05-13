#!/usr/bin/env python3
"""Stage 5N-10B: route low-risk build-status feedback through HUDStatePresenter.

This is intentionally narrow and indentation-preserving. It rewires only the two
safe_next_candidate calls reported by audit_hud_status_feedback_boundary.py.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5n10b.bak"

TARGETS = [
	'game_hud.set_build_status("Choose an element before starting the next wave")',
	'game_hud.set_build_status("Selected: " + tower_name + hint)',
]


def rewire_line(line: str) -> list[str] | None:
	stripped = line.strip()
	if stripped not in TARGETS:
		return None
	indent = line[: len(line) - len(line.lstrip())]
	return [
		indent + "_bind_hud_state_presenter()",
		indent + stripped.replace("game_hud.", "hud_state_presenter.", 1),
	]


def main() -> None:
	text = MAIN.read_text()
	BACKUP.write_text(text)

	out: list[str] = []
	replaced = 0
	for line in text.splitlines():
		new_lines = rewire_line(line)
		if new_lines is None:
			out.append(line)
		else:
			out.extend(new_lines)
			replaced += 1

	if replaced != len(TARGETS):
		raise SystemExit(f"expected {len(TARGETS)} replacements, applied {replaced}")

	new_text = "\n".join(out) + "\n"
	for target in TARGETS:
		if target in new_text:
			raise SystemExit(f"direct safe status call still remains: {target}")
	for expected in [
		'hud_state_presenter.set_build_status("Choose an element before starting the next wave")',
		'hud_state_presenter.set_build_status("Selected: " + tower_name + hint)',
	]:
		if expected not in new_text:
			raise SystemExit(f"missing presenter status call: {expected}")

	MAIN.write_text(new_text)
	print("Stage 5N-10B applied")
	print("Run: python3 tools/refactor/audit_hud_status_feedback_boundary.py")
	print("Run: python3 tools/refactor/audit_hud_presenter_boundary.py")
	print("Run: godot --headless --path . --quit")


if __name__ == "__main__":
	main()
