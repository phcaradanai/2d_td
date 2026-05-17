extends RefCounted

# Tower: Flesh Golem Tower 1
# Role: Primal slam — massive elemental golem that pounds land groups with Water + Nature + Earth.
# Visual source: custom by_id visual
# Visual intent: premium production-ready golem body / splash slam tower.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const WATER := Color(0.23, 0.72, 1.0, 0.95)
const WATER_DARK := Color(0.06, 0.30, 0.50, 0.95)
const NATURE := Color(0.42, 0.95, 0.36, 0.95)
const NATURE_DARK := Color(0.10, 0.35, 0.16, 0.95)
const EARTH := Color(0.70, 0.52, 0.28, 0.96)
const EARTH_DARK := Color(0.25, 0.19, 0.12, 0.98)
const CORE := Color(0.64, 1.0, 0.82, 0.98)
const SLAM := Color(0.70, 0.92, 1.0, 0.72)

static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * VISUAL_SCALE

static func _w(width: float) -> float:
	return max(1.0, width * VISUAL_SCALE)

static func _poly(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * VISUAL_SCALE)
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		pts.append((center + Vector2(cos(a), sin(a)) * radius) * VISUAL_SCALE)
	return pts

static func _draw_filled_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	t.draw_colored_polygon(_poly(points), color)

static func _draw_outlined_poly(t: Node2D, points: PackedVector2Array, fill: Color, outline_width: float = 2.4) -> void:
	var scaled := _poly(points)
	t.draw_colored_polygon(scaled, OUTLINE)
	var inner := PackedVector2Array()
	var center := Vector2.ZERO
	for p: Vector2 in scaled:
		center += p
	if scaled.size() > 0:
		center /= float(scaled.size())
	for p: Vector2 in scaled:
		inner.append(center + (p - center) * 0.88)
	t.draw_colored_polygon(inner, fill)
	var path := PackedVector2Array(scaled)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _w(outline_width), true)

static func _draw_outlined_circle(t: Node2D, center: Vector2, radius: float, fill: Color, outline_width: float = 2.4) -> void:
	t.draw_circle(center * VISUAL_SCALE, (radius + outline_width) * VISUAL_SCALE, OUTLINE)
	t.draw_circle(center * VISUAL_SCALE, radius * VISUAL_SCALE, fill)

static func _draw_line(t: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color, width: float = 2.0) -> void:
	t.draw_line(from_pos * VISUAL_SCALE, to_pos * VISUAL_SCALE, OUTLINE, _w(width + 2.2), true)
	t.draw_line(from_pos * VISUAL_SCALE, to_pos * VISUAL_SCALE, color, _w(width), true)

static func _draw_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float = 2.0, closed: bool = false) -> void:
	var pts := _poly(points)
	if closed and pts.size() > 0:
		pts.append(pts[0])
	t.draw_polyline(pts, OUTLINE, _w(width + 2.2), true)
	t.draw_polyline(pts, color, _w(width), true)

static func _arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, steps: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var f := float(i) / float(steps)
		var a: float = lerp(start_angle, end_angle, f)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

static func _draw_arc_path(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float = 2.0) -> void:
	_draw_polyline(t, _arc_points(center, radius, start_angle, end_angle), color, width, false)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := center
	_draw_outlined_circle(t, c, radius + 2.0, Color(0.06, 0.08, 0.07, 0.96), 1.6)
	_draw_outlined_circle(t, c + Vector2(-radius * 0.72, radius * 0.15), radius * 0.52, WATER, 1.2)
	_draw_outlined_circle(t, c + Vector2(radius * 0.72, radius * 0.15), radius * 0.52, NATURE, 1.2)
	_draw_outlined_circle(t, c + Vector2(0.0, -radius * 0.68), radius * 0.52, EARTH, 1.2)

