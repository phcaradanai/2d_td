extends RefCounted
class_name TowerVisualBlacksmithT1

# Tower: Blacksmith Tower 1
# Role: Economy / forge — buffs and upgrades nearby towers
# Elements: Fire, Earth
# Visual intent: An iron anvil with a protruding horn on the left and a flat top face.
#   The asymmetric anvil silhouette is unmistakably "blacksmith." Forge sparks orbit the strike point.
# Performance note: 2 rects + 1 polygon + 1 line + 3 spark circles. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	var lvl : int = t.tree_tier
	# Flat top face
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-16, -20, 32, 8))
	# Horn (left protrusion)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-24, -20, 10, 6))
	# Tapered body
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(-11, -12), Vector2(11, -12), Vector2(10, 8), Vector2(-10, 8)
	]))
	# Barrel / projectile emitter on right
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(11, -5, 16 + lvl * 2, 10))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var iron := main_color.darkened(0.4)
	var hot := secondary_color.lightened(0.2) if el_colors.size() >= 2 else Color(1.0, 0.6, 0.12, 0.9)

	# Tapered body
	t.draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -12), Vector2(11, -12), Vector2(10, 8), Vector2(-10, 8)
	]), iron)
	# Top face
	t.draw_rect(Rect2(-16, -20, 32, 8), main_color.darkened(0.2))
	t.draw_rect(Rect2(-16, -20, 32, 3), main_color.lightened(0.1))
	# Horn
	t.draw_rect(Rect2(-24, -20, 10, 6), iron)
	# Barrel
	t.draw_rect(Rect2(11, -5, 16 + lvl * 2, 10), main_color.darkened(0.1))
	t.draw_rect(Rect2(11, -4, 16 + lvl * 2, 8), Color(0.0, 0.0, 0.0, 0.3))

	# Heated strike line across top face
	t.draw_line(Vector2(-14, -20), Vector2(14, -20), hot, 2.0)

	# Rotating forge sparks around the strike point
	for i in range(3):
		var a : float = t.idle_rotation * 2.5 + float(i) * TAU / 3.0
		var r := 9.0 + float(i) * 3.0
		t.draw_circle(
			Vector2(cos(a), sin(a)) * r + Vector2(0.0, -8.0),
			1.5, hot
		)

	TowerVisualDrawUtils.draw_element_core(t)
