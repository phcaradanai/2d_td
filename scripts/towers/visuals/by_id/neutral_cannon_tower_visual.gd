extends RefCounted

# Tower: Neutral Cannon Tower
# Role: Neutral ground-only splash starter
# Elements: None
# Visual source: custom by_id visual
# Visual intent: compact heavy mortar / reinforced cannon; clear AoE ground splash identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)
const METAL_DARK := Color(0.14, 0.15, 0.16, 0.96)
const METAL_MID := Color(0.34, 0.36, 0.37, 0.96)
const METAL_LIGHT := Color(0.62, 0.64, 0.62, 0.92)
const BRASS := Color(0.82, 0.58, 0.24, 0.95)
const BRASS_HOT := Color(1.0, 0.72, 0.28, 0.90)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _expand_poly(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if points.is_empty():
		return points
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var expanded := PackedVector2Array()
	for p in points:
		var dir := p - center
		if dir.length() <= 0.001:
			expanded.append(p)
		else:
			expanded.append(p + dir.normalized() * amount)
	return expanded

static func _closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if closed.size() > 0:
		closed.append(closed[0])
	t.draw_polyline(closed, color, width, true)

static func _stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width: float = 2.0) -> void:
	t.draw_colored_polygon(_expand_poly(points, stroke_width), DETAIL_OUTLINE)
	t.draw_colored_polygon(points, fill)

static func _stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_line(from, to, color, width, true)

static func _stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width: float = 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width: float = 1.8) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_shell_icon(t: Node2D, center: Vector2, scale: float) -> void:
	# Small neutral shell badge: communicates projectile/splash without using an element icon.
	var shell := PackedVector2Array([
		center + Vector2(-4.0, -3.2) * scale,
		center + Vector2(1.8, -4.2) * scale,
		center + Vector2(5.2, 0.0) * scale,
		center + Vector2(1.8, 4.2) * scale,
		center + Vector2(-4.0, 3.2) * scale,
	])
	_stroked_poly(t, shell, BRASS, 1.2)
	_stroked_line(t, center + Vector2(-1.8, -2.2) * scale, center + Vector2(-1.8, 2.2) * scale, METAL_LIGHT, 0.8)

