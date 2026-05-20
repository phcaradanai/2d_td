# Tower Draw Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop CanvasItem draw RID overflow and element-limit spam in tower visuals and tower catalog previews while preserving tower identity and gameplay behavior.

**Architecture:** Keep the safety logic centralized in `scripts/towers/visuals/common/tower_visual_draw_utils.gd`, then thread a detail-quality parameter through `scripts/towers/tower_visual_renderer.gd` into the by-id visual scripts that still do procedural drawing. Move the tower rank badge to a cached texture helper so `tower.gd` no longer redraws it procedurally every frame, and keep the catalog/debug scenes on a static low-detail default with only the selected card allowed to escalate to full detail.

**Tech Stack:** Godot 4.6.2 GDScript, CanvasItem drawing, existing catalog preview helpers, small audit script in `tools/refactor/`.

---

### Task 1: Add the draw firewall and a regression audit

**Files:**
- Modify: `scripts/towers/visuals/common/tower_visual_draw_utils.gd`
- Create: `tools/refactor/audit_tower_draw_safety.py`

- [ ] **Step 1: Add the failing audit**

Create an audit that fails until the draw firewall exists and the shared constants are present.

```python
#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
text = (root / "scripts/towers/visuals/common/tower_visual_draw_utils.gd").read_text(encoding="utf-8")
assert "MAX_POLYLINE_POINTS_PER_SHAPE" in text
assert "safe_draw_polyline" in text
assert "safe_draw_polygon" in text
assert "safe_draw_circle" in text
assert "safe_draw_rect" in text
assert "safe_draw_arc" in text
```

- [ ] **Step 2: Run the audit and confirm it fails before implementation**

Run: `python3 tools/refactor/audit_tower_draw_safety.py`

Expected: fail until the wrappers and draw-budget constants exist.

- [ ] **Step 3: Add the shared guard and wrappers**

Extend the utility with budget constants, a shared `DetailQuality` enum, NaN/INF rejection, bounds checks, and draw-call accounting.

```gdscript
const MAX_POLYLINE_POINTS_PER_SHAPE := 24
const MAX_CIRCLE_SEGMENTS := 16
const MAX_DETAIL_SEGMENTS := 12
const MAX_DRAW_CALLS_PER_TOWER_VISUAL := 80
const MAX_DRAW_CALLS_PER_CATALOG_CARD := 35

enum DetailQuality { LOW, MEDIUM, HIGH }

static func safe_draw_polyline(t: CanvasItem, points: PackedVector2Array, color: Color, width: float, closed: bool = false) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if points.size() < 2:
		return false
	if points.size() > MAX_POLYLINE_POINTS_PER_SHAPE:
		return false
	return true
```

Repeat the same pattern for `safe_draw_line()`, `safe_draw_polyline()`, `safe_draw_polygon()`, `safe_draw_circle()`, `safe_draw_rect()`, and `safe_draw_arc()`, and make the wrappers consume a per-visual budget before drawing.

- [ ] **Step 4: Re-run the audit and confirm it passes**

Run: `python3 tools/refactor/audit_tower_draw_safety.py`

