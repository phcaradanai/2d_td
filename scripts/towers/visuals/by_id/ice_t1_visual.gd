extends RefCounted

# Tower: Ice Tower 1
# Role: Frost shard control — piercing ice that slows enemy movement.
# Elements: light, water
# Visual source: custom by_id visual
# Visual intent: premium cryo prism emitter; sharp frost shard silhouette, clear slow/control identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _is_low_detail(detail_quality: int) -> bool:
	return detail_quality == TowerVisualDrawUtils.DetailQuality.LOW

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	TowerVisualDrawUtils.safe_draw_polyline(t, points, color, width, closed)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	TowerVisualDrawUtils.safe_draw_polyline(t, points, DETAIL_OUTLINE, width + 2.2, closed)
	TowerVisualDrawUtils.safe_draw_polyline(t, points, color, width, closed)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	TowerVisualDrawUtils.safe_draw_line(t, from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	TowerVisualDrawUtils.safe_draw_line(t, from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	TowerVisualDrawUtils.safe_draw_circle(t, center, radius + stroke_width, DETAIL_OUTLINE)
	TowerVisualDrawUtils.safe_draw_circle(t, center, radius, fill)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _draw_dual_element_token(t: Node2D, center: Vector2, radius: float, light_color: Color, water_color: Color) -> void:
	# Small Light + Water badge for dual-element identity. Kept behind the main ice body.
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.78, 8, PI / 8.0)

	TowerVisualDrawUtils.safe_draw_polygon(t, outer, DETAIL_OUTLINE)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(outer, -1.5), Color(0.015, 0.025, 0.035, 0.88))
	_draw_closed_polyline(t, outer, Color(water_color.r, water_color.g, water_color.b, 0.45), 1.0)

	# Split diagonal facets: holy ice / water crystal.
	var left_facet := PackedVector2Array([
		center + Vector2(-radius * 0.46, -radius * 0.48),
		center + Vector2(0.0, -radius * 0.66),
		center + Vector2(0.0, radius * 0.66),
		center + Vector2(-radius * 0.46, radius * 0.48),
	])
	var right_facet := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.66),
		center + Vector2(radius * 0.46, -radius * 0.48),
		center + Vector2(radius * 0.46, radius * 0.48),
		center + Vector2(0.0, radius * 0.66),
	])
	TowerVisualDrawUtils.safe_draw_polygon(t, left_facet, Color(light_color.r, light_color.g, light_color.b, 0.42))
	TowerVisualDrawUtils.safe_draw_polygon(t, right_facet, Color(water_color.r, water_color.g, water_color.b, 0.46))
	_draw_closed_polyline(t, inner, Color(1.0, 1.0, 0.90, 0.36), 0.8)

static func _draw_ice_glyph(t: Node2D, center: Vector2, radius: float, ice_color: Color, detail_quality: int) -> void:
	# Static snowflake/frost glyph, cheaper and clearer than particles.
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		var dir := Vector2(cos(a), sin(a))
		var p1 := center + dir * (radius * 0.22)
		var p2 := center + dir * (radius * 0.78)
		_draw_stroked_line(t, p1, p2, Color(ice_color.r, ice_color.g, ice_color.b, 0.72), 0.85, true)

		var branch_center := center + dir * (radius * 0.55)
		var side_a := a + PI * 0.72
		var side_b := a - PI * 0.72
		if not _is_low_detail(detail_quality):
			TowerVisualDrawUtils.safe_draw_line(t, branch_center, branch_center + Vector2(cos(side_a), sin(side_a)) * (radius * 0.16), DETAIL_OUTLINE_SOFT, 1.6, true)
			TowerVisualDrawUtils.safe_draw_line(t, branch_center, branch_center + Vector2(cos(side_b), sin(side_b)) * (radius * 0.16), DETAIL_OUTLINE_SOFT, 1.6, true)
			TowerVisualDrawUtils.safe_draw_line(t, branch_center, branch_center + Vector2(cos(side_a), sin(side_a)) * (radius * 0.12), ice_color, 0.75, true)
			TowerVisualDrawUtils.safe_draw_line(t, branch_center, branch_center + Vector2(cos(side_b), sin(side_b)) * (radius * 0.12), ice_color, 0.75, true)

	TowerVisualDrawUtils.safe_draw_circle(t, center, radius * 0.16, Color(1.0, 1.0, 0.92, 0.92))

