extends Node2D
class_name MapRouteHint

## Fixed-path route hint — lane lines with crossover bridge/gap visuals,
## turn chevrons, portal markers, and a pre-wave flow pulse animation.
##
## Z-layering: z_index = 0, inserted at tree-position 1 (right after the baked
## MazeMapRenderer sprite at 0). EnemyContainer and all gameplay nodes sit at
## later tree positions and render on top at the same z=0.

# ============================================================= constants

const LINE_WIDTH       := 2.0
const CHEVRON_SIZE     := 6.0
const CHEVRON_EVERY    := 8       # cells between non-turn chevrons
const PORTAL_RADIUS    := 8.0
const Z_INDEX_LAYER    := 0

const OPACITY_BUILD    := 0.65    # pre-wave: clearly visible
const OPACITY_WAVE     := 0.15    # during combat: subtle background guide

# Crossover bridge / tunnel
const GAP_HALF         := 15.0   # pixels skipped on each side of an under-crossover center
const BRIDGE_BAR_HALF  := 13.0   # half-length of over-lane bridge deck bar
const BRIDGE_BAR_WIDTH := 4.5
const TUNNEL_HALF      := 11.0   # half-length of under-lane tunnel shadow bar (perpendicular to bridge)

# Flow animation (pre-wave only)
const FLOW_SPEED       := 0.16   # path-fraction per second — full lap ≈ 6 s
const FLOW_DOT_RADIUS  := 3.0
const FLOW_DOT_COUNT   := 2
const FLOW_DOT_SPACING := 0.07   # spacing between dots in path-fraction units

static var LANE_PALETTE: Array[Color] = [
	Color(0.20, 0.90, 1.00, 1.0),   # 0 cyan
	Color(1.00, 0.65, 0.15, 1.0),   # 1 amber
	Color(0.25, 1.00, 0.35, 1.0),   # 2 lime
	Color(0.95, 0.25, 0.75, 1.0),   # 3 pink
]

const PORTAL_ENTRY_COLOR  := Color(0.75, 0.30, 1.00, 1.0)
const PORTAL_EXIT_COLOR   := Color(0.20, 1.00, 1.00, 1.0)
const BRIDGE_BRIGHT_COLOR := Color(1.00, 1.00, 0.50, 0.95)
const TUNNEL_SHADOW_COLOR := Color(0.00, 0.00, 0.00, 0.72)
const FLOW_DOT_COLOR      := Color(1.00, 1.00, 1.00, 0.90)

# ============================================================= state

# {points: PackedVector2Array, lane_idx: int}
var _segments: Array[Dictionary] = []
var _portal_entry_positions: Array[Vector2] = []
var _portal_exit_positions:  Array[Vector2] = []

# Crossover bridge data — one entry per unique crossover cell
# Each: {pos: Vector2, over_dir: Vector2, color: Color}
var _crossover_bridge_data: Array[Dictionary] = []
# Fast set for _draw: pos_key -> true
var _crossover_world_set: Dictionary = {}

# Flow animation along the primary lane
var _flow_path: PackedVector2Array = []
var _flow_t: float = 0.0
var _flow_active: bool = false

var _show_routes: bool = true
var _opacity_tween: Tween = null


# ============================================================= lifecycle

func _ready() -> void:
	set_process(false)
	z_index = Z_INDEX_LAYER
	z_as_relative = false
	modulate.a = OPACITY_BUILD


func _process(delta: float) -> void:
	_flow_t = fmod(_flow_t + delta * FLOW_SPEED, 1.0)
	queue_redraw()


# ============================================================= setup

