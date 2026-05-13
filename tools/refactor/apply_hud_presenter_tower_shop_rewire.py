#!/usr/bin/env python3
"""Stage 5N-5: route tower shop refresh through HUDStatePresenter.

This keeps catalog/prices/element UI direct for now and changes only the
shop-list refresh call that HUDStatePresenter already wraps.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main/main.gd"
BACKUP = ROOT / "scripts/main/main.gd.stage5n5.bak"
OLD = "\tgame_hud.refresh_tower_shop(ids)"
NEW = "\t_bind_hud_state_presenter()\n\thud_state_presenter.refresh_tower_shop(ids)"


def main() -> None:
	text = MAIN.read_text()
	old = text
	count = text.count(OLD)
	if count != 1:
		raise SystemExit(f"expected exactly one direct refresh_tower_shop call, found {count}")
	text = text.replace(OLD, NEW, 1)
	if OLD in text:
		raise SystemExit("direct refresh_tower_shop call still remains")
	if "hud_state_presenter.refresh_tower_shop(ids)" not in text:
		raise SystemExit("tower shop refresh was not rewired to HUDStatePresenter")
	BACKUP.write_text(old)
	MAIN.write_text(text)
	print("Stage 5N-5 applied")
	print("Run: python3 tools/refactor/audit_hud_presenter_boundary.py")
	print("Run: godot --headless --path . --quit")


if __name__ == "__main__":
	main()
