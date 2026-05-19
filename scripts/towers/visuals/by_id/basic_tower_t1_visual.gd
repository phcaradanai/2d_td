extends RefCounted

# Tower: Neutral Arrow Tower
# Role: Cheap starter, single-target projectile, hits land and air
# Elements: None
# Visual source: custom by_id visual
# Visual intent: compact neutral ballista / arrow launcher; readable starter silhouette, non-elemental, all-purpose.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)
const METAL_DARK := Color(0.075, 0.085, 0.095, 0.98)
const METAL_MID := Color(0.25, 0.28, 0.31, 0.96)
const METAL_LIGHT := Color(0.58, 0.64, 0.70, 0.92)
const WOOD_DARK := Color(0.28, 0.19, 0.105, 0.98)
const WOOD_MID := Color(0.55, 0.36, 0.18, 0.96)
const ARROW_HEAD := Color(0.82, 0.88, 0.92, 0.96)
const NEUTRAL_GLOW := Color(0.62, 0.72, 0.80, 0.18)

static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p)
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _draw_closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	t.draw_polyline(closed, color, width, true)

static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width: float = 1.8) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(points, -stroke_width)
	t.draw_colored_polygon(inner, fill)
	_draw_closed_polyline(t, points, DETAIL_OUTLINE_SOFT, 0.8)

static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := PackedVector2Array(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.7) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _draw_neutral_badge(t: Node2D, center: Vector2, radius: float) -> void:
	# Neutral starter token: simple steel target, not an element icon.
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.72, 8, PI / 8.0)
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(outer, -1.6), Color(0.075, 0.085, 0.095, 0.88))
	_draw_closed_polyline(t, outer, Color(0.62, 0.70, 0.76, 0.62), 1.1)
	_draw_closed_polyline(t, inner, Color(0.42, 0.48, 0.53, 0.46), 0.8)
	_draw_stroked_line(t, center + Vector2(-radius * 0.42, 0), center + Vector2(radius * 0.42, 0), Color(0.72, 0.80, 0.86, 0.72), 0.8)
	_draw_stroked_line(t, center + Vector2(0, -radius * 0.42), center + Vector2(0, radius * 0.42), Color(0.72, 0.80, 0.86, 0.72), 0.8)
	t.draw_circle(center, radius * 0.16, Color(0.86, 0.92, 0.96, 0.80))

