extends RefCounted
class_name TowerVisualGoldRefinery

# Procedural visual for "gold_refinery" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-12,0,24,12))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-10,-4,20,8))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-8,-18,16,20))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-4,24+lvl*2,8))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Gold (Light+Fire+Earth) — midas gold refinery
	t.draw_rect(Rect2(-12,0,24,12), Color(0.82,0.68,0.1,1.0))
	t.draw_rect(Rect2(-10,-4,20,8), Color(1.0,0.85,0.22,1.0))
	t.draw_rect(Rect2(-8,-18,16,20), main_color.darkened(0.2))
	t.draw_rect(Rect2(-6,-16,12,16), Color(0.1,0.08,0.02,1.0))
	t.draw_rect(Rect2(0,-4,24+lvl*2,8), Color(1.0,0.85,0.1,1.0))
	for i in range(4):
		var a = t.idle_rotation * 0.8 + i * TAU/4.0
		t.draw_circle(Vector2(cos(a),sin(a))*14, 2, Color(1.0,0.9,0.22,0.9))
	TowerVisualDrawUtils.draw_element_core(t)
