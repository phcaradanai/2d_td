extends RefCounted
class_name TowerVisualSupportHalo

# Procedural visual for "support_halo" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	match t._get_tower_visual_family():
		"life":
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(20,0),Vector2(10,8),Vector2(0,22),Vector2(-10,8),Vector2(-20,0),Vector2(-10,-8)]))
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 8)
		"well":
			TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-18,-10,36,20))
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 16)
		"tidal":
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 19)
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-18,8),Vector2(-6,-8),Vector2(8,-14),Vector2(20,-4),Vector2(8,8),Vector2(-6,14)]))
		"enchantment":
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(19,-11),Vector2(19,11),Vector2(0,22),Vector2(-19,11),Vector2(-19,-11)]))
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 9)
		_:
			TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-10,-10,20,20))
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 20)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var h2c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
	# Support families share aura behavior, but not the same silhouette.
	match t._get_tower_visual_family():
		"life":
			var life_pts = PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(20,0),Vector2(10,8),Vector2(0,22),Vector2(-10,8),Vector2(-20,0),Vector2(-10,-8)])
			t.draw_colored_polygon(life_pts, Color(main_color.r,main_color.g,main_color.b,0.48))
			t.draw_polyline(life_pts + PackedVector2Array([life_pts[0]]), h2c.lightened(0.25), 1.4)
			t.draw_circle(Vector2.ZERO, 8, Color(h2c.r,h2c.g,h2c.b,0.7))
		"well":
			t.draw_rect(Rect2(-18,-10,36,20), main_color.darkened(0.35))
			t.draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(h2c.r,h2c.g,h2c.b,0.75), 2.0)
			t.draw_arc(Vector2.ZERO, 10, 0, TAU, 32, Color(0.82,0.96,1.0,0.5), 1.5)
		"tidal":
			t.draw_arc(Vector2.ZERO, 19, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.55), 2.0)
			var wave_pts = PackedVector2Array([Vector2(-18,8),Vector2(-6,-8),Vector2(8,-14),Vector2(20,-4),Vector2(8,8),Vector2(-6,14)])
			t.draw_colored_polygon(wave_pts, Color(h2c.r,h2c.g,h2c.b,0.55))
			t.draw_polyline(wave_pts + PackedVector2Array([wave_pts[0]]), Color(0.9,0.98,1.0,0.7), 1.2)
		"enchantment":
			var hex_pts = PackedVector2Array([Vector2(0,-22),Vector2(19,-11),Vector2(19,11),Vector2(0,22),Vector2(-19,11),Vector2(-19,-11)])
			t.draw_colored_polygon(hex_pts, Color(main_color.r,main_color.g,main_color.b,0.28))
			t.draw_polyline(hex_pts + PackedVector2Array([hex_pts[0]]), h2c.lightened(0.35), 1.5)
			t.draw_circle(Vector2.ZERO, 9, Color(main_color.r,main_color.g,main_color.b,0.7))
		_:
			t.draw_rect(Rect2(-10,-10,20,20), main_color.darkened(0.4))
			t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.65), 2.0)
			t.draw_arc(Vector2.ZERO, 14, 0, TAU, 32, Color(h2c.r,h2c.g,h2c.b,0.4), 1.5)
			for i in range(4):
				var a = t.idle_rotation * 0.5 + i * TAU/4.0
				t.draw_circle(Vector2(cos(a),sin(a))*20, 3, main_color.lightened(0.35))
	TowerVisualDrawUtils.draw_element_core(t)
