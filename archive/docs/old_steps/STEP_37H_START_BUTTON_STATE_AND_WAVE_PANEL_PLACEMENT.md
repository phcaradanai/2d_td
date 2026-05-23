# STEP 37H - Start Button State And Wave Panel Placement

## Pre-Code Audit

### Current Top HUD Button Logic

Start Wave button node:

- Scene: `scenes/ui/GameHUD.tscn`
- Node path: `Root/TopBar/MarginContainer/HBoxContainer/StartWaveButton`
- Script reference: `scripts/ui/game_hud.gd`
- Variable: `@onready var start_wave_button`

Current functions that affect button text/state:

- `scripts/main/main.gd`
  - `_refresh_start_wave_ui()`
  - `_refresh_ui_for_phase()`
  - `_on_wave_started()`
  - `_on_wave_completed()`
  - `_on_all_waves_completed()`
  - `_on_game_over()`
  - `_on_victory()`
- `scripts/ui/game_hud.gd`
  - `update_start_wave_button(next_wave_number, total_waves, wave_name)`
  - `set_start_wave_enabled(enabled)`
  - `show_game_over()`
  - `show_victory()`
  - `enter_end_game_ui_state()`

Current problem in those helpers:

- `update_start_wave_button()` can set text to `Start N`.
- `set_start_wave_enabled(false)` always changes the text to `In Progress`.
- That means disabled is treated as equivalent to wave-running, even though disabled can also happen during setup, end-game, or non-gameplay phases.

### Current Gameplay State Variables

Wave state:

- `scripts/managers/wave_manager.gd`
  - `current_wave_index: int`
  - `is_wave_running: bool`
  - `active_enemy_count: int`
  - `is_spawning: bool`
  - `waves: Array`

Game phase:

- `scripts/main/main.gd`
  - `current_state: GameState`
  - states include `MENU`, `LEVEL_SELECT`, `BUILD`, `WAVE`, `PAUSED`, `GAME_OVER`, `VICTORY`

No separate `wave_in_progress` variable exists. The project uses `wave_manager.is_wave_running`.

Enemies remaining equivalent:

- `wave_manager.active_enemy_count`
- no `enemies_remaining` UI state variable exists.

### Current Timing Of Updates

Level start from World Map:

- `start_game(level_path)` stores loadout and calls `start_level(level_path)`.
- `start_level()` clears old HUD state, loads the level, sets `selected_level_id`, calls `_setup_game_from_level()`, then calls `set_game_phase(GameState.BUILD)`.
- `_setup_game_from_level()` loads and resets waves, then calls `update_hud()` and `_refresh_hud_wave_intel()`.
- Because `current_state` may still be `LEVEL_SELECT` during `_setup_game_from_level()`, `_refresh_start_wave_ui()` can compute `can_start == false`.

Restart:

- `restart_level()` calls `start_level(current_level_path)`.
- If current state is already gameplay or end-game, the order differs enough that the later BUILD refresh tends to restore `Start 1`, which is why restart appears correct.

Wave start:

- `_on_start_wave_requested()` calls `wave_manager.start_next_wave()`.
- `WaveManager.start_next_wave()` sets `is_wave_running = true`, increments `current_wave_index`, and emits `wave_started`.
- `_on_wave_started()` sets phase to `WAVE`, disables the button, and refreshes Wave Intel.

Wave end:

- `WaveManager._check_wave_completion()` sets `is_wave_running = false`, emits `wave_completed`, and may emit `all_waves_completed`.
- `_on_wave_completed()` sets phase to `BUILD`, awards reward, refreshes Wave Intel, and refreshes the start button.

### Root Cause: Button Says In Progress While Wave Intel Says Ready

The mismatch is caused by update ordering plus an overloaded button helper.

Exact path:

1. Level is loaded from World Map while `current_state` is still `LEVEL_SELECT`.
2. `_setup_game_from_level()` calls `update_hud()`.
3. `update_hud()` calls `_refresh_start_wave_ui()`.
4. `_refresh_start_wave_ui()` sees a next wave and calls `game_hud.update_start_wave_button(...)`, which sets the text to `Start 1`.
5. `_refresh_start_wave_ui()` then computes:
   - `wave_manager.is_wave_running == false`
   - `current_state == LEVEL_SELECT`
   - `can_start == false`
