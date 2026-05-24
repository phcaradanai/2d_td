extends RefCounted

# Tower: Quaker Tower 1
# Role: Seismic slam — massive ground-pound AoE
# Elements: fire, nature, earth
# Visual source: custom by_id visual
# Visual intent: heavy seismic drill/hammer tower; reads as land-only wide splash radius, not a projectile cannon.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.93)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

static func _poly(points: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in points:
		p.append(v)
	return p

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var a := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

static func _closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var path := PackedVector2Array(points)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, color, width, true)

static func _stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, line_color: Color, width := 1.35) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(points, -1.8), fill)
	_closed_polyline(t, points, DETAIL_OUTLINE, width + 2.0)
	_closed_polyline(t, points, line_color, width)

static func _stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _mirror_y(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(Vector2(p.x, -p.y))
	return out

static func _mirrored_trace(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	_stroked_trace(t, points, color, width)
	_stroked_trace(t, _mirror_y(points), color, width)

static func _stroked_trace(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	t.draw_polyline(points, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(points, color, width, true)

static func _stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.6) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float, fire_c: Color, nature_c: Color, earth_c: Color) -> void:
	var frame := _regular_poly(center, radius, 6, PI / 6.0)
	t.draw_colored_polygon(frame, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(frame, -1.3), Color(0.035, 0.031, 0.025, 0.88))
	_closed_polyline(t, frame, Color(1.0, 0.72, 0.28, 0.52), 0.9)

	var p1 := center + Vector2(0, -radius * 0.43)
	var p2 := center + Vector2(-radius * 0.43, radius * 0.30)
	var p3 := center + Vector2(radius * 0.43, radius * 0.30)
	_stroked_circle(t, p1, radius * 0.20, fire_c.lightened(0.16), 0.9)
	_stroked_circle(t, p2, radius * 0.20, nature_c.lightened(0.12), 0.9)
	_stroked_circle(t, p3, radius * 0.20, earth_c.lightened(0.12), 0.9)

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var drill_len := 25.0 + float(lvl) * 2.0

	var base := _poly([
		Vector2(-21, 0), Vector2(-15, -14), Vector2(5, -19), Vector2(22, -10),
		Vector2(25, 0), Vector2(22, 10), Vector2(5, 19), Vector2(-15, 14)
	])
	_outline_poly(t, base)

	var hammer := _poly([
		Vector2(-8, -9), Vector2(10, -13), Vector2(drill_len, -7), Vector2(drill_len + 8, 0),
		Vector2(drill_len, 7), Vector2(10, 13), Vector2(-8, 9)
	])
	_outline_poly(t, hammer)

	var bit := _poly([
		Vector2(drill_len + 5, 0), Vector2(drill_len + 14, -6), Vector2(drill_len + 18, 0), Vector2(drill_len + 14, 6)
	])
	_outline_poly(t, bit)

	_outline_circle(t, Vector2(-8, 0), 8.0)
	_outline_circle(t, Vector2(-22, -18), 3.8)
	_outline_circle(t, Vector2(20, -20), 3.8)
	_outline_circle(t, Vector2(-22, 20), 3.8)
	_outline_circle(t, Vector2(20, 20), 3.8)

	_outline_line(t, Vector2(-27, 24), Vector2(27, 24), 2.0)
	_outline_line(t, Vector2(-25, 29), Vector2(25, 29), 1.4)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var fire_c := Color(1.0, 0.34, 0.08, 1.0)
	var nature_c := Color(0.30, 0.92, 0.34, 1.0)
	var earth_c := Color(0.74, 0.58, 0.34, 1.0)
	if el_colors.size() >= 3:
		fire_c = el_colors[0]
		nature_c = el_colors[1]
		earth_c = el_colors[2]

	var stone := Color(0.36, 0.31, 0.25, 1.0)
	var dark_stone := Color(0.15, 0.13, 0.11, 1.0)
	var metal := Color(0.48, 0.45, 0.38, 1.0)
	var hot := fire_c.lightened(0.18)
	var quake := earth_c.lightened(0.16)
	var vine := nature_c.darkened(0.12)
	var drill_len := 25.0 + float(lvl) * 2.0

	# Static ground impact language: Quaker is wide-radius land splash, not a normal projectile tower.
	t.draw_arc(Vector2(0, 9), 28.0, deg_to_rad(25), deg_to_rad(155), 24, Color(earth_c.r, earth_c.g, earth_c.b, 0.11), 3.2, true)
	t.draw_arc(Vector2(0, 9), 35.0, deg_to_rad(32), deg_to_rad(148), 24, Color(fire_c.r, fire_c.g, fire_c.b, 0.07), 2.4, true)
	t.draw_arc(Vector2(0, 9), 22.0, deg_to_rad(205), deg_to_rad(335), 24, Color(earth_c.r, earth_c.g, earth_c.b, 0.10), 2.6, true)

	# Heavy bastion base.
	var base := _poly([
		Vector2(-21, 0), Vector2(-15, -14), Vector2(5, -19), Vector2(22, -10),
		Vector2(25, 0), Vector2(22, 10), Vector2(5, 19), Vector2(-15, 14)
	])
	_stroked_poly(t, base, stone, quake, 1.35)

	# Dark inset plates / cracked stone facets.
	var upper_plate := _poly([Vector2(-12, -8), Vector2(2, -13), Vector2(15, -7), Vector2(5, -3), Vector2(-8, -3)])
	var lower_plate := _mirror_y(upper_plate)
	_stroked_poly(t, upper_plate, dark_stone, Color(quake.r, quake.g, quake.b, 0.40), 0.8)
	_stroked_poly(t, lower_plate, dark_stone, Color(quake.r, quake.g, quake.b, 0.34), 0.8)
	_mirrored_trace(t, PackedVector2Array([
		Vector2(-12, -2),
		Vector2(-3, -6),
		Vector2(8, -5),
		Vector2(18, -2),
	]), Color(0.66, 1.0, 1.0, 0.22), 0.75)

	# Central seismic engine / molten quake core.
	_stroked_circle(t, Vector2(-8, 0), 8.0, Color(0.06, 0.045, 0.025, 0.94), 2.0)
	_stroked_circle(t, Vector2(-8, 0), 5.0, Color(hot.r, hot.g * 0.78, hot.b * 0.35, 0.92), 1.1)
	t.draw_circle(Vector2(-8, 0), 2.2, Color(1.0, 0.83, 0.28, 0.96))

	# Forward seismic hammer/drill head. Wide, heavy, and blunt to read as ground-pound AoE.
	var hammer := _poly([
		Vector2(-8, -9), Vector2(10, -13), Vector2(drill_len, -7), Vector2(drill_len + 8, 0),
		Vector2(drill_len, 7), Vector2(10, 13), Vector2(-8, 9)
	])
	_stroked_poly(t, hammer, metal, Color(0.95, 0.77, 0.44, 0.55), 1.2)

	var bit := _poly([
		Vector2(drill_len + 5, 0), Vector2(drill_len + 14, -6), Vector2(drill_len + 18, 0), Vector2(drill_len + 14, 6)
	])
	_stroked_poly(t, bit, Color(0.27, 0.24, 0.20, 1.0), hot, 1.05)

	# Drill grooves / seismic channels.
	_stroked_line(t, Vector2(3, -5.4), Vector2(drill_len + 4, -2.0), Color(1.0, 0.61, 0.18, 0.64), 1.1)
	_stroked_line(t, Vector2(3, 5.4), Vector2(drill_len + 4, 2.0), Color(1.0, 0.61, 0.18, 0.50), 1.1)
	_stroked_line(t, Vector2(9, 0), Vector2(drill_len + 11, 0), Color(0.11, 0.08, 0.04, 0.70), 1.0)
	_mirrored_trace(t, PackedVector2Array([
		Vector2(8, -8),
		Vector2(17, -9),
		Vector2(26, -5),
		Vector2(drill_len + 2, -3),
	]), Color(nature_c.r, nature_c.g, nature_c.b, 0.32), 0.8)

	# Nature-earth stabilizer vines: this is Fire + Nature + Earth, so it should not look like pure Earth only.
	var vine_top := _poly([Vector2(-18, -6), Vector2(-5, -17), Vector2(4, -15), Vector2(-6, -8)])
	var vine_bot := _poly([Vector2(-18, 7), Vector2(-5, 17), Vector2(4, 15), Vector2(-6, 8)])
	_stroked_poly(t, vine_top, Color(vine.r, vine.g, vine.b, 0.72), Color(nature_c.r, nature_c.g, nature_c.b, 0.52), 0.8)
	_stroked_poly(t, vine_bot, Color(vine.r, vine.g, vine.b, 0.62), Color(nature_c.r, nature_c.g, nature_c.b, 0.46), 0.8)

	# Corner quake anchors, replacing generic decoration with impact pylons.
	var anchor_fill := Color(0.10, 0.075, 0.045, 0.92)
	var anchor_line := Color(quake.r, quake.g, quake.b, 0.52)
	var anchors := [Vector2(-22, -18), Vector2(20, -20), Vector2(-22, 20), Vector2(20, 20)]
	for p in anchors:
		t.draw_circle(p, 7.0, Color(earth_c.r, earth_c.g, earth_c.b, 0.06))
		_stroked_circle(t, p, 3.8, anchor_fill, 1.2)
		t.draw_circle(p, 1.45, anchor_line)

	# Cracks / shock-wave scars on the ground: cheap static lines, clear AoE identity.
	var crack_c := Color(0.97, 0.66, 0.26, 0.62)
	_stroked_line(t, Vector2(-27, 24), Vector2(-8, 21), crack_c, 0.9)
	_stroked_line(t, Vector2(-8, 21), Vector2(0, 27), crack_c, 0.9)
	_stroked_line(t, Vector2(3, 24), Vector2(16, 20), crack_c, 0.9)
	_stroked_line(t, Vector2(16, 20), Vector2(27, 24), crack_c, 0.9)
	_stroked_line(t, Vector2(-25, 29), Vector2(25, 29), Color(earth_c.r, earth_c.g, earth_c.b, 0.34), 0.7)

	# Compact tri-element token, placed low so it does not obscure the seismic head.
	_draw_tri_element_token(t, Vector2(-2, 27), 7.0, fire_c, nature_c, earth_c)
