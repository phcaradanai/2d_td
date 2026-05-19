# Tower Effect Catalog — Design Spec
Date: 2026-05-19

## Goal

Extend `scenes/debug/tower_catalog.tscn` into a full Tower Effect Catalog that previews tower models, attack VFX, status markers, and support/buff VFX for all 132 towers in `towers_tree.json`. Debug/QA only — no gameplay changes.

---

## Constraints

- Do NOT change damage, range, fire rate, target logic, wave logic, enemy logic, balance, unlock rules, or save data.
- Do NOT add VFX to actual gameplay from this task.
- Keep catalog preview isolated from real gameplay.
- Keep FPS safe (real VFX nodes spawned for selected card only).
- No log spam.
- Must work standalone (`F5` on `tower_catalog.tscn` directly).
- `PerformanceFirebreak` flags are read-only from the catalog — never set them.

---

## Architecture

### Scene structure

`tower_catalog.tscn` is extended in-place. The existing `Background`, `RootMargin`, and `Header` nodes are untouched. Two new nodes are added inside `MainVBox`:

```
Root: Control (full rect)
├── Background: ColorRect (unchanged)
└── RootMargin: MarginContainer (unchanged)
    └── MainVBox: VBoxContainer (unchanged)
        ├── Header: HBoxContainer (unchanged)
        ├── TopToolbar: HBoxContainer          ← NEW
        └── ContentArea: HBoxContainer         ← NEW
            ├── ScrollContainer (existing, size_flags expand-fill)
            │   └── ContentVBox               ← zoom target (scale applied here)
            └── SelectedTowerPanel: VBoxContainer (320px wide, fixed)  ← NEW
```

The existing full-screen modal detail overlay is removed. The persistent `SelectedTowerPanel` replaces it.

### Scripts

| Script | Type | Job |
|---|---|---|
| `scripts/debug/tower_catalog.gd` | Control | Root coordinator — loads data, builds cards, wires signals |
| `scripts/debug/tower_effect_catalog_controller.gd` | Node | Toolbar state: filters, toggles, auto-play timer, FPS/VFX label updates |
| `scripts/debug/tower_effect_catalog_zoom_controller.gd` | RefCounted | Zoom state — clamps, steps, applies `ContentVBox.scale` |
| `scripts/debug/tower_effect_catalog_card.gd` | Node (attached to card PanelContainer) | Per-card state: play/pause buttons, badge display, selection highlight, signals |
| `scripts/debug/tower_effect_preview_target.gd` | Node2D | Dummy target node placed inside selected card's SubViewport for real VFX spawning |

---

## Data Loading

1. Load all 132 entries from `towers_tree.json` into `_towers_config` at `_ready()`.
2. Group towers by `branch_id` — towers in the same family share a branch (e.g. `light_t1/t2/t3` all have branch `"light"`).
3. Sort within each family by `tier` ascending: T1 → T2 → T3 → Pure (tier 4).
4. Group families into sections by `combo_type`: Neutral → Single → Dual → Triple → Pure/Periodic.
5. The hardcoded `CATALOG_ENTRIES` const is retired. `attack_type` and `target_categories` from JSON replace the old role/target overrides.

---

## Card Layout

Each card `PanelContainer` gains:

- **Tier badge** — small chip top-right corner: T1 (gold) / T2 (silver) / T3 (cyan) / Pure (purple).
- **VFX status badge** — colored label below the model preview:
  - `OK` (green) — `TowerAttackVFXRegistry.get_vfx_script(tower_id) != null`
  - `Missing` (red) — expected path absent and no registry entry
  - `T1 Fallback` (yellow) — T2/T3 entry exists but script `extends` the T1 base class
  - `Legacy` (orange) — tower has no registry entry and `visual_type` matches a known legacy projectile type
- **Three card-level buttons** below badge row: `▶ Attack`, `◉ Status`, `⏸ Pause`
- **Selected highlight** — 2px border in `Color(0.35, 0.95, 1.0)` when this card is the active selection.
- `tower_effect_catalog_card.gd` attached to each card manages local play/pause state and emits `card_selected(tower_id, cfg)` up to the controller.

