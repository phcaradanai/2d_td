extends RefCounted

# Tower: Life Tower 1
# Role: Life economy / sacred rapid single-target tower
# Elements: light, nature
# Visual source: custom by_id visual
# Visual intent: holy seed reliquary with leaf rails and life-gain pips; communicates on-kill life economy, not a support aura.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.64)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, antialiased := true) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	t.draw_polyline(closed, color, width, antialiased)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_line(from, to, color, width, true)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_stroked_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	t.draw_arc(center, radius, start_angle, end_angle, 24, DETAIL_OUTLINE, width + 2.0, true)
	t.draw_arc(center, radius, start_angle, end_angle, 24, color, width, true)

static func _draw_leaf(t: Node2D, center: Vector2, scale: float, rotation: float, fill: Color, line: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(-8, 0),
		Vector2(-2, -7),
		Vector2(8, 0),
		Vector2(-2, 7),
	])
	var transformed := PackedVector2Array()
	for p in pts:
		transformed.append(center + p.rotated(rotation) * scale)
	t.draw_colored_polygon(transformed, DETAIL_OUTLINE)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(center + (p * 0.78).rotated(rotation) * scale)
	t.draw_colored_polygon(inner, fill)
	_draw_stroked_polyline(t, transformed, line, 0.9)
	_draw_stroked_line(t, center + Vector2(-5, 0).rotated(rotation) * scale, center + Vector2(5, 0).rotated(rotation) * scale, line, 0.75)

static func _draw_life_heart(t: Node2D, center: Vector2, scale: float, fill: Color, shine: Color) -> void:
	# Low-poly heart/seed token: clear at catalog size, cheap in-game.
	var heart := PackedVector2Array([
		Vector2(0, 8),
		Vector2(-9, -1),
		Vector2(-7, -9),
		Vector2(-2, -10),
		Vector2(0, -6),
		Vector2(2, -10),
		Vector2(7, -9),
		Vector2(9, -1),
	])
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for p in heart:
		outer.append(center + p * scale)
		inner.append(center + p * scale * 0.74)
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(inner, fill)
	_draw_closed_polyline(t, outer, shine, 1.0)
	t.draw_circle(center + Vector2(-2.2, -2.0) * scale, 1.8 * scale, Color(1.0, 1.0, 0.76, 0.88))

