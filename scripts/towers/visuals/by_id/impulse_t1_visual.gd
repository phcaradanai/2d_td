extends RefCounted

# Tower: Impulse Tower 1
# Role: Elemental cannon — precision single-target strike
# Elements: water, fire, nature
# Visual source: custom by_id visual
# Visual intent: premium tri-reactor impulse accelerator; single-target land/air precision hit.
# Performance note: CanvasItem draw calls only; no particles, no new nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const WATER := Color(0.18, 0.86, 1.0, 0.95)
const FIRE := Color(1.0, 0.34, 0.09, 0.95)
const NATURE := Color(0.30, 1.0, 0.42, 0.95)
const CORE := Color(0.88, 1.0, 0.86, 1.0)
const METAL := Color(0.26, 0.30, 0.34, 1.0)
const METAL_DARK := Color(0.09, 0.12, 0.14, 1.0)
const GOLD_TRIM := Color(1.0, 0.78, 0.28, 0.95)

static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * VISUAL_SCALE)
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, start_angle: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(sides):
		var a := start_angle + TAU * float(i) / float(sides)
		out.append((center + Vector2(cos(a), sin(a)) * radius) * VISUAL_SCALE)
	return out

static func _draw_poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), color)

static func _draw_poly_outline(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), OUTLINE)
	var inner: Array[Vector2] = []
	var center := Vector2.ZERO
	for p: Vector2 in points:
		center += p
	center /= max(1, points.size())
	for p: Vector2 in points:
		inner.append(center + (p - center) * 0.86)
	t.draw_colored_polygon(_poly(inner), color)

static func _draw_circle(t: Node2D, pos: Vector2, radius: float, color: Color, outline_width: float = 2.0) -> void:
	t.draw_circle(pos * VISUAL_SCALE, (radius + outline_width) * VISUAL_SCALE, OUTLINE)
	t.draw_circle(pos * VISUAL_SCALE, radius * VISUAL_SCALE, color)

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, OUTLINE, (width + 2.4) * VISUAL_SCALE, true)
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, color, width * VISUAL_SCALE, true)

static func _draw_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float = 2.0, closed: bool = false) -> void:
	var path := _poly(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, (width + 2.2) * VISUAL_SCALE, true)
	t.draw_polyline(path, color, width * VISUAL_SCALE, true)

static func _draw_arc(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float = 2.0) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, start_angle, end_angle, 24, OUTLINE, (width + 2.4) * VISUAL_SCALE, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, start_angle, end_angle, 24, color, width * VISUAL_SCALE, true)

static func _draw_tri_token(t: Node2D, pos: Vector2, radius: float) -> void:
	_draw_circle(t, pos, radius + 3.0, METAL_DARK, 1.2)
	var p1: Vector2 = pos + Vector2(-radius * 0.9, 1.2)
	var p2: Vector2 = pos + Vector2(radius * 0.9, 1.2)
	var p3: Vector2 = pos + Vector2(0.0, -radius * 1.0)
	t.draw_colored_polygon(_poly([p3, pos, p1]), WATER)
	t.draw_colored_polygon(_poly([p1, pos, p2]), FIRE)
	t.draw_colored_polygon(_poly([p2, pos, p3]), NATURE)
	_draw_polyline(t, [p1, p2, p3], OUTLINE, 1.4, true)
	_draw_circle(t, pos, radius * 0.34, CORE, 0.8)

static func _draw_impulse_glyph(t: Node2D) -> void:
	# Three colored impulse vectors converge into one precision shot.
	var starts: Array[Vector2] = [Vector2(0, -12), Vector2(-10, 7), Vector2(10, 7)]
	var colors: Array[Color] = [WATER, FIRE, NATURE]
	for i in range(3):
		var start: Vector2 = starts[i]
		_draw_line(t, start, Vector2.ZERO, colors[i], 2.2)
		_draw_circle(t, start, 3.3, colors[i], 1.0)
	_draw_circle(t, Vector2.ZERO, 6.2, CORE, 1.4)

