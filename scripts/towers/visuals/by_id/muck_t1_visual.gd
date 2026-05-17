extends RefCounted
class_name TowerVisualMuckT1

# Tower: Muck Tower 1
# Role: Slowing tar — fires sticky muck that greatly reduces enemy movement speed
# Elements: Darkness, Water, Earth
# Visual intent: A dark iron cauldron brimming with bubbling tar. The rounded cauldron
#   body, thick rim, and rotating tar-bubble dots communicate "slow sticky substance."
# Performance note: 1 polygon + 1 circle (fill) + 1 rect + 1 line + 3 bubble circles. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	var lvl : int = t.tree_tier
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(-20, 0), Vector2(-17, -12), Vector2(-7, -18),
		Vector2(7, -18), Vector2(17, -12), Vector2(20, 0),
		Vector2(14, 12), Vector2(-14, 12)
	]))
	# Iron rim
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-22, -5, 44, 5))
	# Ejector nozzle
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(14, -4, 10 + lvl * 2, 8))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var sludge := main_color.darkened(0.35)
	var tar := Color(0.05, 0.04, 0.07, 1.0)
	var bubble_col := secondary_color if el_colors.size() >= 2 else main_color.lightened(0.25)

	# Cauldron body
	var cauldron := PackedVector2Array([
		Vector2(-20, 0), Vector2(-17, -12), Vector2(-7, -18),
		Vector2(7, -18), Vector2(17, -12), Vector2(20, 0),
		Vector2(14, 12), Vector2(-14, 12)
	])
	t.draw_colored_polygon(cauldron, sludge)
	t.draw_polyline(cauldron + PackedVector2Array([cauldron[0]]), main_color, 1.5)

	# Tar fill inside (dark circle)
	t.draw_circle(Vector2(0, -5), 12.0, tar)

	# Iron rim
	t.draw_rect(Rect2(-22, -5, 44, 5), main_color.darkened(0.1))
	t.draw_line(Vector2(-22, -5), Vector2(22, -5), main_color.lightened(0.15), 1.5)

	# Ejector nozzle
	var nozzle_len := 10.0 + float(lvl) * 2.0
	t.draw_rect(Rect2(14, -4, nozzle_len, 8), sludge)

	# Rotating tar bubbles
	for i in range(3):
		var a : float = t.idle_rotation * 0.5 + float(i) * TAU / 3.0
		var bpos := Vector2(cos(a) * 6.0, sin(a) * 4.0 - 5.0)
		t.draw_circle(bpos, 2.5, Color(bubble_col.r, bubble_col.g, bubble_col.b, 0.6))

	TowerVisualDrawUtils.draw_element_core(t)
