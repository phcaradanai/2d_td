extends RefCounted

# Tower: Nova Tower 1
# Role: Solar flare slow — searing blast that burns and slows enemies on impact.
# Elements: Light + Fire + Nature
# Visual source: custom by_id visual
# Visual intent: premium solar bloom / flare-control reactor.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.64)

const LIGHT_COL := Color(1.0, 0.95, 0.48, 0.96)
const FIRE_COL := Color(1.0, 0.34, 0.08, 0.96)
const NATURE_COL := Color(0.25, 0.95, 0.38, 0.94)
const SOLAR_CORE := Color(1.0, 0.76, 0.18, 0.98)
const HOT_CORE := Color(1.0, 0.20, 0.05, 0.92)
const LEAF_DARK := Color(0.05, 0.32, 0.16, 0.96)
const GLASS_COL := Color(1.0, 0.91, 0.50, 0.58)
const AURA_COL := Color(1.0, 0.60, 0.10, 0.34)

static func _v(p: Vector2) -> Vector2:
	return p * VISUAL_SCALE

static func _r(value: float) -> float:
	return value * VISUAL_SCALE

static func _scaled(points: Array[Vector2]) -> PackedVector2Array:
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

static func _draw_poly(t: Node2D, points: PackedVector2Array, color: Color) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)
	t.draw_colored_polygon(points, color)

static func _draw_circle(t: Node2D, pos: Vector2, radius: float, color: Color, outline := true) -> void:
	if outline:
		TowerVisualDrawUtils._draw_contour_circle(t, _v(pos), _r(radius))
	t.draw_circle(_v(pos), _r(radius), color)

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, _v(a), _v(b), max(1.0, _r(width + 2.0)))
	t.draw_line(_v(a), _v(b), color, max(1.0, _r(width)), true)

static func _draw_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float, closed := false) -> void:
	var path := _scaled(points)
	if closed and path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, max(1.0, _r(width + 2.2)), true)
	t.draw_polyline(path, color, max(1.0, _r(width)), true)

