extends RefCounted
class_name TowerVisualSteamBoiler

# Procedural visual for "steam_boiler" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-16,-14,32,28))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(0,-6,24+lvl*2,12))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Vapor (Water+Fire) — steam boiler with vents
	t.draw_rect(Rect2(-16,-14,32,28), main_color.darkened(0.3))
	t.draw_rect(Rect2(-12,-10,24,20), Color(0.04,0.06,0.08,1.0))
	var vc = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
	for i in range(3):
		t.draw_rect(Rect2(-10+i*8,-18,4,6), vc)
		t.draw_circle(Vector2(-8+i*8,-20), 3, Color(0.88,0.9,1.0,0.65))
	t.draw_rect(Rect2(0,-6,24+lvl*2,12), main_color.lightened(0.2))
	t.draw_circle(Vector2(-8,0), 5, Color(0.3,0.3,0.3,1.0))
	t.draw_arc(Vector2(-8,0), 3, -PI*0.8, -PI*0.8 + PI * (0.5 + 0.5 * sin(t.idle_rotation * 0.5)), 8, Color(1.0,0.6,0.0,0.9), 2.0)
	TowerVisualDrawUtils.draw_element_core(t)
