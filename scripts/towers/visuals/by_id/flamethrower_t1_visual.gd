extends RefCounted
class_name TowerVisualFlamethrowerT1

# Tower: Flamethrower Tower 1
# Role: Hellfire barrage — rapid explosive splash shells fueled by dark flame.
# Elements: Darkness + Fire + Earth
# Visual source: custom by_id visual
# Visual intent: Premium dark-earth flame artillery with twin hellfire nozzles, armored pressure tank,
#   molten charge core, and static blast markers. It should read as land-only splash/ordnance,
#   not an aura/support tower and not a simple single-target gun.
# Performance note: CanvasItem draw calls only; no nodes, particles, tweens, timers, or gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.94)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)

const DARKNESS := Color(0.28, 0.11, 0.48, 0.98)
const DARKNESS_GLOW := Color(0.48, 0.17, 0.78, 0.72)
const FIRE := Color(1.0, 0.36, 0.06, 0.98)
const FIRE_HOT := Color(1.0, 0.78, 0.18, 0.95)
const EARTH := Color(0.48, 0.35, 0.20, 0.98)
const EARTH_EDGE := Color(0.74, 0.54, 0.30, 0.95)
const STEEL := Color(0.19, 0.17, 0.16, 0.98)
const STEEL_HI := Color(0.38, 0.31, 0.25, 0.96)

static func _v(p: Vector2) -> Vector2:
	return p * VISUAL_SCALE

static func _r(value: float) -> float:
	return value * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in points:
		out.append(_v(point))
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		out.append(_v(center + Vector2(cos(a), sin(a)) * radius))
	return out

static func _draw_poly(t: Node2D, points: Array[Vector2], color: Color, outline_width: float = 2.4) -> void:
	var p := _poly(points)
	TowerVisualDrawUtils._draw_contour_poly(t, p)
	if outline_width > 0.0:
		t.draw_polyline(_closed(p), OUTLINE, outline_width, true)
	t.draw_colored_polygon(p, color)

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	t.draw_line(_v(a), _v(b), OUTLINE, _r(width + 2.0), true)
	t.draw_line(_v(a), _v(b), color, _r(width), true)

static func _draw_circle(t: Node2D, center: Vector2, radius: float, color: Color, outline_width: float = 2.0) -> void:
	t.draw_circle(_v(center), _r(radius + outline_width), OUTLINE)
	t.draw_circle(_v(center), _r(radius), color)

static func _draw_ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(_v(center), _r(radius), 0.0, TAU, 40, OUTLINE, _r(width + 2.0), true)
	t.draw_arc(_v(center), _r(radius), 0.0, TAU, 40, color, _r(width), true)

static func _draw_arc(t: Node2D, center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(_v(center), _r(radius), from_angle, to_angle, 18, OUTLINE_SOFT, _r(width + 2.0), true)
	t.draw_arc(_v(center), _r(radius), from_angle, to_angle, 18, color, _r(width), true)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := _v(center)
	var r := _r(radius)
	t.draw_circle(c, r + _r(2.2), OUTLINE)
	var points := [
		center + Vector2(0.0, -radius * 1.15),
		center + Vector2(radius * 1.05, radius * 0.72),
		center + Vector2(-radius * 1.05, radius * 0.72)
	]
	var colors: Array[Color] = [DARKNESS, FIRE, EARTH]
	for i in range(3):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % 3]
		_draw_line(t, a, b, colors[i], 1.4)
	_draw_circle(t, points[0], radius * 0.34, DARKNESS_GLOW, 1.2)
	_draw_circle(t, points[1], radius * 0.34, FIRE_HOT, 1.2)
	_draw_circle(t, points[2], radius * 0.34, EARTH_EDGE, 1.2)

static func _draw_shell_glyph(t: Node2D, center: Vector2) -> void:
	# Compact explosive-shell badge: round shell body + hot fuse. Static and readable at catalog scale.
	_draw_circle(t, center, 4.3, Color(0.09, 0.06, 0.04, 0.96), 1.2)
	_draw_line(t, center + Vector2(-2.4, -1.0), center + Vector2(2.6, -1.0), FIRE_HOT, 1.0)
	_draw_line(t, center + Vector2(0.0, -4.0), center + Vector2(0.0, -7.0), FIRE, 1.3)
	_draw_circle(t, center + Vector2(0.0, -7.8), 1.7, FIRE_HOT, 0.8)

