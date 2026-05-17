extends RefCounted
class_name TowerVisualTrickery

# Procedural visual for "trickery" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(0, -22), Vector2(18, -4), Vector2(10, 18), Vector2(-10, 18), Vector2(-18, -4)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Hologram prism — support/clone tower (Light + Darkness)
	var prism_fill := main_color if not el_colors.is_empty() else Color(0.72, 0.42, 1.0)
	var prism_edge := secondary_color.lightened(0.35) if el_colors.size() >= 2 else Color(0.95, 0.82, 1.0)
	var prism = PackedVector2Array([Vector2(0, -22), Vector2(18, -4), Vector2(10, 18), Vector2(-10, 18), Vector2(-18, -4)])
	t.draw_colored_polygon(prism, Color(prism_fill.r, prism_fill.g, prism_fill.b, 0.55))
	t.draw_polyline(prism + PackedVector2Array([prism[0]]), prism_edge, 1.5)
	# Inner dark circle + pulsing core
	t.draw_circle(Vector2.ZERO, 8, Color(0.12, 0.04, 0.2, 0.9))
	TowerVisualDrawUtils.draw_element_core(t)
	# Rotating rays
	for i in range(3):
		var a = t.idle_rotation * 0.7 + i * TAU / 3.0
		var ray_color := prism_edge
		if el_colors.size() >= 2:
			ray_color = el_colors[i % el_colors.size()].lightened(0.2)
		t.draw_line(Vector2.RIGHT.rotated(a) * 12, Vector2.RIGHT.rotated(a) * 22, Color(ray_color.r, ray_color.g, ray_color.b, 0.65), 1.5)
