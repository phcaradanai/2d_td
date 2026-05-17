extends RefCounted
class_name TowerVisualFlamethrowerT1

# Tower: Flamethrower Tower 1
# Role: Cone area fire — continuous flame projection over short range
# Elements: Darkness, Fire, Earth
# Visual intent: A heavy armoured fuel tank body (round, plated) with a wide tapered nozzle
#   facing right. Flame streaks from the nozzle tip make the fire-cone role unmistakable.
# Performance note: 1 circle + 1 arc + 3 band lines + 2 polygons + 4 flame lines. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	var lvl : int = t.tree_tier
	# Armoured fuel tank (round)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-8, 0), 15.0)
	# Wide tapered nozzle
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(4, -7), Vector2(26 + lvl * 2, -11),
		Vector2(26 + lvl * 2, 11), Vector2(4, 7)
	]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var tank := main_color.darkened(0.3)
	var nozzle_col := main_color.darkened(0.1)
	var flame := secondary_color if el_colors.size() >= 2 else Color(1.0, 0.5, 0.08, 0.9)
	var tip_x := 26.0 + float(lvl) * 2.0

	# Fuel tank
	t.draw_circle(Vector2(-8, 0), 15.0, tank)
	t.draw_arc(Vector2(-8, 0), 15.0, 0.0, TAU, 30, tank.lightened(0.2), 1.8)
	# Armour bands (horizontal plate lines)
	for i in range(3):
		var by := -5.0 + float(i) * 5.0
		t.draw_line(Vector2(-22.0, by), Vector2(2.0, by), Color(0.0, 0.0, 0.0, 0.4), 1.5)

	# Nozzle body
	t.draw_colored_polygon(PackedVector2Array([
		Vector2(4, -7), Vector2(tip_x, -11),
		Vector2(tip_x, 11), Vector2(4, 7)
	]), nozzle_col)
	# Nozzle inset shadow
	t.draw_colored_polygon(PackedVector2Array([
		Vector2(6, -5), Vector2(tip_x - 1, -9),
		Vector2(tip_x - 1, 9), Vector2(6, 5)
	]), Color(0.0, 0.0, 0.0, 0.3))

	# Flame streams from nozzle tip
	for i in range(4):
		var fy := -8.0 + float(i) * 5.5
		var fa : float = t.idle_rotation * 1.6 + float(i) * 0.45
		var fl := 9.0 + cos(fa) * 3.0
		t.draw_line(
			Vector2(tip_x, fy),
			Vector2(tip_x + fl, fy + sin(fa) * 3.0),
			Color(flame.r, flame.g, flame.b, 0.75 - float(i) * 0.12),
			2.5 - float(i) * 0.3
		)

	t.draw_circle(Vector2(-8, 0), 6.0, Color(0.06, 0.03, 0.02, 0.95))
	TowerVisualDrawUtils.draw_element_core(t)
