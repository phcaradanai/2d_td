extends RefCounted

# Tower: Well Tower 1
# Role: Wellspring support aura — attack speed empowerment for nearby towers
# Elements: water, nature
# Visual source: custom by_id visual
# Visual intent: sacred wellspring / aqua-bio support totem; no weapon barrel, clear aura/support identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.64)
const METAL_DARK := Color(0.035, 0.050, 0.055, 0.95)
const WELL_INNER := Color(0.030, 0.070, 0.080, 0.92)

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

static func _scale_poly(points: PackedVector2Array, delta: float) -> PackedVector2Array:
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
			out.append(center + dir.normalized() * max(0.0, dir.length() + delta))
	return out

static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width := 2.0) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	t.draw_colored_polygon(_scale_poly(points, -stroke_width), fill)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.4, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 2.0) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_stroked_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float, segments := 28) -> void:
	t.draw_arc(center, radius, start_angle, end_angle, segments, DETAIL_OUTLINE_SOFT, width + 2.0, true)
	t.draw_arc(center, radius, start_angle, end_angle, segments, color, width, true)

static func _draw_leaf(t: Node2D, center: Vector2, radius: float, color: Color, angle: float) -> void:
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var leaf := PackedVector2Array([
		center - forward * radius * 0.52,
		center + side * radius * 0.52,
		center + forward * radius * 0.76,
		center - side * radius * 0.52,
	])
	_draw_stroked_poly(t, leaf, color, 1.5)
	_draw_stroked_line(t, center - forward * radius * 0.32, center + forward * radius * 0.42, color.lightened(0.22), 0.9, true)

static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, water: Color, nature: Color) -> void:
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_circle(center, radius * 0.86, Color(0.018, 0.026, 0.024, 0.92))
	_draw_closed_polyline(t, outer, Color(0.70, 0.95, 0.92, 0.46), 1.0)

	var drop := PackedVector2Array([
		center + Vector2(-3.8, -4.2),
		center + Vector2(-7.0, 1.0),
		center + Vector2(-3.8, 5.1),
		center + Vector2(-0.8, 1.0),
	])
	t.draw_colored_polygon(drop, DETAIL_OUTLINE)
	t.draw_colored_polygon(_scale_poly(drop, -0.9), Color(water.r, water.g, water.b, 0.88))

	var leaf := PackedVector2Array([
		center + Vector2(3.4, -5.0),
		center + Vector2(7.1, -0.5),
		center + Vector2(3.2, 5.0),
		center + Vector2(0.6, 0.1),
	])
	t.draw_colored_polygon(leaf, DETAIL_OUTLINE)
	t.draw_colored_polygon(_scale_poly(leaf, -0.9), Color(nature.r, nature.g, nature.b, 0.88))

