extends RefCounted
class_name TowerVisualBlacksmithT1

# Tower: Blacksmith Tower 1
# Role: Forge support aura — tempers nearby non-support towers, increasing damage output.
# Elements: Fire, Earth
# Visual source: custom by_id visual
# Visual intent: premium neon-sci-fi forge/anvil, no cannon barrel; clear support-aura identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.66)
const METAL_DARK := Color(0.075, 0.072, 0.066, 0.96)
const METAL_MID := Color(0.22, 0.205, 0.18, 0.96)
const STONE_DARK := Color(0.105, 0.092, 0.075, 0.95)

static func _outline_poly(t: Node2D, points: PackedVector2Array) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, points)

static func _outline_circle(t: Node2D, center: Vector2, radius: float) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, center, radius)

static func _outline_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	TowerVisualDrawUtils._draw_contour_line(t, from, to, width)

static func _outline_rect(t: Node2D, rect: Rect2) -> void:
	TowerVisualDrawUtils._draw_contour_rect(t, rect)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _closed_path(points: PackedVector2Array) -> PackedVector2Array:
	var path := PackedVector2Array(points)
	if path.size() > 0:
		path.append(path[0])
	return path

static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, line_color: Color, line_width := 1.2) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	var inner := TowerVisualDrawUtils._expand_poly_from_center(points, -1.6)
	t.draw_colored_polygon(inner, fill)
	t.draw_polyline(_closed_path(inner), line_color, line_width, true)

static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.6) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)

static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(from, to, color, width, antialiased)

static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.5) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)

static func _fire_color(el_colors: Array[Color], fallback: Color) -> Color:
	# Blacksmith is Fire + Earth. In most calls the first two element colors are provided.
	if el_colors.size() >= 1:
		return el_colors[0]
	return fallback

static func _earth_color(el_colors: Array[Color], fallback: Color) -> Color:
	if el_colors.size() >= 2:
		return el_colors[1]
	return fallback

static func _draw_dual_fire_earth_token(t: Node2D, center: Vector2, radius: float, fire_c: Color, earth_c: Color) -> void:
	# Small support identity token; does not replace the anvil silhouette.
	var outer := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.78, 8, PI / 8.0)
	t.draw_colored_polygon(outer, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(outer, -1.3), Color(0.045, 0.033, 0.025, 0.90))
	t.draw_polyline(_closed_path(inner), Color(earth_c.r, earth_c.g, earth_c.b, 0.50), 0.9, true)

	# Fire half and earth half as readable miniature symbols.
	var flame := PackedVector2Array([
		center + Vector2(-4.0, 1.5),
		center + Vector2(-2.2, -4.8),
		center + Vector2(0.0, -1.5),
		center + Vector2(1.9, -5.7),
		center + Vector2(4.4, 1.5),
		center + Vector2(0.0, 4.2),
	])
	t.draw_colored_polygon(flame, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(flame, -0.9), Color(fire_c.r, fire_c.g, fire_c.b, 0.82))
	_draw_stroked_line(t, center + Vector2(-4.2, 5.4), center + Vector2(4.2, 5.4), Color(earth_c.r, earth_c.g, earth_c.b, 0.70), 1.0, true)

