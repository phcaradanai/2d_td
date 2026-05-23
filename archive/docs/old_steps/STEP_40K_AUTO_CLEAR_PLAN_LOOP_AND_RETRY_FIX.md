# STEP 40K AUTO CLEAR PLAN LOOP AND RETRY FIX

## 1. Current AUTO CLEAR flow

The debug panel calls `debug_auto_clear_level_7()`, which calls `debug_auto_clear_level(7)`.
That asks `BalanceSolver.solve_level_with_gold_testing("level_07")` for a plan and immediately calls `auto_play_plan(plan)` if the solver returns `PASS`.

The real gameplay executor is `scripts/debug/auto_play_verifier.gd`. It restarts the level, applies a debug-only starting gold override, executes `initial_actions`, starts waves from `wave_actions`, and monitors lives.

## 2. Why it places only one Cannon tower

The solver previously accepted the first simulated `PASS` without a second full-plan validation gate. Candidate ordering also preferred high remaining gold too heavily, so a cheap/short plan could win over a better role-aware plan.

For Level 7, that allowed a bad Cannon-only opening to be treated as usable.

## 3. Where the fallback/default plan is generated

The bad behavior came from `generate_initial_build_candidates()` and `_solve_from_state_with_beam()`.

The solver generated single-tower candidates, including Cannon-only openings, then selected a final beam state by remaining gold. The caller trusted that result as a valid autoplay plan.

## 4. Why wave start happened without enough defense validation

`debug_auto_clear_level()` only checked `res.status == "PASS"`. It did not require:

- `validated == true`
- `expected_lives_lost == 0`
- `covers_all_waves == true`
- one `start_wave` action for every wave
- a role-appropriate fast-wave opening

## 5. Why it did not place/upgrade after wave start

The autoplay loop only executes actions present in the plan. A plan with one initial Cannon and only `start_wave` for wave 1 has no additional placements or upgrades to execute.

The loop itself can continue, but a partial plan has nothing useful to do.

## 6. Why it did not stop/retry when HP drops

The verifier detected lives loss, but the auto-clear orchestration did not retry with the next debug gold candidate. The failure path now records the failed real run and retries from the next starting gold candidate when available.

The verifier also now stops the active wave and clears active enemies when HP loss is detected, so it does not passively let HP fall to 0.

## 7. Planned new state machine

The main debug flow now uses:

```gdscript
enum AutoClearState {
	IDLE,
	SOLVING,
	TESTING_GOLD_CANDIDATE,
	SIMULATING_CANDIDATE,
	PLAN_FOUND,
	AUTOPLAY_STARTING_LEVEL,
	AUTOPLAY_INITIAL_ACTIONS,
	AUTOPLAY_BEFORE_WAVE_ACTIONS,
	AUTOPLAY_STARTING_WAVE,
	AUTOPLAY_WAVE_RUNNING,
	AUTOPLAY_AFTER_WAVE_ACTIONS,
	AUTOPLAY_SUCCESS,
	AUTOPLAY_FAILED,
	NO_PLAN_FOUND
}
```

Plan validation rules:

- must include `level_id`
- must include `initial_actions`
- must include `wave_actions`
- must have `validated == true`
- must have `expected_lives_lost == 0`
- must have `covers_all_waves == true`
- must include `start_wave` for every level wave
- fast-pressure levels reject Cannon-only and fewer-than-two-opening-tower plans

Retry rules:

- current starting gold is tested first
- debug-only higher gold candidates are tested in order: +10, +20, +30, +40, +50, +75, +100
- if real autoplay loses HP, it fails immediately and retries at the next higher gold candidate
- normal tower, enemy, wave, and level data are not modified

## 8. Test results

Implemented code-level fixes:

- removed `+15` from the required gold candidate ladder
- added role-aware opening recipes for Rapid/Slow-heavy Level 7 plans
- lowered Cannon priority for fast-pressure waves
- fixed solver upgrade-cost simulation to use the current tower level's upgrade cost
- added full-plan validation before marking a plan autoplayable
- added `is_plan_valid_for_autoplay()` in `main.gd`
- added the same validation guard inside `auto_play_verifier.gd`
- added HP-loss fail-fast cleanup and retry orchestration
- fixed the actual one-Cannon root cause: initial candidates were created with `wave_num = 0`, but `_create_placement_candidate()` only stored `wave_num == 1` as `initial_actions`; multi-tower openings were being hidden under `wave_actions["0"]` and never executed by real autoplay

Level 7 smoke test:

- `solve_level_with_gold_testing("level_07")` generated multiple openings for each gold candidate
- bad simulated plans at 210 were rejected by validation
- first validated plan was found at debug-only starting gold 235
- validated plan metadata: `validated=true`, `covers_all_waves=true`, `expected_lives_lost=0`
- validated plan has 3 initial actions, so it no longer autoplays the one-Cannon fallback

Remaining limitations:

- real autoplay retry currently advances to the next debug gold candidate, not the next distinct same-gold plan
- the solver is still heuristic/beam-search based, not exhaustive
- parser validation uses `/Applications/Godot.app/Contents/MacOS/Godot` because the CLI binary is not on PATH
