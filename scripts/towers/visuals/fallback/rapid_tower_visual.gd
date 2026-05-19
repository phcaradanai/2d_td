extends RefCounted
class_name TowerVisualRapid

# Procedural visual for "rapid" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-8, -12, 36 + lvl * 3, 24))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-14, -10, 10, 20))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(28 + lvl * 3, -10, 10, 20))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(2, -5, 20 + lvl * 2, 10))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Neutral Cannon Tower — heavy starter, short thick barrel
	var plate_color := secondary_color if el_colors.size() >= 2 else core_color
	# Heavy base
	t.draw_rect(Rect2(-8, -12, 36 + lvl * 3, 24), main_color)
	t.draw_rect(Rect2(-4, -8, 30 + lvl * 3, 16), Color.BLACK)
	# Impact plates on sides
	t.draw_rect(Rect2(-14, -10, 10, 20), plate_color)
	t.draw_rect(Rect2(28 + lvl * 3, -10, 10, 20), plate_color)
	# Short thick barrel
	t.draw_rect(Rect2(2, -5, 20 + lvl * 2, 10), main_color)
	TowerVisualDrawUtils.draw_element_core(t)
