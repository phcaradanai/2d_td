extends RefCounted
class_name TowerVisualTriReactor

# Procedural visual for "tri_reactor" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 20)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-3,30+lvl*4,6))
	for i in range(3):
		var a = t.idle_rotation * 0.6 + i * TAU/3.0
		TowerVisualDrawUtils._draw_contour_circle(t, Vector2(cos(a),sin(a)) * 14, 5)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Impulse (Water+Fire+Nature) — unstable tri-core reactor
	t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.4), 3.0)
	for i in range(3):
		var a = t.idle_rotation * 0.6 + i * TAU/3.0
		var tp = Vector2(cos(a),sin(a)) * 14
		var tec = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
		t.draw_circle(tp, 5, tec)
		t.draw_circle(tp, 2.5, tec.lightened(0.5))
	t.draw_rect(Rect2(0,-3,30+lvl*4,6), Color(0.8,0.8,0.8,0.7))
	TowerVisualDrawUtils.draw_element_core(t)
