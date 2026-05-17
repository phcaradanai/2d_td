extends RefCounted
class_name TowerVisualSporeCap

# Procedural visual for "spore_cap" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	if t._get_tower_visual_family() == "disease":
		TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-16,-14),Vector2(0,-22),Vector2(16,-14),Vector2(14,10),Vector2(0,20),Vector2(-14,10)]))
		for i in range(4):
			var a = i * TAU / 4.0 + PI / 4.0
			TowerVisualDrawUtils._draw_contour_line(t, Vector2(cos(a), sin(a)) * 12, Vector2(cos(a), sin(a)) * 21, 2.0)
	else:
		TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-6,0,12,16))
		TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-20,0),Vector2(-14,-12),Vector2(-6,-20),Vector2(0,-22),Vector2(6,-20),Vector2(14,-12),Vector2(20,0)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	if t._get_tower_visual_family() == "disease":
		var disease_pts = PackedVector2Array([Vector2(-16,-14),Vector2(0,-22),Vector2(16,-14),Vector2(14,10),Vector2(0,20),Vector2(-14,10)])
		t.draw_colored_polygon(disease_pts, Color(main_color.r,main_color.g,main_color.b,0.42))
		t.draw_polyline(disease_pts + PackedVector2Array([disease_pts[0]]), secondary_color.lightened(0.25), 1.4)
		for i in range(4):
			var a = i * TAU / 4.0 + PI / 4.0
			t.draw_line(Vector2(cos(a),sin(a))*12, Vector2(cos(a),sin(a))*21, main_color.lightened(0.2), 1.8)
		t.draw_circle(Vector2.ZERO, 7, Color(0.05,0.08,0.02,1.0))
	else:
		t.draw_rect(Rect2(-6,0,12,16), main_color.darkened(0.3))
		var sc_pts = PackedVector2Array([Vector2(-20,0),Vector2(-14,-12),Vector2(-6,-20),Vector2(0,-22),Vector2(6,-20),Vector2(14,-12),Vector2(20,0)])
		t.draw_colored_polygon(sc_pts, main_color)
		t.draw_polyline(sc_pts, secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3), 1.5)
		for i in range(3):
			var a = -PI/2.0 + (i-1)*0.5
			t.draw_circle(Vector2(cos(a),sin(a))*14, 2, Color(1.0,1.0,0.8,0.8))
	TowerVisualDrawUtils.draw_element_core(t)
