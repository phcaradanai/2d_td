# Tower Defense 2D - Element TD Milestones

> Repository: phcaradanai/2d_td
> Latest SHA at time of writing: `eb6c67fe99bf881480e90710682f44e795cbbbda`
> Latest commit: `Add top bar HUD boundary audit`
> Engine: Godot 4.6.2 (Stable)

This document records the long-term direction, the work already completed, the guardrails future agents must respect, and the prioritized roadmap of open milestones. It is intentionally written so any agent or human can read it before touching the project and avoid regressing previously stabilized work.

The list of "Completed / Stable" items is conservative. Items that the repository confirms (scripts, controllers, audits, decisions in `docs/`) are listed as complete. Items that match prior project direction but are not directly verifiable from the current tree are explicitly marked as **Known direction / needs verification** so future agents can confirm before relying on them.

---

## 1. Project Vision

The target direction for this game is a 2D tower defense inspired by **Element TD (Warcraft 3 custom map)** gameplay. The core experience we want to approach is:

- The player **chooses elements** during the run to unlock new tower families.
- Towers are built and upgraded as part of an **element combination tree** (single, dual, and triple element combinations) rather than a single linear path.
- Waves apply **pressure** with role-distinct enemies (fast, runner, hunter, healer, disruptor, tanky, etc.).
- A simple **interest economy** rewards saving gold and shapes the strategic question of "spend now to defend, or save now to scale".
- **Strategic tower placement**, lane shape, and element choice combine to create replayable tension between damage now and economy later.

The game should feel close in spirit to Element TD WC3, but it must:

- Use **original names** for elements, towers, enemies, modes, and levels.
- Use **original visuals**, **original code**, and **original assets** (or appropriately licensed open assets such as the existing Kenney audio).
- Avoid copying any **proprietary names, exact maps, or copyrighted art** from Warcraft 3 / Element TD or any derivative.

The Element TD reference is a **design north star**, not a content source.

---

## 2. Completed / Stable Milestones

The following items are observable in the current repository (`HEAD = eb6c67f`) or are explicit prior design decisions captured in `docs/`. They should be treated as completed/stabilized work and protected by the guardrails in section 3.

### Core gameplay loop

- **Dynamic maze / tower defense core is playable.** The repo ships with a Godot 4.6.2 project that boots from `scenes/main/Main.tscn`, drives waves, spawns enemies on an A*-grid path, lets the player build towers, and runs a complete level loop end-to-end. See `scripts/main/main.gd`, `scripts/map/maze_map_renderer.gd`, and the maze refactor plan in `docs/plans/2026-05-11-maze-td-refactor.md`.
- **Tower selling exists.** The player can sell placed towers. This is the intentional **correction mechanic** for misplaced or no-longer-useful towers.
- **Tower relocation / move is intentionally NOT part of the design.** **sell/rebuild** is the chosen correction loop. Adding a relocation feature is explicitly out of scope unless the design decision is reversed in writing.
- **Basic / starter tower is not forced into a linear Basic T1 → Basic T2 → Basic T3 path before branching.** The current direction treats the starter tower as a common early root that should branch out into element-based families. (See `docs/element_td_clone_scope.md` for the Element TD direction.)

### Element TD direction

- **Tower progression direction has shifted to Element TD-like element combination tree.** The repo contains `scripts/main/elemental_pick_controller.gd`, `scripts/main/elemental_shop_service.gd`, `scripts/main/element_td_interest_service.gd`, and `scripts/managers/element_progression_manager.gd`. The scope doc `docs/element_td_clone_scope.md` is explicit: choose elements, unlock elemental towers in the shop, build from the shop, upgrade per family, clear fixed-path waves, use gold/lives/interest.
- **Six-element design direction is accepted.** _Known direction / needs verification._ The actual canonical element list and its in-game labels should be confirmed against `scripts/managers/element_progression_manager.gd` and any element data files before any new content patch.
- **Single, dual, and triple element towers are the long-term tower tree direction.** _Known direction / needs verification for completeness._ The shop / progression services exist; the full single+dual+triple matrix is part of upcoming Milestone D in this document.
- **Element pick / interest pick system exists or is being restored.** `INTEREST_PICK_ID` and the interest pick flow are referenced in `scripts/main/main.gd` and implemented inside `elemental_pick_controller.gd` and `element_td_interest_service.gd`.

