extends RefCounted
class_name TowerVisualCrystalEmitter

# Procedural visual for "crystal_emitter" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(8,12),Vector2(0,18),Vector2(-8,12),Vector2(-10,-8)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Water — blue crystal with ripple rings
	t.draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.18), 1.5)
	t.draw_arc(Vector2.ZERO, 15, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.3), 1.5)
	var cx_pts = PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(8,12),Vector2(0,18),Vector2(-8,12),Vector2(-10,-8)])
	t.draw_colored_polygon(cx_pts, Color(main_color.r,main_color.g,main_color.b,0.55))
	t.draw_polyline(cx_pts + PackedVector2Array([cx_pts[0]]), Color(0.7,0.95,1.0,0.9), 1.5)
	t.draw_line(Vector2(0,-22), Vector2(0,18), Color(1.0,1.0,1.0,0.18), 1.0)
	TowerVisualDrawUtils.draw_element_core(t)
