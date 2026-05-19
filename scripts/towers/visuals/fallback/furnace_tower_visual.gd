extends RefCounted
class_name TowerVisualFurnace

# Procedural visual for "furnace" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-16,-16,32,32))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-7,28+lvl*3,14))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(20+lvl*3,-9,10,18))

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Fire — furnace body with plasma nozzle
	t.draw_rect(Rect2(-16,-16,32,32), main_color.darkened(0.5))
	t.draw_rect(Rect2(-12,-12,24,24), Color(0.08,0.02,0.0,1.0))
	for i in range(3):
		t.draw_rect(Rect2(-14,-10+i*8,6,4), Color(1.0,0.3,0.0,0.8))
	t.draw_rect(Rect2(0,-7,28+lvl*3,14), main_color)
	t.draw_rect(Rect2(20+lvl*3,-9,10,18), main_color.darkened(0.3))
	t.draw_circle(Vector2(24+lvl*3,0), 6, Color(1.0,0.6,0.1,0.85))
	TowerVisualDrawUtils.draw_element_core(t)
