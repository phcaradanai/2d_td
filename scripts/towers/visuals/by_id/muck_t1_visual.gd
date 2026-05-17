extends RefCounted
class_name TowerVisualMuckT1

# Tower: Muck Tower 1
# Role: Quagmire slow/control — thick tar sludge massively slows and poisons trapped land enemies.
# Elements: Darkness + Water + Earth
# Visual source: custom by_id visual
# Visual intent: Premium tar-pool quagmire reactor: heavy earth basin, black sludge pool,
#   abyss catalyst, water coolant, and slow-field anchors. No cannon/projectile silhouette.
# Performance note: CanvasItem draw calls only; no particles, nodes, timers, or gameplay logic.

const VISUAL_SCALE := 0.70

const OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.62)

const DARKNESS_COL := Color(0.34, 0.12, 0.55, 1.0)
const WATER_COL := Color(0.15, 0.74, 0.95, 1.0)
const EARTH_COL := Color(0.56, 0.38, 0.18, 1.0)
const TAR_COL := Color(0.035, 0.030, 0.045, 1.0)
const SLUDGE_GREEN := Color(0.32, 0.56, 0.23, 1.0)
const ACID_EDGE := Color(0.60, 0.90, 0.30, 1.0)
const MUD_COL := Color(0.22, 0.15, 0.10, 1.0)
const METAL_COL := Color(0.17, 0.15, 0.19, 1.0)

static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * VISUAL_SCALE

static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * VISUAL_SCALE)
	return out

static func _regular_poly(center: Vector2, radius: float, sides: int, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * float(i) / float(sides)
		out.append((center + Vector2(cos(a), sin(a)) * radius) * VISUAL_SCALE)
	return out

static func _draw_poly(t: Node2D, points: Array[Vector2], color: Color) -> void:
	t.draw_colored_polygon(_poly(points), color)

static func _draw_poly_outline(t: Node2D, points: Array[Vector2], width: float = 2.2) -> void:
	var path := _poly(points)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, width * VISUAL_SCALE, true)

static func _draw_closed_polyline(t: Node2D, points: Array[Vector2], color: Color, width: float) -> void:
	var path := _poly(points)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, OUTLINE, (width + 2.2) * VISUAL_SCALE, true)
	t.draw_polyline(path, color, width * VISUAL_SCALE, true)

static func _draw_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, OUTLINE, (width + 2.0) * VISUAL_SCALE, true)
	t.draw_line(a * VISUAL_SCALE, b * VISUAL_SCALE, color, width * VISUAL_SCALE, true)

static func _draw_circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(pos * VISUAL_SCALE, radius * VISUAL_SCALE, OUTLINE)
	t.draw_circle(pos * VISUAL_SCALE, max(0.0, radius - 1.5) * VISUAL_SCALE, color)

static func _draw_soft_circle(t: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	t.draw_circle(pos * VISUAL_SCALE, radius * VISUAL_SCALE, color)

static func _draw_arc(t: Node2D, center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: float) -> void:
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_angle, to_angle, 28, OUTLINE, (width + 1.8) * VISUAL_SCALE, true)
	t.draw_arc(center * VISUAL_SCALE, radius * VISUAL_SCALE, from_angle, to_angle, 28, color, width * VISUAL_SCALE, true)

static func _draw_tar_bubble(t: Node2D, pos: Vector2, radius: float, fill: Color, shine: Color) -> void:
	_draw_circle(t, pos, radius, fill)
	_draw_soft_circle(t, pos + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.28, shine)

static func _draw_sludge_drop(t: Node2D, center: Vector2, scale: float, color: Color) -> void:
	var pts: Array[Vector2] = [
		center + Vector2(0.0, -5.5) * scale,
		center + Vector2(4.0, -0.8) * scale,
		center + Vector2(2.7, 4.2) * scale,
		center + Vector2(0.0, 5.4) * scale,
		center + Vector2(-2.9, 4.1) * scale,
		center + Vector2(-4.0, -0.8) * scale
	]
	_draw_poly(t, pts, color)
	_draw_poly_outline(t, pts, 1.7)

