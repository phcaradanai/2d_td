extends RefCounted
class_name TowerVisualElectricityT1

# Tower: Electricity Tower 1
# Role: Chain lightning — bolts jump between enemies with falloff.
# Elements: Light, Fire
# Visual source: custom by_id visual
# Visual intent: premium Tesla coil / chain-conductor tower. The shape reads as an electrical relay,
# not a normal cannon: central capacitor, three jump nodes, forked lightning rails, and dual Light/Fire token.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.92)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out


static func _draw_stroked_poly(t: Node2D, points: PackedVector2Array, fill: Color, stroke_width := 2.0) -> void:
	t.draw_colored_polygon(points, DETAIL_OUTLINE)
	# Keep the fill slightly inside the black edge for a crisp catalog silhouette.
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, points, -stroke_width), fill)


static func _draw_stroked_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float, closed := true) -> void:
	var path := _closed(points) if closed else PackedVector2Array(points)
	t.draw_polyline(path, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(path, color, width, true)


static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_line(from, to, color, width, true)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)


static func _draw_zap(t: Node2D, points: PackedVector2Array, color: Color, width := 1.2) -> void:
	# Black under-stroke + bright lightning path.
	t.draw_polyline(points, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_polyline(points, color, width, true)


static func _draw_light_fire_token(t: Node2D, center: Vector2, radius: float, light_color: Color, fire_color: Color) -> void:
	# Tiny dual element badge: light star + fire ember. Kept secondary so it does not hide the coil.
	var token := _regular_poly(center, radius, 8, PI / 8.0)
	t.draw_colored_polygon(token, DETAIL_OUTLINE)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, token, -1.3), Color(0.03, 0.02, 0.015, 0.86))
	_draw_stroked_polyline(t, token, Color(1.0, 0.88, 0.32, 0.55), 0.8)

	# Left light spark.
	var spark_center := center + Vector2(-radius * 0.35, 0.0)
	var spark := PackedVector2Array()
	for i in range(8):
		var a := float(i) / 8.0 * TAU - PI / 2.0
		var r := radius * (0.30 if i % 2 == 0 else 0.12)
		spark.append(spark_center + Vector2(cos(a), sin(a)) * r)
	t.draw_colored_polygon(spark, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, spark, -0.6), Color(light_color.r, light_color.g, light_color.b, 0.82))

	# Right fire ember.
	var flame := PackedVector2Array([
		center + Vector2(radius * 0.08, radius * 0.22),
		center + Vector2(radius * 0.28, -radius * 0.34),
		center + Vector2(radius * 0.42, -radius * 0.02),
		center + Vector2(radius * 0.50, radius * 0.25),
	])
	t.draw_colored_polygon(flame, DETAIL_OUTLINE_SOFT)
	t.draw_colored_polygon(TowerVisualDrawUtils._expand_poly_from_center(t, flame, -0.45), Color(fire_color.r, fire_color.g, fire_color.b, 0.82))


static func draw_contour(t: Node2D) -> void:
	# Hex capacitor body.
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2.ZERO, 18.0, 6, PI / 6.0))

	# Central coil rings and three external chain relay nodes.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 11.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 5.5)
	for i in range(3):
		var a := float(i) * TAU / 3.0 - PI / 2.0
		var tip := Vector2(cos(a), sin(a)) * 25.0
		TowerVisualDrawUtils._draw_contour_line(t, Vector2(cos(a), sin(a)) * 12.0, tip, 2.2)
		TowerVisualDrawUtils._draw_contour_circle(t, tip, 5.0)

	# Lower dual-element badge.
	TowerVisualDrawUtils._draw_contour_poly(t, _regular_poly(Vector2(0, 18.5), 6.0, 8, PI / 8.0))


