extends RefCounted
class_name TowerVisualTrickeryT1

# Tower: Trickery Tower 1
# Role: Illusionist / clone support
# Elements: Light, Darkness
# Visual source: custom by_id visual
# Visual intent: hologram projector that creates mirror-clones of nearby towers.
#   This should read as support/illusion, not as a normal damage cannon.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var a := float(i) / float(sides) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := _closed(points) if closed else PackedVector2Array(points)
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.1, true)
	t.draw_line(from, to, color, width, true)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.6) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, light_col: Color, dark_col: Color) -> void:
	# Compact Light + Darkness token. It replaces the generic element core and
	# makes the tower identity readable in catalog previews.
	var token := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(_regular_poly(center, radius + 2.0, 8, PI / 8.0), Color(light_col.r, light_col.g, light_col.b, 0.08))
	t.draw_colored_polygon(token, DETAIL_OUTLINE)

	var left_half := PackedVector2Array([
		center + Vector2(0, -radius * 0.85),
		center + Vector2(0, radius * 0.85),
		center + Vector2(-radius * 0.72, radius * 0.34),
		center + Vector2(-radius * 0.92, 0),
		center + Vector2(-radius * 0.72, -radius * 0.34),
	])
	var right_half := PackedVector2Array([
		center + Vector2(0, -radius * 0.85),
		center + Vector2(radius * 0.72, -radius * 0.34),
		center + Vector2(radius * 0.92, 0),
		center + Vector2(radius * 0.72, radius * 0.34),
		center + Vector2(0, radius * 0.85),
	])
	t.draw_colored_polygon(left_half, Color(dark_col.r, dark_col.g, dark_col.b, 0.86))
	t.draw_colored_polygon(right_half, Color(light_col.r, light_col.g, light_col.b, 0.70))
	_draw_stroked_polyline(t, token, Color(light_col.r, light_col.g, light_col.b, 0.52), 0.8)
	_draw_stroked_line(t, center + Vector2(0, -radius * 0.72), center + Vector2(0, radius * 0.72), Color(1.0, 1.0, 0.85, 0.42), 0.75)

