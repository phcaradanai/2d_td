extends RefCounted

# Tower: Oblivion Tower 1
# Role: Void aura — erases enemy defenses and drains vitality nearby.
# Elements: Light + Darkness + Nature
# Visual source: custom by_id visual
# Visual intent: void flower / aura-drain reactor, no projectile barrel.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const OUTLINE := Color(0.0, 0.0, 0.0, 0.94)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

const LIGHT_COL := Color(1.0, 0.93, 0.18, 1.0)
const DARK_COL := Color(0.48, 0.24, 0.68, 1.0)
const NATURE_COL := Color(0.25, 0.92, 0.38, 1.0)

const VOID_DEEP := Color(0.055, 0.035, 0.095, 1.0)
const VOID_MID := Color(0.18, 0.09, 0.28, 1.0)
const PETAL_DARK := Color(0.34, 0.16, 0.46, 1.0)
const PETAL_LIGHT := Color(0.82, 0.53, 0.98, 1.0)
const BIO_GLOW := Color(0.38, 1.0, 0.52, 0.9)
const DRAIN_COL := Color(0.75, 0.22, 1.0, 0.74)

# Match other catalog-safe tower visuals: no draw_set_transform and no direct idle_rotation.
# The renderer/catalog owns rotation; this file only scales its local coordinates.
const VISUAL_SCALE := 0.66

static func _sv(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE

static func _sr(v: float) -> float:
	return v * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_sv(p))
	return out

static func _scaled(points: Array[Vector2], scale: float, offset := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_sv((p * scale) + offset))
	return out

static func _outline_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	t.draw_colored_polygon(points, OUTLINE)
	var inner := _shrink(points, 0.88)
	t.draw_colored_polygon(inner, color)

static func _shrink(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p: Vector2 in points:
		center += p
	if points.size() > 0:
		center /= float(points.size())
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(center + ((p - center) * factor))
	return out

static func _line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(_sv(a), _sv(b), OUTLINE, _sr(width + 2.5), true)
	t.draw_line(_sv(a), _sv(b), color, _sr(width), true)

static func _polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed := false) -> void:
	var path := _poly(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _sr(width + 2.4), true)
	t.draw_polyline(path, color, _sr(width), true)

static func _circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(_sv(pos), _sr(radius + 2.2), OUTLINE)
	t.draw_circle(_sv(pos), _sr(radius), color)

static func _ring(t: Node2D, pos: Vector2, radius: float, color: Color, width: float) -> void:
	t.draw_arc(_sv(pos), _sr(radius), 0.0, TAU, 36, OUTLINE_SOFT, _sr(width + 2.6), true)
	t.draw_arc(_sv(pos), _sr(radius), 0.0, TAU, 36, color, _sr(width), true)

static func _arc(t: Node2D, pos: Vector2, radius: float, from_ang: float, to_ang: float, color: Color, width: float) -> void:
	t.draw_arc(_sv(pos), _sr(radius), from_ang, to_ang, 22, OUTLINE_SOFT, _sr(width + 2.6), true)
	t.draw_arc(_sv(pos), _sr(radius), from_ang, to_ang, 22, color, _sr(width), true)

