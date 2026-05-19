extends RefCounted
class_name TowerVisualSawblade

# Procedural visual for "sawblade" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	var blade_size = size + lvl * 2.0
	var teeth = 12
	var pts := PackedVector2Array()
	for i in range(teeth * 2):
		var angle = (float(i) / (teeth * 2)) * TAU + t.idle_rotation
		var r = blade_size * (1.0 if i % 2 == 0 else 0.7)
		pts.append(Vector2.RIGHT.rotated(angle) * r)
	TowerVisualDrawUtils._draw_contour_poly(t, pts)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, _core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Rotating saw — aura damage (LEGACY - used by darkness towers currently)
	var blade_size = size + lvl * 2.0
	# Hub
	t.draw_circle(Vector2.ZERO, blade_size * 0.7, Color(0.25, 0.25, 0.25))
	# Saw blade teeth in primary element color
	var blade_color := main_color
	var teeth = 12
	var pts = []
	for i in range(teeth * 2):
		var angle = (float(i) / (teeth * 2)) * TAU + t.idle_rotation
		var r = blade_size * (1.0 if i % 2 == 0 else 0.7)
		pts.append(Vector2.RIGHT.rotated(angle) * r)
	t.draw_colored_polygon(PackedVector2Array(pts), blade_color)
	# Center hub with secondary accent
	var hub_color := secondary_color.darkened(0.2) if el_colors.size() >= 2 else Color(0.45, 0.45, 0.45)
	t.draw_circle(Vector2.ZERO, blade_size * 0.3, hub_color)
	TowerVisualDrawUtils.draw_element_core(t)
