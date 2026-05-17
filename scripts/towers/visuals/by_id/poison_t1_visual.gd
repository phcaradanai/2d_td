extends RefCounted

# Tower: Poison Tower 1
# Role: Toxic venom — slow + draining poison control
# Elements: darkness, water
# Visual source: custom by_id visual
# Visual intent: toxin vial / venom injector; land-only slow poison with dark-water identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _expand(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in points:
		center += p
	if points.size() > 0:
		center /= float(points.size())

	var out := PackedVector2Array()
	for p in points:
		var d := p - center
		if d.length() <= 0.001:
			out.append(p)
		else:
			out.append(p + d.normalized() * amount)
	return out


static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	t.draw_polyline(closed, color, width, true)


static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width: float = 1.8) -> void:
	t.draw_colored_polygon(_expand(points, stroke_width), DETAIL_OUTLINE)
	t.draw_colored_polygon(points, fill)


static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)


static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)


static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.7) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)


static func _draw_stroked_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	t.draw_arc(center, radius, start_angle, end_angle, 24, DETAIL_OUTLINE, width + 2.0, true)
	t.draw_arc(center, radius, start_angle, end_angle, 24, color, width, true)


static func _draw_drop(t: Node2D, center: Vector2, scale: float, fill: Color) -> void:
	var drop := PackedVector2Array([
		center + Vector2(0.0, -6.0) * scale,
		center + Vector2(5.4, -0.4) * scale,
		center + Vector2(3.1, 5.7) * scale,
		center + Vector2(0.0, 7.1) * scale,
		center + Vector2(-3.1, 5.7) * scale,
		center + Vector2(-5.4, -0.4) * scale,
	])
	_draw_stroked_poly(t, drop, fill, 1.25)


static func _draw_skull_mark(t: Node2D, center: Vector2, scale: float, acid: Color) -> void:
	# Tiny poison symbol. Kept simple for catalog readability and in-game scale.
	_draw_stroked_circle(t, center + Vector2(0.0, -1.4) * scale, 3.3 * scale, Color(acid.r, acid.g, acid.b, 0.52), 0.9)
	t.draw_circle(center + Vector2(-1.2, -1.9) * scale, 0.65 * scale, DETAIL_OUTLINE)
	t.draw_circle(center + Vector2(1.2, -1.9) * scale, 0.65 * scale, DETAIL_OUTLINE)
	_draw_stroked_rect(t, Rect2(center + Vector2(-1.7, 1.1) * scale, Vector2(3.4, 2.2) * scale), Color(acid.r, acid.g, acid.b, 0.35), 0.55)


static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, dark_color: Color, water_color: Color) -> void:
	# Compact Darkness + Water token: tells the element combo without using UI nodes.
	var frame := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(_expand(frame, 1.8), DETAIL_OUTLINE)
	t.draw_colored_polygon(frame, Color(0.020, 0.018, 0.028, 0.86))
	_draw_closed_polyline(t, frame, Color(water_color.r, water_color.g, water_color.b, 0.58), 1.0)

	var left := PackedVector2Array([
		center + Vector2(-radius * 0.58, -radius * 0.38),
		center + Vector2(-radius * 0.06, -radius * 0.62),
		center + Vector2(-radius * 0.10, radius * 0.52),
		center + Vector2(-radius * 0.64, radius * 0.30),
	])
	var right := PackedVector2Array([
		center + Vector2(radius * 0.58, -radius * 0.38),
		center + Vector2(radius * 0.06, -radius * 0.62),
		center + Vector2(radius * 0.10, radius * 0.52),
		center + Vector2(radius * 0.64, radius * 0.30),
	])
	t.draw_colored_polygon(left, Color(dark_color.r, dark_color.g, dark_color.b, 0.74))
	t.draw_colored_polygon(right, Color(water_color.r, water_color.g, water_color.b, 0.66))
	t.draw_line(center + Vector2(0, -radius * 0.58), center + Vector2(0, radius * 0.58), DETAIL_OUTLINE_SOFT, 1.1, true)