static func draw_contour(t: Node2D, detail_quality: int = TowerVisualDrawUtils.DetailQuality.MEDIUM) -> void:
	var lvl: int = t.tree_tier
	var shard_len := 30.0 + float(lvl) * 2.5

	# Rear cryo prism body: symmetric crystal shell.
	var body := PackedVector2Array([
		Vector2(-20, 0),
		Vector2(-12, -16),
		Vector2(8, -15),
		Vector2(18, -7),
		Vector2(18, 7),
		Vector2(8, 15),
		Vector2(-12, 16),
	])
	_outline_poly(t, body)

	# Long frost shard emitter; sharp, not a round muzzle.
	var shard := PackedVector2Array([
		Vector2(-2, -6),
		Vector2(shard_len - 4.0, -5),
		Vector2(shard_len + 8.0, 0),
		Vector2(shard_len - 4.0, 5),
		Vector2(-2, 6),
	])
	_outline_poly(t, shard)

	if not _is_low_detail(detail_quality):
		# Upper/lower stabilizer fins for control/slow identity.
		_outline_poly(t, PackedVector2Array([
			Vector2(-8, -10),
			Vector2(7, -23),
			Vector2(18, -18),
			Vector2(10, -9),
		]))
		_outline_poly(t, PackedVector2Array([
			Vector2(-8, 10),
			Vector2(7, 23),
			Vector2(18, 18),
			Vector2(10, 9),
		]))

	# Rear frost badge and small slow-radius glyph nodes.
	_outline_circle(t, Vector2(-10, 0), 7.5)
	if not _is_low_detail(detail_quality):
		_outline_circle(t, Vector2(-21, -21), 4.0)
		_outline_circle(t, Vector2(21, -21), 4.0)
		_outline_circle(t, Vector2(-21, 21), 4.0)
		_outline_circle(t, Vector2(21, 21), 4.0)

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color], detail_quality: int = TowerVisualDrawUtils.DetailQuality.MEDIUM) -> void:
	var water_color := main_color
	if el_colors.size() > 0:
		water_color = el_colors[0]
	var light_color := Color(1.0, 0.94, 0.44)
	if el_colors.size() > 1:
		light_color = el_colors[1]

	var ice := Color(0.62, 0.94, 1.0, 0.96)
	var _ice_soft := Color(water_color.r, water_color.g, water_color.b, 0.38)
	var ice_glow := Color(water_color.r, water_color.g, water_color.b, 0.12)
	var _deep := Color(0.025, 0.08, 0.12, 0.90)
	var shadow := Color(0.015, 0.030, 0.045, 0.92)
	var shard_len := 30.0 + float(lvl) * 2.5

	# Static slow/control aura language. Very subtle so it does not become an area indicator.
	if not _is_low_detail(detail_quality):
		TowerVisualDrawUtils.safe_draw_circle(t, Vector2.ZERO, 20.5 + float(lvl), ice_glow)
		TowerVisualDrawUtils.safe_draw_arc(t, Vector2.ZERO, 24.0, -0.25 * PI, 0.25 * PI, 18, Color(water_color.r, water_color.g, water_color.b, 0.22), 1.0, true)
		TowerVisualDrawUtils.safe_draw_arc(t, Vector2.ZERO, 24.0, 0.75 * PI, 1.25 * PI, 18, Color(water_color.r, water_color.g, water_color.b, 0.18), 1.0, true)

	# Dual element token behind the main body.
	_draw_dual_element_token(t, Vector2(-14, 0), 11.2 + float(lvl) * 0.3, light_color, water_color)

	# Main crystal body.
	var body := PackedVector2Array([
		Vector2(-20, 0),
		Vector2(-12, -16),
		Vector2(8, -15),
		Vector2(18, -7),
		Vector2(18, 7),
		Vector2(8, 15),
		Vector2(-12, 16),
	])
	TowerVisualDrawUtils.safe_draw_polygon(t, body, DETAIL_OUTLINE)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(body, -2.0), Color(water_color.r * 0.35, water_color.g * 0.48, water_color.b * 0.55, 0.88))
	_draw_stroked_polyline(t, body, Color(ice.r, ice.g, ice.b, 0.68), 1.25)

	# Mirrored inner crystal facets.
	var top_facet := PackedVector2Array([
		Vector2(-10, -12),
		Vector2(5, -11),
		Vector2(14, -4),
		Vector2(-1, -2),
	])
	var bot_facet := PackedVector2Array([
		Vector2(-10, 12),
		Vector2(5, 11),
		Vector2(14, 4),
		Vector2(-1, 2),
	])
	TowerVisualDrawUtils.safe_draw_polygon(t, top_facet, DETAIL_OUTLINE_SOFT)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(top_facet, -1.0), Color(0.88, 1.0, 1.0, 0.22))
	_draw_stroked_polyline(t, top_facet, Color(0.92, 1.0, 1.0, 0.48), 0.8)
	TowerVisualDrawUtils.safe_draw_polygon(t, bot_facet, DETAIL_OUTLINE_SOFT)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(bot_facet, -1.0), Color(water_color.r, water_color.g, water_color.b, 0.24))
	_draw_stroked_polyline(t, bot_facet, Color(0.72, 0.96, 1.0, 0.42), 0.8)

	# Symmetric stabilizer fins. These read as control/slow rather than raw DPS.
	var upper_fin := PackedVector2Array([
		Vector2(-8, -10),
		Vector2(7, -23),
		Vector2(18, -18),
		Vector2(10, -9),
	])
	var lower_fin := PackedVector2Array([
		Vector2(-8, 10),
		Vector2(7, 23),
		Vector2(18, 18),
		Vector2(10, 9),
	])
	TowerVisualDrawUtils.safe_draw_polygon(t, upper_fin, DETAIL_OUTLINE)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(upper_fin, -1.5), Color(water_color.r, water_color.g, water_color.b, 0.34))
	_draw_stroked_polyline(t, upper_fin, Color(ice.r, ice.g, ice.b, 0.42), 0.9)
	TowerVisualDrawUtils.safe_draw_polygon(t, lower_fin, DETAIL_OUTLINE)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(lower_fin, -1.5), Color(water_color.r, water_color.g, water_color.b, 0.26))
	_draw_stroked_polyline(t, lower_fin, Color(ice.r, ice.g, ice.b, 0.38), 0.9)

	# Long frost shard emitter: sharp tip implies piercing frost shard, not round cannon.
	var shard := PackedVector2Array([
		Vector2(-2, -6),
		Vector2(shard_len - 4.0, -5),
		Vector2(shard_len + 8.0, 0),
		Vector2(shard_len - 4.0, 5),
		Vector2(-2, 6),
	])
	TowerVisualDrawUtils.safe_draw_polygon(t, shard, DETAIL_OUTLINE)
	TowerVisualDrawUtils.safe_draw_polygon(t, TowerVisualDrawUtils._expand_poly_from_center(shard, -1.5), shadow)
	TowerVisualDrawUtils.safe_draw_polygon(t, PackedVector2Array([
		Vector2(0, -3.6),
		Vector2(shard_len - 5.0, -2.8),
		Vector2(shard_len + 3.5, 0),
		Vector2(shard_len - 5.0, 2.8),
		Vector2(0, 3.6),
	]), Color(water_color.r, water_color.g, water_color.b, 0.42))
	_draw_stroked_line(t, Vector2(1.0, 0), Vector2(shard_len + 3.0, 0), ice, 1.35, true)
	_draw_stroked_line(t, Vector2(4.0, -7.2), Vector2(shard_len - 7.0, -7.2), Color(0.82, 1.0, 1.0, 0.36), 0.75, true)
	_draw_stroked_line(t, Vector2(4.0, 7.2), Vector2(shard_len - 7.0, 7.2), Color(0.82, 1.0, 1.0, 0.30), 0.75, true)

	# Rear frost lens/glyph.
	_draw_stroked_circle(t, Vector2(-10, 0), 7.5, Color(0.015, 0.040, 0.070, 0.90), 2.0)
	if not _is_low_detail(detail_quality):
		_draw_ice_glyph(t, Vector2(-10, 0), 6.2, Color(0.80, 1.0, 1.0, 0.82), detail_quality)

	# Soft corner frost nodes instead of hard ticks.
	var node_points := [
		Vector2(-21, -21),
		Vector2(21, -21),
		Vector2(-21, 21),
		Vector2(21, 21),
	]
	for p in node_points:
		TowerVisualDrawUtils.safe_draw_circle(t, p, 5.8, Color(water_color.r, water_color.g, water_color.b, 0.08))
		TowerVisualDrawUtils.safe_draw_arc(t, p, 4.4, 0.0, TAU, 18, DETAIL_OUTLINE_SOFT, 1.2, true)
		TowerVisualDrawUtils.safe_draw_arc(t, p, 3.4, 0.0, TAU, 18, Color(ice.r, ice.g, ice.b, 0.34), 1.0, true)
		TowerVisualDrawUtils.safe_draw_circle(t, p, 1.4, Color(0.92, 1.0, 1.0, 0.60))
