# STEP 37G - Wave Intel Strict Correctness And UI Refinement

## Pre-Code Audit

### Level 7 Config Structure

File: `data/levels/level_07.json`

Level 7 is configured as:

- `id`: `level_07`
- `name`: `Fast Lane`
- `area_id`: `2`
- `area_name`: `Iron Sector`
- `difficulty`: `Normal`
- `enemy_intel`: `["Fast", "Heavy"]`
- `recommended_roles`: `["Rapid", "Slow"]`
- `starting_gold`: `140`
- `starting_lives`: `20`
- `waves_path`: `res://data/waves/waves_07.json`
- path: straight lane from `[0, 5]` to `[19, 5]`
- `spawn_cell`: `[0, 5]`
- `base_cell`: `[19, 5]`

### Exact Level 7 Wave Config

File: `data/waves/waves_07.json`

Current checked-in Level 7 wave data:

- Wave 1: `Velocity Check`
  - `completion_reward`: `50`
  - groups:
    - `enemy_type`: `fast`
    - `count`: `25`
    - `spawn_delay`: `0.4`
  - extracted summary from current source: `Fast x25`

- Wave 2: `Sonic Waves`
  - `completion_reward`: `70`
  - groups:
    - `enemy_type`: `fast`
    - `count`: `40`
    - `spawn_delay`: `0.2`
  - extracted summary from current source: `Fast x40`

Important acceptance mismatch found during audit:

- The task states Level 7 Wave 1 must be `Fast x40`.
- The actual source file currently defines Level 7 Wave 1 as `Fast x25`.
- Showing `Fast x40` before Wave 1 without changing spawning data would make Wave Intel lie about the real wave config.

### Current Wave Intel Preview Helper

Current helper in `scripts/main/main.gd`:

- `load_waves_config(path: String) -> Array`
- `summarize_wave(wave_data: Dictionary) -> Dictionary`
- `get_wave_preview_data(waves_path: String) -> Array[Dictionary]`
- `format_wave_enemy_summary(summary: Dictionary) -> String`

Current problem:

- The helper accepts a wave file path rather than the selected level id.
- The HUD asks for previews by `waves_path`, so stale/default paths can be displayed if refresh happens before the selected level is fully loaded.
- The returned data uses legacy keys (`counts`, `total`, `recommended`) rather than the requested strict preview shape (`enemy_counts`, `total_count`, `recommended_roles`).

### Current Wave Progression Variables

Current variables:

- Selected/current level:
  - `scripts/main/main.gd`: `current_level_id: String`
  - `scripts/main/main.gd`: `current_level_path: String`
  - No numeric `selected_level_id` variable currently exists.
- Wave progress:
  - `scripts/managers/wave_manager.gd`: `current_wave_index: int`
  - `scripts/managers/wave_manager.gd`: `is_wave_running: bool`
  - `scripts/managers/wave_manager.gd`: `waves: Array`
  - `scripts/managers/wave_manager.gd`: `active_wave_number`
  - `scripts/managers/wave_manager.gd`: `active_wave_name`
  - `scripts/managers/wave_manager.gd`: `active_wave_reward`
- Total waves:
  - `wave_manager.get_total_waves()`
  - current Level 7 total from `waves_07.json`: `2`

Indexing behavior:

- In ready/build state, `current_wave_index` points at the upcoming wave.
- When a wave starts, `WaveManager.start_next_wave()` increments `current_wave_index` immediately after capturing the active wave.
- During a running wave, the active preview index is therefore `current_wave_index - 1`.

### Current UI Refresh Flow

Current flow:

- `start_level()` calls `set_game_phase(GameState.BUILD)` before `level_manager.load_level()`.
- `set_game_phase(BUILD)` calls `_refresh_ui_for_phase()`.
- `_refresh_ui_for_phase()` shows HUD and calls `_refresh_hud_wave_intel()`.
- `_refresh_hud_wave_intel()` passes `wave_manager.waves_data_path` into `game_hud.refresh_wave_intel()`.
- `WaveManager.waves_data_path` defaults to `res://data/waves.json`.
- `data/waves.json` Wave 1 is `basic` count `6`, normalized as `Normal x6`.

### Root Cause: Wrong Level 7 Wave Summary

Primary root cause:

- The HUD refreshes Wave Intel before the selected level has loaded and before `WaveManager.load_waves_from_file(level_manager.waves_path)` has applied the level-specific wave path.
- At that early moment, Wave Intel can read `WaveManager.waves_data_path`, which defaults to `res://data/waves.json`.
- The default file Wave 1 is `basic x6`, which displays as `Normal x6`.

