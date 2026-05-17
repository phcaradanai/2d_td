extends RefCounted

# Tower: Earth Tower I
# Role: Seismic heavy impact / land-only splash
# Elements: earth
# Visual source: custom by_id visual
# Visual intent: heavy stone bastion with seismic hammer-mortar silhouette; reads as slow, heavy AoE impact.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)
const STONE_DARK := Color(0.075, 0.065, 0.050, 1.0)
const STONE_CRACK := Color(0.0, 0.0, 0.0, 0.82)
const MOLTEN_AMBER := Color(1.0, 0.58, 0.15, 0.92)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var path := PackedVector2Array(points)
	if path.size() > 0:
		path.append(path[0])
	return path

static func _draw_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width := 1.8) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(t, points, -stroke_width)
	t.draw_colored_polygon(inner, fill)

static func _draw_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := points
	if closed:
		path = _closed(points)
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.0, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.1, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.8) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_earth_token(t: Node2D, center: Vector2, radius: float, main_color: Color) -> void:
	# Compact Earth element token: hex-stone with mountain/strata mark.
	var earth := main_color.lightened(0.18)
	var outer := _regular_poly(center, radius, 6, PI / 6.0)
	var inner := _regular_poly(center, radius * 0.78, 6, PI / 6.0)

	t.draw_colored_polygon(_regular_poly(center, radius * 1.08, 6, PI / 6.0), Color(earth.r, earth.g, earth.b, 0.10))
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, outer, -1.5), Color(0.045, 0.040, 0.025, 0.92))
	t.draw_polyline(_closed(inner), Color(earth.r, earth.g, earth.b, 0.35), 0.9, true)

	var mountain := PackedVector2Array([
		center + Vector2(-radius * 0.46, radius * 0.22),
		center + Vector2(-radius * 0.18, -radius * 0.18),
		center + Vector2(radius * 0.02, radius * 0.08),
		center + Vector2(radius * 0.26, -radius * 0.28),
		center + Vector2(radius * 0.52, radius * 0.22),
	])
	t.draw_polyline(mountain, DETAIL_OUTLINE, 2.9, true)
	t.draw_polyline(mountain, Color(0.92, 0.70, 0.36, 0.82), 1.25, true)

	_draw_stroked_line(t, center + Vector2(-radius * 0.43, radius * 0.42), center + Vector2(radius * 0.43, radius * 0.42), Color(earth.r, earth.g, earth.b, 0.55), 0.9, true)

