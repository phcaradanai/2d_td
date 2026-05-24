extends RefCounted

# Tower: Corrosion Tower 1
# Role: Acid mist — corrosive cloud that melts enemy armor and slows movement.
# Elements: Darkness + Water + Fire
# Visual source: custom by_id visual
# Visual intent: symmetrical acid injector tower; neutral-arrow style body + centered mist diffuser.
# Performance note: CanvasItem draw calls only; no nodes, particles, timers, or gameplay changes.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.60)

const DARKNESS := Color(0.47, 0.20, 0.80, 1.0)
const DARKNESS_DARK := Color(0.18, 0.08, 0.30, 1.0)
const WATER := Color(0.20, 0.82, 1.00, 1.0)
const WATER_DARK := Color(0.05, 0.28, 0.42, 1.0)
const FIRE := Color(1.00, 0.36, 0.10, 1.0)
const FIRE_DARK := Color(0.48, 0.10, 0.03, 1.0)
const ACID := Color(0.58, 1.00, 0.18, 1.0)
const ACID_DARK := Color(0.10, 0.36, 0.10, 1.0)
const ACID_GLOW := Color(0.72, 1.00, 0.26, 0.42)
const METAL := Color(0.36, 0.42, 0.42, 1.0)
const METAL_DARK := Color(0.13, 0.17, 0.18, 1.0)

