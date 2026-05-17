extends RefCounted
class_name TowerVisualDualNozzle

# Procedural visual for "dual_nozzle" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-16,-18,32,36))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-14,30+lvl*2,10))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,4,30+lvl*2,10))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-20,-16,6,32))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Flamethrower (Darkness+Fire+Earth) — heavy dual nozzle
	t.draw_rect(Rect2(-16,-18,32,36), main_color.darkened(0.5))
	t.draw_rect(Rect2(-10,-12,20,24), Color(0.04,0.02,0.02,1.0))
	var dn_barrel = secondary_color.darkened(0.2) if el_colors.size() >= 2 else main_color
	t.draw_rect(Rect2(0,-14,30+lvl*2,10), dn_barrel)
	t.draw_rect(Rect2(0,4,30+lvl*2,10), dn_barrel)
	t.draw_circle(Vector2(28+lvl*2,-9), 5, Color(1.0,0.4,0.0,0.9))
	t.draw_circle(Vector2(28+lvl*2,9), 5, Color(1.0,0.4,0.0,0.9))
	var dn_fuel = el_colors[2] if el_colors.size() >= 3 else main_color
	t.draw_rect(Rect2(-20,-16,6,32), Color(dn_fuel.r,dn_fuel.g,dn_fuel.b,0.8))
	TowerVisualDrawUtils.draw_element_core(t)
