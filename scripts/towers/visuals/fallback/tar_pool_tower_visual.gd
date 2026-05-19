extends RefCounted
class_name TowerVisualTarPool

# Procedural visual for "tar_pool" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var _lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-18,-8,36,16))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 16)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Muck (Darkness+Water+Earth) — tar/sludge pool emitter
	t.draw_rect(Rect2(-18,-8,36,16), main_color.darkened(0.5))
	t.draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.6), 3.0)
	t.draw_circle(Vector2.ZERO, 12, Color(0.04,0.03,0.07,0.9))
	t.draw_rect(Rect2(0,-5,18+lvl*2,10), Color(0.18,0.14,0.22,1.0))
	var b2c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
	t.draw_circle(Vector2(-4,2), 2, Color(b2c.r,b2c.g,b2c.b,0.6))
	t.draw_circle(Vector2(5,-3), 2, Color(b2c.r,b2c.g,b2c.b,0.5))
	TowerVisualDrawUtils.draw_element_core(t)
