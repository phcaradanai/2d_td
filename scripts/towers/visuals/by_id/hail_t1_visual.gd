extends RefCounted

# Tower: Hail Tower 1
# Role: Frozen chain shards — chain between enemies, slow and damage groups.
# Elements: light, darkness, water
# Visual source: custom by_id visual
# Visual intent: premium symmetrical hail rail-conductor; neutral-arrow style body + forward shard emitter.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := false) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float, light_color: Color, dark_color: Color, water_color: Color) -> void:
	var outer := _regular_poly(center, radius, 9, PI / 9.0)
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(outer, -1.4), Color(0.012, 0.018, 0.030, 0.9))

	var top := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.66),
		center + Vector2(radius * 0.52, radius * 0.18),
		center + Vector2(0.0, radius * 0.08),
		center + Vector2(-radius * 0.52, radius * 0.18),
	])
	var left := PackedVector2Array([
		center + Vector2(-radius * 0.52, radius * 0.18),
		center + Vector2(0.0, radius * 0.08),
		center + Vector2(0.0, radius * 0.66),
		center + Vector2(-radius * 0.58, radius * 0.48),
	])
	var right := PackedVector2Array([
		center + Vector2(0.0, radius * 0.08),
		center + Vector2(radius * 0.52, radius * 0.18),
		center + Vector2(radius * 0.58, radius * 0.48),
		center + Vector2(0.0, radius * 0.66),
	])
	t.draw_colored_polygon(top, Color(light_color.r, light_color.g, light_color.b, 0.46))
	t.draw_colored_polygon(left, Color(dark_color.r, dark_color.g, dark_color.b, 0.50))
	t.draw_colored_polygon(right, Color(water_color.r, water_color.g, water_color.b, 0.50))
	_draw_stroked_polyline(t, outer, Color(0.86, 0.96, 1.0, 0.38), 0.8, true)

static func _draw_snowflake(t: Node2D, center: Vector2, radius: float, ice_color: Color) -> void:
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		var dir := Vector2(cos(a), sin(a))
		_draw_stroked_line(t, center + dir * (radius * 0.18), center + dir * (radius * 0.82), Color(ice_color.r, ice_color.g, ice_color.b, 0.72), 0.75, true)
		var p := center + dir * (radius * 0.58)
		var side_a := a + PI * 0.74
		var side_b := a - PI * 0.74
		t.draw_line(p, p + Vector2(cos(side_a), sin(side_a)) * radius * 0.13, DETAIL_OUTLINE_SOFT, 1.5, true)
		t.draw_line(p, p + Vector2(cos(side_b), sin(side_b)) * radius * 0.13, DETAIL_OUTLINE_SOFT, 1.5, true)
		t.draw_line(p, p + Vector2(cos(side_a), sin(side_a)) * radius * 0.10, ice_color, 0.65, true)
		t.draw_line(p, p + Vector2(cos(side_b), sin(side_b)) * radius * 0.10, ice_color, 0.65, true)
	_draw_stroked_circle(t, center, radius * 0.14, Color(0.92, 1.0, 1.0, 0.88), 1.2)

static func _draw_hail_chain(t: Node2D, nodes: Array, color: Color, width: float) -> void:
	for i in range(nodes.size() - 1):
		var a: Vector2 = nodes[i]
		var b: Vector2 = nodes[i + 1]
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var jag := PackedVector2Array([
			a,
			mid + n * 2.5,
			mid - n * 2.0,
			b,
		])
		_draw_stroked_polyline(t, jag, color, width, false)

static func _mirrored_y(points: PackedVector2Array) -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	for p: Vector2 in points:
		mirrored.append(Vector2(p.x, -p.y))
	return mirrored

