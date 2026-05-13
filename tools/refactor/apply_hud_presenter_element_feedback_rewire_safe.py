#!/usr/bin/env python3
"""Stage 5N-7C: safe element/interest build-status feedback rewire.

This replaces the original 5N-7B script with an indentation-preserving version.
If the previous script already produced scripts/main/main.gd.stage5n7b.bak, this
script restores that backup before applying the safe replacement.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
PREVIOUS_BACKUP = ROOT / "scripts/main/main.gd.stage5n7b.bak"
BACKUP = ROOT / "scripts/main/main.gd.stage5n7c.bak"

TARGETS = [
	'game_hud.set_build_status("Element unlocked: %s" % element_progression_manager.get_element_label(element_id))',
	'game_hud.set_build_status("Cannot choose that element")',
	'game_hud.set_build_status("Interest upgrade is already maxed")',
	'game_hud.set_build_status("Interest upgraded to %s" % _format_interest_rate_percent())',
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
	if PREVIOUS_BACKUP.exists():
		text = PREVIOUS_BACKUP.read_text()
		print("Restored source from previous Stage 5N-7B backup")
	else:
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
			raise SystemExit(f"direct build-status call still remains: {target}")
	if "\t\t\t_bind_hud_state_presenter()" in new_text:
		raise SystemExit("unsafe triple-indented presenter binding detected")
	if "hud_state_presenter.set_build_status" not in new_text:
		raise SystemExit("presenter build-status calls were not written")

	MAIN.write_text(new_text)
	print("Stage 5N-7C applied")
	print("Run: python3 tools/refactor/audit_hud_presenter_boundary.py")
	print("Run: godot --headless --path . --quit")


if __name__ == "__main__":
	main()