static func _draw_quagmire_glyph(t: Node2D, center: Vector2, radius: float) -> void:
	# Concentric sinking rings + central tar drop: reads as "slow/quagmire" from catalog distance.
	_draw_arc(t, center, radius, PI * 0.08, PI * 0.92, ACID_EDGE, 1.4)
	_draw_arc(t, center, radius, PI * 1.08, PI * 1.92, WATER_COL, 1.4)
	_draw_arc(t, center, radius * 0.62, PI * 0.18, PI * 1.82, DARKNESS_COL.lightened(0.25), 1.2)
	_draw_sludge_drop(t, center + Vector2(0.0, 0.5), 0.55, SLUDGE_GREEN)

static func _draw_tri_element_token(t: Node2D, center: Vector2, radius: float) -> void:
	# Small token at the rear/bottom: Darkness + Water + Earth.
	_draw_circle(t, center, radius + 2.0, METAL_COL)
	var positions: Array[Vector2] = [
		center + Vector2(-radius * 0.72, 0.2),
		center + Vector2(radius * 0.72, 0.2),
		center + Vector2(0.0, -radius * 0.72)
	]
	var colors: Array[Color] = [DARKNESS_COL, WATER_COL, EARTH_COL]
	for i in range(3):
		_draw_soft_circle(t, positions[i], radius * 0.58, colors[i])
		t.draw_arc(positions[i] * VISUAL_SCALE, radius * 0.60 * VISUAL_SCALE, 0.0, TAU, 16, OUTLINE, 0.9 * VISUAL_SCALE, true)