static func _draw_mirrored_circuit_trace(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	_draw_stroked_polyline(t, points, color, width, false)
	_draw_stroked_polyline(t, _mirrored_y(points), color, width, false)

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var s := 1.0 + float(max(lvl - 1, 0)) * 0.05

	var base := _regular_poly(Vector2(0, 3) * s, 25.5 * s, 8, PI / 8.0)
	_outline_poly(t, base)

	var chassis := PackedVector2Array([
		Vector2(-22, -14) * s,
		Vector2(-10, -22) * s,
		Vector2(12, -20) * s,
		Vector2(22, -9) * s,
		Vector2(22, 9) * s,
		Vector2(12, 20) * s,
		Vector2(-10, 22) * s,
		Vector2(-22, 14) * s,
	])
	_outline_poly(t, chassis)

	var emitter := PackedVector2Array([
		Vector2(-9, -6) * s,
		Vector2(3, -10) * s,
		Vector2(28, -6) * s,
		Vector2(34, 0) * s,
		Vector2(28, 6) * s,
		Vector2(3, 10) * s,
		Vector2(-9, 6) * s,
	])
	_outline_poly(t, emitter)

	for p in [Vector2(-18, -13) * s, Vector2(-18, 13) * s, Vector2(14, -15) * s, Vector2(14, 15) * s]:
		_outline_circle(t, p, 4.5 * s)
	_outline_circle(t, Vector2(0, 0) * s, 9.5 * s)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var s := 1.0 + float(max(lvl - 1, 0)) * 0.05
	var light_color := Color(1.0, 0.92, 0.40, 1.0)
	var dark_color := Color(0.50, 0.20, 0.95, 1.0)
	var water_color := Color(0.34, 0.88, 1.0, 1.0)
	if el_colors.size() > 0:
		light_color = el_colors[0]
	if el_colors.size() > 1:
		dark_color = el_colors[1]
	if el_colors.size() > 2:
		water_color = el_colors[2]

	var ice := Color(0.68, 0.96, 1.0, 1.0)
	var _ice_soft := Color(0.38, 0.84, 1.0, 0.72)
	var shadow := Color(0.015, 0.020, 0.036, 0.94)
	var dark_ice := Color(0.16, 0.18, 0.34, 0.96)

	# Subtle static chain/slow radius cue, not a gameplay radius indicator.
	for r in [23.0, 29.0]:
		t.draw_arc(Vector2.ZERO, r * s, -2.65, -0.35, 18, DETAIL_OUTLINE_SOFT, 2.2, true)
		t.draw_arc(Vector2.ZERO, r * s, -2.65, -0.35, 18, Color(ice.r, ice.g, ice.b, 0.20), 1.0, true)
		t.draw_arc(Vector2.ZERO, r * s, 0.40, 2.52, 18, DETAIL_OUTLINE_SOFT, 2.2, true)
		t.draw_arc(Vector2.ZERO, r * s, 0.40, 2.52, 18, Color(dark_color.r, dark_color.g, dark_color.b, 0.18), 1.0, true)

	# Base plate.
	var base := _regular_poly(Vector2(0, 3) * s, 25.5 * s, 8, PI / 8.0)
	t.draw_colored_polygon(base, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(base, -2.0 * s), shadow)
	_draw_stroked_polyline(t, _regular_poly(Vector2(0, 3) * s, 21.0 * s, 8, PI / 8.0), Color(water_color.r, water_color.g, water_color.b, 0.38), 1.0, true)

	# Neutral-arrow style chassis: hard-surface, y-mirrored, with the emitter on the X axis.
	var chassis := PackedVector2Array([
		Vector2(-22, -14) * s,
		Vector2(-10, -22) * s,
		Vector2(12, -20) * s,
		Vector2(22, -9) * s,
		Vector2(22, 9) * s,
		Vector2(12, 20) * s,
		Vector2(-10, 22) * s,
		Vector2(-22, 14) * s,
	])
	t.draw_colored_polygon(chassis, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(chassis, -1.8 * s), dark_ice)
	_draw_stroked_polyline(t, chassis, Color(water_color.r, water_color.g, water_color.b, 0.38), 0.95, true)

	var top_plate := PackedVector2Array([
		Vector2(-14, -13) * s,
		Vector2(8, -14) * s,
		Vector2(17, -7) * s,
		Vector2(4, -5) * s,
		Vector2(-15, -7) * s,
	])
	var bottom_plate := PackedVector2Array([
		Vector2(-14, 13) * s,
		Vector2(8, 14) * s,
		Vector2(17, 7) * s,
		Vector2(4, 5) * s,
		Vector2(-15, 7) * s,
	])
	t.draw_colored_polygon(top_plate, Color(dark_color.r, dark_color.g, dark_color.b, 0.34))
	t.draw_colored_polygon(bottom_plate, Color(water_color.r, water_color.g, water_color.b, 0.32))
	_draw_stroked_polyline(t, top_plate, Color(ice.r, ice.g, ice.b, 0.35), 0.7, true)
	_draw_stroked_polyline(t, bottom_plate, Color(ice.r, ice.g, ice.b, 0.30), 0.7, true)

	# Mirrored circuit chain traces: draw the top trace once, mirror it over the center axis.
	var top_trace := PackedVector2Array([
		Vector2(-18, -13) * s,
		Vector2(-8, -16) * s,
		Vector2(2, -13) * s,
		Vector2(14, -15) * s,
	])
	_draw_mirrored_circuit_trace(t, top_trace, Color(ice.r, ice.g, ice.b, 0.62), 1.15)
	_draw_mirrored_circuit_trace(t, PackedVector2Array([
		Vector2(-11, -6) * s,
		Vector2(-2, -9) * s,
		Vector2(8, -6) * s,
	]), Color(water_color.r, water_color.g, water_color.b, 0.40), 0.85)

	var relay_nodes := [Vector2(-18, -13) * s, Vector2(14, -15) * s, Vector2(14, 15) * s, Vector2(-18, 13) * s]
	for i in range(relay_nodes.size()):
		var p: Vector2 = relay_nodes[i]
		var col := dark_color if i == 0 or i == 3 else light_color
		_draw_stroked_circle(t, p, 4.5 * s, Color(col.r, col.g, col.b, 0.72), 1.4)
		t.draw_circle(p, 1.6 * s, Color(0.95, 1.0, 1.0, 0.92))

	# Forward hail emitter: shard launcher, not a round muzzle.
	var emitter := PackedVector2Array([
		Vector2(-9, -6) * s,
		Vector2(3, -10) * s,
		Vector2(28, -6) * s,
		Vector2(34, 0) * s,
		Vector2(28, 6) * s,
		Vector2(3, 10) * s,
		Vector2(-9, 6) * s,
	])
	t.draw_colored_polygon(emitter, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(emitter, -1.3 * s), Color(0.22, 0.68, 0.90, 0.94))
	_draw_stroked_line(t, Vector2(3, -7) * s, Vector2(28, -3) * s, Color(0.94, 1.0, 1.0, 0.68), 0.9, true)
	_draw_stroked_line(t, Vector2(3, 7) * s, Vector2(28, 3) * s, Color(dark_color.r, dark_color.g, dark_color.b, 0.46), 0.9, true)

	# Central frost glyph.
	_draw_stroked_circle(t, Vector2(0, 0) * s, 9.5 * s, Color(0.05, 0.12, 0.20, 0.96), 1.8)
	_draw_snowflake(t, Vector2(0, 0) * s, 8.0 * s, ice)

	# Static hail shards near exit: chain projectile preview only.
	for p in [Vector2(37, -9) * s, Vector2(42, 0) * s, Vector2(37, 9) * s]:
		var shard := PackedVector2Array([
			p + Vector2(-2.1, 0.0) * s,
			p + Vector2(0.0, -3.3) * s,
			p + Vector2(2.1, 0.0) * s,
			p + Vector2(0.0, 3.3) * s,
		])
		t.draw_colored_polygon(shard, DETAIL_OUTLINE)
		t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(shard, -0.7 * s), Color(ice.r, ice.g, ice.b, 0.78))

	_draw_tri_element_token(t, Vector2(0, 28.0) * s, 6.5 * s, light_color, dark_color, water_color)
