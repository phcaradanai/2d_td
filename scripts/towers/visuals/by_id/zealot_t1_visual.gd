extends RefCounted
class_name TowerVisualZealotT1

# Tower: Zealot Tower 1
# Role: Templar assault — rapid sacred single-target strikes
# Elements: Water + Fire + Earth
# Visual source: custom by_id visual
# Visual intent: Premium strike-blades / templar assault engine. Fast blade identity, not splash/aura.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.58)

const WATER := Color(0.18, 0.78, 1.0, 0.96)
const FIRE := Color(1.0, 0.38, 0.08, 0.96)
const EARTH := Color(0.58, 0.42, 0.24, 0.96)
const STEEL := Color(0.74, 0.82, 0.88, 1.0)
const HOLY_GOLD := Color(1.0, 0.78, 0.22, 0.96)
const CORE := Color(1.0, 0.94, 0.58, 1.0)


static func _s(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE


static func _r(value: float) -> float:
	return value * VISUAL_SCALE


static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_s(p))
	return out


static func _draw_poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), color)


static func _expand(points: Array[Vector2], amount: float) -> Array[Vector2]:
	var center := Vector2.ZERO
	for p: Vector2 in points:
		center += p
	if points.size() > 0:
		center /= float(points.size())

	var out: Array[Vector2] = []
	for p: Vector2 in points:
		out.append(center + (p - center) * amount)
	return out


static func _draw_poly_outline(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), OUTLINE)
	t.draw_colored_polygon(_poly(_expand(points, 0.86)), color)


static func _line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(_s(a), _s(b), OUTLINE, _r(width + 2.0), true)
	t.draw_line(_s(a), _s(b), color, _r(width), true)


static func _circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(_s(pos), _r(radius + 1.8), OUTLINE)
	t.draw_circle(_s(pos), _r(radius), color)


static func _ring(t: Node2D, pos: Vector2, radius: float, color: Color, width: float) -> void:
	t.draw_arc(_s(pos), _r(radius), 0.0, TAU, 42, OUTLINE, _r(width + 2.0), true)
	t.draw_arc(_s(pos), _r(radius), 0.0, TAU, 42, color, _r(width), true)


static func _arc(t: Node2D, pos: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void:
	t.draw_arc(_s(pos), _r(radius), start, end, 24, OUTLINE, _r(width + 2.0), true)
	t.draw_arc(_s(pos), _r(radius), start, end, 24, color, _r(width), true)


static func _draw_blade(t: Node2D, angle: float, tint: Color) -> void:
	var axis := Vector2(cos(angle), sin(angle))
	var side := Vector2(-axis.y, axis.x)

	var tip := axis * 29.0
	var base := -axis * 9.0
	var blade: Array[Vector2] = [
		tip,
		axis * 16.0 + side * 4.8,
		base + side * 3.2,
		base - side * 3.2,
		axis * 16.0 - side * 4.8,
	]
	_draw_poly_outline(t, blade, tint)

	var ridge_a := axis * 21.0
	var ridge_b := axis * 1.0
	_line(t, ridge_a, ridge_b, Color(1.0, 1.0, 1.0, 0.38), 1.1)

	var guard: Array[Vector2] = [
		base + side * 8.2 + axis * 1.0,
		base + side * 8.2 - axis * 2.0,
		base - side * 8.2 - axis * 2.0,
		base - side * 8.2 + axis * 1.0,
	]
	_draw_poly_outline(t, guard, HOLY_GOLD.darkened(0.05))

	var grip: Array[Vector2] = [
		base - axis * 1.0 + side * 2.4,
		base - axis * 12.0 + side * 2.0,
		base - axis * 12.0 - side * 2.0,
		base - axis * 1.0 - side * 2.4,
	]
	_draw_poly_outline(t, grip, EARTH.darkened(0.25))


static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	_circle(t, center, radius + 1.8, Color(0.08, 0.10, 0.12, 0.90))

	var top: Array[Vector2] = [
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.84, radius * 0.48),
		center + Vector2(0, 0),
		center + Vector2(-radius * 0.84, radius * 0.48),
	]
	_draw_poly(t, top, FIRE)

	var left: Array[Vector2] = [
		center + Vector2(-radius * 0.84, radius * 0.48),
		center + Vector2(0, 0),
		center + Vector2(0, radius),
	]
	_draw_poly(t, left, WATER)

	var right: Array[Vector2] = [
		center + Vector2(radius * 0.84, radius * 0.48),
		center + Vector2(0, radius),
		center + Vector2(0, 0),
	]
	_draw_poly(t, right, EARTH)

	t.draw_arc(_s(center), _r(radius), 0.0, TAU, 28, OUTLINE, _r(1.2), true)