static func draw_contour(t: Node2D) -> void:
	# Compact silhouette only. Renderer/catalog controls rotation; this file only controls local size.
	TowerVisualDrawUtils._draw_contour_circle(t, _v(Vector2(-9, 0)), _r(20.0))
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(-25, -18), Vector2(5, -23), Vector2(23, -16),
		Vector2(23, 16), Vector2(5, 23), Vector2(-25, 18)
	]))
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(1, -11), Vector2(32, -16), Vector2(38, -8),
		Vector2(20, -3), Vector2(38, 8), Vector2(32, 16),
		Vector2(1, 11)
	]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var dark_col := DARKNESS
	var fire_col := FIRE
	var earth_col := EARTH
	if el_colors.size() >= 3:
		dark_col = el_colors[0]
		fire_col = el_colors[1]
		earth_col = el_colors[2]

	# Ground-only splash footprint: muted quake/blast arcs, static for perf.
	_draw_arc(t, Vector2(-1, 2), 34.0, deg_to_rad(205), deg_to_rad(330), Color(0.88, 0.42, 0.13, 0.36), 2.0)
	_draw_arc(t, Vector2(-2, 1), 27.0, deg_to_rad(28), deg_to_rad(148), Color(0.43, 0.18, 0.65, 0.32), 1.8)
	_draw_arc(t, Vector2(1, 0), 22.0, deg_to_rad(156), deg_to_rad(210), Color(0.67, 0.48, 0.26, 0.34), 1.7)

	# Earth armor base, faceted and heavy.
	_draw_poly(t, [
		Vector2(-25, -14), Vector2(-8, -22), Vector2(11, -17), Vector2(21, -7),
		Vector2(21, 7), Vector2(11, 17), Vector2(-8, 22), Vector2(-25, 14)
	], earth_col.darkened(0.18))
	_draw_poly(t, [
		Vector2(-20, -11), Vector2(-8, -17), Vector2(9, -13), Vector2(16, -5),
		Vector2(16, 5), Vector2(9, 13), Vector2(-8, 17), Vector2(-20, 11)
	], STEEL)

	# Rear dark-fuel pressure tank.
	_draw_circle(t, Vector2(-14, 0), 15.0, dark_col.darkened(0.22), 2.0)
	_draw_ring(t, Vector2(-14, 0), 11.0, DARKNESS_GLOW, 1.5)
	_draw_line(t, Vector2(-26, -5), Vector2(-3, -8), STEEL_HI, 1.5)
	_draw_line(t, Vector2(-26, 5), Vector2(-3, 8), STEEL_HI, 1.5)
	_draw_shell_glyph(t, Vector2(-14, 0))

	# Molten ignition core.
	_draw_circle(t, Vector2(2, 0), 10.5, Color(0.08, 0.035, 0.02, 0.98), 2.4)
	_draw_circle(t, Vector2(2, 0), 7.4, fire_col.darkened(0.05), 1.4)
	_draw_circle(t, Vector2(2, 0), 3.7, FIRE_HOT, 1.0)

	# Twin-nozzle hellfire projector: rapid barrage identity.
	_draw_poly(t, [
		Vector2(2, -11), Vector2(25, -16), Vector2(38, -10), Vector2(36, -4),
		Vector2(16, -3), Vector2(2, -6)
	], STEEL_HI)
	_draw_poly(t, [
		Vector2(2, 6), Vector2(16, 3), Vector2(36, 4), Vector2(38, 10),
		Vector2(25, 16), Vector2(2, 11)
	], STEEL_HI)
	_draw_poly(t, [
		Vector2(18, -8), Vector2(39, -10), Vector2(44, -6), Vector2(38, -2), Vector2(18, -3)
	], fire_col.darkened(0.12))
	_draw_poly(t, [
		Vector2(18, 3), Vector2(38, 2), Vector2(44, 6), Vector2(39, 10), Vector2(18, 8)
	], fire_col.darkened(0.12))

	# Flame mouths and dark-flame charge.
	_draw_circle(t, Vector2(39, -6), 3.7, Color(0.06, 0.02, 0.015, 0.98), 1.0)
	_draw_circle(t, Vector2(39, 6), 3.7, Color(0.06, 0.02, 0.015, 0.98), 1.0)
	_draw_circle(t, Vector2(41, -6), 1.9, FIRE_HOT, 0.7)
	_draw_circle(t, Vector2(41, 6), 1.9, FIRE_HOT, 0.7)

	# Static hellfire tongues at the tips. No particles; just readable direction/role markers.
	var flame_a: Array[Vector2] = [Vector2(42, -10), Vector2(54, -14), Vector2(49, -7), Vector2(58, -5), Vector2(43, -3)]
	var flame_b: Array[Vector2] = [Vector2(43, 3), Vector2(58, 5), Vector2(49, 7), Vector2(54, 14), Vector2(42, 10)]
	_draw_poly(t, flame_a, Color(1.0, 0.24, 0.035, 0.68), 1.4)
	_draw_poly(t, flame_b, Color(1.0, 0.24, 0.035, 0.68), 1.4)
	_draw_line(t, Vector2(43, -6), Vector2(54, -9), FIRE_HOT, 1.3)
	_draw_line(t, Vector2(43, 6), Vector2(54, 9), FIRE_HOT, 1.3)

	# Earth crack/gunpowder seams.
	_draw_line(t, Vector2(-5, 15), Vector2(-1, 20), EARTH_EDGE, 1.1)
	_draw_line(t, Vector2(8, 14), Vector2(14, 19), EARTH_EDGE, 1.1)
	_draw_line(t, Vector2(-4, -15), Vector2(3, -20), EARTH_EDGE, 1.1)

	# Explosion markers around base make splash role obvious.
	var markers: Array[Vector2] = [Vector2(-31, -12), Vector2(-31, 12), Vector2(-4, -29), Vector2(8, 28)]
	for marker: Vector2 in markers:
		_draw_circle(t, marker, 2.2, Color(1.0, 0.52, 0.11, 0.62), 0.8)
		_draw_line(t, marker + Vector2(-2.8, 0), marker + Vector2(2.8, 0), Color(1.0, 0.68, 0.18, 0.48), 0.9)

	_draw_tri_element_token(t, Vector2(0, 31), 5.2)
