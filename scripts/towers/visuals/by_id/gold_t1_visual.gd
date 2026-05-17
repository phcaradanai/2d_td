extends RefCounted

# Tower: Gold Tower 1
# Role: Economy single-target — bonus bounty on kills
# Elements: Light + Fire + Earth
# Visual source: custom by_id visual
# Visual intent: premium gold refinery / mint-lens cannon, readable as economy tower but still a single-target attacker.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const GOLD_MAIN := Color(1.0, 0.73, 0.18, 1.0)
const GOLD_LIGHT := Color(1.0, 0.93, 0.40, 1.0)
const GOLD_DEEP := Color(0.76, 0.39, 0.06, 1.0)
const MOLTEN := Color(1.0, 0.34, 0.08, 1.0)
const LIGHT_CORE := Color(1.0, 0.98, 0.66, 1.0)
const EARTH_PLATE := Color(0.42, 0.33, 0.22, 1.0)
const SHADOW_GOLD := Color(0.30, 0.20, 0.06, 1.0)

static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * VISUAL_SCALE

static func _r(value: float) -> float:
	return value * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
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

static func _outline_poly(t: Node2D, points: PackedVector2Array, color: Color = OUTLINE) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)
	t.draw_colored_polygon(points, color)

static func _fill_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)
	t.draw_colored_polygon(points, color)

static func _stroked_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, a * VISUAL_SCALE, b * VISUAL_SCALE, width * VISUAL_SCALE + 2.0)
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, color, width * VISUAL_SCALE, true)

static func _stroked_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float = 2.0, closed: bool = false) -> void:
	var path := PackedVector2Array()
	for p: Vector2 in points:
		path.append(p * VISUAL_SCALE)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, width * VISUAL_SCALE + 2.2, true)
	t.draw_polyline(path, color, width * VISUAL_SCALE, true)

static func _circle(t: Node2D, center: Vector2, radius: float, color: Color, outline_width: float = 2.0) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center * VISUAL_SCALE, radius * VISUAL_SCALE)
	t.draw_circle(center * VISUAL_SCALE, radius * VISUAL_SCALE, color)

static func _ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 48, OUTLINE, width * VISUAL_SCALE + 2.2, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 48, color, width * VISUAL_SCALE, true)

static func _arc(t: Node2D, center: Vector2, radius: float, from_a: float, to_a: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_a, to_a, 24, OUTLINE, width * VISUAL_SCALE + 2.0, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_a, to_a, 24, color, width * VISUAL_SCALE, true)

static func _draw_coin(t: Node2D, center: Vector2, radius: float) -> void:
	_circle(t, center, radius + 1.4, OUTLINE_SOFT, 1.0)
	_circle(t, center, radius, GOLD_MAIN, 1.3)
	_ring(t, center, radius * 0.68, GOLD_LIGHT, 1.2)
	_stroked_line(t, center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), SHADOW_GOLD, 1.4)
	_stroked_line(t, center + Vector2(-radius * 0.28, -radius * 0.25), center + Vector2(radius * 0.28, -radius * 0.25), SHADOW_GOLD, 1.1)
	_stroked_line(t, center + Vector2(-radius * 0.30, radius * 0.23), center + Vector2(radius * 0.30, radius * 0.23), SHADOW_GOLD, 1.1)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float, el_colors: Array[Color]) -> void:
	var light_col := Color(1.0, 0.96, 0.58, 1.0)
	var fire_col := Color(1.0, 0.28, 0.08, 1.0)
	var earth_col := Color(0.62, 0.46, 0.24, 1.0)
	if el_colors.size() >= 3:
		light_col = el_colors[0]
		fire_col = el_colors[1]
		earth_col = el_colors[2]

	_circle(t, center, radius + 2.4, OUTLINE_SOFT, 1.0)
	var c := center * VISUAL_SCALE
	var rr := radius * VISUAL_SCALE
	var p1 := c + Vector2(0.0, -rr)
	var p2 := c + Vector2(-rr * 0.86, rr * 0.50)
	var p3 := c + Vector2(rr * 0.86, rr * 0.50)
	t.draw_colored_polygon(PackedVector2Array([c, p1, p2]), light_col)
	t.draw_colored_polygon(PackedVector2Array([c, p2, p3]), earth_col)
	t.draw_colored_polygon(PackedVector2Array([c, p3, p1]), fire_col)
	t.draw_arc(c, rr, 0.0, TAU, 24, OUTLINE, 1.2 * VISUAL_SCALE, true)