static func draw_contour(t: Node2D) -> void:
	# Main hologram prism body.
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(0, -23),
		Vector2(18, -8),
		Vector2(18, 8),
		Vector2(0, 22),
		Vector2(-18, 8),
		Vector2(-18, -8),
	]))

	# Echo bodies show that this is a clone-support projector, not a cannon.
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(-11, -16),
		Vector2(-2, -9),
		Vector2(-2, 9),
		Vector2(-11, 16),
		Vector2(-20, 8),
		Vector2(-20, -8),
	]))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(11, -16),
		Vector2(20, -8),
		Vector2(20, 8),
		Vector2(11, 16),
		Vector2(2, 9),
		Vector2(2, -9),
	]))

	# Projector core and static illusion rings.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 7.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 14.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-24, 0), Vector2(24, 0), 1.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(0, -25), Vector2(0, 23), 1.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var light_col := el_colors[0] if not el_colors.is_empty() else Color(1.0, 0.94, 0.55)
	var dark_col := el_colors[1] if el_colors.size() >= 2 else Color(0.22, 0.05, 0.36)
	var deep_void := Color(0.035, 0.018, 0.060, 0.96)

	# Soft static aura. It hints at clone projection without continuous particles.
	t.draw_circle(Vector2.ZERO, 25.0, Color(dark_col.r, dark_col.g, dark_col.b, 0.08))
	t.draw_circle(Vector2.ZERO, 19.0, Color(light_col.r, light_col.g, light_col.b, 0.055))

	# Faint clone echoes on both sides.
	var left_echo := PackedVector2Array([
		Vector2(-11, -16),
		Vector2(-2, -9),
		Vector2(-2, 9),
		Vector2(-11, 16),
		Vector2(-20, 8),
		Vector2(-20, -8),
	])
	var right_echo := PackedVector2Array([
		Vector2(11, -16),
		Vector2(20, -8),
		Vector2(20, 8),
		Vector2(11, 16),
		Vector2(2, 9),
		Vector2(2, -9),
	])
	t.draw_colored_polygon(left_echo, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(left_echo, Color(dark_col.r, dark_col.g, dark_col.b, 0.18))
	_draw_stroked_polyline(t, left_echo, Color(dark_col.r, dark_col.g, dark_col.b, 0.34), 0.8)
	t.draw_colored_polygon(right_echo, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(right_echo, Color(light_col.r, light_col.g, light_col.b, 0.16))
	_draw_stroked_polyline(t, right_echo, Color(light_col.r, light_col.g, light_col.b, 0.38), 0.8)

	# Main hex-prism projector body.
	var body := PackedVector2Array([
		Vector2(0, -23),
		Vector2(18, -8),
		Vector2(18, 8),
		Vector2(0, 22),
		Vector2(-18, 8),
		Vector2(-18, -8),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)

	var left_body := PackedVector2Array([
		Vector2(0, -20),
		Vector2(0, 19),
		Vector2(-15, 7),
		Vector2(-15, -7),
	])
	var right_body := PackedVector2Array([
		Vector2(0, -20),
		Vector2(15, -7),
		Vector2(15, 7),
		Vector2(0, 19),
	])
	t.draw_colored_polygon(left_body, Color(dark_col.r, dark_col.g, dark_col.b, 0.74))
	t.draw_colored_polygon(right_body, Color(light_col.r, light_col.g, light_col.b, 0.46))

	# Mirrored inner facets for premium prism detail.
	var upper_facet := PackedVector2Array([
		Vector2(-11, -7),
		Vector2(0, -17),
		Vector2(11, -7),
		Vector2(0, -4),
	])
	var lower_facet := PackedVector2Array([
		Vector2(-11, 7),
		Vector2(0, 17),
		Vector2(11, 7),
		Vector2(0, 4),
	])
	t.draw_colored_polygon(upper_facet, Color(1.0, 1.0, 0.72, 0.16))
	t.draw_colored_polygon(lower_facet, Color(0.38, 0.08, 0.70, 0.22))
	_draw_stroked_polyline(t, upper_facet, Color(light_col.r, light_col.g, light_col.b, 0.45), 0.75)
	_draw_stroked_polyline(t, lower_facet, Color(dark_col.r, dark_col.g, dark_col.b, 0.45), 0.75)

	# Main body trim and split axis.
	_draw_stroked_polyline(t, body, Color(light_col.r, light_col.g, light_col.b, 0.72), 1.2)
	_draw_stroked_line(t, Vector2(0, -20), Vector2(0, 19), Color(0.92, 0.96, 1.0, 0.42), 0.9)

	# Hologram projection rings. These are static arcs, not runtime VFX.
	t.draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, DETAIL_OUTLINE_SOFT, 1.45, true)
	t.draw_arc(Vector2.ZERO, 13.0, -PI * 0.92, PI * 0.12, 18, Color(light_col.r, light_col.g, light_col.b, 0.46), 1.1, true)
	t.draw_arc(Vector2.ZERO, 13.0, PI * 0.08, PI * 1.10, 18, Color(dark_col.r, dark_col.g, dark_col.b, 0.50), 1.1, true)
	t.draw_arc(Vector2.ZERO, 20.5, -PI * 0.28, PI * 0.28, 14, Color(light_col.r, light_col.g, light_col.b, 0.22), 0.9, true)
	t.draw_arc(Vector2.ZERO, 20.5, PI * 0.72, PI * 1.28, 14, Color(dark_col.r, dark_col.g, dark_col.b, 0.28), 0.9, true)

	# Central lens: clone projector rather than weapon muzzle.
	_draw_stroked_circle(t, Vector2.ZERO, 7.0, deep_void, 1.8)
	t.draw_circle(Vector2.ZERO, 4.6, Color(0.18, 0.06, 0.28, 0.96))
	t.draw_circle(Vector2(-1.6, -1.2), 2.0, Color(light_col.r, light_col.g, light_col.b, 0.72))
	t.draw_circle(Vector2(1.5, 1.2), 1.8, Color(dark_col.r, dark_col.g, dark_col.b, 0.88))
	t.draw_circle(Vector2.ZERO, 1.1, Color(0.84, 0.96, 1.0, 0.95))

	# Four small hologram nodes show clone-link support.
	var node_points := [
		Vector2(-23, -13),
		Vector2(23, -13),
		Vector2(-23, 13),
		Vector2(23, 13),
	]
	for i in range(node_points.size()):
		var p: Vector2 = node_points[i]
		var c := light_col if i % 2 == 1 else dark_col.lightened(0.25)
		t.draw_circle(p, 4.8, Color(c.r, c.g, c.b, 0.09))
		t.draw_arc(p, 3.4, 0.0, TAU, 16, DETAIL_OUTLINE_SOFT, 1.0, true)
		t.draw_arc(p, 2.7, 0.0, TAU, 16, Color(c.r, c.g, c.b, 0.55), 0.8, true)
		t.draw_circle(p, 1.25, Color(c.r, c.g, c.b, 0.68))

	# Thin clone-link beams from side echoes to core.
	_draw_stroked_line(t, Vector2(-16, 0), Vector2(-7, 0), Color(dark_col.r, dark_col.g, dark_col.b, 0.38), 0.75)
	_draw_stroked_line(t, Vector2(16, 0), Vector2(7, 0), Color(light_col.r, light_col.g, light_col.b, 0.40), 0.75)

	# Mini dual-element token tucked behind the core; small enough not to obscure the projector.
	_draw_dual_element_token(t, Vector2(0, 25), 5.6, light_col, dark_col)
