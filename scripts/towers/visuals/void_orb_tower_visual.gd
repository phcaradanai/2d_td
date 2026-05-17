extends RefCounted
class_name TowerVisualVoidOrb

# Procedural visual for "void_orb" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 20)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Darkness — void orb with shadow rings and inward particles
	t.draw_circle(Vector2.ZERO, 20, Color(main_color.r,main_color.g,main_color.b,0.12))
	t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.5), 2.0)
	t.draw_arc(Vector2.ZERO, 12, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.4), 1.5)
	t.draw_circle(Vector2.ZERO, 9, Color(0.04,0.0,0.1,1.0))
	for i in range(6):
		var a = i * TAU/6.0 + t.idle_rotation * 0.4
		t.draw_line(Vector2(cos(a),sin(a))*16, Vector2(cos(a),sin(a))*11, Color(main_color.r,main_color.g,main_color.b,0.7), 1.5)
	TowerVisualDrawUtils.draw_element_core(t)
