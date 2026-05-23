# STEP 40L AUTO CLEAR BETWEEN-WAVE UPGRADE AND CONTINUE

## 1. Current Auto Clear state machine

The real run executor is `scripts/debug/auto_play_verifier.gd`. It now uses:

```gdscript
IDLE
STARTING_LEVEL
APPLYING_INITIAL_ACTIONS
BEFORE_WAVE_ACTIONS
STARTING_WAVE
WAVE_RUNNING
AFTER_WAVE_ACTIONS
PREPARING_NEXT_WAVE
COMPLETED
FAILED
```

The main debug orchestration in `scripts/main/main.gd` still owns solve/retry/report state.

## 2. Current plan format

Plans contain:

- `level_id`
- `starting_gold_used`
- `validated`
- `expected_lives_lost`
- `covers_all_waves`
- `initial_actions`
- `wave_actions`

`wave_actions` now supports both legacy arrays and the preferred structure:

```gdscript
wave_actions["1"] = {
	"before_wave": [{"type": "start_wave"}],
	"after_wave": []
}
```

Legacy array actions are normalized by `BalanceSolver._normalize_plan_wave_actions()`.

## 3. Whether plan includes after_wave or before_next_wave actions

The solver primarily plans between-wave work as `before_wave` actions for the upcoming wave, because rewards are already applied in the simulated state after the previous wave clears.

The executor also supports `after_wave` actions for plans that explicitly use them.

## 4. How rewards are applied after wave clear

In real gameplay, `WaveManager` emits `wave_completed`, and `GameManager.award_wave_completion()` applies the reward before Auto Clear enters `AFTER_WAVE_ACTIONS`.

In simulation, `simulate_wave()` adds `completion_reward` to `sim.gold` when the queue and active enemies are empty.

## 5. How upgrade cost is read

Real gameplay reads upgrade cost from the placed tower via `tower.get_upgrade_cost()`.

Simulation reads the current tower level's `upgrade_cost` from `data/towers.json`, using the current level index.

## 6. How tower upgrade is executed

Real gameplay uses the same tower method as player upgrades:

```gdscript
game_manager.spend_gold(cost)
tower.upgrade()
```

Auto Clear supports upgrade references by:

- explicit action id such as `rapid_a`
- cell/type reference such as `rapid_tower@7,4`
- direct `cell` field

## 7. Why Auto Clear did not continue to next wave

The old executor only filtered legacy array actions by `timing`, then jumped from wave-complete directly to the next array. It did not clearly model `AFTER_WAVE_ACTIONS` or `PREPARING_NEXT_WAVE`, and it did not support the newer nested `before_wave` / `after_wave` format.

If the next wave lacked a readable `start_wave` action, the run could appear stopped after Wave 1.

## 8. Planned fix

Implemented:

- explicit `WAVE_RUNNING`, `AFTER_WAVE_ACTIONS`, and `PREPARING_NEXT_WAVE` executor states
- reliable `is_auto_clear_wave_complete()` check using wave running, spawning, active enemy count, and enemy group count
- fallback auto-start when a wave lacks explicit `start_wave`
- `plan_between_wave_actions()` in the solver
- upgrade scoring for coverage, DPS gain per gold, role match, and wave pressure
- build scoring for coverage, role match, missing Slow role, and affordability
- safe upgrade execution through tower refs or cells
- safe build execution through `BuildManager.validate_placement()`
- status/log updates while moving between waves

## Level 7 test result

Solver smoke test for Level 7:

- current gold candidates are tested in order
- first validated plan found at debug gold `235`
- plan has `validated=true`
- plan has `covers_all_waves=true`
- plan has `expected_lives_lost=0`
- plan has three initial actions and nested wave action support
- dumped plan includes Wave 2 `before_wave` work, for example an added `rapid_tower` build before `start_wave`
- report smoke passes and includes Wave 2 / `before_wave` details

Remaining limitations:

- real same-gold alternate-plan retry is still limited; failed real runs advance to the next gold candidate
- planner is heuristic beam search, not exhaustive
- headless full autoplay is noisy in isolation because some scene scripts expect `current_scene`; the executor did place all initial towers and start Wave 1 during the headless check, but scene-only camera/damage-number errors make that run unsuitable as the final automated assertion
- parser, solver smoke, plan dump, and report smoke tests pass
