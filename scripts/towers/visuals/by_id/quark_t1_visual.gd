extends RefCounted
class_name TowerVisualQuarkT1

# Tower: Quark Tower 1
# Role: Periodic burst / charged single-target nuke
# Elements: Light + Earth
# Visual source: custom by_id visual
# Visual intent:
#   Premium particle-accelerator tower: dense earth collider body, light focusing lens,
#   charge capacitors, and one narrow release rail for rare devastating single-target shots.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.85

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const DEFAULT_LIGHT := Color(1.0, 0.92, 0.42, 1.0)
const DEFAULT_EARTH := Color(0.68, 0.54, 0.32, 1.0)


static func _s() -> float:
	return VISUAL_SCALE


static func _v(p: Vector2) -> Vector2:
	return p * VISUAL_SCALE


static func _r(value: float) -> float:
	return value * VISUAL_SCALE


static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_v(p))
	return out


static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(_v(center + Vector2(cos(angle), sin(angle)) * radius))
	return points


static func _closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if closed.size() > 0:
		closed.append(closed[0])
	t.draw_polyline(closed, color, _r(width), true)


static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _r(width + 2.2), true)
	t.draw_polyline(path, color, _r(width), true)


static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(_v(from), _v(to), OUTLINE, _r(width + 2.3), true)
	t.draw_line(_v(from), _v(to), color, _r(width), true)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(_v(center), _r(radius + stroke_width), OUTLINE)
	t.draw_circle(_v(center), _r(radius), fill)


static func _draw_ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float, point_count := 40) -> void:
	t.draw_arc(_v(center), _r(radius), 0.0, TAU, point_count, OUTLINE, _r(width + 2.0), true)
	t.draw_arc(_v(center), _r(radius), 0.0, TAU, point_count, color, _r(width), true)


static func _draw_stroked_polygon(t: Node2D, points: PackedVector2Array, fill: Color, trim: Color, trim_width := 1.2) -> void:
	t.draw_colored_polygon(points, OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(points, -_r(1.4))
	t.draw_colored_polygon(inner, fill)
	_closed_polyline(t, inner, trim, trim_width)


static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, light_col: Color, earth_col: Color) -> void:
	var frame := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(frame, OUTLINE)
	t.draw_circle(_v(center), _r(radius * 0.88), Color(0.02, 0.018, 0.014, 0.90))

	var left := _poly([
		center + Vector2(-radius * 0.52, -radius * 0.58),
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(0.0, radius * 0.74),
		center + Vector2(-radius * 0.52, radius * 0.58),
	])
	var right := _poly([
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(radius * 0.52, -radius * 0.58),
		center + Vector2(radius * 0.52, radius * 0.58),
		center + Vector2(0.0, radius * 0.74),
	])

	t.draw_colored_polygon(left, Color(light_col.r, light_col.g, light_col.b, 0.68))
	t.draw_colored_polygon(right, Color(earth_col.r, earth_col.g, earth_col.b, 0.70))
	_closed_polyline(t, frame, Color(1.0, 0.93, 0.50, 0.46), 0.9)

	# Quark mark: nucleus + release dot.
	t.draw_circle(_v(center), _r(radius * 0.22), Color(1.0, 0.95, 0.62, 0.90))
	t.draw_circle(_v(center + Vector2(radius * 0.38, 0.0)), _r(radius * 0.12), Color(earth_col.r, earth_col.g, earth_col.b, 0.86))


