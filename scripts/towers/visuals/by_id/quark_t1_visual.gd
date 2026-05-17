extends RefCounted
class_name TowerVisualQuarkT1

# Tower: Quark Tower 1
# Role: Periodic burst / charged single-target nuke
# Elements: Light, Earth
# Visual source: custom by_id visual
# Visual intent: compact particle accelerator with a dense charged nucleus and a forward release rail.
#   It should read as "stores energy, then fires one devastating particle shot", not AoE/aura.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if closed.size() > 0:
		closed.append(closed[0])
	t.draw_polyline(closed, color, width, true)


static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)


static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.3, true)
	t.draw_line(from, to, color, width, true)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)


static func _draw_ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float) -> void:
	t.draw_arc(center, radius, 0.0, TAU, 40, DETAIL_OUTLINE, width + 2.0, true)
	t.draw_arc(center, radius, 0.0, TAU, 40, color, width, true)


static func _draw_stroked_polygon(t: Node2D, points: PackedVector2Array, fill: Color, trim: Color, trim_width := 1.2) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(t, points, -1.4)
	t.draw_colored_polygon(inner, fill)
	_closed_polyline(t, inner, trim, trim_width)


static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, light_col: Color, earth_col: Color) -> void:
	var frame := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(frame, DETAIL_OUTLINE)
	t.draw_circle(center, radius * 0.88, Color(0.02, 0.018, 0.014, 0.86))

	var left := PackedVector2Array([
		center + Vector2(-radius * 0.52, -radius * 0.58),
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(0.0, radius * 0.74),
		center + Vector2(-radius * 0.52, radius * 0.58),
	])
	var right := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(radius * 0.52, -radius * 0.58),
		center + Vector2(radius * 0.52, radius * 0.58),
		center + Vector2(0.0, radius * 0.74),
	])
	t.draw_colored_polygon(left, Color(light_col.r, light_col.g, light_col.b, 0.64))
	t.draw_colored_polygon(right, Color(earth_col.r, earth_col.g, earth_col.b, 0.66))
	_closed_polyline(t, frame, Color(1.0, 0.93, 0.50, 0.44), 0.9)

	# Quark mark: small nucleus and a single release dot.
	t.draw_circle(center, radius * 0.22, Color(1.0, 0.95, 0.62, 0.88))
	t.draw_circle(center + Vector2(radius * 0.38, 0.0), radius * 0.12, Color(earth_col.r, earth_col.g, earth_col.b, 0.82))


static func draw_contour(t: Node2D) -> void:
	var barrel_len := 24.0 + float(t.tree_tier) * 3.0

	# Accelerator shell / collider body.
	var body := PackedVector2Array([
		Vector2(-19, 0),
		Vector2(-12, -15),
		Vector2(7, -17),
		Vector2(18, -9),
		Vector2(20, 0),
		Vector2(18, 9),
		Vector2(7, 17),
		Vector2(-12, 15),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, body)

	# Forward release rail. This is a charged single-target emitter, not an AoE mouth.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(4, -4, barrel_len, 8))
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(6, -8), Vector2(barrel_len + 5.0, -8), 2.4)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(6, 8), Vector2(barrel_len + 5.0, 8), 2.4)

	# Dense nucleus and storage rings.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-5, 0), 12.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-5, 0), 6.0)