### main.gd refactor / controller architecture

- **Existing `main.gd` refactor started.** The git log shows multiple `refactor main file Ax` commits (`09977e9`, `91fcbf4`, `a0dbbb4`, `08a8bb6`) and a long Stage 5O series (`Stage 5O-1` through `Stage 5O-6F`) actively reducing `main.gd`.
- **`gameplay_layout_controller.gd` extracted.** Present at `scripts/main/gameplay_layout_controller.gd`; owns world layout, playfield rect, and map fitting.
- **`elemental_pick_controller.gd` extracted.** Present at `scripts/main/elemental_pick_controller.gd`; owns the element-pick / interest-pick coordination with HUD and progression manager.
- **`wave_flow_controller.gd` extracted.** Present at `scripts/main/wave_flow_controller.gd`; owns "is waiting for manual first wave", auto-next-wave countdown gating, etc.
- **Controller architecture polish / stability work is ongoing.** Stage 5O-3 introduced a **GameplayContext** dependency container; Stage 5O-5/5O-6 added a controller binder (`gameplay_controller_binder.gd`) and a `tower_interaction_controller.gd` skeleton. Recent hotfixes (`525f6ff`, `9ec2359`) restored HUD state fanout and bind constants after refactor regressions, confirming the work is iterative and still hardening.
- **Compatibility wrappers in `main.gd` are important and should not be deleted casually.** Wrappers like `_update_world_layout`, `_has_pending_element_pick`, `_can_auto_next_wave_countdown`, etc. now delegate to controllers. The audit `tools/refactor/audit_main_thin_wrappers.py` enforces that they exist, stay thin, and delegate correctly.

### UI and state

- **Interest UI / state is important and must remain visible to the player.** The repo has a dedicated audit `tools/refactor/audit_interest_ui_boundary.py`, and `main.gd` formats and emits an interest status string via `hud_state_presenter.set_interest_status(...)`.
- **Wave UI must clearly show current wave, next wave, countdown / active state, and interest information.** Multiple step docs (e.g. `docs/STEP_37G_WAVE_INTEL_STRICT_CORRECTNESS_AND_UI_REFINEMENT.md`, `docs/STEP_37H_START_BUTTON_STATE_AND_WAVE_PANEL_PLACEMENT.md`) and audits (`audit_start_wave_ui_boundary.py`, `audit_top_bar_hud_boundary.py`) protect this surface.
- **Enemies have role / visual differentiation work in progress.** _Known direction / needs verification._ Step docs reference Wave Intel composition tooltips and enemy type foundation work (`STEP_38A_ENEMY_TYPE_FOUNDATION_LAND_AIR.md`); the README's "In Progress" section lists enhanced tactical wave intel and additional enemy types.
- **Tower / enemy balance and role clarity are core goals.** Documented in `AGENTS.md` (hard balance rules), `docs/BALANCE_*` files at repo root, and the polish review report.

### Out-of-scope / removed direction

- **Hero / Guardian is no longer part of the Element TD-mode core loop.** See `docs/decisions/stage_5d_hero_guardian_cleanup.md`. The Element TD mode is intended to be a pure TD flow; runtime hero references are being removed conservatively.

If you find a system listed here that is no longer true on disk, **mark it as "needs verification" and update this section rather than silently relying on it**.

---

## 3. Current Architecture Guardrails

These rules govern any future code change. They protect the in-progress refactor and prevent regressions.

