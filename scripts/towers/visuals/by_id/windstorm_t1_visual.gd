extends RefCounted

# Tower: Windstorm Tower 1
# Role: Howling gale — freezing winds slow and batter enemies in a wide area.
# Elements: Light + Water + Fire
# Visual source: custom by_id visual
# Visual intent: storm turbine / gale-control tower, not a cannon.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.72

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const LIGHT_COL := Color(1.0, 0.92, 0.42, 1.0)
const WATER_COL := Color(0.32, 0.82, 1.0, 1.0)
const FIRE_COL := Color(1.0, 0.43, 0.16, 1.0)

const METAL_DARK := Color(0.15, 0.19, 0.27, 1.0)
const METAL_MID := Color(0.30, 0.42, 0.54, 1.0)
const STORM_BLUE := Color(0.42, 0.92, 1.0, 1.0)
const STORM_PALE := Color(0.78, 0.98, 1.0, 0.96)
const FROST_COL := Color(0.68, 0.92, 1.0, 0.82)
const HEAT_COL := Color(1.0, 0.52, 0.18, 0.72)

static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * VISUAL_SCALE

static func _r(value: float) -> float:
	return value * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * VISUAL_SCALE)
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rotation + TAU * float(i) / float(sides)
		pts.append((center + Vector2(cos(a), sin(a)) * radius) * VISUAL_SCALE)
	return pts

static func _draw_poly(t: Node2D, points: PackedVector2Array, fill: Color) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)
	t.draw_colored_polygon(points, fill)

static func _draw_circle(t: Node2D, pos: Vector2, radius: float, fill: Color, outline_width: float = 1.0) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, pos * VISUAL_SCALE, radius * VISUAL_SCALE)
	t.draw_circle(pos * VISUAL_SCALE, radius * VISUAL_SCALE, fill)
	if outline_width > 0.0:
		t.draw_arc(pos * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 48, OUTLINE, outline_width * VISUAL_SCALE, true)

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, OUTLINE, (width + 2.2) * VISUAL_SCALE, true)
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, color, width * VISUAL_SCALE, true)

static func _draw_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed: bool = false) -> void:
	var arr := PackedVector2Array()
	for p: Vector2 in points:
		arr.append(p * VISUAL_SCALE)
	if closed and arr.size() > 0:
		arr.append(arr[0])
	t.draw_polyline(arr, OUTLINE, (width + 2.0) * VISUAL_SCALE, true)
	t.draw_polyline(arr, color, width * VISUAL_SCALE, true)

static func _draw_arc(t: Node2D, center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: float) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_angle, to_angle, 36, OUTLINE_SOFT, (width + 2.0) * VISUAL_SCALE, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_angle, to_angle, 36, color, width * VISUAL_SCALE, true)