static func _draw_speed_marks(t: Node2D) -> void:
	var mark_a: Array[Vector2] = [Vector2(-35, -15), Vector2(-25, -12), Vector2(-30, -7)]
	var mark_b: Array[Vector2] = [Vector2(35, -15), Vector2(25, -12), Vector2(30, -7)]
	var mark_c: Array[Vector2] = [Vector2(-33, 16), Vector2(-23, 12), Vector2(-27, 20)]
	var mark_d: Array[Vector2] = [Vector2(33, 16), Vector2(23, 12), Vector2(27, 20)]
	_draw_poly_outline(t, mark_a, Color(1.0, 0.72, 0.20, 0.88))
	_draw_poly_outline(t, mark_b, Color(1.0, 0.72, 0.20, 0.88))
	_draw_poly_outline(t, mark_c, Color(1.0, 0.72, 0.20, 0.88))
	_draw_poly_outline(t, mark_d, Color(1.0, 0.72, 0.20, 0.88))


static func draw_contour(t: Node2D) -> void:
	# Compact contour. No transform/rotation here; renderer/catalog owns rotation.
	t.draw_circle(Vector2.ZERO, _r(36.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _r(25.0), OUTLINE)

	# Blade silhouettes.
	_draw_blade(t, -PI / 5.6, OUTLINE)
	_draw_blade(t, PI + PI / 5.6, OUTLINE)
	_draw_blade(t, PI / 2.0, OUTLINE)

	# Base and token silhouette.
	t.draw_circle(_s(Vector2(0, 4)), _r(15.0), OUTLINE)
	t.draw_circle(_s(Vector2(0, 30)), _r(8.0), OUTLINE)


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Passive assault field — reads rapid strikes, not AoE gameplay.
	_arc(t, Vector2.ZERO, 35.0, -2.75, -1.62, WATER, 1.7)
	_arc(t, Vector2.ZERO, 35.0, -0.92, 0.18, FIRE, 1.7)
	_arc(t, Vector2.ZERO, 35.0, 1.05, 2.25, EARTH.lightened(0.12), 1.7)
	_draw_speed_marks(t)

	# Earth-templar base.
	_draw_poly_outline(t, [
		Vector2(-19, 17),
		Vector2(-14, 4),
		Vector2(0, -1),
		Vector2(14, 4),
		Vector2(19, 17),
		Vector2(11, 25),
		Vector2(-11, 25),
	], EARTH.darkened(0.10))

	_draw_poly_outline(t, [
		Vector2(-13, 12),
		Vector2(-8, 3),
		Vector2(8, 3),
		Vector2(13, 12),
		Vector2(8, 18),
		Vector2(-8, 18),
	], Color(0.22, 0.18, 0.16, 1.0))

	# Three strike blades: water / fire / earth-backed holy metal.
	_draw_blade(t, -PI / 5.6, WATER.lightened(0.18))
	_draw_blade(t, PI + PI / 5.6, FIRE.lightened(0.12))
	_draw_blade(t, PI / 2.0, STEEL.lightened(0.08))

	# Central templar reactor.
	_circle(t, Vector2(0, 3), 13.2, Color(0.16, 0.18, 0.20, 1.0))
	_ring(t, Vector2(0, 3), 10.0, HOLY_GOLD, 2.2)
	_circle(t, Vector2(0, 3), 5.6, CORE)

	# Cross-shaped zeal glyph.
	_line(t, Vector2(-7, 3), Vector2(7, 3), Color(1.0, 0.88, 0.38, 0.96), 1.8)
	_line(t, Vector2(0, -4), Vector2(0, 10), Color(1.0, 0.88, 0.38, 0.96), 1.8)

	# Small element conduits feeding the blades.
	_circle(t, Vector2(-17, -7), 3.2, WATER)
	_circle(t, Vector2(17, -7), 3.2, FIRE)
	_circle(t, Vector2(0, 19), 3.2, EARTH.lightened(0.12))
	_line(t, Vector2(-14, -5), Vector2(-4, 0), WATER, 1.2)
	_line(t, Vector2(14, -5), Vector2(4, 0), FIRE, 1.2)
	_line(t, Vector2(0, 16), Vector2(0, 8), EARTH.lightened(0.20), 1.2)

	# Tri-element identity token.
	_draw_tri_element_token(t, Vector2(0, 31), 5.4)
