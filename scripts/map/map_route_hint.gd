extends Node2D
class_name MapRouteHint

## Fixed-path route visualizer — lane lines, turn chevrons, portal markers,
## and crossover bridge indicators.
##
## Z-layering: z_index = 0, placed at tree-position 1 (right after the baked
## MazeMapRenderer sprite). All gameplay nodes (TowerContainer, EnemyContainer,
## ProjectileContainer, EffectsContainer) are later in the tree and therefore
## always render on top at the same z-level.

# ------------------------------------------------------------------ visuals
const LINE_WIDTH      := 2.0
const CHEVRON_SIZE    := 6.0   # smaller than map-baked chevrons
const CHEVRON_EVERY   := 8     # interval between non-turn chevrons (cells)
const PORTAL_RADIUS   := 8.0
const BRIDGE_SIZE     := 6.0
const Z_INDEX_LAYER   := 0     # same z as map; tree-position keeps us below enemies

const OPACITY_BUILD   := 0.65  # pre-wave: clearly visible
const OPACITY_WAVE    := 0.15  # during combat: subtle background guide

# Per-lane tint palette
static var LANE_PALETTE: Array[Color] = [
	Color(0.20, 0.90, 1.00, 1.0),   # 0 cyan
	Color(1.00, 0.65, 0.15, 1.0),   # 1 amber
	Color(0.25, 1.00, 0.35, 1.0),   # 2 lime
	Color(0.95, 0.25, 0.75, 1.0),   # 3 pink
]
const PORTAL_ENTRY_COLOR := Color(0.75, 0.30, 1.00, 1.0)  # violet — teleport-from
const PORTAL_EXIT_COLOR  := Color(0.20, 1.00, 1.00, 1.0)  # cyan   — teleport-to
const CROSSOVER_COLOR    := Color(1.00, 1.00, 0.30, 1.0)  # yellow — bridge indicator

# ------------------------------------------------------------------ state
# A segment is one contiguous run within a single lane (split at portal jumps).
# Structure: {points: PackedVector2Array, lane_idx: int}
var _segments: Array[Dictionary] = []
var _portal_entry_positions: Array[Vector2] = []
var _portal_exit_positions:  Array[Vector2] = []
# world-centers of cells that appear in ≥2 ground lanes
var _crossover_positions: Array[Vector2] = []

var _show_routes: bool = true
var _opacity_tween: Tween = null


# ================================================================== setup

func _ready() -> void:
	set_process(false)
	z_index = Z_INDEX_LAYER
	z_as_relative = false
	modulate.a = OPACITY_BUILD


## Call once each time a level is loaded. Pass the LevelManager node.
func setup(lm: Node) -> void:
	_segments.clear()
	_portal_entry_positions.clear()
	_portal_exit_positions.clear()
	_crossover_positions.clear()

	# Reset opacity on every level load — the node persists, _ready() does not re-run.
	if _opacity_tween:
		_opacity_tween.kill()
		_opacity_tween = null
	modulate.a = OPACITY_BUILD

	if lm == null or not is_instance_valid(lm):
		return

	var grid_size: int = int(lm.grid_size)
	var grid_origin: Vector2 = lm.grid_origin
	var multi_paths: Dictionary = lm.multi_paths
	var level_data: Dictionary = lm.level_data

	# ---- collect all non-air ground lanes -----------------------------------
	var lane_idx := 0
	var cell_to_lane: Dictionary = {}   # Vector2i key -> Array of lane indices

	for path_id in multi_paths.keys():
		if (path_id as String).begins_with("air"):
			continue

		var cells: Array = multi_paths[path_id]
		var world_pts := _cells_to_world(cells, grid_size, grid_origin)
		if world_pts.size() < 2:
			lane_idx += 1
			continue

		# Track crossover candidates
		for cell in cells:
			if cell is Vector2i:
				var key := _key(cell)
				if not cell_to_lane.has(key):
					cell_to_lane[key] = []
				(cell_to_lane[key] as Array).append(lane_idx)

		# Split into segments at portal jumps (Manhattan dist > 1)
		var seg_start := 0
		for i in range(1, cells.size()):
			var a: Variant = cells[i - 1]
			var b: Variant = cells[i]
			if a is Vector2i and b is Vector2i:
				var manhattan: int = abs((b as Vector2i).x - (a as Vector2i).x) + abs((b as Vector2i).y - (a as Vector2i).y)
				if manhattan > 1:
					var seg_pts := PackedVector2Array(world_pts.slice(seg_start, i))
					if seg_pts.size() >= 2:
						_segments.append({"points": seg_pts, "lane_idx": lane_idx})
					seg_start = i

		# Final segment
		var final_pts := PackedVector2Array(world_pts.slice(seg_start, world_pts.size()))
		if final_pts.size() >= 2:
			_segments.append({"points": final_pts, "lane_idx": lane_idx})

		lane_idx += 1

	# ---- crossover positions -------------------------------------------------
	for key in cell_to_lane.keys():
		if (cell_to_lane[key] as Array).size() >= 2:
			var parts := (key as String).split(",")
			if parts.size() == 2:
				var cx := int(parts[0])
				var cy := int(parts[1])
				_crossover_positions.append(
					grid_origin + Vector2(cx * grid_size + grid_size * 0.5,
										  cy * grid_size + grid_size * 0.5)
				)

	# ---- portal entry / exit positions from path_portals JSON ---------------
	var portals = level_data.get("path_portals", [])
	if portals is Array:
		for portal in portals:
			if not (portal is Dictionary):
				continue
			var pid: String = portal.get("path", "default")
			var e_idx: int = int(portal.get("entry_index", -1))
			var x_idx: int = int(portal.get("exit_index", -1))
			var lane_cells: Array = multi_paths.get(pid, [])
			if e_idx >= 0 and e_idx < lane_cells.size() and lane_cells[e_idx] is Vector2i:
				var ec: Vector2i = lane_cells[e_idx]
				_portal_entry_positions.append(
					grid_origin + Vector2(ec.x * grid_size + grid_size * 0.5,
										 ec.y * grid_size + grid_size * 0.5)
				)
			if x_idx >= 0 and x_idx < lane_cells.size() and lane_cells[x_idx] is Vector2i:
				var xc: Vector2i = lane_cells[x_idx]
				_portal_exit_positions.append(
					grid_origin + Vector2(xc.x * grid_size + grid_size * 0.5,
										 xc.y * grid_size + grid_size * 0.5)
				)

	queue_redraw()