Secondary root cause:

- `get_wave_preview_data()` uses a path argument, not the current gameplay level id.
- This allows stale path/default path data to leak into the in-game HUD.

### Root Cause: Rough Panel Layout

Current Wave Intel panel is created dynamically in `scripts/ui/game_hud.gd`.

Current UI issues:

- One compact label combines section title and value (`Upcoming: ...` or `Now: ...`).
- Next-wave text is another single-line label with weaker hierarchy.
- Threats and suggestions are prefixed inline (`Threats: ...`, `Suggested: ...`) instead of grouped.
- Vertical spacing is only `4px`, making the panel cramped.
- Padding is light and the background/border style reads like a debug overlay.
- The title, state, content, threats, and suggested tower roles do not have enough visual hierarchy.

### Planned Fix

Data/source-of-truth plan:

- Add a numeric `selected_level_id` in `main.gd` and set it only after the level is loaded.
- Replace path-driven in-game preview fetching with level-id-driven preview fetching.
- Implement:
  - `get_wave_preview_data(level_id: int) -> Array[Dictionary]`
  - `get_wave_preview_for_index(level_id: int, wave_index: int) -> Dictionary`
  - `summarize_wave_for_preview(wave) -> Dictionary`
- Use the current gameplay level's loaded `wave_manager.waves` when the requested level id matches the active level.
- Fall back only to that level's own `waves_path` for non-active level previews such as World Map Mission Intel.
- Do not fall back to `data/waves.json` for in-game Wave Intel.
- Do not substitute Mission Intel enemy summaries into in-game Wave Intel.
- Add debug logging for selected level id, level name, total wave count, Wave 1 preview, and Wave 2 preview.

Display-state plan:

- Ready/build state:
  - `Wave N / Total`
  - `Status: Ready`
  - Section: `Upcoming`
  - Summary: upcoming wave only
- Running state:
  - `Wave N / Total`
  - `Status: In Progress`
  - Section: `Current`
  - Summary: active wave
  - Optional `Next` section only when a next wave exists
- Remove any `After` style line.
- Clear/hide stale panel state on level start, restart, menu return, and when no valid preview exists.

UI plan:

- Rebuild the dynamic panel as a compact info card with:
  - strong title
  - separate wave/status lines
  - clean separators
  - section label and value labels
  - separate Threats and Suggested Towers groups
- Increase padding and spacing.
- Use dark navy panel background, subtle border, muted section labels, brighter values, soft warning color for threats, and cool accent for suggestions.
- Keep it anchored in the right HUD area with a stable width around 300px.

## Final Update

### Files Changed

- `scripts/main/main.gd`
- `scripts/ui/game_hud.gd`
- `scripts/ui/level_select.gd`
- `docs/STEP_37G_WAVE_INTEL_STRICT_CORRECTNESS_AND_UI_REFINEMENT.md`

Small regression cleanup included:

- `scripts/ui/game_hud.gd`: changed optional `CenterNextLevelButton` lookup to `get_node_or_null()` because the scene creates that button dynamically when absent.
- `scripts/main/main.gd`: removed a duplicate `all_waves_completed` signal connection.

### Root Cause Of Wrong Level 7 Wave Data

The in-game Wave Intel could refresh before `level_manager.load_level()` and `wave_manager.load_waves_from_file(level_manager.waves_path)` had completed.

At that point:

- `current_level_id` was not yet updated for the new level.
- `WaveManager.waves_data_path` could still be its default: `res://data/waves.json`.
- `data/waves.json` Wave 1 is `basic` count `6`.
- The preview normalizer converts `basic` to `Normal`.

That produced the bad in-game display:

- `Normal x6`

This was a stale/default wave path leak, not a Level 7 preview extraction failure once the correct file is used.

### Fix Applied To Preview Extraction And Indexing

Implemented strict preview helpers in `scripts/main/main.gd`:

- `get_wave_preview_data(level_id: int) -> Array[Dictionary]`
- `get_wave_preview_for_index(level_id: int, wave_index: int) -> Dictionary`
- `summarize_wave_for_preview(wave) -> Dictionary`

Preview extraction now:

- Uses numeric `selected_level_id`.
- Reads from active `wave_manager.waves` only when:
  - active `level_manager.level_id` matches the requested level id
  - `wave_manager.waves_data_path` matches `level_manager.waves_path`
  - loaded waves are non-empty
