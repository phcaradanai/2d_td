extends RefCounted
class_name TowerVisualCannon

# Procedural visual for "cannon" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-6, -14, 32 + lvl * 4, 28))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-14, -16, 14, 32))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Heavy cannon — splash damage (LEGACY - used by fire/earth towers currently)
	var plate_color := secondary_color if el_colors.size() >= 2 else core_color
	t.draw_rect(Rect2(-6, -14, 32 + lvl * 4, 28), main_color)
	t.draw_rect(Rect2(-2, -10, 26 + lvl * 4, 20), Color.BLACK)
	t.draw_rect(Rect2(-14, -16, 14, 32), main_color)
	t.draw_rect(Rect2(-10, -12, 6, 24), plate_color)
	TowerVisualDrawUtils.draw_element_core(t)