6. It calls `game_hud.set_start_wave_enabled(false)`.
7. `set_start_wave_enabled(false)` overwrites the text to `In Progress`.
8. Wave Intel separately uses `wave_manager.is_wave_running == false`, so it correctly displays `Status: Ready`.

So the Start button is not wrong because gameplay is running a wave. It is wrong because non-gameplay setup disabled the button through a helper that always labels disabled as `In Progress`.

### Current Wave Intel Panel Parent And Placement

Current parent:

- `WaveIntelPanel` is created dynamically in `scripts/ui/game_hud.gd`.
- It is added directly to `$Root`.
- It is positioned by `_layout_wave_intel_panel()` using top-right anchors and manual offsets.

Current placement issue:

- The gameplay world reserves a right-side area via `RIGHT_SIDEBAR_WIDTH`, but Wave Intel is still effectively an absolute-position overlay.
- It does not live in a right info column/container.
- It can feel visually detached from the HUD layout and too close to the map.

### Planned Fix

Start button:

- Replace mixed text/enabled calls with a single authoritative refresh:
  - `refresh_start_wave_button(...)` in `game_hud.gd`
  - `_refresh_start_wave_ui()` in `main.gd` becomes the only caller that computes gameplay state and passes it into that HUD method.
- The button text will be based on:
  - total waves
  - next wave number
  - `wave_manager.is_wave_running`
  - all-waves-cleared state
  - gameplay phase
- `set_start_wave_enabled(false)` will no longer mean `In Progress`; it will only set disabled state.
- Remove ad-hoc `set_start_wave_enabled(false)` calls from wave/gameover/victory flows where `_refresh_start_wave_ui()` can provide the real state.

Wave Intel placement:

- Create a dedicated `RightInfoColumn` under `GameHUD/Root`.
- Parent `WaveIntelPanel` into the right info column instead of `$Root`.
- Use container layout:
  - `RightInfoColumn`
    - `MarginContainer`
      - `VBoxContainer`
        - `WaveIntelPanel`
        - spacer
- Keep the panel inside the reserved right HUD area, top-aligned below the top bar.
- Keep `mouse_filter = IGNORE` for informational UI.

## Final Update

### Files Changed

- `scripts/main/main.gd`
- `scripts/ui/game_hud.gd`
- `docs/STEP_37H_START_BUTTON_STATE_AND_WAVE_PANEL_PLACEMENT.md`

### Root Cause Of Start Button State Mismatch

The Start Wave button state was split across two HUD calls:

- `update_start_wave_button()` set the correct ready text, such as `Start 1`.
- `set_start_wave_enabled(false)` then overwrote that text with `In Progress`.

During normal level start from the World Map, `_setup_game_from_level()` refreshed the HUD while `current_state` could still be `LEVEL_SELECT`. That made `_refresh_start_wave_ui()` compute `can_start == false`, even though `wave_manager.is_wave_running == false`.

Result:

- Wave Intel used the real wave-running state and displayed `Status: Ready`.
- Start Wave button used the generic disabled helper and displayed `In Progress`.

The bug was not a spawning-state issue. It was a UI helper conflating disabled with active wave.

### Final Start Button State Rules

`scripts/ui/game_hud.gd` now has one authoritative method:

- `refresh_start_wave_button(total_waves, next_wave_number, wave_name, wave_running, can_start, level_cleared, locked_label)`

Rules:

- no waves loaded:
  - text: `No Waves`
  - disabled: `true`
- game over:
  - text: `Game Over`
  - disabled: `true`
- all waves cleared:
  - text: `Cleared`
  - disabled: `true`
- wave running:
  - text: `In Progress`
  - disabled: `true`
- ready/build with next wave:
  - text: `Start N`
  - disabled: `false`
- non-gameplay setup/menu/map with next wave:
  - text remains `Start N`
  - disabled: `true`
  - it no longer says `In Progress` unless `wave_running == true`

`set_start_wave_enabled()` now only toggles disabled state. It no longer mutates the button text.

