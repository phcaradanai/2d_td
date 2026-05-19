extends RefCounted
class_name TowerVisualForgeAnvil

# Procedural visual for "forge_anvil" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-20,8),Vector2(20,8),Vector2(16,0),Vector2(8,-4),Vector2(8,-16),Vector2(-8,-16),Vector2(-8,-4),Vector2(-16,0)]))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 8)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(8,-5,20+lvl*2,10))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Blacksmith (Fire+Earth) — forge anvil silhouette
	var fa_pts = PackedVector2Array([Vector2(-20,8),Vector2(20,8),Vector2(16,0),Vector2(8,-4),Vector2(8,-16),Vector2(-8,-16),Vector2(-8,-4),Vector2(-16,0)])
	t.draw_colored_polygon(fa_pts, main_color.darkened(0.3))
	t.draw_polyline(fa_pts + PackedVector2Array([fa_pts[0]]), main_color, 1.5)
	t.draw_circle(Vector2.ZERO, 8, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.7))
	t.draw_rect(Rect2(8,-5,20+lvl*2,10), main_color.lightened(0.2))
	for i in range(4):
		var a = t.idle_rotation * 1.5 + i * TAU/4.0
		t.draw_circle(Vector2(cos(a),sin(a))*(10+randf()*5), 1.5, Color(1.0,0.82,0.2,0.85))
	TowerVisualDrawUtils.draw_element_core(t)
