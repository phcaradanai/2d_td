# STEP 37I - Right HUD Panel Layout Conflict Fix

## Pre-Code Audit

### Current Gameplay HUD Structure

Scene: `scenes/ui/GameHUD.tscn`

Current right-side HUD pieces:

- `Root/RightSidebar`
  - scene-authored `PanelContainer`
  - contains Tower Detail labels, target mode dropdown, upgrade button, and close button
- dynamic `RightInfoColumn`
  - created in `scripts/ui/game_hud.gd`
  - contains dynamic `WaveIntelPanel`

### Current Node Paths

Wave Intel:

- Created dynamically in `scripts/ui/game_hud.gd`
- Runtime path before this fix:
  - `GameHUD/Root/RightInfoColumn/MarginContainer/VBoxContainer/WaveIntelPanel`

Tower Detail:

- Scene-authored in `scenes/ui/GameHUD.tscn`
- Scene path before this fix:
  - `GameHUD/Root/RightSidebar`
- Important controls:
  - `Root/RightSidebar/MarginContainer/VBoxContainer/TargetModeOptionButton`
  - `Root/RightSidebar/MarginContainer/VBoxContainer/UpgradeTowerButton`
  - `Root/RightSidebar/MarginContainer/VBoxContainer/DeselectTowerButton`

Right-side HUD area:

- Original tower detail panel: `Root/RightSidebar`
- New Wave Intel column: `Root/RightInfoColumn`

### Current Parent Ownership

Wave Intel parent:

- `RightInfoColumn/MarginContainer/VBoxContainer`

Tower Detail parent:

- `$Root`

### Current Positioning Mode

Wave Intel:

- Managed by the dynamic `RightInfoColumn`, anchored to the right side below the top bar.

Tower Detail:

- `Root/RightSidebar` is also anchored to the right side below the top bar.
- It uses its own right-wide offsets.

They are not siblings inside one vertical layout container. They are two separate right-side panels using overlapping right-edge ownership.

### Why They Overlap

The overlap happens because Step 37H added a new right info column for Wave Intel, but the existing Tower Detail panel stayed as the original independent `Root/RightSidebar`.

Both systems reserve the same right-side visual area:

- `RightInfoColumn` contains Wave Intel.
- `RightSidebar` contains Tower Detail.
- Both are anchored to the right side.
- Neither container knows about the other's height or visibility.

Result: when a tower is selected, Tower Detail appears in the same region as Wave Intel instead of stacking below it.

### Planned Fix

- Keep the existing Tower Detail controls and signal wiring.
- Reparent `Root/RightSidebar` into `RightInfoColumn/MarginContainer/VBoxContainer` at runtime.
- Treat `RightSidebar` as the Tower Detail panel inside the right column.
- Stack panels in this order:
  1. `WaveIntelPanel`
  2. `RightSidebar` / Tower Detail
  3. spacer
- Use VBoxContainer size flags instead of competing right-side anchors.
- Keep Wave Intel informational with `mouse_filter = IGNORE`.
- Keep Tower Detail interactive with `mouse_filter = STOP` only when visible.
- Refresh right column visibility whenever Wave Intel or Tower Detail visibility changes.

## Final Update

### Files Changed

- `scripts/ui/game_hud.gd`
- `scripts/main/main.gd`
- `docs/STEP_37I_RIGHT_HUD_PANEL_LAYOUT_CONFLICT_FIX.md`

### Root Cause Of Overlap

Wave Intel and Tower Detail were both right-side gameplay HUD panels, but they had different layout owners.

- Wave Intel lived in the dynamic `RightInfoColumn`.
- Tower Detail lived in the scene-authored `Root/RightSidebar`.

Both were anchored to the right edge below the top bar, so selecting a tower made `RightSidebar` appear over the same area occupied by Wave Intel. There was no shared vertical layout container to stack them.

### New RightInfoColumn Structure

Runtime structure now becomes:

- `GameHUD/Root`
  - `RightInfoColumn`
    - `MarginContainer`
      - `VBoxContainer`
        - `WaveIntelPanel`
        - `TowerDetailPanel`
          - `TowerDetailScroll`
            - original Tower Detail `MarginContainer`
        - `RightInfoSpacer`

The existing `RightSidebar` node is reused as the Tower Detail panel and reparented into the right info column at runtime. Its existing labels, target mode dropdown, upgrade button, and close button are preserved.

### Panel Visibility Rules

No tower selected:

- Wave Intel visible during gameplay when wave preview data exists.
- Tower Detail hidden.
- Right column remains visible only if Wave Intel is visible.

Tower selected:

- Wave Intel remains visible at the top.
- Tower Detail appears below Wave Intel.
- Tower Detail receives mouse input.

Close / deselect:

- Tower Detail hides.
- Wave Intel remains visible.
- Hidden Tower Detail switches to `mouse_filter = IGNORE`.

Restart / map / game over / victory:

- existing selection clearing still calls `hide_tower_info()`.
- Wave Intel visibility is refreshed through `set_wave_intel_visible()` / `clear_wave_intel()`.
- Right column hides when neither panel is visible.

### Panel Sizing And Layout Rules

- `RightInfoColumn` is still anchored to the right side below the top bar.
- `VBoxContainer` owns vertical stacking, so panels cannot overlap.
- `WaveIntelPanel` uses `SHRINK_BEGIN` and stays compact.
- `TowerDetailPanel` uses `EXPAND_FILL` below Wave Intel.
- Tower Detail content is wrapped in `TowerDetailScroll`, so tight vertical layouts scroll inside the detail panel instead of overlapping Wave Intel.
- Wave Intel is informational and keeps `mouse_filter = IGNORE`.
- Tower Detail is interactive only when visible.

### Manual And Headless Test Results

Temporary headless HUD probe confirmed:

- `right_column_exists=true`
- `wave_parent=VBoxContainer`
- `detail_parent=VBoxContainer`
- `detail_initial_visible=false`
- `wave_visible_selected=true`
- `detail_visible_selected=true`
- `detail_below_wave=true`
- `detail_scroll_exists=true`
- after close: Wave Intel remains visible and Tower Detail hides
- after clearing Wave Intel with no tower selected: right column hides

Godot checks run:

- `Godot --headless --check-only --script res://scripts/ui/game_hud.gd`
- `Godot --headless --check-only --script res://scripts/main/main.gd`
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

- Wave Intel no longer overlaps Tower Detail.
- Both panels live in the right-side HUD column at runtime.
- Tower Detail appears below Wave Intel.
- Tower Detail controls remain interactive.
- Tower Detail hides when no tower is selected.
- Hidden Tower Detail does not block input.
- Wave Intel remains compact and visible during gameplay.
- Right column visibility is refreshed when either panel changes.
- Documentation updated.
