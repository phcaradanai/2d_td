extends RefCounted
class_name TowerVisualQuarkT1

# Tower: Quark Tower 1
# Role: Particle physics — fires sub-atomic projectiles with area physics damage
# Elements: Light, Earth
# Visual intent: A Bohr-model atom — two visible orbital shells with moving electron dots
#   and a dense glowing nucleus. Communicates "particle" identity unmistakably.
# Performance note: 2 arcs + 6 circles. Safe for gameplay rate.

static func draw_contour(t: Node2D) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 20.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 13.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 6.0)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var orbital_col := secondary_color if el_colors.size() >= 2 else Color(0.9, 0.85, 0.4, 0.8)
	var nucleus_col := main_color.lightened(0.15)

	# Outer orbital shell
	t.draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 36,
		Color(orbital_col.r, orbital_col.g, orbital_col.b, 0.35), 1.2)
	# Inner orbital shell
	t.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 28,
		Color(orbital_col.r, orbital_col.g, orbital_col.b, 0.5), 1.2)

	# Outer electrons (2, counter-rotating slowly)
	for i in range(2):
		var a : float = t.idle_rotation * 1.1 + float(i) * PI
		t.draw_circle(Vector2(cos(a), sin(a)) * 20.0, 2.5,
			Color(orbital_col.r, orbital_col.g, orbital_col.b, 0.9))
	# Inner electrons (2, opposite phase)
	for i in range(2):
		var a : float = t.idle_rotation * -0.85 + float(i) * PI + PI * 0.5
		t.draw_circle(Vector2(cos(a), sin(a)) * 13.0, 2.0,
			Color(orbital_col.r, orbital_col.g, orbital_col.b, 0.85))

	# Nucleus (dense layered core)
	t.draw_circle(Vector2.ZERO, 6.0, nucleus_col)
	t.draw_circle(Vector2.ZERO, 4.0, Color(0.9, 0.9, 0.6, 0.9))
	TowerVisualDrawUtils.draw_element_core(t)
