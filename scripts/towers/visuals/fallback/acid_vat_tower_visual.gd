extends RefCounted
class_name TowerVisualAcidVat

# Procedural visual for "acid_vat" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-14,-10,28,20))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-6,22+lvl*2,12))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(20+lvl*2,0), 4)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Corrosion (Darkness+Water+Fire) — acid reactor
	t.draw_rect(Rect2(-14,-10,28,20), main_color.darkened(0.4))
	t.draw_rect(Rect2(-10,-6,20,16), Color(0.04,0.06,0.03,1.0))
	var av_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
	t.draw_arc(Vector2(0,4), 9, 0, TAU, 32, Color(av_sec.r,av_sec.g,av_sec.b,0.7), 2.0)
	t.draw_rect(Rect2(0,-6,22+lvl*2,12), main_color.lightened(0.2))
	t.draw_circle(Vector2(20+lvl*2,0), 4, Color(0.3,1.0,0.1,0.8))
	t.draw_line(Vector2(-8,8), Vector2(-6,14), Color(0.4,1.0,0.2,0.6), 1.5)
	t.draw_circle(Vector2(-6,15), 2, Color(0.4,1.0,0.2,0.5))
	TowerVisualDrawUtils.draw_element_core(t)
