# Maze Tower Defense Refactor Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Convert all maps from fixed-path tower defense to dynamic maze tower defense with lightweight visuals, dynamic pathfinding, and 100+ enemies per level.

**Architecture:** Single shared lightweight `maze_map_renderer.gd` replaces heavy per-level tile rendering. Enemies default to A* grid pathfinding (already implemented). Level data simplified to spawn, core, grid, and minimal guideline only.

**Tech Stack:** Godot 4.6.2, GDScript, AStarGrid2D pathfinding, JSON level data.

---

## Phase 1: Lightweight Maze Map Renderer

### Task 1: Create `scripts/map/maze_map_renderer.gd` — dark background + playable grid

**Objective:** Create the core lightweight map renderer that draws only the dark playfield background and subtle grid lines.

**Files:**
- Create: `scripts/map/maze_map_renderer.gd`
- Create: `scripts/map/maze_map_renderer.gd.uid` (auto-generated)

**Steps:**

**Step 1:** Create maze_map_renderer.gd with minimal drawing functions.

The renderer extends Node2D and provides these draw functions:
- `_draw()` — draws dark background, then faint grid lines
- `draw_playable_area()` — fills entire grid bounds with dark color
- `draw_minimal_grid()` — draws subtle grid lines
- `draw_start_marker()` — simple triangle arrow at spawn point
- `draw_core_marker()` — simple circle/diamond at core point
- `draw_minimal_guideline()` — thin dotted line from start to core (optional)
- `setup(level_manager)` — configures from level data

Complete code to write:

```gdscript
extends Node2D
class_name MazeMapRenderer

## Lightweight maze-TD map renderer — draws only essential elements.
## Priorities: readability at a glance, stable 60 FPS, zero per-frame allocs.

var level_manager: Node = null
var grid_size: int = 64
var grid_cols: int = 20
var grid_rows: int = 12
var grid_origin: Vector2 = Vector2.ZERO

var spawn_cells: Array[Vector2i] = []
var base_cells: Array[Vector2i] = []
var guideline_cells: Array[Vector2i] = []

## Colors
const BG_COLOR := Color(0.06, 0.07, 0.10, 1.0)     # Dark arena floor
const GRID_COLOR := Color(0.12, 0.14, 0.18, 0.35)    # Very faint grid lines
const SPAWN_COLOR := Color(0.3, 0.9, 0.4, 0.9)        # Green start marker
const CORE_COLOR := Color(0.9, 0.25, 0.15, 0.9)       # Red core marker
const GUIDELINE_COLOR := Color(0.25, 0.35, 0.5, 0.18) # Very faint route hint

func setup(p_level_manager: Node) -> void:
	level_manager = p_level_manager
	grid_size = int(level_manager.grid_size)
	grid_cols = int(level_manager.grid_cols)
	grid_rows = int(level_manager.grid_rows)
	grid_origin = level_manager.grid_origin
	
	spawn_cells = _extract_cells(level_manager.level_data.get("spawn_cells", []))
	if spawn_cells.is_empty():
		spawn_cells.append(level_manager.spawn_cell)
	
	base_cells = _extract_cells(level_manager.level_data.get("base_cells", []))
	if base_cells.is_empty():
		base_cells.append(level_manager.base_cell)
	
	guideline_cells = _extract_cells(level_manager.level_data.get("guideline_cells", []))
	if guideline_cells.is_empty() and not level_manager.multi_paths.is_empty():
		# Fall back to "default" path cells as minimal guideline
		guideline_cells = level_manager.multi_paths.get("default", [])
	
	set_process(false)  # Static map — no per-frame redraw
	queue_redraw()

func _draw() -> void:
	if level_manager == null:
		return
	_draw_playable_area()
	_draw_minimal_grid()
	_draw_minimal_guideline()
	_draw_spawn_markers()
	_draw_core_markers()

func _draw_playable_area() -> void:
	var area_rect := Rect2(grid_origin, Vector2(grid_cols * grid_size, grid_rows * grid_size))
	draw_rect(area_rect, BG_COLOR)

func _draw_minimal_grid() -> void:
	var cols := grid_cols
	var rows := grid_rows
	var gs := float(grid_size)
	var origin := grid_origin
	
	for x in range(cols + 1):
		draw_line(origin + Vector2(x * gs, 0), origin + Vector2(x * gs, rows * gs), GRID_COLOR, 0.5)
	for y in range(rows + 1):
		draw_line(origin + Vector2(0, y * gs), origin + Vector2(cols * gs, y * gs), GRID_COLOR, 0.5)

func _draw_spawn_markers() -> void:
	for cell in spawn_cells:
		var center := _cell_center(cell)
		var gs := float(grid_size)
		# Simple green triangle pointing right
		var pts := PackedVector2Array([
			center + Vector2(gs * 0.35, 0),
			center + Vector2(-gs * 0.25, -gs * 0.3),
			center + Vector2(-gs * 0.25, gs * 0.3)
		])
		draw_colored_polygon(pts, SPAWN_COLOR)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.0)
		# Small label
		draw_string(ThemeDB.fallback_font, center + Vector2(-12, gs * 0.5), "SPAWN", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, SPAWN_COLOR)

func _draw_core_markers() -> void:
	for cell in base_cells:
		var center := _cell_center(cell)
		var r := float(grid_size) * 0.35
		# Red diamond
		var pts := PackedVector2Array([
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0)
		])
		draw_colored_polygon(pts, CORE_COLOR)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.2)
		# Outer ring
		draw_arc(center, r * 1.35, 0, TAU, 24, CORE_COLOR, 1.0)
		# Label
		draw_string(ThemeDB.fallback_font, center + Vector2(-10, r * 1.6), "CORE", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, CORE_COLOR)

func _draw_minimal_guideline() -> void:
	if guideline_cells.is_empty():
		return
	
	var world_pts := PackedVector2Array()
	for cell in guideline_cells:
		if cell is Vector2i:
			world_pts.append(_cell_center(cell))
	
	if world_pts.size() < 2:
		return
	
	# Draw as a very faint dotted line — thin and low opacity
	var dash_length := 12.0
	var gap_length := 24.0
	var total_dist := 0.0
	for i in range(world_pts.size() - 1):
		var p1 := world_pts[i]
		var p2 := world_pts[i + 1]
		var seg := p2 - p1
		var seg_len := seg.length()
		var dir := seg.normalized()
		var drawn := 0.0
		var in_dash := total_dist <= 0.0 or fmod(total_dist, dash_length + gap_length) < dash_length
		while drawn < seg_len:
			var remaining := seg_len - drawn
			if in_dash:
				var dash_chunk := min(remaining, dash_length - fmod(total_dist, dash_length + gap_length))
				if dash_chunk > 0:
					draw_line(p1 + dir * drawn, p1 + dir * (drawn + dash_chunk), GUIDELINE_COLOR, 0.8)
				drawn += dash_chunk
				total_dist += dash_chunk
				in_dash = false
			else:
				var gap_chunk := min(remaining, gap_length - fmod(total_dist, dash_length + gap_length))
				drawn += gap_chunk
				total_dist += gap_chunk
				in_dash = true
	
	# Small arrow every ~10 cells
	var arrow_interval := 10
	for i in range(arrow_interval, guideline_cells.size(), arrow_interval):
		if i >= guideline_cells.size():
			break
		var center := _cell_center(guideline_cells[i])
		var prev := _cell_center(guideline_cells[i - 1])
		var arrow_dir := (center - prev).normalized()
		if arrow_dir == Vector2.ZERO:
			arrow_dir = Vector2.RIGHT
		var perp := Vector2(-arrow_dir.y, arrow_dir.x)
		var tip := center + arrow_dir * 8.0
		var back := center - arrow_dir * 4.0
		draw_polyline([back + perp * 5, tip, back - perp * 5], Color(GUIDELINE_COLOR.r, GUIDELINE_COLOR.g, GUIDELINE_COLOR.b, GUIDELINE_COLOR.a * 2.5), 1.0, true)

func _cell_center(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x * grid_size + grid_size / 2.0, cell.y * grid_size + grid_size / 2.0)

func _extract_cells(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (raw is Array):
		return out
	for item in raw:
		if item is Vector2i:
			out.append(item)
		elif item is Array and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out
```

**Step 2:** Verify the file compiles by running Godot headless check.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

Expected: No errors related to maze_map_renderer.

---

## Phase 2: Simplify map_visual_layer.gd

### Task 2: Strip heavy tile road code from map_visual_layer.gd

**Objective:** Remove all expensive sci-fi tile rendering. Keep only the performance-mode path.

**Files:**
- Modify: `scripts/map/map_visual_layer.gd`

**Steps:**

**Step 1:** Replace _draw() with a simplified version that delegates to the new MazeMapRenderer approach, or strip all non-performance code paths.

Actually — the simplest approach: make `_draw()` just draw the dark background, grid, and markers. Cut all tile road code. The new `maze_map_renderer.gd` will be the primary renderer, but map_visual_layer stays as a fallback.

