extends RefCounted
class_name TowerVisualVaporT1

# Tower: Vapor Tower 1
# Role: Steam blast splash + brief slow
# Elements: Water, Fire
# Visual source: custom by_id visual
# Visual intent: premium pressurized steam boiler / scalding vapor mortar.
#   It should read as splash + slow, not as a single-target cannon.
# Performance note: CanvasItem draw calls only; no particles, nodes, timers, or gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

static func _poly(points: Array) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for p in points:
		arr.append(p)
	return arr

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if closed.size() > 0:
		closed.append(closed[0])
	t.draw_polyline(closed, color, width, true)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.1, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.6) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_vapor_token(t: Node2D, center: Vector2, radius: float, water_color: Color, fire_color: Color) -> void:
	# Compact Water + Fire token. It replaces generic element core without obscuring the boiler.
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.78, 8, PI / 8.0)

	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(outer, Color(0.025, 0.030, 0.035, 0.88))
	_draw_closed_polyline(t, outer, Color(0.75, 0.92, 1.0, 0.38), 0.9)

	# Split droplet/flame halves.
	var left_drop := _poly([
		center + Vector2(-radius * 0.48, -radius * 0.10),
		center + Vector2(-radius * 0.16, -radius * 0.58),
		center + Vector2(-radius * 0.02, radius * 0.10),
		center + Vector2(-radius * 0.26, radius * 0.46),
		center + Vector2(-radius * 0.54, radius * 0.18),
	])
	var right_flame := _poly([
		center + Vector2(radius * 0.22, -radius * 0.58),
		center + Vector2(radius * 0.52, -radius * 0.06),
		center + Vector2(radius * 0.34, radius * 0.50),
		center + Vector2(radius * 0.04, radius * 0.18),
		center + Vector2(radius * 0.10, -radius * 0.16),
	])
	t.draw_colored_polygon(left_drop, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(left_drop, -0.7), Color(water_color.r, water_color.g, water_color.b, 0.86))
	t.draw_colored_polygon(right_flame, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(right_flame, -0.7), Color(fire_color.r, fire_color.g, fire_color.b, 0.88))

	_draw_closed_polyline(t, inner, Color(1.0, 1.0, 1.0, 0.16), 0.7)

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var nozzle_len := 17.0 + float(lvl) * 2.0

	# Main boiler and pressure tanks.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-3, 0), 17.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-10, -10), 7.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-10, 10), 7.0)

	# Wide steam diffuser / splash vent.
	var vent := _poly([
		Vector2(9, -8),
		Vector2(16 + nozzle_len, -12),
		Vector2(22 + nozzle_len, 0),
		Vector2(16 + nozzle_len, 12),
		Vector2(9, 8),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, vent)

	# Top safety valve and lower condenser foot.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-5, -23, 10, 8))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(0, -25), 4.0)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-15, 15, 24, 7))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var water := main_color
	var fire := secondary_color if el_colors.size() >= 2 else Color(1.0, 0.48, 0.12, 0.95)
	var steam := Color(0.86, 0.96, 1.0, 0.58)
	var steam_soft := Color(0.82, 0.94, 1.0, 0.16)
	var metal := Color(0.06, 0.075, 0.085, 0.96)
	var dark_water := water.darkened(0.42)
	var hot := fire.lightened(0.18)
	var nozzle_len := 17.0 + float(lvl) * 2.0

	# Static steam cloud language behind the tower. Cheap and readable, not particle-based.
	t.draw_circle(Vector2(2, 0), 23.0, Color(water.r, water.g, water.b, 0.045))
	t.draw_arc(Vector2(2, 0), 23.0, -0.74, 0.74, 18, steam_soft, 2.0, true)
	t.draw_arc(Vector2(2, 0), 18.5, -0.58, 0.58, 16, Color(fire.r, fire.g, fire.b, 0.10), 1.4, true)

	# Rear dual pressure tanks: water tank above, heat chamber below.
	_draw_stroked_circle(t, Vector2(-10, -10), 7.0, Color(water.r, water.g, water.b, 0.46), 2.0)
	_draw_stroked_circle(t, Vector2(-10, 10), 7.0, Color(fire.r, fire.g, fire.b, 0.48), 2.0)
	t.draw_circle(Vector2(-10, -10), 3.3, Color(0.86, 0.98, 1.0, 0.42))
	t.draw_circle(Vector2(-10, 10), 3.3, Color(1.0, 0.72, 0.22, 0.46))

	# Main round boiler body with black rim and polished metal shell.
	_draw_stroked_circle(t, Vector2(-3, 0), 17.0, metal, 2.2)
	t.draw_circle(Vector2(-3, 0), 13.5, Color(dark_water.r, dark_water.g, dark_water.b, 0.78))
	t.draw_arc(Vector2(-3, 0), 15.0, -2.75, 2.75, 30, Color(0.78, 0.94, 1.0, 0.34), 1.5, true)
	t.draw_arc(Vector2(-3, 0), 10.0, 0.0, TAU, 24, DETAIL_OUTLINE_SOFT, 1.2, true)
	t.draw_arc(Vector2(-3, 0), 9.0, 0.0, TAU, 24, Color(steam.r, steam.g, steam.b, 0.42), 1.0, true)

	# Pressure gauge needle and rivet band to make it read as a boiler.
	_draw_stroked_line(t, Vector2(-3, 0), Vector2(3, -5), Color(1.0, 0.92, 0.58, 0.72), 1.0, true)
	_draw_stroked_line(t, Vector2(-18, 0), Vector2(8, 0), Color(0.72, 0.92, 1.0, 0.32), 1.0, true)
	for p in [Vector2(-16, -5), Vector2(-16, 5), Vector2(8, -5), Vector2(8, 5)]:
		_draw_stroked_circle(t, p, 1.7, Color(0.78, 0.94, 1.0, 0.44), 0.8)

	# Wide steam diffuser / splash vent. This is intentionally not a sniper barrel.
	var vent := _poly([
		Vector2(9, -8),
		Vector2(16 + nozzle_len, -12),
		Vector2(22 + nozzle_len, 0),
		Vector2(16 + nozzle_len, 12),
		Vector2(9, 8),
	])
	t.draw_colored_polygon(vent, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(vent, -2.0), Color(0.075, 0.085, 0.088, 0.96))
	_draw_stroked_polyline(t, vent, Color(steam.r, steam.g, steam.b, 0.46), 1.1)
	_draw_stroked_line(t, Vector2(12, -4), Vector2(18 + nozzle_len, -7), Color(water.r, water.g, water.b, 0.50), 1.0, true)
	_draw_stroked_line(t, Vector2(12, 4), Vector2(18 + nozzle_len, 7), Color(fire.r, fire.g, fire.b, 0.48), 1.0, true)

	# Scalding vapor tip: soft cloud circles instead of a muzzle orb.
	var tip := Vector2(21 + nozzle_len, 0)
	t.draw_circle(tip + Vector2(2.0, -3.0), 4.0, Color(steam.r, steam.g, steam.b, 0.16))
	t.draw_circle(tip + Vector2(2.0, 3.0), 4.0, Color(steam.r, steam.g, steam.b, 0.13))
	t.draw_circle(tip, 2.0, Color(1.0, 0.78, 0.30, 0.58))
	_draw_stroked_line(t, Vector2(tip.x - 6.0, 0), tip, hot, 1.6, true)

	# Safety valve and static steam arcs. No idle_rotation, so the catalog stays stable.
	_draw_stroked_rect(t, Rect2(-5, -23, 10, 8), Color(0.055, 0.060, 0.065, 0.95), 1.4)
	_draw_stroked_circle(t, Vector2(0, -25), 4.0, hot, 1.5)
	t.draw_arc(Vector2(0, -25), 7.0, -2.55, -0.55, 10, steam, 1.3, true)
	t.draw_arc(Vector2(0, -25), 9.5, -2.35, -0.85, 10, Color(steam.r, steam.g, steam.b, 0.36), 1.1, true)
	t.draw_arc(Vector2(0, -25), 7.0, -0.20, 1.45, 10, Color(steam.r, steam.g, steam.b, 0.36), 1.1, true)

	# Lower condenser foot / base.
	_draw_stroked_rect(t, Rect2(-15, 15, 24, 7), Color(0.05, 0.055, 0.058, 0.95), 1.5)
	_draw_stroked_line(t, Vector2(-12, 18.5), Vector2(6, 18.5), Color(water.r, water.g, water.b, 0.34), 1.0, true)

	# Splash + slow language around base: soft thermal/water arcs, static and cheap.
	t.draw_arc(Vector2(0, 5), 22.0, 0.52, 2.60, 18, Color(water.r, water.g, water.b, 0.28), 1.3, true)
	t.draw_arc(Vector2(0, 5), 25.0, 0.28, 2.85, 20, Color(fire.r, fire.g, fire.b, 0.20), 1.0, true)
	t.draw_arc(Vector2(0, 5), 19.0, -2.60, -0.52, 18, Color(steam.r, steam.g, steam.b, 0.20), 1.0, true)

	# Water + Fire identity token, deliberately small and below the main silhouette.
	_draw_vapor_token(t, Vector2(-2, 3), 6.3, water, fire)
