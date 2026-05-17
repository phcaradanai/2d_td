extends RefCounted
class_name TowerVisualSniper

# Procedural visual for "sniper" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0, -4, 40 + lvl * 6, 8))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(36 + lvl * 6, -5, 6, 10))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-18, -12), Vector2(12, -8), Vector2(12, 8), Vector2(-18, 12)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Long rifle — precision single-target (LEGACY - used by light towers currently)
	var barrel_accent := secondary_color if el_colors.size() >= 2 else main_color
	t.draw_rect(Rect2(0, -4, 40 + lvl * 6, 8), main_color)
	# Muzzle cap in secondary color
	t.draw_rect(Rect2(36 + lvl * 6, -5, 6, 10), barrel_accent.darkened(0.5))
	# Sleek body
	var pts = PackedVector2Array([Vector2(-18, -12), Vector2(12, -8), Vector2(12, 8), Vector2(-18, 12)])
	t.draw_colored_polygon(pts, main_color)
	t.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.6), 1.0)
	TowerVisualDrawUtils.draw_element_core(t)
