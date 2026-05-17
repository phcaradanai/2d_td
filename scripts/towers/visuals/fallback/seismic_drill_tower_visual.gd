extends RefCounted
class_name TowerVisualSeismicDrill

# Procedural visual for "seismic_drill" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-14,-12,24,24))
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0,-8),Vector2(30+lvl*3,0),Vector2(0,8)]))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(28+lvl*3,0), 5)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Quaker (Fire+Nature+Earth) — seismic drill head
	t.draw_rect(Rect2(-14,-12,24,24), main_color.darkened(0.3))
	var sd_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
	for i in range(3):
		t.draw_line(Vector2(-8+i*8,-12), Vector2(-8+i*8,12), Color(sd_sec.r,sd_sec.g,sd_sec.b,0.6), 2.0)
	t.draw_colored_polygon(PackedVector2Array([Vector2(0,-8),Vector2(30+lvl*3,0),Vector2(0,8)]), main_color.lightened(0.2))
	var sd3 = el_colors[2] if el_colors.size() >= 3 else main_color
	t.draw_circle(Vector2(28+lvl*3,0), 5, Color(sd3.r,sd3.g,sd3.b,0.8))
	TowerVisualDrawUtils.draw_element_core(t)