Expected: pass once the wrappers and constants are in place.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/visuals/common/tower_visual_draw_utils.gd tools/refactor/audit_tower_draw_safety.py
git commit -m "feat: add tower draw safety firewall"
```

### Task 2: Thread detail quality through the renderer and by-id visuals

**Files:**
- Modify: `scripts/towers/tower_visual_renderer.gd`
- Modify: `scripts/towers/visuals/by_id/nature_t1_visual.gd`
- Modify: `scripts/towers/visuals/by_id/ice_t1_visual.gd`
- Modify: `scripts/towers/visuals/by_id/fire_t1_visual.gd`
- Modify: `scripts/towers/visuals/by_id/light_t1_visual.gd`
- Modify: `scripts/towers/visuals/by_id/blacksmith_t1_visual.gd`
- Modify: `scripts/towers/visuals/by_id/*.gd` files that still call raw `draw_*` after the audit

- [ ] **Step 1: Make the audit fail on raw draw calls in the targeted visuals**

Extend the audit so it checks for the quality parameter and for the safe wrappers in the named hot-path files.

```python
for rel_path in [
    "scripts/towers/tower_visual_renderer.gd",
    "scripts/towers/visuals/by_id/nature_t1_visual.gd",
    "scripts/towers/visuals/by_id/ice_t1_visual.gd",
    "scripts/towers/visuals/by_id/fire_t1_visual.gd",
    "scripts/towers/visuals/by_id/light_t1_visual.gd",
    "scripts/towers/visuals/by_id/blacksmith_t1_visual.gd",
]:
    text = (root / rel_path).read_text(encoding="utf-8")
    assert "DetailQuality" in text or "detail_quality" in text
```

- [ ] **Step 2: Add the renderer-side detail resolver**

Pass a resolved detail level from the facade instead of letting every visual animate at full cost by default.

```gdscript
static func draw_turret_contour(t: Node2D) -> void:
	var detail_quality := _resolve_detail_quality(t)
	var visual_script := TowerVisualRegistryScript.get_visual_script(t.tower_id, t.visual_type)
	if visual_script:
		visual_script.draw_contour(t, detail_quality)
```

Apply the same detail-quality resolution to `draw_turret_top()` and forward the existing color, level, and element arguments unchanged.

Resolve detail quality as:

- `LOW` whenever `CatalogPreviewMode.is_emergency_low_detail()` is true
- `LOW` for static catalog preview nodes
- `HIGH` for the selected / hovered catalog card or the selected tower
- `MEDIUM` for normal gameplay

- [ ] **Step 3: Update the named by-id visuals to branch on detail quality**

Each file should accept `detail_quality` and cut decoration before the draw budget is stressed.

```gdscript
static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color], detail_quality: int = TowerVisualDrawUtils.DetailQuality.MEDIUM) -> void:
	if detail_quality == TowerVisualDrawUtils.DetailQuality.LOW:
		TowerVisualDrawUtils.safe_draw_circle(t, Vector2.ZERO, 18.0, Color(main_color.r, main_color.g, main_color.b, 0.05))
		return
```

Apply that pattern to the five named visuals first, then repeat it for any other by-id visual the audit flags as still doing heavy procedural drawing.

- [ ] **Step 4: Re-run the audit**

Run: `python3 tools/refactor/audit_tower_draw_safety.py`

Expected: pass once the facade threads detail quality and the named visuals accept it.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/tower_visual_renderer.gd scripts/towers/visuals/by_id/nature_t1_visual.gd scripts/towers/visuals/by_id/ice_t1_visual.gd scripts/towers/visuals/by_id/fire_t1_visual.gd scripts/towers/visuals/by_id/light_t1_visual.gd scripts/towers/visuals/by_id/blacksmith_t1_visual.gd tools/refactor/audit_tower_draw_safety.py
git commit -m "feat: gate tower visuals by detail quality"
```

### Task 3: Replace procedural rank badges with a cached texture helper

**Files:**
- Create: `scripts/towers/visuals/common/tower_rank_badge_cache.gd`
- Modify: `scripts/towers/tower.gd`

- [ ] **Step 1: Add the failing audit coverage**

Update the safety audit so it checks that rank badge drawing no longer uses `draw_polyline` or `draw_colored_polygon` directly inside `_draw_tower_rank_badge()`.

```python
text = (root / "scripts/towers/tower.gd").read_text(encoding="utf-8")
assert "_draw_tower_rank_badge" in text
assert "TowerRankBadgeCache" in text
assert "draw_texture" in text or "draw_texture_rect" in text
```

- [ ] **Step 2: Add the cached badge helper**

Generate a small `ImageTexture` once per `(tier, accent, scale)` tuple and reuse it.

```gdscript
static func get_badge(tier: int, accent: Color, scale_factor: float) -> Texture2D:
	var key := "%d|%.3f|%.3f|%.3f|%.2f" % [tier, accent.r, accent.g, accent.b, scale_factor]
	if _cache.has(key):
		return _cache[key]
	# Render the badge once into an Image or SubViewport-backed texture, then memoize it by key.
	return _cache[key]
```

- [ ] **Step 3: Switch `tower.gd` to dirty-flag redraws**

Use the existing visual dirty path plus explicit rank/selection/preview-zoom flags instead of calling `queue_redraw()` from `_process()` for the badge.

```gdscript
var _rank_dirty: bool = true
var _selection_dirty: bool = true
var _preview_zoom_dirty: bool = true

func _mark_rank_dirty() -> void:
	_rank_dirty = true
	_mark_tower_visual_dirty()
```

In `_draw_tower_rank_badge()`, draw the cached texture instead of rebuilding the badge geometry every frame.

- [ ] **Step 4: Re-run the audit**

Run: `python3 tools/refactor/audit_tower_draw_safety.py`

Expected: pass once the badge cache is wired and the procedural badge path is removed.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/visuals/common/tower_rank_badge_cache.gd scripts/towers/tower.gd tools/refactor/audit_tower_draw_safety.py
git commit -m "feat: cache tower rank badges"
```

### Task 4: Keep catalog/debug previews static by default and add the emergency low-detail fallback

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scripts/debug/tower_catalog_virtual_list.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`
- Modify: `scripts/debug/catalog_preview_mode.gd`
- Modify: `scripts/debug/catalog_vfx_mode.gd`
- Modify: `scripts/debug/catalog_performance_monitor.gd`

- [ ] **Step 1: Make the audit fail until catalog preview defaults are static and selected-only**

Extend the safety audit to check that catalog cards default to low detail, selected/hovered cards can escalate, and off-screen rows are deactivated.

```python
catalog = (root / "scripts/debug/tower_catalog.gd").read_text(encoding="utf-8")
preview = (root / "scripts/towers/tower_catalog_preview.gd").read_text(encoding="utf-8")
assert "VFX_SELECTED_ONLY" in catalog or "selected_only" in catalog
assert "set_static_preview" in preview
assert "set_active(active)" in preview
```

- [ ] **Step 2: Make off-screen rows fully idle**

Rebind only visible rows, and when a row leaves the viewport, disable its process tree and stop preview redraws.

```gdscript
func _deactivate_row(row: Control) -> void:
	if row_deactivator.is_valid():
		row_deactivator.call(row)
	for child in row.get_children():
		child.queue_free()
```

Extend the row deactivation path so off-screen cards do not keep animating or requesting redraws.

- [ ] **Step 3: Default catalog previews to static LOW detail**

Keep the preview viewport static unless the card is selected or hovered, and only then allow HIGH detail and VFX.

```gdscript
func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if _tower:
		CatalogPreviewMode.set_static_preview(_tower, static_preview or not active)
		CatalogPreviewMode.set_selected_demo(_tower, active and not static_preview)
```

Add the emergency fail-safe so `CatalogPerformanceMonitor` or `PerformanceBudgetService` forces LOW detail when FPS drops below 45 or the draw guard trips.

```gdscript
if Engine.get_frames_per_second() < 45:
	CatalogPreviewMode.set_emergency_low_detail(true)
```

`CatalogPreviewMode` should expose:

```gdscript
static var _emergency_low_detail: bool = false

static func set_emergency_low_detail(enabled: bool) -> void:
	_emergency_low_detail = enabled

static func is_emergency_low_detail() -> bool:
	return _emergency_low_detail
```

`CatalogPerformanceMonitor` should toggle that flag on and off from the live budget check:

```gdscript
func _update_emergency_mode() -> void:
	var low := Engine.get_frames_per_second() < 45 or _draw_guard_tripped
	CatalogPreviewMode.set_emergency_low_detail(low)
```

- [ ] **Step 4: Re-run the audit and smoke tests**

Run: `python3 tools/refactor/audit_tower_draw_safety.py`

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/oyl/my_folders/projects/clone tower defend" --quit`

Expected: pass with no parser/runtime errors.

Then open `res://scenes/debug/tower_catalog.tscn` in the editor, idle for 2 minutes, and confirm the debugger stays clean and the catalog remains responsive.

- [ ] **Step 5: Commit**

```bash
git add scripts/debug/tower_catalog.gd scripts/debug/tower_catalog_virtual_list.gd scripts/towers/tower_catalog_preview.gd scripts/debug/catalog_preview_mode.gd scripts/debug/catalog_vfx_mode.gd scripts/debug/catalog_performance_monitor.gd tools/refactor/audit_tower_draw_safety.py
git commit -m "feat: harden tower catalog draw safety"
```

### Task 5: Final verification and cleanup

**Files:**
- Verify all touched files

- [ ] **Step 1: Run the draw-safety audit**

Run: `python3 tools/refactor/audit_tower_draw_safety.py`

Expected: PASS.

- [ ] **Step 2: Run Godot headless project load**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/oyl/my_folders/projects/clone tower defend" --quit`

Expected: PASS with no `Element limit reached`, `Parameter "mem" is null`, or `!vertex_buffer_owner.owns(buf)` spam.

- [ ] **Step 3: Inspect the diff**

Run: `git diff --check`

Expected: no whitespace or patch-format errors.

- [ ] **Step 4: Confirm catalog stability**

Open `res://scenes/debug/tower_catalog.tscn` and keep it idle for 2 minutes.

Expected:

- no debugger error growth
- stable FPS in the catalog
- clear tower identity in gameplay scenes
- lower draw call count in the catalog compared to the current baseline
