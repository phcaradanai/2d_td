extends RefCounted
class_name TowerVisualRootCage

# Procedural visual for "root_cage" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 10)
	for i in range(5):
		var a = i * TAU/5.0 + t.idle_rotation * 0.2
		TowerVisualDrawUtils._draw_contour_line(t, Vector2.ZERO, Vector2(cos(a),sin(a)) * 22, 3.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Roots (Darkness+Nature+Earth) — thorn/root cage
	t.draw_circle(Vector2.ZERO, 10, Color(0.04,0.07,0.02,1.0))
	for i in range(5):
		var a = i * TAU/5.0 + t.idle_rotation * 0.2
		var rend = Vector2(cos(a),sin(a)) * 22
		t.draw_line(Vector2.ZERO, rend, main_color.darkened(0.1), 3.0)
		t.draw_line(Vector2.ZERO, rend, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.45), 1.0)
		var thorn_dir = Vector2(cos(a+PI/2.0),sin(a+PI/2.0))
		var thorn_base = rend - Vector2(cos(a),sin(a))*5
		var rc3 = el_colors[2] if el_colors.size() >= 3 else main_color
		t.draw_line(thorn_base, thorn_base + thorn_dir*5, Color(rc3.r,rc3.g,rc3.b,0.8), 1.5)
	TowerVisualDrawUtils.draw_element_core(t)