static func _draw_dual_token(t: Node2D, center: Vector2, radius: float, light_color: Color, nature_color: Color) -> void:
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(_regular_poly(center, radius + 1.8, 8, PI / 8.0), DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(outer, Color(0.018, 0.024, 0.018, 0.88))
	_draw_closed_polyline(t, outer, Color(0.92, 1.0, 0.56, 0.60), 1.0)

	# Left half: light star. Right half: nature leaf.
	var star := PackedVector2Array()
	var star_center := center + Vector2(-3.4, 0)
	for i in range(10):
		var angle := float(i) / 10.0 * TAU - PI / 2.0
		var r := radius * (0.34 if i % 2 == 0 else 0.14)
		star.append(star_center + Vector2(cos(angle), sin(angle)) * r)
	t.draw_colored_polygon(star, DETAIL_OUTLINE)
	t.draw_colored_polygon(star, Color(light_color.r, light_color.g, light_color.b, 0.90))

	var leaf := PackedVector2Array([
		center + Vector2(0.5, 0),
		center + Vector2(4.5, -4.2),
		center + Vector2(8.0, 0),
		center + Vector2(4.5, 4.2),
	])
	t.draw_colored_polygon(leaf, DETAIL_OUTLINE)
	t.draw_colored_polygon(leaf, Color(nature_color.r, nature_color.g, nature_color.b, 0.86))

static func draw_contour(t: Node2D) -> void:
	var body := PackedVector2Array([
		Vector2(-19, 0),
		Vector2(-12, -15),
		Vector2(5, -18),
		Vector2(18, -7),
		Vector2(20, 0),
		Vector2(18, 7),
		Vector2(5, 18),
		Vector2(-12, 15),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, body)

	# Compact forward emitter: this tower shoots, but its identity is life economy.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(10, -4, 18, 8))
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-5, 0), Vector2(31, 0), 4.0)

	# Sacred seed core and life pips.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-3, 0), 10.0)
	for p in [Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20)]:
		TowerVisualDrawUtils._draw_contour_circle(t, p, 4.6)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var light_color := Color(1.0, 0.92, 0.42, 1.0)
	var nature_color := Color(0.24, 1.0, 0.42, 1.0)
	if el_colors.size() >= 1:
		light_color = el_colors[0]
	if el_colors.size() >= 2:
		nature_color = el_colors[1]

	var sacred := light_color.lightened(0.18)
	var vine := nature_color.lightened(0.08)
	var leaf_dark := nature_color.darkened(0.46)
	var metal := Color(0.030, 0.040, 0.030, 0.94)
	var deep := Color(0.012, 0.020, 0.014, 0.96)
	var gold_glow := Color(sacred.r, sacred.g, sacred.b, 0.30)
	var green_glow := Color(vine.r, vine.g, vine.b, 0.24)

	# Soft holy/nature aura language, static only.
	t.draw_circle(Vector2.ZERO, 22.0 + float(lvl) * 1.2, Color(vine.r, vine.g, vine.b, 0.055))
	t.draw_arc(Vector2.ZERO, 20.0, -0.92 * PI, -0.18 * PI, 28, Color(vine.r, vine.g, vine.b, 0.22), 1.15, true)
	t.draw_arc(Vector2.ZERO, 20.0, 0.18 * PI, 0.92 * PI, 28, Color(sacred.r, sacred.g, sacred.b, 0.20), 1.15, true)

	# Main reliquary body.
	var body := PackedVector2Array([
		Vector2(-19, 0),
		Vector2(-12, -15),
		Vector2(5, -18),
		Vector2(18, -7),
		Vector2(20, 0),
		Vector2(18, 7),
		Vector2(5, 18),
		Vector2(-12, 15),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)
	var body_inner := PackedVector2Array([
		Vector2(-16, 0),
		Vector2(-10, -12),
		Vector2(4, -14),
		Vector2(15, -6),
		Vector2(17, 0),
		Vector2(15, 6),
		Vector2(4, 14),
		Vector2(-10, 12),
	])
	t.draw_colored_polygon(body_inner, metal)
	_draw_stroked_polyline(t, body, Color(vine.r, vine.g, vine.b, 0.55), 1.25)

	# Mirrored leaves make the silhouette feel alive but still symmetrical.
	_draw_leaf(t, Vector2(-4, -16), 0.78, -0.12, Color(leaf_dark.r, leaf_dark.g, leaf_dark.b, 0.88), Color(vine.r, vine.g, vine.b, 0.64))
	_draw_leaf(t, Vector2(-4, 16), 0.78, 0.12, Color(leaf_dark.r, leaf_dark.g, leaf_dark.b, 0.88), Color(vine.r, vine.g, vine.b, 0.64))
	_draw_leaf(t, Vector2(12, -10), 0.58, 0.60, Color(leaf_dark.r, leaf_dark.g, leaf_dark.b, 0.82), Color(vine.r, vine.g, vine.b, 0.56))
	_draw_leaf(t, Vector2(12, 10), 0.58, -0.60, Color(leaf_dark.r, leaf_dark.g, leaf_dark.b, 0.82), Color(vine.r, vine.g, vine.b, 0.56))

	# Forward rapid emitter: small and clean, because this is not cannon/splash.
	var channel := PackedVector2Array([
		Vector2(6, -5),
		Vector2(28, -3),
		Vector2(31, 0),
		Vector2(28, 3),
		Vector2(6, 5),
	])
	t.draw_colored_polygon(channel, DETAIL_OUTLINE)
	t.draw_colored_polygon(PackedVector2Array([
		Vector2(8, -3.2), Vector2(26.5, -2.0), Vector2(28.8, 0), Vector2(26.5, 2.0), Vector2(8, 3.2)
	]), deep)
	_draw_stroked_line(t, Vector2(7, -2.0), Vector2(27, -1.0), Color(sacred.r, sacred.g, sacred.b, 0.52), 0.9)
	_draw_stroked_line(t, Vector2(7, 2.0), Vector2(27, 1.0), Color(vine.r, vine.g, vine.b, 0.52), 0.9)
	t.draw_circle(Vector2(29, 0), 2.8, DETAIL_OUTLINE)
	t.draw_circle(Vector2(29, 0), 1.6, Color(0.86, 1.0, 0.48, 0.82))

	# Sacred life seed / on-kill life economy identity.
	_draw_stroked_circle(t, Vector2(-3, 0), 10.2, Color(0.020, 0.034, 0.020, 0.94), 2.0)
	t.draw_circle(Vector2(-3, 0), 8.2, Color(vine.r, vine.g, vine.b, 0.12))
	_draw_life_heart(t, Vector2(-3, 0), 0.78, Color(0.50, 1.0, 0.34, 0.92), Color(1.0, 1.0, 0.58, 0.80))

	# Life counter pips: communicates gain-life-after-kills without UI text.
	var pip_fill := Color(0.76, 1.0, 0.38, 0.72)
	var pip_glow := Color(0.86, 1.0, 0.42, 0.12)
	var pips := [Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20)]
	for p in pips:
		t.draw_circle(p, 6.3, pip_glow)
		t.draw_circle(p, 4.8, DETAIL_OUTLINE_SOFT)
		t.draw_circle(p, 3.2, Color(0.025, 0.040, 0.020, 0.88))
		t.draw_circle(p, 1.8, pip_fill)

	# Cross-body sacred conduits from life seed to pips.
	_draw_stroked_arc(t, Vector2(-3, 0), 16.0, -2.72, -1.98, Color(vine.r, vine.g, vine.b, 0.30), 0.85)
	_draw_stroked_arc(t, Vector2(-3, 0), 16.0, 1.98, 2.72, Color(vine.r, vine.g, vine.b, 0.30), 0.85)
	_draw_stroked_arc(t, Vector2(-3, 0), 16.0, -1.14, -0.42, Color(sacred.r, sacred.g, sacred.b, 0.28), 0.85)
	_draw_stroked_arc(t, Vector2(-3, 0), 16.0, 0.42, 1.14, Color(sacred.r, sacred.g, sacred.b, 0.28), 0.85)

	# Dual element token sits low so it does not fight the life seed silhouette.
	_draw_dual_token(t, Vector2(0, 23), 6.6, light_color, nature_color)