Simplified _draw():
```gdscript
func _draw() -> void:
	if level_manager == null or current_theme == null: return
	
	var gs = level_manager.grid_size
	var cols = level_manager.grid_cols
	var rows = level_manager.grid_rows
	var origin = level_manager.grid_origin
	
	# 1. Dark background
	draw_rect(Rect2(origin - Vector2(500, 500), Vector2(10000, 10000)), current_theme.color_bg)
	
	# 2. Minimal grid
	if current_theme.color_grid.a > 0:
		for x in range(cols + 1):
			draw_line(origin + Vector2(x * gs, 0), origin + Vector2(x * gs, rows * gs), current_theme.color_grid)
		for y in range(rows + 1):
			draw_line(origin + Vector2(0, y * gs), origin + Vector2(cols * gs, y * gs), current_theme.color_grid)
	
	# 3. Markers only (spawn/core)
	_draw_markers(gs)
```

**Step 2:** Remove or comment out these functions (will be done with targeted patches):
- `_draw_tile_road_system`
- `_draw_sci_fi_road_cell`
- `_draw_cheap_build_tile`
- `_draw_guide_lane_cell`
- `_draw_cheap_guide_tile`
- `_draw_tile_road_roundabouts`
- `_draw_tile_road_energy_nodes`
- `_draw_all_paths_base` (simplify)
- `_draw_path_overlays` (simplify)
- `_draw_polyline_paths_base`
- `_draw_foundation_tile` (simplify to performance mode only)
- `_draw_normal_build_tile` (simplify to performance mode only)

These functions won't be called anymore since we'll route through the new MazeMapRenderer. We'll keep map_visual_layer as-is but not use its heavy functions. Actually, let's just point main.gd to use maze_map_renderer instead.

---

## Phase 3: Update Level Data

### Task 3: Strip road visual fields from all 20 level JSONs

**Objective:** Remove all `road_visual_*` keys. Add minimal `guideline_cells` from the default path. Set `buildable_mode: "full_non_path"` and `camera_fit_mode: ""` for all maps.

**Files:**
- Modify: `data/levels/level_01.json` through `data/levels/level_20.json`

**Step 1:** For each level JSON, execute these transformations:
1. Add `"guideline_cells"` copied from `"path_cells"` (the legacy path array)
2. Remove keys: `road_visual_style`, `road_visual_width_cells`, `road_visual_blocks_building`, `road_visual_guidance_lane`, `road_visual_manual_chevrons`, `road_visual_roundabout_cells`, `road_visual_node_cells`, `road_visual_extra_cells`, `road_visual_node_connection_cells`
3. Set `"buildable_mode": "full_non_path"`
4. Set `"camera_fit_mode": ""`
5. Keep `paths`, `path_cells`, `spawn_cell`, `base_cell`, `spawn_cells`, `base_cells`, `blocked_cells`, `grid_size`, `grid_cols`, `grid_rows`, `grid_origin`, `starting_gold`, `starting_lives`, `area_id`

Example final level_01.json structure:
```json
{
  "id": "level_01",
  "name": "Level 1 - Maze Arena",
  "area_id": 1,
  "grid_size": 64,
  "grid_cols": 20,
  "grid_rows": 12,
  "grid_origin": {"x": 0, "y": 0},
  "starting_gold": 180,
  "starting_lives": 20,
  "waves_path": "res://data/waves.json",
  "buildable_mode": "full_non_path",
  "camera_fit_mode": "",
  "spawn_cell": [0, 5],
  "base_cell": [19, 3],
  "spawn_cells": [[0, 4], [0, 5], [0, 6]],
  "base_cells": [[19, 2], [19, 3], [19, 4]],
  "paths": {
    "default": [[0,5],[1,5],...[19,3]]
  },
  "guideline_cells": [[0,5],[1,5],...[19,3]],
  "path_cells": [[0,5],[1,5],...[19,3]],
  "blocked_cells": [],
  "hero_enabled": false
}
```

**Step 2:** Process all 20 files with a Python script for efficiency.

---

## Phase 4: Wire Dynamic Pathfinding as Default

### Task 4: Update WaveManager to spawn all ground enemies with dynamic pathfinding

**Objective:** When spawning an enemy, call `set_dynamic_pathing()` so ground enemies use A* pathfinding instead of PathFollow2D.

**Files:**
- Modify: `scripts/managers/wave_manager.gd` (in `_spawn_enemy` or equivalent function)

**Steps:**

