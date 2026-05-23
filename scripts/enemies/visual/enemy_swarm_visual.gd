class_name EnemySwarmVisual
extends RefCounted

static func _draw_swarm_orbiter(enemy: Node2D, origin: Vector2, size: float, flicker: float) -> void:
	EnemySwarmVisual._draw_swarm_body_layers(enemy, origin, size, flicker)
	var orb_core := enemy.swarm_core_glow_color.lerp(enemy.SWARM_GLOW_LIGHT, 0.42)
	EnemySwarmVisual._draw_swarm_core_layers(enemy, origin + Vector2(size * 0.08, -size * 0.02), size * 0.52, orb_core, 0.55, flicker)


static func _draw_swarm_hover_fx(enemy: Node2D, origin: Vector2, size: float, pulse: float) -> void:
	var shadow_pos := origin + Vector2(-size * 0.16, size * 0.90)
	enemy.draw_circle(
		shadow_pos,
		size * (0.72 + pulse * 0.03),
		Color(0.0, 0.0, 0.0, 0.10 + pulse * 0.03)
	)
	var under_glow_pos := origin + Vector2(-size * 0.04, size * 0.36)
	enemy.draw_arc(
		under_glow_pos,
		size * (0.68 + pulse * 0.03),
		PI * 0.16,
		PI * 0.84,
		18,
		Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.10 + pulse * 0.03),
		1.0
	)
	

static func _draw_swarm_body_layers(enemy: Node2D, origin: Vector2, size: float, flicker: float) -> void:
	# Symmetric 3/4 top-down swarm body. Keep wings mirrored to avoid visual skew.
	var skew_y := size * 0.05

	var outer := PackedVector2Array([
		origin + Vector2(size * 1.42, 0.0),
		origin + Vector2(size * 0.76, -size * 0.34),
		origin + Vector2(-size * 0.18, -size * 0.76 + skew_y),
		origin + Vector2(-size * 0.94, -size * 0.54 + skew_y),
		origin + Vector2(-size * 0.58, 0.0 + skew_y * 0.75),
		origin + Vector2(-size * 0.94, size * 0.54 + skew_y),
		origin + Vector2(-size * 0.18, size * 0.76 + skew_y),
		origin + Vector2(size * 0.76, size * 0.34)
	])

	var inner := PackedVector2Array([
		origin + Vector2(size * 0.86, 0.0),
		origin + Vector2(size * 0.24, -size * 0.22),
		origin + Vector2(-size * 0.20, -size * 0.48 + skew_y * 0.85),
		origin + Vector2(-size * 0.42, 0.0 + skew_y * 0.6),
		origin + Vector2(-size * 0.20, size * 0.48 + skew_y * 0.85),
		origin + Vector2(size * 0.24, size * 0.22)
	])

	var under_plate := PackedVector2Array([
		origin + Vector2(size * 0.38, size * 0.14 + skew_y * 0.55),
		origin + Vector2(-size * 0.16, size * 0.08 + skew_y * 0.72),
		origin + Vector2(-size * 0.02, size * 0.42 + skew_y * 0.9),
		origin + Vector2(size * 0.28, size * 0.34 + skew_y * 0.78)
	])

	var top_fin := PackedVector2Array([
		origin + Vector2(-size * 0.34, -size * 0.34 + skew_y * 0.55),
		origin + Vector2(-size * 1.18, -size * 0.98 + skew_y),
		origin + Vector2(-size * 0.92, -size * 0.14 + skew_y * 0.8),
		origin + Vector2(-size * 0.48, -size * 0.06 + skew_y * 0.65)
	])

	var bottom_fin := PackedVector2Array([
		origin + Vector2(-size * 0.34, size * 0.34 + skew_y * 0.55),
		origin + Vector2(-size * 1.18, size * 0.98 + skew_y),
		origin + Vector2(-size * 0.92, size * 0.14 + skew_y * 0.8),
		origin + Vector2(-size * 0.48, size * 0.06 + skew_y * 0.65)
	])

	var sensor := PackedVector2Array([
		origin + Vector2(size * 1.04, 0.0),
		origin + Vector2(size * 0.82, -size * 0.15),
		origin + Vector2(size * 0.82, size * 0.15)
	])

	enemy.draw_colored_polygon(top_fin, SWARM_PANEL_COLOR)
	enemy.draw_colored_polygon(bottom_fin, SWARM_PANEL_COLOR)
	enemy.draw_colored_polygon(outer, swarm_body_color)
	enemy.draw_colored_polygon(inner, SWARM_PANEL_COLOR)
	enemy.draw_colored_polygon(under_plate, Color(SWARM_PANEL_COLOR.r, SWARM_PANEL_COLOR.g, SWARM_PANEL_COLOR.b, 0.8))
	enemy.draw_colored_polygon(sensor, Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.86 * flicker))

	enemy.draw_polyline(outer + PackedVector2Array([outer[0]]), Color(SWARM_TRAIL_COLOR.r, SWARM_TRAIL_COLOR.g, SWARM_TRAIL_COLOR.b, 0.9), 1.35)
	enemy.draw_polyline(top_fin + PackedVector2Array([top_fin[0]]), Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.52 * flicker), 1.0)
	enemy.draw_polyline(bottom_fin + PackedVector2Array([bottom_fin[0]]), Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.52 * flicker), 1.0)

	# Mirrored wing circuit accents. Do not use an undeclared variable named angle here.
	enemy.draw_line(
		origin + Vector2(-size * 0.98, -size * 0.72 + skew_y),
		origin + Vector2(-size * 0.74, -size * 0.30 + skew_y),
		Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.98 * flicker),
		1.25
	)
	enemy.draw_line(
		origin + Vector2(-size * 0.98, size * 0.72 + skew_y),
		origin + Vector2(-size * 0.74, size * 0.30 + skew_y),
		Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.98 * flicker),
		1.25
	)

	enemy.draw_line(
		origin + Vector2(size * 0.60, -size * 0.04),
		origin + Vector2(-size * 0.04, -size * 0.24 + skew_y * 0.72),
		Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.88 * flicker),
		1.15
	)
	enemy.draw_line(
		origin + Vector2(size * 0.60, size * 0.04),
		origin + Vector2(-size * 0.04, size * 0.24 + skew_y * 0.72),
		Color(SWARM_TRAIL_COLOR.r, SWARM_TRAIL_COLOR.g, SWARM_TRAIL_COLOR.b, 0.78 * flicker),
		1.15
	)
	enemy.draw_circle(
		origin + Vector2(-size * 0.60, -size * 0.20),
		size * 0.055,
		Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.86 * flicker)
	)
	enemy.draw_circle(
		origin + Vector2(-size * 0.68, 0.0),
		size * 0.065,
		Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.92 * flicker)
	)
	enemy.draw_circle(
		origin + Vector2(-size * 0.60, size * 0.20),
		size * 0.055,
		Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.86 * flicker)
	)


