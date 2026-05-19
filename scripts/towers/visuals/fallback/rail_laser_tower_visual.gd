extends RefCounted
class_name TowerVisualRailLaser

# Procedural visual for "rail_laser" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-18,-14,32,28))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-5,44+lvl*5,10))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(42+lvl*5,0), 4)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Laser (Light+Darkness+Earth) — heavy rail-laser cannon
	t.draw_rect(Rect2(-18,-14,32,28), main_color.darkened(0.4))
	t.draw_rect(Rect2(-12,-10,20,20), Color(0.05,0.03,0.08,1.0))
	t.draw_rect(Rect2(0,-5,44+lvl*5,10), main_color)
	for i in range(3):
		t.draw_rect(Rect2(6+i*12,-7,4,14), main_color.lightened(0.3))
	var rl_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.4)
	t.draw_circle(Vector2(42+lvl*5,0), 4, Color(rl_sec.r,rl_sec.g,rl_sec.b,0.8))
	t.draw_circle(Vector2(42+lvl*5,0), 2, Color(1.0,1.0,1.0,0.9))
	TowerVisualDrawUtils.draw_element_core(t)
