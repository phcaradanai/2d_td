extends RefCounted
class_name TowerVisualVoidFlower

# Procedural visual for "void_flower" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var _lvl = t.tree_tier
	var _size = 20.0
	for i in range(5):
		var a = i * TAU/5.0 + t.idle_rotation * -0.2
		TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(cos(a-0.3),sin(a-0.3))*6, Vector2(cos(a),sin(a))*18, Vector2(cos(a+0.3),sin(a+0.3))*6]))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 10)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Oblivion (Light+Darkness+Nature) — collapsing star/void flower
	for i in range(5):
		var a = i * TAU/5.0 + t.idle_rotation * -0.2
		var pf_col = main_color if i % 2 == 0 else secondary_color
		t.draw_colored_polygon(PackedVector2Array([Vector2(cos(a-0.3),sin(a-0.3))*6, Vector2(cos(a),sin(a))*18, Vector2(cos(a+0.3),sin(a+0.3))*6]), Color(pf_col.r,pf_col.g,pf_col.b,0.55))
	t.draw_circle(Vector2.ZERO, 10, Color(0.04,0.0,0.1,1.0))
	t.draw_circle(Vector2.ZERO, 6, main_color.darkened(0.2))
	t.draw_circle(Vector2.ZERO, 3, Color(1.0,1.0,1.0,0.6))
	TowerVisualDrawUtils.draw_element_core(t)
