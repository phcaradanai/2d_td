extends RefCounted

# Tower: Darkness Tower I
# Role: Void damage amplifier / vulnerability aura
# Elements: darkness
# Visual source: custom by_id visual
# Visual intent: aura debuff tower, not a cannon. Central void singularity with amplifier rings and shadow pylons.
# Performance note: CanvasItem draw calls only; no particles, no nodes, no gameplay logic.

const DETAIL_OUTLINE := Color(0.0, 0.0, 0.0, 0.94)
const DETAIL_OUTLINE_SOFT := Color(0.0, 0.0, 0.0, 0.68)
const VOID_CORE := Color(0.018, 0.010, 0.032, 0.96)

static func _regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _closed_polyline(t: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var path := PackedVector2Array(points)
	if path.size() > 0:
		path.append(path[0])
	t.draw_polyline(path, color, width, true)


static func _draw_stroked_line(t: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	t.draw_line(from, to, DETAIL_OUTLINE, width + 2.2, true)
	t.draw_line(from, to, color, width, true)


static func _draw_stroked_circle(t: Node2D, center: Vector2, radius: float, fill: Color, stroke_width := 1.8) -> void:
	t.draw_circle(center, radius + stroke_width, DETAIL_OUTLINE)
	t.draw_circle(center, radius, fill)


static func _draw_ring(t: Node2D, center: Vector2, radius: float, color: Color, width: float) -> void:
	t.draw_arc(center, radius, 0.0, TAU, 40, DETAIL_OUTLINE_SOFT, width + 1.6, true)
	t.draw_arc(center, radius, 0.0, TAU, 40, color, width, true)


static func _draw_shadow_diamond(t: Node2D, center: Vector2, radius: float, fill: Color, line: Color) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.72, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.72, 0),
	])
	t.draw_colored_polygon(diamond, DETAIL_OUTLINE)
	var inner := PackedVector2Array([
		center + Vector2(0, -radius + 1.8),
		center + Vector2(radius * 0.72 - 1.8, 0),
		center + Vector2(0, radius - 1.8),
		center + Vector2(-radius * 0.72 + 1.8, 0),
	])
	t.draw_colored_polygon(inner, fill)
	_closed_polyline(t, inner, line, 1.0)


static func _draw_darkness_element_icon(t: Node2D, center: Vector2, radius: float, main_color: Color) -> void:
	# Compact Darkness token, adapted for Node2D tower drawing.
	# Eclipse + void diamond language: this replaces generic cores.
	var purple := main_color.lightened(0.22)
	var token := _regular_poly(center, radius, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.78, 8, PI / 8.0)

	t.draw_colored_polygon(_regular_poly(center, radius * 1.12, 8, PI / 8.0), Color(purple.r, purple.g, purple.b, 0.10))
	t.draw_colored_polygon(token, DETAIL_OUTLINE)
	t.draw_colored_polygon(token, Color(0.018, 0.010, 0.030, 0.92))
	t.draw_colored_polygon(inner, Color(0.055, 0.020, 0.085, 0.88))
	_closed_polyline(t, token, Color(purple.r, purple.g, purple.b, 0.70), 1.25)

	# Eclipse disc: bright crescent eaten by black void.
	t.draw_circle(center, radius * 0.42, Color(purple.r, purple.g, purple.b, 0.68))
	t.draw_circle(center + Vector2(radius * 0.17, -radius * 0.06), radius * 0.39, Color(0.0, 0.0, 0.0, 0.92))
	t.draw_circle(center, radius * 0.14, Color(0.0, 0.0, 0.0, 0.94))
	t.draw_arc(center, radius * 0.48, -PI * 0.72, PI * 0.72, 20, Color(purple.r, purple.g, purple.b, 0.82), 1.0, true)


static func draw_contour(t: Node2D) -> void:
	var lvl: int = t.tree_tier
	var aura_r := 20.0 + float(lvl) * 1.6

	# Aura/debuff identity: circular amplifier, not a forward cannon.
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, aura_r)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 12.0)
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2.ZERO, 6.6)

	var pylons := [
		Vector2(0, -20),
		Vector2(20, 0),
		Vector2(0, 20),
		Vector2(-20, 0),
	]
	for p in pylons:
		TowerVisualDrawUtils._draw_contour_circle(t, p, 4.8)

	TowerVisualDrawUtils._draw_contour_line(t, Vector2(0, -14), Vector2(0, 14), 2.0)
	TowerVisualDrawUtils._draw_contour_line(t, Vector2(-14, 0), Vector2(14, 0), 2.0)


