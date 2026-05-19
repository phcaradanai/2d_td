extends RefCounted

# Tower: Tidal Tower 1
# Role: Surging wave — enchanted water splash that slows and damages groups
# Elements: light, water, nature
# Visual source: custom by_id visual
# Visual intent: premium tidal-prism wave engine; splash + slow identity, not a generic support halo.
# Performance note: CanvasItem draw calls only; no particles, no extra nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const LIGHT_COL := Color(1.0, 0.94, 0.54, 0.96)
const WATER_COL := Color(0.22, 0.84, 1.0, 0.96)
const WATER_DARK := Color(0.04, 0.34, 0.62, 0.96)
const NATURE_COL := Color(0.30, 1.0, 0.48, 0.94)
const NATURE_DARK := Color(0.05, 0.44, 0.22, 0.94)
const FOAM_COL := Color(0.78, 1.0, 1.0, 0.92)
const CORE_COL := Color(0.62, 1.0, 0.92, 0.96)
const GLASS_COL := Color(0.18, 0.64, 0.94, 0.82)


static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * VISUAL_SCALE


static func _r(value: float) -> float:
	return value * VISUAL_SCALE


static func _scaled_poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * VISUAL_SCALE)
	return out


static func _regular_poly(center: Vector2, radius: float, sides: int, start_angle: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := start_angle + TAU * float(i) / float(sides)
		pts.append((center + Vector2(cos(a), sin(a)) * radius) * VISUAL_SCALE)
	return pts


static func _outline_poly(t: Node2D, points: PackedVector2Array, color: Color = OUTLINE) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)
	t.draw_colored_polygon(points, color)


static func _fill_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)
	t.draw_colored_polygon(points, color)


static func _stroked_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, OUTLINE, (width + 2.6) * VISUAL_SCALE, true)
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, color, width * VISUAL_SCALE, true)


static func _stroked_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed: bool = false) -> void:
	var pts := _scaled_poly(points)
	if closed and pts.size() > 0:
		pts.append(pts[0])
	t.draw_polyline(pts, OUTLINE, (width + 2.4) * VISUAL_SCALE, true)
	t.draw_polyline(pts, color, width * VISUAL_SCALE, true)


static func _stroked_circle(t: Node2D, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	t.draw_circle(center * VISUAL_SCALE, (radius + width * 0.85) * VISUAL_SCALE, OUTLINE_SOFT)
	t.draw_circle(center * VISUAL_SCALE, radius * VISUAL_SCALE, color)


static func _ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 48, OUTLINE, (width + 2.0) * VISUAL_SCALE, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 48, color, width * VISUAL_SCALE, true)


static func _arc(t: Node2D, center: Vector2, radius: float, from_a: float, to_a: float, color: Color, width: float) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_a, to_a, 18, OUTLINE, (width + 2.2) * VISUAL_SCALE, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_a, to_a, 18, color, width * VISUAL_SCALE, true)