func setup(lm: Node) -> void:
	_segments.clear()
	_portal_entry_positions.clear()
	_portal_exit_positions.clear()
	_crossover_bridge_data.clear()
	_crossover_world_set.clear()
	_flow_path = PackedVector2Array()
	_flow_t = 0.0

	if _opacity_tween:
		_opacity_tween.kill()
		_opacity_tween = null
	modulate.a = OPACITY_BUILD

	if lm == null or not is_instance_valid(lm):
		set_process(false)
		return

	var gs: int        = int(lm.grid_size)
	var origin: Vector2 = lm.grid_origin
	var multi_paths: Dictionary = lm.multi_paths
	var level_data: Dictionary  = lm.level_data

	# ── pass 1: visit every cell to detect crossovers and record first-visit dir ──
	# cell_visits[cell_key] = Array of {lane_idx, pos, dir}
	var cell_visits: Dictionary = {}
	var lane_idx := 0

	for path_id in multi_paths.keys():
		if (path_id as String).begins_with("air"):
			continue

		var cells: Array = multi_paths[path_id]
		for j in range(cells.size()):
			var cell: Variant = cells[j]
			if not (cell is Vector2i):
				continue
			var cv: Vector2i = cell as Vector2i
			var wp: Vector2  = _cell_center(cv, gs, origin)

			var travel_dir := Vector2.RIGHT
			if j + 1 < cells.size() and cells[j + 1] is Vector2i:
				var nv: Vector2i = cells[j + 1] as Vector2i
				travel_dir = (Vector2(float(nv.x), float(nv.y)) - Vector2(float(cv.x), float(cv.y))).normalized()
			elif j > 0 and cells[j - 1] is Vector2i:
				var pv: Vector2i = cells[j - 1] as Vector2i
				travel_dir = (Vector2(float(cv.x), float(cv.y)) - Vector2(float(pv.x), float(pv.y))).normalized()

			var ck: String = _key(cv)
			if not cell_visits.has(ck):
				cell_visits[ck] = []
			(cell_visits[ck] as Array).append({
				"lane_idx": lane_idx, "pos": wp, "dir": travel_dir
			})

		lane_idx += 1

	# ── pass 2: identify crossovers (cell visited by ≥2 lane-visits) ──────────
	for ck in cell_visits.keys():
		var visits: Array = cell_visits[ck] as Array
		if visits.size() < 2:
			continue
		var first: Dictionary = visits[0]
		var wp: Vector2 = first["pos"]
		var wk: String  = _pos_key(wp)
		_crossover_world_set[wk] = true
		_crossover_bridge_data.append({
			"pos":      wp,
			"over_dir": first["dir"],
			"color":    LANE_PALETTE[int(first["lane_idx"]) % LANE_PALETTE.size()]
		})

	# ── pass 3: build segments (split at portal jumps: Manhattan dist > 1) ───
	lane_idx = 0
	var primary_lane_idx := 0   # first non-air lane = lane 0

	for path_id in multi_paths.keys():
		if (path_id as String).begins_with("air"):
			continue

		var cells: Array        = multi_paths[path_id]
		var world_pts           := _cells_to_world(cells, gs, origin)
		if world_pts.size() < 2:
			lane_idx += 1
			continue

		var seg_start := 0
		for i in range(1, cells.size()):
			var a: Variant = cells[i - 1]
			var b: Variant = cells[i]
			if a is Vector2i and b is Vector2i:
				var manhattan: int = abs((b as Vector2i).x - (a as Vector2i).x) + abs((b as Vector2i).y - (a as Vector2i).y)
				if manhattan > 1:
					var sp := PackedVector2Array(world_pts.slice(seg_start, i))
					if sp.size() >= 2:
						_segments.append({"points": sp, "lane_idx": lane_idx})
					seg_start = i

		var fp := PackedVector2Array(world_pts.slice(seg_start, world_pts.size()))
		if fp.size() >= 2:
			_segments.append({"points": fp, "lane_idx": lane_idx})

		lane_idx += 1

	# ── build flow path from primary lane segments ────────────────────────────
	for seg in _segments:
		if int(seg["lane_idx"]) == primary_lane_idx:
			var flow_pts: PackedVector2Array = seg["points"]
			for pt in flow_pts:
				_flow_path.append(pt)

	# ── portals ───────────────────────────────────────────────────────────────
	var portals = level_data.get("path_portals", [])
	if portals is Array:
		for portal in portals:
			if not (portal is Dictionary):
				continue
			var pid: String = portal.get("path", "default")
			var e_idx: int  = int(portal.get("entry_index", -1))
			var x_idx: int  = int(portal.get("exit_index",  -1))
			var lc: Array   = multi_paths.get(pid, [])
			if e_idx >= 0 and e_idx < lc.size() and lc[e_idx] is Vector2i:
				_portal_entry_positions.append(_cell_center(lc[e_idx] as Vector2i, gs, origin))
			if x_idx >= 0 and x_idx < lc.size() and lc[x_idx] is Vector2i:
				_portal_exit_positions.append(_cell_center(lc[x_idx] as Vector2i, gs, origin))

	_flow_active = true
	set_process(_show_routes)
	queue_redraw()


