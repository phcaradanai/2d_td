extends RefCounted

# Tower: Jinx Tower 1
# Role: Cursed lightning chain tower — chain bolts that hex enemies and amplify damage taken.
# Elements: Light + Darkness + Fire
# Visual source: custom by_id visual
# Visual intent: curse-conductor / hex lightning pylon with chain relays, not a generic lightning fallback.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

const LIGHT_C := Color(1.0, 0.92, 0.36, 1.0)
const DARK_C := Color(0.42, 0.16, 0.72, 1.0)
const FIRE_C := Color(1.0, 0.34, 0.12, 1.0)
const HEX_C := Color(0.75, 0.22, 1.0, 1.0)
const METAL_DARK := Color(0.12, 0.10, 0.16, 1.0)
const METAL_MID := Color(0.27, 0.22, 0.33, 1.0)
const METAL_HI := Color(0.50, 0.42, 0.56, 1.0)
const CATALOG_FIT_SCALE := 0.94


static func _scaled_poly(points: Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x * s, p.y * s))
	return out


static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)


static func _outline_circle(t: Node2D, pos: Vector2, r: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, pos, r)


static func _draw_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	_outline_poly(t, points)
	t.draw_colored_polygon(points, color)


static func _draw_circle(t: Node2D, pos: Vector2, r: float, color: Color) -> void:
	_outline_circle(t, pos, r)
	t.draw_circle(pos, r, color)


static func _draw_stroked_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(a, b, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_line(a, b, color, width, true)


static func _draw_stroked_polyline(t: Node2D, points: Array, color: Color, width: float, closed: bool = false) -> void:
	var path := PackedVector2Array()
	for p in points:
		path.append(p)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)


