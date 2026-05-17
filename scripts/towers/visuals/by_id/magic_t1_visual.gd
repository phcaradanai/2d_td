extends RefCounted

# Tower: Magic Tower 1
# Role: Arcane explosion — dark fire AoE splash that damages groups.
# Elements: darkness, fire
# Visual source: custom by_id visual
# Visual intent: chaos orb / arcane blast reactor; reads as splash AoE, not single-target sniper.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	t.draw_polyline(closed, color, width, true)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_element_dot(t: Node2D, center: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(center, radius + 1.8, DETAIL_OUTLINE)
	t.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.82))
	t.draw_circle(center, radius * 0.46, color.lightened(0.35))

static func _draw_dual_token(t: Node2D, center: Vector2, radius: float, dark_c: Color, fire_c: Color) -> void:
	var frame := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(frame, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, frame, -1.6), Color(0.018, 0.015, 0.026, 0.88))
	_draw_closed_polyline(t, TowerVisualDrawUtils._expand_poly_from_center(t, frame, -0.5), Color(0.86, 0.42, 1.0, 0.38), 0.9)

	_draw_element_dot(t, center + Vector2(-4.0, 0.0), radius * 0.28, dark_c)
	_draw_element_dot(t, center + Vector2(4.0, 0.0), radius * 0.28, fire_c)

