extends RefCounted

# Tower: Laser Tower 1
# Role: Focused beam / precision single-target rail laser
# Elements: light, darkness, earth
# Visual source: custom by_id visual
# Visual intent: premium symmetric prism rail-laser with paired void capacitors, earth stabilization rails, and a clear precision beam identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.79

const OUTLINE := Color(0.0, 0.0, 0.0, 0.94)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

const LIGHT_COL := Color(1.0, 0.92, 0.18, 1.0)
const LIGHT_SOFT := Color(1.0, 0.98, 0.46, 0.88)
const DARK_COL := Color(0.28, 0.16, 0.48, 1.0)
const DARK_SOFT := Color(0.60, 0.38, 0.88, 0.86)
const EARTH_COL := Color(0.56, 0.38, 0.19, 1.0)
const EARTH_SOFT := Color(0.82, 0.60, 0.34, 0.90)

const STEEL_DARK := Color(0.08, 0.105, 0.145, 1.0)
const STEEL_MID := Color(0.20, 0.24, 0.29, 1.0)
const STEEL_LIGHT := Color(0.50, 0.56, 0.61, 1.0)
const BEAM_CORE := Color(1.0, 0.98, 0.24, 1.0)
const BEAM_EDGE := Color(0.76, 0.48, 1.0, 0.94)
const BEAM_GHOST := Color(1.0, 0.93, 0.24, 0.36)


static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y)


static func _s(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE


static func _r(value: float) -> float:
	return value * VISUAL_SCALE


static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_s(p))
	return out


static func _outline_poly(t: Node2D, points: Array[Vector2]) -> void:
	t.draw_colored_polygon(_poly(points), OUTLINE)


static func _fill_poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), color)


static func _circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(_s(pos), _r(radius + 1.8), OUTLINE)
	t.draw_circle(_s(pos), _r(radius), color)


static func _ring(t: Node2D, pos: Vector2, radius: float, color: Color, width: float) -> void:
	t.draw_arc(_s(pos), _r(radius), 0.0, TAU, 40, OUTLINE, _r(width + 2.0), true)
	t.draw_arc(_s(pos), _r(radius), 0.0, TAU, 40, color, _r(width), true)


static func _line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(_s(a), _s(b), OUTLINE, _r(width + 2.3), true)
	t.draw_line(_s(a), _s(b), color, _r(width), true)


static func _polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed: bool = false) -> void:
	var path := PackedVector2Array()
	for p: Vector2 in points:
		path.append(_s(p))
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _r(width + 2.2), true)
	t.draw_polyline(path, color, _r(width), true)


static func _arc(t: Node2D, pos: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: float) -> void:
	t.draw_arc(_s(pos), _r(radius), from_angle, to_angle, 28, OUTLINE_SOFT, _r(width + 2.0), true)
	t.draw_arc(_s(pos), _r(radius), from_angle, to_angle, 28, color, _r(width), true)


static func _draw_prism_lens(t: Node2D, center: Vector2) -> void:
	_circle(t, center, 12.5, Color(0.10, 0.08, 0.16, 1.0))
	_ring(t, center, 9.0, LIGHT_SOFT, 1.8)
	var prism: Array[Vector2] = [
		center + _v(0, -8.0),
		center + _v(7.0, 0.0),
		center + _v(0, 8.0),
		center + _v(-7.0, 0.0),
	]
	_outline_poly(t, prism)
	_fill_poly(t, prism, Color(0.95, 0.88, 0.23, 0.92))
	_line(t, center + _v(-6.0, 0.0), center + _v(6.0, 0.0), BEAM_CORE, 1.65)
	_line(t, center + _v(0.0, -6.0), center + _v(0.0, 6.0), BEAM_EDGE, 1.3)
	_line(t, center + _v(-4.3, -4.3), center + _v(4.3, 4.3), EARTH_SOFT, 1.1)
	_line(t, center + _v(-4.3, 4.3), center + _v(4.3, -4.3), DARK_SOFT, 1.1)


static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float = 4.0) -> void:
	var bg: Array[Vector2] = [
		center + _v(-15.0, 6.0),
		center + _v(-12.0, -6.0),
		center + _v(0.0, -12.0),
		center + _v(12.0, -6.0),
		center + _v(15.0, 6.0),
		center + _v(0.0, 12.0),
	]
	_outline_poly(t, bg)
	_fill_poly(t, bg, Color(0.055, 0.062, 0.085, 0.97))
	_circle(t, center + _v(-7.5, -1.2), radius, LIGHT_COL)
	_circle(t, center + _v(0.0, 4.7), radius, DARK_COL)
	_circle(t, center + _v(7.5, -1.2), radius, EARTH_COL)


