extends RefCounted
class_name TowerVisualTrickeryT1

# Tower: Trickery Tower 1
# Role: Deception / illusion / clone support
# Elements: Light, Darkness
# Visual intent: A split-face diamond prism — left half void-dark, right half brilliant light.
#   The diagonal cut through the body signals duality and misdirection at a glance.
# Performance note: 2 triangles + 1 polygon outline + 1 circle + 4 lines. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([
		Vector2(0, -22), Vector2(18, 0), Vector2(0, 16), Vector2(-18, 0)
	]))
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(0, -22), Vector2(0, 16), 1.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 7)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var light_col := el_colors[0] if not el_colors.is_empty() else Color(1.0, 0.95, 0.7)
	var dark_col := el_colors[1] if el_colors.size() >= 2 else Color(0.12, 0.0, 0.24)

	# Dark left half
	t.draw_colored_polygon(PackedVector2Array([
		Vector2(0, -22), Vector2(0, 16), Vector2(-18, 0)
	]), Color(dark_col.r, dark_col.g, dark_col.b, 0.75))
	# Light right half
	t.draw_colored_polygon(PackedVector2Array([
		Vector2(0, -22), Vector2(18, 0), Vector2(0, 16)
	]), Color(light_col.r, light_col.g, light_col.b, 0.55))

	# Diamond outline
	var pts := PackedVector2Array([
		Vector2(0, -22), Vector2(18, 0), Vector2(0, 16), Vector2(-18, 0)
	])
	t.draw_polyline(pts + PackedVector2Array([pts[0]]),
		Color(light_col.r, light_col.g, light_col.b, 0.9), 1.5)
	# Split divider line
	t.draw_line(Vector2(0, -22), Vector2(0, 16), Color(1.0, 1.0, 1.0, 0.35), 1.0)

	# Inner void core
	t.draw_circle(Vector2.ZERO, 7, Color(0.08, 0.04, 0.14, 0.95))
	TowerVisualDrawUtils.draw_element_core(t)

	# Rotating dual-tone rays (alternating light / dark)
	for i in range(4):
		var a : float = t.idle_rotation * 0.8 + float(i) * TAU / 4.0
		var ray_col := light_col if i % 2 == 0 else dark_col.lightened(0.35)
		t.draw_line(
			Vector2(cos(a), sin(a)) * 9.0,
			Vector2(cos(a), sin(a)) * 20.0,
			Color(ray_col.r, ray_col.g, ray_col.b, 0.5), 1.5
		)