static func draw_contour(t: Node2D) -> void:
	# Compact outer silhouette for catalog cards. Do not rotate/scale with draw_set_transform; renderer handles rotation.
	t.draw_circle(Vector2.ZERO, 37.0 * VISUAL_SCALE, OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, 29.0 * VISUAL_SCALE, OUTLINE)
	t.draw_colored_polygon(_regular_poly(Vector2.ZERO, 24.0, 8, PI / 8.0), OUTLINE)
	_draw_poly(t, [Vector2(6, -11), Vector2(34, -7), Vector2(43, 0), Vector2(34, 7), Vector2(6, 11)], OUTLINE)
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var p := Vector2(cos(a), sin(a)) * 27.0
		t.draw_circle(p * VISUAL_SCALE, 5.4 * VISUAL_SCALE, OUTLINE)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Element colors are intentionally fixed to the role from towers_tree.json: water + fire + nature.
	# Static impulse field; no self-rotation here, so catalog/tower renderer controls rotation consistently.
	_draw_arc(t, Vector2.ZERO, 33.0, -0.25, 0.95, WATER, 1.8)
	_draw_arc(t, Vector2.ZERO, 33.0, 1.85, 3.05, FIRE, 1.8)
	_draw_arc(t, Vector2.ZERO, 33.0, 3.95, 5.15, NATURE, 1.8)
	_draw_arc(t, Vector2.ZERO, 26.0, -0.05, 0.62, Color(WATER.r, WATER.g, WATER.b, 0.50), 1.2)
	_draw_arc(t, Vector2.ZERO, 26.0, 2.05, 2.72, Color(FIRE.r, FIRE.g, FIRE.b, 0.50), 1.2)
	_draw_arc(t, Vector2.ZERO, 26.0, 4.15, 4.82, Color(NATURE.r, NATURE.g, NATURE.b, 0.50), 1.2)

	_draw_poly_outline(t, [Vector2(-22, -12), Vector2(-10, -25), Vector2(11, -24), Vector2(24, -10), Vector2(21, 13), Vector2(7, 25), Vector2(-15, 21), Vector2(-26, 4)], METAL_DARK)
	_draw_poly_outline(t, [Vector2(-16, -9), Vector2(-8, -18), Vector2(8, -18), Vector2(17, -7), Vector2(16, 9), Vector2(4, 17), Vector2(-12, 14), Vector2(-19, 2)], METAL)

	var chamber_positions: Array[Vector2] = [Vector2(-13, -11), Vector2(13, -10), Vector2(0, 15)]
	var chamber_colors: Array[Color] = [WATER, FIRE, NATURE]
	for i in range(3):
		_draw_circle(t, chamber_positions[i], 6.4, chamber_colors[i], 1.4)
		_draw_circle(t, chamber_positions[i], 2.6, Color(1, 1, 1, 0.85), 0.6)
		_draw_line(t, chamber_positions[i], Vector2.ZERO, Color(chamber_colors[i].r, chamber_colors[i].g, chamber_colors[i].b, 0.82), 2.0)

	# Precision impulse accelerator: narrow rail, not splash cannon.
	_draw_poly_outline(t, [Vector2(4, -7), Vector2(28, -7), Vector2(40, -3), Vector2(44, 0), Vector2(40, 3), Vector2(28, 7), Vector2(4, 7)], Color(0.18, 0.22, 0.25, 1.0))
	_draw_line(t, Vector2(10, -3.5), Vector2(37, -1.0), WATER, 1.7)
	_draw_line(t, Vector2(10, 3.5), Vector2(37, 1.0), FIRE, 1.7)
	_draw_circle(t, Vector2(40, 0), 3.4, CORE, 1.0)

	# Static focus wedge to read as a precision strike.
	t.draw_colored_polygon(_poly([Vector2(30, -4), Vector2(50, 0), Vector2(30, 4)]), Color(0.9, 1.0, 0.82, 0.22))
	_draw_polyline(t, [Vector2(30, -4), Vector2(50, 0), Vector2(30, 4)], Color(0.9, 1.0, 0.82, 0.56), 1.2, false)

	_draw_circle(t, Vector2.ZERO, 12.0, OUTLINE, 0.0)
	_draw_circle(t, Vector2.ZERO, 9.0, Color(0.18, 0.25, 0.23, 1.0), 0.8)
	_draw_impulse_glyph(t)

	_draw_line(t, Vector2(-18, -22), Vector2(-7, -27), GOLD_TRIM, 1.4)
	_draw_line(t, Vector2(19, 18), Vector2(8, 25), GOLD_TRIM, 1.4)
	_draw_line(t, Vector2(-24, 7), Vector2(-27, -6), Color(NATURE.r, NATURE.g, NATURE.b, 0.78), 1.3)
	_draw_circle(t, Vector2(-25, -4), 3.5, WATER, 0.8)
	_draw_circle(t, Vector2(24, 11), 3.5, FIRE, 0.8)
	_draw_circle(t, Vector2(-11, 24), 3.5, NATURE, 0.8)

	_draw_tri_token(t, Vector2(0, 31), 4.8)