static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var light_color := el_colors[0] if el_colors.size() > 0 else Color(1.0, 0.95, 0.34, 1.0)
	var fire_color := el_colors[1] if el_colors.size() > 1 else Color(1.0, 0.32, 0.08, 1.0)
	var electric := Color(1.0, 0.92, 0.22, 1.0)
	var hot := Color(1.0, 0.42, 0.08, 0.90)
	var metal := Color(0.11, 0.095, 0.035, 0.92)
	var dark_metal := Color(0.025, 0.018, 0.010, 0.95)

	# Static electric aura, very soft. This reads as chain range without drawing gameplay range.
	t.draw_arc(Vector2.ZERO, 27.0, -0.30, TAU - 0.30, 42, Color(electric.r, electric.g, electric.b, 0.10), 1.4, true)
	t.draw_arc(Vector2.ZERO, 21.0, 0.45, TAU + 0.45, 36, Color(fire_color.r, fire_color.g, fire_color.b, 0.08), 1.0, true)

	# Hexagonal capacitor chassis.
	var body := _regular_poly(Vector2.ZERO, 18.0, 6, PI / 6.0)
	_draw_stroked_poly(t, body, metal, 2.2)
	_draw_stroked_polyline(t, body, Color(electric.r, electric.g, electric.b, 0.62), 1.2)

	# Inner alternating plates to avoid a flat generic orb look.
	var upper_plate := PackedVector2Array([
		Vector2(-9.5, -8.5), Vector2(0.0, -13.0), Vector2(9.5, -8.5), Vector2(6.0, -2.0), Vector2(-6.0, -2.0)
	])
	var lower_plate := PackedVector2Array([
		Vector2(-9.5, 8.5), Vector2(0.0, 13.0), Vector2(9.5, 8.5), Vector2(6.0, 2.0), Vector2(-6.0, 2.0)
	])
	_draw_stroked_poly(t, upper_plate, Color(light_color.r, light_color.g, light_color.b, 0.24), 1.2)
	_draw_stroked_poly(t, lower_plate, Color(fire_color.r, fire_color.g, fire_color.b, 0.22), 1.2)

	# Relay nodes: three chain-jump contact points. Top node faces the default forward direction in catalog.
	var relay_points: Array[Vector2] = []
	for i in range(3):
		var a := float(i) * TAU / 3.0 - PI / 2.0
		var inner := Vector2(cos(a), sin(a)) * 11.5
		var mid := Vector2(cos(a + 0.07), sin(a + 0.07)) * 18.0
		var tip := Vector2(cos(a), sin(a)) * 25.0
		relay_points.append(tip)

		# Forked lightning rail from core to node.
		_draw_zap(t, PackedVector2Array([inner, mid, tip]), electric, 1.3)
		_draw_stroked_circle(t, tip, 5.0, dark_metal, 1.8)
		t.draw_circle(tip, 3.1, Color(electric.r, electric.g, electric.b, 0.72))
		t.draw_circle(tip, 1.35, Color(1.0, 1.0, 0.72, 0.95))

	# Chain language: small broken arcs between nodes, not a solid aura.
	for i in range(relay_points.size()):
		var a_pt := relay_points[i]
		var b_pt := relay_points[(i + 1) % relay_points.size()]
		var mid_pt := (a_pt + b_pt) * 0.5 + (a_pt + b_pt).normalized() * -2.0
		_draw_zap(t, PackedVector2Array([a_pt * 0.82, mid_pt, b_pt * 0.82]), Color(electric.r, electric.g, electric.b, 0.38), 0.75)

	# Central Tesla coil / capacitor core.
	_draw_stroked_circle(t, Vector2.ZERO, 10.5, dark_metal, 2.2)
	t.draw_circle(Vector2.ZERO, 8.4, Color(electric.r, electric.g, electric.b, 0.18))
	t.draw_arc(Vector2.ZERO, 7.4, -PI * 0.82, PI * 0.82, 26, Color(electric.r, electric.g, electric.b, 0.82), 1.35, true)
	t.draw_arc(Vector2.ZERO, 5.2, PI * 0.18, TAU + PI * 0.18, 24, Color(hot.r, hot.g, hot.b, 0.70), 1.05, true)
	_draw_zap(t, PackedVector2Array([Vector2(-3.8, -5.2), Vector2(1.1, -1.0), Vector2(-1.2, 1.0), Vector2(4.0, 5.2)]), Color(1.0, 1.0, 0.72, 0.95), 1.1)
	t.draw_circle(Vector2.ZERO, 2.25, Color(1.0, 0.96, 0.44, 0.95))

	# Small corner discharge beads. Subtle glow, no particles.
	var bead_color := Color(electric.r, electric.g, electric.b, 0.46)
	for p in [Vector2(-18, -18), Vector2(18, -18), Vector2(-18, 18), Vector2(18, 18)]:
		t.draw_circle(p, 4.6, Color(electric.r, electric.g, electric.b, 0.06))
		t.draw_arc(p, 3.3, 0.0, TAU, 18, DETAIL_OUTLINE_SOFT, 1.0, true)
		t.draw_arc(p, 2.6, 0.0, TAU, 18, bead_color, 0.8, true)

	# Dual element badge: light + fire, kept under the body as identity chip.
	_draw_light_fire_token(t, Vector2(0, 18.5), 6.0, light_color, fire_color)