static func draw_contour(t: Node2D) -> void:
	# Support-aura footprint: not a target range circle, just four forge pylon anchors.
	for p in [Vector2(-20, -18), Vector2(20, -18), Vector2(-20, 18), Vector2(20, 18)]:
		_outline_circle(t, p, 4.8)

	# Heavy forge base.
	_outline_poly(t, PackedVector2Array([
		Vector2(-18, 16), Vector2(-23, 4), Vector2(-16, -11),
		Vector2(16, -11), Vector2(23, 4), Vector2(18, 16),
	]))

	# Anvil silhouette: left horn, flat striking face, tapered foot.
	_outline_poly(t, PackedVector2Array([
		Vector2(-26, -9), Vector2(-16, -15), Vector2(14, -15), Vector2(23, -10),
		Vector2(15, -5), Vector2(-8, -5), Vector2(-18, -2), Vector2(-28, -3),
	]))
	_outline_poly(t, PackedVector2Array([
		Vector2(-11, -5), Vector2(11, -5), Vector2(8, 9), Vector2(-8, 9),
	]))
	_outline_rect(t, Rect2(-14, 8, 28, 6))

	# Central forge chamber and hammer signifier.
	_outline_circle(t, Vector2(0, 0), 7.6)
	_outline_line(t, Vector2(10, -21), Vector2(22, -9), 3.2)
	_outline_rect(t, Rect2(19, -13, 8, 5))

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, el_colors: Array[Color]) -> void:
	var fire_c := _fire_color(el_colors, Color(1.0, 0.36, 0.08, 1.0))
	var earth_c := _earth_color(el_colors, Color(0.58, 0.43, 0.20, 1.0))
	var _forge_hot := Color(1.0, 0.48, 0.08, 0.95)
	var forge_yellow := Color(1.0, 0.82, 0.25, 0.92)
	var earth_glow := Color(earth_c.r, earth_c.g, earth_c.b, 0.34)
	var fire_glow := Color(fire_c.r, fire_c.g, fire_c.b, 0.22)

	# Static forge aura language. These arcs say "support aura" without gameplay range visuals.
	t.draw_arc(Vector2.ZERO, 25.5, deg_to_rad(205), deg_to_rad(335), 24, fire_glow, 1.4, true)
	t.draw_arc(Vector2.ZERO, 25.5, deg_to_rad(25), deg_to_rad(155), 24, earth_glow, 1.4, true)
	t.draw_arc(Vector2.ZERO, 20.5, deg_to_rad(215), deg_to_rad(325), 20, Color(fire_c.r, fire_c.g, fire_c.b, 0.16), 0.9, true)

	# Four aura pylons / rivets for support identity.
	var pylon_fill := Color(0.035, 0.030, 0.025, 0.88)
	var pylon_line := Color(forge_yellow.r, forge_yellow.g, forge_yellow.b, 0.62)
	for p in [Vector2(-20, -18), Vector2(20, -18), Vector2(-20, 18), Vector2(20, 18)]:
		t.draw_circle(p, 6.6, Color(fire_c.r, fire_c.g, fire_c.b, 0.055))
		_draw_stroked_circle(t, p, 4.0, pylon_fill, 1.3)
		t.draw_arc(p, 3.0, 0.0, TAU, 16, pylon_line, 0.8, true)
		t.draw_circle(p, 1.25, Color(forge_yellow.r, forge_yellow.g, forge_yellow.b, 0.72))

	# Heavy stone/metal base.
	var base := PackedVector2Array([
		Vector2(-18, 16), Vector2(-23, 4), Vector2(-16, -11),
		Vector2(16, -11), Vector2(23, 4), Vector2(18, 16),
	])
	_draw_stroked_poly(t, base, STONE_DARK, Color(earth_c.r, earth_c.g, earth_c.b, 0.38), 1.1)
	_draw_stroked_line(t, Vector2(-15, 10), Vector2(15, 10), Color(earth_c.r, earth_c.g, earth_c.b, 0.30), 0.9, true)
	_draw_stroked_line(t, Vector2(-11, -7), Vector2(-17, 4), Color(earth_c.r, earth_c.g, earth_c.b, 0.24), 0.8, true)
	_draw_stroked_line(t, Vector2(11, -7), Vector2(17, 4), Color(earth_c.r, earth_c.g, earth_c.b, 0.24), 0.8, true)

	# Anvil top: unmistakable blacksmith silhouette. No projectile barrel.
	var anvil_top := PackedVector2Array([
		Vector2(-26, -9), Vector2(-16, -15), Vector2(14, -15), Vector2(23, -10),
		Vector2(15, -5), Vector2(-8, -5), Vector2(-18, -2), Vector2(-28, -3),
	])
	_draw_stroked_poly(t, anvil_top, METAL_MID, Color(0.62, 0.58, 0.48, 0.58), 1.0)
	_draw_stroked_line(t, Vector2(-14, -15), Vector2(12, -15), Color(0.88, 0.78, 0.56, 0.50), 1.0, true)
	_draw_stroked_line(t, Vector2(-23, -7), Vector2(-15, -12), Color(0.82, 0.74, 0.60, 0.35), 0.8, true)

	# Tapered anvil foot and base plate.
	var foot := PackedVector2Array([
		Vector2(-11, -5), Vector2(11, -5), Vector2(8, 9), Vector2(-8, 9),
	])
	_draw_stroked_poly(t, foot, METAL_DARK, Color(0.70, 0.62, 0.48, 0.42), 0.9)
	_draw_stroked_rect(t, Rect2(-14, 8, 28, 6), Color(0.145, 0.128, 0.098, 0.96), 1.4)

	# Molten forge chamber. This communicates damage-buff tempering rather than direct shooting.
	_draw_stroked_circle(t, Vector2(0, 0), 7.4, Color(0.075, 0.027, 0.012, 0.96), 1.9)
	t.draw_circle(Vector2(0, 0), 5.6, Color(fire_c.r, fire_c.g * 0.72, fire_c.b * 0.48, 0.32))
	t.draw_circle(Vector2(0, 0), 3.9, Color(1.0, 0.32, 0.04, 0.78))
	t.draw_circle(Vector2(0, 0), 1.8, forge_yellow)
	_draw_stroked_line(t, Vector2(-5.5, 0.0), Vector2(5.5, 0.0), Color(1.0, 0.70, 0.20, 0.72), 0.9, true)
	_draw_stroked_line(t, Vector2(0.0, -5.5), Vector2(0.0, 5.5), Color(1.0, 0.44, 0.08, 0.55), 0.75, true)

	# Hammer badge above the anvil: reads as forge/support, not turret.
	_draw_stroked_line(t, Vector2(10, -21), Vector2(22, -9), Color(0.78, 0.66, 0.48, 0.88), 2.0, true)
	_draw_stroked_rect(t, Rect2(19, -13, 8, 5), Color(0.38, 0.32, 0.24, 0.94), 1.2)
	_draw_stroked_line(t, Vector2(8, -19), Vector2(14, -25), Color(fire_c.r, fire_c.g, fire_c.b, 0.36), 0.85, true)

	# Small static sparks at the striking face. Fixed positions = stable and cheap.
	for spark in [Vector2(-7, -18), Vector2(0, -20), Vector2(8, -18)]:
		t.draw_circle(spark, 2.5, Color(fire_c.r, fire_c.g, fire_c.b, 0.08))
		t.draw_circle(spark, 1.25, Color(1.0, 0.68, 0.16, 0.82))
		t.draw_circle(spark, 0.55, Color(1.0, 0.92, 0.50, 0.86))

	# Compact dual-element token, deliberately secondary to the forge silhouette.
	_draw_dual_fire_earth_token(t, Vector2(0, 20.5), 6.3, fire_c, earth_c)