Families with T1 only show one card. Families with T1/T2/T3 show three cards in a row (columns = 3, matching the existing grid layout).

---

## Top Toolbar

Single `HBoxContainer` with `VSeparator` nodes between logical groups:

```
[Search] [Element▼] [Tier▼] [AttackType▼]
  | [Models✓] [AttackVFX✓] [StatusFX✓] [SupportFX✓]
  | [AutoPlay✓] [Pause✓] [Replay]
  | [−] [+] [Reset] [Fit]
  | FPS: 60   VFX: 3
```

**Filters** (compose with AND):
- **Search** — substring match on `tower_id` or `display_name`, updates on keystroke.
- **Element** — All / Light / Darkness / Water / Fire / Nature / Earth. Matches `elements` array contains selection.
- **Tier** — All / T1 / T2 / T3 / Pure. Maps to `tier` field (1/2/3/4).
- **Attack type** — All / Single / Splash / Slow / Support / Aura. Matches `attack_type`.

**Visibility toggles** (`CheckButton`):
- Show Models — hides/shows the `TowerCatalogPreview` SubViewportContainer on each card.
- Show Attack VFX — when toggled off, frees all `attack_vfx` group nodes and stops new spawns.
- Show Status FX — hides/shows the status icon layer on all cards.
- Show Support FX — hides/shows the support/aura layer on all cards.

**Playback controls**:
- Auto Play — arms 0.8s repeating timer; on each tick spawns one attack VFX cycle on the selected card.
- Pause — disarms the auto-play timer; existing VFX nodes finish naturally.
- Replay Selected — fires one VFX cycle on the currently selected card immediately.

**Zoom controls** — delegate to `TowerEffectCatalogZoomController`:
- `−` / `+` snap to previous/next step in `[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]`.
- Reset → 1.0.
- Fit → calculates scale so the 3-column grid fills the scroll area width.

**Status labels** — updated every 0.5s:
- `FPS: N` via `Engine.get_frames_per_second()`.
- `VFX: N` via `BaseTowerAttackVFX._active_count`.

---

## Selected Tower Side Panel

Fixed 320px-wide `VBoxContainer` on the right edge, always visible. Shows "Click a tower to inspect" placeholder until a card is selected.

On card selection, populates:
- `tower_id` label
- `display_name` label
- `tier` label
- `elements` chips (reusing existing `_make_element_badge()`)
- `attack_type`, `visual_type` labels
- `status_effect` and `support_type` labels (if present in config)
- VFX file path as a read-only `LineEdit` (selectable for copy): `res://scripts/vfx/towers/{tower_id}_attack_vfx.gd`
- VFX status badge (same logic as card badge)
- Three buttons: **Replay Attack**, **Replay Status**, **Replay Support**
- A `TowerCatalogPreview` SubViewport (400×280) with real VFX spawning enabled

---

## VFX Spawning (Selected Card)

Real VFX spawning is used only inside the **side panel's dedicated SubViewport**. Grid cards (including the selected card's grid thumbnail) all keep the existing `PreviewFxLayer` simulation. When a card is selected, the side panel's SubViewport spawns real VFX nodes from `TowerAttackVFXRegistry`.

### Dummy nodes

Two lightweight `Node2D` subclasses live in `tower_effect_preview_target.gd` and are added to the side panel's SubViewport when a card is selected:

**DummyTowerPreview** (class in `tower_effect_preview_target.gd`):
```gdscript
var tower_id: String
var _color: Color
func get_fire_origin() -> Vector2: return global_position
func _get_tower_color() -> Color: return _color
```

**DummyTargetPreview** (inner class of `tower_effect_preview_target.gd`):
```gdscript
func get_hit_origin() -> Vector2: return global_position
# no health, no enemy logic, no collision
```

### Spawn flow

The catalog bypasses `TowerAttackVFXService` (which hardcodes the `WorldRoot/MapRoot/EffectsContainer` path) and calls the registry directly:

```gdscript
if PerformanceFirebreak.disable_all_attack_vfx:
    return  # fall back to simulation
var script := TowerAttackVFXRegistry.get_vfx_script(tower_id)
if script == null:
    return
var node := Node2D.new()
node.set_script(script)
vfx_container.add_child(node)   # vfx_container is inside the SubViewport
node.setup(dummy_tower.global_position, dummy_target.global_position, color)
node.configure({})
```

