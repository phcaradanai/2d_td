extends RefCounted

# Tower: Fire Tower I
# Role: Plasma splash burn / land-only AoE furnace
# Elements: fire
# Visual source: custom by_id visual
# Visual intent: compact molten furnace mortar; wide splash vent, heat shields, AoE read at small scale.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

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
	center /= max(1, points.size())
	var out := PackedVector2Array()
	for p in points:
		var dir := p - center
		if dir.length() <= 0.001:
			out.append(p)
		else:
			out.append(center + dir.normalized() * max(0.0, dir.length() + amount))
	return out

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

static func _draw_fire_element_token(t: Node2D, center: Vector2, radius: float, main_color: Color) -> void:
	# Small fire token behind the furnace, adapted for Node2D drawing.
	var token_color := Color(1.0, 0.36, 0.06, 1.0)
	var outer := _regular_poly(center, radius * 0.94, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.78, 8, PI / 8.0)

	t.draw_colored_polygon(_regular_poly(center, radius * 1.06, 8, PI / 8.0), Color(token_color.r, token_color.g, token_color.b, 0.10))
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(outer, -1.2), Color(0.08, 0.018, 0.006, 0.90))
	t.draw_colored_polygon(inner, Color(0.18, 0.045, 0.008, 0.84))
	_draw_closed_polyline(t, outer, Color(1.0, 0.34, 0.04, 0.55), 1.1)

	var flame := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.58),
		center + Vector2(radius * 0.30, -radius * 0.16),
		center + Vector2(radius * 0.20, radius * 0.46),
		center + Vector2(0.0, radius * 0.28),
		center + Vector2(-radius * 0.20, radius * 0.46),
		center + Vector2(-radius * 0.32, -radius * 0.12),
	])
	t.draw_colored_polygon(flame, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(flame, -1.1), Color(1.0, 0.26, 0.025, 0.92))
	var inner_flame := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.32),
		center + Vector2(radius * 0.16, radius * 0.06),
		center + Vector2(0.0, radius * 0.27),
		center + Vector2(-radius * 0.14, radius * 0.04),
	])
	t.draw_colored_polygon(inner_flame, Color(1.0, 0.78, 0.10, 0.95))

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var vent_len := 20.0 + float(lvl) * 2.0

	# Heavy compact furnace body.
	var body := PackedVector2Array([
		Vector2(-18, -11),
		Vector2(-10, -18),
		Vector2(8, -18),
		Vector2(17, -10),
		Vector2(17, 10),
		Vector2(8, 18),
		Vector2(-10, 18),
		Vector2(-18, 11),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, body)

	# Wide splash vent/mortar mouth, not a sniper barrel.
	var vent := PackedVector2Array([
		Vector2(4, -8),
		Vector2(vent_len + 9.0, -12),
		Vector2(vent_len + 16.0, -7),
		Vector2(vent_len + 16.0, 7),
		Vector2(vent_len + 9.0, 12),
		Vector2(4, 8),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, vent)

	# Symmetric heat shields.
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-6, -19), Vector2(11, -22), Vector2(17, -15), Vector2(2, -12)]))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-6, 19), Vector2(11, 22), Vector2(17, 15), Vector2(2, 12)]))

	# Rear fire token and center chamber.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-11, 0), 10.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(2, 0), 8.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var fire := Color(1.0, 0.30, 0.035, 1.0)
	var amber := Color(1.0, 0.64, 0.08, 1.0)
	var molten := Color(1.0, 0.12, 0.015, 1.0)
	var deep_metal := Color(0.13, 0.025, 0.012, 1.0)
	var dark_metal := Color(0.055, 0.020, 0.014, 1.0)
	var vent_len := 20.0 + float(lvl) * 2.0

	# Static splash/heat language under the tower. Cheap and subtle.
	t.draw_arc(Vector2.ZERO, 23.0, deg_to_rad(205.0), deg_to_rad(335.0), 20, Color(1.0, 0.18, 0.02, 0.16), 1.3, true)
	t.draw_arc(Vector2.ZERO, 18.0, deg_to_rad(25.0), deg_to_rad(155.0), 18, Color(1.0, 0.52, 0.03, 0.10), 1.0, true)
	t.draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.11, 0.02, 0.045))

	# Element token sits behind the body so Fire identity is visible without reading as a muzzle.
	_draw_fire_element_token(t, Vector2(-11, 0), 12.0 + float(lvl) * 0.45, main_color)

	# Side heat shields/fins, mirrored top/bottom.
	var top_shield := PackedVector2Array([Vector2(-7, -18), Vector2(12, -22), Vector2(18, -15), Vector2(2, -12)])
	var bottom_shield := PackedVector2Array([Vector2(-7, 18), Vector2(12, 22), Vector2(18, 15), Vector2(2, 12)])
	t.draw_colored_polygon(top_shield, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(top_shield, -1.4), Color(0.34, 0.055, 0.018, 0.96))
	_draw_stroked_polyline(t, top_shield, Color(1.0, 0.24, 0.035, 0.62), 0.9)
	t.draw_colored_polygon(bottom_shield, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(bottom_shield, -1.4), Color(0.30, 0.045, 0.016, 0.96))
	_draw_stroked_polyline(t, bottom_shield, Color(1.0, 0.20, 0.03, 0.54), 0.9)

	# Main furnace body: heavy, compact, symmetrical.
	var body := PackedVector2Array([
		Vector2(-18, -11),
		Vector2(-10, -18),
		Vector2(8, -18),
		Vector2(17, -10),
		Vector2(17, 10),
		Vector2(8, 18),
		Vector2(-10, 18),
		Vector2(-18, 11),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(body, -2.0), deep_metal)
	_draw_stroked_polyline(t, body, Color(1.0, 0.23, 0.035, 0.58), 1.2)

	# Molten inner chamber.
	_draw_stroked_circle(t, Vector2(1.5, 0), 8.2, Color(0.10, 0.018, 0.006, 0.95), 2.0)
	t.draw_circle(Vector2(1.5, 0), 6.2, Color(1.0, 0.11, 0.015, 0.82))
	t.draw_circle(Vector2(1.5, 0), 3.8, Color(1.0, 0.58, 0.06, 0.88))
	t.draw_circle(Vector2(1.5, 0), 1.8, Color(1.0, 0.94, 0.36, 0.94))

	# Furnace grate bars communicate heat/plasma, not precision beam.
	for y in [-7.5, 0.0, 7.5]:
		_draw_stroked_line(t, Vector2(-13.0, y), Vector2(-5.2, y), Color(1.0, 0.39, 0.035, 0.72), 1.2, true)

	# Wide splash vent / plasma mortar mouth.
	var vent := PackedVector2Array([
		Vector2(4, -8),
		Vector2(vent_len + 9.0, -12),
		Vector2(vent_len + 16.0, -7),
		Vector2(vent_len + 16.0, 7),
		Vector2(vent_len + 9.0, 12),
		Vector2(4, 8),
	])
	t.draw_colored_polygon(vent, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(vent, -1.8), Color(0.42, 0.060, 0.018, 1.0))
	_draw_stroked_polyline(t, vent, Color(1.0, 0.28, 0.025, 0.72), 1.1)

	# Dark inner vent with hot slit, no round muzzle orb.
	var mouth_x := vent_len + 12.0
	var mouth := PackedVector2Array([
		Vector2(mouth_x - 2.0, -5.0),
		Vector2(mouth_x + 6.0, -3.4),
		Vector2(mouth_x + 6.0, 3.4),
		Vector2(mouth_x - 2.0, 5.0),
	])
	t.draw_colored_polygon(mouth, DETAIL_OUTLINE)
	t.draw_colored_polygon(_expand(mouth, -1.0), dark_metal)
	_draw_stroked_line(t, Vector2(mouth_x - 1.0, 0), Vector2(mouth_x + 5.0, 0), amber, 1.5, true)

	# Small mirrored ember fins near the vent; static, readable, cheap.
	var ember_top := PackedVector2Array([Vector2(15, -15), Vector2(22, -18), Vector2(19, -11)])
	var ember_bottom := PackedVector2Array([Vector2(15, 15), Vector2(22, 18), Vector2(19, 11)])
	t.draw_colored_polygon(ember_top, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_expand(ember_top, -0.8), Color(1.0, 0.36, 0.02, 0.45))
	t.draw_colored_polygon(ember_bottom, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_expand(ember_bottom, -0.8), Color(1.0, 0.27, 0.02, 0.38))

	# Four small heat rivets, replacing generic corner ticks.
	var rivet_color := Color(1.0, 0.46, 0.04, 0.48)
	for p in [Vector2(-18, -18), Vector2(18, -18), Vector2(-18, 18), Vector2(18, 18)]:
		t.draw_circle(p, 3.8, Color(1.0, 0.18, 0.02, 0.08))
		t.draw_arc(p, 2.8, 0.0, TAU, 14, DETAIL_OUTLINE_SOFT, 1.1, true)
		t.draw_circle(p, 1.25, rivet_color)