- Falls back only to the requested level's own `waves_path` for non-active previews such as World Map Mission Intel.
- Does not use `res://data/waves.json` as an in-game Wave Intel fallback.
- Skips malformed groups instead of inventing `basic` or `count = 1`.
- Aggregates multiple groups by normalized enemy type.
- Outputs the requested structure:
  - `enemy_counts`
  - `total_count`
  - `traits`
  - `recommended_roles`

Display indexing now follows `WaveManager` exactly:

- Ready/build: `current_wave_index` is the upcoming wave index.
- In progress: active wave index is `current_wave_index - 1` because `WaveManager.start_next_wave()` increments immediately after capturing the active wave.

### Final Display Rules

Ready/build state:

- `Wave N / Total`
- `Status: Ready`
- `Upcoming`
- current upcoming wave composition
- no `Next`
- no `After`

Running state:

- `Wave N / Total`
- `Status: In Progress`
- `Current`
- running wave composition
- optional `Next` only if another wave exists
- no `After`

Final wave running:

- shows `Current`
- hides `Next`

### UI Refinement Improvements

The Wave Intel panel is now a compact right-side HUD card with:

- 300px stable width
- 16px horizontal padding
- 14px vertical padding
- dark navy panel background
- subtle blue border
- 8px radius
- separated title, wave/status, wave summary, threats, and suggested tower groups
- muted section labels
- brighter main values
- warm threat color
- cool suggested-tower color
- optional next-wave section that hides cleanly

Removed rough/debug-like formatting:

- no crammed `Upcoming: ...` combined label
- no inline `Threats: ...` and `Suggested: ...` prefixes
- no stale `Next` line in Ready state
- no `After` line

### Manual And Headless Test Results

Test 1: Level 7 before Wave 1

- Source selected: `level_07`
- Level name: `Fast Lane`
- Source waves path: `res://data/waves/waves_07.json`
- Extracted total waves: `2`
- Extracted Wave 1 preview from current source: `Fast x25`
- Result: no `Normal x6`, no stale default preview
- Important: this does not meet the requested `Fast x40` acceptance text because the current source file defines Wave 1 as `Fast x25`.

Test 2: Level 7 during Wave 1

Headless HUD probe result:

- `Wave 1 / 2`
- `Status: In Progress`
- `Current`
- `Fast x25`
- `Next`
- `Fast x40`

Test 3: Level 7 after Wave 1

Headless HUD probe result:

- `Wave 2 / 2`
- `Status: Ready`
- `Upcoming`
- `Fast x40`
- `Next` hidden

Test 4: Restart Level 7

- `start_level()` now clears Wave Intel before loading.
- `selected_level_id` is reset from the loaded level id before preview refresh.
- `WaveManager` reloads the level-specific wave file before HUD refresh.
- Expected result with current source: reset to `Wave 1 / 2`, `Status: Ready`, `Upcoming`, `Fast x25`.

Test 5: Switch Levels

- In-game preview no longer uses a path supplied by the HUD.
- Active previews require both matching level id and matching wave data path.
- Starting Level 7 after another level cannot reuse another level's loaded wave list.

Test 6: UI Quality

- Panel structure is separated into title, state, content, threats, and suggested sections.
- Spacing, padding, and colors were refined for a compact strategy HUD card.
- The card remains top-right aligned in CanvasLayer UI space.

Test 7: Regression

Godot checks run:

- `Godot --headless --check-only --script res://scripts/main/main.gd`
- `Godot --headless --check-only --script res://scripts/ui/game_hud.gd`
- `Godot --headless --check-only --script res://scripts/ui/level_select.gd`
- `Godot --headless --path . --quit-after 3`

Results:

- Changed scripts parse successfully.
- Headless project startup succeeds.
- Remaining startup warnings are unrelated existing/environment warnings:
  - macOS CA certificate warning
  - invalid scene ext_resource UID warnings that fall back to text paths
  - existing Ogg Vorbis comment warning
  - resource cleanup warnings on forced quit

### Level 7 Fast x40 Acceptance Status

Not marked complete as `Fast x40` for Level 7 Wave 1.

Reason:

- The actual checked-in source of truth is `data/waves/waves_07.json`.
- That file defines Level 7 Wave 1 as `fast` count `25`.
- The task also says not to change actual wave spawning behavior or rebalance waves.
- Changing Level 7 Wave 1 from `25` to `40` would alter spawning behavior.

Current completed correctness result:

- Wave Intel now displays the real current Level 7 config.
- With current data, that is `Fast x25` for Wave 1 and `Fast x40` for Wave 2.
- The old incorrect `Normal x6` default preview leak is fixed.
