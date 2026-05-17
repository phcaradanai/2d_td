extends RefCounted

# Tower: Polar Tower 1
# Role: Arctic freeze — massive slow/control field
# Elements: Light + Water + Earth
# Visual source: custom by_id visual
# Visual intent: premium polar-core freeze engine; intentionally different from Hail.
# Performance note: CanvasItem draw calls only; no particles, nodes, timers, or gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.58)

const LIGHT_COL := Color(1.0, 0.93, 0.48, 0.95)
const WATER_COL := Color(0.34, 0.92, 1.0, 0.96)
const EARTH_COL := Color(0.64, 0.50, 0.34, 0.95)

const ICE_CORE := Color(0.62, 0.96, 1.0, 0.96)
const ICE_DEEP := Color(0.10, 0.42, 0.68, 0.92)
const ICE_SHADOW := Color(0.05, 0.22, 0.34, 0.95)
const AURORA := Color(0.62, 1.0, 0.92, 0.42)
const AURORA_LIGHT := Color(1.0, 0.96, 0.58, 0.34)
const STONE_DARK := Color(0.20, 0.17, 0.14, 0.96)
const STONE_LIT := Color(0.50, 0.43, 0.33, 0.96)


static func _sv(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE


static func _sr(value: float) -> float:
	return value * VISUAL_SCALE


static func _scaled_poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_sv(p))
	return out


static func _draw_poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_scaled_poly(points), color)


static func _draw_poly_outline(t: Node2D, points: Array[Vector2], color: Color, outline_width: float = 2.4) -> void:
	var poly := _scaled_poly(points)
	t.draw_colored_polygon(poly, OUTLINE)
	t.draw_polyline(_closed(poly), OUTLINE, _sr(outline_width), true)
	t.draw_colored_polygon(poly, color)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out


static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	t.draw_line(_sv(a), _sv(b), OUTLINE, _sr(width + 2.2), true)
	t.draw_line(_sv(a), _sv(b), color, _sr(width), true)


static func _draw_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float = 2.0, closed := false) -> void:
	var poly := _scaled_poly(points)
	if closed and poly.size() > 0:
		poly.append(poly[0])
	t.draw_polyline(poly, OUTLINE, _sr(width + 2.2), true)
	t.draw_polyline(poly, color, _sr(width), true)


static func _draw_circle(t: Node2D, center: Vector2, radius: float, color: Color, outline := true) -> void:
	if outline:
		t.draw_circle(_sv(center), _sr(radius + 1.8), OUTLINE)
	t.draw_circle(_sv(center), _sr(radius), color)


static func _draw_ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(_sv(center), _sr(radius), 0.0, TAU, 96, OUTLINE, _sr(width + 2.2), true)
	t.draw_arc(_sv(center), _sr(radius), 0.0, TAU, 96, color, _sr(width), true)


