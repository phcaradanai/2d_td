#!/usr/bin/env python3
"""Stage 5N-7B: route element/interest build-status feedback through HUDStatePresenter.

This is intentionally narrow. It rewires only element-pick and interest-pick
status messages, leaving tower upgrade/sell/start-wave messages direct for now.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5n7b.bak"

REPLACEMENTS = {
	'\t\tgame_hud.set_build_status("Element unlocked: %s" % element_progression_manager.get_element_label(element_id))':
	'\t\t_bind_hud_state_presenter()\n\t\thud_state_presenter.set_build_status("Element unlocked: %s" % element_progression_manager.get_element_label(element_id))',
	'\t\tgame_hud.set_build_status("Cannot choose that element")':
	'\t\t_bind_hud_state_presenter()\n\t\thud_state_presenter.set_build_status("Cannot choose that element")',
	'\t\tgame_hud.set_build_status("Interest upgrade is already maxed")':
	'\t\t_bind_hud_state_presenter()\n\t\thud_state_presenter.set_build_status("Interest upgrade is already maxed")',
	'\t\tgame_hud.set_build_status("Interest upgraded to %s" % _format_interest_rate_percent())':
	'\t\t_bind_hud_state_presenter()\n\t\thud_state_presenter.set_build_status("Interest upgraded to %s" % _format_interest_rate_percent())',
}

EXPECTED_NEW_CALLS = [
	'hud_state_presenter.set_build_status("Element unlocked: %s" % element_progression_manager.get_element_label(element_id))',
	'hud_state_presenter.set_build_status("Cannot choose that element")',
	'hud_state_presenter.set_build_status("Interest upgrade is already maxed")',
	'hud_state_presenter.set_build_status("Interest upgraded to %s" % _format_interest_rate_percent())',
]


def main() -> None:
	text = MAIN.read_text()
	old = text
	for old_line, new_block in REPLACEMENTS.items():
		count = text.count(old_line)
		if count != 1:
			raise SystemExit(f"expected exactly one match for {old_line!r}, found {count}")
		text = text.replace(old_line, new_block, 1)

	for old_line in REPLACEMENTS:
		if old_line in text:
			raise SystemExit(f"direct build-status call still remains: {old_line!r}")
	for new_call in EXPECTED_NEW_CALLS:
		if new_call not in text:
			raise SystemExit(f"missing rewired presenter call: {new_call!r}")

	BACKUP.write_text(old)
	MAIN.write_text(text)
	print("Stage 5N-7B applied")
	print("Run: python3 tools/refactor/audit_hud_presenter_boundary.py")
	print("Run: godot --headless --path . --quit")


if __name__ == "__main__":
	main()