static func _draw_charge_tick(t: Node2D, center: Vector2, angle: float, color: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var tangent := Vector2(-dir.y, dir.x)
	var a := center + dir * 18.0 - tangent * 2.0
	var b := center + dir * 21.0
	var c := center + dir * 18.0 + tangent * 2.0
	var tick := _poly([a, b, c])
	t.draw_colored_polygon(tick, OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(tick, -_r(0.8))
	t.draw_colored_polygon(inner, color)


static func _draw_focus_lens(t: Node2D, center: Vector2, light_col: Color, earth_col: Color) -> void:
	var lens := _regular_poly(center, 8.0, 6, PI / 6.0)
	t.draw_colored_polygon(lens, OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(lens, -_r(1.2))
	t.draw_colored_polygon(inner, Color(0.98, 0.90, 0.44, 0.42))
	_closed_polyline(t, inner, Color(light_col.r, light_col.g, light_col.b, 0.60), 1.0)

	t.draw_circle(_v(center), _r(4.4), Color(0.02, 0.017, 0.010, 0.94))
	t.draw_circle(_v(center), _r(2.8), Color(light_col.r, light_col.g, light_col.b, 0.80))
	t.draw_circle(_v(center + Vector2(-1.2, -1.0)), _r(0.9), Color(1.0, 1.0, 0.78, 0.95))
	t.draw_circle(_v(center + Vector2(1.6, 1.2)), _r(0.8), Color(earth_col.r, earth_col.g, earth_col.b, 0.86))


static func draw_contour(t: Node2D) -> void:
	var barrel_len := 25.0 + float(t.tree_tier) * 3.0

	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(-23, 0),
		Vector2(-15, -17),
		Vector2(4, -20),
		Vector2(18, -14),
		Vector2(24, -6),
		Vector2(25, 6),
		Vector2(18, 14),
		Vector2(4, 20),
		Vector2(-15, 17),
	]))
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(5, -5),
		Vector2(barrel_len + 5.0, -5),
		Vector2(barrel_len + 11.0, 0),
		Vector2(barrel_len + 5.0, 5),
		Vector2(5, 5),
	]))
	TowerVisualDrawUtils._draw_contour_line(t, _v(Vector2(6, -10)), _v(Vector2(barrel_len + 4.0, -10)), _r(2.4))
	TowerVisualDrawUtils._draw_contour_line(t, _v(Vector2(6, 10)), _v(Vector2(barrel_len + 4.0, 10)), _r(2.4))

	TowerVisualDrawUtils._draw_contour_circle(t, _v(Vector2(-6, 0)), _r(14.0))
	TowerVisualDrawUtils._draw_contour_circle(t, _v(Vector2(-6, 0)), _r(7.0))

	for p: Vector2 in [Vector2(-22, -8), Vector2(-22, 8), Vector2(0, -20), Vector2(0, 20)]:
		TowerVisualDrawUtils._draw_contour_circle(t, _v(p), _r(3.2))


