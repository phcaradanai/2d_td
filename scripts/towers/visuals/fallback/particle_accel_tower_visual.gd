extends RefCounted
class_name TowerVisualParticleAccel

# Procedural visual for "particle_accel" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var _size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 18)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-2,38+lvl*5,4))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Quark (Light+Earth) — particle accelerator ring
	t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, main_color, 3.0)
	t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, secondary_color if el_colors.size() >= 2 else core_color, 1.5)
	t.draw_rect(Rect2(0,-2,38+lvl*5,4), main_color.lightened(0.2))
	t.draw_circle(Vector2(36+lvl*5,0), 3, core_color)
	for i in range(3):
		var a = t.idle_rotation * 1.2 + i * TAU/3.0
		t.draw_circle(Vector2(cos(a),sin(a))*18, 2, core_color)
	TowerVisualDrawUtils.draw_element_core(t)
