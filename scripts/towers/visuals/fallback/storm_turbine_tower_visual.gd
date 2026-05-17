extends RefCounted
class_name TowerVisualStormTurbine

# Procedural visual for "storm_turbine" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 18)
	for i in range(4):
		var a = i * TAU/4.0 + t.idle_rotation * 1.2
		TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(cos(a)*4,sin(a)*4), Vector2(cos(a+0.4)*16,sin(a+0.4)*16), Vector2(cos(a+0.6)*18,sin(a+0.6)*18), Vector2(cos(a+0.15)*4,sin(a+0.15)*4)]))

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Windstorm (Light+Water+Fire) — storm turbine with rotating blades
	t.draw_circle(Vector2.ZERO, 18, Color(main_color.r,main_color.g,main_color.b,0.18))
	t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, main_color, 2.0)
	for i in range(4):
		var a = i * TAU/4.0 + t.idle_rotation * 1.2
		var st_c = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
		t.draw_colored_polygon(PackedVector2Array([Vector2(cos(a)*4,sin(a)*4), Vector2(cos(a+0.4)*16,sin(a+0.4)*16), Vector2(cos(a+0.6)*18,sin(a+0.6)*18), Vector2(cos(a+0.15)*4,sin(a+0.15)*4)]), Color(st_c.r,st_c.g,st_c.b,0.75))
	t.draw_circle(Vector2.ZERO, 5, main_color.darkened(0.3))
	TowerVisualDrawUtils.draw_element_core(t)
