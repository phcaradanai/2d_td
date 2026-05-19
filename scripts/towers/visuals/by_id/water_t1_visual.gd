extends RefCounted

# Tower: Water Tower I
# Role: Cryo Control / water crystal burst
# Elements: Water
# Visual source: custom by_id visual
# Visual intent: premium aqua crystal emitter; symmetric silhouette, water element identity, readable control/cold theme.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _outline_rect(t: Node2D, rect: Rect2) -> void:
	TowerVisualDrawUtils._draw_contour_rect(t, rect)

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

static func _draw_water_element_icon(t: Node2D, center: Vector2, radius: float, main_color: Color) -> void:
	# Water element token adapted for Node2D tower drawing.
	# It replaces generic element-core circles with a clear droplet / wave identity.
	var token_color := main_color.lightened(0.20)
	var outer_poly := _regular_poly(center, radius * 1.02, 8, PI / 8.0)
	var inner_poly := _regular_poly(center, radius * 0.82, 8, PI / 8.0)

	t.draw_colored_polygon(outer_poly, DETAIL_OUTLINE)
	t.draw_colored_polygon(outer_poly, Color(0.018, 0.032, 0.052, 0.90))
	t.draw_colored_polygon(inner_poly, Color(0.020, 0.105, 0.165, 0.82))
	_draw_closed_polyline(t, outer_poly, Color(token_color.r, token_color.g, token_color.b, 0.70), 1.25)
	_draw_closed_polyline(t, inner_poly, Color(token_color.r, token_color.g, token_color.b, 0.30), 0.85)

	t.draw_circle(center, radius * 0.95, Color(token_color.r, token_color.g, token_color.b, 0.07))

	var drop := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.58),
		center + Vector2(radius * 0.34, -radius * 0.10),
		center + Vector2(radius * 0.26, radius * 0.34),
		center + Vector2(0.0, radius * 0.54),
		center + Vector2(-radius * 0.26, radius * 0.34),
		center + Vector2(-radius * 0.34, -radius * 0.10),
	])
	t.draw_colored_polygon(drop, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(drop, -0.9), Color(0.16, 0.78, 1.0, 0.92))
	_draw_closed_polyline(t, drop, Color(0.72, 0.96, 1.0, 0.82), 0.85)

	_draw_stroked_line(
		t,
		center + Vector2(-radius * 0.22, radius * 0.04),
		center + Vector2(radius * 0.20, -radius * 0.06),
		Color(0.86, 1.0, 1.0, 0.72),
		0.85,
		true
	)

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var nose_len := 23.0 + float(lvl) * 1.8

	_outline_circle(t, Vector2(-10, 0), 13.0)

	var body := PackedVector2Array([
		Vector2(-20, 0),
		Vector2(-9, -15),
		Vector2(12, -12),
		Vector2(21, 0),
		Vector2(12, 12),
		Vector2(-9, 15),
	])
	_outline_poly(t, body)

	_outline_rect(t, Rect2(-2, -4, nose_len, 8))
	_outline_line(t, Vector2(-5, -8), Vector2(nose_len + 2.0, -8), 2.4)
	_outline_line(t, Vector2(-5, 8), Vector2(nose_len + 2.0, 8), 2.4)

	_outline_poly(t, PackedVector2Array([
		Vector2(-15, -4),
		Vector2(-28, -12),
		Vector2(-18, -16),
		Vector2(-7, -8),
	]))
	_outline_poly(t, PackedVector2Array([
		Vector2(-15, 4),
		Vector2(-28, 12),
		Vector2(-18, 16),
		Vector2(-7, 8),
	]))

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	var aqua := main_color.lightened(0.25)
	var ice := Color(0.72, 0.95, 1.0, 0.92)
	var deep := Color(0.025, 0.095, 0.145, 0.92)
	var glass := Color(main_color.r, main_color.g, main_color.b, 0.42)
	var nose_len := 23.0 + float(lvl) * 1.8

	t.draw_circle(Vector2.ZERO, 21.0 + float(lvl) * 1.2, Color(main_color.r, main_color.g, main_color.b, 0.075))
	t.draw_arc(Vector2.ZERO, 19.0 + float(lvl) * 0.8, 0.15, TAU - 0.15, 36, Color(main_color.r, main_color.g, main_color.b, 0.18), 1.0, true)

	_draw_water_element_icon(t, Vector2(-10, 0), 10.8 + float(lvl) * 0.25, main_color)

	var body := PackedVector2Array([
		Vector2(-20, 0),
		Vector2(-9, -15),
		Vector2(12, -12),
		Vector2(21, 0),
		Vector2(12, 12),
		Vector2(-9, 15),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(body, -2.0), glass)
	_draw_stroked_polyline(t, body, Color(aqua.r, aqua.g, aqua.b, 0.78), 1.4)

	var upper_facet := PackedVector2Array([
		Vector2(-8, -11),
		Vector2(10, -8),
		Vector2(17, 0),
		Vector2(-2, -2),
	])
	var lower_facet := PackedVector2Array([
		Vector2(-8, 11),
		Vector2(10, 8),
		Vector2(17, 0),
		Vector2(-2, 2),
	])
	t.draw_colored_polygon(upper_facet, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(upper_facet, -1.1), Color(ice.r, ice.g, ice.b, 0.22))
	_draw_stroked_polyline(t, upper_facet, Color(ice.r, ice.g, ice.b, 0.55), 0.85)
	t.draw_colored_polygon(lower_facet, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(lower_facet, -1.1), Color(aqua.r, aqua.g, aqua.b, 0.18))
	_draw_stroked_polyline(t, lower_facet, Color(aqua.r, aqua.g, aqua.b, 0.46), 0.85)

	_draw_stroked_rect(t, Rect2(-2, -4, nose_len, 8), deep, 1.8)
	_draw_stroked_line(t, Vector2(-2, 0), Vector2(nose_len + 1.5, 0), ice, 2.0, true)
	_draw_stroked_line(t, Vector2(-4, -8), Vector2(nose_len + 2.0, -8), Color(aqua.r, aqua.g, aqua.b, 0.46), 1.0, true)
	_draw_stroked_line(t, Vector2(-4, 8), Vector2(nose_len + 2.0, 8), Color(aqua.r, aqua.g, aqua.b, 0.46), 1.0, true)

	var tip_x := nose_len + 3.0
	var splash_tip := PackedVector2Array([
		Vector2(tip_x - 3.5, -4.2),
		Vector2(tip_x + 4.0, 0.0),
		Vector2(tip_x - 3.5, 4.2),
		Vector2(tip_x - 1.6, 0.0),
	])
	t.draw_colored_polygon(splash_tip, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(splash_tip, -0.8), Color(0.78, 0.98, 1.0, 0.86))
	_draw_stroked_polyline(t, splash_tip, Color(0.90, 1.0, 1.0, 0.70), 0.75)

	var upper_fin := PackedVector2Array([
		Vector2(-15, -4),
		Vector2(-28, -12),
		Vector2(-18, -16),
		Vector2(-7, -8),
	])
	var lower_fin := PackedVector2Array([
		Vector2(-15, 4),
		Vector2(-28, 12),
		Vector2(-18, 16),
		Vector2(-7, 8),
	])
	t.draw_colored_polygon(upper_fin, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(upper_fin, -1.0), Color(0.10, 0.54, 0.82, 0.72))
	_draw_stroked_polyline(t, upper_fin, Color(0.60, 0.90, 1.0, 0.50), 0.85)
	t.draw_colored_polygon(lower_fin, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(lower_fin, -1.0), Color(0.06, 0.38, 0.64, 0.72))
	_draw_stroked_polyline(t, lower_fin, Color(0.42, 0.80, 1.0, 0.42), 0.85)

	var halo_points := [
		Vector2(-21, -20),
		Vector2(21, -20),
		Vector2(-21, 20),
		Vector2(21, 20),
	]
	for p in halo_points:
		t.draw_circle(p, 5.0, Color(main_color.r, main_color.g, main_color.b, 0.06))
		t.draw_arc(p, 3.8, 0.0, TAU, 18, DETAIL_OUTLINE_SOFT, 1.05, true)
		t.draw_arc(p, 3.0, 0.0, TAU, 18, Color(aqua.r, aqua.g, aqua.b, 0.26), 0.9, true)
		t.draw_circle(p, 1.15, Color(0.78, 0.98, 1.0, 0.48))