static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var light_col := main_color.lightened(0.18)
	var earth_col := secondary_color if el_colors.size() >= 2 else Color(0.72, 0.58, 0.32, 1.0)
	var deep_metal := Color(0.055, 0.050, 0.038, 0.94)
	var chamber := Color(0.12, 0.105, 0.052, 0.92)
	var charge := Color(1.0, 0.92, 0.45, 0.92)
	var barrel_len := 24.0 + float(lvl) * 3.0

	# Static stored-energy aura. Cheap but communicates a slow charged shot.
	t.draw_circle(Vector2(-5, 0), 23.0, Color(light_col.r, light_col.g, light_col.b, 0.055))
	t.draw_circle(Vector2(-5, 0), 17.0, Color(earth_col.r, earth_col.g, earth_col.b, 0.055))

	# Heavy collider shell.
	var body := PackedVector2Array([
		Vector2(-19, 0),
		Vector2(-12, -15),
		Vector2(7, -17),
		Vector2(18, -9),
		Vector2(20, 0),
		Vector2(18, 9),
		Vector2(7, 17),
		Vector2(-12, 15),
	])
	_draw_stroked_polygon(t, body, deep_metal, Color(light_col.r, light_col.g, light_col.b, 0.36), 1.0)

	# Earth mass plates on top/bottom: the tower feels dense and impact-heavy.
	var upper_plate := PackedVector2Array([
		Vector2(-11, -14),
		Vector2(5, -15),
		Vector2(13, -9),
		Vector2(6, -6),
		Vector2(-8, -7),
	])
	var lower_plate := PackedVector2Array([
		Vector2(-11, 14),
		Vector2(5, 15),
		Vector2(13, 9),
		Vector2(6, 6),
		Vector2(-8, 7),
	])
	_draw_stroked_polygon(t, upper_plate, Color(earth_col.r * 0.45, earth_col.g * 0.42, earth_col.b * 0.35, 0.90), Color(earth_col.r, earth_col.g, earth_col.b, 0.32), 0.9)
	_draw_stroked_polygon(t, lower_plate, Color(earth_col.r * 0.36, earth_col.g * 0.34, earth_col.b * 0.30, 0.86), Color(earth_col.r, earth_col.g, earth_col.b, 0.24), 0.9)

	# Particle storage rings around the nucleus.
	_draw_ring(t, Vector2(-5, 0), 13.2, Color(light_col.r, light_col.g, light_col.b, 0.46), 1.15)
	_draw_ring(t, Vector2(-5, 0), 8.6, Color(earth_col.r, earth_col.g, earth_col.b, 0.38), 1.0)

	# Static charge pips positioned symmetrically; no animated orbit needed.
	for p in [
		Vector2(-5, -13.2),
		Vector2(-5, 13.2),
		Vector2(3.6, -8.6),
		Vector2(3.6, 8.6),
	]:
		t.draw_circle(p, 3.0, DETAIL_OUTLINE)
		t.draw_circle(p, 1.8, Color(charge.r, charge.g, charge.b, 0.88))

	# Dense nucleus / quark core.
	_draw_stroked_circle(t, Vector2(-5, 0), 6.2, Color(0.02, 0.017, 0.010, 0.94), 1.8)
	t.draw_circle(Vector2(-5, 0), 4.6, Color(light_col.r, light_col.g, light_col.b, 0.38))
	t.draw_circle(Vector2(-5, 0), 2.8, charge)
	t.draw_circle(Vector2(-3.8, -1.2), 1.0, Color(1.0, 1.0, 0.82, 0.92))
	t.draw_circle(Vector2(-6.7, 1.4), 0.9, Color(earth_col.r, earth_col.g, earth_col.b, 0.80))

	# Forward accelerator rails: narrow and precise, to show single-target release.
	var rail_body := PackedVector2Array([
		Vector2(4, -4),
		Vector2(barrel_len + 4.0, -4),
		Vector2(barrel_len + 8.0, 0),
		Vector2(barrel_len + 4.0, 4),
		Vector2(4, 4),
	])
	_draw_stroked_polygon(t, rail_body, chamber, Color(light_col.r, light_col.g, light_col.b, 0.42), 0.9)
	_draw_stroked_line(t, Vector2(6, -8), Vector2(barrel_len + 4.0, -8), Color(light_col.r, light_col.g, light_col.b, 0.50), 1.0)
	_draw_stroked_line(t, Vector2(6, 8), Vector2(barrel_len + 4.0, 8), Color(light_col.r, light_col.g, light_col.b, 0.50), 1.0)

	# Single release point: small and sharp, not a cannon muzzle.
	var tip := Vector2(barrel_len + 8.0, 0)
	t.draw_circle(tip, 4.0, DETAIL_OUTLINE)
	t.draw_circle(tip, 2.5, Color(light_col.r, light_col.g, light_col.b, 0.34))
	t.draw_circle(tip, 1.25, Color(1.0, 0.96, 0.62, 0.92))
	_draw_stroked_line(t, Vector2(barrel_len + 1.0, -3.0), tip, Color(1.0, 0.92, 0.42, 0.72), 1.0)
	_draw_stroked_line(t, Vector2(barrel_len + 1.0, 3.0), tip, Color(1.0, 0.92, 0.42, 0.72), 1.0)

	# Charge countdown language: three capacitors that imply a periodic burst cycle.
	var cap_col := Color(light_col.r, light_col.g, light_col.b, 0.58)
	for i in range(3):
		var x := -17.0 + float(i) * 5.0
		_draw_stroked_circle(t, Vector2(x, 19.0), 2.1, Color(cap_col.r, cap_col.g, cap_col.b, 0.46), 1.1)

	# Dual element identity, kept small so it does not override the particle-accelerator silhouette.
	_draw_dual_element_token(t, Vector2(-13, 0), 4.2, light_col, earth_col)
