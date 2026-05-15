# Agent Guardrails

> **Read this file before changing anything in this repository.**
> Companion document: [`docs/MILESTONES.md`](./MILESTONES.md) — the longer roadmap, vision, and verification details.
> Repository: phcaradanai/2d_td · Engine: Godot 4.6.2 · Reference SHA: `eb6c67f`.

This is the short version. If anything here conflicts with `docs/MILESTONES.md`, both files are wrong — update them together.

---

## Golden Rules

1. **Refactor patches must preserve behavior.** Signals, node paths, exported variables, HUD strings, gameplay outcomes.
2. **Read before writing.** Pull the latest repo state, read relevant files, record the SHA. Never write from memory only.
3. **One responsibility per file.** No giant `utils.gd`. No generic dump files.
4. **Small, audited steps.** Prefer many small patches over one large one. Run audits after every patch.
5. **When in doubt, leave it alone.** Especially balance, signal timings, and `main.gd` wrappers.
6. **Element TD is the design north star.** Original names, original assets, original code — never copies of proprietary content.

---

## Refactor Rules

- `main.gd` is on a **gradual reduction track**. Do not perform large, risky extractions.
- New controllers must:
  - Live under `scripts/main/`
  - Accept dependencies via `bind(deps: Dictionary)`
  - Use explicit fields and `Callable` for injected callbacks
  - Avoid `main._private_method(...)` and `Callable(main, "_private_method")` from inside controller bodies (those are detected by `audit_main_thin_wrappers.py`)
  - Provide `is_bound()` / `has_required_dependencies()` where useful
- `main.gd` **compatibility wrappers** must stay until all call sites are verified. Delete only when an audit pass + manual sweep confirms safety.
- Wrappers must stay **thin** (≤ 8 non-empty lines is the current audit threshold).
- Prefer `GameplayContext` / explicit dependency dictionaries over loose `owner` / `main` access.
- Do not create files named `utils.gd`, `helpers.gd`, `controller_utils.gd`, or `main_utils.gd`. Use responsibility-based names.
- For high-risk `main.gd` changes, prefer adding or running focused extractors/audits first, such as `tools/refactor/extract_main_sections.py` and `tools/refactor/audit_main_tower_upgrade_flow.py`, instead of reviewing the whole file through truncated tool output.

---

## Gameplay Rules

- **Tower selling stays.** It is the intentional correction mechanic — the **sell/rebuild** loop is how players correct mistakes.
- **Tower relocation / move does not exist** and must not be added unless a written design decision reverses this (e.g. a new file in `docs/decisions/`).
- **Basic / starter tower is an early root, not a forced linear funnel.** Do not lock Basic → Basic T2 → Basic T3 before branching.
- **Six elements** are the long-term foundation. Single, dual, and triple element towers are the long-term tree.
- **Element tower upgrades must be gated by element level.** Upgrading into a target tower config must pass `element_progression_manager.can_build_tower(target_config)`, not only `tower.can_upgrade()`.
- **Interest economy stays.** Do not remove it. Do not silently retune it.
- **Wave pacing** (manual first wave, auto next wave countdown, override) stays.
- **Enemy roles** (fast, runner, hunter, healer, disruptor, armored, tanky, …) must stay distinct.
- **Do not change balance** in a refactor patch. Balance changes belong in their own clearly-labelled patch.

---

## UI Rules

- **Interest information** (rate, next rate, cadence, totals) must be visible.
- **Wave UI** must clearly show: current wave, next wave, countdown vs active state, pending element pick (when applicable).
- **Element pick UI** must be clear about what is being chosen and what the alternative (interest upgrade) does.
- HUD strings, panel placement, and signal timings must be preserved during refactors. Boundary audits exist for the HUD top bar (`audit_top_bar_hud_boundary.py`), the start-wave UI (`audit_start_wave_ui_boundary.py`), the interest UI (`audit_interest_ui_boundary.py`), and the HUD presenter (`audit_hud_presenter_boundary.py`).
- Avoid visual changes inside refactor-only patches.
- Do not hurt frame rate or introduce new performance regressions. 60 frame rate is the target or better.
---

## Element TD Direction