# ============================================================= phase control

func set_wave_active(active: bool) -> void:
	var target_a := OPACITY_WAVE if active else OPACITY_BUILD
	if _opacity_tween:
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.tween_property(self, "modulate:a", target_a, 0.35)
	_flow_active = not active
	set_process(_show_routes and _flow_active)
	if not active:
		queue_redraw()   # redraw without flow dots immediately


func set_show_routes(visible_flag: bool) -> void:
	_show_routes = visible_flag
	set_process(_show_routes and _flow_active)
	queue_redraw()


# ============================================================= draw

func _draw() -> void:
	if not _show_routes:
		return

	# Tracks which crossover world-positions have been claimed by an "over" lane.
	# First drawer of a position = over (no gap); subsequent drawers = under (gap).
	var crossover_drawn: Dictionary = {}

	# 1. Lane lines — under-lanes get a gap at crossover centers
	for seg in _segments:
		var pts: PackedVector2Array = seg["points"]
		var li: int = int(seg["lane_idx"])
		var col: Color = LANE_PALETTE[li % LANE_PALETTE.size()]
		_draw_lane_with_gaps(pts, col, crossover_drawn)

	# 2. Bridge / tunnel visuals — drawn after lines so they appear on top
	for bd in _crossover_bridge_data:
		var bpos: Vector2 = bd["pos"]
		var bdir: Vector2 = bd["over_dir"]
		var bcol: Color   = bd["color"]
		_draw_bridge(bpos, bdir, bcol)

	# 3. Turn chevrons per segment
	for seg in _segments:
		var pts: PackedVector2Array = seg["points"]
		var li: int = int(seg["lane_idx"])
		_draw_chevrons(pts, LANE_PALETTE[li % LANE_PALETTE.size()])

	# 4. Portal markers
	for pos in _portal_entry_positions:
		draw_circle(pos, PORTAL_RADIUS, Color(PORTAL_ENTRY_COLOR, 0.25))
		draw_arc(pos, PORTAL_RADIUS, 0.0, TAU, 24, PORTAL_ENTRY_COLOR, 1.5)
	for pos in _portal_exit_positions:
		draw_circle(pos, PORTAL_RADIUS, Color(PORTAL_EXIT_COLOR, 0.25))
		draw_arc(pos, PORTAL_RADIUS, 0.0, TAU, 24, PORTAL_EXIT_COLOR, 1.5)

	# 5. Flow pulse animation (pre-wave only)
	if _flow_active and _flow_path.size() >= 2:
		_draw_flow_dots()


# Draws a polyline with a gap at any crossover point that has already been
# "claimed" as over by an earlier draw call.  First visit claims (no gap).
func _draw_lane_with_gaps(pts: PackedVector2Array, color: Color, drawn: Dictionary) -> void:
	var sub := PackedVector2Array()

	for i in range(pts.size()):
		var pt: Vector2 = pts[i]
		var wk: String  = _pos_key(pt)

		if _crossover_world_set.has(wk):
			if not drawn.has(wk):
				# First draw of this crossover = over lane — include normally
				drawn[wk] = true
				sub.append(pt)
			else:
				# Under lane — emit current sub-segment ending just before the gap
				if sub.size() > 0 and i > 0:
					var dir_in: Vector2 = pts[i - 1].direction_to(pt)
					sub.append(pt - dir_in * GAP_HALF)
				if sub.size() >= 2:
					draw_polyline(sub, color, LINE_WIDTH, false)
				# Start fresh from the other side of the gap
				sub = PackedVector2Array()
				if i + 1 < pts.size():
					var dir_out: Vector2 = pt.direction_to(pts[i + 1])
					sub.append(pt + dir_out * GAP_HALF)
		else:
			sub.append(pt)

	if sub.size() >= 2:
		draw_polyline(sub, color, LINE_WIDTH, false)


