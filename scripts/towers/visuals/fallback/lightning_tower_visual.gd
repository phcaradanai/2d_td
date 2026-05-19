extends RefCounted
class_name TowerVisualLightning

# Procedural visual for "lightning" tower family.
# Keep this file visual-only. Safe to edit silhouette, contour, colors, and lightweight draw calls.

static func draw_contour(t: Node2D) -> void:
	var _lvl = t.tree_tier
	var _size = 20.0
	match t._get_tower_visual_family():
		"jinx":
			TowerVisualDrawUtils._draw_contour_poly(t, PackedVector2Array([Vector2(-14,-18),Vector2(8,-18),Vector2(18,-8),Vector2(10,0),Vector2(18,8),Vector2(8,18),Vector2(-14,18),Vector2(-4,0)]))
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 8)
		"periodic":
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 19)
			for i in range(6):
				var a = i * TAU / 6.0
				TowerVisualDrawUtils._draw_contour_circle(t, Vector2(cos(a), sin(a)) * 18, 3.5)
		_:
			TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 16)
			for i in range(4):
				var a = i * PI / 2 + (t.idle_rotation * 0.3)
				var tip := Vector2(cos(a), sin(a)) * 24
				TowerVisualDrawUtils._draw_contour_line(t, Vector2.ZERO, tip, 3.0)
				TowerVisualDrawUtils._draw_contour_circle(t, tip, 4)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, _lvl: int, size: float, el_colors: Array[Color]) -> void:
	# Electricity / Jinx / Periodic — shared chain-like VFX, distinct silhouettes.
	var spike_tip_color := secondary_color if el_colors.size() >= 2 else core_color
	match t._get_tower_visual_family():
		"jinx":
			var jinx_pts = PackedVector2Array([Vector2(-14,-18),Vector2(8,-18),Vector2(18,-8),Vector2(10,0),Vector2(18,8),Vector2(8,18),Vector2(-14,18),Vector2(-4,0)])
			t.draw_colored_polygon(jinx_pts, Color(main_color.r, main_color.g, main_color.b, 0.55))
			t.draw_polyline(jinx_pts + PackedVector2Array([jinx_pts[0]]), secondary_color.lightened(0.25), 1.4)
			t.draw_circle(Vector2.ZERO, 8, Color(0.05,0.0,0.08,1.0))
			for i in range(3):
				var a = -PI / 4.0 + i * PI / 4.0
				t.draw_line(Vector2(2, 0), Vector2(cos(a), sin(a)) * 18, spike_tip_color, 1.5)
		"periodic":
			t.draw_arc(Vector2.ZERO, 19, 0, TAU, 36, Color(main_color.r,main_color.g,main_color.b,0.6), 2.0)
			for i in range(6):
				var a = i * TAU / 6.0
				var node_color = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
				t.draw_circle(Vector2(cos(a), sin(a)) * 18, 3.5, node_color)
			t.draw_circle(Vector2.ZERO, 9, Color(0.92,0.96,1.0,0.85))
		_:
			t.draw_circle(Vector2.ZERO, 16, main_color)
			t.draw_arc(Vector2.ZERO, 16, 0, TAU, 32, main_color.lightened(0.4), 1.5)
			for i in range(4):
				var a = i * PI / 2 + (t.idle_rotation * 0.3)
				t.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 24, main_color, 3.0)
				t.draw_circle(Vector2(cos(a), sin(a)) * 24, 4, spike_tip_color)
			for i in range(2):
				var crackle_pts = PackedVector2Array()
				var start_a = randf() * TAU
				var dist = randf_range(18, 30)
				crackle_pts.append(Vector2.RIGHT.rotated(start_a) * 12)
				crackle_pts.append(Vector2.RIGHT.rotated(start_a + 0.2) * dist)
				crackle_pts.append(Vector2.RIGHT.rotated(start_a - 0.2) * (dist + 5))
				t.draw_polyline(crackle_pts, core_color, 1.0)
	TowerVisualDrawUtils.draw_element_core(t)
