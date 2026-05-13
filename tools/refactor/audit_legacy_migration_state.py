#!/usr/bin/env python3
"""Stage 5J-1: Audit legacy migration state before removing sync variables.

The refactor currently keeps some legacy variables in main.gd so older HUD/gameplay
call sites can keep working while services are introduced. This audit reports
where those variables and legacy helper functions are still referenced.
"""
from __future__ import annotations

from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[2]
SEARCH_DIRS = [ROOT / "scripts", ROOT / "scenes", ROOT / "data"]

LEGACY_SYMBOLS = [
    # Auto next wave migration state.
    "auto_next_wave_enabled",
    "auto_next_wave_delay_sec",
    "auto_next_wave_remaining",
    "auto_next_wave_countdown_active",
    "has_started_first_wave",
    "_sync_auto_next_wave_state_from_service",
    "_can_auto_next_wave_countdown",
    # Element TD interest migration state.
    "element_td_interest_enabled",
    "element_td_interest_base_rate",
    "element_td_interest_rate",
    "element_td_interest_upgrade_step",
    "element_td_interest_upgrade_count",
    "element_td_interest_max_upgrades",
    "element_td_interest_interval_sec",
    "element_td_interest_elapsed",
    "element_td_interest_disabled_for_wave",
    "_sync_interest_state_from_service",
    # HUD presenter migration state.
    "hud_state_presenter",
    "_bind_hud_state_presenter",
]

SERVICE_SYMBOLS = [
    "WaveIntelService",
    "ElementalShopService",
    "ElementTDInterestService",
    "AutoNextWaveService",
    "HUDStatePresenter",
]

FILE_SUFFIXES = {".gd", ".tscn", ".tres", ".json", ".cfg"}


def iter_files() -> list[Path]:
    files: list[Path] = []
    for base in SEARCH_DIRS:
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix in FILE_SUFFIXES:
                files.append(path)
    return sorted(files)


def scan_symbol(files: list[Path], symbol: str) -> list[tuple[Path, int, str]]:
    matches: list[tuple[Path, int, str]] = []
    for path in files:
        try:
            lines = path.read_text(errors="replace").splitlines()
        except Exception as exc:
            print(f"WARN: cannot read {path.relative_to(ROOT)}: {exc}")
            continue
        for idx, line in enumerate(lines, start=1):
            if symbol in line:
                matches.append((path, idx, line.strip()))
    return matches


def classify_line(symbol: str, line: str) -> str:
    stripped = line.strip()
    if stripped.startswith("var ") and symbol in stripped:
        return "declaration"
    if stripped.startswith("func ") and symbol in stripped:
        return "function"
    if f"{symbol} =" in stripped or f"{symbol}=" in stripped:
        return "write"
    if f"{symbol}." in stripped or f"{symbol}(" in stripped:
        return "call/read"
    return "reference"


def print_report(title: str, symbols: list[str], files: list[Path]) -> None:
    print("\n" + title)
    print("=" * len(title))
    for symbol in symbols:
        matches = scan_symbol(files, symbol)
        print(f"\n{symbol}: {len(matches)} match(es)")
        grouped: dict[str, int] = defaultdict(int)
        for _, _, line in matches:
            grouped[classify_line(symbol, line)] += 1
        if grouped:
            print("  classes: " + ", ".join(f"{k}={v}" for k, v in sorted(grouped.items())))
        for path, line_no, line in matches[:20]:
            print(f"  {path.relative_to(ROOT)}:{line_no}: {line}")
        if len(matches) > 20:
            print(f"  ... {len(matches) - 20} more")


def main() -> None:
    files = iter_files()
    print(f"Scanned {len(files)} files")
    print_report("Legacy migration symbols", LEGACY_SYMBOLS, files)
    print_report("Service symbols", SERVICE_SYMBOLS, files)
    print("\nNext cleanup rule of thumb:")
    print("- Do not remove a legacy variable while it still has non-declaration references outside sync helpers.")
    print("- Prefer removing one service family's legacy state per commit.")
    print("- Run: godot --headless --path . --quit")


if __name__ == "__main__":
    main()