static func _draw_arc(t: Node2D, center: Vector2, radius: float, from_ang: float, to_ang: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(_sv(center), _sr(radius), from_ang, to_ang, 42, OUTLINE, _sr(width + 2.2), true)
	t.draw_arc(_sv(center), _sr(radius), from_ang, to_ang, 42, color, _sr(width), true)


static func _regular_poly(center: Vector2, radius: float, sides: int, rot: float = 0.0) -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		arr.append(center + Vector2(cos(a), sin(a)) * radius)
	return arr


static func _diamond(center: Vector2, rx: float, ry: float) -> Array[Vector2]:
	return [
		center + Vector2(0.0, -ry),
		center + Vector2(rx, 0.0),
		center + Vector2(0.0, ry),
		center + Vector2(-rx, 0.0),
	]


static func _draw_polar_glyph(t: Node2D, center: Vector2, radius: float) -> void:
	# North/South polarity mark: communicates control field instead of hail projectile.
	_draw_circle(t, center, radius, ICE_DEEP, true)
	_draw_circle(t, center, radius * 0.62, ICE_CORE, true)
	_draw_line(t, center + Vector2(-radius * 0.72, 0.0), center + Vector2(radius * 0.72, 0.0), LIGHT_COL, 1.5)
	_draw_line(t, center + Vector2(0.0, -radius * 0.72), center + Vector2(0.0, radius * 0.72), WATER_COL, 1.5)
	_draw_arc(t, center, radius * 0.88, -PI * 0.82, -PI * 0.18, AURORA_LIGHT, 1.6)
	_draw_arc(t, center, radius * 0.88, PI * 0.18, PI * 0.82, AURORA, 1.6)


static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := center
	var r := radius
	_draw_circle(t, c, r + 1.2, OUTLINE, false)
	_draw_circle(t, c, r, Color(0.03, 0.06, 0.08, 0.92), false)
	_draw_circle(t, c + Vector2(-r * 0.52, -r * 0.18), r * 0.36, LIGHT_COL, false)
	_draw_circle(t, c + Vector2(r * 0.52, -r * 0.18), r * 0.36, WATER_COL, false)
	_draw_circle(t, c + Vector2(0.0, r * 0.48), r * 0.36, EARTH_COL, false)


static func draw_contour(t: Node2D) -> void:
	# Compact outer silhouette only. No self-rotation; catalog renderer handles rotation.
	_draw_ring(t, Vector2.ZERO, 35.0, OUTLINE_SOFT, 6.0)
	_draw_poly_outline(t, _regular_poly(Vector2.ZERO, 26.0, 8, PI / 8.0), OUTLINE, 2.0)
	_draw_poly_outline(t, _diamond(Vector2.ZERO, 18.0, 31.0), OUTLINE, 2.0)


static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Ground/earth anchor: heavy and stable, not a hail shard cluster.
	_draw_poly_outline(t, [
		Vector2(-24.0, 15.0), Vector2(-16.0, 24.0), Vector2(0.0, 28.0),
		Vector2(16.0, 24.0), Vector2(24.0, 15.0), Vector2(16.0, 7.0),
		Vector2(-16.0, 7.0),
	], STONE_DARK, 2.2)
	_draw_poly_outline(t, [
		Vector2(-17.0, 14.0), Vector2(-8.0, 20.0), Vector2(0.0, 22.0),
		Vector2(8.0, 20.0), Vector2(17.0, 14.0), Vector2(10.0, 10.0),
		Vector2(-10.0, 10.0),
	], STONE_LIT, 1.8)

	# Massive slow radius field: static aurora rings, no particles.
	_draw_arc(t, Vector2.ZERO, 34.0, -PI * 0.92, -PI * 0.08, AURORA, 2.1)
	_draw_arc(t, Vector2.ZERO, 34.0, PI * 0.08, PI * 0.92, AURORA_LIGHT, 2.1)
	_draw_arc(t, Vector2.ZERO, 28.0, -PI * 0.78, -PI * 0.22, Color(0.42, 0.90, 1.0, 0.42), 1.6)
	_draw_arc(t, Vector2.ZERO, 28.0, PI * 0.22, PI * 0.78, Color(1.0, 0.96, 0.55, 0.28), 1.6)

	# Four polar pylons: different read from hail relays; they look like field anchors.
	var anchors: Array[Vector2] = [
		Vector2(-25.0, -7.0), Vector2(25.0, -7.0),
		Vector2(-20.0, 18.0), Vector2(20.0, 18.0),
	]
	for i in range(anchors.size()):
		var p: Vector2 = anchors[i]
		var col := WATER_COL if i < 2 else EARTH_COL
		_draw_poly_outline(t, _diamond(p, 4.2, 7.2), col, 1.5)
		_draw_circle(t, p, 2.2, ICE_CORE, true)
		_draw_line(t, p, p * 0.45, Color(0.70, 0.98, 1.0, 0.58), 1.2)

	# Main polar engine body: icy monolith inside a magnetic cage.
	_draw_poly_outline(t, _regular_poly(Vector2.ZERO, 22.5, 8, PI / 8.0), ICE_SHADOW, 2.4)
	_draw_poly_outline(t, _diamond(Vector2.ZERO, 15.5, 25.5), ICE_DEEP, 2.0)
	_draw_poly_outline(t, [
		Vector2(-8.5, -21.0), Vector2(8.5, -21.0), Vector2(13.0, -4.0),
		Vector2(7.0, 17.5), Vector2(0.0, 23.5), Vector2(-7.0, 17.5),
		Vector2(-13.0, -4.0),
	], Color(0.26, 0.78, 0.96, 0.94), 2.0)
	_draw_poly_outline(t, [
		Vector2(-4.0, -17.0), Vector2(6.0, -15.0), Vector2(8.0, -2.0),
		Vector2(3.5, 13.0), Vector2(-2.0, 17.0), Vector2(-7.0, 4.0),
		Vector2(-7.0, -11.0),
	], Color(0.74, 1.0, 1.0, 0.90), 1.4)

	# Magnetic polar clamps: premium silhouette and clear control identity.
	_draw_poly_outline(t, [
		Vector2(-22.0, -14.0), Vector2(-14.0, -21.0), Vector2(-8.0, -17.0),
		Vector2(-13.0, -10.0), Vector2(-19.0, -6.0),
	], LIGHT_COL, 1.8)
	_draw_poly_outline(t, [
		Vector2(22.0, -14.0), Vector2(14.0, -21.0), Vector2(8.0, -17.0),
		Vector2(13.0, -10.0), Vector2(19.0, -6.0),
	], LIGHT_COL, 1.8)
	_draw_poly_outline(t, [
		Vector2(-23.0, 3.0), Vector2(-16.0, -2.0), Vector2(-11.0, 3.0),
		Vector2(-16.0, 9.0), Vector2(-23.0, 10.0),
	], WATER_COL, 1.8)
	_draw_poly_outline(t, [
		Vector2(23.0, 3.0), Vector2(16.0, -2.0), Vector2(11.0, 3.0),
		Vector2(16.0, 9.0), Vector2(23.0, 10.0),
	], WATER_COL, 1.8)

	# Internal glyph and field-flow lines.
	_draw_polar_glyph(t, Vector2(0.0, -1.0), 8.5)
	_draw_polyline(t, [
		Vector2(-11.0, -6.0), Vector2(-5.0, -10.0), Vector2(0.0, -8.0),
		Vector2(5.0, -10.0), Vector2(11.0, -6.0),
	], Color(0.90, 1.0, 1.0, 0.72), 1.4, false)
	_draw_polyline(t, [
		Vector2(-11.0, 8.0), Vector2(-4.0, 12.0), Vector2(0.0, 10.0),
		Vector2(4.0, 12.0), Vector2(11.0, 8.0),
	], Color(0.52, 0.92, 1.0, 0.68), 1.4, false)

	# Small frost/snow accents. They are static and sparse for FPS safety.
	var flakes: Array[Vector2] = [Vector2(-29.0, -19.0), Vector2(29.0, -19.0), Vector2(-30.0, 18.0), Vector2(30.0, 18.0)]
	for f: Vector2 in flakes:
		_draw_line(t, f + Vector2(-3.0, 0.0), f + Vector2(3.0, 0.0), ICE_CORE, 1.1)
		_draw_line(t, f + Vector2(0.0, -3.0), f + Vector2(0.0, 3.0), ICE_CORE, 1.1)

	# Element identity.
	_draw_tri_element_token(t, Vector2(0.0, 31.0), 5.6)