**Step 1:** Find the spawn function in wave_manager.gd. After `enemy.setup(config)`, add:
```gdscript
if pathfinding_manager and enemy.has_method("set_dynamic_pathing"):
	var spawn_cell := level_data.spawn_cells[spawn_lane_cursor % level_data.spawn_cells.size()]
	enemy.set_dynamic_pathing(pathfinding_manager, spawn_cell)
```

**Step 2:** Also update the split-child spawn path in enemy.gd (`_handle_split_on_death` already handles this — it calls `spawn_enemy_at_world_position` which should trigger setup).

### Task 5: Update enemy.gd to not extend PathFollow2D (or handle gracefully)

**Objective:** Enemy currently extends `PathFollow2D`. For dynamic pathing, we want a plain Node2D. However, refactoring the base class could break many things. Safer approach: ensure dynamic pathing code path is taken and PathFollow2D fallback never triggers.

**Files:**
- Modify: `scripts/enemies/enemy.gd`

**Steps:**

**Step 1:** In `set_dynamic_pathing`, set `use_dynamic_pathing = true` and ensure `_process_pathing` takes the dynamic branch.

**Step 2:** In `_ready`, add self to group "ground_enemies" when category is land (already done in setup).

**Step 3:** Remove the PathFollow2D `progress` usage in `_process_pathing` — the dynamic pathing branch already bypasses it.

---

## Phase 5: Increase Enemy Counts

### Task 6: Scale enemy counts to 100+ per level in wave data

**Objective:** Modify wave JSON files to have around 100+ total enemies per level with paced spawning.

**Files:**
- Modify: `data/waves/waves_01.json` through `data/waves/waves_20.json`
- Reference: `data/waves.json` (index)

**Rules:**
- Early levels (1-5): 80-100 total enemies
- Mid levels (6-12): 100-130 total enemies
- Late levels (13-20): 120-180 total enemies
- Use spawn intervals of 0.3-0.8 seconds between enemies
- Use groups with `count` and `interval` fields
- Keep max concurrent active enemies around 35-60
- More basic enemies, more swarm groups
- Occasional fast runners and tank/support enemies
- Fewer overpowered specials early

**Step 1:** Generate wave data modifications using a script that preserves wave names/rewards but scales enemy counts.

---

## Phase 6: Main Scene Integration

### Task 7: Update main.gd to use new lightweight renderer

**Objective:** Replace map_visual_layer usage with MazeMapRenderer in main.gd. Remove old path visual setup code.

**Files:**
- Modify: `scripts/main/main.gd`

**Steps:**

**Step 1:** Add reference to MazeMapRenderer script:
```gdscript
const MAZE_MAP_RENDERER_SCRIPT = preload("res://scripts/map/maze_map_renderer.gd")
var maze_map_renderer: Node2D = null
```

**Step 2:** In `_ensure_level_nodes_exist()` or `_setup_game_from_level()`, create and use MazeMapRenderer:
```gdscript
if maze_map_renderer == null:
	maze_map_renderer = MAZE_MAP_RENDERER_SCRIPT.new()
	maze_map_renderer.name = "MazeMapRenderer"
	map_root.add_child(maze_map_renderer)

maze_map_renderer.setup(level_manager)
```

**Step 3:** Hide or remove the old map_visual_layer:
```gdscript
if map_visual_layer:
	map_visual_layer.visible = false  # or queue_free()
```

**Step 4:** Remove old path visual creation code in `_setup_game_from_level()` (the Path2D/curve creation for PathFollow2D). Air enemies still use the old path system, so keep it for now but disable line visual.

---

## Phase 7: Verification

### Task 8: Performance verification

**Objective:** Confirm all changes work and FPS is stable.

**Steps:**

**Step 1:** Run Godot headless to verify no script errors.

**Step 2:** Check that all 20 level JSONs parse correctly.

**Step 3:** Verify maze_map_renderer.gd compiles and renders.

**Step 4:** Verify dynamic pathfinding is wired correctly.

---

## Summary

| Phase | Task | Files Changed |
|-------|------|---------------|
| 1 | Create maze_map_renderer.gd | 1 new |
| 2 | Simplify map_visual_layer.gd | 1 modified |
| 3 | Update 20 level JSONs | 20 modified |
| 4 | Wire dynamic pathfinding | wave_manager.gd, enemy.gd |
| 5 | Increase enemy counts | 20 wave JSONs |
| 6 | Update main.gd integration | main.gd |
| 7 | Performance verification | — |

Total: ~45 files touched, all changes are backward-compatible (old data preserved as guideline/fallback).