static func draw_contour(t: Node2D) -> void:
	t.draw_circle(Vector2.ZERO, 24.0, DETAIL_OUTLINE_SOFT)

	var basin := _regular_poly(Vector2.ZERO, 18.5, 8, PI / 8.0)
	t.draw_colored_polygon(basin, DETAIL_OUTLINE)

	for p in [Vector2(-22, -18), Vector2(22, -18), Vector2(-22, 18), Vector2(22, 18)]:
		t.draw_circle(p, 4.7, DETAIL_OUTLINE)

	t.draw_colored_polygon(PackedVector2Array([Vector2(-13, -16), Vector2(0, -24), Vector2(13, -16), Vector2(0, -13)]), DETAIL_OUTLINE)
	t.draw_colored_polygon(PackedVector2Array([Vector2(-13, 16), Vector2(0, 24), Vector2(13, 16), Vector2(0, 13)]), DETAIL_OUTLINE)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var water := Color(0.18, 0.82, 1.0, 1.0)
	var nature := Color(0.28, 0.92, 0.42, 1.0)
	if el_colors.size() > 0:
		water = el_colors[0]
	if el_colors.size() > 1:
		nature = el_colors[1]

	var aqua := water.lightened(0.14)
	var leaf_c := nature.lightened(0.08)
	var radius_boost := float(lvl) * 0.8

	# Static aura language for attack-speed support. Kept subtle so it does not look like gameplay range.
	t.draw_circle(Vector2.ZERO, 27.0 + radius_boost, Color(aqua.r, aqua.g, aqua.b, 0.055))
	_draw_stroked_arc(t, Vector2.ZERO, 26.0 + radius_boost, -2.82, -1.82, Color(aqua.r, aqua.g, aqua.b, 0.34), 1.0, 22)
	_draw_stroked_arc(t, Vector2.ZERO, 26.0 + radius_boost, -0.36, 0.64, Color(leaf_c.r, leaf_c.g, leaf_c.b, 0.34), 1.0, 22)
	_draw_stroked_arc(t, Vector2.ZERO, 22.0 + radius_boost, 1.14, 2.02, Color(leaf_c.r, leaf_c.g, leaf_c.b, 0.28), 0.9, 20)
	_draw_stroked_arc(t, Vector2.ZERO, 22.0 + radius_boost, 3.95, 4.72, Color(aqua.r, aqua.g, aqua.b, 0.28), 0.9, 20)

	# Main octagonal well basin.
	var outer_basin := _regular_poly(Vector2.ZERO, 18.5, 8, PI / 8.0)
	var mid_basin := _regular_poly(Vector2.ZERO, 15.6, 8, PI / 8.0)
	t.draw_colored_polygon(outer_basin, DETAIL_OUTLINE)
	t.draw_colored_polygon(_scale_poly(outer_basin, -1.8), METAL_DARK)
	_draw_closed_polyline(t, outer_basin, Color(aqua.r, aqua.g, aqua.b, 0.55), 1.2)

	t.draw_colored_polygon(mid_basin, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_scale_poly(mid_basin, -1.4), WELL_INNER)
	_draw_closed_polyline(t, mid_basin, Color(leaf_c.r, leaf_c.g, leaf_c.b, 0.30), 0.9)

	# Living water pool: reads as a well, not a cannon.
	t.draw_circle(Vector2.ZERO, 11.3, DETAIL_OUTLINE)
	t.draw_circle(Vector2.ZERO, 9.5, Color(0.02, 0.13, 0.13, 0.96))
	t.draw_circle(Vector2.ZERO, 7.4, Color(aqua.r, aqua.g, aqua.b, 0.46))
	t.draw_arc(Vector2.ZERO, 6.0, -2.65, -0.30, 30, Color(0.88, 1.0, 0.98, 0.72), 1.15, true)
	t.draw_arc(Vector2.ZERO, 3.9, 0.45, 2.65, 24, Color(leaf_c.r, leaf_c.g, leaf_c.b, 0.46), 0.95, true)
	t.draw_circle(Vector2(-2.6, -1.8), 1.8, Color(0.90, 1.0, 0.96, 0.82))

	# Nature leaf conduits, symmetrical top/bottom.
	_draw_leaf(t, Vector2(0, -18.0), 8.8, Color(leaf_c.r, leaf_c.g, leaf_c.b, 0.82), -PI / 2.0)
	_draw_leaf(t, Vector2(0, 18.0), 8.8, Color(leaf_c.r, leaf_c.g, leaf_c.b, 0.76), PI / 2.0)

	# Water channels left/right.
	_draw_stroked_line(t, Vector2(-17.0, 0.0), Vector2(-10.5, 0.0), Color(aqua.r, aqua.g, aqua.b, 0.72), 1.8, true)
	_draw_stroked_line(t, Vector2(10.5, 0.0), Vector2(17.0, 0.0), Color(aqua.r, aqua.g, aqua.b, 0.72), 1.8, true)
	_draw_stroked_arc(t, Vector2(-18.0, 0.0), 4.8, -1.15, 1.15, Color(aqua.r, aqua.g, aqua.b, 0.38), 1.0, 16)
	_draw_stroked_arc(t, Vector2(18.0, 0.0), 4.8, 2.0, 4.28, Color(aqua.r, aqua.g, aqua.b, 0.38), 1.0, 16)

	# Four support pylons: represent empowering nearby non-support towers.
	var pylons := [
		Vector2(-22, -18),
		Vector2(22, -18),
		Vector2(-22, 18),
		Vector2(22, 18),
	]
	for i in range(pylons.size()):
		var p : Vector2 = pylons[i]
		var c := aqua if i < 2 else leaf_c
		t.draw_circle(p, 6.0, Color(c.r, c.g, c.b, 0.08))
		_draw_stroked_circle(t, p, 4.0, Color(0.025, 0.038, 0.035, 0.95), 1.6)
		t.draw_circle(p, 2.2, Color(c.r, c.g, c.b, 0.74))
		t.draw_circle(p, 1.0, Color(0.92, 1.0, 0.92, 0.80))
		_draw_stroked_line(t, p, p.normalized() * 13.5, Color(c.r, c.g, c.b, 0.32), 0.9, true)

	# Small acceleration chevrons around basin: attack-speed aura identity.
	var chevron_c := Color(0.82, 1.0, 0.88, 0.56)
	_draw_stroked_line(t, Vector2(-5.0, -8.0), Vector2(0.0, -5.6), chevron_c, 0.9, true)
	_draw_stroked_line(t, Vector2(0.0, -5.6), Vector2(5.0, -8.0), chevron_c, 0.9, true)
	_draw_stroked_line(t, Vector2(-5.0, 8.0), Vector2(0.0, 5.6), chevron_c, 0.9, true)
	_draw_stroked_line(t, Vector2(0.0, 5.6), Vector2(5.0, 8.0), chevron_c, 0.9, true)

	# Dual element identity token, intentionally small and below the well so it doesn't become the main read.
	_draw_dual_element_token(t, Vector2(0, 28.0), 7.2, aqua, leaf_c)
