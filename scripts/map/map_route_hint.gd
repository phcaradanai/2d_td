extends Node2D
class_name MapRouteHint

## Fixed-path route visualizer — draws colored lane lines, portal markers,
## and crossover bridge indicators. No pathfinding. No per-frame processing.
## Chevrons are handled by MazeMapRenderer (baked). This node handles only
## the elements that need to change opacity (BUILD bright / WAVE dim).

# ------------------------------------------------------------------ visuals
const LINE_WIDTH      := 2.0
const PORTAL_RADIUS   := 8.0
const BRIDGE_SIZE     := 6.0
const Z_INDEX_LAYER   := 2    # above EnemyRouteOverlay(1), below towers(4+)

const OPACITY_BUILD   := 0.55
const OPACITY_WAVE    := 0.18

# Per-lane tint palette (alpha set at draw time via modulate)
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
# crossover_positions: cells world-centers that appear in ≥2 ground lanes
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

	if lm == null or not is_instance_valid(lm):
		return

	var grid_size: int = int(lm.grid_size)
	var grid_origin: Vector2 = lm.grid_origin
	var multi_paths: Dictionary = lm.multi_paths
	var level_data: Dictionary = lm.level_data

	# ---- collect all non-air ground lanes -----------------------------------
	var lane_idx := 0
	# cell_to_lane: maps Vector2i key -> Array of lane indices that use it (for crossover)
	var cell_to_lane: Dictionary = {}

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

		# Split into segments at portal jumps (Manhattan dist > 1 between consecutive cells)
		var seg_start := 0
		for i in range(1, cells.size()):
			var a: Variant = cells[i - 1]
			var b: Variant = cells[i]
			if a is Vector2i and b is Vector2i:
				var manhattan: int = abs((b as Vector2i).x - (a as Vector2i).x) + abs((b as Vector2i).y - (a as Vector2i).y)
				if manhattan > 1:
					# portal jump — close current segment, start new one
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
			# Extract cell back from key
			var parts := (key as String).split(",")
			if parts.size() == 2:
				var cx := int(parts[0])
				var cy := int(parts[1])
				var world_center := grid_origin + Vector2(cx * grid_size + grid_size * 0.5,
														  cy * grid_size + grid_size * 0.5)
				_crossover_positions.append(world_center)

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

## Call when wave starts/ends.
func set_wave_active(active: bool) -> void:
	var target_a := OPACITY_WAVE if active else OPACITY_BUILD
	if _opacity_tween:
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.tween_property(self, "modulate:a", target_a, 0.35)


## Toggle whether routes are drawn at all (for "Show Route" HUD button).
func set_show_routes(visible_flag: bool) -> void:
	_show_routes = visible_flag
	queue_redraw()


# =================================================================== draw

func _draw() -> void:
	if not _show_routes:
		return

	# ---- lane lines --------------------------------------------------------
	for seg in _segments:
		var pts: PackedVector2Array = seg["points"]
		var li: int = seg["lane_idx"]
		var color: Color = LANE_PALETTE[li % LANE_PALETTE.size()]
		draw_polyline(pts, color, LINE_WIDTH, false)

	# ---- crossover bridge indicators (yellow diamond at intersection) ------
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
