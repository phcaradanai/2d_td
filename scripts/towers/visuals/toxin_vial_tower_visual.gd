extends RefCounted
class_name TowerVisualToxinVial

# Procedural visual for "toxin_vial" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-8,-18),Vector2(8,-18),Vector2(10,-8),Vector2(12,12),Vector2(-12,12),Vector2(-10,-8)]))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-3,-24,6,8))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Poison (Darkness+Water) — toxin vial emitter
	var tv_pts = PackedVector2Array([Vector2(-8,-18),Vector2(8,-18),Vector2(10,-8),Vector2(12,12),Vector2(-12,12),Vector2(-10,-8)])
	t.draw_colored_polygon(tv_pts, Color(main_color.r,main_color.g,main_color.b,0.4))
	t.draw_polyline(tv_pts + PackedVector2Array([tv_pts[0]]), main_color.lightened(0.2), 1.5)
	var bubble_c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
	t.draw_circle(Vector2(-3,4), 3, bubble_c)
	t.draw_circle(Vector2(4,0), 2, bubble_c)
	t.draw_rect(Rect2(-3,-24,6,8), main_color)
	t.draw_circle(Vector2(0,-22), 2, Color(main_color.r,main_color.g,main_color.b,0.8))
	TowerVisualDrawUtils.draw_element_core(t)
