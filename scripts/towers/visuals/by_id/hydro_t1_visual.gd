extends RefCounted

# Tower: Hydro Tower 1
# Role: Tidal impact — heavy water splash that drenches and slows enemies.
# Elements: water, earth
# Visual source: custom by_id visual
# Visual intent: heavy hydro-cannon / tidal mortar; reads as land-only splash + slow, not a single-target beam.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p)
	return out

static func _closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, antialiased := true) -> void:
	var path := PackedVector2Array(points)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, color, width, antialiased)

static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width := 2.0, line_color := Color.TRANSPARENT) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	var inner := _scale_poly(points, -stroke_width)
	t.draw_colored_polygon(inner, fill)
	if line_color.a > 0.0:
		_closed_polyline(t, inner, line_color, 1.0, true)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.4, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.7) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _scale_poly(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	if points.size() == 0:
		return points
	for p in points:
		center += p
	center /= float(points.size())

	var out := PackedVector2Array()
	for p in points:
		var dir := p - center
		var len := dir.length()
		if len <= 0.001:
			out.append(p)
		else:
			out.append(center + dir.normalized() * max(0.0, len + amount))
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var a := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

static func _draw_wave_icon(t: Node2D, center: Vector2, radius: float, water_color: Color, earth_color: Color) -> void:
	# Dual Water + Earth token. Small, readable, and static.
	var token := _regular_poly(center, radius, 8, PI / 8.0)

	t.draw_colored_polygon(token, DETAIL_OUTLINE)
	t.draw_colored_polygon(_scale_poly(token, -1.3), Color(0.018, 0.024, 0.028, 0.90))
	_closed_polyline(t, _scale_poly(token, -1.2), Color(water_color.r, water_color.g, water_color.b, 0.56), 1.0)

	# Earth base chip.
	var ground := _poly([
		center + Vector2(-radius * 0.55, radius * 0.22),
		center + Vector2(-radius * 0.16, radius * 0.02),
		center + Vector2(radius * 0.20, radius * 0.19),
		center + Vector2(radius * 0.52, radius * 0.02),
		center + Vector2(radius * 0.58, radius * 0.47),
		center + Vector2(-radius * 0.55, radius * 0.47),
	])
	t.draw_colored_polygon(ground, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_scale_poly(ground, -0.8), Color(earth_color.r, earth_color.g, earth_color.b, 0.70))

	# Water wave.
	var wave := PackedVector2Array([
		center + Vector2(-radius * 0.58, -radius * 0.04),
		center + Vector2(-radius * 0.32, -radius * 0.30),
		center + Vector2(-radius * 0.04, -radius * 0.08),
		center + Vector2(radius * 0.24, -radius * 0.32),
		center + Vector2(radius * 0.55, -radius * 0.05),
	])
	t.draw_polyline(wave, DETAIL_OUTLINE, 3.4, true)
	t.draw_polyline(wave, water_color.lightened(0.25), 1.6, true)

	t.draw_circle(center + Vector2(radius * 0.34, -radius * 0.33), radius * 0.10, water_color.lightened(0.35))

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var barrel_len := 24.0 + float(lvl) * 2.6

	# Heavy tidal mortar body.
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(-19, -11),
		Vector2(-7, -18),
		Vector2(13, -16),
		Vector2(22, -7),
		Vector2(22, 7),
		Vector2(13, 16),
		Vector2(-7, 18),
		Vector2(-19, 11),
	]))

	# Wide hydro cannon / diffuser, not a thin single-target barrel.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-2, -6, barrel_len, 12))
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(barrel_len - 3, -10),
		Vector2(barrel_len + 10, -7),
		Vector2(barrel_len + 13, 0),
		Vector2(barrel_len + 10, 7),
		Vector2(barrel_len - 3, 10),
	]))

	# Water tanks and earth anchors.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-12, -9), 5.5)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-12, 9), 5.5)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-17, -18), Vector2(-6, -18), 3.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-17, 18), Vector2(-6, 18), 3.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var water := main_color.lightened(0.16)
	var water_bright := main_color.lightened(0.42)
	var earth := secondary_color.darkened(0.08) if secondary_color.a > 0.01 else Color(0.54, 0.42, 0.24, 1.0)
	var earth_dark := earth.darkened(0.42)
	var metal := Color(0.065, 0.080, 0.082, 0.96)
	var wet_dark := Color(0.025, 0.065, 0.078, 0.94)
	var barrel_len := 24.0 + float(lvl) * 2.6

	# Static tidal splash/slow language around the base.
	for r in [20.0, 25.5]:
		t.draw_arc(Vector2.ZERO, r, deg_to_rad(205.0), deg_to_rad(335.0), 22, Color(water.r, water.g, water.b, 0.12), 1.2, true)
		t.draw_arc(Vector2.ZERO, r + 1.8, deg_to_rad(25.0), deg_to_rad(155.0), 22, Color(earth.r, earth.g, earth.b, 0.10), 1.0, true)

	# Main reinforced stone-water chamber.
	var body := _poly([
		Vector2(-19, -11),
		Vector2(-7, -18),
		Vector2(13, -16),
		Vector2(22, -7),
		Vector2(22, 7),
		Vector2(13, 16),
		Vector2(-7, 18),
		Vector2(-19, 11),
	])
	_draw_stroked_poly(t, body, metal, 2.0, Color(water.r, water.g, water.b, 0.36))

	# Earth armor plates, top/bottom.
	var top_plate := _poly([
		Vector2(-9, -17),
		Vector2(8, -15),
		Vector2(16, -8),
		Vector2(7, -6),
		Vector2(-11, -8),
	])
	var bottom_plate := _poly([
		Vector2(-9, 17),
		Vector2(8, 15),
		Vector2(16, 8),
		Vector2(7, 6),
		Vector2(-11, 8),
	])
	_draw_stroked_poly(t, top_plate, Color(earth.r, earth.g, earth.b, 0.70), 1.5)
	_draw_stroked_poly(t, bottom_plate, Color(earth.r, earth.g, earth.b, 0.62), 1.5)

	# Pressurized water tanks.
	_draw_stroked_circle(t, Vector2(-12, -9), 5.4, wet_dark, 1.7)
	_draw_stroked_circle(t, Vector2(-12, 9), 5.4, wet_dark, 1.7)
	t.draw_circle(Vector2(-12, -9), 3.0, Color(water.r, water.g, water.b, 0.62))
	t.draw_circle(Vector2(-12, 9), 3.0, Color(water.r, water.g, water.b, 0.50))
	t.draw_circle(Vector2(-13.6, -10.5), 1.0, Color(0.85, 1.0, 1.0, 0.74))
	t.draw_circle(Vector2(-13.6, 7.5), 1.0, Color(0.85, 1.0, 1.0, 0.60))

	# Central pressure core.
	_draw_stroked_circle(t, Vector2(2, 0), 8.5, Color(0.018, 0.035, 0.040, 0.96), 2.0)
	_draw_stroked_circle(t, Vector2(2, 0), 5.2, Color(water.r, water.g, water.b, 0.72), 1.2)
	t.draw_circle(Vector2(2, 0), 2.6, Color(0.82, 1.0, 1.0, 0.90))

	# Heavy hydro barrel / pressure channel.
	_draw_stroked_rect(t, Rect2(-2, -6, barrel_len, 12), Color(earth_dark.r, earth_dark.g, earth_dark.b, 0.92), 1.8)
	_draw_stroked_rect(t, Rect2(1, -3.3, barrel_len - 4.5, 6.6), Color(water.r, water.g, water.b, 0.42), 1.0)
	_draw_stroked_line(t, Vector2(1, 0), Vector2(barrel_len + 4.0, 0), water_bright, 2.0, true)

	# Wide splash diffuser muzzle.
	var diffuser := _poly([
		Vector2(barrel_len - 3, -10),
		Vector2(barrel_len + 10, -7),
		Vector2(barrel_len + 13, 0),
		Vector2(barrel_len + 10, 7),
		Vector2(barrel_len - 3, 10),
		Vector2(barrel_len + 1, 0),
	])
	_draw_stroked_poly(t, diffuser, Color(0.035, 0.090, 0.105, 0.96), 2.0, Color(water_bright.r, water_bright.g, water_bright.b, 0.52))
	t.draw_arc(Vector2(barrel_len + 8, 0), 6.8, -PI / 2.5, PI / 2.5, 16, Color(water_bright.r, water_bright.g, water_bright.b, 0.62), 1.2, true)
	t.draw_arc(Vector2(barrel_len + 10, 0), 10.2, -PI / 3.0, PI / 3.0, 16, Color(water_bright.r, water_bright.g, water_bright.b, 0.20), 1.0, true)

	# Earth stabilizers / anchor feet.
	var anchor_color := Color(earth_dark.r, earth_dark.g, earth_dark.b, 0.92)
	_draw_stroked_line(t, Vector2(-17, -18), Vector2(-5, -18), anchor_color.lightened(0.30), 2.0, true)
	_draw_stroked_line(t, Vector2(-17, 18), Vector2(-5, 18), anchor_color.lightened(0.20), 2.0, true)
	_draw_stroked_line(t, Vector2(10, -18), Vector2(19, -13), anchor_color.lightened(0.18), 2.0, true)
	_draw_stroked_line(t, Vector2(10, 18), Vector2(19, 13), anchor_color.lightened(0.12), 2.0, true)

	# Small splash droplets near the muzzle. Static only.
	for p in [
		Vector2(barrel_len + 16, -7),
		Vector2(barrel_len + 18, 0),
		Vector2(barrel_len + 16, 7),
	]:
		t.draw_circle(p, 2.2, DETAIL_OUTLINE_SOFT)
		t.draw_circle(p, 1.3, Color(water_bright.r, water_bright.g, water_bright.b, 0.52))

	# Dual element token below: Water + Earth.
	_draw_wave_icon(t, Vector2(-3, 22), 7.6, water_bright, earth)

	# Premium micro highlights, mirrored.
	_draw_stroked_line(t, Vector2(-4, -11), Vector2(9, -10), Color(water_bright.r, water_bright.g, water_bright.b, 0.36), 0.9, true)
	_draw_stroked_line(t, Vector2(-4, 11), Vector2(9, 10), Color(water_bright.r, water_bright.g, water_bright.b, 0.28), 0.9, true)
