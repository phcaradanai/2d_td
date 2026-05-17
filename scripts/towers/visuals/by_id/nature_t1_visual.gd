extends RefCounted

# Tower: Nature Tower I
# Role: Bio-circuit rapid fire
# Elements: nature
# Visual source: custom by_id visual
# Visual intent: rapid organic twin-spitter; vine-wrapped accelerator with leaf reactor and clear forward axis.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _scaled(points: PackedVector2Array, center: Vector2, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		var dir := p - center
		if dir.length() > 0.001:
			out.append(p + dir.normalized() * amount)
		else:
			out.append(p)
	return out

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _outline_rect(t: Node2D, rect: Rect2) -> void:
	TowerVisualDrawUtils._draw_contour_rect(t, rect)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.0, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.6) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_leaf_shape(t: Node2D, center: Vector2, radius: float, rot: float, fill: Color, line_color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var angle := float(i) / 10.0 * TAU
		var local_r: float = radius * (0.62 + 0.38 * abs(cos(angle)))
		var p := Vector2(cos(angle) * local_r, sin(angle) * radius * 0.55)
		p = p.rotated(rot) + center
		pts.append(p)
	t.draw_colored_polygon(_scaled(pts, center, 1.6), DETAIL_OUTLINE)
	t.draw_colored_polygon(pts, fill)
	_draw_stroked_polyline(t, pts, line_color, 0.85)
	_draw_stroked_line(t, center - Vector2(cos(rot), sin(rot)) * radius * 0.40, center + Vector2(cos(rot), sin(rot)) * radius * 0.52, line_color, 0.75)

static func _draw_nature_element_icon(t: Node2D, center: Vector2, radius: float, main_color: Color) -> void:
	# Static Node2D version of the Nature element language: hex bio-token + leaf sprout.
	var token_color := main_color.lightened(0.12)
	var outer := _regular_poly(center, radius * 0.98, 6, PI / 6.0)
	var inner := _regular_poly(center, radius * 0.78, 6, PI / 6.0)

	t.draw_colored_polygon(_scaled(outer, center, 1.8), Color(token_color.r, token_color.g, token_color.b, 0.10))
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(outer, Color(0.012, 0.030, 0.018, 0.86))
	t.draw_colored_polygon(inner, Color(0.025, 0.095, 0.035, 0.76))
	_draw_stroked_polyline(t, outer, Color(token_color.r, token_color.g, token_color.b, 0.62), 1.05)
	_draw_stroked_polyline(t, inner, Color(token_color.r, token_color.g, token_color.b, 0.28), 0.8)

	_draw_leaf_shape(t, center + Vector2(-2.8, 0.4), radius * 0.36, -0.70, Color(0.48, 1.0, 0.34, 0.88), Color(0.76, 1.0, 0.58, 0.70))
	_draw_leaf_shape(t, center + Vector2(3.2, 0.6), radius * 0.34, 0.70, Color(0.32, 0.92, 0.30, 0.82), Color(0.72, 1.0, 0.55, 0.64))
	_draw_stroked_line(t, center + Vector2(0.0, 4.0), center + Vector2(0.0, -5.0), Color(0.72, 1.0, 0.42, 0.70), 0.9)

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var barrel_len := 24.0 + float(lvl) * 2.2

	# Organic diamond body / seed pod accelerator.
	var body := PackedVector2Array([
		Vector2(-19, 0),
		Vector2(-10, -15),
		Vector2(9, -15),
		Vector2(19, -6),
		Vector2(20, 6),
		Vector2(9, 15),
		Vector2(-10, 15),
	])
	_outline_poly(t, body)

	# Twin rapid-fire bio channels.
	_outline_rect(t, Rect2(3, -8.0, barrel_len, 4.7))
	_outline_rect(t, Rect2(3, 3.3, barrel_len, 4.7))
	_outline_line(t, Vector2(0, -5.6), Vector2(barrel_len + 7.0, -5.6), 3.4)
	_outline_line(t, Vector2(0, 5.6), Vector2(barrel_len + 7.0, 5.6), 3.4)

	# Leaf fins and rear element token.
	_outline_poly(t, PackedVector2Array([Vector2(-8, -18), Vector2(3, -25), Vector2(7, -14), Vector2(-2, -10)]))
	_outline_poly(t, PackedVector2Array([Vector2(-8, 18), Vector2(3, 25), Vector2(7, 14), Vector2(-2, 10)]))
	_outline_circle(t, Vector2(-9, 0), 8.0)

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, size: float, _el_colors: Array[Color]) -> void:
	var leaf := main_color.lightened(0.28)
	var lime := Color(0.62, 1.0, 0.34, 0.92)
	var sap := Color(0.18, 0.45, 0.16, 0.92)
	var deep := Color(0.018, 0.055, 0.028, 0.92)
	var vein := Color(0.72, 1.0, 0.44, 0.70)
	var barrel_len := 24.0 + float(lvl) * 2.2

	# Soft bio glow behind the compact rapid-fire tower.
	t.draw_circle(Vector2.ZERO, 18.5 + float(lvl) * 1.2, Color(main_color.r, main_color.g, main_color.b, 0.055))

	# Rear Nature token, visible but not overpowering the silhouette.
	_draw_nature_element_icon(t, Vector2(-10, 0), 8.8 + float(lvl) * 0.25, main_color)

	# Main organic seed-pod body.
	var body := PackedVector2Array([
		Vector2(-19, 0),
		Vector2(-10, -15),
		Vector2(9, -15),
		Vector2(19, -6),
		Vector2(20, 6),
		Vector2(9, 15),
		Vector2(-10, 15),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)
	t.draw_colored_polygon(_scaled(body, Vector2.ZERO, -2.1), deep)
	_draw_stroked_polyline(t, body, Color(leaf.r, leaf.g, leaf.b, 0.72), 1.25)

	# Inner bio-circuit plates. These imply very fast projectile cycling, not splash/aura.
	var upper_plate := PackedVector2Array([
		Vector2(-5, -11),
		Vector2(8, -10),
		Vector2(15, -5),
		Vector2(4, -3),
		Vector2(-7, -5),
	])
	var lower_plate := PackedVector2Array([
		Vector2(-5, 11),
		Vector2(8, 10),
		Vector2(15, 5),
		Vector2(4, 3),
		Vector2(-7, 5),
	])
	t.draw_colored_polygon(upper_plate, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_scaled(upper_plate, Vector2(3, -7), -1.1), Color(main_color.r, main_color.g, main_color.b, 0.24))
	_draw_stroked_polyline(t, upper_plate, Color(leaf.r, leaf.g, leaf.b, 0.45), 0.85)

	t.draw_colored_polygon(lower_plate, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(_scaled(lower_plate, Vector2(3, 7), -1.1), Color(main_color.r, main_color.g, main_color.b, 0.18))
	_draw_stroked_polyline(t, lower_plate, Color(leaf.r, leaf.g, leaf.b, 0.40), 0.85)

	# Symmetric leaf fins. They break the cannon silhouette and make it read as Nature.
	_draw_leaf_shape(t, Vector2(-1, -17.5), 7.4, -0.20, Color(0.25, 0.74, 0.25, 0.84), vein)
	_draw_leaf_shape(t, Vector2(-1, 17.5), 7.4, 0.20, Color(0.20, 0.64, 0.24, 0.80), vein)

	# Twin rapid-fire bio channels. No large muzzle orb: two small spitters = fast single-target fire.
	_draw_stroked_rect(t, Rect2(2.5, -8.0, barrel_len, 4.7), sap.darkened(0.18), 1.45)
	_draw_stroked_rect(t, Rect2(2.5, 3.3, barrel_len, 4.7), sap.darkened(0.18), 1.45)
	_draw_stroked_line(t, Vector2(2.0, -5.6), Vector2(barrel_len + 5.0, -5.6), lime, 1.7, true)
	_draw_stroked_line(t, Vector2(2.0, 5.6), Vector2(barrel_len + 5.0, 5.6), lime, 1.7, true)

	# Vine wraps across both channels. Cheap static diagonal rhythm = "rapid bio-circuit".
	for i in range(3):
		var x := 7.0 + float(i) * 7.2
		_draw_stroked_line(t, Vector2(x, -9.6), Vector2(x + 4.2, 1.2), Color(main_color.r, main_color.g, main_color.b, 0.52), 0.85, true)
		_draw_stroked_line(t, Vector2(x, 9.6), Vector2(x + 4.2, -1.2), Color(main_color.r, main_color.g, main_color.b, 0.42), 0.85, true)

	# Small seed tips instead of cannon muzzle.
	var tip_x := barrel_len + 5.8
	_draw_stroked_circle(t, Vector2(tip_x, -5.6), 2.3, Color(0.60, 1.0, 0.30, 0.86), 1.1)
	_draw_stroked_circle(t, Vector2(tip_x, 5.6), 2.3, Color(0.42, 0.88, 0.28, 0.82), 1.1)
	t.draw_circle(Vector2(tip_x + 2.4, -5.6), 1.3, Color(0.75, 1.0, 0.48, 0.42))
	t.draw_circle(Vector2(tip_x + 2.4, 5.6), 1.3, Color(0.75, 1.0, 0.48, 0.36))

	# Tiny bio pulse dots near the body: readable in catalog, still cheap in-game.
	var pulse_c := Color(main_color.r, main_color.g, main_color.b, 0.30)
	var pulse_core := Color(0.76, 1.0, 0.48, 0.62)
	var pulse_points := [
		Vector2(-19, -19),
		Vector2(-19, 19),
		Vector2(17, -18),
		Vector2(17, 18),
	]
	for p in pulse_points:
		t.draw_circle(p, 4.7, Color(main_color.r, main_color.g, main_color.b, 0.055))
		t.draw_arc(p, 3.3, 0.0, TAU, 16, DETAIL_OUTLINE_SOFT, 1.0, true)
		t.draw_arc(p, 2.7, 0.0, TAU, 16, pulse_c, 0.8, true)
		t.draw_circle(p, 1.15, pulse_core)