- Element pick progression (periodic pick during the run).
- Element levels (invest deeper in already-picked elements).
- Interest upgrade pick (an alternative to picking an element).
- Wave preview with clear enemy composition.
- Clear elemental tower identities (damage flavor + visual).
- Single, dual, and triple element towers.
- Economic pressure: gold, interest, leaks, build timing.
- Strategic tension: damage now vs economy later.
- Replayability across element builds.
- **Never** copy proprietary names, assets, or maps from Warcraft 3 / Element TD. Original names, original art, original code only.

For the full direction, see `docs/MILESTONES.md` §1 and §5, and `docs/element_td_clone_scope.md`.

---

## Do Not Break List

The following items must continue to work end-to-end after any patch. If a patch puts any of them at risk, it must call that out explicitly in the patch notes.

- **Tower selling.**
- **No tower relocation / move** unless explicitly approved by a new design decision file.
- **Element pick** (the periodic element-choice flow).
- **Element tower upgrade gate** (target tower config must require the matching element level; e.g. Light T2 requires Light 2).
- **Interest upgrade pick** (the alternative to picking an element).
- **Interest display** (rate, next rate, totals visible in the HUD).
- **Wave current / next display** (the player can always tell which wave is now and which is coming).
- **Countdown / active wave state** (manual first wave, auto-next-wave countdown, active wave indicator).
- **`main.gd` compatibility wrappers** (do not delete casually; keep them thin).
- **Controller bind / dependency structure** (`bind(deps)`, `Callable` dependencies, no `main._private(...)` from controller bodies).
- **Tower tree branch direction** (starter tower is a root that branches; no forced linear T1→T2→T3 path before branching).
- **Enemy role clarity** (distinct fast / runner / hunter / healer / disruptor / armored / tanky roles).

---

## Required Checks Before Commit

Run every relevant check. Record exactly what was run and what passed in the patch notes.

```bash
# Godot parse / boot check (uses the alias in AGENTS.md if applicable)
godot --headless --path . --quit

# Refactor audits — run any that apply to the touched area
python3 tools/refactor/audit_main_thin_wrappers.py
python3 tools/refactor/audit_main_small_split.py
python3 tools/refactor/audit_controller_stability.py
python3 tools/refactor/audit_tower_interaction_boundary.py
python3 tools/refactor/audit_main_tower_upgrade_flow.py
python3 tools/refactor/audit_hud_presenter_boundary.py
python3 tools/refactor/audit_hud_status_feedback_boundary.py
python3 tools/refactor/audit_interest_ui_boundary.py
python3 tools/refactor/audit_top_bar_hud_boundary.py
python3 tools/refactor/audit_start_wave_ui_boundary.py
python3 tools/refactor/audit_legacy_migration_state.py

# Guardrails doc audit (this repo)
python3 tools/refactor/audit_project_guardrails.py

# Manual smoke test
# - boot the game
# - play one full early wave
# - exercise one element pick
# - verify interest UI updates
# - sell at least one tower
# - verify an element tower cannot upgrade beyond the owned element level
```

If Godot is not installed in the current environment, **report that the command could not be run** rather than claiming it passed.

---

## Required Final Report Format

Every change you submit should end with a final report shaped like this. Copy the headings; fill them in with what actually happened.

```
## Files read
- <path> @ <SHA / version if available>
- ...

## Files created / updated
- <path> (created | updated)
- ...

## Summary of milestones documented / advanced
- ...

## Summary of guardrails reinforced or relaxed
- ...

## Items marked "needs verification"
- ...

## Checks run
- godot --headless --path . --quit : PASS | FAIL | NOT RUN (why)
- audit_*.py : PASS | FAIL | NOT RUN (why)

## Confirmation
- [ ] No gameplay code was changed (for documentation-only patches)
- [ ] Compatibility wrappers preserved
- [ ] Signal names / node paths / exported vars preserved
- [ ] Interest UI still visible
- [ ] Wave UI still correct
- [ ] Tower selling still works
- [ ] Tower relocation still intentionally absent
- [ ] Element pick still works
- [ ] Element tower upgrade gate still works
- [ ] Wave start / countdown still works
- [ ] Manual test notes attached
```

If any checkbox is left unchecked, explain why in the report.

## Element UI Rule
Never render raw element_id, element_index, or numeric enum values directly in UI.
All element UI must go through ElementIcon / ElementDisplay helper.