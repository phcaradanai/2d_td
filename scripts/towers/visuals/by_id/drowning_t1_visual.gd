extends RefCounted

# Tower: Drowning Tower 1
# Role: Abyssal grasp — heavy single-target damage
# Elements: darkness, water, nature
# Visual source: custom by_id visual
# Visual intent: premium abyssal vortex harpoon / drowning grasp engine.
# Performance note: CanvasItem draw calls only; no particles, nodes, timers, or gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.90)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)
const VOID_DARK := Color(0.055, 0.028, 0.105, 0.98)
const VOID_PURPLE := Color(0.42, 0.16, 0.72, 0.95)
const ABYSS_BLUE := Color(0.05, 0.38, 0.66, 0.95)
const WATER_GLOW := Color(0.23, 0.86, 1.0, 0.82)
const NATURE_GLOW := Color(0.24, 0.86, 0.43, 0.78)
const BONE_WHITE := Color(0.78, 0.92, 0.96, 0.90)
const METAL_DARK := Color(0.12, 0.15, 0.21, 0.98)
const METAL_EDGE := Color(0.28, 0.36, 0.48, 0.95)

static func _sv(v: Vector2) -> Vector2:
	return v * VISUAL_SCALE

static func _sr(r: float) -> float:
	return r * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_sv(p))
	return out

static func _circle(t: Node2D, p: Vector2, r: float, c: Color) -> void:
	t.draw_circle(_sv(p), _sr(r), c)

static func _line(t: Node2D, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	t.draw_line(_sv(a), _sv(b), c, _sr(w), true)

static func _poly_fill(t: Node2D, points: Array[Vector2], c: Color) -> void:
	t.draw_colored_polygon(_poly(points), c)

static func _poly_outline(t: Node2D, points: Array[Vector2], fill: Color) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, _poly(points))
	t.draw_colored_polygon(_poly(points), fill)