static func _draw_blade(t: Node2D, angle: float, fill: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := dir.orthogonal()
	var pts := PackedVector2Array([
		(dir * 5.0 + side * 3.2) * VISUAL_SCALE,
		(dir * 24.0 + side * 8.0) * VISUAL_SCALE,
		(dir * 33.0 + side * 2.2) * VISUAL_SCALE,
		(dir * 14.0 - side * 3.6) * VISUAL_SCALE
	])
	_draw_poly(t, pts, fill)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	var c := center
	_draw_circle(t, c, radius + 3.2, Color(0.05, 0.07, 0.10, 0.92), 0.0)
	_draw_circle(t, c + Vector2(-5.8, 0.7), radius, LIGHT_COL, 0.0)
	_draw_circle(t, c + Vector2(0.0, -3.8), radius, WATER_COL, 0.0)
	_draw_circle(t, c + Vector2(5.8, 0.7), radius, FIRE_COL, 0.0)
	t.draw_arc((c + Vector2(-5.8, 0.7)) * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 18, OUTLINE, 1.0 * VISUAL_SCALE, true)
	t.draw_arc((c + Vector2(0.0, -3.8)) * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 18, OUTLINE, 1.0 * VISUAL_SCALE, true)
	t.draw_arc((c + Vector2(5.8, 0.7)) * VISUAL_SCALE, radius * VISUAL_SCALE, 0.0, TAU, 18, OUTLINE, 1.0 * VISUAL_SCALE, true)

static func _draw_gale_runes(t: Node2D) -> void:
	# Static wind paths: renderer/catalog may rotate the whole tower; this file does not self-animate.
	_draw_arc(t, Vector2.ZERO, 33.0, -0.05 * PI, 0.43 * PI, STORM_PALE, 2.0)
	_draw_arc(t, Vector2.ZERO, 28.0, 0.63 * PI, 1.05 * PI, FROST_COL, 1.8)
	_draw_arc(t, Vector2.ZERO, 22.5, 1.30 * PI, 1.82 * PI, HEAT_COL, 1.6)

	_draw_line(t, Vector2(21, -13), Vector2(28, -17), STORM_PALE, 1.5)
	_draw_line(t, Vector2(-24, 12), Vector2(-31, 15), FROST_COL, 1.4)
	_draw_line(t, Vector2(-5, -28), Vector2(-8, -35), HEAT_COL, 1.3)

static func draw_contour(t: Node2D) -> void:
	# Compact contour matching the custom top art. Do not rotate/scale here; catalog renderer owns rotation.
	t.draw_circle(Vector2.ZERO, _r(43.0), OUTLINE_SOFT)
	t.draw_circle(Vector2.ZERO, _r(31.5), OUTLINE)
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.ZERO, 25.0, 8, PI / 8.0))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Soft slow-field ring.
	_draw_arc(t, Vector2.ZERO, 38.0, 0.03 * PI, 0.65 * PI, Color(0.70, 0.96, 1.0, 0.30), 2.4)
	_draw_arc(t, Vector2.ZERO, 38.0, 0.75 * PI, 1.38 * PI, Color(0.58, 0.86, 1.0, 0.24), 2.2)
	_draw_arc(t, Vector2.ZERO, 38.0, 1.50 * PI, 1.93 * PI, Color(1.0, 0.58, 0.25, 0.18), 1.9)

	# Base and storm turbine frame.
	_draw_poly(t, _regular_poly(Vector2.ZERO, 27.5, 8, PI / 8.0), METAL_DARK)
	_draw_poly(t, _regular_poly(Vector2.ZERO, 22.0, 8, PI / 8.0), METAL_MID)

	# Four outer support vanes so it reads like a turbine tower, not a projectile cannon.
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		var vane := PackedVector2Array([
			(dir * 18.0 + side * 3.2) * VISUAL_SCALE,
			(dir * 29.0 + side * 5.0) * VISUAL_SCALE,
			(dir * 34.0 - side * 1.8) * VISUAL_SCALE,
			(dir * 20.0 - side * 4.0) * VISUAL_SCALE
		])
		_draw_poly(t, vane, Color(0.21, 0.31, 0.43, 1.0))

	# Tri-blade rotor: Light/Wind + Water/Frost + Fire/thermal current.
	_draw_blade(t, -PI / 2.0, Color(0.78, 0.98, 1.0, 0.96))
	_draw_blade(t, PI / 6.0, Color(0.42, 0.84, 1.0, 0.94))
	_draw_blade(t, PI * 5.0 / 6.0, Color(1.0, 0.55, 0.24, 0.90))

	# Central eye / pressure core.
	_draw_circle(t, Vector2.ZERO, 12.7, Color(0.05, 0.11, 0.17, 1.0), 0.0)
	_draw_circle(t, Vector2.ZERO, 8.7, STORM_BLUE, 0.0)
	_draw_circle(t, Vector2(-2.4, -2.7), 3.1, Color(0.92, 1.0, 1.0, 0.94), 0.0)

	# Slow/control identifiers.
	_draw_gale_runes(t)

	# Frost crystals at north/south and heat stabilizers east/west.
	for p: Vector2 in [Vector2(0, -31), Vector2(0, 31)]:
		_draw_poly(t, _poly([
			p + Vector2(0, -5),
			p + Vector2(4, 0),
			p + Vector2(0, 5),
			p + Vector2(-4, 0)
		]), FROST_COL)

	for p: Vector2 in [Vector2(31, 0), Vector2(-31, 0)]:
		_draw_circle(t, p, 4.2, HEAT_COL, 0.0)

	# Element token kept inside silhouette so it does not clip in catalog cards.
	_draw_tri_element_token(t, Vector2(0, 28.0), 3.8)
