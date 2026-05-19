extends RefCounted
class_name TowerVisualHeavyMortar

# Procedural visual for "heavy_mortar" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-14,-18,28,36))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-12,28+lvl*2,24))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(26+lvl*2,0), 10)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Gunpowder (Darkness+Earth) — wide mortar tube
	t.draw_rect(Rect2(-14,-18,28,36), main_color.darkened(0.4))
	t.draw_rect(Rect2(-10,-14,20,28), Color(0.05,0.04,0.04,1.0))
	t.draw_line(Vector2(-14,-18), Vector2(0,-12), main_color.lightened(0.2), 2.0)
	t.draw_line(Vector2(-14,18), Vector2(0,12), main_color.lightened(0.2), 2.0)
	t.draw_rect(Rect2(0,-12,28+lvl*2,24), main_color)
	t.draw_circle(Vector2(26+lvl*2,0), 10, Color(0.07,0.05,0.05,1.0))
	t.draw_circle(Vector2(26+lvl*2,0), 6, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.8))
	TowerVisualDrawUtils.draw_element_core(t)
