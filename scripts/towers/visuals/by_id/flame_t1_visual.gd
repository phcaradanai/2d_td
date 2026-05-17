extends RefCounted

# Tower: Flame Tower 1
# Role: Inferno aura / vulnerability burn
# Elements: fire, nature
# Visual source: custom by_id visual
# Visual intent: living ember bloom aura tower; reads as fire+nature debuff aura, not a projectile cannon.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var p := PackedVector2Array(points)
	if p.size() > 0:
		p.append(p[0])
	return p

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_line(from, to, color, width, true)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_petal(t: Node2D, dir: Vector2, length: float, width: float, fill: Color, edge: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var base := dir * 5.0
	var points := PackedVector2Array([
		base - n * width,
		dir * length - n * width * 0.34,
		dir * (length + 4.0),
		dir * length + n * width * 0.34,
		base + n * width,
	])
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(points, -1.4), fill)
	_draw_stroked_polyline(t, points, edge, 1.0)

static func _draw_leaf(t: Node2D, dir: Vector2, length: float, width: float, fill: Color, edge: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var base := dir * 4.0
	var points := PackedVector2Array([
		base - n * width * 0.75,
		dir * (length * 0.70) - n * width,
		dir * length,
		dir * (length * 0.70) + n * width,
		base + n * width * 0.75,
	])
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(points, -1.2), fill)
	_draw_stroked_polyline(t, points, edge, 0.9)

static func _draw_dual_fire_nature_token(t: Node2D, center: Vector2, radius: float, fire_c: Color, nature_c: Color) -> void:
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.78, 8, PI / 8.0)
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(outer, -1.1), Color(0.035, 0.030, 0.018, 0.86))
	_draw_stroked_polyline(t, outer, Color(fire_c.r, fire_c.g, fire_c.b, 0.54), 0.8)
	_draw_stroked_polyline(t, inner, Color(nature_c.r, nature_c.g, nature_c.b, 0.48), 0.7)

	var flame := PackedVector2Array([
		center + Vector2(-3.2, 3.8),
		center + Vector2(-4.4, -0.8),
		center + Vector2(-1.0, -6.2),
		center + Vector2(1.5, -1.2),
		center + Vector2(3.5, -4.0),
		center + Vector2(3.0, 3.8),
	])
	t.draw_colored_polygon(flame, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(flame, -0.8), Color(1.0, 0.34, 0.06, 0.92))

	var leaf := PackedVector2Array([
		center + Vector2(0.0, 4.8),
		center + Vector2(4.9, 1.2),
		center + Vector2(6.0, -3.7),
		center + Vector2(1.1, -1.4),
	])
	t.draw_colored_polygon(leaf, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(leaf, -0.7), Color(nature_c.r, nature_c.g, nature_c.b, 0.72))

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var body := PackedVector2Array([
		Vector2(-14, -10),
		Vector2(0, -18),
		Vector2(14, -10),
		Vector2(17, 5),
		Vector2(8, 17),
		Vector2(-8, 17),
		Vector2(-17, 5),
	])
	_outline_poly(t, body)
	_outline_circle(t, Vector2.ZERO, 11.0 + float(lvl) * 0.6)
	for p in [Vector2(-18, -14), Vector2(18, -14), Vector2(-18, 14), Vector2(18, 14)]:
		_outline_circle(t, p, 3.6)


