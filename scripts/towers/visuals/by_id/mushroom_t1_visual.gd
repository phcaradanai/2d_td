extends RefCounted

# Tower: Mushroom Tower 1
# Role: Spore volley — rapid fungal splash projectiles
# Elements: Nature + Earth
# Visual source: custom by_id visual
# Visual intent: spore-cap launcher / fungal mortar, readable as land-only splash without looking like a metal cannon.
# Performance note: CanvasItem draw calls only; no particles, nodes, timers, or gameplay logic.

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _scaled_poly(points: PackedVector2Array, scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * scale)
	return out


static func draw_contour(t: Node2D) -> void:
	var s := 0.2

	# Ground/root footprint.
	_outline_circle(t, Vector2(0, 14) * s, 27 * s)
	_outline_arc(t, Vector2(0, 14) * s, 31 * s, deg_to_rad(198), deg_to_rad(342), 3.6 * s)

	# Mushroom cap silhouette.
	var cap := _scaled_poly(PackedVector2Array([
		Vector2(-35, -8), Vector2(-27, -26), Vector2(-11, -37),
		Vector2(10, -38), Vector2(28, -27), Vector2(38, -9),
		Vector2(29, 3), Vector2(9, 8), Vector2(-10, 8), Vector2(-28, 3)
	]), s)
	_outline_poly(t, cap)

	# Thick organic trunk / launcher body.
	var trunk := _scaled_poly(PackedVector2Array([
		Vector2(-15, 6), Vector2(-10, -8), Vector2(10, -8),
		Vector2(16, 6), Vector2(12, 30), Vector2(-12, 30)
	]), s)
	_outline_poly(t, trunk)

	# Forward spore nozzle and seed pods.
	_outline_poly(t, _scaled_poly(PackedVector2Array([Vector2(19, -4), Vector2(38, -10), Vector2(41, 3), Vector2(23, 8)]), s))
	for p in [Vector2(-24, -13), Vector2(-7, -23), Vector2(12, -24), Vector2(27, -13)]:
		_outline_circle(t, p * s, 4.4 * s)

	# Earth-root stabilizers.
	_draw_stroked_line(t, Vector2(-22, 16) * s, Vector2(-39, 24) * s, Color(0.45, 0.28, 0.13, 0.84), 3.0 * s)
	_draw_stroked_line(t, Vector2(22, 16) * s, Vector2(39, 24) * s, Color(0.45, 0.28, 0.13, 0.84), 3.0 * s)


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	var s : float= max(size / 54.0, 0.62)

	var nature := Color(0.28, 0.95, 0.48, 1.0)
	var earth := Color(0.78, 0.55, 0.28, 1.0)
	if el_colors.size() > 0:
		nature = el_colors[0]
	if el_colors.size() > 1:
		earth = el_colors[1]

	var cap_dark := Color(0.20, 0.46, 0.25, 1.0).lerp(nature, 0.16)
	var cap_mid := Color(0.38, 0.78, 0.35, 1.0).lerp(nature, 0.25)
	var cap_light := Color(0.72, 1.0, 0.55, 1.0)
	var trunk := Color(0.54, 0.39, 0.20, 1.0).lerp(earth, 0.28)
	var gill := Color(0.90, 0.78, 0.43, 0.95)
	var spore := Color(0.72, 1.0, 0.54, 0.88)

	# Soft splash radius language, static and cheap.
	_draw_stroked_arc(t, Vector2(0, 12) * s, 33 * s, deg_to_rad(202), deg_to_rad(338), Color(0.44, 1.0, 0.48, 0.20), 2.0 * s)
	_draw_stroked_arc(t, Vector2(0, 13) * s, 24 * s, deg_to_rad(214), deg_to_rad(326), Color(0.82, 0.58, 0.30, 0.22), 1.7 * s)

	# Rooted base.
	_draw_stroked_circle(t, Vector2(0, 16) * s, 27 * s, Color(0.12, 0.20, 0.12, 0.72), 3.0 * s, false)
	_draw_stroked_line(t, Vector2(-14, 20) * s, Vector2(-39, 27) * s, trunk.darkened(0.08), 3.0 * s)
	_draw_stroked_line(t, Vector2(15, 20) * s, Vector2(39, 27) * s, trunk.darkened(0.08), 3.0 * s)
	_draw_stroked_line(t, Vector2(-5, 25) * s, Vector2(-22, 36) * s, nature.darkened(0.25), 2.2 * s)
	_draw_stroked_line(t, Vector2(6, 25) * s, Vector2(22, 36) * s, nature.darkened(0.25), 2.2 * s)

	# Organic trunk.
	var trunk_poly := _scaled_poly(PackedVector2Array([
		Vector2(-15, 6), Vector2(-10, -10), Vector2(10, -10),
		Vector2(16, 6), Vector2(12, 31), Vector2(-12, 31)
	]), s)
	_outline_poly(t, trunk_poly)
	t.draw_colored_polygon(trunk_poly, trunk)
	_draw_stroked_line(t, Vector2(-5, -6) * s, Vector2(-8, 27) * s, earth.lightened(0.20), 1.7 * s)
	_draw_stroked_line(t, Vector2(7, -6) * s, Vector2(8, 25) * s, Color(0.24, 0.60, 0.30, 0.85), 1.7 * s)

	# Forward fungal spore launcher: organic tube, not a cannon.
	var nozzle := _scaled_poly(PackedVector2Array([Vector2(15, -4), Vector2(38, -12), Vector2(43, 1), Vector2(22, 9)]), s)
	_outline_poly(t, nozzle)
	t.draw_colored_polygon(nozzle, Color(0.42, 0.68, 0.33, 1.0))
	_draw_stroked_circle(t, Vector2(39, -5) * s, 6.0 * s, Color(0.68, 1.0, 0.46, 0.92), 2.0 * s, false)
	_draw_stroked_circle(t, Vector2(39, -5) * s, 2.3 * s, Color(0.16, 0.28, 0.14, 1.0), 1.2 * s, true)

	# Mushroom cap.
	var cap := _scaled_poly(PackedVector2Array([
		Vector2(-36, -8), Vector2(-28, -27), Vector2(-12, -39),
		Vector2(9, -40), Vector2(28, -29), Vector2(39, -9),
		Vector2(30, 4), Vector2(10, 9), Vector2(-10, 9), Vector2(-29, 4)
	]), s)
	_outline_poly(t, cap)
	t.draw_colored_polygon(cap, cap_dark)

	var cap_inner := _scaled_poly(PackedVector2Array([
		Vector2(-27, -8), Vector2(-21, -23), Vector2(-8, -31),
		Vector2(8, -32), Vector2(22, -24), Vector2(30, -9),
		Vector2(23, 0), Vector2(7, 4), Vector2(-8, 4), Vector2(-22, 0)
	]), s)
	t.draw_colored_polygon(cap_inner, cap_mid)

	# Underside gills to make the cap readable.
	for x in [-22, -12, -2, 8, 18]:
		_draw_stroked_line(t, Vector2(x, 2) * s, Vector2(x * 0.48, -15) * s, gill, 1.45 * s)

	# Cap spots / spore pods.
	for spot in [
		[Vector2(-23, -13), 4.6],
		[Vector2(-7, -24), 5.0],
		[Vector2(11, -25), 4.5],
		[Vector2(27, -13), 4.2],
		[Vector2(3, -11), 3.2],
	]:
		_draw_stroked_circle(t, spot[0] * s, float(spot[1]) * s, cap_light, 1.1 * s, true)

	# Burst/spore cloud markers near muzzle and around base.
	for p in [Vector2(48, -8), Vector2(53, 0), Vector2(48, 7), Vector2(31, 15), Vector2(-30, 15)]:
		_draw_stroked_circle(t, p * s, 2.4 * s, spore, 1.0 * s, true)

	# Nature + Earth dual token.
	_draw_dual_element_token(t, Vector2(0, 36) * s, nature, earth, s)


