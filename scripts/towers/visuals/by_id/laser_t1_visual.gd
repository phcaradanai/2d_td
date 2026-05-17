extends RefCounted

# Tower: Laser Tower 1
# Role: Focused beam / precision single-target rail laser
# Elements: light, darkness, earth
# Visual source: custom by_id visual
# Visual intent: compact rail-laser emitter with prism lens, void capacitor, and earth armor rails.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

const LIGHT_COL := Color(1.0, 0.93, 0.18, 1.0)
const LIGHT_SOFT := Color(1.0, 0.98, 0.48, 0.88)
const DARK_COL := Color(0.37, 0.22, 0.56, 1.0)
const DARK_SOFT := Color(0.62, 0.40, 0.86, 0.86)
const EARTH_COL := Color(0.58, 0.38, 0.18, 1.0)
const EARTH_SOFT := Color(0.82, 0.59, 0.31, 0.88)

const METAL_DARK := Color(0.10, 0.13, 0.17, 1.0)
const METAL_MID := Color(0.23, 0.27, 0.31, 1.0)
const METAL_LIGHT := Color(0.48, 0.53, 0.57, 1.0)
const BEAM_CORE := Color(1.0, 0.96, 0.18, 1.0)
const BEAM_EDGE := Color(0.78, 0.53, 1.0, 0.92)


static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y)


static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p)
	return out


static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	t.draw_colored_polygon(points, OUTLINE)


static func _fill_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	t.draw_colored_polygon(points, color)


static func _line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(a, b, OUTLINE, width + 2.4, true)
	t.draw_line(a, b, color, width, true)


static func _polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed: bool = false) -> void:
	var path := PackedVector2Array()
	for p: Vector2 in points:
		path.append(p)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, width + 2.4, true)
	t.draw_polyline(path, color, width, true)


static func _circle(t: Node2D, p: Vector2, r: float, color: Color) -> void:
	t.draw_circle(p, r + 1.7, OUTLINE)
	t.draw_circle(p, r, color)


static func _ring(t: Node2D, p: Vector2, r: float, color: Color, width: float) -> void:
	t.draw_arc(p, r, 0.0, TAU, 32, OUTLINE, width + 2.2, true)
	t.draw_arc(p, r, 0.0, TAU, 32, color, width, true)


static func _arc(t: Node2D, p: Vector2, r: float, a0: float, a1: float, color: Color, width: float) -> void:
	t.draw_arc(p, r, a0, a1, 24, OUTLINE_SOFT, width + 2.0, true)
	t.draw_arc(p, r, a0, a1, 24, color, width, true)


static func _draw_tri_token(t: Node2D, center: Vector2) -> void:
	var token_bg := _poly([
		center + _v(-14, 6), center + _v(-11, -6), center + _v(0, -11),
		center + _v(11, -6), center + _v(14, 6), center + _v(0, 12)
	])
	_outline_poly(t, token_bg)
	_fill_poly(t, token_bg, Color(0.06, 0.07, 0.10, 0.96))

	_circle(t, center + _v(-7, -1), 3.1, LIGHT_COL)
	_circle(t, center + _v(0, 4), 3.1, DARK_COL)
	_circle(t, center + _v(7, -1), 3.1, EARTH_COL)


static func _draw_lens_glyph(t: Node2D, center: Vector2) -> void:
	_ring(t, center, 8.5, LIGHT_SOFT, 1.8)
	_line(t, center + _v(-6.5, 0), center + _v(6.5, 0), BEAM_CORE, 2.1)
	_line(t, center + _v(0, -6.5), center + _v(0, 6.5), BEAM_EDGE, 1.5)
	_line(t, center + _v(-4.7, -4.7), center + _v(4.7, 4.7), EARTH_SOFT, 1.25)
	_line(t, center + _v(-4.7, 4.7), center + _v(4.7, -4.7), DARK_SOFT, 1.25)