static func _draw_arc_outline(t: Node2D, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	t.draw_arc(_v(center), _r(radius), start_angle, end_angle, 28, OUTLINE_SOFT, max(1.0, _r(width + 2.0)), true)
	t.draw_arc(_v(center), _r(radius), start_angle, end_angle, 28, color, max(1.0, _r(width)), true)

static func _draw_leaf(t: Node2D, center: Vector2, angle: float, length: float, color: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := dir.orthogonal()
	var pts := _scaled([
		center + dir * length,
		center + side * 5.0,
		center - dir * (length * 0.34),
		center - side * 5.0,
	])
	_draw_poly(t, pts, color)
	_draw_line(t, center - dir * 6.0, center + dir * (length * 0.64), Color(0.78, 1.0, 0.58, 0.72), 1.15)

static func _draw_flame_petal(t: Node2D, center: Vector2, angle: float, outer: float, inner: float, color: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := dir.orthogonal()
	var pts := _scaled([
		center + dir * outer,
		center + dir * inner + side * 8.0,
		center + side * 4.0,
		center + dir * inner - side * 8.0,
	])
	_draw_poly(t, pts, color)

static func _draw_prism_ray(t: Node2D, angle: float, len: float, color: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := dir.orthogonal()
	var pts := _scaled([
		dir * 11.0,
		dir * len + side * 2.6,
		dir * (len + 6.0),
		dir * len - side * 2.6,
	])
	_draw_poly(t, pts, color)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	_draw_circle(t, center, radius + 2.2, Color(0.04, 0.05, 0.04, 0.90), false)
	_draw_circle(t, center + Vector2(-radius * 0.70, -radius * 0.26), radius * 0.58, LIGHT_COL, true)
	_draw_circle(t, center + Vector2(radius * 0.70, -radius * 0.26), radius * 0.58, FIRE_COL, true)
	_draw_circle(t, center + Vector2(0.0, radius * 0.64), radius * 0.58, NATURE_COL, true)

static func _draw_solar_glyph(t: Node2D) -> void:
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		_draw_line(t, Vector2.RIGHT.rotated(angle) * 4.2, Vector2.RIGHT.rotated(angle) * 12.0, Color(1.0, 0.95, 0.38, 0.74), 1.05)
	_draw_circle(t, Vector2.ZERO, 6.8, Color(1.0, 0.95, 0.36, 0.92), true)
	_draw_circle(t, Vector2.ZERO, 3.3, HOT_CORE, false)

static func draw_contour(t: Node2D) -> void:
	# Compact outer silhouette: broad enough to read as slow AoE, still catalog-safe.
	t.draw_arc(Vector2.ZERO, _r(33.0), 0.12, 2.55, 30, OUTLINE_SOFT, _r(4.0), true)
	t.draw_arc(Vector2.ZERO, _r(33.0), 3.18, 5.74, 30, OUTLINE_SOFT, _r(4.0), true)
	for i in range(6):
		var angle := TAU * float(i) / 6.0 + PI / 6.0
		TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.RIGHT.rotated(angle) * 22.0, 7.2, 5, angle))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, _r(23.0))
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.ZERO, 16.5, 6, PI / 6.0))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, _el_colors: Array[Color]) -> void:
	# Slow radius / flare field, static so it does not add particle or per-frame node cost.
	_draw_arc_outline(t, Vector2.ZERO, 35.0, -0.18, 1.45, AURA_COL, 2.3)
	_draw_arc_outline(t, Vector2.ZERO, 35.0, 1.92, 3.55, Color(1.0, 0.78, 0.20, 0.27), 2.1)
	_draw_arc_outline(t, Vector2.ZERO, 35.0, 3.98, 5.62, Color(0.42, 1.0, 0.34, 0.23), 2.1)

	# Nature stabilizers: these make Nova different from pure fire/laser towers.
	_draw_leaf(t, Vector2(-18, 8), 2.48, 17.0, Color(0.12, 0.64, 0.25, 0.96))
	_draw_leaf(t, Vector2(18, 8), 0.66, 17.0, Color(0.12, 0.64, 0.25, 0.96))
	_draw_leaf(t, Vector2(-14, -14), 3.82, 13.5, Color(0.10, 0.50, 0.21, 0.92))
	_draw_leaf(t, Vector2(14, -14), 5.60, 13.5, Color(0.10, 0.50, 0.21, 0.92))

	# Solar flare petals: shows burn/flare impact, not a weapon barrel.
	for i in range(6):
		var angle := TAU * float(i) / 6.0 - PI / 2.0
		var col := FIRE_COL if i % 2 == 0 else SOLAR_CORE
		_draw_flame_petal(t, Vector2.ZERO, angle, 31.5, 14.0, col)

	# Light prism rays: reads as Light element and impact burst.
	for i in range(6):
		_draw_prism_ray(t, TAU * float(i) / 6.0 + PI / 6.0, 27.0, Color(1.0, 0.96, 0.42, 0.56))

	# Body plate and reactor glass.
	_draw_poly(t, _regular_poly(Vector2.ZERO, 22.0, 8, PI / 8.0), Color(0.14, 0.11, 0.08, 0.96))
	_draw_poly(t, _regular_poly(Vector2.ZERO, 17.2, 6, PI / 6.0), Color(0.48, 0.20, 0.08, 0.94))
	_draw_poly(t, _regular_poly(Vector2.ZERO, 13.8, 6, PI / 6.0), GLASS_COL)

	# Inner solar core + slow glyph.
	_draw_circle(t, Vector2.ZERO, 12.0, SOLAR_CORE, true)
	_draw_circle(t, Vector2.ZERO, 8.0, Color(1.0, 0.38, 0.06, 0.94), false)
	_draw_solar_glyph(t)

	# Slow/control pips around the edge.
	for i in range(6):
		var angle := TAU * float(i) / 6.0 + PI / 6.0
		var p := Vector2.RIGHT.rotated(angle) * 25.5
		var pip_col := Color(1.0, 0.86, 0.26, 0.92) if i % 2 == 0 else Color(0.36, 1.0, 0.36, 0.84)
		_draw_circle(t, p, 3.0, pip_col, true)

	# Small forward flare diffuser: communicates impact projectile without looking like a cannon barrel.
	_draw_poly(t, _scaled([
		Vector2(7.0, -3.8),
		Vector2(30.0, -7.2),
		Vector2(35.0, 0.0),
		Vector2(30.0, 7.2),
		Vector2(7.0, 3.8),
	]), Color(1.0, 0.60, 0.10, 0.82))
	_draw_line(t, Vector2(12.0, 0.0), Vector2(32.5, 0.0), Color(1.0, 0.96, 0.45, 0.78), 1.15)

	# Burn/slow landing markers.
	_draw_circle(t, Vector2(38.0, -7.5), 2.3, FIRE_COL, true)
	_draw_circle(t, Vector2(39.5, 0.0), 1.9, LIGHT_COL, true)
	_draw_circle(t, Vector2(38.0, 7.5), 2.3, NATURE_COL, true)

	_draw_tri_element_token(t, Vector2(0.0, 30.5), 5.0)
