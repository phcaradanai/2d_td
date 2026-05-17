extends RefCounted

# Tower: Enchantment Tower 1
# Role: Vulnerability aura — curses enemies and makes them take more damage
# Elements: Light + Nature + Earth
# Visual source: custom by_id visual
# Visual intent: premium nature-ward enchantment altar, no projectile barrel.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.62, 0.64)

const LIGHT := Color(1.00, 0.92, 0.48, 0.96)
const LIGHT_SOFT := Color(1.00, 0.94, 0.58, 0.36)
const NATURE := Color(0.34, 0.92, 0.46, 0.94)
const NATURE_DARK := Color(0.12, 0.42, 0.20, 0.96)
const EARTH := Color(0.58, 0.42, 0.24, 0.96)
const EARTH_DARK := Color(0.25, 0.18, 0.13, 0.98)
const WARD := Color(0.74, 1.00, 0.70, 0.92)
const CURSE := Color(0.80, 0.58, 1.00, 0.86)
const CORE := Color(1.00, 0.98, 0.72, 0.98)

static func _v(p: Vector2) -> Vector2:
	return p * VISUAL_SCALE

static func _r(value: float) -> float:
	return value * VISUAL_SCALE

static func _scaled_poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_v(p))
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, phase: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := phase + TAU * float(i) / float(sides)
		pts.append(_v(center + Vector2(cos(a), sin(a)) * radius))
	return pts

static func _outline_poly(t: Node2D, points: PackedVector2Array, fill: Color, outline_width: float = 2.2) -> void:
	t.draw_colored_polygon(points, OUTLINE)
	var inset := PackedVector2Array()
	var c := Vector2.ZERO
	for p: Vector2 in points:
		c += p
	if points.size() > 0:
		c /= float(points.size())
	for p: Vector2 in points:
		inset.append(c + (p - c) * 0.91)
	t.draw_colored_polygon(inset, fill)
	if points.size() > 1:
		var path := PackedVector2Array(points)
		path.append(points[0])
		t.draw_polyline(path, OUTLINE, outline_width * VISUAL_SCALE, true)

static func _outline_circle(t: Node2D, pos: Vector2, radius: float, fill: Color, outline_width: float = 2.2) -> void:
	t.draw_circle(_v(pos), _r(radius + outline_width), OUTLINE)
	t.draw_circle(_v(pos), _r(radius), fill)

static func _stroked_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	t.draw_line(_v(a), _v(b), OUTLINE, _r(width + 2.4), true)
	t.draw_line(_v(a), _v(b), color, _r(width), true)

static func _stroked_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float = 2.0, closed: bool = false) -> void:
	var path := _scaled_poly(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _r(width + 2.3), true)
	t.draw_polyline(path, color, _r(width), true)

static func _arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int = 18) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i in range(segments + 1):
		var f := float(i) / float(segments)
		var a: float = lerp(start_angle, end_angle, f)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

static func _draw_leaf(t: Node2D, center: Vector2, angle: float, color: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := Vector2(-dir.y, dir.x)
	var pts: Array[Vector2] = [
		center + dir * 12.0,
		center + side * 5.0 + dir * 2.0,
		center - dir * 9.0,
		center - side * 5.0 + dir * 2.0
	]
	_outline_poly(t, _scaled_poly(pts), color)
	_stroked_line(t, center - dir * 6.5, center + dir * 9.5, WARD, 1.2)

static func _draw_rune_stone(t: Node2D, center: Vector2, angle: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := Vector2(-dir.y, dir.x)
	var pts: Array[Vector2] = [
		center + dir * 8.5,
		center + side * 6.0,
		center - dir * 7.0,
		center - side * 6.0
	]
	_outline_poly(t, _scaled_poly(pts), EARTH)
	_stroked_line(t, center - side * 2.5 - dir * 1.0, center + side * 2.5 + dir * 1.0, LIGHT, 1.0)
	_stroked_line(t, center - dir * 4.0, center + dir * 4.0, CURSE, 0.9)

static func _draw_ward_glyph(t: Node2D, center: Vector2, radius: float) -> void:
	# Hex ward shape: reads as enchantment/debuff, not as a weapon muzzle.
	_stroked_polyline(t, [
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.86, -radius * 0.48),
		center + Vector2(radius * 0.86, radius * 0.48),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.86, radius * 0.48),
		center + Vector2(-radius * 0.86, -radius * 0.48)
	], CURSE, 1.6, true)
	_stroked_line(t, center + Vector2(-radius * 0.55, 0), center + Vector2(radius * 0.55, 0), LIGHT, 1.2)
	_stroked_line(t, center + Vector2(0, -radius * 0.55), center + Vector2(0, radius * 0.55), NATURE, 1.2)
	_stroked_line(t, center + Vector2(-radius * 0.35, radius * 0.35), center + Vector2(radius * 0.35, -radius * 0.35), WARD, 1.0)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	_outline_circle(t, center, radius + 2.2, OUTLINE_SOFT, 1.0)
	var c := _v(center)
	var r := _r(radius)
	var left := PackedVector2Array([c, _v(center + Vector2(-radius, -radius * 0.82)), _v(center + Vector2(-radius, radius * 0.82))])
	var top := PackedVector2Array([c, _v(center + Vector2(-radius, -radius * 0.82)), _v(center + Vector2(radius, -radius * 0.82))])
	var right := PackedVector2Array([c, _v(center + Vector2(radius, -radius * 0.82)), _v(center + Vector2(radius, radius * 0.82))])
	t.draw_colored_polygon(left, LIGHT)
	t.draw_colored_polygon(top, NATURE)
	t.draw_colored_polygon(right, EARTH)
	t.draw_arc(c, r + _r(0.9), 0.0, TAU, 24, OUTLINE, _r(1.2), true)
	t.draw_circle(c, _r(1.7), CORE)