static func _draw_chaos_rune(t: Node2D, center: Vector2, radius: float, dark_c: Color, fire_c: Color) -> void:
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.62, 8, 0.0)

	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, outer, -2.1), Color(0.025, 0.014, 0.032, 0.92))
	t.draw_colored_polygon(inner, Color(dark_c.r, dark_c.g, dark_c.b, 0.50))
	_draw_closed_polyline(t, outer, Color(fire_c.r, fire_c.g, fire_c.b, 0.58), 1.25)
	_draw_closed_polyline(t, inner, Color(dark_c.r, dark_c.g, dark_c.b, 0.74), 1.1)

	# Arcane explosion mark: crossing dark-fire diagonals.
	_draw_stroked_line(t, center + Vector2(-radius * 0.45, -radius * 0.45), center + Vector2(radius * 0.45, radius * 0.45), fire_c.lightened(0.18), 1.15)
	_draw_stroked_line(t, center + Vector2(radius * 0.45, -radius * 0.45), center + Vector2(-radius * 0.45, radius * 0.45), dark_c.lightened(0.12), 1.15)
	t.draw_circle(center, radius * 0.20, Color(1.0, 0.48, 0.10, 0.90))

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var body_radius := 17.0 + float(lvl) * 0.8

	# Compact chaos reactor silhouette: symmetric, orb-like, AoE-focused.
	_outline_circle(t, Vector2.ZERO, body_radius)
	_outline_circle(t, Vector2.ZERO, body_radius * 0.58)

	# Four amplifier pylons imply radial splash release.
	for p in [
		Vector2(-18, -13),
		Vector2(18, -13),
		Vector2(-18, 13),
		Vector2(18, 13),
	]:
		_outline_circle(t, p, 4.4)

	# Side stabilizers / dark-fire containment claws.
	var upper_claw := PackedVector2Array([
		Vector2(-20, -2),
		Vector2(-12, -18),
		Vector2(2, -14),
		Vector2(-4, -6),
	])
	var lower_claw := PackedVector2Array([
		Vector2(-20, 2),
		Vector2(-12, 18),
		Vector2(2, 14),
		Vector2(-4, 6),
	])
	var right_upper := PackedVector2Array([
		Vector2(20, -2),
		Vector2(12, -18),
		Vector2(-2, -14),
		Vector2(4, -6),
	])
	var right_lower := PackedVector2Array([
		Vector2(20, 2),
		Vector2(12, 18),
		Vector2(-2, 14),
		Vector2(4, 6),
	])
	_outline_poly(t, upper_claw)
	_outline_poly(t, lower_claw)
	_outline_poly(t, right_upper)
	_outline_poly(t, right_lower)

	# Static splash rings.
	_outline_circle(t, Vector2.ZERO, 23.0)
	_outline_line(t, Vector2(-24, 0), Vector2(-16, 0), 2.0)
	_outline_line(t, Vector2(16, 0), Vector2(24, 0), 2.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var dark_c := el_colors[1] if el_colors.size() > 1 else Color(0.55, 0.25, 1.0)
	var fire_c := el_colors[3] if el_colors.size() > 3 else Color(1.0, 0.28, 0.08)
	var body_radius := 17.0 + float(lvl) * 0.8

	# Low-cost static AoE language: dark-fire shock rings under the reactor.
	t.draw_arc(Vector2.ZERO, 25.0, deg_to_rad(18), deg_to_rad(162), 28, Color(fire_c.r, fire_c.g, fire_c.b, 0.20), 1.2, true)
	t.draw_arc(Vector2.ZERO, 25.0, deg_to_rad(198), deg_to_rad(342), 28, Color(dark_c.r, dark_c.g, dark_c.b, 0.22), 1.2, true)
	t.draw_arc(Vector2.ZERO, 20.5, deg_to_rad(35), deg_to_rad(325), 36, DETAIL_OUTLINE_SOFT, 1.0, true)
	t.draw_arc(Vector2.ZERO, 20.5, deg_to_rad(35), deg_to_rad(325), 36, Color(0.92, 0.32, 1.0, 0.18), 0.75, true)

	# Mirrored containment claws. They make the tower read as an unstable arcane reactor.
	var claw_sets := [
		[
			PackedVector2Array([Vector2(-20, -2), Vector2(-12, -18), Vector2(2, -14), Vector2(-4, -6)]),
			Color(dark_c.r, dark_c.g, dark_c.b, 0.54)
		],
		[
			PackedVector2Array([Vector2(-20, 2), Vector2(-12, 18), Vector2(2, 14), Vector2(-4, 6)]),
			Color(fire_c.r, fire_c.g, fire_c.b, 0.44)
		],
		[
			PackedVector2Array([Vector2(20, -2), Vector2(12, -18), Vector2(-2, -14), Vector2(4, -6)]),
			Color(fire_c.r, fire_c.g, fire_c.b, 0.48)
		],
		[
			PackedVector2Array([Vector2(20, 2), Vector2(12, 18), Vector2(-2, 14), Vector2(4, 6)]),
			Color(dark_c.r, dark_c.g, dark_c.b, 0.50)
		],
	]
	for item in claw_sets:
		var poly: PackedVector2Array = item[0]
		var fill: Color = item[1]
		t.draw_colored_polygon(poly, DETAIL_OUTLINE)
		t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, poly, -1.7), fill)
		_draw_stroked_polyline(t, poly, Color(1.0, 0.47, 0.12, 0.35), 0.8)

	# Four pylon nodes that imply the explosion is released in all directions.
	var pylon_points := [
		Vector2(-18, -13),
		Vector2(18, -13),
		Vector2(-18, 13),
		Vector2(18, 13),
	]
	for i in range(pylon_points.size()):
		var p : Vector2 = pylon_points[i]
		var c := fire_c if i % 2 == 0 else dark_c
		t.draw_circle(p, 6.3, Color(c.r, c.g, c.b, 0.10))
		_draw_stroked_circle(t, p, 4.2, Color(0.025, 0.018, 0.030, 0.94), 1.7)
		t.draw_circle(p, 2.2, Color(c.r, c.g, c.b, 0.78))

	# Main chaos orb / blast chamber.
	t.draw_circle(Vector2.ZERO, body_radius + 3.5, Color(fire_c.r, fire_c.g, fire_c.b, 0.08))
	_draw_stroked_circle(t, Vector2.ZERO, body_radius, Color(0.018, 0.012, 0.028, 0.94), 2.4)
	_draw_stroked_circle(t, Vector2.ZERO, body_radius * 0.64, Color(dark_c.r, dark_c.g, dark_c.b, 0.60), 1.8)
	t.draw_circle(Vector2.ZERO, body_radius * 0.44, Color(fire_c.r, fire_c.g, fire_c.b, 0.52))
	t.draw_circle(Vector2.ZERO, body_radius * 0.24, Color(1.0, 0.43, 0.05, 0.88))

	# Split dark-fire swirl inside the orb: static but communicates chaotic AoE magic.
	var swirl_a := PackedVector2Array([
		Vector2(-9, -2),
		Vector2(-4, -9),
		Vector2(7, -7),
		Vector2(10, -1),
		Vector2(2, 2),
	])
	var swirl_b := PackedVector2Array([
		Vector2(9, 2),
		Vector2(4, 9),
		Vector2(-7, 7),
		Vector2(-10, 1),
		Vector2(-2, -2),
	])
	t.draw_colored_polygon(swirl_a, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, swirl_a, -0.9), Color(fire_c.r, fire_c.g, fire_c.b, 0.62))
	t.draw_colored_polygon(swirl_b, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, swirl_b, -0.9), Color(dark_c.r, dark_c.g, dark_c.b, 0.66))

	# Arcane explosion rune over the core, kept small so it does not become noisy.
	_draw_chaos_rune(t, Vector2.ZERO, 8.2, dark_c, fire_c)

	# Cross-links from core to pylons.
	for p in pylon_points:
		_draw_stroked_line(t, Vector2.ZERO, p * 0.70, Color(0.96, 0.36, 1.0, 0.34), 0.85, true)

	# Dual Darkness + Fire token: smaller than the main orb so the role stays readable.
	_draw_dual_token(t, Vector2(0, 20.5), 7.0, dark_c, fire_c)