static func _sv(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE

static func _sf(v: float) -> float:
	return v * VISUAL_SCALE

static func _sp(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in points:
		out.append(_sv(point))
	return out

static func _circle(t: Node2D, pos: Vector2, radius: float, color: Color, outline_width: float = 2.0) -> void:
	t.draw_circle(_sv(pos), _sf(radius + outline_width), OUTLINE)
	t.draw_circle(_sv(pos), _sf(radius), color)

static func _soft_circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(_sv(pos), _sf(radius), color)

static func _poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	var p := _sp(points)
	TowerVisualDrawUtils._draw_contour_poly(t, p)
	t.draw_colored_polygon(p, color)

static func _poly_raw_outline(t: Node2D, points: Array[Vector2], color: Color) -> void:
	var p := _sp(points)
	t.draw_colored_polygon(p, OUTLINE)
	var inner := PackedVector2Array()
	for point: Vector2 in points:
		inner.append(_sv(point * 0.92))
	t.draw_colored_polygon(inner, color)

static func _line(t: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color, width: float = 2.0) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, _sv(from_pos), _sv(to_pos), _sf(width + 1.8))
	t.draw_line(_sv(from_pos), _sv(to_pos), color, _sf(width), true)

static func _polyline(t: Node2D, points: Array[Vector2], color: Color, width: float = 2.0, closed: bool = false) -> void:
	var path := _sp(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _sf(width + 2.0), true)
	t.draw_polyline(path, color, _sf(width), true)

static func _arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(_sv(center), _sf(radius), start_angle, end_angle, 28, OUTLINE, _sf(width + 2.0), true)
	t.draw_arc(_sv(center), _sf(radius), start_angle, end_angle, 28, color, _sf(width), true)

static func _regular_poly(center: Vector2, radius: float, sides: int, rot: float = 0.0) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

static func _draw_corrosion_glyph(t: Node2D, center: Vector2, scale: float) -> void:
	# Acid drop + dissolved armor mark.
	var drop: Array[Vector2] = [
		center + Vector2(0, -7) * scale,
		center + Vector2(5, -1) * scale,
		center + Vector2(3, 6) * scale,
		center + Vector2(0, 8) * scale,
		center + Vector2(-4, 5) * scale,
		center + Vector2(-5, -1) * scale,
	]
	_poly(t, drop, ACID)
	_line(t, center + Vector2(-5, 8) * scale, center + Vector2(5, 8) * scale, FIRE, 1.6 * scale)
	_line(t, center + Vector2(-3, 11) * scale, center + Vector2(3, 11) * scale, WATER, 1.2 * scale)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := _sv(center)
	var r := _sf(radius)
	t.draw_circle(c, r + _sf(1.8), OUTLINE)
	var a0 := -PI / 2.0
	var colors: Array[Color] = [DARKNESS, WATER, FIRE]
	for i in range(3):
		var a1 := a0 + TAU * float(i) / 3.0
		var a2 := a0 + TAU * float(i + 1) / 3.0
		var wedge := PackedVector2Array([c, c + Vector2(cos(a1), sin(a1)) * r, c + Vector2(cos(a2), sin(a2)) * r])
		t.draw_colored_polygon(wedge, colors[i])
	t.draw_arc(c, r, 0.0, TAU, 28, OUTLINE, _sf(1.2), true)

static func _draw_vat_ribs(t: Node2D) -> void:
	for x in [-13.0, 0.0, 13.0]:
		_line(t, Vector2(x, -17), Vector2(x, 15), METAL_DARK, 1.6)
	for y in [-11.0, 2.0, 14.0]:
		_line(t, Vector2(-18, y), Vector2(18, y), METAL, 1.4)

static func _draw_acid_cloud(t: Node2D) -> void:
	# Static mist puffs around tower radius: communicates slow/control without particles.
	var puffs: Array[Vector2] = [
		Vector2(-33, -17), Vector2(-39, 0), Vector2(-33, 17),
		Vector2(31, -17), Vector2(40, 0), Vector2(31, 17),
		Vector2(-10, -31), Vector2(10, -31)
	]
	var sizes: Array[float] = [4.5, 5.8, 4.5, 4.5, 5.8, 4.5, 3.8, 3.8]
	for i in range(puffs.size()):
		_soft_circle(t, puffs[i], sizes[i], ACID_GLOW)
		t.draw_arc(_sv(puffs[i]), _sf(sizes[i] + 1.2), 0.2, PI * 1.6, 14, Color(0.0, 0.0, 0.0, 0.42), _sf(0.9), true)
	for i in range(3):
		var rr := 32.0 + float(i) * 5.5
		var alpha := 0.24 - float(i) * 0.045
		_arc(t, Vector2.ZERO, rr, -2.8 + float(i) * 0.20, -0.35 + float(i) * 0.15, Color(0.58, 1.0, 0.18, alpha), 1.4)
		_arc(t, Vector2.ZERO, rr, 0.35 - float(i) * 0.10, 2.85 - float(i) * 0.20, Color(0.20, 0.82, 1.0, alpha), 1.3)

static func draw_contour(t: Node2D) -> void:
	# Compact contour that fits catalog cards and lets the shared renderer control rotation.
	t.draw_circle(Vector2.ZERO, _sf(42.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _sf(33.0), OUTLINE)
	TowerVisualDrawUtils._draw_contour_poly(t, _sp([
		Vector2(-24, -17), Vector2(-10, -25), Vector2(18, -21), Vector2(29, -10),
		Vector2(29, 10), Vector2(18, 21), Vector2(-10, 25), Vector2(-24, 17)
	]))
	TowerVisualDrawUtils._draw_contour_poly(t, _sp([
		Vector2(10, -8), Vector2(38, -10), Vector2(46, 0), Vector2(38, 10), Vector2(10, 8)
	]))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Slow/control field
	_draw_acid_cloud(t)

	# Dark corrosive base: neutral-arrow style hard-surface silhouette.
	_poly(t, [
		Vector2(-25, -17), Vector2(-11, -26), Vector2(18, -22), Vector2(30, -10),
		Vector2(30, 10), Vector2(18, 22), Vector2(-11, 26), Vector2(-25, 17)
	], DARKNESS_DARK)
	_poly(t, [
		Vector2(-20, -13), Vector2(-8, -20), Vector2(14, -17), Vector2(23, -8),
		Vector2(23, 8), Vector2(14, 17), Vector2(-8, 20), Vector2(-20, 13)
	], Color(0.18, 0.18, 0.20, 1.0))

	# Acid glass chamber, centered so the forward diffuser has a clear origin.
	_poly(t, [
		Vector2(-15, -15), Vector2(13, -15), Vector2(19, -7), Vector2(19, 7),
		Vector2(13, 15), Vector2(-15, 15), Vector2(-21, 7), Vector2(-21, -7)
	], Color(0.11, 0.30, 0.28, 1.0))
	_poly(t, [
		Vector2(-12, -10), Vector2(11, -10), Vector2(15, -4), Vector2(15, 4),
		Vector2(11, 10), Vector2(-12, 10), Vector2(-16, 4), Vector2(-16, -4)
	], Color(0.35, 0.78, 0.20, 0.82))
	_poly(t, [
		Vector2(-12, 0), Vector2(11, 0), Vector2(15, 4), Vector2(11, 10),
		Vector2(-12, 10), Vector2(-16, 4)
	], Color(0.68, 1.00, 0.18, 0.94))

	# Inner bubbles
	var bubbles: Array[Vector2] = [Vector2(-8, -6), Vector2(6, -6), Vector2(-8, 6), Vector2(6, 6), Vector2(0, 0)]
	for b: Vector2 in bubbles:
		_circle(t, b, 2.1, Color(0.90, 1.00, 0.42, 0.80), 0.8)

	_draw_vat_ribs(t)

	# Fire heating coil under vat
	_polyline(t, [
		Vector2(-16, 20), Vector2(-10, 17), Vector2(-4, 20), Vector2(2, 17), Vector2(8, 20), Vector2(14, 17)
	], FIRE, 1.6, false)
	_polyline(t, [
		Vector2(-16, -20), Vector2(-10, -17), Vector2(-4, -20), Vector2(2, -17), Vector2(8, -20), Vector2(14, -17)
	], FIRE, 1.6, false)

	# Centered mist injector / acid diffuser, not a cannon barrel.
	_poly(t, [
		Vector2(17, -8), Vector2(35, -13), Vector2(44, 0), Vector2(35, 13), Vector2(17, 8)
	], METAL_DARK)
	_poly(t, [
		Vector2(23, -4.8), Vector2(37, -8.0), Vector2(41, 0), Vector2(37, 8.0), Vector2(23, 4.8)
	], ACID_DARK)
	_circle(t, Vector2(43, 0), 4.4, ACID, 1.2)
	var mist_drops: Array[Vector2] = [Vector2(51, -7), Vector2(54, 0), Vector2(51, 7)]
	for d: Vector2 in mist_drops:
		_circle(t, d, 1.8, ACID_GLOW, 0.6)

	# Mirrored pressure canisters keep the silhouette balanced around the firing axis.
	_circle(t, Vector2(-23, -12), 5.8, WATER_DARK, 1.6)
	_circle(t, Vector2(-23, -12), 3.0, WATER, 1.0)
	_circle(t, Vector2(-23, 12), 5.8, DARKNESS_DARK, 1.6)
	_circle(t, Vector2(-23, 12), 3.0, DARKNESS, 1.0)

	# Corrosion glyph makes role readable at small size.
	_draw_corrosion_glyph(t, Vector2(0, -2), 0.76)

	# Field anchors / acid drip pods
	var pods: Array[Vector2] = [Vector2(-28, -23), Vector2(28, -23), Vector2(-28, 23), Vector2(28, 23)]
	for pod: Vector2 in pods:
		_circle(t, pod, 4.0, ACID_DARK, 1.2)
		_circle(t, pod, 2.1, ACID, 0.7)

	# Tri-element token
	_draw_tri_element_token(t, Vector2(0, 38), 6.0)
