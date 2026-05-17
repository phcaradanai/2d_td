extends RefCounted
class_name TowerVisualEmberBloom

# Procedural visual for "ember_bloom" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	for i in range(5):
		var a = i * TAU/5.0 + t.idle_rotation * 0.3
		TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2.ZERO, Vector2(cos(a-0.4),sin(a-0.4))*16, Vector2(cos(a),sin(a))*22, Vector2(cos(a+0.4),sin(a+0.4))*16]))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 10)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Flame (Fire+Nature) — wildfire bio-core with ember leaves
	for i in range(5):
		var a = i * TAU/5.0 + t.idle_rotation * 0.3
		var ep_pts = PackedVector2Array([Vector2.ZERO, Vector2(cos(a-0.4),sin(a-0.4))*16, Vector2(cos(a),sin(a))*22, Vector2(cos(a+0.4),sin(a+0.4))*16])
		t.draw_colored_polygon(ep_pts, Color(main_color.r,main_color.g,main_color.b,0.5))
	t.draw_circle(Vector2.ZERO, 10, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.85))
	t.draw_circle(Vector2.ZERO, 6, Color(1.0,0.92,0.3,0.9))
	TowerVisualDrawUtils.draw_element_core(t)
