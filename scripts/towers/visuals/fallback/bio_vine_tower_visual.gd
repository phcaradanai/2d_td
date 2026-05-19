extends RefCounted
class_name TowerVisualBioVine

# Procedural visual for "bio_vine" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-14,-16),Vector2(16,0),Vector2(-14,16),Vector2(-8,0)]))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(4,-12,22+lvl*2,6))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(4,6,22+lvl*2,6))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Nature — organic vine-wrapped twin barrel turret
	var bv_pts = PackedVector2Array([Vector2(-14,-16),Vector2(16,0),Vector2(-14,16),Vector2(-8,0)])
	t.draw_colored_polygon(bv_pts, main_color.darkened(0.3))
	t.draw_polyline(bv_pts + PackedVector2Array([bv_pts[0]]), main_color, 1.5)
	t.draw_rect(Rect2(4,-12,22+lvl*2,6), main_color.darkened(0.2))
	t.draw_rect(Rect2(4,6,22+lvl*2,6), main_color.darkened(0.2))
	for i in range(3):
		t.draw_line(Vector2(6+i*7,-12), Vector2(9+i*7,6), Color(main_color.r,main_color.g,main_color.b,0.55), 1.0)
	var leaf_c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
	t.draw_circle(Vector2(24+lvl*2,-9), 4, leaf_c)
	t.draw_circle(Vector2(24+lvl*2,9), 4, leaf_c)
	TowerVisualDrawUtils.draw_element_core(t)
