extends RefCounted
class_name TowerVisualElectricityT1

# Tower: Electricity Tower 1
# Role: Chain lightning — arcs to multiple nearby enemies simultaneously
# Elements: Light, Fire
# Visual intent: A hexagonal Tesla-coil frame with three arc-tip nodes rotating outward.
#   The nodes suggest electricity jumping between targets; hex body signals structured energy.
# Performance note: 1 polygon + 1 arc + 6 circles + 3 lines. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var a := float(i) * TAU / 6.0
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	TowerVisualDrawUtils._draw_contour_poly(t, pts)
	for i in range(3):
		var a : float = float(i) * TAU / 3.0 + t.idle_rotation * 0.35
		TowerVisualDrawUtils._draw_contour_circle(t, Vector2(cos(a), sin(a)) * 22.0, 3.5)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var arc_col := secondary_color if el_colors.size() >= 2 else Color(1.0, 0.88, 0.2, 1.0)

	# Hexagonal body
	var pts := PackedVector2Array()
	for i in range(6):
		var a := float(i) * TAU / 6.0
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	t.draw_colored_polygon(pts, Color(main_color.r, main_color.g, main_color.b, 0.55))
	t.draw_polyline(pts + PackedVector2Array([pts[0]]),
		main_color.lightened(0.35), 1.5)

	# Inner coil ring
	t.draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20,
		Color(main_color.r, main_color.g, main_color.b, 0.6), 1.2)

	# Three arc-tip nodes with connecting spokes
	for i in range(3):
		var a : float = float(i) * TAU / 3.0 + t.idle_rotation * 0.35
		var tip := Vector2(cos(a), sin(a)) * 22.0
		t.draw_line(Vector2(cos(a), sin(a)) * 11.0, tip, arc_col, 1.5)
		t.draw_circle(tip, 3.5, arc_col)
		t.draw_circle(tip, 2.0, Color(1.0, 1.0, 1.0, 0.5))

	t.draw_circle(Vector2.ZERO, 8.0, Color(0.04, 0.02, 0.0, 0.95))
	TowerVisualDrawUtils.draw_element_core(t)
