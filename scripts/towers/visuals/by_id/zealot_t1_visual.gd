extends RefCounted
class_name TowerVisualZealotT1

# Tower: Zealot Tower 1
# Role: Melee-AoE fanatic — high damage strikes to all enemies in close range
# Elements: Water, Fire, Earth
# Visual intent: Two crossed blades mounted on a stone altar with a holy flame at the top.
#   The X of crossed swords immediately reads as "attacks everything nearby."
# Performance note: 1 rect + 4 lines + 5 flame circles. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	# Stone altar base
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-16, 4, 32, 12))
	# Crossed blades
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-16, -18), Vector2(16, 10), 5.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(16, -18), Vector2(-16, 10), 5.0)
	# Holy flame aura at top
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(0, -16), 7.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var stone := el_colors[2].darkened(0.4) if el_colors.size() >= 3 else Color(0.38, 0.32, 0.28, 1.0)
	var blade := main_color.lightened(0.1)
	var flame := secondary_color if el_colors.size() >= 2 else Color(1.0, 0.55, 0.1, 0.9)

	# Stone altar base
	t.draw_rect(Rect2(-16, 4, 32, 12), stone)
	t.draw_rect(Rect2(-16, 4, 32, 4), stone.lightened(0.2))

	# Crossed blades (X) with edge highlight
	t.draw_line(Vector2(-16, -18), Vector2(16, 10), blade, 5.0)
	t.draw_line(Vector2(-16, -18), Vector2(16, 10), Color(1.0, 1.0, 1.0, 0.25), 2.0)
	t.draw_line(Vector2(16, -18), Vector2(-16, 10), blade, 5.0)
	t.draw_line(Vector2(16, -18), Vector2(-16, 10), Color(1.0, 1.0, 1.0, 0.25), 2.0)
	# Crossguard bar
	t.draw_line(Vector2(-11, -4), Vector2(11, -4), blade.lightened(0.3), 3.0)

	# Holy flame (orbiting cluster + central core)
	for i in range(5):
		var a : float = t.idle_rotation * 1.3 + float(i) * TAU / 5.0
		var r := 3.5 + float(i % 2) * 1.5
		t.draw_circle(
			Vector2(cos(a), sin(a)) * r + Vector2(0, -16),
			2.0, Color(flame.r, flame.g, flame.b, 0.72)
		)
	t.draw_circle(Vector2(0, -16), 5.0, Color(flame.r, flame.g, flame.b, 0.9))

	TowerVisualDrawUtils.draw_element_core(t)