static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var nozzle_len := 21.0 + float(lvl) * 2.0

	# Venom tank silhouette.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-7, 0), 15.0)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-14, -12, 14, 24))

	# Injector body and asymmetric-free pointed nozzle.
	var injector := PackedVector2Array([
		Vector2(-2, -6),
		Vector2(nozzle_len, -5),
		Vector2(nozzle_len + 7.0, 0),
		Vector2(nozzle_len, 5),
		Vector2(-2, 6),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, injector)

	# Toxic control pods and slow field.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-22, -15), 4.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-22, 15), 4.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(13, -15), 3.5)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(13, 15), 3.5)


static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var dark := Color(0.18, 0.08, 0.32, 1.0)
	var water := Color(0.10, 0.70, 0.82, 1.0)
	if el_colors.size() > 0:
		dark = el_colors[0]
	if el_colors.size() > 1:
		water = el_colors[1]

	var venom := Color(0.42, 1.00, 0.22, 1.0)
	var venom_soft := Color(0.42, 1.00, 0.22, 0.42)
	var toxic_shadow := Color(0.07, 0.025, 0.095, 0.94)
	var metal := Color(0.095, 0.105, 0.118, 0.95)
	var dark_glass := Color(0.028, 0.018, 0.045, 0.94)
	var nozzle_len := 21.0 + float(lvl) * 2.0

	# Static slow/poison field: soft circles and broken arcs, not particles.
	t.draw_circle(Vector2.ZERO, 23.0 + float(lvl) * 1.2, Color(venom.r, venom.g, venom.b, 0.045))
	_draw_stroked_arc(t, Vector2.ZERO, 22.0, -2.80, -1.72, Color(venom.r, venom.g, venom.b, 0.24), 1.0)
	_draw_stroked_arc(t, Vector2.ZERO, 22.0, 1.72, 2.80, Color(dark.r, dark.g, dark.b, 0.22), 1.0)
	_draw_stroked_arc(t, Vector2.ZERO, 18.0, -0.52, 0.52, Color(water.r, water.g, water.b, 0.18), 0.9)

	# Rear toxic vial / reservoir.
	_draw_stroked_circle(t, Vector2(-7, 0), 15.0, dark_glass, 2.2)
	_draw_stroked_rect(t, Rect2(-14, -12, 14, 24), metal, 1.7)

	# Poison liquid inside the vial.
	var liquid := PackedVector2Array([
		Vector2(-17, 2),
		Vector2(-11, -4),
		Vector2(-5, 1),
		Vector2(1, -3),
		Vector2(5, 4),
		Vector2(2, 9),
		Vector2(-7, 12),
		Vector2(-15, 9),
	])
	t.draw_colored_polygon(liquid, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_expand(liquid, -1.1), Color(venom.r, venom.g, venom.b, 0.54))
	_draw_stroked_polyline(t, liquid, Color(venom.r, venom.g, venom.b, 0.70), 0.9)

	# Glass highlight and toxic bubbles.
	_draw_stroked_line(t, Vector2(-14, -8), Vector2(-7, -12), Color(water.r, water.g, water.b, 0.36), 0.9, true)
	_draw_stroked_circle(t, Vector2(-12, 4), 1.6, Color(venom.r, venom.g, venom.b, 0.62), 0.45)
	_draw_stroked_circle(t, Vector2(-4, 7), 1.2, Color(venom.r, venom.g, venom.b, 0.46), 0.45)
	_draw_stroked_circle(t, Vector2(-4, -5), 1.0, Color(venom.r, venom.g, venom.b, 0.42), 0.4)

	# Injector channel / toxic needle: clearly not a cannon.
	var injector := PackedVector2Array([
		Vector2(-2, -6),
		Vector2(nozzle_len, -5),
		Vector2(nozzle_len + 7.0, 0),
		Vector2(nozzle_len, 5),
		Vector2(-2, 6),
	])
	_draw_stroked_poly(t, injector, Color(0.060, 0.072, 0.068, 0.96), 2.0)
	var inner_channel := PackedVector2Array([
		Vector2(0, -2.4),
		Vector2(nozzle_len - 1.0, -2.2),
		Vector2(nozzle_len + 3.2, 0),
		Vector2(nozzle_len - 1.0, 2.2),
		Vector2(0, 2.4),
	])
	t.draw_colored_polygon(inner_channel, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_expand(inner_channel, -0.8), Color(venom.r, venom.g, venom.b, 0.58))
	_draw_stroked_line(t, Vector2(0, 0), Vector2(nozzle_len + 2.8, 0), Color(venom.r, venom.g, venom.b, 0.72), 1.15, true)

	# Mirrored venom tubes from reservoir to injector.
	_draw_stroked_line(t, Vector2(-10, -12), Vector2(9, -9), Color(water.r, water.g, water.b, 0.36), 1.2, true)
	_draw_stroked_line(t, Vector2(-10, 12), Vector2(9, 9), Color(water.r, water.g, water.b, 0.30), 1.2, true)
	_draw_stroked_line(t, Vector2(-7, -10), Vector2(8, -6), Color(venom.r, venom.g, venom.b, 0.46), 0.8, true)
	_draw_stroked_line(t, Vector2(-7, 10), Vector2(8, 6), Color(venom.r, venom.g, venom.b, 0.40), 0.8, true)

	# Toxic pods around the body: control/slow identity.
	var pod_positions := [
		Vector2(-22, -15),
		Vector2(-22, 15),
		Vector2(13, -15),
		Vector2(13, 15),
	]
	for i in range(pod_positions.size()):
		var p: Vector2 = pod_positions[i]
		var r := 4.0
		if i >= 2:
			r = 3.5
			t.draw_circle(p, r + 3.5, Color(venom.r, venom.g, venom.b, 0.045))
		_draw_stroked_circle(t, p, r, toxic_shadow, 1.2)
		_draw_stroked_circle(t, p, r * 0.54, Color(venom.r, venom.g, venom.b, 0.54), 0.7)

	# Small poison skull mark: communicates toxic draining without text.
	_draw_skull_mark(t, Vector2(-7, -0.5), 1.0, venom)

	# Droplet markers near the tip suggest venom spray/slow without adding runtime VFX.
	_draw_drop(t, Vector2(nozzle_len + 10.5, -7.2), 0.50, Color(venom.r, venom.g, venom.b, 0.32))
	_draw_drop(t, Vector2(nozzle_len + 10.5, 7.2), 0.50, Color(venom.r, venom.g, venom.b, 0.24))

	# Darkness + Water token, placed below so it does not hide the vial.
	_draw_dual_element_token(t, Vector2(-2, 21.0), 6.6, dark, water)