static func draw_top(t: Node2D, _main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, _size: float, el_colors: Array[Color]) -> void:
	var light_col := DEFAULT_LIGHT
	var earth_col := DEFAULT_EARTH
	if el_colors.size() >= 1:
		light_col = el_colors[0].lightened(0.18)
	if el_colors.size() >= 2:
		earth_col = el_colors[1]
	else:
		earth_col = secondary_color

	var deep_metal := Color(0.050, 0.047, 0.040, 0.96)
	var dark_cavity := Color(0.018, 0.015, 0.010, 0.96)
	var chamber := Color(0.120, 0.100, 0.055, 0.94)
	var charge := Color(1.0, 0.92, 0.42, 0.94)
	var barrel_len := 25.0 + float(lvl) * 3.0

	# Stored energy halo, static and cheap.
	t.draw_circle(_v(Vector2(-6, 0)), _r(27.0), Color(light_col.r, light_col.g, light_col.b, 0.050))
	t.draw_circle(_v(Vector2(-6, 0)), _r(20.0), Color(earth_col.r, earth_col.g, earth_col.b, 0.050))

	# Collider body: asymmetric but compact, so the firing direction is obvious.
	var body := _poly([
		Vector2(-23, 0),
		Vector2(-15, -17),
		Vector2(4, -20),
		Vector2(18, -14),
		Vector2(24, -6),
		Vector2(25, 6),
		Vector2(18, 14),
		Vector2(4, 20),
		Vector2(-15, 17),
	])
	_draw_stroked_polygon(t, body, deep_metal, Color(light_col.r, light_col.g, light_col.b, 0.34), 1.0)

	# Dense earth shielding plates.
	var plates: Array[PackedVector2Array] = [
		_poly([Vector2(-16, -15), Vector2(4, -18), Vector2(17, -12), Vector2(9, -7), Vector2(-11, -7)]),
		_poly([Vector2(-16, 15), Vector2(4, 18), Vector2(17, 12), Vector2(9, 7), Vector2(-11, 7)]),
		_poly([Vector2(-23, -1), Vector2(-17, -10), Vector2(-10, -7), Vector2(-11, 7), Vector2(-17, 10)]),
	]
	for plate: PackedVector2Array in plates:
		_draw_stroked_polygon(t, plate, Color(earth_col.r * 0.46, earth_col.g * 0.42, earth_col.b * 0.34, 0.90), Color(earth_col.r, earth_col.g, earth_col.b, 0.34), 0.85)

	# Particle accelerator rings and focus lens.
	_draw_ring(t, Vector2(-6, 0), 15.3, Color(light_col.r, light_col.g, light_col.b, 0.48), 1.15)
	_draw_ring(t, Vector2(-6, 0), 10.0, Color(earth_col.r, earth_col.g, earth_col.b, 0.42), 1.0)
	_draw_focus_lens(t, Vector2(-6, 0), light_col, earth_col)

	# Periodic burst read: charge ticks are like a countdown around the nucleus.
	for a: float in [-PI * 0.78, -PI * 0.22, PI * 0.22, PI * 0.78]:
		_draw_charge_tick(t, Vector2(-6, 0), a, Color(charge.r, charge.g, charge.b, 0.78))

	# External capacitors: premium sci-fi details, still static.
	var caps: Array[Vector2] = [Vector2(-22, -8), Vector2(-22, 8), Vector2(0, -20), Vector2(0, 20)]
	for i in range(caps.size()):
		var p := caps[i]
		var col := Color(light_col.r, light_col.g, light_col.b, 0.72) if i < 2 else Color(earth_col.r, earth_col.g, earth_col.b, 0.70)
		_draw_stroked_circle(t, p, 3.2, Color(col.r, col.g, col.b, 0.66), 1.25)
		t.draw_circle(_v(p), _r(1.1), Color(1.0, 0.95, 0.58, 0.90))

	# Forward rail accelerator: sharp single-target emitter, not a cannon mouth.
	var rail_body := _poly([
		Vector2(5, -5),
		Vector2(barrel_len + 5.0, -5),
		Vector2(barrel_len + 11.0, 0),
		Vector2(barrel_len + 5.0, 5),
		Vector2(5, 5),
	])
	_draw_stroked_polygon(t, rail_body, chamber, Color(light_col.r, light_col.g, light_col.b, 0.45), 0.9)

	_draw_stroked_line(t, Vector2(6, -10), Vector2(barrel_len + 4.0, -10), Color(light_col.r, light_col.g, light_col.b, 0.52), 1.0)
	_draw_stroked_line(t, Vector2(6, 10), Vector2(barrel_len + 4.0, 10), Color(light_col.r, light_col.g, light_col.b, 0.52), 1.0)
	_draw_stroked_line(t, Vector2(9, -2.8), Vector2(barrel_len + 6.0, -1.0), Color(1.0, 0.88, 0.35, 0.50), 0.8)
	_draw_stroked_line(t, Vector2(9, 2.8), Vector2(barrel_len + 6.0, 1.0), Color(1.0, 0.88, 0.35, 0.50), 0.8)

	var tip := Vector2(barrel_len + 11.0, 0.0)
	_draw_stroked_circle(t, tip, 3.8, dark_cavity, 1.4)
	t.draw_circle(_v(tip), _r(2.1), Color(light_col.r, light_col.g, light_col.b, 0.38))
	t.draw_circle(_v(tip), _r(1.0), Color(1.0, 0.96, 0.62, 0.94))

	# Narrow pre-shot wedge. Static, small, and precise.
	var focus_wedge := _poly([
		tip + Vector2(2.0, 0.0),
		tip + Vector2(10.0, -2.0),
		tip + Vector2(14.0, 0.0),
		tip + Vector2(10.0, 2.0),
	])
	t.draw_colored_polygon(focus_wedge, Color(light_col.r, light_col.g, light_col.b, 0.16))
	_closed_polyline(t, focus_wedge, Color(light_col.r, light_col.g, light_col.b, 0.35), 0.75)

	# Single-target / periodic identity marker.
	_draw_dual_element_token(t, Vector2(-14, 0), 4.7, light_col, earth_col)