# ================================================================ opacity

## Call when wave starts (active=true) or ends (active=false).
func set_wave_active(active: bool) -> void:
	var target_a := OPACITY_WAVE if active else OPACITY_BUILD
	if _opacity_tween:
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.tween_property(self, "modulate:a", target_a, 0.35)


## Toggle route visibility (for "Show Route" HUD button).
func set_show_routes(visible_flag: bool) -> void:
	_show_routes = visible_flag
	queue_redraw()


# =================================================================== draw

func _draw() -> void:
	if not _show_routes:
		return

	# ---- lane lines + turn chevrons ----------------------------------------
	for seg in _segments:
		var pts: PackedVector2Array = seg["points"]
		var li: int = seg["lane_idx"]
		var color: Color = LANE_PALETTE[li % LANE_PALETTE.size()]
		draw_polyline(pts, color, LINE_WIDTH, false)
		_draw_chevrons_for_segment(pts, color)

	# ---- crossover bridge indicators ---------------------------------------
	for pos in _crossover_positions:
		_draw_diamond(pos, BRIDGE_SIZE, CROSSOVER_COLOR)

	# ---- portal entry markers (violet ring — teleport FROM) ----------------
	for pos in _portal_entry_positions:
		draw_circle(pos, PORTAL_RADIUS, Color(PORTAL_ENTRY_COLOR, 0.25))
		draw_arc(pos, PORTAL_RADIUS, 0.0, TAU, 24, PORTAL_ENTRY_COLOR, 1.5)

	# ---- portal exit markers (cyan ring — teleport TO) ---------------------
	for pos in _portal_exit_positions:
		draw_circle(pos, PORTAL_RADIUS, Color(PORTAL_EXIT_COLOR, 0.25))
		draw_arc(pos, PORTAL_RADIUS, 0.0, TAU, 24, PORTAL_EXIT_COLOR, 1.5)


## Draw chevrons at every turn and at regular intervals along a segment.
## Prioritises turns so that confusing bends always get a direction indicator.
func _draw_chevrons_for_segment(pts: PackedVector2Array, color: Color) -> void:
	var n := pts.size()
	if n < 2:
		return

	var last_chevron_at := -CHEVRON_EVERY  # force one early in segment

	for i in range(1, n - 1):
		var from_dir := (pts[i] - pts[i - 1]).normalized()
		var to_dir   := (pts[i + 1] - pts[i]).normalized()
		var is_turn  := from_dir.dot(to_dir) < 0.92    # ~23° threshold
		var is_interval := (i - last_chevron_at) >= CHEVRON_EVERY

		if is_turn or is_interval:
			_draw_chevron(pts[i], to_dir, color)
			last_chevron_at = i

	# One near the end of the segment so the final direction is always clear
	if n >= 3:
		var final_dir := (pts[n - 1] - pts[n - 2]).normalized()
		_draw_chevron(pts[n - 2].lerp(pts[n - 1], 0.4), final_dir, color)


func _draw_chevron(at: Vector2, dir: Vector2, color: Color) -> void:
	if dir.length_squared() < 0.001:
		return
	var perp := Vector2(-dir.y, dir.x)
	var tip   := at + dir * CHEVRON_SIZE * 0.45
	var left  := tip - dir * CHEVRON_SIZE * 0.55 + perp * CHEVRON_SIZE * 0.50
	var right := tip - dir * CHEVRON_SIZE * 0.55 - perp * CHEVRON_SIZE * 0.50
	draw_line(tip, left,  color, 1.2)
	draw_line(tip, right, color, 1.2)


func _draw_diamond(center: Vector2, half: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -half),
		center + Vector2(half, 0.0),
		center + Vector2(0.0,  half),
		center + Vector2(-half, 0.0),
	])
	draw_colored_polygon(pts, color)


# ================================================================ helpers

func _cells_to_world(cells: Array, grid_size: int, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(cells.size())
	for i in range(cells.size()):
		var c = cells[i]
		if c is Vector2i:
			out[i] = origin + Vector2(c.x * grid_size + grid_size * 0.5,
									  c.y * grid_size + grid_size * 0.5)
	return out


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