static func _stroked_line(t: Node2D, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	_line(t, a, b, OUTLINE, w + 3.0)
	_line(t, a, b, c, w)

static func _stroked_polyline(t: Node2D, points: Array[Vector2], c: Color, w: float, closed: bool = false) -> void:
	var path := _poly(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, _sr(w + 3.0), true)
	t.draw_polyline(path, c, _sr(w), true)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rotation + TAU * float(i) / float(sides)
		pts.append(_sv(center + Vector2(cos(a), sin(a)) * radius))
	return pts

static func _contour_circle(t: Node2D, p: Vector2, r: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, _sv(p), _sr(r))

static func _draw_abyss_swirl(t: Node2D) -> void:
	var rings: Array[float] = [21.0, 15.5, 10.0]
	var cols: Array[Color] = [Color(0.04, 0.18, 0.34, 0.78), Color(0.16, 0.55, 0.82, 0.62), Color(0.42, 0.12, 0.62, 0.72)]
	for i in range(rings.size()):
		_circle(t, Vector2.ZERO, rings[i] + 3.4, OUTLINE_SOFT)
		_circle(t, Vector2.ZERO, rings[i], cols[i])

	var swirl_a: Array[Vector2] = [Vector2(-18, -2), Vector2(-8, -10), Vector2(5, -7), Vector2(11, 0), Vector2(2, 8), Vector2(-8, 5)]
	var swirl_b: Array[Vector2] = [Vector2(17, 2), Vector2(7, 10), Vector2(-5, 7), Vector2(-11, 0), Vector2(-2, -8), Vector2(8, -5)]
	_stroked_polyline(t, swirl_a, WATER_GLOW, 2.5, false)
	_stroked_polyline(t, swirl_b, VOID_PURPLE, 2.5, false)
	_circle(t, Vector2.ZERO, 4.7, OUTLINE)
	_circle(t, Vector2.ZERO, 3.0, Color(0.78, 0.96, 1.0, 0.96))

static func _draw_grasp_glyph(t: Node2D) -> void:
	# Three claw-like undertow marks: reads as abyssal grasp without adding animated VFX.
	var claws: Array[Array] = [
		[Vector2(-10, 0), Vector2(-15, 10), Vector2(-12, 15)],
		[Vector2(0, 2), Vector2(-2, 15), Vector2(2, 19)],
		[Vector2(10, 0), Vector2(15, 10), Vector2(12, 15)]
	]
	for claw in claws:
		var p0: Vector2 = claw[0]
		var p1: Vector2 = claw[1]
		var p2: Vector2 = claw[2]
		_stroked_polyline(t, [p0, p1, p2], Color(0.70, 0.94, 1.0, 0.70), 1.55, false)

static func _draw_tri_element_token(t: Node2D, center: Vector2, r: float) -> void:
	_contour_circle(t, center, r + 2.2)
	_circle(t, center, r + 1.0, Color(0.025, 0.03, 0.05, 0.92))
	var offsets: Array[Vector2] = [Vector2(-4.4, -1.7), Vector2(4.4, -1.7), Vector2(0.0, 4.1)]
	var colors: Array[Color] = [VOID_PURPLE, WATER_GLOW, NATURE_GLOW]
	for i in range(3):
		_circle(t, center + offsets[i], 3.05, OUTLINE)
		_circle(t, center + offsets[i], 2.0, colors[i])

static func _draw_harpoon_emitter(t: Node2D) -> void:
	# Single target identity: a narrow abyssal lance, not an AoE cannon.
	var rail_top: Array[Vector2] = [Vector2(16, -8), Vector2(32, -6), Vector2(36, -2), Vector2(17, -2)]
	var rail_bottom: Array[Vector2] = [Vector2(16, 8), Vector2(32, 6), Vector2(36, 2), Vector2(17, 2)]
	_poly_outline(t, rail_top, METAL_DARK)
	_poly_outline(t, rail_bottom, METAL_DARK)
	_stroked_line(t, Vector2(18, 0), Vector2(40, 0), Color(0.55, 0.95, 1.0, 0.92), 2.5)
	var tip: Array[Vector2] = [Vector2(37, -5), Vector2(48, 0), Vector2(37, 5), Vector2(41, 0)]
	_poly_outline(t, tip, Color(0.28, 0.72, 0.92, 0.94))
	_circle(t, Vector2(24, 0), 5.6, OUTLINE)
	_circle(t, Vector2(24, 0), 3.6, WATER_GLOW)

static func draw_contour(t: Node2D) -> void:
	# Compact silhouette, scaled in helper methods so catalog/renderer rotation remains untouched.
	_circle(t, Vector2.ZERO, 38.0, OUTLINE_SOFT)
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.ZERO, 28.0, 8, PI / 8.0))
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([Vector2(15, -11), Vector2(48, 0), Vector2(15, 11), Vector2(22, 0)]))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Abyssal base shell.
	_circle(t, Vector2.ZERO, 35.5, OUTLINE_SOFT)
	t.draw_colored_polygon(_regular_poly(Vector2.ZERO, 29.0, 8, PI / 8.0), OUTLINE)
	t.draw_colored_polygon(_regular_poly(Vector2.ZERO, 25.0, 8, PI / 8.0), Color(0.07, 0.09, 0.15, 0.98))
	t.draw_colored_polygon(_regular_poly(Vector2.ZERO, 20.5, 8, PI / 8.0), Color(0.11, 0.14, 0.22, 0.98))

	# Nature-root clamps holding the drowned void basin.
	var roots: Array[Array] = [
		[Vector2(-28, -13), Vector2(-16, -8), Vector2(-10, -11), Vector2(-20, -18)],
		[Vector2(-28, 13), Vector2(-16, 8), Vector2(-10, 11), Vector2(-20, 18)],
		[Vector2(2, -29), Vector2(9, -17), Vector2(4, -12), Vector2(-5, -24)],
		[Vector2(2, 29), Vector2(9, 17), Vector2(4, 12), Vector2(-5, 24)]
	]
	for root in roots:
		var rp: Array[Vector2] = []
		for p in root:
			rp.append(p)
		_poly_outline(t, rp, Color(0.12, 0.48, 0.29, 0.95))

	# Water pressure crescent plates.
	var crescent_top: Array[Vector2] = [Vector2(-15, -23), Vector2(6, -24), Vector2(15, -16), Vector2(0, -12), Vector2(-17, -14)]
	var crescent_bottom: Array[Vector2] = [Vector2(-15, 23), Vector2(6, 24), Vector2(15, 16), Vector2(0, 12), Vector2(-17, 14)]
	_poly_outline(t, crescent_top, Color(0.07, 0.34, 0.56, 0.96))
	_poly_outline(t, crescent_bottom, Color(0.07, 0.34, 0.56, 0.96))

	# Central single-target abyss vortex.
	_draw_abyss_swirl(t)
	_draw_grasp_glyph(t)

	# Harpoon/lance emitter for heavy single-target attack.
	_draw_harpoon_emitter(t)

	# Static undertow tethers; visual only, no gameplay logic.
	var tether_sets: Array[Array] = [
		[Vector2(-27, -3), Vector2(-39, -11), Vector2(-45, -4)],
		[Vector2(-27, 3), Vector2(-39, 11), Vector2(-45, 4)],
		[Vector2(7, -27), Vector2(20, -37), Vector2(29, -31)],
		[Vector2(7, 27), Vector2(20, 37), Vector2(29, 31)]
	]
	for tether in tether_sets:
		var tp: Array[Vector2] = []
		for p in tether:
			tp.append(p)
		_stroked_polyline(t, tp, Color(0.32, 0.86, 1.0, 0.46), 1.35, false)

	# Small premium detail nodes / bubbles, static and cheap.
	var bubbles: Array[Vector2] = [Vector2(-21, -3), Vector2(-18, 7), Vector2(10, -16), Vector2(14, 14), Vector2(31, -10), Vector2(32, 10)]
	for i in range(bubbles.size()):
		var col := WATER_GLOW if i % 2 == 0 else Color(0.35, 0.92, 0.55, 0.72)
		_circle(t, bubbles[i], 2.5, OUTLINE)
		_circle(t, bubbles[i], 1.45, col)

	# Tri-element identity token: Darkness + Water + Nature.
	_draw_tri_element_token(t, Vector2(0, 32), 6.0)