static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var fire_c := main_color
	var nature_c := secondary_color
	if el_colors.size() >= 2:
		fire_c = el_colors[0]
		nature_c = el_colors[1]

	var ember := fire_c.lightened(0.28)
	var hot := Color(1.0, 0.56, 0.08, 0.96)
	var yellow := Color(1.0, 0.88, 0.34, 0.94)
	var green := nature_c.lightened(0.18)
	var body_dark := Color(0.09, 0.035, 0.018, 0.92)
	var metal := Color(0.18, 0.105, 0.055, 0.94)

	# Static aura language: this is an inferno aura / vulnerability tower, not a projectile weapon.
	t.draw_circle(Vector2.ZERO, 27.0 + float(lvl) * 1.5, Color(fire_c.r, fire_c.g, fire_c.b, 0.055))
	t.draw_arc(Vector2.ZERO, 22.0, -0.30, PI * 0.76, 32, DETAIL_OUTLINE_SOFT, 2.2, true)
	t.draw_arc(Vector2.ZERO, 22.0, -0.30, PI * 0.76, 32, Color(fire_c.r, fire_c.g, fire_c.b, 0.32), 1.15, true)
	t.draw_arc(Vector2.ZERO, 22.0, PI - 0.30, PI * 1.76, 32, DETAIL_OUTLINE_SOFT, 2.2, true)
	t.draw_arc(Vector2.ZERO, 22.0, PI - 0.30, PI * 1.76, 32, Color(fire_c.r, fire_c.g, fire_c.b, 0.32), 1.15, true)
	t.draw_arc(Vector2.ZERO, 27.0, PI * 0.20, PI * 0.80, 24, Color(green.r, green.g, green.b, 0.25), 1.0, true)
	t.draw_arc(Vector2.ZERO, 27.0, PI * 1.20, PI * 1.80, 24, Color(green.r, green.g, green.b, 0.20), 1.0, true)

	# Living ember bloom petals: fire petals + nature leaves, symmetric and readable at small size.
	_draw_petal(t, Vector2(0, -1), 22.0, 5.2, Color(fire_c.r, fire_c.g, fire_c.b, 0.62), Color(ember.r, ember.g, ember.b, 0.78))
	_draw_petal(t, Vector2(0.82, -0.58).normalized(), 20.0, 4.5, Color(fire_c.r, fire_c.g, fire_c.b, 0.50), Color(ember.r, ember.g, ember.b, 0.62))
	_draw_petal(t, Vector2(-0.82, -0.58).normalized(), 20.0, 4.5, Color(fire_c.r, fire_c.g, fire_c.b, 0.50), Color(ember.r, ember.g, ember.b, 0.62))
	_draw_leaf(t, Vector2(0.92, 0.42).normalized(), 20.0, 4.6, Color(green.r, green.g, green.b, 0.54), Color(green.r, green.g, green.b, 0.72))
	_draw_leaf(t, Vector2(-0.92, 0.42).normalized(), 20.0, 4.6, Color(green.r, green.g, green.b, 0.54), Color(green.r, green.g, green.b, 0.72))

	# Reinforced central seed/furnace body.
	var body := PackedVector2Array([
		Vector2(-14, -10),
		Vector2(0, -18),
		Vector2(14, -10),
		Vector2(17, 5),
		Vector2(8, 17),
		Vector2(-8, 17),
		Vector2(-17, 5),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(body, -1.7), body_dark)
	_draw_stroked_polyline(t, body, Color(ember.r, ember.g, ember.b, 0.54), 1.0)

	# Molten bio-reactor core with vulnerability spikes.
	_draw_stroked_circle(t, Vector2.ZERO, 11.0 + float(lvl) * 0.45, metal, 2.0)
	_draw_stroked_circle(t, Vector2.ZERO, 7.4 + float(lvl) * 0.25, Color(0.23, 0.050, 0.025, 0.96), 1.4)
	var inner_flame := PackedVector2Array([
		Vector2(-4.5, 4.6),
		Vector2(-5.7, -0.4),
		Vector2(-1.7, -7.7),
		Vector2(0.9, -1.8),
		Vector2(4.2, -5.2),
		Vector2(5.0, 4.6),
	])
	t.draw_colored_polygon(inner_flame, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(inner_flame, -0.9), hot)
	var inner_leaf := PackedVector2Array([
		Vector2(-1.2, 5.2),
		Vector2(4.2, 1.5),
		Vector2(5.1, -2.6),
		Vector2(0.8, -1.0),
	])
	t.draw_colored_polygon(inner_leaf, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(inner_leaf, -0.55), Color(green.r, green.g, green.b, 0.64))
	t.draw_circle(Vector2(0.0, -0.7), 2.2, yellow)

	# Aura pylons: small bloom nodes around the tower to signal nearby burn/amplify effect.
	var pylon_fill := Color(0.10, 0.045, 0.018, 0.94)
	for p in [Vector2(-18, -14), Vector2(18, -14), Vector2(-18, 14), Vector2(18, 14)]:
		_draw_stroked_circle(t, p, 3.6, pylon_fill, 1.4)
		t.draw_circle(p, 1.7, Color(fire_c.r, fire_c.g, fire_c.b, 0.62))
		t.draw_circle(p, 0.85, Color(green.r, green.g, green.b, 0.65))

	# Short thorn/ember marks around body: communicates vulnerability amplifier without target lines.
	_draw_stroked_line(t, Vector2(-11, -2), Vector2(-20, -4), Color(fire_c.r, fire_c.g, fire_c.b, 0.48), 0.9)
	_draw_stroked_line(t, Vector2(11, -2), Vector2(20, -4), Color(fire_c.r, fire_c.g, fire_c.b, 0.48), 0.9)
	_draw_stroked_line(t, Vector2(-8, 8), Vector2(-16, 12), Color(green.r, green.g, green.b, 0.42), 0.9)
	_draw_stroked_line(t, Vector2(8, 8), Vector2(16, 12), Color(green.r, green.g, green.b, 0.42), 0.9)

	# Compact dual token, placed low so it does not hide the aura/core silhouette.
	_draw_dual_fire_nature_token(t, Vector2(0, 25), 6.2, fire_c, nature_c)