static func _mirrored_y(points: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in points:
		var v: Vector2 = p
		out.append(Vector2(v.x, -v.y))
	return out


static func _draw_mirrored_trace(t: Node2D, points: Array, color: Color, width: float) -> void:
	_draw_stroked_polyline(t, points, color, width, false)
	_draw_stroked_polyline(t, _mirrored_y(points), color, width, false)


static func _draw_stroked_arc(t: Node2D, center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: float) -> void:
	t.draw_arc(center, radius, from_angle, to_angle, 20, DETAIL_OUTLINE, width + 2.0, true)
	t.draw_arc(center, radius, from_angle, to_angle, 20, color, width, true)


static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rotation + TAU * float(i) / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func _draw_hex_mark(t: Node2D, center: Vector2, s: float, color: Color) -> void:
	var hex := _regular_poly(center, 6.2 * s, 6, PI / 6.0)
	_outline_poly(t, hex)
	t.draw_colored_polygon(hex, Color(color.r, color.g, color.b, 0.42))
	_draw_stroked_line(t, center + Vector2(-3.2, -2.0) * s, center + Vector2(3.2, 2.0) * s, color, 1.05 * s)
	_draw_stroked_line(t, center + Vector2(-3.0, 2.2) * s, center + Vector2(3.0, -2.2) * s, color, 1.05 * s)


static func _draw_tri_element_token(t: Node2D, center: Vector2, s: float, el_colors: Array[Color]) -> void:
	var c_light := LIGHT_C
	var c_dark := DARK_C
	var c_fire := FIRE_C
	if el_colors.size() >= 3:
		c_light = el_colors[0]
		c_dark = el_colors[1]
		c_fire = el_colors[2]

	_draw_circle(t, center, 9.0 * s, Color(0.06, 0.05, 0.08, 0.92))
	var left := PackedVector2Array([
		center + Vector2(-7.0, -5.0) * s,
		center + Vector2(0.0, -1.0) * s,
		center + Vector2(-1.0, 7.0) * s,
		center + Vector2(-7.0, 5.0) * s,
	])
	var right := PackedVector2Array([
		center + Vector2(0.0, -1.0) * s,
		center + Vector2(7.0, -5.0) * s,
		center + Vector2(7.0, 5.0) * s,
		center + Vector2(1.0, 7.0) * s,
	])
	var top := PackedVector2Array([
		center + Vector2(-7.0, -5.0) * s,
		center + Vector2(0.0, -9.0) * s,
		center + Vector2(7.0, -5.0) * s,
		center + Vector2(0.0, -1.0) * s,
	])
	t.draw_colored_polygon(left, Color(c_dark.r, c_dark.g, c_dark.b, 0.88))
	t.draw_colored_polygon(right, Color(c_fire.r, c_fire.g, c_fire.b, 0.88))
	t.draw_colored_polygon(top, Color(c_light.r, c_light.g, c_light.b, 0.9))
	t.draw_arc(center, 9.4 * s, 0.0, TAU, 28, DETAIL_OUTLINE, 1.2 * s, true)


static func draw_contour(t: Node2D) -> void:
	var s := CATALOG_FIT_SCALE

	# Broad support base and shadow silhouette.
	_outline_poly(t, _scaled_poly([
		Vector2(-23.0, 14.0), Vector2(-17.0, 4.0), Vector2(-8.0, 0.0),
		Vector2(0.0, -5.0), Vector2(8.0, 0.0), Vector2(17.0, 4.0),
		Vector2(23.0, 14.0), Vector2(18.0, 22.0), Vector2(-18.0, 22.0),
	], s))

	# Main cursed conductor body.
	_outline_poly(t, _regular_poly(Vector2(0, -3) * s, 19.0 * s, 6, PI / 6.0))

	# Relay nodes for chain jumps.
	for p in [Vector2(-22, -8), Vector2(22, -8), Vector2(-17, 18), Vector2(17, 18)]:
		_outline_circle(t, p * s, 5.6 * s)

	# Upper forked lightning crown.
	_outline_poly(t, _scaled_poly([
		Vector2(-4.0, -20.0), Vector2(2.0, -20.0), Vector2(-1.5, -9.0),
		Vector2(8.0, -13.0), Vector2(1.0, 2.0), Vector2(3.0, -7.0),
		Vector2(-8.0, -2.0), Vector2(-1.5, -10.0),
	], s))


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Renderer/catalog may pass a larger preview scale value.
	# Do NOT multiply by `size`; by_id tower visuals are authored in local pixels like the other catalog-safe files.
	var s := CATALOG_FIT_SCALE * (1.0 + float(max(lvl - 1, 0)) * 0.05)
	var c_light := LIGHT_C
	var c_dark := DARK_C
	var c_fire := FIRE_C
	if el_colors.size() >= 3:
		c_light = el_colors[0]
		c_dark = el_colors[1]
		c_fire = el_colors[2]

	# Static mirrored aura arcs: hex/vulnerability field, not moving particles.
	_draw_stroked_arc(t, Vector2.ZERO, 29.0 * s, deg_to_rad(205), deg_to_rad(335), Color(c_dark.r, c_dark.g, c_dark.b, 0.42), 1.7 * s)
	_draw_stroked_arc(t, Vector2.ZERO, 29.0 * s, deg_to_rad(25), deg_to_rad(155), Color(c_dark.r, c_dark.g, c_dark.b, 0.34), 1.7 * s)
	_draw_stroked_arc(t, Vector2.ZERO, 22.0 * s, deg_to_rad(-34), deg_to_rad(34), Color(c_fire.r, c_fire.g, c_fire.b, 0.34), 1.4 * s)
	_draw_stroked_arc(t, Vector2.ZERO, 22.0 * s, deg_to_rad(146), deg_to_rad(214), Color(c_light.r, c_light.g, c_light.b, 0.36), 1.4 * s)

	# Heavy base.
	var base := _scaled_poly([
		Vector2(-23.0, 14.0), Vector2(-17.0, 4.0), Vector2(-8.0, 0.0),
		Vector2(0.0, -5.0), Vector2(8.0, 0.0), Vector2(17.0, 4.0),
		Vector2(23.0, 14.0), Vector2(18.0, 22.0), Vector2(-18.0, 22.0),
	], s)
	_draw_poly(t, base, METAL_DARK)

	var base_inner := _scaled_poly([
		Vector2(-15.5, 13.0), Vector2(-9.0, 7.0), Vector2(0.0, 3.5),
		Vector2(9.0, 7.0), Vector2(15.5, 13.0), Vector2(11.0, 18.0),
		Vector2(-11.0, 18.0),
	], s)
	_draw_poly(t, base_inner, METAL_MID)

	# Relay nodes and static chain paths. Top traces are mirrored across the center axis.
	var relays: Array[Vector2] = [Vector2(-22, -10) * s, Vector2(22, -10) * s, Vector2(-22, 10) * s, Vector2(22, 10) * s]
	_draw_mirrored_trace(t, [relays[0], Vector2(0, -14) * s, relays[1]], Color(c_light.r, c_light.g, c_light.b, 0.72), 1.35 * s)
	_draw_mirrored_trace(t, [relays[0], Vector2(-12, -3) * s, Vector2(0, -6) * s], Color(c_dark.r, c_dark.g, c_dark.b, 0.48), 0.95 * s)
	_draw_mirrored_trace(t, [relays[1], Vector2(12, -3) * s, Vector2(0, -6) * s], Color(c_fire.r, c_fire.g, c_fire.b, 0.48), 0.95 * s)

	for i in range(relays.size()):
		var p: Vector2 = relays[i]
		var node_col: Color = c_dark
		if i == 1:
			node_col = c_fire
		elif i >= 2:
			node_col = Color(HEX_C.r, HEX_C.g, HEX_C.b, 1.0)
		_draw_circle(t, p, 5.6 * s, Color(0.07, 0.05, 0.09, 1.0))
		_draw_circle(t, p, 3.2 * s, Color(node_col.r, node_col.g, node_col.b, 0.95))

	# Main hex-conductor body.
	var body := _regular_poly(Vector2(0, -3) * s, 19.0 * s, 6, PI / 6.0)
	_draw_poly(t, body, Color(0.16, 0.10, 0.22, 1.0))

	var body_plate := _regular_poly(Vector2(0, -3) * s, 14.6 * s, 6, PI / 6.0)
	_draw_poly(t, body_plate, Color(0.24, 0.16, 0.32, 1.0))

	# Three-element reactor core.
	_draw_circle(t, Vector2(0, -3) * s, 10.0 * s, Color(0.05, 0.04, 0.07, 1.0))
	t.draw_arc(Vector2(0, -3) * s, 7.9 * s, deg_to_rad(210), deg_to_rad(330), 18, c_dark, 3.0 * s, true)
	t.draw_arc(Vector2(0, -3) * s, 7.9 * s, deg_to_rad(-35), deg_to_rad(85), 18, c_fire, 3.0 * s, true)
	t.draw_arc(Vector2(0, -3) * s, 7.9 * s, deg_to_rad(90), deg_to_rad(200), 18, c_light, 3.0 * s, true)
	_draw_hex_mark(t, Vector2(0, -3) * s, s, Color(0.95, 0.62, 1.0, 1.0))

	# Centered forked curse emitter, mirrored from the center axis.
	var top_bolt := [
		Vector2(-7.0, -20.0) * s,
		Vector2(1.0, -17.0) * s,
		Vector2(-2.0, -10.0) * s,
		Vector2(9.0, -13.0) * s,
	]
	_draw_mirrored_trace(t, top_bolt, Color(c_light.r, c_light.g, c_light.b, 0.86), 1.25 * s)
	_draw_mirrored_trace(t, [Vector2(-2, -14) * s, Vector2(-8, -8) * s], Color(c_dark.r, c_dark.g, c_dark.b, 0.72), 1.05 * s)
	_draw_mirrored_trace(t, [Vector2(2, -14) * s, Vector2(8, -8) * s], Color(c_fire.r, c_fire.g, c_fire.b, 0.72), 1.05 * s)

	# Curse/vulnerability thorns.
	for p in [Vector2(-12, -13), Vector2(12, -13), Vector2(-12, 7), Vector2(12, 7)]:
		var tri := _scaled_poly([
			p + Vector2(0, -4),
			p + Vector2(4, 3),
			p + Vector2(-4, 3),
		], s)
		_draw_poly(t, tri, Color(0.46, 0.12, 0.70, 0.96))

	# Static outbound mini bolts to sell chain attack, mirrored from the center axis.
	_draw_mirrored_trace(t, [Vector2(8, -19) * s, Vector2(16, -23) * s, Vector2(22, -19) * s], Color(c_light.r, c_light.g, c_light.b, 0.62), 1.05 * s)
	_draw_mirrored_trace(t, [Vector2(-8, -18) * s, Vector2(-16, -22) * s, Vector2(-23, -18) * s], Color(c_dark.r, c_dark.g, c_dark.b, 0.58), 1.05 * s)

	# Tri-element badge near bottom.
	_draw_tri_element_token(t, Vector2(0, 23.0) * s, 0.75 * s, [c_light, c_dark, c_fire])

	# Small level/premium ticks.
	for x in [-9.0, 0.0, 9.0]:
		_draw_stroked_line(t, Vector2(x - 2.5, 12.0) * s, Vector2(x + 2.5, 12.0) * s, Color(0.92, 0.62, 1.0, 0.78), 1.0 * s)
