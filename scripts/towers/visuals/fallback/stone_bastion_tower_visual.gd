extends RefCounted
class_name TowerVisualStoneBastion

# Procedural visual for "stone_bastion" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-20,-20,40,40))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-10,26+lvl*3,20))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-20,-8,8,16))

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Earth — heavy armored block with amber reactor
	t.draw_rect(Rect2(-20,-20,40,40), main_color.darkened(0.4))
	t.draw_rect(Rect2(-14,-14,28,28), Color(0.06,0.04,0.02,1.0))
	t.draw_line(Vector2(-20,-20), Vector2(-14,-14), main_color.lightened(0.2), 1.0)
	t.draw_line(Vector2(20,-20), Vector2(14,-14), main_color.lightened(0.2), 1.0)
	t.draw_line(Vector2(-20,20), Vector2(-14,14), main_color.lightened(0.2), 1.0)
	t.draw_line(Vector2(20,20), Vector2(14,14), main_color.lightened(0.2), 1.0)
	t.draw_rect(Rect2(0,-10,26+lvl*3,20), main_color)
	t.draw_rect(Rect2(18+lvl*3,-12,10,24), main_color.darkened(0.3))
	t.draw_rect(Rect2(-20,-8,8,16), main_color.darkened(0.2))
	TowerVisualDrawUtils.draw_element_core(t)
