extends RefCounted

# Tower: Light Tower I
# Role: Precision Sniper
# Elements: Light
# Visual source: custom by_id visual
# Visual intent: symmetrical holy prism cannon; clear forward axis, centered lens, readable muzzle.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

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
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2)
	t.draw_polyline(path, color, width)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.7) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	t.draw_polyline(closed, color, width, true)


static func _draw_light_element_icon(t: Node2D, center: Vector2, radius: float, main_color: Color) -> void:
	# Same visual language as ElementIcon Light symbol, adapted for Node2D tower drawing.
	# Static draw only: no node, no particle, no gameplay logic.
	var token_color := main_color.lightened(0.16)

	# Small octagon token like the panel element icon.
	var glow_poly := _regular_poly(center, radius * 1.02, 8, PI / 8.0)
	var outer_poly := _regular_poly(center, radius * 0.94, 8, PI / 8.0)
	var inner_poly := _regular_poly(center, radius * 0.80, 8, PI / 8.0)

	t.draw_colored_polygon(glow_poly, Color(token_color.r, token_color.g, token_color.b, 0.12))

	t.draw_colored_polygon(outer_poly, DETAIL_OUTLINE)
	t.draw_colored_polygon(outer_poly, Color(0.020, 0.024, 0.018, 0.84))
	t.draw_colored_polygon(inner_poly, Color(0.055, 0.050, 0.018, 0.88))

	_draw_closed_polyline(t, outer_poly, Color(token_color.r, token_color.g, token_color.b, 0.72), 1.35)
	_draw_closed_polyline(t, inner_poly, Color(token_color.r, token_color.g, token_color.b, 0.28), 0.9)

	# Soft light aura, replacing the old plain yellow circle.
	t.draw_circle(center, radius * 0.92, Color(token_color.r, token_color.g, token_color.b, 0.08))

	# Light star symbol, matching the panel icon language.
	var star := PackedVector2Array()
	for i in range(16):
		var angle := float(i) / 16.0 * TAU - PI / 2.0
		var r := radius * 0.56 if i % 2 == 0 else radius * 0.22
		star.append(center + Vector2(cos(angle), sin(angle)) * r)

	t.draw_colored_polygon(star, DETAIL_OUTLINE)
	t.draw_colored_polygon(
		TowerVisualDrawUtils._expand_poly_from_center(star, -1.0),
		Color(1.0, 0.76, 0.06, 0.96)
	)
	_draw_closed_polyline(t, star, Color(1.0, 0.96, 0.58, 0.82), 0.9)

	# Inner bright core.
	t.draw_circle(center, radius * 0.16, Color(1.0, 1.0, 0.82, 0.94))
	t.draw_circle(center, radius * 0.055, Color(1.0, 0.70, 0.12, 0.94))

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var barrel_len := 30.0 + float(lvl) * 3.0

	# Centered rear prism body. Symmetric on the forward axis.
	var body := PackedVector2Array([
		Vector2(-18, 0),
		Vector2(-8, -16),
		Vector2(13, -12),
		Vector2(20, 0),
		Vector2(13, 12),
		Vector2(-8, 16),
	])
	_outline_poly(t, body)

	# Perfectly centered cannon / light-channel.
	_outline_rect(t, Rect2(-2, -4, barrel_len, 8))

	# Rear lens ring only. Forward muzzle orb removed for cleaner silhouette.
	_outline_circle(t, Vector2(-10, 0), 7.0)

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	var light := main_color.lightened(0.35)
	var soft := Color(main_color.r, main_color.g, main_color.b, 0.42)
	var deep := main_color.darkened(0.38)
	var barrel_len := 30.0 + float(lvl) * 1.5

	# Premium static halo. Cheap draw calls only; no particles/nodes.
	t.draw_circle(Vector2.ZERO, 22.0 + float(lvl) * 1.5, Color(main_color.r, main_color.g, main_color.b, 0.055))
	t.draw_arc(Vector2.ZERO, 18.5 + float(lvl) * 0.8, 0.0, TAU, 32, Color(main_color.r, main_color.g, main_color.b, 0.13), 1.0, true)

	# Main prism body: mirrored top/bottom points for clean silhouette.
	var body := PackedVector2Array([
		Vector2(-18, 0),
		Vector2(-8, -16),
		Vector2(13, -12),
		Vector2(20, 0),
		Vector2(13, 12),
		Vector2(-8, 16),
	])
	t.draw_colored_polygon(body, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(body, -2.0), soft)
	_draw_stroked_polyline(t, body, light, 1.5)

	# Light element token replaces the old generic yellow rear circle.
	# Drawn on the rear focus point so the tower clearly reads as Light.
	_draw_light_element_icon(t, Vector2(-10, 0), 8.4 + float(lvl) * 0.15, main_color)

	# Inner mirrored prism facets. Black stroke first, then translucent light fill.
	var upper_facet := PackedVector2Array([
		Vector2(-8, -12),
		Vector2(10, -8),
		Vector2(15, 0),
		Vector2(-2, -3),
	])
	var lower_facet := PackedVector2Array([
		Vector2(-8, 12),
		Vector2(10, 8),
		Vector2(15, 0),
		Vector2(-2, 3),
	])
	t.draw_colored_polygon(upper_facet, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(upper_facet, -1.2), Color(light.r, light.g, light.b, 0.22))
	_draw_stroked_polyline(t, upper_facet, Color(light.r, light.g, light.b, 0.50), 0.9)

	t.draw_colored_polygon(lower_facet, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(lower_facet, -1.2), Color(light.r, light.g, light.b, 0.14))
	_draw_stroked_polyline(t, lower_facet, Color(light.r, light.g, light.b, 0.42), 0.9)

	# Centered beam channel / barrel with black trim on every rail.
	_draw_stroked_rect(t, Rect2(-2, -4, barrel_len, 8), deep, 1.8)
	_draw_stroked_line(t, Vector2(-2, 0), Vector2(barrel_len, 0), light, 2.2, true)
	_draw_stroked_line(t, Vector2(2, -6), Vector2(barrel_len - 3.0, -6), Color(main_color.r, main_color.g, main_color.b, 0.45), 0.9, true)
	_draw_stroked_line(t, Vector2(2, 6), Vector2(barrel_len - 3.0, 6), Color(main_color.r, main_color.g, main_color.b, 0.45), 0.9, true)

	# Clean forward light emitter. No round muzzle orb.
	var tip_x := barrel_len + 4.0
	_draw_stroked_line(t, Vector2(tip_x - 5.0, -3.0), Vector2(tip_x, 0.0), light, 1.5, true)
	_draw_stroked_line(t, Vector2(tip_x - 5.0, 3.0), Vector2(tip_x, 0.0), light, 1.5, true)
	t.draw_circle(Vector2(tip_x - 1.0, 0.0), 2.4, Color(main_color.r, main_color.g, main_color.b, 0.22))
	t.draw_circle(Vector2(tip_x - 1.0, 0.0), 1.2, Color(1.0, 0.98, 0.70, 0.80))

	# Polished central focus gem over the Light icon.
	_draw_stroked_circle(t, Vector2(-10, 0), 3.4, Color(1.0, 0.96, 0.48, 0.92), 1.2)
	t.draw_circle(Vector2(-10, 0), 1.35, Color(1.0, 1.0, 0.82, 0.92))

	# Soft corner halos instead of hard corner ticks.
	var halo_c := Color(main_color.r, main_color.g, main_color.b, 0.30)
	var halo_core := Color(1.0, 0.98, 0.58, 0.62)
	var halo_points := [
		Vector2(-20, -20),
		Vector2(20, -20),
		Vector2(-20, 20),
		Vector2(20, 20),
	]

	for p in halo_points:
		t.draw_circle(p, 5.5, Color(main_color.r, main_color.g, main_color.b, 0.08))
		t.draw_arc(p, 4.2, 0.0, TAU, 18, DETAIL_OUTLINE_SOFT, 1.2, true)
		t.draw_arc(p, 3.4, 0.0, TAU, 18, halo_c, 1.0, true)
		t.draw_circle(p, 1.6, halo_core)