static func draw_contour(t: Node2D) -> void:
	# Compact contour so the renderer/catalog can rotate it consistently.
	t.draw_circle(Vector2.ZERO, _r(38.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _r(30.0), OUTLINE)
	_outline_poly(t, _regular_poly(Vector2.ZERO, 23.0, 6, PI / 6.0), OUTLINE)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Aura rings: vulnerability field. Static only; renderer handles any catalog rotation.
	_stroked_polyline(t, _arc_points(Vector2.ZERO, 34.0, -2.85, -0.35, 18), LIGHT_SOFT, 1.6)
	_stroked_polyline(t, _arc_points(Vector2.ZERO, 34.0, 0.30, 2.75, 18), Color(0.52, 1.0, 0.50, 0.28), 1.6)
	_stroked_polyline(t, _arc_points(Vector2.ZERO, 27.0, -0.70, 0.85, 14), Color(0.90, 0.62, 1.0, 0.34), 1.4)
	_stroked_polyline(t, _arc_points(Vector2.ZERO, 27.0, 2.35, 3.95, 14), Color(0.90, 0.62, 1.0, 0.34), 1.4)

	# Earth ward base: stable altar, not a cannon.
	_outline_poly(t, _regular_poly(Vector2.ZERO, 26.0, 6, PI / 6.0), EARTH_DARK)
	_outline_poly(t, _regular_poly(Vector2.ZERO, 21.5, 6, PI / 6.0), EARTH)
	_outline_poly(t, _regular_poly(Vector2.ZERO, 16.0, 6, PI / 6.0), Color(0.16, 0.29, 0.18, 0.98))

	# Four ward stones / pylons.
	for i in range(4):
		var a := PI / 4.0 + float(i) * PI / 2.0
		_draw_rune_stone(t, Vector2(cos(a), sin(a)) * 25.0, a)

	# Nature leaves woven into the ward.
	for i in range(4):
		var a := float(i) * PI / 2.0
		_draw_leaf(t, Vector2(cos(a), sin(a)) * 18.0, a, NATURE_DARK)
	for i in range(4):
		var a := PI / 4.0 + float(i) * PI / 2.0
		_draw_leaf(t, Vector2(cos(a), sin(a)) * 13.0, a + PI * 0.12, NATURE)

	# Enchantment halo crown.
	_outline_circle(t, Vector2.ZERO, 15.4, Color(0.22, 0.50, 0.27, 0.98), 2.4)
	t.draw_arc(Vector2.ZERO, _r(17.2), 0.0, TAU, 32, WARD, _r(1.5), true)
	t.draw_arc(Vector2.ZERO, _r(12.2), 0.0, TAU, 32, Color(0.84, 0.66, 1.0, 0.72), _r(1.2), true)

	# Central cursed ward core.
	_outline_circle(t, Vector2.ZERO, 10.5, Color(0.24, 0.14, 0.30, 0.98), 2.2)
	_outline_circle(t, Vector2.ZERO, 6.5, CORE, 1.7)
	_draw_ward_glyph(t, Vector2.ZERO, 8.2)

	# Vulnerability spikes facing outward.
	for i in range(6):
		var a := PI / 6.0 + float(i) * TAU / 6.0
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var spike: Array[Vector2] = [
			dir * 20.5,
			dir * 27.8 + side * 2.7,
			dir * 31.5,
			dir * 27.8 - side * 2.7
		]
		_outline_poly(t, _scaled_poly(spike), CURSE, 1.5)

	# Small premium glints.
	for i in range(8):
		var a := float(i) * TAU / 8.0
		var p := Vector2(cos(a), sin(a)) * 33.0
		_outline_circle(t, p, 1.9, LIGHT if i % 2 == 0 else NATURE, 0.8)

	_draw_tri_element_token(t, Vector2(0, 31.0), 5.2)