`BaseTowerAttackVFX` self-destructs after `lifetime` — no manual cleanup needed.

### Status FX preview

`StatusMarkerVFX` requires a live enemy node. Instead of mocking an enemy, the side panel draws status icons directly using `StatusMarkerVFX`'s color constants (`C_SLOW`, `C_BURN`, etc.) — a lightweight draw-only preview, no live node. Avoids coupling to enemy logic.

### Support FX preview

Uses the existing `PreviewFxLayer._draw_aura_or_support_preview()` simulation unchanged. Support-style detection via `attack_type.contains("support")` or `support_type != ""`.

### Toggle off

When "Show Attack VFX" is toggled off:
```gdscript
for node in get_tree().get_nodes_in_group("attack_vfx"):
    node.queue_free()
```

---

## Zoom Controller

`TowerEffectCatalogZoomController` (`RefCounted`) owns zoom state and applies to `ContentVBox.scale`:

```gdscript
class_name TowerEffectCatalogZoomController
extends RefCounted

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEPS := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

var zoom_value: float = 1.0
var content_root: Control = null  # ContentVBox

func setup(p_content_root: Control) -> void
func zoom_in() -> void       # snap to next step
func zoom_out() -> void      # snap to previous step
func reset_zoom() -> void    # set 1.0
func fit_grid() -> void      # calculate scale to fill scroll area width
func set_zoom(value: float) -> void
func get_zoom() -> float
```

**Scroll + zoom interaction**: `ScrollContainer`'s `custom_minimum_size` is updated whenever zoom changes so scrollbars reflect the true scaled content size.

`ContentVBox` uses `size_flags_horizontal = SHRINK_BEGIN` so `scale` doesn't fight the layout engine.

**Mouse input**: `Cmd/Ctrl + scroll wheel` inside the `ScrollContainer` triggers zoom. Plain scroll passes through to `ScrollContainer` for normal scrolling.

---

## VFX File Validation

Run once at `_build_catalog()` time (not per-frame):

```gdscript
func _get_vfx_badge(tower_id: String, tier: int) -> String:
    var script := TowerAttackVFXRegistry.get_vfx_script(tower_id)
    if script == null:
        var path := "res://scripts/vfx/towers/%s_attack_vfx.gd" % tower_id
        if not FileAccess.file_exists(path):
            return "Missing"
        return "Legacy"
    # T2/T3 fallback check: script source contains "extends <base_t1_name>"
    # source_code is available on GDScript resources in editor/debug mode (not exported builds)
    # This catalog is debug-only so this is safe
    if tier >= 2:
        var src := script.source_code
        var base_name := tower_id.replace("_t%d" % tier, "_t1") + "_attack_vfx"
        if src.contains("extends " + base_name):
            return "T1 Fallback"
    return "OK"
```

---

## Files Touched

### Modified
- `scenes/debug/tower_catalog.tscn` — add `TopToolbar`, `ContentArea` wrapper, `SelectedTowerPanel`
- `scripts/debug/tower_catalog.gd` — replace `CATALOG_ENTRIES` with dynamic JSON load; add toolbar/panel wiring; remove modal overlay

### New
- `scripts/debug/tower_effect_catalog_controller.gd`
- `scripts/debug/tower_effect_catalog_zoom_controller.gd`
- `scripts/debug/tower_effect_catalog_card.gd`
- `scripts/debug/tower_effect_preview_target.gd`

### Unchanged (read-only from catalog)
- `scripts/vfx/core/tower_attack_vfx_registry.gd`
- `scripts/vfx/core/tower_attack_vfx_service.gd`
- `scripts/vfx/core/base_tower_attack_vfx.gd`
- `scripts/vfx/status/status_marker_vfx.gd`
- `scripts/services/performance_firebreak.gd`
- All gameplay scripts

---

## Out of Scope

- T2/T3 tower unlock logic or progression rules
- Saving catalog state between sessions
- Exporting catalog reports
- Testing framework / automated verification
