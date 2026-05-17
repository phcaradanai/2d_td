extends RefCounted
class_name TowerVisualSlow

# Procedural visual for "slow" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0, -20 - lvl * 2), Vector2(16, 0), Vector2(0, 20 + lvl * 2), Vector2(-16, 0)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Diamond shard — slow/freeze (LEGACY - used by water towers currently)
	var outline_color := Color.WHITE
	if el_colors.size() >= 2:
		outline_color = secondary_color.lightened(0.3)
	var pts = PackedVector2Array([Vector2(0, -20 - lvl * 2), Vector2(16, 0), Vector2(0, 20 + lvl * 2), Vector2(-16, 0)])
	t.draw_colored_polygon(pts, main_color)
	t.draw_polyline(pts + PackedVector2Array([pts[0]]), outline_color, 1.5)
	# Aura ring
	t.draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(main_color.r, main_color.g, main_color.b, 0.2), 2.0)
	TowerVisualDrawUtils.draw_element_core(t)
