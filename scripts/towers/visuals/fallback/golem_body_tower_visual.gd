extends RefCounted
class_name TowerVisualGolemBody

# Procedural visual for "golem_body" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-18,-18,36,36))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-12,24+lvl*2,24))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Flesh Golem (Water+Nature+Earth) — bulky organic golem
	t.draw_rect(Rect2(-18,-18,36,36), main_color.darkened(0.3))
	t.draw_rect(Rect2(-12,-12,24,24), Color(0.04,0.08,0.05,1.0))
	var gl_vein = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
	t.draw_line(Vector2(-12,-12), Vector2(0,0), Color(gl_vein.r,gl_vein.g,gl_vein.b,0.5), 1.0)
	t.draw_line(Vector2(-12,12), Vector2(0,0), Color(gl_vein.r,gl_vein.g,gl_vein.b,0.5), 1.0)
	t.draw_rect(Rect2(0,-12,24+lvl*2,24), main_color)
	var gl_pulse = el_colors[1] if el_colors.size() >= 2 else main_color
	t.draw_circle(Vector2(-4,0), 8, Color(gl_pulse.r,gl_pulse.g,gl_pulse.b,0.4))
	TowerVisualDrawUtils.draw_element_core(t)
