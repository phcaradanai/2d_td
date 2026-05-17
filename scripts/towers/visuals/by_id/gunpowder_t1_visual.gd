extends RefCounted

# Tower: Gunpowder Tower 1
# Role: Heavy ordnance — massive explosive shells with wide splash damage
# Elements: darkness, earth
# Visual source: custom by_id visual
# Visual intent: compact siege mortar / dark-earth artillery; heavy land-only AoE identity.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.93)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.70)

static func _poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func _closed_line(t: Node2D, pts: PackedVector2Array, color: Color, width: float) -> void:
	var line := PackedVector2Array(pts)
	if line.size() > 0:
		line.append(line[0])
	t.draw_polyline(line, color, width, true)


static func _draw_stroked_poly(t: Node2D, pts: PackedVector2Array, fill: Color, line_color: Color, width := 1.2) -> void:
	t.draw_colored_polygon(pts, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, pts, -1.6), fill)
	_closed_line(t, pts, line_color, width)


static func _draw_stroked_line(t: Node2D, a: Vector2, b: Vector2, color: Color, width: float, antialiased := true) -> void:
	t.draw_line(a, b, DETAIL_OUTLINE, width + 2.2, antialiased)
	t.draw_line(a, b, color, width, antialiased)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.7) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)


static func _draw_stroked_rect(t: Node2D, rect: Rect2, fill: Color, stroke_width := 1.7) -> void:
	t.draw_rect(rect.grow(stroke_width), DETAIL_OUTLINE)
	t.draw_rect(rect, fill)


static func _draw_dual_token(t: Node2D, center: Vector2, radius: float, darkness: Color, earth: Color) -> void:
	var frame := _poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(_poly(center, radius * 1.18, 8, PI / 8.0), Color(earth.r, earth.g, earth.b, 0.08))
	t.draw_colored_polygon(frame, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, frame, -1.5), Color(0.020, 0.018, 0.016, 0.92))

	var left := PackedVector2Array([
		center + Vector2(-radius * 0.55, -radius * 0.44),
		center + Vector2(0.0, -radius * 0.50),
		center + Vector2(0.0, radius * 0.50),
		center + Vector2(-radius * 0.55, radius * 0.44),
	])
	var right := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.50),
		center + Vector2(radius * 0.55, -radius * 0.44),
		center + Vector2(radius * 0.55, radius * 0.44),
		center + Vector2(0.0, radius * 0.50),
	])
	t.draw_colored_polygon(left, Color(darkness.r, darkness.g, darkness.b, 0.72))
	t.draw_colored_polygon(right, Color(earth.r, earth.g, earth.b, 0.72))
	_closed_line(t, frame, Color(earth.r, earth.g, earth.b, 0.40), 0.9)

	# Tiny shell mark in the token: darkness payload + earth casing.
	_draw_stroked_circle(t, center + Vector2(-2.5, 0.0), radius * 0.18, Color(darkness.r, darkness.g, darkness.b, 0.92), 0.8)
	_draw_stroked_line(t, center + Vector2(1.5, -2.6), center + Vector2(4.5, 2.6), Color(earth.r, earth.g, earth.b, 0.90), 1.0)


static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var barrel_len := 27.0 + float(lvl) * 2.0

	# Heavy siege base.
	var base := PackedVector2Array([
		Vector2(-19, -12),
		Vector2(-9, -19),
		Vector2(12, -18),
		Vector2(21, -9),
		Vector2(21, 9),
		Vector2(12, 18),
		Vector2(-9, 19),
		Vector2(-19, 12),
	])
	TowerVisualDrawUtils._draw_contour_poly(t, base)

	# Wide mortar barrel: short, thick, and land-splash oriented.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-2, -8, barrel_len, 16))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(barrel_len - 2.0, -11, 9, 22))

	# Recoil housing and side armor plates.
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-15, -7, 17, 14))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-12, -19), Vector2(7, -15), Vector2(3, -8), Vector2(-16, -11)]))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-12, 19), Vector2(7, 15), Vector2(3, 8), Vector2(-16, 11)]))

	# Front blast crown, shell badge, and rear dark magazine.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(barrel_len + 9.0, 0), 7.5)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-12, 0), 8.0)


