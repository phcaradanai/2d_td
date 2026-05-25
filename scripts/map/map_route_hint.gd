extends Node2D
class_name MapRouteHint

## Fixed-path route hint — per-route lane lines, crossover bridge/gap visuals,
## turn chevrons, portal markers, per-route flow pulses, and spawn badges.
##
## Z-layering: z_index=0, tree-position 1 (right after baked MazeMapRenderer).
## All gameplay containers (EnemyContainer, TowerContainer, …) are later in the
## tree and render on top at the same z=0.

# ============================================================= constants

const LINE_WIDTH       := 2.0
const CHEVRON_SIZE     := 6.0
const CHEVRON_EVERY    := 8
const PORTAL_RADIUS    := 8.0
const Z_INDEX_LAYER    := 0

const OPACITY_BUILD    := 0.65
const OPACITY_WAVE     := 0.15

const GAP_HALF         := 15.0
const BRIDGE_BAR_HALF  := 13.0
const BRIDGE_BAR_WIDTH := 4.5
const TUNNEL_HALF      := 11.0

const FLOW_SPEED       := 0.16
const FLOW_DOT_RADIUS  := 3.2
const SPAWN_BADGE_R    := 9.0
const SPAWN_FONT_SIZE  := 10

static var LANE_PALETTE: Array[Color] = [
	Color(0.20, 0.90, 1.00, 1.0),
	Color(1.00, 0.65, 0.15, 1.0),
	Color(0.25, 1.00, 0.35, 1.0),
	Color(0.95, 0.25, 0.75, 1.0),
]

const PORTAL_ENTRY_COLOR  := Color(0.75, 0.30, 1.00, 1.0)
const PORTAL_EXIT_COLOR   := Color(0.20, 1.00, 1.00, 1.0)
const BRIDGE_BRIGHT_COLOR := Color(1.00, 1.00, 0.50, 0.95)
const TUNNEL_SHADOW_COLOR := Color(0.00, 0.00, 0.00, 0.72)
const FLOW_DOT_COLOR      := Color(1.00, 1.00, 1.00, 0.90)

# ============================================================= state

# Each segment: {points: PackedVector2Array, lane_idx: int, path_id: String}
var _segments: Array[Dictionary] = []
var _portal_entry_positions: Array[Vector2] = []
var _portal_exit_positions:  Array[Vector2] = []

var _crossover_bridge_data: Array[Dictionary] = []
var _crossover_world_set:   Dictionary = {}

# Per-path flow data
var _path_flows:     Dictionary = {}   # path_id -> PackedVector2Array
var _path_lane_idx:  Dictionary = {}   # path_id -> int
var _path_badge_pos: Dictionary = {}   # path_id -> Vector2 (badge anchor, 1 step into route)

# Which path IDs are considered "active" for drawing.
# Empty = draw all non-air paths (default for single-spawn maps).
var _active_path_ids:  Array[String] = []
var _all_non_air_ids:  Array[String] = []

