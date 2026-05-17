extends RefCounted

# Tower: Disease Tower 1
# Role: Plague aura / vulnerability debuff
# Elements: darkness, nature
# Visual source: custom by_id visual
# Visual intent: plague spore reactor; reads as an aura/debuff tower, not a projectile cannon.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.64)

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var a := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, antialiased := true) -> void:
	var path := PackedVector2Array(points)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, color, width, antialiased)

static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke: Color = DETAIL_OUTLINE, stroke_width := 1.6) -> void:
	t.draw_colored_polygon(points, stroke)
	t.draw_colored_polygon(points, fill)
	_draw_closed_polyline(t, points, stroke, stroke_width + 1.4)
	_draw_closed_polyline(t, points, fill.lightened(0.28), max(0.8, stroke_width * 0.55))

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_ring(t: Node2D, center: Vector2, radius: float, color: Color, width := 1.2, points := 36) -> void:
	t.draw_arc(center, radius, 0.0, TAU, points, DETAIL_OUTLINE_SOFT, width + 1.6, true)
	t.draw_arc(center, radius, 0.0, TAU, points, color, width, true)

static func _draw_plague_spore(t: Node2D, center: Vector2, radius: float, main_color: Color, fill_alpha := 0.82) -> void:
	var sick := Color(main_color.r, main_color.g, main_color.b, fill_alpha)
	_draw_stroked_circle(t, center, radius, sick.darkened(0.22), 1.35)
	t.draw_circle(center + Vector2(-radius * 0.25, -radius * 0.22), radius * 0.28, Color(0.04, 0.015, 0.055, 0.82))
	t.draw_circle(center + Vector2(radius * 0.18, radius * 0.20), radius * 0.19, Color(0.10, 0.26, 0.06, 0.80))
	t.draw_circle(center + Vector2(radius * 0.05, -radius * 0.05), radius * 0.10, Color(0.84, 1.0, 0.28, 0.70))

static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, darkness_color: Color, nature_color: Color) -> void:
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var left := PackedVector2Array([
		center + Vector2(0, -radius * 0.78),
		center + Vector2(-radius * 0.78, -radius * 0.38),
		center + Vector2(-radius * 0.78, radius * 0.38),
		center + Vector2(0, radius * 0.78),
	])
	var right := PackedVector2Array([
		center + Vector2(0, -radius * 0.78),
		center + Vector2(radius * 0.78, -radius * 0.38),
		center + Vector2(radius * 0.78, radius * 0.38),
		center + Vector2(0, radius * 0.78),
	])

	t.draw_colored_polygon(_regular_poly(center, radius * 1.14, 8, PI / 8.0), Color(nature_color.r, nature_color.g, nature_color.b, 0.10))
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(left, darkness_color.darkened(0.22))
	t.draw_colored_polygon(right, nature_color.darkened(0.12))
	_draw_closed_polyline(t, outer, Color(0.70, 1.0, 0.40, 0.58), 1.0)
	_draw_stroked_line(t, center + Vector2(0, -radius * 0.62), center + Vector2(0, radius * 0.62), Color(0.58, 1.0, 0.32, 0.56), 0.9)
	t.draw_circle(center, radius * 0.22, Color(0.78, 1.0, 0.36, 0.76))

