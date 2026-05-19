extends RefCounted
class_name TowerVisualVoodooTotem

# Procedural visual for "voodoo_totem" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var _lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-8,-22,16,44))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-10,-26,20,16))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Voodoo (Darkness+Fire+Nature) — cursed totem pole
	t.draw_rect(Rect2(-8,-22,16,44), main_color.darkened(0.3))
	t.draw_rect(Rect2(-10,-26,20,16), main_color.darkened(0.2))
	t.draw_circle(Vector2(-5,-20), 3, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.9))
	t.draw_circle(Vector2(5,-20), 3, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.9))
	var vtc3 = el_colors[2] if el_colors.size() >= 3 else main_color
	t.draw_arc(Vector2.ZERO, 14, 0, TAU, 6, Color(vtc3.r,vtc3.g,vtc3.b,0.7), 1.5)
	for i in range(2):
		var bx = 12 * (1 if i == 0 else -1)
		t.draw_line(Vector2(0,-10), Vector2(bx,-18), main_color.lightened(0.3), 2.0)
		t.draw_circle(Vector2(bx,-18), 3, Color(1.0,1.0,0.8,0.7))
	TowerVisualDrawUtils.draw_element_core(t)
