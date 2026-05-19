extends RefCounted
class_name TowerVisualRootsT1

# Tower: Roots Tower 1
# Role: Entangling roots / slow-control field
# Elements: Darkness + Nature + Earth
# Visual source: custom by_id visual
# Visual intent: Premium root-cage control tower: a dark-earth altar splitting the ground,
#   living vines forming a cage, and thorn pylons showing land-only slow radius.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const DARKNESS_COL := Color(0.28, 0.12, 0.44, 1.0)
const NATURE_COL := Color(0.30, 0.88, 0.36, 1.0)
const EARTH_COL := Color(0.56, 0.39, 0.20, 1.0)
const ROOT_BARK := Color(0.30, 0.17, 0.09, 1.0)
const ROOT_HIGHLIGHT := Color(0.62, 0.43, 0.22, 1.0)
const POISON_GLOW := Color(0.42, 1.0, 0.42, 0.85)
const VOID_GLOW := Color(0.38, 0.16, 0.62, 0.88)

static func _sv(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE

static func _sf(v: float) -> float:
	return v * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_sv(p))
	return out

static func _closed(points: Array[Vector2]) -> PackedVector2Array:
	var out := _poly(points)
	if out.size() > 0:
		out.append(out[0])
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		pts.append(_sv(center + Vector2(cos(a), sin(a)) * radius))
	return pts

static func _draw_poly(t: Node2D, points: Array[Vector2], fill: Color, stroke: Color = OUTLINE, stroke_width: float = 1.6) -> void:
	var p := _poly(points)
	TowerVisualDrawUtils._draw_contour_poly(t, p)
	t.draw_colored_polygon(p, fill)
	t.draw_polyline(_closed(points), stroke, _sf(stroke_width), true)

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, _sv(a), _sv(b), _sf(width + 2.0))
	t.draw_line(_sv(a), _sv(b), col, _sf(width), true)

static func _draw_path(t: Node2D, pts: Array[Vector2], col: Color, width: float) -> void:
	var p := _poly(pts)
	t.draw_polyline(p, OUTLINE, _sf(width + 2.4), true)
	t.draw_polyline(p, col, _sf(width), true)
	t.draw_polyline(p, col.lightened(0.28), _sf(max(1.0, width * 0.32)), true)

static func _draw_ring_arc(t: Node2D, radius: float, from_angle: float, to_angle: float, col: Color, width: float) -> void:
	t.draw_arc(Vector2.ZERO, _sf(radius), from_angle, to_angle, 32, OUTLINE_SOFT, _sf(width + 1.8), true)
	t.draw_arc(Vector2.ZERO, _sf(radius), from_angle, to_angle, 32, col, _sf(width), true)

static func _draw_circle(t: Node2D, pos: Vector2, radius: float, col: Color, outline: bool = true) -> void:
	if outline:
		TowerVisualDrawUtils._draw_contour_circle(t, _sv(pos), _sf(radius))
	t.draw_circle(_sv(pos), _sf(radius), col)

static func _draw_root_cage(t: Node2D) -> void:
	var root_sets: Array[Array] = [
		[Vector2(-8, 8), Vector2(-18, 10), Vector2(-27, 4), Vector2(-32, -7)],
		[Vector2(8, 8), Vector2(18, 10), Vector2(27, 4), Vector2(32, -7)],
		[Vector2(-6, -8), Vector2(-17, -14), Vector2(-22, -25), Vector2(-18, -34)],
		[Vector2(6, -8), Vector2(17, -14), Vector2(22, -25), Vector2(18, -34)],
		[Vector2(-9, 1), Vector2(-20, -2), Vector2(-27, -13), Vector2(-26, -24)],
		[Vector2(9, 1), Vector2(20, -2), Vector2(27, -13), Vector2(26, -24)]
	]
	for raw in root_sets:
		var pts: Array[Vector2] = []
		for p in raw:
			pts.append(p)
		_draw_path(t, pts, ROOT_BARK, 4.1)

	# cage cross-bindings
	_draw_path(t, [Vector2(-25, -14), Vector2(-12, -20), Vector2(0, -22), Vector2(12, -20), Vector2(25, -14)], NATURE_COL.darkened(0.10), 2.2)
	_draw_path(t, [Vector2(-28, 1), Vector2(-13, -4), Vector2(0, -6), Vector2(13, -4), Vector2(28, 1)], ROOT_HIGHLIGHT, 2.0)

	# thorn tips / poison seed points
	var tips: Array[Vector2] = [
		Vector2(-32, -7), Vector2(32, -7), Vector2(-18, -34), Vector2(18, -34),
		Vector2(-26, -24), Vector2(26, -24)
	]
	for tip: Vector2 in tips:
		_draw_circle(t, tip, 2.9, POISON_GLOW, true)
		_draw_circle(t, tip, 1.25, Color(0.76, 1.0, 0.55, 0.95), false)

