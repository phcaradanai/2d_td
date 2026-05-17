extends RefCounted
class_name TowerVisualBasic

# Procedural visual for "basic" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0, -6, 26 + lvl * 4, 12))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 15)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Neutral Arrow Tower — precision starter, thin rail-arrow barrel
	t.draw_rect(Rect2(0, -6, 26 + lvl * 4, 12), main_color)
	t.draw_rect(Rect2(2, -4, 22 + lvl * 4, 8), Color(0, 0, 0, 0.5))
	t.draw_circle(Vector2.ZERO, 15, main_color)
	t.draw_circle(Vector2.ZERO, 10, Color.BLACK)
	if el_colors.is_empty():
		t.draw_circle(Vector2.ZERO, 6, core_color)
	else:
		TowerVisualDrawUtils.draw_element_core(t)