static func _draw_slam_rune(t: Node2D) -> void:
	# Three grounded shock chevrons: clear splash/ground-pound language.
	var left := PackedVector2Array([Vector2(-18, 20), Vector2(-10, 15), Vector2(-2, 20)])
	var mid := PackedVector2Array([Vector2(-9, 24), Vector2(0, 18), Vector2(9, 24)])
	var right := PackedVector2Array([Vector2(2, 20), Vector2(10, 15), Vector2(18, 20)])
	_draw_polyline(t, left, SLAM, 2.2, false)
	_draw_polyline(t, mid, SLAM, 2.4, false)
	_draw_polyline(t, right, SLAM, 2.2, false)

static func _draw_leaf_plate(t: Node2D, center: Vector2, flip: float) -> void:
	var leaf := PackedVector2Array([
		center + Vector2(0, -10),
		center + Vector2(8 * flip, -3),
		center + Vector2(5 * flip, 8),
		center + Vector2(0, 12),
		center + Vector2(-5 * flip, 8),
		center + Vector2(-8 * flip, -3),
	])
	_draw_outlined_poly(t, leaf, NATURE_DARK.lerp(NATURE, 0.35), 1.8)
	_draw_line(t, center + Vector2(0, -7), center + Vector2(0, 8), NATURE, 1.4)

static func _draw_boulder_shoulder(t: Node2D, center: Vector2, flip: float) -> void:
	var shoulder := PackedVector2Array([
		center + Vector2(-8 * flip, -13),
		center + Vector2(11 * flip, -9),
		center + Vector2(15 * flip, 3),
		center + Vector2(6 * flip, 14),
		center + Vector2(-12 * flip, 11),
		center + Vector2(-15 * flip, -2),
	])
	_draw_outlined_poly(t, shoulder, EARTH, 2.2)
	_draw_line(t, center + Vector2(-5 * flip, -7), center + Vector2(7 * flip, 6), EARTH_DARK.lerp(WATER, 0.25), 1.4)

static func _draw_fist(t: Node2D, center: Vector2, flip: float) -> void:
	var wrist := PackedVector2Array([
		center + Vector2(-5 * flip, -15),
		center + Vector2(7 * flip, -14),
		center + Vector2(10 * flip, 8),
		center + Vector2(-5 * flip, 12),
	])
	_draw_outlined_poly(t, wrist, EARTH_DARK.lerp(WATER_DARK, 0.22), 1.8)
	var fist := PackedVector2Array([
		center + Vector2(4 * flip, 2),
		center + Vector2(18 * flip, 6),
		center + Vector2(21 * flip, 17),
		center + Vector2(14 * flip, 25),
		center + Vector2(0 * flip, 20),
		center + Vector2(-3 * flip, 9),
	])
	_draw_outlined_poly(t, fist, EARTH.lerp(NATURE, 0.12), 2.4)
	for i in range(3):
		var x := center.x + (7.0 + float(i) * 4.2) * flip
		_draw_line(t, Vector2(x, center.y + 9), Vector2(x + 2.4 * flip, center.y + 18), EARTH_DARK, 1.1)

