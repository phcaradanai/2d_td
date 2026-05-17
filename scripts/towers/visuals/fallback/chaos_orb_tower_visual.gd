extends RefCounted
class_name TowerVisualChaosOrb

# Procedural visual for "chaos_orb" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 12)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Magic (Darkness+Fire) — arcane flame sigil
	for i in range(6):
		var a1 = i * TAU/6.0
		var a2 = (i+2) * TAU/6.0
		t.draw_line(Vector2(cos(a1),sin(a1))*16, Vector2(cos(a2),sin(a2))*16, Color(main_color.r,main_color.g,main_color.b,0.65), 1.0)
	t.draw_circle(Vector2.ZERO, 12, Color(0.05,0.0,0.08,1.0))
	t.draw_circle(Vector2.ZERO, 8, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.9))
	for i in range(3):
		var a = t.idle_rotation * 0.8 + i * TAU/3.0
		t.draw_line(Vector2.RIGHT.rotated(a)*8, Vector2.RIGHT.rotated(a+0.35)*16, Color(1.0,0.4,0.0,0.6), 1.5)
	TowerVisualDrawUtils.draw_element_core(t)