static func draw_contour(t: Node2D) -> void:
	# Heavy starter base.
	var base := _poly([
		Vector2(-18, -13),
		Vector2(12, -15),
		Vector2(20, -7),
		Vector2(20, 7),
		Vector2(12, 15),
		Vector2(-18, 13),
		Vector2(-23, 0),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, base)

	# Ballista bow arms / rails.
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-11, -12), Vector2(15, -18), 3.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-11, 12), Vector2(15, 18), 3.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-5, -7), Vector2(29, -3), 3.2)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-5, 7), Vector2(29, 3), 3.2)

	# Center arrow shaft and pointed head.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-7, -3, 28, 6))
	var arrow_head := _poly([
		Vector2(18, -8),
		Vector2(34, 0),
		Vector2(18, 8),
		Vector2(22, 0),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, arrow_head)

	# Rear neutral badge.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-11, 0), 7.0)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Subtle neutral aura: tells the player this is a non-element starter, not a magic tower.
	t.draw_circle(Vector2.ZERO, 17.0, NEUTRAL_GLOW)
	for r in [19.0, 24.0]:
		t.draw_arc(Vector2.ZERO, r, -0.72, 0.72, 16, Color(0.58, 0.66, 0.72, 0.13), 1.0, true)
		t.draw_arc(Vector2.ZERO, r, PI - 0.72, PI + 0.72, 16, Color(0.58, 0.66, 0.72, 0.10), 1.0, true)

	# Main metal base. Wide and compact so it reads as a cheap starter platform.
	var base := _poly([
		Vector2(-18, -13),
		Vector2(12, -15),
		Vector2(20, -7),
		Vector2(20, 7),
		Vector2(12, 15),
		Vector2(-18, 13),
		Vector2(-23, 0),
	])
	_draw_stroked_poly(t, base, METAL_DARK, 2.0)

	var top_plate := _poly([
		Vector2(-14, -9),
		Vector2(10, -10),
		Vector2(15, -4),
		Vector2(15, 4),
		Vector2(10, 10),
		Vector2(-14, 9),
		Vector2(-18, 0),
	])
	_draw_stroked_poly(t, top_plate, METAL_MID, 1.5)
	_draw_stroked_polyline(t, top_plate, Color(0.66, 0.74, 0.80, 0.48), 0.9)

	# Rear neutral badge / pivot.
	_draw_neutral_badge(t, Vector2(-11, 0), 7.2)

	# Wooden/metal ballista arms. Mirrored top/bottom makes the direction obvious without looking like a sci-fi laser.
	_draw_stroked_line(t, Vector2(-12, -12), Vector2(14, -18), WOOD_MID, 2.5)
	_draw_stroked_line(t, Vector2(-12, 12), Vector2(14, 18), WOOD_MID, 2.5)
	_draw_stroked_line(t, Vector2(-8, -9), Vector2(17, -13), Color(0.72, 0.48, 0.22, 0.66), 1.1)
	_draw_stroked_line(t, Vector2(-8, 9), Vector2(17, 13), Color(0.72, 0.48, 0.22, 0.66), 1.1)

	# Tension string / guide lines.
	_draw_stroked_line(t, Vector2(14, -18), Vector2(24, 0), Color(0.72, 0.80, 0.84, 0.58), 0.9)
	_draw_stroked_line(t, Vector2(14, 18), Vector2(24, 0), Color(0.72, 0.80, 0.84, 0.58), 0.9)

	# Forward twin rails around the arrow shaft.
	_draw_stroked_line(t, Vector2(-5, -7), Vector2(28, -3), METAL_LIGHT, 2.2)
	_draw_stroked_line(t, Vector2(-5, 7), Vector2(28, 3), METAL_LIGHT, 2.2)
	_draw_stroked_line(t, Vector2(-3, -4.6), Vector2(22, -1.8), Color(0.85, 0.90, 0.94, 0.32), 0.8)
	_draw_stroked_line(t, Vector2(-3, 4.6), Vector2(22, 1.8), Color(0.85, 0.90, 0.94, 0.26), 0.8)

	# Center arrow body: this is the key identity of the neutral starter.
	_draw_stroked_rect(t, Rect2(-7, -3, 28, 6), WOOD_DARK, 1.6)
	_draw_stroked_line(t, Vector2(-5, 0), Vector2(24, 0), Color(0.72, 0.51, 0.25, 0.88), 1.3)
	var arrow_head := _poly([
		Vector2(18, -8),
		Vector2(34, 0),
		Vector2(18, 8),
		Vector2(22, 0),
	])
	_draw_stroked_poly(t, arrow_head, ARROW_HEAD, 1.7)
	_draw_stroked_polyline(t, _poly([Vector2(19.5, -5.2), Vector2(30, 0), Vector2(19.5, 5.2)]), Color(1.0, 1.0, 1.0, 0.38), 0.8, false)

	# Small rear fletching, symmetrical and readable in catalog.
	var feather_top := _poly([
		Vector2(-9, -3.2),
		Vector2(-16, -8.2),
		Vector2(-12, -2.0),
	])
	var feather_bot := _poly([
		Vector2(-9, 3.2),
		Vector2(-16, 8.2),
		Vector2(-12, 2.0),
	])
	_draw_stroked_poly(t, feather_top, Color(0.46, 0.54, 0.58, 0.88), 1.0)
	_draw_stroked_poly(t, feather_bot, Color(0.40, 0.48, 0.52, 0.88), 1.0)

	# Four tiny rivets instead of elemental glow, reinforcing non-magic starter identity.
	var rivet_c := Color(0.78, 0.84, 0.88, 0.78)
	for p in [Vector2(-18, -7), Vector2(-18, 7), Vector2(11, -8), Vector2(11, 8)]:
		_draw_stroked_circle(t, p, 1.7, rivet_c, 0.9)
