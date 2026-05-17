extends RefCounted
class_name TowerVisualHydroCannon

# Procedural visual for "hydro_cannon" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-18,-12,36,24))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-9,30+lvl*3,18))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(28+lvl*3,0), 7)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Hydro (Water+Earth) — water cannon on stone base
	var hc_stone = secondary_color if el_colors.size() >= 2 else main_color.darkened(0.4)
	t.draw_rect(Rect2(-18,-12,36,24), hc_stone.darkened(0.4))
	t.draw_rect(Rect2(-14,-8,28,16), Color(0.05,0.07,0.05,1.0))
	t.draw_rect(Rect2(0,-9,30+lvl*3,18), main_color)
	t.draw_rect(Rect2(22+lvl*3,-10,10,20), main_color.darkened(0.3))
	t.draw_circle(Vector2(28+lvl*3,0), 7, Color(main_color.r,main_color.g,main_color.b,0.9))
	t.draw_circle(Vector2(28+lvl*3,0), 3, Color(0.85,0.97,1.0,1.0))
	TowerVisualDrawUtils.draw_element_core(t)