static func draw_contour(t: Node2D) -> void:
	# Slightly oversized black silhouette only. Renderer/catalog handles rotation.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 34.0 * VISUAL_SCALE)
	TowerVisualDrawUtils._draw_contour_circle(t, _v(-21, -2), 8.0 * VISUAL_SCALE)
	TowerVisualDrawUtils._draw_contour_circle(t, _v(21, -2), 8.0 * VISUAL_SCALE)
	TowerVisualDrawUtils._draw_contour_poly(t, _poly([
		Vector2(-27, -4), Vector2(-21, -19), Vector2(-8, -27),
		Vector2(8, -27), Vector2(21, -19), Vector2(27, -4),
		Vector2(22, 19), Vector2(10, 28), Vector2(-10, 28), Vector2(-22, 19)
	]))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	var darkness := DARKNESS_COL
	var water := WATER_COL
	var earth := EARTH_COL
	if el_colors.size() >= 3:
		darkness = el_colors[0]
		water = el_colors[1]
		earth = el_colors[2]

	# Slow field / sticky ground pool — static, no particles.
	_draw_arc(t, Vector2.ZERO, 33.5, PI * 0.10, PI * 0.48, Color(water.r, water.g, water.b, 0.42), 1.4)
	_draw_arc(t, Vector2.ZERO, 33.5, PI * 0.58, PI * 0.94, Color(earth.r, earth.g, earth.b, 0.42), 1.4)
	_draw_arc(t, Vector2.ZERO, 33.5, PI * 1.08, PI * 1.46, Color(darkness.r, darkness.g, darkness.b, 0.42), 1.4)
	_draw_arc(t, Vector2.ZERO, 33.5, PI * 1.56, PI * 1.90, Color(SLUDGE_GREEN.r, SLUDGE_GREEN.g, SLUDGE_GREEN.b, 0.45), 1.4)

	# Earth anchor slabs: heavy land-only control silhouette.
	var bottom_slab: Array[Vector2] = [
		Vector2(-23, 14), Vector2(-12, 25), Vector2(12, 25), Vector2(23, 14),
		Vector2(18, 28), Vector2(-18, 28)
	]
	_draw_poly(t, bottom_slab, earth.darkened(0.26))
	_draw_poly_outline(t, bottom_slab, 2.0)
	_draw_line(t, Vector2(-16, 22), Vector2(16, 22), earth.lightened(0.20), 1.1)
	_draw_line(t, Vector2(-8, 16), Vector2(-15, 25), OUTLINE_SOFT, 1.0)
	_draw_line(t, Vector2(9, 16), Vector2(17, 25), OUTLINE_SOFT, 1.0)

	# Main tar-pool cauldron / basin.
	var basin: Array[Vector2] = [
		Vector2(-28, -5), Vector2(-22, -20), Vector2(-9, -27),
		Vector2(9, -27), Vector2(22, -20), Vector2(28, -5),
		Vector2(23, 15), Vector2(12, 25), Vector2(-12, 25), Vector2(-23, 15)
	]
	_draw_poly(t, basin, METAL_COL)
	_draw_poly_outline(t, basin, 2.4)

	var inner: PackedVector2Array = _regular_poly(Vector2.ZERO, 23.5, 12, PI / 12.0)
	t.draw_colored_polygon(inner, MUD_COL)
	var inner_path := PackedVector2Array(inner)
	inner_path.append(inner_path[0])
	t.draw_polyline(inner_path, OUTLINE, 2.0 * VISUAL_SCALE, true)

	# Black tar pool with colored oily edges.
	_draw_soft_circle(t, Vector2(0, -2), 18.5, TAR_COL)
	_draw_arc(t, Vector2(0, -2), 17.8, PI * 0.08, PI * 0.94, Color(water.r, water.g, water.b, 0.60), 1.5)
	_draw_arc(t, Vector2(0, -2), 15.0, PI * 1.05, PI * 1.85, Color(darkness.r, darkness.g, darkness.b, 0.70), 1.5)
	_draw_arc(t, Vector2(0, -2), 11.3, PI * 0.35, PI * 1.55, Color(ACID_EDGE.r, ACID_EDGE.g, ACID_EDGE.b, 0.55), 1.2)

	# Central quagmire glyph.
	_draw_quagmire_glyph(t, Vector2(0, -3), 10.8)

	# Tar bubbles / poison read.
	var bubbles: Array[Vector2] = [
		Vector2(-10, -8), Vector2(8, -11), Vector2(11, 3),
		Vector2(-7, 7), Vector2(2, 10)
	]
	var bubble_sizes: Array[float] = [2.8, 2.2, 2.5, 2.1, 1.8]
	for i in range(bubbles.size()):
		_draw_tar_bubble(t, bubbles[i], bubble_sizes[i], Color(SLUDGE_GREEN.r, SLUDGE_GREEN.g, SLUDGE_GREEN.b, 0.76), Color(water.r, water.g, water.b, 0.55))

	# Slow/control pylons: not chain relays, not weapon barrels.
	var pylons: Array[Vector2] = [
		Vector2(-24, -6), Vector2(24, -6), Vector2(-18, 16), Vector2(18, 16)
	]
	var pylon_cols: Array[Color] = [darkness, water, earth, SLUDGE_GREEN]
	for i in range(pylons.size()):
		_draw_circle(t, pylons[i], 5.3, pylon_cols[i].darkened(0.05))
		_draw_soft_circle(t, pylons[i], 2.1, pylon_cols[i].lightened(0.25))

	# Sticky tendrils/clamps reaching inward.
	_draw_line(t, Vector2(-24, -6), Vector2(-12, -3), darkness.lightened(0.20), 1.4)
	_draw_line(t, Vector2(24, -6), Vector2(12, -3), water.lightened(0.05), 1.4)
	_draw_line(t, Vector2(-18, 16), Vector2(-8, 8), earth.lightened(0.20), 1.4)
	_draw_line(t, Vector2(18, 16), Vector2(8, 8), SLUDGE_GREEN.lightened(0.18), 1.4)

	# Tar fins / mud fins to break the round silhouette.
	var left_fin: Array[Vector2] = [
		Vector2(-28, 1), Vector2(-37, 8), Vector2(-25, 12)
	]
	var right_fin: Array[Vector2] = [
		Vector2(28, 1), Vector2(37, 8), Vector2(25, 12)
	]
	_draw_poly(t, left_fin, earth.darkened(0.12))
	_draw_poly_outline(t, left_fin, 1.8)
	_draw_poly(t, right_fin, water.darkened(0.28))
	_draw_poly_outline(t, right_fin, 1.8)

	# Sludge drops around the lip communicate poison/slow without particles.
	_draw_sludge_drop(t, Vector2(-16, -18), 0.46, SLUDGE_GREEN.darkened(0.05))
	_draw_sludge_drop(t, Vector2(16, -18), 0.46, water.darkened(0.25))
	_draw_sludge_drop(t, Vector2(0, -24), 0.42, darkness.lightened(0.15))

	# Front lip highlight, still static.
	_draw_arc(t, Vector2(0, -2), 24.2, PI * 0.05, PI * 0.95, Color(0.72, 0.92, 0.52, 0.36), 1.1)

	_draw_tri_element_token(t, Vector2(0, 31), 4.9)