var _flow_t:    float = 0.0
var _flow_active: bool = false
var _show_routes: bool = true
var _opacity_tween: Tween = null
var _font: Font = null


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
	_path_flows.clear()
	_path_lane_idx.clear()
	_path_badge_pos.clear()
	_active_path_ids.clear()
	_all_non_air_ids.clear()
	_flow_t = 0.0

	if _opacity_tween:
		_opacity_tween.kill()
		_opacity_tween = null
	modulate.a = OPACITY_BUILD

	if lm == null or not is_instance_valid(lm):
		set_process(false)
		return

	_font = ThemeDB.fallback_font

	var gs: int        = int(lm.grid_size)
	var origin: Vector2 = lm.grid_origin
	var multi_paths: Dictionary = lm.multi_paths
	var level_data: Dictionary  = lm.level_data

	# ── pass 1: visit every non-air cell, collect for crossover detection ──────
	var cell_visits: Dictionary = {}
	var lane_idx := 0

	for path_id in multi_paths.keys():
		var pid: String = path_id
		if pid.begins_with("air"):
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
			(cell_visits[ck] as Array).append({"lane_idx": lane_idx, "pos": wp, "dir": travel_dir})

		lane_idx += 1

	# ── pass 2: identify crossovers ────────────────────────────────────────────
	for ck in cell_visits.keys():
		var visits: Array = cell_visits[ck] as Array
		if visits.size() < 2:
			continue
		var first: Dictionary = visits[0]
		var wp: Vector2 = first["pos"]
		var wk: String  = _pos_key(wp)
		_crossover_world_set[wk] = true
		_crossover_bridge_data.append({
			"pos": wp,
			"over_dir": first["dir"],
			"color": LANE_PALETTE[int(first["lane_idx"]) % LANE_PALETTE.size()]
		})

	# ── pass 3: build segments + per-path flow paths ───────────────────────────
	lane_idx = 0

	for path_id in multi_paths.keys():
		var pid: String = path_id
		if pid.begins_with("air"):
			continue

		_all_non_air_ids.append(pid)
		_path_lane_idx[pid] = lane_idx

		var cells: Array = multi_paths[path_id]
		var world_pts    := _cells_to_world(cells, gs, origin)
		if world_pts.size() < 2:
			lane_idx += 1
			continue

		# Split into segments at portal jumps (Manhattan dist > 1)
		var seg_start := 0
		for i in range(1, cells.size()):
			var a: Variant = cells[i - 1]
			var b: Variant = cells[i]
			if a is Vector2i and b is Vector2i:
				var manhattan: int = abs((b as Vector2i).x - (a as Vector2i).x) + abs((b as Vector2i).y - (a as Vector2i).y)
				if manhattan > 1:
					var sp := PackedVector2Array(world_pts.slice(seg_start, i))
					if sp.size() >= 2:
						_segments.append({"points": sp, "lane_idx": lane_idx, "path_id": pid})
					seg_start = i

		var fp := PackedVector2Array(world_pts.slice(seg_start, world_pts.size()))
		if fp.size() >= 2:
			_segments.append({"points": fp, "lane_idx": lane_idx, "path_id": pid})

		# Build flow path for this route (all its segments concatenated)
		var flow: PackedVector2Array = PackedVector2Array()
		for seg in _segments:
			var spid: String = seg["path_id"]
			if spid == pid:
				var spts: PackedVector2Array = seg["points"]
				for pt in spts:
					flow.append(pt)
		_path_flows[pid] = flow

		# Badge anchor: 1 step into the route (index 1), not at the very first point
		if flow.size() >= 2:
			_path_badge_pos[pid] = flow[1]
		elif flow.size() == 1:
			_path_badge_pos[pid] = flow[0]

		lane_idx += 1

	# ── portals ────────────────────────────────────────────────────────────────
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
	set_process(_show_routes and _flow_active)
	queue_redraw()


# ============================================================= active routes

## Supply the path IDs used by the upcoming/current wave.
## Call from main when the wave preview changes.
## Pass [] to fall back to showing all non-air paths.
func set_active_path_ids(ids: Array[String]) -> void:
	_active_path_ids = ids.duplicate()
	queue_redraw()


func _get_effective_ids() -> Array[String]:
	if not _active_path_ids.is_empty():
		return _active_path_ids
	return _all_non_air_ids


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
		queue_redraw()


func set_show_routes(visible_flag: bool) -> void:
	_show_routes = visible_flag
	set_process(_show_routes and _flow_active)
	queue_redraw()


# ============================================================= draw

