#!/usr/bin/env python3
"""Audit that project guardrail docs exist and mention the key phrases.

This audit is intentionally small and low-risk. It does NOT inspect gameplay
code or scripts. It only confirms that the two guardrail documents:

    docs/MILESTONES.md
    docs/AGENT_GUARDRAILS.md

exist and contain the key phrases that future agents must respect. If a phrase
is missing, the audit emits a clear warning. If a whole file is missing, the
audit fails so the gap is impossible to ignore.

Exit codes:
    0 — both files present, every required phrase found.
    1 — at least one required document is missing, or one or more required
        phrases are missing.

Usage:
    python3 tools/refactor/audit_project_guardrails.py
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MILESTONES = ROOT / "docs" / "MILESTONES.md"
GUARDRAILS = ROOT / "docs" / "AGENT_GUARDRAILS.md"

# Phrases that must appear in either document. Case-insensitive substring match.
REQUIRED_PHRASES = [
    "Element TD",
    "interest",
    "element pick",
    "compatibility wrappers",
    "main.gd",
    "TowerInteractionController",
    "no tower relocation",
    "sell/rebuild",
]


def _check_file(path: Path) -> tuple[bool, str]:
    """Return (exists, contents_lower). Empty string if missing."""
    if not path.exists():
        return False, ""
    try:
        text = path.read_text(errors="replace")
    except OSError as exc:
        print(f"  ERROR could not read {path}: {exc}")
        return False, ""
    return True, text.lower()


def main() -> int:
    print("Project guardrail audit")
    print("-----------------------")

    failures: list[str] = []
    warnings: list[str] = []

    milestones_ok, milestones_text = _check_file(MILESTONES)
    guardrails_ok, guardrails_text = _check_file(GUARDRAILS)

    if milestones_ok:
        print(f"  OK   found {MILESTONES.relative_to(ROOT)}")
    else:
        msg = f"missing {MILESTONES.relative_to(ROOT)}"
        print(f"  FAIL {msg}")
        failures.append(msg)

    if guardrails_ok:
        print(f"  OK   found {GUARDRAILS.relative_to(ROOT)}")
    else:
        msg = f"missing {GUARDRAILS.relative_to(ROOT)}"
        print(f"  FAIL {msg}")
        failures.append(msg)

    combined_text = milestones_text + "\n" + guardrails_text

    print()
    print("Required phrases")
    print("----------------")
    for phrase in REQUIRED_PHRASES:
        needle = phrase.lower()
        if needle in combined_text:
            print(f"  OK   '{phrase}'")
        else:
            print(f"  WARN '{phrase}' not found in MILESTONES.md or AGENT_GUARDRAILS.md")
            warnings.append(phrase)

    print()
    if failures:
        print("Result: FAIL")
        for f in failures:
            print(f"  - {f}")
        if warnings:
            print("Also missing required phrases:")
            for w in warnings:
                print(f"  - {w}")
        return 1

    if warnings:
        print("Result: FAIL (missing required phrases)")
        for w in warnings:
            print(f"  - {w}")
        return 1

    print("Result: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