static func draw_contour(t: Node2D) -> void:
	# Compact contour to keep catalog fit stable. No self-rotation here; renderer/catalog handles it.
	t.draw_circle(_v(0, 0), 42.0 * VISUAL_SCALE, OUTLINE_SOFT)
	t.draw_circle(_v(0, 0), 32.0 * VISUAL_SCALE, OUTLINE)
	_draw_outlined_circle(t, Vector2(-29, 2), 12.5, OUTLINE, 1.0)
	_draw_outlined_circle(t, Vector2(29, 2), 12.5, OUTLINE, 1.0)
	_draw_outlined_circle(t, Vector2(-23, 24), 11.5, OUTLINE, 1.0)
	_draw_outlined_circle(t, Vector2(23, 24), 11.5, OUTLINE, 1.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var water_col := WATER
	var nature_col := NATURE
	var earth_col := EARTH
	if el_colors.size() >= 3:
		water_col = el_colors[0]
		nature_col = el_colors[1]
		earth_col = el_colors[2]

	# Static splash/ground-pound field: conveys land-only AoE without particles.
	_draw_arc_path(t, Vector2.ZERO, 37.0, deg_to_rad(20), deg_to_rad(92), water_col.lerp(Color.WHITE, 0.20), 1.8)
	_draw_arc_path(t, Vector2.ZERO, 37.0, deg_to_rad(138), deg_to_rad(205), nature_col, 1.8)
	_draw_arc_path(t, Vector2.ZERO, 39.0, deg_to_rad(238), deg_to_rad(320), earth_col, 2.0)
	for p: Vector2 in [Vector2(-35, 19), Vector2(35, 19), Vector2(-25, 31), Vector2(25, 31)]:
		_draw_outlined_circle(t, p, 2.2, SLAM, 1.0)

	# Earth base slab / golem feet.
	var base := PackedVector2Array([
		Vector2(-26, 20), Vector2(-15, 13), Vector2(15, 13), Vector2(26, 20),
		Vector2(21, 31), Vector2(-21, 31),
	])
	_draw_outlined_poly(t, base, earth_col.lerp(EARTH_DARK, 0.24), 2.6)
	_draw_slam_rune(t)

	# Massive golem torso.
	var torso := PackedVector2Array([
		Vector2(-18, -19), Vector2(-8, -29), Vector2(9, -29), Vector2(20, -18),
		Vector2(24, 0), Vector2(15, 20), Vector2(-14, 20), Vector2(-24, 0),
	])
	_draw_outlined_poly(t, torso, earth_col.lerp(WATER_DARK, 0.18), 2.8)

	# Water-vine chest basin/core.
	_draw_outlined_circle(t, Vector2.ZERO, 17.0, water_col.lerp(NATURE_DARK, 0.18), 2.4)
	_draw_outlined_circle(t, Vector2.ZERO, 10.5, CORE.lerp(water_col, 0.30), 1.8)
	_draw_polyline(t, PackedVector2Array([Vector2(-11, 2), Vector2(-4, -5), Vector2(3, -2), Vector2(10, -8)]), water_col, 1.6)
	_draw_polyline(t, PackedVector2Array([Vector2(-10, 8), Vector2(-2, 3), Vector2(5, 7), Vector2(12, 1)]), nature_col, 1.6)

	# Head / primal mask.
	var head := PackedVector2Array([
		Vector2(-12, -34), Vector2(0, -43), Vector2(12, -34),
		Vector2(10, -24), Vector2(0, -19), Vector2(-10, -24),
	])
	_draw_outlined_poly(t, head, earth_col.lerp(Color.WHITE, 0.08), 2.4)
	_draw_outlined_circle(t, Vector2(-4.8, -31), 2.3, water_col.lerp(Color.WHITE, 0.28), 0.9)
	_draw_outlined_circle(t, Vector2(4.8, -31), 2.3, nature_col.lerp(Color.WHITE, 0.25), 0.9)
	_draw_line(t, Vector2(-6, -23), Vector2(6, -23), OUTLINE_SOFT, 1.2)

	# Shoulders / arms / slam fists.
	_draw_boulder_shoulder(t, Vector2(-24, -8), -1.0)
	_draw_boulder_shoulder(t, Vector2(24, -8), 1.0)
	_draw_fist(t, Vector2(-32, 0), -1.0)
	_draw_fist(t, Vector2(32, 0), 1.0)

	# Nature armor fins and water runes.
	_draw_leaf_plate(t, Vector2(-17, 7), -1.0)
	_draw_leaf_plate(t, Vector2(17, 7), 1.0)
	for p: Vector2 in [Vector2(-22, -22), Vector2(22, -22), Vector2(-14, 25), Vector2(14, 25)]:
		_draw_outlined_circle(t, p, 3.2, water_col.lerp(Color.WHITE, 0.15), 1.1)

	# Heavy crack seams for premium stone/earth material.
	_draw_line(t, Vector2(-5, -18), Vector2(-10, -7), EARTH_DARK, 1.3)
	_draw_line(t, Vector2(7, -17), Vector2(13, -5), EARTH_DARK, 1.3)
	_draw_line(t, Vector2(-8, 13), Vector2(-2, 20), EARTH_DARK, 1.2)
	_draw_line(t, Vector2(8, 13), Vector2(2, 20), EARTH_DARK, 1.2)

	# Tri-element token at the lower rear.
	_draw_tri_element_token(t, Vector2(0, 35), 5.6)
