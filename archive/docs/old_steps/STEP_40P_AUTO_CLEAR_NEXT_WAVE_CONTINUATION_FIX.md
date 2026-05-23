# STEP_40P_AUTO_CLEAR_NEXT_WAVE_CONTINUATION_FIX.md

## 1. Current Auto Clear State After Wave Ends
Currently, Auto Clear transitions from `WAVE_RUNNING` to `AFTER_WAVE_ACTIONS` once it detects the wave is complete. However, the detection depends on a mix of `completed_wave_pending` (signal-based) and `is_auto_clear_wave_complete()` (state-based). If these are out of sync, the transition might fail or stall.

## 2. How Wave Completion is Detected
Wave completion is detected by checking:
- `wave_manager.is_wave_running == false`
- `wave_manager.active_enemy_count == 0`
- `wave_manager.is_spawning == false`
- `get_tree().get_nodes_in_group("enemies").size() == 0`

## 3. Current `current_wave` Behavior
Auto Clear tracks the wave number in `current_wave` (starting at 1). It uses this to pull actions from the plan.

## 4. Current `wave_running` Behavior
`wave_manager.is_wave_running` is the source of truth for the engine's wave state. It becomes false in `_check_wave_completion()` when all enemies are gone and spawning has stopped.

## 5. Why Next Wave is Not Started
The transition logic was occasionally missing the `wave_completed` signal or failing to advance `current_wave` in a way that triggered the next `BEFORE_WAVE_ACTIONS`. Additionally, there was no robust "handled" flag to ensure a wave completion is processed exactly once.

## 6. Final Fix
- **Robust Detection**: `auto_clear_is_wave_fully_complete()` now strictly checks all spawning and active enemy flags.
- **Handled Flag**: `auto_clear_handled_wave_complete` prevents duplicate triggers.
- **Standardized Transitions**: `auto_clear_on_wave_complete()` and `auto_clear_start_next_wave_if_available()` provide a clean path from wave end to next wave start.
- **Improved Logging**: Clear logs for every stage of the transition (Complete -> Prepare -> Start).