static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var head_size := 15.0 + float(lvl) * 1.0

	# Low, armored bastion body.
	var body := PackedVector2Array([
		Vector2(-20, -12),
		Vector2(-12, -20),
		Vector2(12, -20),
		Vector2(20, -12),
		Vector2(20, 12),
		Vector2(12, 20),
		Vector2(-12, 20),
		Vector2(-20, 12),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, body)

	# Forward seismic ram / impact head, wide instead of sniper-like.
	var ram := PackedVector2Array([
		Vector2(2, -9),
		Vector2(23 + head_size * 0.15, -11),
		Vector2(29 + head_size * 0.15, -4),
		Vector2(29 + head_size * 0.15, 4),
		Vector2(23 + head_size * 0.15, 11),
		Vector2(2, 9),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, ram)

	# Rear counterweight and central quake core.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-24, -9, 9, 18))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-2, 0), 8.5)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var stone := main_color.darkened(0.08)
	var stone_mid := main_color.darkened(0.24)
	var stone_light := main_color.lightened(0.18)
	var amber := Color(1.0, 0.56, 0.16, 0.92)
	var quake_c := Color(main_color.r, main_color.g, main_color.b, 0.42)
	var head_size := 15.0 + float(lvl) * 1.0

	# Static ground tremor language: communicates land-only AoE without heavy VFX.
	t.draw_arc(Vector2.ZERO, 22.5, PI * 0.10, PI * 0.42, 16, Color(stone_light.r, stone_light.g, stone_light.b, 0.16), 1.6, true)
	t.draw_arc(Vector2.ZERO, 22.5, -PI * 0.42, -PI * 0.10, 16, Color(stone_light.r, stone_light.g, stone_light.b, 0.16), 1.6, true)
	t.draw_arc(Vector2.ZERO, 16.0, PI * 0.70, PI * 1.05, 16, Color(amber.r, amber.g, amber.b, 0.11), 1.2, true)
	t.draw_arc(Vector2.ZERO, 16.0, -PI * 1.05, -PI * 0.70, 16, Color(amber.r, amber.g, amber.b, 0.11), 1.2, true)

	# Earth token in the back, partially visible but not replacing the heavy body.
	_draw_earth_token(t, Vector2(-6, 0), 13.5 + float(lvl) * 0.45, main_color)

	# Main armored body: octagonal stone bunker.
	var body := PackedVector2Array([
		Vector2(-20, -12),
		Vector2(-12, -20),
		Vector2(12, -20),
		Vector2(20, -12),
		Vector2(20, 12),
		Vector2(12, 20),
		Vector2(-12, 20),
		Vector2(-20, 12),
	])
	_draw_poly(t, body, stone_mid, 2.0)
	_draw_polyline(t, body, Color(stone_light.r, stone_light.g, stone_light.b, 0.58), 1.25)

	# Inner stone plates / facets, all black-trimmed.
	var top_plate := PackedVector2Array([
		Vector2(-11, -15),
		Vector2(8, -15),
		Vector2(14, -8),
		Vector2(-3, -5),
	])
	var bottom_plate := PackedVector2Array([
		Vector2(-11, 15),
		Vector2(8, 15),
		Vector2(14, 8),
		Vector2(-3, 5),
	])
	_draw_poly(t, top_plate, Color(stone_light.r, stone_light.g, stone_light.b, 0.55), 1.3)
	_draw_poly(t, bottom_plate, Color(stone.r, stone.g, stone.b, 0.82), 1.3)

	# Forward seismic ram / hammer-mortar head: wide, blunt, splash-oriented.
	var ram := PackedVector2Array([
		Vector2(1, -9),
		Vector2(23 + head_size * 0.15, -11),
		Vector2(30 + head_size * 0.15, -4),
		Vector2(30 + head_size * 0.15, 4),
		Vector2(23 + head_size * 0.15, 11),
		Vector2(1, 9),
	])
	_draw_poly(t, ram, stone, 2.0)
	_draw_polyline(t, ram, Color(stone_light.r, stone_light.g, stone_light.b, 0.48), 1.05)

	# Heavy impact face, no thin barrel / no sniper read.
	var impact_face := PackedVector2Array([
		Vector2(21 + head_size * 0.15, -7),
		Vector2(30 + head_size * 0.15, -3),
		Vector2(30 + head_size * 0.15, 3),
		Vector2(21 + head_size * 0.15, 7),
	])
	_draw_poly(t, impact_face, Color(0.045, 0.035, 0.025, 0.94), 1.5)
	_draw_stroked_line(t, Vector2(22 + head_size * 0.15, -4), Vector2(29 + head_size * 0.15, 0), Color(amber.r, amber.g, amber.b, 0.50), 1.0, true)
	_draw_stroked_line(t, Vector2(22 + head_size * 0.15, 4), Vector2(29 + head_size * 0.15, 0), Color(amber.r, amber.g, amber.b, 0.50), 1.0, true)

	# Rear counterweight: balances silhouette and makes it feel heavy.
	_draw_stroked_rect(t, Rect2(-24, -9, 9, 18), stone.darkened(0.22), 1.8)
	_draw_stroked_line(t, Vector2(-20, -7), Vector2(-20, 7), Color(stone_light.r, stone_light.g, stone_light.b, 0.42), 1.1, true)

	# Central molten quake core, small and controlled.
	_draw_stroked_circle(t, Vector2(-2, 0), 8.5, Color(0.035, 0.028, 0.018, 0.96), 2.1)
	_draw_stroked_circle(t, Vector2(-2, 0), 5.3, Color(0.34, 0.20, 0.08, 0.95), 1.2)
	t.draw_circle(Vector2(-2, 0), 3.0, amber)
	t.draw_circle(Vector2(-2, 0), 1.4, Color(1.0, 0.82, 0.34, 0.96))

	# Cracks/strata: makes it read as stone while preserving symmetry.
	_draw_stroked_line(t, Vector2(-15, -4), Vector2(-8, -9), Color(stone_light.r, stone_light.g, stone_light.b, 0.36), 0.75, true)
	_draw_stroked_line(t, Vector2(-15, 4), Vector2(-8, 9), Color(stone_light.r, stone_light.g, stone_light.b, 0.30), 0.75, true)
	_draw_stroked_line(t, Vector2(7, -14), Vector2(12, -9), Color(stone_light.r, stone_light.g, stone_light.b, 0.30), 0.7, true)
	_draw_stroked_line(t, Vector2(7, 14), Vector2(12, 9), Color(stone_light.r, stone_light.g, stone_light.b, 0.24), 0.7, true)

	# Small mirrored ground shards, static and cheap.
	var shard_c := Color(stone_light.r, stone_light.g, stone_light.b, 0.35)
	var shard_a := PackedVector2Array([Vector2(-25, -16), Vector2(-21, -20), Vector2(-18, -15)])
	var shard_b := PackedVector2Array([Vector2(-25, 16), Vector2(-21, 20), Vector2(-18, 15)])
	var shard_c_poly := PackedVector2Array([Vector2(24, -17), Vector2(29, -14), Vector2(23, -11)])
	var shard_d := PackedVector2Array([Vector2(24, 17), Vector2(29, 14), Vector2(23, 11)])
	_draw_poly(t, shard_a, shard_c, 1.0)
	_draw_poly(t, shard_b, Color(shard_c.r, shard_c.g, shard_c.b, 0.28), 1.0)
	_draw_poly(t, shard_c_poly, Color(amber.r, amber.g, amber.b, 0.18), 1.0)
	_draw_poly(t, shard_d, Color(amber.r, amber.g, amber.b, 0.14), 1.0)