static func draw_contour(t: Node2D) -> void:
	var base := PackedVector2Array([
		Vector2(-20, -10),
		Vector2(6, -16),
		Vector2(18, -9),
		Vector2(20, 9),
		Vector2(6, 16),
		Vector2(-20, 10),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, base)

	# Short, wide forward mortar barrel. Neutral Cannon must read as splash artillery.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-2, -7, 32, 14))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(21, -10, 10, 20))

	# Recoil brace and wheel-like side housings.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-10, -11), 5.5)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-10, 11), 5.5)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-19, 0), Vector2(24, 0), 4.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var barrel_len := 30.0 + float(lvl) * 1.5
	var dark := METAL_DARK
	var mid := METAL_MID
	var light := METAL_LIGHT
	var accent := BRASS

	# Cheap static ground-splash language. Very subtle so it does not look elemental.
	for r in [18.0, 24.0]:
		t.draw_arc(Vector2(3, 2), r, deg_to_rad(205), deg_to_rad(335), 24, Color(0.0, 0.0, 0.0, 0.24), 2.0, true)
		t.draw_arc(Vector2(3, 2), r - 1.3, deg_to_rad(210), deg_to_rad(330), 24, Color(0.72, 0.58, 0.36, 0.20), 1.0, true)

	# Reinforced low base: neutral, heavy, readable from distance.
	var base := PackedVector2Array([
		Vector2(-20, -10),
		Vector2(6, -16),
		Vector2(18, -9),
		Vector2(20, 9),
		Vector2(6, 16),
		Vector2(-20, 10),
	])
	_stroked_poly(t, base, dark, 2.3)
	_stroked_polyline(t, base, Color(0.58, 0.60, 0.58, 0.65), 1.0)

	# Metal top plate, slightly inset.
	var top_plate := PackedVector2Array([
		Vector2(-15, -6),
		Vector2(5, -11),
		Vector2(14, -6),
		Vector2(15, 6),
		Vector2(5, 11),
		Vector2(-15, 6),
	])
	_stroked_poly(t, top_plate, Color(0.23, 0.24, 0.24, 0.98), 1.5)
	_closed_polyline(t, top_plate, Color(0.74, 0.74, 0.68, 0.32), 0.9)

	# Side wheel / recoil housings make it feel like a physical cannon, not a magic tower.
	_stroked_circle(t, Vector2(-11, -11), 5.4, Color(0.10, 0.11, 0.12, 0.96), 1.8)
	_stroked_circle(t, Vector2(-11, 11), 5.4, Color(0.10, 0.11, 0.12, 0.96), 1.8)
	_stroked_circle(t, Vector2(-11, -11), 2.4, accent.darkened(0.10), 1.0)
	_stroked_circle(t, Vector2(-11, 11), 2.4, accent.darkened(0.10), 1.0)

	# Wide mortar barrel: black outside, dark bore, brass lip.
	_stroked_rect(t, Rect2(-2, -7, barrel_len, 14), Color(0.18, 0.19, 0.19, 0.98), 2.0)
	_stroked_rect(t, Rect2(2, -4.5, barrel_len - 6.0, 9.0), Color(0.08, 0.085, 0.085, 0.98), 1.0)
	_stroked_line(t, Vector2(1, -7.7), Vector2(barrel_len - 3.0, -7.7), Color(0.74, 0.74, 0.68, 0.42), 0.9)
	_stroked_line(t, Vector2(1, 7.7), Vector2(barrel_len - 3.0, 7.7), Color(0.0, 0.0, 0.0, 0.42), 0.8)

	# Big square-ish muzzle clearly says cannon/splash shell, not sniper or beam.
	var muzzle_x := barrel_len - 1.0
	_stroked_rect(t, Rect2(muzzle_x - 3.0, -10.0, 10.0, 20.0), Color(0.12, 0.13, 0.13, 0.98), 2.0)
	_stroked_rect(t, Rect2(muzzle_x - 0.5, -6.8, 5.0, 13.6), Color(0.015, 0.014, 0.012, 0.98), 1.0)
	_stroked_line(t, Vector2(muzzle_x - 1.0, -8.0), Vector2(muzzle_x + 5.4, -8.0), accent, 1.0)
	_stroked_line(t, Vector2(muzzle_x - 1.0, 8.0), Vector2(muzzle_x + 5.4, 8.0), accent.darkened(0.22), 1.0)

	# Rear recoil block and shell badge.
	_stroked_rect(t, Rect2(-20, -5, 14, 10), Color(0.11, 0.12, 0.12, 0.96), 1.7)
	_draw_shell_icon(t, Vector2(-13, 0), 0.82)

	# Small rivets / bolts: premium detail, still cheap.
	for p in [Vector2(-4, -12), Vector2(9, -9), Vector2(-4, 12), Vector2(9, 9)]:
		_stroked_circle(t, p, 1.9, light.darkened(0.18), 0.75)
		t.draw_circle(p + Vector2(-0.5, -0.5), 0.75, Color(1.0, 0.92, 0.62, 0.55))

	# Low recoil rails, symmetric top/bottom.
	_stroked_line(t, Vector2(-18, -16), Vector2(15, -16), Color(0.52, 0.52, 0.48, 0.56), 1.1)
	_stroked_line(t, Vector2(-18, 16), Vector2(15, 16), Color(0.52, 0.52, 0.48, 0.56), 1.1)

	# Warm loaded-shell glow in the bore; not an element icon.
	t.draw_circle(Vector2(muzzle_x + 1.5, 0), 3.8, Color(0.0, 0.0, 0.0, 0.62))
	t.draw_circle(Vector2(muzzle_x + 1.5, 0), 2.2, Color(BRASS_HOT.r, BRASS_HOT.g, BRASS_HOT.b, 0.32))
	t.draw_circle(Vector2(muzzle_x + 1.5, 0), 1.0, Color(1.0, 0.78, 0.38, 0.65))