static func draw_contour(t: Node2D) -> void:
	# Compact catalog-safe silhouette. Coordinates are fixed local pixels; do not multiply by renderer `size`.
	var body := _poly([
		_v(-26, 12), _v(-22, -11), _v(-6, -23), _v(13, -20),
		_v(27, -5), _v(25, 14), _v(10, 24), _v(-12, 24)
	])
	_outline_poly(t, body)

	var upper_rail := _poly([_v(-18, -10), _v(2, -21), _v(30, -8), _v(24, -2), _v(0, -11), _v(-16, -3)])
	_outline_poly(t, upper_rail)

	var lower_rail := _poly([_v(-15, 5), _v(0, 14), _v(26, 8), _v(31, 14), _v(1, 24), _v(-18, 12)])
	_outline_poly(t, lower_rail)

	var beam := _poly([_v(-32, -20), _v(-11, -13), _v(32, 18), _v(24, 25), _v(-18, -5), _v(-36, -10)])
	_outline_poly(t, beam)

	_circle(t, _v(-8, 0), 14.0, OUTLINE)
	_circle(t, _v(15, 0), 7.0, OUTLINE)


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Fixed scale keeps catalog preview consistent with other tower by_id visuals.
	var base := _poly([
		_v(-24, 13), _v(-20, -9), _v(-5, -20), _v(12, -18),
		_v(25, -4), _v(23, 13), _v(9, 22), _v(-11, 22)
	])
	_outline_poly(t, base)
	_fill_poly(t, base, METAL_DARK)

	var earth_plate_l := _poly([_v(-25, 9), _v(-20, -8), _v(-11, -13), _v(-10, 17), _v(-19, 20)])
	var earth_plate_r := _poly([_v(13, -17), _v(24, -5), _v(22, 12), _v(13, 18), _v(11, -10)])
	_outline_poly(t, earth_plate_l)
	_fill_poly(t, earth_plate_l, EARTH_COL.darkened(0.10))
	_outline_poly(t, earth_plate_r)
	_fill_poly(t, earth_plate_r, EARTH_COL.darkened(0.18))

	# Prism lens chamber.
	_circle(t, _v(-7, 0), 13.0, DARK_COL.darkened(0.08))
	_circle(t, _v(-7, 0), 9.0, Color(0.11, 0.09, 0.16, 1.0))
	_draw_lens_glyph(t, _v(-7, 0))

	# Twin rail body: reads as a precision rail laser, not cannon/mortar.
	var upper_rail := _poly([_v(-18, -10), _v(0, -19), _v(28, -7), _v(22, -1), _v(1, -10), _v(-16, -3)])
	var lower_rail := _poly([_v(-16, 5), _v(1, 13), _v(25, 7), _v(30, 13), _v(2, 22), _v(-17, 12)])
	_outline_poly(t, upper_rail)
	_fill_poly(t, upper_rail, METAL_MID)
	_outline_poly(t, lower_rail)
	_fill_poly(t, lower_rail, METAL_MID.darkened(0.04))

	# Focused beam wedge between rails.
	var beam := _poly([_v(-31, -18), _v(-11, -12), _v(30, 17), _v(23, 23), _v(-18, -4), _v(-35, -9)])
	_outline_poly(t, beam)
	_fill_poly(t, beam, Color(0.97, 0.90, 0.10, 0.94))
	var beam_inner := _poly([_v(-24, -12), _v(-11, -8), _v(21, 14), _v(17, 18), _v(-16, -2), _v(-29, -5)])
	_fill_poly(t, beam_inner, Color(1.0, 0.97, 0.28, 0.78))

	# Void capacitor and earth stabilizer.
	_circle(t, _v(8, -2), 5.2, DARK_SOFT)
	_circle(t, _v(17, 5), 4.3, EARTH_SOFT)
	_circle(t, _v(0, 7), 3.8, LIGHT_SOFT)
	_line(t, _v(-2, -2), _v(24, -7), BEAM_EDGE, 1.7)
	_line(t, _v(-1, 5), _v(25, 9), BEAM_CORE, 1.7)

	# Beam target aperture at the rail end.
	var nose := _poly([_v(23, -4), _v(33, 3), _v(24, 10), _v(17, 4)])
	_outline_poly(t, nose)
	_fill_poly(t, nose, METAL_LIGHT)
	_circle(t, _v(24, 3), 3.1, BEAM_CORE)

	# Static piercing indicators: tiny line fragments along beam path.
	_line(t, _v(-32, -14), _v(-26, -12), LIGHT_SOFT, 1.1)
	_line(t, _v(-23, -7), _v(-17, -4), BEAM_CORE, 1.1)
	_line(t, _v(10, 9), _v(16, 13), BEAM_CORE, 1.1)

	# Subtle lock-on arcs, not aura.
	_arc(t, _v(-7, 0), 19.0, -0.76, 0.20, LIGHT_SOFT, 1.25)
	_arc(t, _v(-7, 0), 19.0, 2.95, 3.85, DARK_SOFT, 1.25)

	# Small panel bolts/details.
	_circle(t, _v(-19, 12), 2.1, METAL_LIGHT)
	_circle(t, _v(15, -12), 2.1, METAL_LIGHT)
	_circle(t, _v(14, 15), 2.0, EARTH_SOFT)
	_polyline(t, [_v(-19, -7), _v(-13, -11), _v(-7, -13)], Color(0.72, 0.77, 0.80, 0.78), 1.15)
	_polyline(t, [_v(-13, 17), _v(-4, 19), _v(5, 18)], Color(0.72, 0.77, 0.80, 0.72), 1.15)

	_draw_tri_token(t, _v(0, 31))