- **`main.gd` is being reduced gradually.** Do not perform massive single-patch extractions. Prefer small, audited stages (the existing Stage 5O cadence is a good model).
- **Do not turn controllers into remote copies of `main.gd`.** A controller is a small object with one responsibility; if a new controller starts pulling in unrelated state, split it.
- **Controllers must have one clear responsibility.** `gameplay_layout_controller` is layout. `elemental_pick_controller` is element/interest pick. `wave_flow_controller` is wave countdown gating. `tower_interaction_controller` is tower selection / build / sell / upgrade interaction. Do not blend these.
- **Prefer explicit `bind(deps)`, `GameplayContext`, or `Callable` dependencies.** All current controllers accept a `deps: Dictionary` and store explicit fields/callables. New controllers must follow the same pattern.
- **Avoid loose `owner` / `main` access.** Transitional `dependencies["main"]` paths exist (e.g. inside `ElementalPickController.bind`); they are explicitly marked transitional and should shrink, not grow.
- **Avoid direct calls like `main._private_method()` from controllers.** Wrap them in `Callable` dependencies passed through `bind(deps)` so the controller never reads private state through `main.`. The audit `audit_main_thin_wrappers.py` already detects `main._foo()` and `Callable(main, "_foo")` patterns.
- **Keep compatibility wrappers in `main.gd` until all call sites are verified.** Deleting a wrapper before audits and call-site sweeps confirm it is unused is a guaranteed regression source (Hotfix commits `525f6ff` and `9ec2359` exist precisely because of this risk).
- **Wrappers should stay thin.** A wrapper that exceeds ~8 non-empty lines (the threshold in `audit_main_thin_wrappers.py`) is a sign the underlying controller method is incomplete or that the wrapper is becoming a parallel implementation.
- **Do not create giant generic `utils.gd` / `helpers.gd` / `main_utils.gd` files.** The audit `audit_main_small_split.py` explicitly fails on these names. Split by responsibility, not by random line count.
- **Every file should be small enough to read fully through connector tools.** That means roughly: controllers stay well under 400 lines; auxiliary scripts under ~200 lines is preferred. `main.gd` is the exception and is on a known reduction track.

---

## 4. Gameplay Guardrails

These rules protect the design intent of the game. They must not be broken by refactors or "minor improvements".

- **Do not add tower relocation / move** unless the design decision is explicitly reversed in writing (e.g. a new decision file in `docs/decisions/`).
- **Selling towers is the intended correction mechanic.** Do not remove or hide the sell affordance.
- **Do not force the Basic Tower to upgrade linearly to Basic T3 before branching.** The starter tower acts as an **early root / common entry point**, not a forced funnel.
- **Basic / starter tower should act as an early root / common entry point** that connects into the element tree.
- **Element-based tower tree is the preferred long-term system.** New tower content should fit the single / dual / triple element progression, not orthogonal one-off systems.
- **Six elements should remain the foundation.** _Known direction / needs verification of canonical names._ Adding or removing the element count is a design-level change and must not happen silently inside a refactor.
- **Support single, dual, and triple element tower paths** as the long-term tree.
- **Do not remove the interest economy.** Interest is a core strategic dial.
- **Do not hide interest information from the UI.** Interest rate, accrual cadence, and totals must stay visible to the player.
- **Do not make wave UI ambiguous.** Current wave, next wave, countdown / active state, and pending element pick must be readable at a glance.
- **Do not make fast / runner / hunter / healer / disruptor / etc. roles overlap without reason.** Each role must mean something different in counter-play.
- **Do not change balance secretly during refactor patches.** Refactor patches must preserve behavior. Any intentional balance change belongs in its own clearly-labelled patch with notes.
- **Refactor patches must preserve behavior.** Signal names, signal timings, exported variables, node paths, and HUD-visible strings should be preserved unless the patch explicitly says it is changing them and why.

---

## 5. Element TD Warcraft 3 Reference Goals

These are the **target features** to approach over time. They define the gameplay shape we are heading toward. Each one should be implemented in original code, with original naming, and original visuals — **never by copying proprietary names, assets, or maps**.