static func draw_contour(t: Node2D) -> void:
	var body := PackedVector2Array([
		Vector2(-18, -7),
		Vector2(-10, -18),
		Vector2(10, -18),
		Vector2(18, -7),
		Vector2(16, 10),
		Vector2(7, 18),
		Vector2(-7, 18),
		Vector2(-16, 10),
	])
	_outline_poly(t, body)

	# Plague aura ring and four static spore vents.
	_outline_circle(t, Vector2.ZERO, 18.0)
	_outline_circle(t, Vector2.ZERO, 9.0)
	_outline_circle(t, Vector2(-19, -12), 4.2)
	_outline_circle(t, Vector2(19, -12), 4.2)
	_outline_circle(t, Vector2(-19, 12), 4.2)
	_outline_circle(t, Vector2(19, 12), 4.2)

	# Thorny pylon silhouettes. These make it read as a debuff aura tower.
	_outline_line(t, Vector2(-16, 0), Vector2(-26, 0), 3.0)
	_outline_line(t, Vector2(16, 0), Vector2(26, 0), 3.0)
	_outline_line(t, Vector2(0, -16), Vector2(0, -25), 3.0)
	_outline_line(t, Vector2(0, 16), Vector2(0, 25), 3.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var darkness := Color(0.34, 0.12, 0.48, 1.0)
	var nature := Color(0.42, 0.92, 0.28, 1.0)
	if el_colors.size() > 0:
		darkness = el_colors[0]
	if el_colors.size() > 1:
		nature = el_colors[1]

	var plague := nature.lerp(darkness, 0.36)
	var acid := Color(0.74, 1.0, 0.24, 1.0)
	var body_dark := Color(0.055, 0.040, 0.070, 0.94)
	var sick_glow := Color(plague.r, plague.g, plague.b, 0.18)

	# Static aura language: Disease is an aura/vulnerability tower, so the ring is the identity.
	t.draw_circle(Vector2.ZERO, 24.0 + float(lvl), Color(plague.r, plague.g, plague.b, 0.055))
	_draw_ring(t, Vector2.ZERO, 20.0, Color(nature.r, nature.g, nature.b, 0.28), 1.0, 44)
	_draw_ring(t, Vector2.ZERO, 14.8, Color(darkness.r, darkness.g, darkness.b, 0.25), 0.9, 38)

	# Organic reactor body, symmetrical and compact.
	var body := PackedVector2Array([
		Vector2(-18, -7),
		Vector2(-10, -18),
		Vector2(10, -18),
		Vector2(18, -7),
		Vector2(16, 10),
		Vector2(7, 18),
		Vector2(-7, 18),
		Vector2(-16, 10),
	])
	_draw_stroked_poly(t, body, body_dark, DETAIL_OUTLINE, 1.5)

	# Sick membrane inside the body.
	var membrane := PackedVector2Array([
		Vector2(-12, -5),
		Vector2(-6, -12),
		Vector2(7, -12),
		Vector2(13, -4),
		Vector2(11, 7),
		Vector2(4, 12),
		Vector2(-6, 12),
		Vector2(-12, 6),
	])
	t.draw_colored_polygon(membrane, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(membrane, Color(plague.r, plague.g, plague.b, 0.24))
	_draw_closed_polyline(t, membrane, Color(nature.r, nature.g, nature.b, 0.36), 0.9)

	# Central plague vial / spore core.
	_draw_stroked_circle(t, Vector2.ZERO, 9.0, Color(0.075, 0.035, 0.105, 0.96), 2.0)
	t.draw_circle(Vector2.ZERO, 6.6, Color(plague.r, plague.g, plague.b, 0.48))
	t.draw_circle(Vector2.ZERO, 4.4, Color(0.20, 0.56, 0.10, 0.88))
	t.draw_circle(Vector2(-1.6, -1.4), 2.0, Color(0.80, 1.0, 0.32, 0.90))
	t.draw_arc(Vector2.ZERO, 6.0, PI * 0.12, PI * 1.30, 20, Color(0.92, 1.0, 0.46, 0.55), 1.0, true)

	# Biohazard-like glyph, simplified enough to stay readable at small scale.
	var glyph_c := Color(0.88, 1.0, 0.36, 0.78)
	var glyph_angles := [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]
	for a in glyph_angles:
		var p := Vector2(cos(a), sin(a)) * 4.2
		t.draw_arc(p, 2.5, a - 1.0, a + 1.0, 10, DETAIL_OUTLINE_SOFT, 1.7, true)
		t.draw_arc(p, 2.5, a - 1.0, a + 1.0, 10, glyph_c, 0.85, true)
	t.draw_circle(Vector2.ZERO, 1.15, glyph_c)

	# Four spore emitters show aura spread without adding particles.
	var spore_points := [
		Vector2(-19, -12),
		Vector2(19, -12),
		Vector2(-19, 12),
		Vector2(19, 12),
	]
	for p in spore_points:
		_draw_plague_spore(t, p, 4.2, plague, 0.80)
		t.draw_circle(p, 7.5, sick_glow)

	# Thorn pylons: static debuff spikes, not gun barrels.
	var pylon_c := Color(darkness.r, darkness.g, darkness.b, 0.76)
	_draw_stroked_line(t, Vector2(-14, 0), Vector2(-25, 0), pylon_c, 2.1)
	_draw_stroked_line(t, Vector2(14, 0), Vector2(25, 0), pylon_c, 2.1)
	_draw_stroked_line(t, Vector2(0, -14), Vector2(0, -24), pylon_c, 2.1)
	_draw_stroked_line(t, Vector2(0, 14), Vector2(0, 24), pylon_c, 2.1)

	# Small poison/vulnerability ticks around the ring.
	for i in range(8):
		var a := float(i) / 8.0 * TAU + PI / 8.0
		var p1 := Vector2(cos(a), sin(a)) * 17.0
		var p2 := Vector2(cos(a), sin(a)) * 19.8
		_draw_stroked_line(t, p1, p2, Color(acid.r, acid.g, acid.b, 0.42), 0.85)

	# Dual element badge, small and secondary so the plague core remains the hero.
	_draw_dual_element_token(t, Vector2(0, 25), 5.3, darkness, nature)
