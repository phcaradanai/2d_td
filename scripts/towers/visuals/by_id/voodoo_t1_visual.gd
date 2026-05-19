extends RefCounted

# Tower: Voodoo Tower 1
# Role: Dark ritual aura — drains life and amplifies damage on nearby enemies.
# Elements: Darkness + Fire + Nature
# Visual source: custom by_id visual
# Visual intent: premium voodoo ritual totem / curse aura reactor.
# Performance note: CanvasItem draw calls only; no particles, no new nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const DARKNESS := Color(0.58, 0.22, 0.95, 0.96)
const VOID := Color(0.17, 0.08, 0.25, 0.98)
const FIRE := Color(1.0, 0.42, 0.10, 0.96)
const EMBER := Color(1.0, 0.76, 0.20, 0.92)
const NATURE := Color(0.26, 0.95, 0.42, 0.92)
const BONE := Color(0.92, 0.82, 0.58, 0.95)
const RUNE := Color(0.92, 0.34, 1.0, 0.92)

static func _v(p: Vector2) -> Vector2:
	return p * VISUAL_SCALE

static func _r(value: float) -> float:
	return value * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_v(p))
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		pts.append(_v(center + Vector2(cos(a), sin(a)) * radius))
	return pts

static func _draw_poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), color)

static func _draw_poly_outline(t: Node2D, points: Array[Vector2], color: Color) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, _poly(points))
	t.draw_colored_polygon(_poly(points), color)

static func _draw_circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, _v(pos), _r(radius))
	t.draw_circle(_v(pos), _r(radius), color)

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, _v(a), _v(b), _r(width + 2.0))
	t.draw_line(_v(a), _v(b), color, _r(width), true)

static func _draw_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed := false) -> void:
	var path := _poly(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _r(width + 2.4), true)
	t.draw_polyline(path, color, _r(width), true)

static func _draw_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	t.draw_arc(_v(center), _r(radius), start_angle, end_angle, 18, OUTLINE_SOFT, _r(width + 2.0), true)
	t.draw_arc(_v(center), _r(radius), start_angle, end_angle, 18, color, _r(width), true)

