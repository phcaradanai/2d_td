extends RefCounted
class_name TowerVisualRootsT1

# Tower: Roots Tower 1
# Role: Immobilize / trap — root tendrils burst from the ground ensnaring enemies
# Elements: Darkness, Nature, Earth
# Visual intent: A gnarled dark stump with four thick root tendrils spreading at angles.
#   Each tendril has a visible bend and thorn tip — clearly organic and trapping, not spiky.
# Performance note: 1 polygon + 4 polylines + 4 thorn circles + 1 core circle. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	# Irregular stump outline
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(-7, -16), Vector2(6, -17), Vector2(16, -7),
		Vector2(17, 5), Vector2(8, 17), Vector2(-5, 16),
		Vector2(-16, 7), Vector2(-17, -4)
	]))
	# Four root tendrils
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-7, 7), Vector2(-20, 16), 4.5)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(7, 7), Vector2(20, 18), 4.5)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(7, -9), Vector2(20, -20), 3.5)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-6, -8), Vector2(-20, -18), 3.5)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var bark := main_color.darkened(0.45)
	var vine := secondary_color.darkened(0.1) if el_colors.size() >= 2 else main_color
	var thorn := el_colors[2] if el_colors.size() >= 3 else main_color.lightened(0.35)

	# Gnarled stump polygon
	var stump := PackedVector2Array([
		Vector2(-7, -16), Vector2(6, -17), Vector2(16, -7),
		Vector2(17, 5), Vector2(8, 17), Vector2(-5, 16),
		Vector2(-16, 7), Vector2(-17, -4)
	])
	t.draw_colored_polygon(stump, bark)
	t.draw_polyline(stump + PackedVector2Array([stump[0]]), main_color, 1.5)

	# Root tendrils — bent polylines with shadow and thorn tip
	var roots: Array = [
		PackedVector2Array([Vector2(-7, 7), Vector2(-13, 13), Vector2(-20, 16)]),
		PackedVector2Array([Vector2(7, 7), Vector2(14, 14), Vector2(20, 18)]),
		PackedVector2Array([Vector2(7, -9), Vector2(14, -15), Vector2(20, -20)]),
		PackedVector2Array([Vector2(-6, -8), Vector2(-13, -13), Vector2(-20, -18)])
	]
	for root in roots:
		t.draw_polyline(root, vine, 4.5)
		t.draw_polyline(root, Color(0.0, 0.0, 0.0, 0.35), 2.0)
		t.draw_circle(root[2], 2.5, thorn)

	# Hollow dark core
	t.draw_circle(Vector2.ZERO, 8.0, Color(0.02, 0.05, 0.01, 0.95))
	TowerVisualDrawUtils.draw_element_core(t)
