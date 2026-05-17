extends RefCounted
class_name TowerVisualVaporT1

# Tower: Vapor Tower 1
# Role: Slowing steam cloud — emits vapor that reduces enemy movement speed
# Elements: Water, Fire
# Visual intent: A pressurized steam boiler — round tank body with a right-facing nozzle
#   and a safety valve on top venting steam arcs. Communicates "pressurized slow substance."
# Performance note: 1 circle + 2 arcs + 2 rects + 1 line + 2 steam arcs. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	var lvl : int = t.tree_tier
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 16.0)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(12, -4, 12 + lvl * 2, 8))
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(0, -16), 4.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var steam := Color(0.82, 0.92, 1.0, 0.6)
	var hot := secondary_color if el_colors.size() >= 2 else Color(1.0, 0.62, 0.18, 0.9)
	var nozzle_len := 12.0 + float(lvl) * 2.0

	# Boiler body
	t.draw_circle(Vector2.ZERO, 16.0, main_color.darkened(0.25))
	t.draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, main_color.lightened(0.2), 1.8)
	# Pressure gauge ring
	t.draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20,
		Color(0.6, 0.75, 0.9, 0.45), 1.0)
	# Rivet band
	t.draw_line(Vector2(-16.0, 0.0), Vector2(12.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.35), 2.0)

	# Nozzle
	t.draw_rect(Rect2(12, -4, nozzle_len, 8), main_color.darkened(0.1))
	t.draw_rect(Rect2(12, -3, nozzle_len, 6), Color(0.0, 0.0, 0.0, 0.3))
	# Nozzle tip heat edge
	t.draw_line(
		Vector2(12.0 + nozzle_len, -4.0),
		Vector2(12.0 + nozzle_len, 4.0), hot, 2.5
	)

	# Safety valve
	t.draw_circle(Vector2(0, -16), 4.0, hot)
	t.draw_circle(Vector2(0, -16), 2.0, Color(1.0, 1.0, 1.0, 0.5))
	# Steam venting arcs from valve
	for i in range(2):
		var sa : float = t.idle_rotation * 0.7 + float(i) * PI
		t.draw_arc(Vector2(0, -16), 6.0, sa, sa + PI, 8, steam, 1.5)

	t.draw_circle(Vector2.ZERO, 7.0, Color(0.05, 0.06, 0.08, 0.95))
	TowerVisualDrawUtils.draw_element_core(t)