### Refresh Timing

`scripts/main/main.gd` now centralizes gameplay HUD syncing through:

- `_refresh_start_wave_ui()`
- `_refresh_gameplay_hud_state()`

The shared refresh is called when:

- entering BUILD phase
- entering WAVE phase
- wave starts
- wave clears
- all waves complete
- game over
- victory
- general `update_hud()`

Wave Intel also refuses to show outside BUILD/WAVE, preventing stale gameplay information during menu, World Map, Game Over, and Victory.

### New Wave Intel Parent And Layout

Wave Intel is no longer added directly to `$Root` as a top-right floating overlay.

New runtime structure:

- `GameHUD/Root`
  - `RightInfoColumn`
    - `MarginContainer`
      - `VBoxContainer`
        - `WaveIntelPanel`
        - `RightInfoSpacer`

Placement:

- `RightInfoColumn` is anchored to the right side below the 60px top bar.
- Width is aligned with the reserved right HUD area:
  - 260px normally
  - 240px on narrow viewports
- The panel fills the column width with 12px column margins.
- `mouse_filter = IGNORE` is used for the informational column and Wave Intel panel.

This keeps Wave Intel in the right-side HUD area instead of visually floating over the map.

### UI Refinement Changes

The panel keeps the Step 37G hierarchy but is now nested in a proper right-column container.

Current content structure:

- `WAVE INTEL`
- `Wave N / Total`
- `Status: Ready` or `Status: In Progress`
- `Upcoming` or `Current`
- main wave summary
- optional `Next`
- `Threats`
- `Suggested Towers`

Styling:

- dark navy card background
- subtle border
- 8px corner radius
- 16px card padding
- 7px section separation
- muted section labels
- brighter values
- warm threat color
- cyan suggested-tower color

### Manual And Headless Test Results

Test 1: Enter level from World Map

- State path now keeps `Start N` text even if an early setup refresh happens before BUILD.
- Once BUILD phase is entered, button is refreshed again and enabled.
- Expected visible result: Wave Intel `Status: Ready`, button `Start 1`.

Test 2: Start wave 1

Headless HUD probe:

- button: `In Progress`
- disabled: `true`
- Wave Intel: `Status: In Progress`, `Current`, `Fast x25`

Test 3: Wave 1 cleared

Headless HUD probe for next-ready state:

- button: `Start 2`
- disabled: `false`
- Wave Intel: `Status: Ready`, `Upcoming`, `Fast x40`

Test 4: Restart

- `start_level()` clears old Wave Intel.
- `wave_manager.reset_waves()` sets `current_wave_index = 0` and `is_wave_running = false`.
- Shared HUD refresh then displays `Start 1` and Ready Wave Intel.

Test 5: Right panel placement

Headless HUD probe confirmed:

- `WaveIntelPanel` parent is `VBoxContainer` inside the new right info column.
- `RightInfoColumn` becomes visible when Wave Intel is refreshed.
- The panel is no longer parented directly to `Root`.

Test 6: UI polish

- Wave Intel now lives inside a dedicated right column.
- It uses container margins instead of manual floating offsets.
- Section labels and values remain split and readable.

Test 7: Regression

Godot checks run:

- `Godot --headless --check-only --script res://scripts/main/main.gd`
- `Godot --headless --check-only --script res://scripts/ui/game_hud.gd`
- `Godot --headless --check-only --script res://scripts/ui/level_select.gd`
- `Godot --headless --path . --quit-after 3`

Results:

- Changed scripts parse successfully.
- Headless project startup succeeds.
- Existing unrelated startup warnings remain:
  - macOS CA certificate warning
  - invalid scene ext_resource UID warnings that fall back to text paths
  - existing Ogg Vorbis comment warning
  - resource cleanup warnings on forced quit

### Definition Of Done Status

Completed:

- Ready Wave Intel pairs with `Start N`.
- In-progress Wave Intel pairs with disabled `In Progress`.
- Restart path resets to wave 1 ready state.
- Start button text is no longer overwritten by generic disabled state.
- Wave Intel is parented into the right-side HUD info column.
- Wave Intel no longer uses root-level floating placement.
- Documentation updated.