static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)


static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)


static func _outline_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, width: float) -> void:
	t.draw_arc(center, radius, start_angle, end_angle, 24, OUTLINE_SOFT, width + 2.2, true)


static func _draw_stroked_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	t.draw_arc(center, radius, start_angle, end_angle, 28, OUTLINE_SOFT, width + 2.0, true)
	t.draw_arc(center, radius, start_angle, end_angle, 28, color, width, true)


static func _draw_stroked_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, a, b, width + 2.2)
	t.draw_line(a, b, color, width, true)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, color: Color, width: float, filled: bool) -> void:
	if filled:
		TowerVisualDrawUtils._draw_contour_circle(t, center, radius)
		t.draw_circle(center, radius, color, true)
	else:
		t.draw_circle(center, radius, OUTLINE_SOFT, false, width + 2.2, true)
		t.draw_circle(center, radius, color, false, width, true)


static func _draw_dual_element_token(t: Node2D, center: Vector2, a: Color, b: Color, s: float) -> void:
	var r := 8.0 * s
	TowerVisualDrawUtils._draw_contour_circle(t, center, r + 1.4 * s)
	t.draw_circle(center + Vector2(-2.2, 0) * s, r, a.darkened(0.08), true)
	t.draw_circle(center + Vector2(2.2, 0) * s, r, b.darkened(0.05), true)
	t.draw_circle(center, r * 0.54, Color(0.10, 0.15, 0.10, 0.80), true)
	t.draw_line(center + Vector2(-6, 4) * s, center + Vector2(0, -5) * s, a.lightened(0.25), 1.4 * s, true)
	t.draw_line(center + Vector2(0, -5) * s, center + Vector2(6, 4) * s, b.lightened(0.20), 1.4 * s, true)
