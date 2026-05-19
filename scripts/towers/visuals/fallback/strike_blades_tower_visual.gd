extends RefCounted
class_name TowerVisualStrikeBlades

# Procedural visual for "strike_blades" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-14,-14),Vector2(18,-6),Vector2(24,0),Vector2(18,6),Vector2(-14,14),Vector2(-6,0)]))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-2,-6),Vector2(10,-6),Vector2(14,-14),Vector2(2,-16)]))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-2,6),Vector2(10,6),Vector2(14,14),Vector2(2,16)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Zealot (Water+Fire+Earth) — aggressive blade striker
	var sb_pts = PackedVector2Array([Vector2(-14,-14),Vector2(18,-6),Vector2(24,0),Vector2(18,6),Vector2(-14,14),Vector2(-6,0)])
	t.draw_colored_polygon(sb_pts, main_color.darkened(0.2))
	t.draw_polyline(sb_pts + PackedVector2Array([sb_pts[0]]), main_color.lightened(0.2), 1.5)
	var w2c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
	t.draw_colored_polygon(PackedVector2Array([Vector2(-2,-6),Vector2(10,-6),Vector2(14,-14),Vector2(2,-16)]), w2c)
	t.draw_colored_polygon(PackedVector2Array([Vector2(-2,6),Vector2(10,6),Vector2(14,14),Vector2(2,16)]), w2c)
	TowerVisualDrawUtils.draw_element_core(t)