static func draw_contour(t: Node2D) -> void:
	# Compact outline only; the catalog/renderer handles rotation.
	t.draw_circle(Vector2.ZERO, _r(40.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _r(31.0), OUTLINE)
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.ZERO, 25.0, 8, PI / 8.0))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Static premium economy silhouette: refinery body + mint lens + single-target emitter.

	# Outer value-field rings: communicates economy without being an aura gameplay visual.
	_arc(t, Vector2.ZERO, 34.0, deg_to_rad(18), deg_to_rad(116), Color(1.0, 0.82, 0.24, 0.62), 1.4)
	_arc(t, Vector2.ZERO, 34.0, deg_to_rad(198), deg_to_rad(296), Color(1.0, 0.82, 0.24, 0.50), 1.4)
	_arc(t, Vector2.ZERO, 27.5, deg_to_rad(128), deg_to_rad(174), Color(1.0, 0.95, 0.55, 0.55), 1.1)
	_arc(t, Vector2.ZERO, 27.5, deg_to_rad(306), deg_to_rad(352), Color(1.0, 0.95, 0.55, 0.55), 1.1)

	# Earth-heavy premium base.
	var base := _regular_poly(Vector2.ZERO, 25.0, 8, PI / 8.0)
	_fill_poly(t, base, EARTH_PLATE)
	var inner_base := _regular_poly(Vector2.ZERO, 20.0, 8, PI / 8.0)
	_fill_poly(t, inner_base, Color(0.24, 0.20, 0.15, 1.0))

	# Gold refinery plates.
	var left_plate := _poly([
		Vector2(-24, -10), Vector2(-15, -18), Vector2(-7, -13), Vector2(-10, 9), Vector2(-20, 14), Vector2(-27, 5)
	])
	var right_plate := _poly([
		Vector2(24, -10), Vector2(15, -18), Vector2(7, -13), Vector2(10, 9), Vector2(20, 14), Vector2(27, 5)
	])
	_fill_poly(t, left_plate, GOLD_DEEP)
	_fill_poly(t, right_plate, GOLD_DEEP)
	_stroked_line(t, Vector2(-19, -9), Vector2(-13, 7), GOLD_LIGHT, 1.5)
	_stroked_line(t, Vector2(19, -9), Vector2(13, 7), GOLD_LIGHT, 1.5)

	# Central vault/mint core.
	_circle(t, Vector2.ZERO, 17.0, GOLD_MAIN, 2.0)
	_circle(t, Vector2.ZERO, 12.5, GOLD_DEEP, 1.5)
	_circle(t, Vector2.ZERO, 8.4, LIGHT_CORE, 1.2)
	_ring(t, Vector2.ZERO, 15.3, Color(1.0, 0.88, 0.28, 0.92), 1.4)

	# Coin glyph and bounty indicator in the core.
	_stroked_line(t, Vector2(0, -7.0), Vector2(0, 7.0), SHADOW_GOLD, 1.7)
	_stroked_line(t, Vector2(-4.1, -3.6), Vector2(4.1, -3.6), SHADOW_GOLD, 1.2)
	_stroked_line(t, Vector2(-4.1, 3.6), Vector2(4.1, 3.6), SHADOW_GOLD, 1.2)
	_circle(t, Vector2(9.5, -9.5), 2.3, MOLTEN, 0.8)
	_circle(t, Vector2(-9.5, 9.5), 2.3, Color(1.0, 0.93, 0.46, 1.0), 0.8)

	# Single-target emitter: small premium lens, not a cannon.
	var emitter_back := _poly([
		Vector2(14.0, -7.4), Vector2(30.0, -5.4), Vector2(34.5, 0.0), Vector2(30.0, 5.4), Vector2(14.0, 7.4)
	])
	_fill_poly(t, emitter_back, GOLD_DEEP)
	var emitter_tip := _poly([
		Vector2(27.5, -4.0), Vector2(38.0, 0.0), Vector2(27.5, 4.0), Vector2(30.5, 0.0)
	])
	_fill_poly(t, emitter_tip, LIGHT_CORE)
	_stroked_line(t, Vector2(18.0, -3.6), Vector2(31.0, -1.2), Color(1.0, 0.88, 0.35, 0.92), 1.2)
	_stroked_line(t, Vector2(18.0, 3.6), Vector2(31.0, 1.2), Color(1.0, 0.88, 0.35, 0.92), 1.2)

	# Refinery smoke/heat-fin accents, kept static and clean.
	var top_crown := _poly([
		Vector2(-10, -19), Vector2(-4, -27), Vector2(3, -27), Vector2(10, -19), Vector2(6, -14), Vector2(-6, -14)
	])
	_fill_poly(t, top_crown, Color(0.62, 0.43, 0.12, 1.0))
	_circle(t, Vector2(0, -21.5), 4.2, MOLTEN, 1.0)
	_stroked_line(t, Vector2(-6.5, -24.5), Vector2(-2.0, -30.0), Color(1.0, 0.66, 0.18, 0.55), 1.0)
	_stroked_line(t, Vector2(6.5, -24.5), Vector2(2.0, -30.0), Color(1.0, 0.66, 0.18, 0.45), 1.0)

	# Bonus bounty coins around the base.
	_draw_coin(t, Vector2(-25.5, 20.5), 4.6)
	_draw_coin(t, Vector2(22.0, 22.5), 4.0)
	_draw_coin(t, Vector2(-29.0, -18.5), 3.6)
	_draw_coin(t, Vector2(24.5, -20.0), 3.4)

	# Premium circuit/gold flow accents.
	_stroked_polyline(t, [Vector2(-18, 14), Vector2(-10, 21), Vector2(0, 23), Vector2(10, 21), Vector2(18, 14)], Color(1.0, 0.76, 0.22, 0.74), 1.35, false)
	_stroked_polyline(t, [Vector2(-18, -14), Vector2(-10, -21), Vector2(0, -23), Vector2(10, -21), Vector2(18, -14)], Color(1.0, 0.92, 0.45, 0.62), 1.15, false)

	# Tri-element badge: Light + Fire + Earth.
	_draw_tri_element_token(t, Vector2(0, 31.0), 5.2, el_colors)