func _draw() -> void:
	if not _show_routes:
		return

	var effective_ids := _get_effective_ids()
	if effective_ids.is_empty():
		return

	# crossover_drawn: first segment to reach a crossover pos "claims" over status
	# gapped: positions where a gap was actually drawn (for bridge filter)
	var crossover_drawn: Dictionary = {}
	var gapped: Dictionary = {}

	# 1. Lane lines — under-lanes get a gap at crossover centers
	for seg in _segments:
		var spid: String = seg["path_id"]
		if not effective_ids.has(spid):
			continue
		var pts: PackedVector2Array = seg["points"]
		var li: int = int(seg["lane_idx"])
		_draw_lane_with_gaps(pts, LANE_PALETTE[li % LANE_PALETTE.size()], crossover_drawn, gapped)

	# 2. Bridge deck + tunnel shadow — only where a gap was actually created
	for bd in _crossover_bridge_data:
		var bwk: String = _pos_key(bd["pos"])
		if gapped.has(bwk):
			_draw_bridge(bd["pos"], bd["over_dir"], bd["color"])

	# 3. Turn chevrons
	for seg in _segments:
		var spid: String = seg["path_id"]
		if not effective_ids.has(spid):
			continue
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

	# 5. Per-route flow pulses (pre-wave)
	if _flow_active:
		var route_count := effective_ids.size()
		for ri in range(route_count):
			var pid: String = effective_ids[ri]
			if not _path_flows.has(pid):
				continue
			var flow: PackedVector2Array = _path_flows[pid]
			if flow.size() < 2:
				continue
			var phase: float = float(ri) / float(max(route_count, 1))
			var t: float = fmod(_flow_t + phase, 1.0)
			var li: int = int(_path_lane_idx.get(pid, 0))
			var col: Color = LANE_PALETTE[li % LANE_PALETTE.size()]
			var dot_pos: Vector2 = _sample_path(flow, t)
			draw_circle(dot_pos, FLOW_DOT_RADIUS, Color(FLOW_DOT_COLOR, 0.88))
			draw_arc(dot_pos, FLOW_DOT_RADIUS + 1.5, 0.0, TAU, 12, Color(col, 0.45), 1.2)

	# 6. Spawn badges — only when multiple active routes AND pre-wave
	if _flow_active and effective_ids.size() >= 2:
		for ri in range(effective_ids.size()):
			var pid: String = effective_ids[ri]
			if not _path_badge_pos.has(pid):
				continue
			var badge_pos: Vector2 = _path_badge_pos[pid]
			var li: int = int(_path_lane_idx.get(pid, 0))
			var col: Color = LANE_PALETTE[li % LANE_PALETTE.size()]
			var label: String = String.chr(65 + ri)  # 65 = ord('A')
			_draw_spawn_badge(badge_pos, label, col)


# Draws a polyline for one lane, inserting a gap wherever a crossover position
# has already been claimed by an earlier draw call (= over lane).
# First visit to a crossover claims it as "over" (no gap). Fills `gapped` with
# positions where a gap was actually inserted so the bridge filter can use it.
func _draw_lane_with_gaps(pts: PackedVector2Array, color: Color, drawn: Dictionary, gapped: Dictionary) -> void:
	var sub := PackedVector2Array()

	for i in range(pts.size()):
		var pt: Vector2 = pts[i]
		var wk: String  = _pos_key(pt)

		if _crossover_world_set.has(wk):
			if not drawn.has(wk):
				drawn[wk] = true
				sub.append(pt)
			else:
				# Under-lane: create gap
				if sub.size() > 0 and i > 0:
					var dir_in: Vector2 = pts[i - 1].direction_to(pt)
					sub.append(pt - dir_in * GAP_HALF)
				if sub.size() >= 2:
					draw_polyline(sub, color, LINE_WIDTH, false)
				sub = PackedVector2Array()
				if i + 1 < pts.size():
					var dir_out: Vector2 = pt.direction_to(pts[i + 1])
					sub.append(pt + dir_out * GAP_HALF)
				gapped[wk] = true
		else:
			sub.append(pt)

	if sub.size() >= 2:
		draw_polyline(sub, color, LINE_WIDTH, false)


func _draw_bridge(pos: Vector2, over_dir: Vector2, color: Color) -> void:
	if over_dir.length_squared() < 0.001:
		return
	var perp: Vector2 = Vector2(-over_dir.y, over_dir.x)
	draw_line(pos - perp * TUNNEL_HALF, pos + perp * TUNNEL_HALF, TUNNEL_SHADOW_COLOR, BRIDGE_BAR_WIDTH + 2.0)
	draw_line(pos - over_dir * BRIDGE_BAR_HALF, pos + over_dir * BRIDGE_BAR_HALF, BRIDGE_BRIGHT_COLOR, BRIDGE_BAR_WIDTH)
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


func _draw_spawn_badge(pos: Vector2, label: String, color: Color) -> void:
	draw_circle(pos, SPAWN_BADGE_R, Color(0.0, 0.0, 0.0, 0.78))
	draw_arc(pos, SPAWN_BADGE_R, 0.0, TAU, 20, color, 1.8)
	if _font != null:
		draw_string(_font, pos + Vector2(-3.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, SPAWN_FONT_SIZE, color)


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
	return origin + Vector2(float(cv.x) * float(gs) + float(gs) * 0.5, float(cv.y) * float(gs) + float(gs) * 0.5)


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _pos_key(pos: Vector2) -> String:
	return "%d,%d" % [int(round(pos.x)), int(round(pos.y))]