- **Element pick progression.** Periodic pick of an element during the run (e.g. every N waves), unlocking new tower families.
- **Element levels.** Investing further into an already-picked element to deepen / strengthen that family.
- **Interest upgrade option.** A pick choice that converts an element-pick opportunity into an upgrade to the interest economy.
- **Wave pacing.** Manual first wave, then auto-advance with a countdown that the player can override.
- **Wave preview.** A clear preview of upcoming enemy composition so the player can react.
- **Clear enemy roles.** Distinct, non-overlapping enemy archetypes (fast, runner, hunter, healer, disruptor, armored, tanky, etc.) so counter-play is meaningful.
- **Elemental tower identities.** Each element has a recognizable damage flavor, attack pattern, and visual identity.
- **Single-element towers.** Entry-level towers tied to one element.
- **Dual-element towers.** Combination towers from two distinct elements with new behaviors.
- **Triple-element towers.** Top-tier combination towers from three distinct elements with strong, identity-defining behaviors.
- **Economy pressure through gold, interest, leaks, and build timing.** The player must always feel the trade-off between spending now and saving now.
- **Strong visual clarity** for tower damage type, enemy role, current wave status, and element choices.
- **Strategic choice tension: damage now vs economy later.** The interest pick versus the element pick is the cleanest expression of this tension.
- **Replayability through different element builds.** No single optimal element route.

**Important — non-infringement.** Do not copy exact proprietary names, exact tower names, exact map shapes, or copyrighted art from Warcraft 3 or Element TD. Use **original element names** (project-internal naming, not the Warcraft 3 names), **original tower names**, **original art**, and **original code**. The Element TD reference is for *gameplay shape*, not assets.

---

## 6. Open Milestones / Next Work

Prioritized roadmap. Each milestone is a small, testable scope. **Finish the earlier milestones before starting the later ones** unless there is a clear, documented reason.

### Milestone A — Controller Stability

- Stabilize extracted controllers (`gameplay_layout_controller`, `elemental_pick_controller`, `wave_flow_controller`, `tower_interaction_controller`).
- Remove ambiguous callback helpers; prefer `callv(args)` for callbacks with multiple arguments.
- Add **clear dependency binding** to every controller (`bind(deps)` + explicit fields).
- Add `is_bound()` / `has_required_dependencies()` methods where useful (already present on `WaveFlowController`).
- Keep `main.gd` wrappers thin.
- Extend / add audits for wrapper thinness and loose dependencies.

### Milestone B — `main.gd` Reduction

- Continue extracting small, safe groups (HUD plumbing, build-mode state, etc.).
- Avoid large, risky extraction batches.
- Add binding markers and responsibility regions inside `main.gd` so the remaining content is easy to reason about.
- Extract `TowerInteractionController` only after controller audits pass.

### Milestone C — TowerInteractionController

- Move tower selection, placement, upgrade, sell, hover, build-mode, and tower-interaction-UI logic out of `main.gd` and into `tower_interaction_controller.gd`.
- Keep compatibility wrappers in `main.gd`.
- Preserve signal timing (e.g. "tower placed", "tower sold", "tower selected").
- Preserve build / sell / upgrade behavior exactly.

### Milestone D — Element Tower Tree

- Define the six elements (original names, original visuals).
- Define all single-element towers (one per element).
- Define dual-element towers (every meaningful pair).
- Define triple-element towers (key triples).
- Define upgrade costs and unlock rules.
- Ensure Basic / starter tower **branches early** into the tree and does not force one linear path.

### Milestone E — Economy / Interest

- Ensure interest is "active only when X" or whichever design-approved behavior we land on (currently the interest service is gated by an enabled flag).
- Ensure **interest rate**, **next rate**, **timer / cadence**, and **total economy info** are visible.
- Ensure the **interest pick option** works, is selectable from the element pick UI, and is understandable.

### Milestone F — Wave System

- Improve wave preview (composition, counts, roles).
- Confirm **current wave** / **next wave** UI is not duplicated or misleading.
- Confirm **manual first wave** and **auto-next-wave countdown** behavior.
- Confirm leaks do not stall the game (an enemy escape should not freeze progression).

### Milestone G — Balance / Role Clarity

