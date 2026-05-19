extends RefCounted
class_name TowerVisualVoidVortex

# Procedural visual for "void_vortex" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var _lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 20)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Drowning (Darkness+Water+Nature) — abyssal vortex
	var vv_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
	for i in range(4):
		var r = 20 - i * 4
		var col = main_color.lerp(vv_sec, float(i)/3.0)
		var arc_start = t.idle_rotation * (0.4 + i * 0.1)
		t.draw_arc(Vector2.ZERO, r, arc_start, arc_start + TAU * 0.8, 24, Color(col.r,col.g,col.b,0.4+i*0.08), 2.0 - i * 0.3)
	t.draw_circle(Vector2.ZERO, 8, Color(0.02,0.0,0.05,1.0))
	t.draw_circle(Vector2.ZERO, 4, Color(0.1,0.05,0.15,1.0))
	TowerVisualDrawUtils.draw_element_core(t)