static func _draw_slow_field(t: Node2D) -> void:
	# broken control rings: communicates slow radius without showing an expensive animated area.
	_draw_ring_arc(t, 38.0, -2.92, -2.20, Color(0.22, 1.0, 0.45, 0.38), 1.35)
	_draw_ring_arc(t, 38.0, -0.95, -0.18, Color(0.22, 1.0, 0.45, 0.38), 1.35)
	_draw_ring_arc(t, 38.0, 0.60, 1.36, Color(0.38, 0.18, 0.62, 0.34), 1.35)
	_draw_ring_arc(t, 38.0, 2.15, 2.86, Color(0.38, 0.18, 0.62, 0.34), 1.35)

	var anchors: Array[Vector2] = [Vector2(-32, 24), Vector2(32, 24), Vector2(-32, -22), Vector2(32, -22)]
	for a: Vector2 in anchors:
		_draw_circle(t, a, 4.2, EARTH_COL.darkened(0.20), true)
		_draw_circle(t, a, 2.0, NATURE_COL.lightened(0.18), false)

static func _draw_earth_base(t: Node2D) -> void:
	_draw_poly(t, [
		Vector2(-20, 18), Vector2(-8, 26), Vector2(8, 26), Vector2(20, 18),
		Vector2(15, 8), Vector2(-15, 8)
	], EARTH_COL.darkened(0.28), OUTLINE, 1.45)

	_draw_poly(t, [
		Vector2(-15, 14), Vector2(-6, 19), Vector2(6, 19), Vector2(15, 14),
		Vector2(9, 10), Vector2(-9, 10)
	], EARTH_COL.lightened(0.05), OUTLINE_SOFT, 1.0)

	# fissures
	_draw_line(t, Vector2(-8, 18), Vector2(-13, 12), Color(0.13, 0.07, 0.04, 0.82), 1.1)
	_draw_line(t, Vector2(6, 19), Vector2(12, 12), Color(0.13, 0.07, 0.04, 0.82), 1.1)
	_draw_line(t, Vector2(0, 23), Vector2(0, 16), Color(0.13, 0.07, 0.04, 0.82), 1.0)