static func _draw_swarm_core_layers(enemy: Node2D, origin: Vector2, size: float, core_color: Color, pulse: float, flicker: float) -> void:
	var glow_core := PackedVector2Array()
	var core := PackedVector2Array()
	var hot_core := PackedVector2Array()
	var radius_glow := size * (0.68 + pulse * 0.12)
	for i in range(6):
		var a := PI / 6.0 + float(i) * TAU / 6.0
		var dir := Vector2(cos(a), sin(a))
		glow_core.append(origin + dir * radius_glow)
		core.append(origin + dir * size * 0.34)
		hot_core.append(origin + dir * size * (0.17 + pulse * 0.03))
	enemy.draw_colored_polygon(glow_core, Color(core_color.r, core_color.g, core_color.b, 0.34 * flicker))
	enemy.draw_colored_polygon(core, Color(core_color.r, core_color.g, core_color.b, 0.98 * flicker))
	enemy.draw_polyline(core + PackedVector2Array([core[0]]), Color(enemy.SWARM_GLOW_LIGHT.r, enemy.SWARM_GLOW_LIGHT.g, enemy.SWARM_GLOW_LIGHT.b, 1.0 * flicker), 1.45)
	enemy.draw_colored_polygon(hot_core, Color(enemy.SWARM_GLOW_LIGHT.r, enemy.SWARM_GLOW_LIGHT.g, enemy.SWARM_GLOW_LIGHT.b, 1.0 * flicker))