static func _draw_leaf(t: Node2D, center: Vector2, angle: float, color: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := dir.rotated(PI * 0.5)
	var points: Array[Vector2] = [
		center + dir * 10.0,
		center + side * 5.2,
		center - dir * 5.0,
		center - side * 5.2
	]
	_draw_poly_outline(t, points, color)
	_draw_line(t, center - dir * 4.0, center + dir * 7.0, Color(0.70, 1.0, 0.58, 0.78), 1.2)

static func _draw_flame(t: Node2D, center: Vector2, scale := 1.0) -> void:
	var pts: Array[Vector2] = [
		center + Vector2(0, -10.5) * scale,
		center + Vector2(6.2, -2.0) * scale,
		center + Vector2(3.0, 8.2) * scale,
		center + Vector2(-3.4, 8.0) * scale,
		center + Vector2(-6.4, -1.6) * scale
	]
	_draw_poly_outline(t, pts, FIRE)
	var inner: Array[Vector2] = [
		center + Vector2(0, -5.8) * scale,
		center + Vector2(3.0, 2.8) * scale,
		center + Vector2(-2.6, 3.8) * scale
	]
	_draw_poly(t, inner, EMBER)

static func _draw_curse_eye(t: Node2D, center: Vector2) -> void:
	var eye: Array[Vector2] = [
		center + Vector2(-11, 0),
		center + Vector2(-5, -5.0),
		center + Vector2(0, -6.4),
		center + Vector2(5, -5.0),
		center + Vector2(11, 0),
		center + Vector2(5, 5.0),
		center + Vector2(0, 6.4),
		center + Vector2(-5, 5.0)
	]
	_draw_poly_outline(t, eye, Color(0.34, 0.08, 0.48, 0.96))
	_draw_circle(t, center, 4.4, RUNE)
	_draw_circle(t, center, 1.8, Color(0.04, 0.0, 0.07, 0.96))
	_draw_line(t, center + Vector2(-14, 0), center + Vector2(-20, -4), RUNE, 1.2)
	_draw_line(t, center + Vector2(14, 0), center + Vector2(20, -4), RUNE, 1.2)

static func _draw_skull_mask(t: Node2D, center: Vector2) -> void:
	_draw_circle(t, center + Vector2(0, -2.0), 8.2, BONE)
	_draw_poly_outline(t, [
		center + Vector2(-6.0, 2.8),
		center + Vector2(6.0, 2.8),
		center + Vector2(4.8, 10.0),
		center + Vector2(-4.8, 10.0)
	], BONE)
	_draw_circle(t, center + Vector2(-3.4, -2.8), 2.3, VOID)
	_draw_circle(t, center + Vector2(3.4, -2.8), 2.3, VOID)
	_draw_poly(t, [
		center + Vector2(0, 0.4),
		center + Vector2(2.0, 4.0),
		center + Vector2(-2.0, 4.0)
	], VOID)
	for x in [-3.0, 0.0, 3.0]:
		_draw_line(t, center + Vector2(x, 6.0), center + Vector2(x, 10.0), VOID, 0.9)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var positions: Array[Vector2] = [
		center + Vector2(0, -radius * 1.35),
		center + Vector2(-radius * 1.25, radius * 0.85),
		center + Vector2(radius * 1.25, radius * 0.85)
	]
	var colors: Array[Color] = [DARKNESS, FIRE, NATURE]
	for i in range(3):
		_draw_circle(t, positions[i], radius, colors[i])
	for i in range(3):
		_draw_line(t, positions[i], positions[(i + 1) % 3], Color(0.75, 0.26, 0.95, 0.72), 1.0)

static func draw_contour(t: Node2D) -> void:
	# Aura footprint + body contour. Keep compact; renderer/catalog handles rotation like other towers.
	t.draw_circle(_v(Vector2.ZERO), _r(40.0), OUTLINE_SOFT)
	t.draw_circle(_v(Vector2.ZERO), _r(30.0), OUTLINE)
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.ZERO, 24.0, 6, PI / 6.0))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Static ritual aura rings: communicates aura attack without using particles.
	_draw_arc(t, Vector2.ZERO, 39.0, -2.65, -0.52, Color(0.67, 0.22, 1.0, 0.36), 2.0)
	_draw_arc(t, Vector2.ZERO, 39.0, 0.50, 2.66, Color(1.0, 0.38, 0.13, 0.32), 2.0)
	_draw_arc(t, Vector2.ZERO, 33.0, -0.20, 1.75, Color(0.33, 1.0, 0.45, 0.30), 1.6)
	_draw_arc(t, Vector2.ZERO, 33.0, 2.95, 4.80, Color(0.73, 0.20, 1.0, 0.30), 1.6)

	# Ritual pedestal with black trim.
	_draw_poly_outline(t, [
		Vector2(-18, 24), Vector2(18, 24), Vector2(23, 12), Vector2(17, -16),
		Vector2(8, -26), Vector2(-8, -26), Vector2(-17, -16), Vector2(-23, 12)
	], Color(0.10, 0.06, 0.13, 0.98))
	_draw_poly(t, [
		Vector2(-13, 20), Vector2(13, 20), Vector2(16, 9), Vector2(12, -13),
		Vector2(4, -20), Vector2(-4, -20), Vector2(-12, -13), Vector2(-16, 9)
	], Color(0.23, 0.09, 0.30, 0.98))

	# Totem spine: clear silhouette for voodoo, not projectile cannon.
	_draw_poly_outline(t, [
		Vector2(-7, 22), Vector2(7, 22), Vector2(7, -27), Vector2(3, -33),
		Vector2(-3, -33), Vector2(-7, -27)
	], Color(0.19, 0.09, 0.12, 0.98))
	_draw_poly(t, [
		Vector2(-3.8, 19), Vector2(3.8, 19), Vector2(3.8, -25), Vector2(0, -30),
		Vector2(-3.8, -25)
	], Color(0.36, 0.13, 0.16, 0.98))

	# Ritual head + skull mask.
	_draw_circle(t, Vector2(0, -15), 16.5, Color(0.30, 0.08, 0.38, 0.98))
	_draw_skull_mask(t, Vector2(0, -16.5))
	_draw_curse_eye(t, Vector2(0, 5.5))

	# Fire/Nature/Darkness identity: side flames, leaf charms, void beads.
	_draw_flame(t, Vector2(-19, -9), 0.70)
	_draw_flame(t, Vector2(19, -9), 0.70)
	_draw_leaf(t, Vector2(-20, 12), -2.35, NATURE)
	_draw_leaf(t, Vector2(20, 12), -0.78, NATURE)
	_draw_circle(t, Vector2(-24, -24), 5.4, DARKNESS)
	_draw_circle(t, Vector2(24, -24), 5.4, DARKNESS)
	_draw_circle(t, Vector2(-25, 22), 4.2, FIRE)
	_draw_circle(t, Vector2(25, 22), 4.2, NATURE)

	# Charm strings / damage amplifier curse links.
	var left_charms: Array[Vector2] = [Vector2(-24, -24), Vector2(-19, -9), Vector2(-20, 12), Vector2(-25, 22)]
	_draw_polyline(t, left_charms, Color(0.86, 0.55, 1.0, 0.62), 1.2, false)
	var right_charms: Array[Vector2] = [Vector2(24, -24), Vector2(19, -9), Vector2(20, 12), Vector2(25, 22)]
	_draw_polyline(t, right_charms, Color(1.0, 0.42, 0.16, 0.54), 1.2, false)

	# Voodoo pins/runes around the aura: static and readable at catalog scale.
	var pin_angles: Array[float] = [-2.15, -1.15, -0.05, 0.95, 2.05]
	for a: float in pin_angles:
		var from := Vector2(cos(a), sin(a)) * 25.5
		var to := Vector2(cos(a), sin(a)) * 33.5
		_draw_line(t, from, to, RUNE, 1.25)
		_draw_circle(t, to, 2.0, EMBER)

	# Central life-drain bead.
	_draw_circle(t, Vector2(0, 18), 7.0, Color(0.08, 0.02, 0.11, 0.98))
	_draw_circle(t, Vector2(0, 18), 3.6, Color(0.78, 0.22, 1.0, 0.92))
	_draw_line(t, Vector2(-5, 18), Vector2(5, 18), Color(0.28, 1.0, 0.45, 0.65), 1.0)

	# Triple-element identity token.
	_draw_tri_element_token(t, Vector2(0, 33), 4.8)