static func _draw_core(t: Node2D) -> void:
	# Dark seed altar body
	_draw_poly(t, [
		Vector2(-17, -16), Vector2(0, -25), Vector2(17, -16),
		Vector2(20, 2), Vector2(12, 18), Vector2(-12, 18), Vector2(-20, 2)
	], DARKNESS_COL.darkened(0.22), OUTLINE, 1.55)

	_draw_poly(t, [
		Vector2(-10, -12), Vector2(0, -18), Vector2(10, -12),
		Vector2(12, 3), Vector2(6, 11), Vector2(-6, 11), Vector2(-12, 3)
	], ROOT_BARK.darkened(0.08), OUTLINE_SOFT, 1.0)

	# root-cage core / seed
	_draw_circle(t, Vector2.ZERO, 8.8, Color(0.02, 0.07, 0.025, 1.0), true)
	_draw_circle(t, Vector2.ZERO, 5.8, VOID_GLOW, false)
	_draw_circle(t, Vector2.ZERO, 3.1, POISON_GLOW, false)

	# grasp glyph inside core
	_draw_line(t, Vector2(-5.2, -0.8), Vector2(-1.7, 3.4), NATURE_COL.lightened(0.10), 1.2)
	_draw_line(t, Vector2(5.2, -0.8), Vector2(1.7, 3.4), NATURE_COL.lightened(0.10), 1.2)
	_draw_line(t, Vector2(-1.7, 3.4), Vector2(0.0, -4.8), Color(0.84, 1.0, 0.62, 0.95), 1.1)
	_draw_line(t, Vector2(1.7, 3.4), Vector2(0.0, -4.8), Color(0.84, 1.0, 0.62, 0.95), 1.1)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := _sv(center)
	var r := _sf(radius)
	TowerVisualDrawUtils._draw_contour_circle(t, c, r + _sf(1.3))
	t.draw_circle(c, r + _sf(1.1), Color(0.03, 0.025, 0.035, 0.94))

	var centers: Array[Vector2] = [
		center + Vector2(-radius * 0.66, 0.25),
		center + Vector2(radius * 0.66, 0.25),
		center + Vector2(0.0, -radius * 0.70)
	]
	var cols: Array[Color] = [DARKNESS_COL, NATURE_COL, EARTH_COL]
	for i in range(3):
		_draw_circle(t, centers[i], radius * 0.38, cols[i], false)

static func draw_contour(t: Node2D) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, _sf(41.0))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, _sf(28.0))

	# Main silhouettes only; top pass adds interior color.
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(-20, 18), Vector2(-8, 26), Vector2(8, 26), Vector2(20, 18),
		Vector2(15, 8), Vector2(-15, 8)
	]))
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(-17, -16), Vector2(0, -25), Vector2(17, -16),
		Vector2(20, 2), Vector2(12, 18), Vector2(-12, 18), Vector2(-20, 2)
	]))
	var tendrils: Array[Array] = [
		[Vector2(-8, 8), Vector2(-18, 10), Vector2(-27, 4), Vector2(-32, -7)],
		[Vector2(8, 8), Vector2(18, 10), Vector2(27, 4), Vector2(32, -7)],
		[Vector2(-6, -8), Vector2(-17, -14), Vector2(-22, -25), Vector2(-18, -34)],
		[Vector2(6, -8), Vector2(17, -14), Vector2(22, -25), Vector2(18, -34)]
	]
	for raw in tendrils:
		var pts: Array[Vector2] = []
		for p in raw:
			pts.append(p)
		var pp := _poly(pts)
		t.draw_polyline(pp, OUTLINE, _sf(6.6), true)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	_draw_slow_field(t)
	_draw_earth_base(t)
	_draw_root_cage(t)
	_draw_core(t)

	# side moss/leaf trims
	_draw_poly(t, [Vector2(-19, -2), Vector2(-27, 2), Vector2(-21, 8), Vector2(-14, 5)], NATURE_COL.darkened(0.08), OUTLINE_SOFT, 0.9)
	_draw_poly(t, [Vector2(19, -2), Vector2(27, 2), Vector2(21, 8), Vector2(14, 5)], NATURE_COL.darkened(0.08), OUTLINE_SOFT, 0.9)
	_draw_poly(t, [Vector2(-8, -20), Vector2(-1, -30), Vector2(4, -20)], DARKNESS_COL.lightened(0.08), OUTLINE_SOFT, 0.85)
	_draw_poly(t, [Vector2(8, -20), Vector2(1, -30), Vector2(-4, -20)], DARKNESS_COL.lightened(0.08), OUTLINE_SOFT, 0.85)

	# small toxin/slow droplets
	var drops: Array[Vector2] = [Vector2(-24, 10), Vector2(24, 12), Vector2(-11, -26), Vector2(12, -27)]
	for d: Vector2 in drops:
		_draw_circle(t, d, 1.8, POISON_GLOW, true)

	_draw_tri_element_token(t, Vector2(0, 31), 5.2)