- Ensure every tower has a clear role.
- Ensure every enemy has a clear role.
- Avoid duplicate roles such as "fast" and "runner" both being only "fast".
- Verify **perfect-clear assumptions with real gameplay**, not only scripts (`AGENTS.md` rule 8).
- Balance around **meaningful strategic choices**, not around forcing one optimal build.

### Milestone H — Visual Polish

- Improve lane / route guidance for the player.
- Improve tower silhouettes and enemy silhouettes so role is readable at a glance.
- Improve the sci-fi neon / circuit / robotic-virus theme so it stays original and recognizable.
- Improve UI readability.
- **Avoid visual changes in refactor-only patches.**

### Milestone I — Regression Testing / Audit

- Add scripts that check `main.gd` wrapper thinness (already done — `audit_main_thin_wrappers.py`).
- Add scripts that check controller dependency quality (in progress — `audit_controller_stability.py`).
- Add gameplay smoke tests where possible (headless boot, one wave, one element pick).
- Maintain the **manual test checklist** in section 7 below.

---

## 7. Regression Checklist Before Every Patch

Future agents must read and answer each item before changing code:

1. Is this a **refactor patch** or a **gameplay patch**?
2. Does this patch change behavior intentionally? If yes, is the intended change documented in this patch's notes?
3. Are **compatibility wrappers** in `main.gd` preserved?
4. Are **signal names** and **node paths** preserved?
5. Are **exported variables** preserved?
6. Is **interest UI** still visible?
7. Is **wave UI** still correct (current wave, next wave, countdown, active state)?
8. Can the player still **sell towers**?
9. Is **tower relocation still intentionally absent**?
10. Does **element pick** still work end-to-end?
11. Does **wave start / countdown** still work?
12. Does **leak / respawn / end-of-wave** still work without stalling?
13. Did Godot **headless parse** pass?
    - `godot --headless --path . --quit`
14. Did relevant **audit scripts** pass?
    - `python3 tools/refactor/audit_main_thin_wrappers.py`
    - `python3 tools/refactor/audit_controller_stability.py`
    - `python3 tools/refactor/audit_tower_interaction_boundary.py`
    - `python3 tools/refactor/audit_interest_ui_boundary.py`
    - `python3 tools/refactor/audit_top_bar_hud_boundary.py`
    - `python3 tools/refactor/audit_project_guardrails.py` (this repo, if added)
15. Did **manual testing** cover at least one early wave and one element pick?

If you cannot answer "yes" (or "n/a with reason") to all of the above, **stop and document the gap** before committing.

---

## 8. Definition of Done

A patch is "done" when:

- **Godot parse check passes** (`godot --headless --path . --quit` exits cleanly).
- **Relevant audit scripts pass** (`tools/refactor/audit_*.py`).
- **No unrelated systems changed.**
- **`main.gd` does not grow unnecessarily.** Net additions to `main.gd` must be justified.
- **New files are focused and readable** (single responsibility, small enough to read end-to-end through connector tools).
- **Behavior changes are explicitly documented** in the patch description / CHANGELOG / step doc.
- **Manual test notes are included** (which waves were played, which element pick was tested, what looked right and what did not).

---

## Appendix — Files read while writing this document

- `README.md`
- `AGENTS.md`
- `docs/element_td_clone_scope.md`
- `docs/decisions/stage_5d_hero_guardian_cleanup.md`
- `docs/plans/2026-05-11-maze-td-refactor.md`
- `scripts/main/main.gd` (header / element + interest sections)
- `scripts/main/gameplay_layout_controller.gd`
- `scripts/main/elemental_pick_controller.gd`
- `scripts/main/elemental_pick_controller_bindings.gd`
- `scripts/main/wave_flow_controller.gd`
- `scripts/main/tower_interaction_controller.gd`
- `scripts/main/hud_state_presenter.gd`
- `tools/refactor/audit_main_thin_wrappers.py`
- `tools/refactor/audit_main_small_split.py`
- `git log` (latest 20 commits, `HEAD = eb6c67f`)

Where claims in this document could not be fully verified from the files above, the relevant bullet is marked **"Known direction / needs verification"**.
