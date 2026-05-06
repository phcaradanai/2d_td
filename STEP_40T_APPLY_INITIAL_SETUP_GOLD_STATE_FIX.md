# STEP_40T_APPLY_INITIAL_SETUP_GOLD_STATE_FIX.md

## 1. Problem
After Auto Clear completes a successful run and calculates the "Recommended Starting Gold", the "Apply Initial Setup Gold" button fails with the message: `[BALANCE] No valid initial setup gold recorded.`

## 2. Root Cause
- **Incorrect Enum Indices**: In `main.gd`, the `_on_verifier_state_changed` function was checking for `state == 15` (Completed) and `state == 16` (Failed). These were the line numbers in the script, not the actual enum values (which are 8 and 9).
- **State Capture Failure**: Because the index check failed, the verifier's findings (`auto_clear_verified_initial_setup_gold`) were never copied into `last_auto_clear_result` in `main.gd`.

## 3. Fixed State Flow
1. **Verifier Finishes**: `_complete_success()` calculates `auto_clear_verified_initial_setup_gold = 230` and emits `state_changed(8, ...)`.
2. **Main Receives Signal**: `_on_verifier_state_changed(8, ...)` matches `AutoPlayState.COMPLETED`.
3. **Main Captures Data**:
   - `last_auto_clear_result["verified_setup_gold"] = 230`
   - `last_auto_clear_result["success"] = true`
4. **Apply Button Clicked**: `_apply_verified_starting_gold()` reads `230` from `last_auto_clear_result` and updates the level config.

## 4. Key Variables
- `auto_play_verifier.auto_clear_verified_initial_setup_gold`: Source of truth from the verifier.
- `main.last_auto_clear_result["verified_setup_gold"]`: Persistent storage in main for UI and application.

## 5. UI Improvements
- The "Apply" button will now be disabled if no valid `verified_setup_gold` exists in `last_auto_clear_result`.