static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var darkness := el_colors[1] if el_colors.size() > 1 else Color(0.42, 0.18, 0.72)
	var earth := el_colors[5] if el_colors.size() > 5 else Color(0.62, 0.46, 0.25)
	var metal := Color(0.19, 0.17, 0.15, 0.96)
	var dark_metal := Color(0.065, 0.056, 0.055, 0.96)
	var warm := Color(1.0, 0.52, 0.13, 0.92)
	var blast := Color(earth.r, earth.g, earth.b, 0.72)
	var void_c := Color(darkness.r, darkness.g, darkness.b, 0.78)
	var barrel_len := 27.0 + float(lvl) * 2.0

	# Static ground blast language. Cheap arcs only, not an active range indicator.
	t.draw_arc(Vector2.ZERO, 24.0, deg_to_rad(205), deg_to_rad(335), 22, Color(earth.r, earth.g, earth.b, 0.12), 2.2, true)
	t.draw_arc(Vector2.ZERO, 18.0, deg_to_rad(215), deg_to_rad(325), 20, Color(darkness.r, darkness.g, darkness.b, 0.10), 1.5, true)

	# Heavy octagonal chassis.
	var base := PackedVector2Array([
		Vector2(-19, -12),
		Vector2(-9, -19),
		Vector2(12, -18),
		Vector2(21, -9),
		Vector2(21, 9),
		Vector2(12, 18),
		Vector2(-9, 19),
		Vector2(-19, 12),
	])
	_draw_stroked_poly(t, base, dark_metal, Color(earth.r, earth.g, earth.b, 0.42), 1.2)

	# Top/bottom armor plates make it feel earth-heavy and reinforced.
	var top_plate := PackedVector2Array([Vector2(-12, -19), Vector2(7, -15), Vector2(3, -8), Vector2(-16, -11)])
	var bot_plate := PackedVector2Array([Vector2(-12, 19), Vector2(7, 15), Vector2(3, 8), Vector2(-16, 11)])
	_draw_stroked_poly(t, top_plate, Color(earth.r * 0.65, earth.g * 0.62, earth.b * 0.58, 0.96), Color(earth.r, earth.g, earth.b, 0.50), 0.9)
	_draw_stroked_poly(t, bot_plate, Color(earth.r * 0.58, earth.g * 0.55, earth.b * 0.52, 0.96), Color(earth.r, earth.g, earth.b, 0.38), 0.9)

	# Rear dark powder magazine with a glowing unstable charge.
	_draw_stroked_circle(t, Vector2(-12, 0), 8.0, Color(0.025, 0.018, 0.030, 0.96), 2.0)
	_draw_stroked_circle(t, Vector2(-12, 0), 4.8, Color(darkness.r, darkness.g, darkness.b, 0.58), 1.1)
	t.draw_circle(Vector2(-12, 0), 2.1, Color(warm.r, warm.g, warm.b, 0.88))

	# Recoil housing.
	_draw_stroked_rect(t, Rect2(-15, -7, 17, 14), metal, 1.7)
	_draw_stroked_line(t, Vector2(-10, -7), Vector2(-10, 7), Color(earth.r, earth.g, earth.b, 0.38), 1.0)
	_draw_stroked_line(t, Vector2(-4, -7), Vector2(-4, 7), Color(darkness.r, darkness.g, darkness.b, 0.35), 1.0)

	# Wide mortar barrel. It must read as explosive shell delivery, not sniper or beam.
	_draw_stroked_rect(t, Rect2(-2, -8, barrel_len, 16), Color(0.12, 0.105, 0.090, 0.98), 2.0)
	_draw_stroked_line(t, Vector2(0, -4.7), Vector2(barrel_len - 1.0, -4.7), Color(earth.r, earth.g, earth.b, 0.35), 1.0)
	_draw_stroked_line(t, Vector2(0, 4.7), Vector2(barrel_len - 1.0, 4.7), Color(earth.r, earth.g, earth.b, 0.28), 1.0)
	_draw_stroked_line(t, Vector2(1, 0), Vector2(barrel_len + 3.0, 0), Color(warm.r, warm.g, warm.b, 0.62), 1.5)

	# Blast crown / muzzle brake: open, chunky, and black-trimmed.
	_draw_stroked_rect(t, Rect2(barrel_len - 2.0, -11, 9, 22), Color(0.085, 0.074, 0.064, 0.98), 2.0)
	var crown := Vector2(barrel_len + 9.0, 0)
	_draw_stroked_circle(t, crown, 7.5, Color(0.035, 0.030, 0.026, 0.96), 2.0)
	_draw_stroked_circle(t, crown, 4.5, Color(earth.r * 0.45, earth.g * 0.38, earth.b * 0.32, 0.92), 1.1)
	t.draw_circle(crown, 2.1, Color(warm.r, warm.g, warm.b, 0.74))

	# Mortar shell glyphs near the front to communicate explosive splash.
	for off in [Vector2(22, -14), Vector2(22, 14), Vector2(11, 0)]:
		_draw_stroked_circle(t, off, 3.1, Color(earth.r, earth.g, earth.b, 0.56), 1.1)
		t.draw_circle(off + Vector2(0.9, -0.7), 0.9, Color(warm.r, warm.g, warm.b, 0.75))

	# Dark-earth cracks on the chassis.
	_draw_stroked_line(t, Vector2(-2, -16), Vector2(4, -10), void_c, 0.9)
	_draw_stroked_line(t, Vector2(5, 15), Vector2(11, 9), blast, 0.9)
	_draw_stroked_line(t, Vector2(-18, 4), Vector2(-11, 8), Color(darkness.r, darkness.g, darkness.b, 0.42), 0.8)

	# Small debris/splash ticks. Static and symmetrical enough to read at catalog size.
	_draw_stroked_line(t, Vector2(25, -18), Vector2(31, -22), Color(warm.r, warm.g, warm.b, 0.50), 1.0)
	_draw_stroked_line(t, Vector2(25, 18), Vector2(31, 22), Color(warm.r, warm.g, warm.b, 0.42), 1.0)
	_draw_stroked_line(t, Vector2(-20, -20), Vector2(-25, -24), Color(earth.r, earth.g, earth.b, 0.34), 0.9)
	_draw_stroked_line(t, Vector2(-20, 20), Vector2(-25, 24), Color(earth.r, earth.g, earth.b, 0.30), 0.9)

	# Dual Darkness + Earth token. Placed low so the siege silhouette stays readable.
	_draw_dual_token(t, Vector2(-2, 24), 5.8, darkness, earth)
