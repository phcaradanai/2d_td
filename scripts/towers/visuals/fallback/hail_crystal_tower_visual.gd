extends RefCounted
class_name TowerVisualHailCrystal

# Procedural visual for "hail_crystal" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	for i in range(6):
		var a = i * TAU/6.0 + t.idle_rotation * 0.1
		TowerVisualDrawUtils._draw_contour_line(t, Vector2.ZERO, Vector2(cos(a),sin(a))*20, 2.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 6)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Hail (Light+Darkness+Water) — storm ice crystal snowflake
	for i in range(6):
		var a = i * TAU/6.0 + t.idle_rotation * 0.1
		t.draw_line(Vector2.ZERO, Vector2(cos(a),sin(a))*20, main_color, 2.0)
		var mid = Vector2(cos(a),sin(a)) * 12
		t.draw_line(mid, mid + Vector2(cos(a+PI/3.0),sin(a+PI/3.0))*6, main_color.lightened(0.3), 1.0)
		t.draw_line(mid, mid + Vector2(cos(a-PI/3.0),sin(a-PI/3.0))*6, main_color.lightened(0.3), 1.0)
	var hc_sec = secondary_color if el_colors.size() >= 2 else main_color.darkened(0.3)
	t.draw_circle(Vector2.ZERO, 6, Color(hc_sec.r,hc_sec.g,hc_sec.b,0.6))
	t.draw_circle(Vector2.ZERO, 3, Color(0.9,0.95,1.0,0.9))
	TowerVisualDrawUtils.draw_element_core(t)