static func _draw_lock_marks(t: Node2D) -> void:
	# Precision-target UI marks, static only. They help Laser read as long-range single-target.
	_arc(t, _v(-6.0, 0.0), 23.0, -0.95, -0.25, LIGHT_SOFT, 1.25)
	_arc(t, _v(-6.0, 0.0), 23.0, 0.25, 0.92, LIGHT_SOFT, 1.25)
	_arc(t, _v(-6.0, 0.0), 23.0, 2.30, 3.05, DARK_SOFT, 1.25)
	_arc(t, _v(-6.0, 0.0), 23.0, -3.05, -2.30, DARK_SOFT, 1.25)


static func draw_contour(t: Node2D) -> void:
	# Catalog-safe fixed local pixels. Do not rotate/scale here; renderer/catalog handles rotation.
	_outline_poly(t, [
		_v(-30, -18), _v(-14, -28), _v(11, -26), _v(30, -15),
		_v(36, -6), _v(42, 0), _v(36, 6), _v(30, 15),
		_v(11, 26), _v(-14, 28), _v(-30, 18), _v(-36, 8), _v(-36, -8)
	])
	_outline_poly(t, [_v(-25, -16), _v(4, -28), _v(35, -13), _v(39, -5), _v(8, -12), _v(-22, -5)])
	_outline_poly(t, [_v(-25, 16), _v(4, 28), _v(35, 13), _v(39, 5), _v(8, 12), _v(-22, 5)])
	_outline_poly(t, [_v(-43, -9), _v(-20, -7), _v(35, -4), _v(43, 0), _v(35, 4), _v(-20, 7), _v(-43, 9)])
	_circle(t, _v(-8, 0), 15.5, OUTLINE)
	_circle(t, _v(16, -7), 7.2, OUTLINE)
	_circle(t, _v(16, 7), 7.2, OUTLINE)


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Main armored chassis, mirrored around the local X-axis for a production-clean silhouette.
	var chassis: Array[Vector2] = [
		_v(-29, -17), _v(-13, -27), _v(10, -25), _v(29, -14),
		_v(35, -6), _v(40, 0), _v(35, 6), _v(29, 14),
		_v(10, 25), _v(-13, 27), _v(-29, 17), _v(-35, 8), _v(-35, -8)
	]
	_outline_poly(t, chassis)
	_fill_poly(t, chassis, STEEL_DARK)

	# Mirrored earth stabilization armor: heavier but balanced, not a cannon barrel.
	var upper_side_plate: Array[Vector2] = [_v(-26, -15), _v(-12, -24), _v(5, -24), _v(1, -10), _v(-22, -5)]
	var lower_side_plate: Array[Vector2] = [_v(-26, 15), _v(-12, 24), _v(5, 24), _v(1, 10), _v(-22, 5)]
	var nose_plate: Array[Vector2] = [_v(18, -18), _v(31, -12), _v(36, -5), _v(36, 5), _v(31, 12), _v(18, 18), _v(13, 9), _v(13, -9)]
	_outline_poly(t, upper_side_plate)
	_fill_poly(t, upper_side_plate, EARTH_COL.darkened(0.14))
	_outline_poly(t, lower_side_plate)
	_fill_poly(t, lower_side_plate, EARTH_COL.darkened(0.14))
	_outline_poly(t, nose_plate)
	_fill_poly(t, nose_plate, EARTH_COL.darkened(0.20))

	# Prism + paired void focus chambers.
	_draw_prism_lens(t, _v(-8, 0))
	_circle(t, _v(10, -8), 5.2, DARK_SOFT)
	_circle(t, _v(10, 8), 5.2, DARK_SOFT)
	_circle(t, _v(18, -7), 4.5, EARTH_SOFT)
	_circle(t, _v(18, 7), 4.5, EARTH_SOFT)
	_circle(t, _v(2, 0), 4.4, LIGHT_SOFT)

	# Upper/lower rail assemblies are exact visual counterparts for symmetry.
	var upper_rail: Array[Vector2] = [_v(-24, -16), _v(4, -28), _v(34, -13), _v(38, -5), _v(8, -12), _v(-22, -5)]
	var lower_rail: Array[Vector2] = [_v(-24, 16), _v(4, 28), _v(34, 13), _v(38, 5), _v(8, 12), _v(-22, 5)]
	_outline_poly(t, upper_rail)
	_fill_poly(t, upper_rail, STEEL_MID)
	_outline_poly(t, lower_rail)
	_fill_poly(t, lower_rail, STEEL_MID)

	# Inset rail highlights and focus conduits, mirrored top/bottom.
	_polyline(t, [_v(-17, -10), _v(4, -18), _v(27, -9)], STEEL_LIGHT, 1.25)
	_polyline(t, [_v(-17, 10), _v(4, 18), _v(27, 9)], STEEL_LIGHT, 1.25)
	_line(t, _v(-2, -5), _v(29, -7), BEAM_EDGE, 1.55)
	_line(t, _v(-2, 5), _v(29, 7), BEAM_EDGE, 1.55)
	_line(t, _v(2, 0), _v(32, 0), BEAM_CORE, 1.65)

	# Focused beam wedge: centered and straight = precision single-target laser.
	var beam_shadow: Array[Vector2] = [_v(-44, -10), _v(-20, -7), _v(35, -4), _v(44, 0), _v(35, 4), _v(-20, 7), _v(-44, 10)]
	var beam: Array[Vector2] = [_v(-41, -8), _v(-19, -5), _v(33, -3), _v(41, 0), _v(33, 3), _v(-19, 5), _v(-41, 8)]
	var beam_inner: Array[Vector2] = [_v(-33, -5), _v(-17, -3), _v(25, -1.8), _v(32, 0), _v(25, 1.8), _v(-17, 3), _v(-33, 5)]
	_outline_poly(t, beam_shadow)
	_fill_poly(t, beam_shadow, Color(0.02, 0.01, 0.04, 0.72))
	_fill_poly(t, beam, BEAM_GHOST)
	_fill_poly(t, beam_inner, Color(1.0, 0.97, 0.29, 0.66))
	_line(t, _v(-39, 0), _v(39, 0), BEAM_CORE, 1.45)
	_line(t, _v(-30, -5), _v(31, -1.5), BEAM_EDGE, 0.95)
	_line(t, _v(-30, 5), _v(31, 1.5), BEAM_EDGE, 0.95)

	# Symmetric rail aperture / lens nose.
	var aperture: Array[Vector2] = [_v(25, -9), _v(39, 0), _v(25, 9), _v(17, 0)]
	_outline_poly(t, aperture)
	_fill_poly(t, aperture, STEEL_LIGHT)
	_circle(t, _v(27, 0), 3.8, BEAM_CORE)
	_ring(t, _v(27, 0), 6.2, DARK_SOFT, 1.05)

	# Charge ticks/capacitors along the beam path, mirrored for a cleaner catalog read.
	_circle(t, _v(-20, -15), 2.0, STEEL_LIGHT)
	_circle(t, _v(-20, 15), 2.0, STEEL_LIGHT)
	_circle(t, _v(15, -16), 2.0, EARTH_SOFT)
	_circle(t, _v(15, 16), 2.0, EARTH_SOFT)
	_line(t, _v(-34, -8), _v(-27, -6), LIGHT_SOFT, 1.0)
	_line(t, _v(-34, 8), _v(-27, 6), LIGHT_SOFT, 1.0)
	_line(t, _v(-23, -3), _v(-17, -1.5), BEAM_CORE, 1.0)
	_line(t, _v(-23, 3), _v(-17, 1.5), BEAM_CORE, 1.0)
	_line(t, _v(13, -8), _v(20, -6), BEAM_CORE, 1.0)
	_line(t, _v(13, 8), _v(20, 6), BEAM_CORE, 1.0)

	# Premium micro paneling, mirrored and static.
	_polyline(t, [_v(-19, -7), _v(-13, -11), _v(-6, -12)], Color(0.74, 0.80, 0.85, 0.78), 1.0)
	_polyline(t, [_v(-19, 7), _v(-13, 11), _v(-6, 12)], Color(0.74, 0.80, 0.85, 0.78), 1.0)
	_polyline(t, [_v(15, -7), _v(21, -5), _v(26, -4)], Color(0.92, 0.74, 0.42, 0.80), 1.0)
	_polyline(t, [_v(15, 7), _v(21, 5), _v(26, 4)], Color(0.92, 0.74, 0.42, 0.80), 1.0)

	_draw_lock_marks(t)
	_draw_tri_element_token(t, _v(0, 33), 3.3)
