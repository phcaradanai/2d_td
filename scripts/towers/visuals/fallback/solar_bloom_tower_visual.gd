extends RefCounted
class_name TowerVisualSolarBloom

# Procedural visual for "solar_bloom" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var _lvl = t.tree_tier
	var _size = 20.0
	for i in range(6):
		var a = i * TAU/6.0 + t.idle_rotation * 0.2
		TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(cos(a-0.35),sin(a-0.35))*6, Vector2(cos(a),sin(a))*20, Vector2(cos(a+0.35),sin(a+0.35))*6]))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 10)

static func draw_top(t: Node2D, main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Nova (Light+Fire+Nature) — solar flower reactor
	for i in range(6):
		var a = i * TAU/6.0 + t.idle_rotation * 0.2
		var sol_c = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
		t.draw_colored_polygon(PackedVector2Array([Vector2(cos(a-0.35),sin(a-0.35))*6, Vector2(cos(a),sin(a))*20, Vector2(cos(a+0.35),sin(a+0.35))*6]), Color(sol_c.r,sol_c.g,sol_c.b,0.6))
	t.draw_circle(Vector2.ZERO, 10, Color(1.0,0.9,0.3,0.9))
	t.draw_circle(Vector2.ZERO, 6, Color(1.0,1.0,0.85,1.0))
	TowerVisualDrawUtils.draw_element_core(t)