static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	var purple := main_color.lightened(0.20)
	var violet := Color(max(main_color.r, 0.32), max(main_color.g, 0.08), max(main_color.b, 0.58), 1.0)
	var aura := Color(purple.r, purple.g, purple.b, 0.22)
	var faint := Color(purple.r, purple.g, purple.b, 0.10)
	var aura_r := 20.0 + float(lvl) * 1.6

	# Soft static vulnerability field. Cheap, readable, and communicates aura attack_type.
	t.draw_circle(Vector2.ZERO, aura_r + 5.5, Color(purple.r, purple.g, purple.b, 0.035))
	t.draw_circle(Vector2.ZERO, aura_r, Color(purple.r, purple.g, purple.b, 0.050))
	_draw_ring(t, Vector2.ZERO, aura_r, Color(purple.r, purple.g, purple.b, 0.32), 1.1)
	_draw_ring(t, Vector2.ZERO, aura_r - 5.5, Color(purple.r, purple.g, purple.b, 0.22), 0.9)

	# Broken amplifier arcs: feels like debuff/vulnerability, not projectile firing.
	t.draw_arc(Vector2.ZERO, aura_r + 2.8, -0.10, 1.10, 18, DETAIL_OUTLINE_SOFT, 2.5, true)
	t.draw_arc(Vector2.ZERO, aura_r + 2.8, -0.10, 1.10, 18, aura, 1.2, true)
	t.draw_arc(Vector2.ZERO, aura_r + 2.8, PI - 0.10, PI + 1.10, 18, DETAIL_OUTLINE_SOFT, 2.5, true)
	t.draw_arc(Vector2.ZERO, aura_r + 2.8, PI - 0.10, PI + 1.10, 18, aura, 1.2, true)

	# Symmetric shadow pylons. They radiate the vulnerability aura.
	var pylon_points := [
		Vector2(0, -20),
		Vector2(20, 0),
		Vector2(0, 20),
		Vector2(-20, 0),
	]
	for p in pylon_points:
		t.draw_circle(p, 7.8, faint)
		_draw_stroked_circle(t, p, 4.9, Color(0.025, 0.012, 0.040, 0.92), 1.6)
		t.draw_circle(p, 2.2, Color(purple.r, purple.g, purple.b, 0.55))

	# Cross-channel lines connect pylons to the singularity.
	_draw_stroked_line(t, Vector2(0, -16), Vector2(0, -7), Color(purple.r, purple.g, purple.b, 0.48), 0.9)
	_draw_stroked_line(t, Vector2(16, 0), Vector2(7, 0), Color(purple.r, purple.g, purple.b, 0.48), 0.9)
	_draw_stroked_line(t, Vector2(0, 16), Vector2(0, 7), Color(purple.r, purple.g, purple.b, 0.48), 0.9)
	_draw_stroked_line(t, Vector2(-16, 0), Vector2(-7, 0), Color(purple.r, purple.g, purple.b, 0.48), 0.9)

	# Premium central void amplifier body.
	_draw_shadow_diamond(t, Vector2.ZERO, 13.0, Color(0.040, 0.018, 0.065, 0.94), Color(purple.r, purple.g, purple.b, 0.42))
	_draw_ring(t, Vector2.ZERO, 10.4, Color(purple.r, purple.g, purple.b, 0.34), 1.0)

	# Singularity core: black center with purple rim; this is the damage amplifier.
	_draw_stroked_circle(t, Vector2.ZERO, 7.0, VOID_CORE, 2.0)
	t.draw_circle(Vector2.ZERO, 5.4, Color(0.0, 0.0, 0.0, 0.92))
	t.draw_arc(Vector2.ZERO, 6.2, -PI * 0.70, PI * 0.35, 24, Color(violet.r, violet.g, violet.b, 0.82), 1.2, true)
	t.draw_arc(Vector2.ZERO, 3.5, PI * 0.20, PI * 1.35, 18, Color(purple.r, purple.g, purple.b, 0.56), 0.9, true)
	t.draw_circle(Vector2(-1.8, -1.3), 1.2, Color(0.82, 0.52, 1.0, 0.70))

	# Small debuff spikes around the core to show vulnerability status effect.
	var spike_c := Color(purple.r, purple.g, purple.b, 0.62)
	for i in range(8):
		var a := float(i) / 8.0 * TAU
		var from := Vector2(cos(a), sin(a)) * 14.2
		var to := Vector2(cos(a), sin(a)) * 17.0
		_draw_stroked_line(t, from, to, spike_c, 0.8)

	# Element token kept small so it does not hide the void core.
	_draw_darkness_element_icon(t, Vector2(-13, 13), 5.8, main_color)