static func _regular_poly(center: Vector2, radius: float, sides: int, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(sides):
		var a := rot + (TAU * float(i) / float(sides))
		out.append(_sv(center + Vector2(cos(a), sin(a)) * radius))
	return out

static func _draw_tri_element_token(t: Node2D, pos: Vector2, r: float) -> void:
	_circle(t, pos + Vector2(-r * 0.78, -r * 0.15), r * 0.47, LIGHT_COL)
	_circle(t, pos + Vector2(r * 0.78, -r * 0.15), r * 0.47, DARK_COL)
	_circle(t, pos + Vector2(0.0, r * 0.65), r * 0.47, NATURE_COL)
	_ring(t, pos, r * 1.25, Color(0.55, 1.0, 0.75, 0.32), 1.2)

static func _draw_void_glyph(t: Node2D, center: Vector2) -> void:
	_ring(t, center, 11.0, Color(0.94, 0.72, 1.0, 0.82), 2.0)
	_arc(t, center, 15.5, -2.7, -0.55, DRAIN_COL, 2.0)
	_arc(t, center, 15.5, 0.45, 2.65, BIO_GLOW, 2.0)
	_line(t, center + Vector2(-8.0, -2.0), center + Vector2(8.0, 2.0), LIGHT_COL, 1.7)
	_line(t, center + Vector2(0.0, -9.0), center + Vector2(0.0, 9.0), Color(0.6, 0.24, 0.85, 0.9), 1.6)
	_circle(t, center, 4.2, Color(0.04, 0.0, 0.07, 1.0))

static func draw_contour(t: Node2D) -> void:
	# Outer contour only. Kept compact to fit tower catalog cards.
	t.draw_circle(Vector2.ZERO, _sr(39.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _sr(30.0), OUTLINE)
	_outline_poly(t, _regular_poly(Vector2.ZERO, 24.0, 8, PI / 8.0), OUTLINE)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var light_col := LIGHT_COL
	var dark_col := DARK_COL
	var nature_col := NATURE_COL
	if el_colors.size() >= 3:
		light_col = el_colors[0]
		dark_col = el_colors[1]
		nature_col = el_colors[2]

	# Soft aura rings: communicates aura/debuff, not projectile.
	_arc(t, Vector2.ZERO, 36.0, -2.95, -0.36, Color(dark_col.r, dark_col.g, dark_col.b, 0.48), 2.5)
	_arc(t, Vector2.ZERO, 36.0, 0.16, 2.72, Color(nature_col.r, nature_col.g, nature_col.b, 0.40), 2.5)
	_arc(t, Vector2.ZERO, 30.0, -0.12, 1.92, Color(light_col.r, light_col.g, light_col.b, 0.36), 1.8)
	_arc(t, Vector2.ZERO, 30.0, 2.25, 4.95, Color(0.73, 0.25, 1.0, 0.42), 1.8)

	# Base shadow and pedestal.
	_outline_poly(t, _regular_poly(Vector2(0, 8), 26.5, 8, PI / 8.0), VOID_MID)
	_outline_poly(t, _regular_poly(Vector2(0, 9), 19.5, 8, PI / 8.0), Color(0.14, 0.08, 0.21, 1.0))

	# Void flower petals. Each petal points outward to read as "void flower".
	var petal_centers: Array[Vector2] = [
		Vector2(0, -18),
		Vector2(18, 0),
		Vector2(0, 18),
		Vector2(-18, 0),
		Vector2(13, -13),
		Vector2(13, 13),
		Vector2(-13, 13),
		Vector2(-13, -13)
	]
	for i in range(petal_centers.size()):
		var p: Vector2 = petal_centers[i]
		var dir := p.normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := p + dir * 11.5
		var base := p - dir * 8.5
		var petal := PackedVector2Array([
			base + side * 7.0,
			p + side * 8.8,
			tip,
			p - side * 8.8,
			base - side * 7.0
		])
		var col := PETAL_DARK
		if i % 3 == 0:
			col = Color(0.43, 0.19, 0.58, 1.0)
		elif i % 3 == 1:
			col = Color(0.22, 0.48, 0.30, 1.0)
		_outline_poly(t, petal, col)

	# Light/nature veins over petals.
	_polyline(t, [Vector2(-24, -2), Vector2(-12, -7), Vector2(0, -15), Vector2(12, -7), Vector2(24, -2)], Color(light_col.r, light_col.g, light_col.b, 0.82), 1.5)
	_polyline(t, [Vector2(-20, 14), Vector2(-9, 8), Vector2(0, 12), Vector2(9, 8), Vector2(20, 14)], Color(nature_col.r, nature_col.g, nature_col.b, 0.80), 1.5)
	_polyline(t, [Vector2(-17, -17), Vector2(-7, -6), Vector2(0, 0), Vector2(7, -6), Vector2(17, -17)], Color(0.86, 0.50, 1.0, 0.72), 1.4)

	# Pylons around tower: defense-erasing/vitality-drain aura anchors.
	var anchors: Array[Vector2] = [
		Vector2(-29, -24), Vector2(29, -24), Vector2(31, 19), Vector2(-31, 19)
	]
	for a: Vector2 in anchors:
		_outline_poly(t, _regular_poly(a, 5.2, 6, PI / 6.0), Color(0.13, 0.08, 0.18, 1.0))
		_circle(t, a, 2.7, Color(dark_col.r, dark_col.g, dark_col.b, 0.90))
		_line(t, a * 0.82, a * 0.54, Color(0.65, 0.25, 1.0, 0.46), 1.2)

	# Central void-drain core.
	_circle(t, Vector2.ZERO, 17.5, Color(0.05, 0.0, 0.08, 1.0))
	_circle(t, Vector2.ZERO, 13.0, Color(0.15, 0.04, 0.22, 1.0))
	_circle(t, Vector2.ZERO, 8.2, Color(0.37, 0.09, 0.55, 1.0))
	_draw_void_glyph(t, Vector2.ZERO)

	# Small drain ticks, static and readable in catalog.
	for i in range(6):
		var a := -PI * 0.88 + float(i) * 0.62
		var from := Vector2(cos(a), sin(a)) * 24.0
		var to := Vector2(cos(a + 0.22), sin(a + 0.22)) * 27.5
		_line(t, from, to, Color(0.74, 0.22, 1.0, 0.58), 1.2)

	# Tri-element identity token.
	_draw_tri_element_token(t, Vector2(0, 31), 5.2)
