# STEP 40M AUTO CLEAR EXECUTE BETWEEN-WAVE ACTIONS

## 1. Current Auto Clear plan structure

Auto Clear plans use:

- `initial_actions`
- `wave_actions`
- `validated`
- `expected_lives_lost`
- `covers_all_waves`

The intended executable format is:

```gdscript
wave_actions["2"] = {
	"before_wave": [
		{"type": "upgrade_tower", "tower_ref": "rapid_tower@6,4"},
		{"type": "start_wave"}
	],
	"after_wave": []
}
```

Legacy array wave actions are still normalized into this structure.

## 2. Where upgrade decisions are generated

Upgrade and build decisions are generated in `scripts/debug/balance_solver.gd`:

- `_generate_candidates_for_wave()`
- `plan_between_wave_actions()`
- `_best_upgrade_action()`
- `_best_build_action()`

The solver also generates ordinary single upgrade or build candidates, so diagnostic logs can mention many actions that do not survive into the final selected plan.

## 3. Whether upgrade decisions are actually stored in the plan

Some upgrade decisions are stored, but candidate logs were misleading. A logged upgrade only means that candidate was considered. It does not guarantee that candidate became the final validated plan.

Root cause found:

- Candidate upgrade logs were printed for every explored state.
- The beam scorer did not value upgraded tower levels strongly, so an ordinary Wave 2 build could beat a Wave 2 upgrade candidate even though many upgrades were logged.
- The final plan was not dumped before autoplay, making it look like the logged candidate upgrades were supposed to execute.

Fix:

- Final executable plans are now dumped before real autoplay.
- Candidate upgrade/build spam is hidden unless `auto_clear_verbose_solver_logs` is enabled.
- The beam scorer now rewards upgraded tower levels, especially Rapid/Slow upgrades for fast pressure.
- Level 7 final plan now includes Wave 2 `before_wave` upgrade + build + start.

## 4. Where autoplay reads before_wave / after_wave actions

Real autoplay reads wave actions in `scripts/debug/auto_play_verifier.gd` through `_get_actions(wave_num, timing)`.

That reader supports both:

- nested dictionary format: `before_wave` / `after_wave`
- legacy arrays filtered by `timing`

## 5. Whether executor supports upgrade_tower actions

The executor supports:

- `place_tower`
- `upgrade_tower`
- `start_wave`

`upgrade_tower` resolves a tower by id, metadata, `tower_type@x,y`, or cell, then calls the real tower upgrade path: spend gold through `GameManager`, then call `tower.upgrade()`.

## 6. Whether wave completion detection fires correctly

Completion currently checks:

- `wave_manager.is_wave_running == false`
- `wave_manager.is_spawning == false`
- `wave_manager.active_enemy_count == 0`
- enemy group count is zero

Fix implemented:

- The verifier now connects to `WaveManager.wave_completed`.
- Polling still confirms no running wave, no spawning, no active enemies, and no enemy group nodes.
- The executor only enters `AFTER_WAVE_ACTIONS` for the wave that actually emitted completion.
- Completion logs include `Wave running=false active_enemies=0 pending_spawns=0 => complete`.

## 7. Whether wave reward is available before upgrades

`WaveManager.wave_completed` is connected to `Main._on_wave_completed()`, which awards reward through `GameManager.award_wave_completion()`.

Because reward is signal-driven, the executor waits one process frame after detecting completion before running `after_wave` actions. This avoids spending before reward appears.

## 8. Why the system does not start the next wave automatically

The executor has a fallback auto-start, but final plan visibility was poor and candidate logs made it look like planned actions existed even when the selected plan did not contain them. The executor also treated `start_wave` as a no-op action and always started in the next state, which made logs less explicit.

Fix implemented:

- The final plan is printed before autoplay.
- Wave 2 `before_wave` actions execute before the Wave 2 start.
- If the plan has no explicit `start_wave`, the executor logs a fallback and starts the wave.
- Starting a wave now goes through Main's real `_on_start_wave_requested()` path when available.

## 9. Planned fix

- Added a canonical `get_wave_action_list()` helper in the executor and main validation.
- Normalized and dumped the final plan before autoplay.
- Validated that every wave has parseable actions.
- Required final plans to contain at least one between-wave non-start action when the level has multiple waves.
- Registered placed towers by both action id and `tower_type@x,y`.
- Executed `start_wave` through the same real gameplay start path when possible.
- Deferred after-wave actions by one frame after completion so reward gold is present.
- Added concise final-plan logs and quieted candidate-selection spam by default.
- Updated tests with solver smoke, plan dump, report smoke, and targeted upgrade execution smoke.

## 10. Final plan format

Final Level 7 dump now includes:

```gdscript
"2": {
	"before_wave": [
		{"type": "upgrade_tower", "tower_ref": "rapid_tower@8,4", "cell": [8, 4]},
		{"type": "place_tower", "id": "slow_9_4", "tower_type": "slow_tower", "cell": [9, 4]},
		{"type": "start_wave"}
	],
	"after_wave": []
}
```

## 11. Test results

- Headless project parse: PASS.
- Level 7 solver smoke: PASS, validated full-wave plan at debug gold `235`, zero expected lives lost.
- Level 7 final plan dump: PASS, Wave 2 before-wave includes `upgrade_tower`, `place_tower`, and `start_wave`.
- Report smoke: PASS, report includes Wave 2 before-wave details.
- Targeted upgrade executor smoke: PASS, `rapid_tower@8,4` resolved, upgraded from level 1 to 2, and gold changed from `190` to `125`.

Remaining limitation:

- Full headless autoplay remains noisy because several visual scene scripts expect `current_scene`; targeted executor smoke verifies the same real placement and tower upgrade methods without changing permanent data.
