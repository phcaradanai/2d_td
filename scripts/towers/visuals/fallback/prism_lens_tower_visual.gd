extends RefCounted
class_name TowerVisualPrismLens

# Procedural visual for "prism_lens" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	match t._get_tower_visual_family():
		"ice":
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0,-24),Vector2(12,-8),Vector2(8,16),Vector2(0,22),Vector2(-8,16),Vector2(-12,-8)]))
			TowerVisualDrawUtils._draw_contour_line(t, Vector2(-18, -4), Vector2(18, 4), 3.0)
			TowerVisualDrawUtils._draw_contour_line(t, Vector2(-14, 10), Vector2(14, -10), 3.0)
		"polar":
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 18)
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-18,-10),Vector2(10,-16),Vector2(22,0),Vector2(10,16),Vector2(-18,10),Vector2(-8,0)]))
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2(20, 0), 5)
		_:
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(14,-8),Vector2(18,6),Vector2(0,14),Vector2(-18,6),Vector2(-14,-8)]))
			TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-4,32+lvl*4,8))
			TowerVisualDrawUtils._draw_contour_rect(t, Rect2(28+lvl*4,-6,8,12))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	# Light / Ice / Polar share lens attacks but keep different silhouettes.
	match t._get_tower_visual_family():
		"ice":
			var ice_pts = PackedVector2Array([Vector2(0,-24),Vector2(12,-8),Vector2(8,16),Vector2(0,22),Vector2(-8,16),Vector2(-12,-8)])
			t.draw_colored_polygon(ice_pts, Color(main_color.r,main_color.g,main_color.b,0.52))
			t.draw_polyline(ice_pts + PackedVector2Array([ice_pts[0]]), Color(0.82,0.96,1.0,0.9), 1.4)
			t.draw_line(Vector2(-18,-4), Vector2(18,4), secondary_color.lightened(0.25), 2.0)
			t.draw_line(Vector2(-14,10), Vector2(14,-10), Color(0.88,0.98,1.0,0.65), 1.5)
		"polar":
			t.draw_arc(Vector2.ZERO, 18, -PI * 0.72, PI * 0.72, 32, main_color, 3.0)
			var polar_pts = PackedVector2Array([Vector2(-18,-10),Vector2(10,-16),Vector2(22,0),Vector2(10,16),Vector2(-18,10),Vector2(-8,0)])
			t.draw_colored_polygon(polar_pts, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.42))
			t.draw_polyline(polar_pts + PackedVector2Array([polar_pts[0]]), main_color.lightened(0.25), 1.4)
			t.draw_circle(Vector2(20,0), 4, Color(0.9,0.98,1.0,0.9))
		_:
			var prism_pts = PackedVector2Array([Vector2(0,-22),Vector2(14,-8),Vector2(18,6),Vector2(0,14),Vector2(-18,6),Vector2(-14,-8)])
			t.draw_colored_polygon(prism_pts, Color(main_color.r,main_color.g,main_color.b,0.45))
			t.draw_polyline(prism_pts + PackedVector2Array([prism_pts[0]]), main_color.lightened(0.35), 1.5)
			t.draw_rect(Rect2(0,-4,32+lvl*4,8), main_color.darkened(0.35))
			t.draw_rect(Rect2(28+lvl*4,-6,8,12), main_color)
			t.draw_circle(Vector2(32+lvl*4,0), 5, Color.BLACK)
			t.draw_circle(Vector2(32+lvl*4,0), 3, main_color.lightened(0.5))
			t.draw_circle(Vector2.ZERO, 10, Color(main_color.r,main_color.g,main_color.b,0.25))
	TowerVisualDrawUtils.draw_element_core(t)