static func _draw_swarm_forward_motion_fx(enemy: Node2D, origin: Vector2, size: float, pulse: float, flicker: float) -> void:
	var nose := origin + Vector2(size * 1.20, 0.0)

	enemy.draw_arc(
		nose + Vector2(size * (0.30 + pulse * 0.05), 0.0),
		size * (0.36 + pulse * 0.06),
		-0.58,
		0.58,
		18,
		Color(enemy.SWARM_GLOW_LIGHT.r, enemy.SWARM_GLOW_LIGHT.g, enemy.SWARM_GLOW_LIGHT.b, 0.28 * flicker),
		1.25
	)

	enemy.draw_arc(
		nose + Vector2(size * (0.48 + pulse * 0.06), 0.0),
		size * (0.58 + pulse * 0.04),
		-0.42,
		0.42,
		16,
		Color(enemy.swarm_core_glow_color.r, enemy.swarm_core_glow_color.g, enemy.swarm_core_glow_color.b, 0.13 * flicker),
		1.0
	)

	var slash_color := Color(enemy.SWARM_GLOW_LIGHT.r, enemy.SWARM_GLOW_LIGHT.g, enemy.SWARM_GLOW_LIGHT.b, 0.46 * flicker)

	enemy.draw_polyline(
		PackedVector2Array([
			nose + Vector2(size * 0.04, -size * 0.30),
			nose + Vector2(size * 0.42, -size * 0.10),
			nose + Vector2(size * 0.14, -size * 0.01)
		]),
		slash_color,
		1.1
	)

	enemy.draw_polyline(
		PackedVector2Array([
			nose + Vector2(size * 0.04, size * 0.30),
			nose + Vector2(size * 0.42, size * 0.10),
			nose + Vector2(size * 0.14, size * 0.01)
		]),
		slash_color,
		1.1
	)
	

static func _draw_swarm_thruster_fx(enemy: Node2D, origin: Vector2, size: float, pulse: float, flicker: float) -> void:
	var plume_len := size * (1.18 + pulse * 0.24)
	var plume_w := size * (0.20 + pulse * 0.04)

	var rear_ports := [
		origin + Vector2(-size * 0.62, -size * 0.22),
		origin + Vector2(-size * 0.72, 0.0),
		origin + Vector2(-size * 0.62, size * 0.22)
	]

	for i in range(rear_ports.size()):
		var port: Vector2 = rear_ports[i]
		var center_boost := 1.18 if i == 1 else 1.0
		var spread := plume_w * (0.86 if i == 1 else 0.72)
		var length := plume_len * center_boost

		var outer_plume := PackedVector2Array([
			port + Vector2(0.0, -spread),
			port + Vector2(-length, -spread * 0.36),
			port + Vector2(-length * 1.12, 0.0),
			port + Vector2(-length, spread * 0.36),
			port + Vector2(0.0, spread)
		])

		var inner_plume := PackedVector2Array([
			port + Vector2(-size * 0.03, -spread * 0.44),
			port + Vector2(-length * 0.68, -spread * 0.18),
			port + Vector2(-length * 0.82, 0.0),
			port + Vector2(-length * 0.68, spread * 0.18),
			port + Vector2(-size * 0.03, spread * 0.44)
		])

		var hot_core := PackedVector2Array([
			port + Vector2(-size * 0.22, -spread * 0.18),
			port + Vector2(-length * 1.42, 0.18),
			port + Vector2(-size * 0.22, spread * 0.18)
		])

		enemy.draw_colored_polygon(
			outer_plume,
			Color(SWARM_TRAIL_COLOR.r, SWARM_TRAIL_COLOR.g, SWARM_TRAIL_COLOR.b, 0.16 + pulse * 0.05)
		)

		enemy.draw_colored_polygon(
			inner_plume,
			Color(SWARM_ACCENT_AMBER.r, SWARM_ACCENT_AMBER.g, SWARM_ACCENT_AMBER.b, 0.18 + pulse * 0.08)
		)

		enemy.draw_colored_polygon(
			hot_core,
			Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.34 + pulse * 0.14)
		)

		enemy.draw_circle(
			port,
			size * 0.095,
			Color(enemy.SWARM_GLOW_LIGHT.r, enemy.SWARM_GLOW_LIGHT.g, enemy.SWARM_GLOW_LIGHT.b, 0.9 * flicker)
		)

		enemy.draw_circle(
			port + Vector2(-size * 0.04, 0.0),
			size * 0.17,
			Color(SWARM_ACCENT_AMBER.r, SWARM_ACCENT_AMBER.g, SWARM_ACCENT_AMBER.b, 0.20 * flicker)
		)