static func _draw_drop(t: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var pts := _scaled_poly([
		center + Vector2(0.0, -radius * 1.45),
		center + Vector2(radius * 0.95, -radius * 0.12),
		center + Vector2(radius * 0.42, radius * 0.92),
		center + Vector2(0.0, radius * 1.25),
		center + Vector2(-radius * 0.42, radius * 0.92),
		center + Vector2(-radius * 0.95, -radius * 0.12),
	])
	_fill_poly(t, pts, color)


static func _draw_leaf(t: Node2D, center: Vector2, dir: Vector2, radius: float, color: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var pts := _scaled_poly([
		center - dir * radius * 0.9,
		center + n * radius * 0.52,
		center + dir * radius * 1.12,
		center - n * radius * 0.52,
	])
	_fill_poly(t, pts, color)
	_stroked_line(t, center - dir * radius * 0.52, center + dir * radius * 0.78, FOAM_COL, 1.0)


static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := center
	var r := radius
	var offsets: Array[Vector2] = [
		Vector2(-r * 0.9, 0.0),
		Vector2(0.0, -r * 0.95),
		Vector2(r * 0.9, 0.0),
	]
	var cols: Array[Color] = [LIGHT_COL, WATER_COL, NATURE_COL]
	for i in range(3):
		t.draw_circle((c + offsets[i]) * VISUAL_SCALE, (r + 1.8) * VISUAL_SCALE, OUTLINE)
		t.draw_circle((c + offsets[i]) * VISUAL_SCALE, r * VISUAL_SCALE, cols[i])
	t.draw_circle(c * VISUAL_SCALE, (r * 0.72) * VISUAL_SCALE, CORE_COL)


static func draw_contour(t: Node2D) -> void:
	# Soft silhouette only; renderer/catalog handles rotation like other passed tower visuals.
	t.draw_circle(Vector2.ZERO, _r(37.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _r(29.0), OUTLINE)
	_outline_poly(t, _regular_poly(Vector2.ZERO, 23.0, 8, PI / 8.0), OUTLINE)


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Slow/splash field rings.
	_arc(t, Vector2.ZERO, 34.0, -2.72, -0.36, WATER_COL, 2.1)
	_arc(t, Vector2.ZERO, 31.0, 0.24, 2.62, NATURE_COL, 1.8)
	_arc(t, Vector2.ZERO, 27.0, 2.98, 4.92, LIGHT_COL, 1.6)

	# Organic stabilizer leaves: nature part of enchanted water.
	_draw_leaf(t, Vector2(-24, -4), Vector2(-0.96, -0.18).normalized(), 7.2, NATURE_DARK)
	_draw_leaf(t, Vector2(-18, 19), Vector2(-0.42, 0.90).normalized(), 6.4, NATURE_COL)
	_draw_leaf(t, Vector2(18, 19), Vector2(0.42, 0.90).normalized(), 6.4, NATURE_COL)
	_draw_leaf(t, Vector2(24, -4), Vector2(0.96, -0.18).normalized(), 7.2, NATURE_DARK)

	# Back basin / wave reservoir.
	_fill_poly(t, _scaled_poly([
		Vector2(-23, -14), Vector2(-13, -26), Vector2(13, -26), Vector2(23, -14),
		Vector2(20, 11), Vector2(10, 22), Vector2(-10, 22), Vector2(-20, 11),
	]), Color(0.05, 0.18, 0.30, 0.96))
	_fill_poly(t, _regular_poly(Vector2.ZERO, 21.0, 8, PI / 8.0), Color(0.09, 0.34, 0.52, 0.95))
	_fill_poly(t, _regular_poly(Vector2.ZERO, 15.5, 8, PI / 8.0), GLASS_COL)

	# Inner tidal swirl / wave crest.
	_stroked_polyline(t, [
		Vector2(-13, 2), Vector2(-7, -4), Vector2(0, -2), Vector2(7, -7), Vector2(13, -1)
	], FOAM_COL, 2.1)
	_stroked_polyline(t, [
		Vector2(-12, 8), Vector2(-5, 4), Vector2(2, 7), Vector2(10, 3)
	], WATER_COL, 2.0)
	_stroked_polyline(t, [
		Vector2(-7, -10), Vector2(-1, -14), Vector2(7, -12)
	], LIGHT_COL, 1.45)

	# Forward wave-diffuser: splash projectile identity without becoming a cannon.
	_fill_poly(t, _scaled_poly([
		Vector2(-8, -4), Vector2(8, -4), Vector2(15, -17), Vector2(8, -23),
		Vector2(0, -27), Vector2(-8, -23), Vector2(-15, -17),
	]), Color(0.08, 0.42, 0.74, 0.96))
	_fill_poly(t, _scaled_poly([
		Vector2(-5, -9), Vector2(5, -9), Vector2(10, -18), Vector2(0, -23), Vector2(-10, -18),
	]), WATER_COL)
	_stroked_line(t, Vector2(-11, -17), Vector2(11, -17), FOAM_COL, 1.6)

	# Splash droplets/foam near muzzle, static and cheap.
	_draw_drop(t, Vector2(-18, -25), 2.5, FOAM_COL)
	_draw_drop(t, Vector2(18, -25), 2.5, FOAM_COL)
	_draw_drop(t, Vector2(0, -33), 2.8, WATER_COL)

	# Side tide anchors / slow crystals.
	for p: Vector2 in [Vector2(-26, 0), Vector2(26, 0), Vector2(-15, 25), Vector2(15, 25)]:
		t.draw_circle(p * VISUAL_SCALE, _r(5.2), OUTLINE)
		t.draw_circle(p * VISUAL_SCALE, _r(3.6), WATER_COL)
		t.draw_circle(p * VISUAL_SCALE, _r(1.5), FOAM_COL)

	# Core: luminous enchanted tide heart.
	t.draw_circle(Vector2.ZERO, _r(9.8), OUTLINE)
	t.draw_circle(Vector2.ZERO, _r(7.2), CORE_COL)
	t.draw_circle(_v(-2.2, -2.2), _r(2.3), LIGHT_COL)

	# Bottom tri-element token.
	_draw_tri_element_token(t, Vector2(0, 30), 4.8)