# Bridge deck (bright bar along over_dir) + tunnel shadow (dark bar across it).
func _draw_bridge(pos: Vector2, over_dir: Vector2, color: Color) -> void:
	if over_dir.length_squared() < 0.001:
		return
	var perp: Vector2 = Vector2(-over_dir.y, over_dir.x)

	# Tunnel shadow — dark bar in the under-lane direction, slightly wider
	draw_line(pos - perp * TUNNEL_HALF, pos + perp * TUNNEL_HALF, TUNNEL_SHADOW_COLOR, BRIDGE_BAR_WIDTH + 2.0)

	# Bridge deck — bright bar in the over-lane direction
	draw_line(pos - over_dir * BRIDGE_BAR_HALF, pos + over_dir * BRIDGE_BAR_HALF, BRIDGE_BRIGHT_COLOR, BRIDGE_BAR_WIDTH)

	# White centre dot for visual crispness
	draw_circle(pos, 2.0, Color(1.0, 1.0, 1.0, 0.80))


func _draw_chevrons(pts: PackedVector2Array, color: Color) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var last_at := -CHEVRON_EVERY

	for i in range(1, n - 1):
		var from_dir: Vector2 = (pts[i] - pts[i - 1]).normalized()
		var to_dir:   Vector2 = (pts[i + 1] - pts[i]).normalized()
		var is_turn:  bool    = from_dir.dot(to_dir) < 0.92
		var is_int:   bool    = (i - last_at) >= CHEVRON_EVERY
		if is_turn or is_int:
			_draw_chevron(pts[i], to_dir, color)
			last_at = i

	if n >= 3:
		var fd: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
		_draw_chevron(pts[n - 2].lerp(pts[n - 1], 0.4), fd, color)


func _draw_chevron(at: Vector2, dir: Vector2, color: Color) -> void:
	if dir.length_squared() < 0.001:
		return
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip:   Vector2 = at + dir  * CHEVRON_SIZE * 0.45
	var left:  Vector2 = tip - dir * CHEVRON_SIZE * 0.55 + perp * CHEVRON_SIZE * 0.50
	var right: Vector2 = tip - dir * CHEVRON_SIZE * 0.55 - perp * CHEVRON_SIZE * 0.50
	draw_line(tip, left,  color, 1.2)
	draw_line(tip, right, color, 1.2)


func _draw_flow_dots() -> void:
	for i in range(FLOW_DOT_COUNT):
		var t:   float  = fmod(_flow_t + float(i) * FLOW_DOT_SPACING, 1.0)
		var pos: Vector2 = _sample_path(_flow_path, t)
		var alpha: float = 1.0 - float(i) * 0.35
		draw_circle(pos, FLOW_DOT_RADIUS, Color(FLOW_DOT_COLOR, alpha))
		draw_arc(pos, FLOW_DOT_RADIUS + 1.5, 0.0, TAU, 12, Color(FLOW_DOT_COLOR, alpha * 0.38), 1.0)


func _sample_path(path_pts: PackedVector2Array, t: float) -> Vector2:
	var n: int = path_pts.size()
	if n <= 1:
		return path_pts[0] if n == 1 else Vector2.ZERO
	var fi:  float = t * float(n - 1)
	var idx: int   = clampi(int(fi), 0, n - 2)
	return path_pts[idx].lerp(path_pts[idx + 1], fi - float(idx))


# ============================================================= helpers

func _cells_to_world(cells: Array, gs: int, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(cells.size())
	for i in range(cells.size()):
		var c: Variant = cells[i]
		if c is Vector2i:
			out[i] = _cell_center(c as Vector2i, gs, origin)
	return out


func _cell_center(cv: Vector2i, gs: int, origin: Vector2) -> Vector2:
	return origin + Vector2(float(cv.x) * float(gs) + float(gs) * 0.5,
							float(cv.y) * float(gs) + float(gs) * 0.5)


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _pos_key(pos: Vector2) -> String:
	return "%d,%d" % [int(round(pos.x)), int(round(pos.y))]
