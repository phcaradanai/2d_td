class_name EnemyHunterVisual
extends RefCounted

static func _draw_cyber_hunter(enemy: Node2D, _color: Color, size: float) -> void:
	# Hunter visual pass 4: reference-inspired crimson energy blades + stronger motion read.
	# Still purely visual; gameplay logic/hitbox/pathing remain unchanged.
	var phase: float = float(enemy.get_instance_id() % 89) * 0.083
	var pulse: float = 0.5 + sin(enemy.pulse_time * 6.2 + phase) * 0.5
	var flicker: float = clampf(0.84 + sin(enemy.pulse_time * 17.0 + phase) * 0.18, 0.68, 1.14)
	var bob_x: float = sin(enemy.pulse_time * 5.2 + phase * 0.7) * size * 0.022
	var bob_y: float = sin(enemy.pulse_time * 7.0 + phase) * size * 0.050
	var origin := Vector2(bob_x, bob_y)
	var hot_pink := Color(1.0, 0.02, 0.42, 1.0)
	var crimson := Color(0.58, 0.02, 0.18, 1.0)
	var deep_crimson := Color(0.22, 0.015, 0.065, 1.0)
	var gunmetal := Color(0.045, 0.052, 0.075, 1.0)
	var panel_dark := Color(0.085, 0.09, 0.12, 1.0)
	var cyan := Color(0.20, 0.95, 1.0, 1.0)
	var blade_red := Color(1.0, 0.20, 0.34, 1.0)
	var blade_glow := Color(1.0, 0.80, 0.90, 1.0)
	var white_hot := Color(1.0, 0.82, 0.94, 1.0)

	# Motion support effects stay behind the body.
	EnemyHunterVisual._draw_hunter_motion_fx(enemy, size, hot_pink, blade_red, pulse, flicker)
	EnemyHunterVisual._draw_hunter_afterburner_upgrade(enemy, size, Color(0.10, 0.92, 1.0, 1.0), Color(0.12, 0.42, 1.0, 1.0), pulse, flicker)
	EnemyHunterVisual._draw_hunter_motion_ribbons(enemy, size, hot_pink, blade_red, pulse, flicker)

	var glow_outline := PackedVector2Array([
		origin + Vector2(size * 1.95, 0.0),
		origin + Vector2(size * 0.56, -size * 0.54),
		origin + Vector2(-size * 1.42, -size * 1.36),
		origin + Vector2(-size * 0.50, 0.0),
		origin + Vector2(-size * 1.42, size * 1.36),
		origin + Vector2(size * 0.56, size * 0.54)
	])
	enemy.draw_colored_polygon(glow_outline, Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.055 + pulse * 0.025))

	var outer := PackedVector2Array([
		origin + Vector2(size * 1.90, 0.0),
		origin + Vector2(size * 0.46, -size * 0.50),
		origin + Vector2(-size * 1.28, -size * 1.24),
		origin + Vector2(-size * 0.38, 0.0),
		origin + Vector2(-size * 1.28, size * 1.24),
		origin + Vector2(size * 0.46, size * 0.50)
	])
	var inner_body := PackedVector2Array([
		origin + Vector2(size * 1.46, 0.0),
		origin + Vector2(size * 0.34, -size * 0.34),
		origin + Vector2(-size * 0.88, -size * 0.88),
		origin + Vector2(-size * 0.25, 0.0),
		origin + Vector2(-size * 0.88, size * 0.88),
		origin + Vector2(size * 0.34, size * 0.34)
	])

	enemy.draw_colored_polygon(outer, Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.95))
	enemy.draw_colored_polygon(inner_body, gunmetal)

	var spine_shadow := PackedVector2Array([
		origin + Vector2(size * 1.46, 0.0),
		origin + Vector2(size * 0.34, -size * 0.085),
		origin + Vector2(-size * 0.44, -size * 0.12),
		origin + Vector2(-size * 0.24, 0.0),
		origin + Vector2(-size * 0.44, size * 0.12),
		origin + Vector2(size * 0.34, size * 0.085)
	])
	enemy.draw_colored_polygon(spine_shadow, Color(0.0, 0.0, 0.0, 0.62))

	var top_wing := PackedVector2Array([
		origin + Vector2(size * 0.30, -size * 0.31),
		origin + Vector2(-size * 1.02, -size * 1.05),
		origin + Vector2(-size * 0.56, -size * 0.19),
		origin + Vector2(size * 0.24, -size * 0.12)
	])
	var bottom_wing := PackedVector2Array([
		origin + Vector2(size * 0.30, size * 0.31),
		origin + Vector2(-size * 1.02, size * 1.05),
		origin + Vector2(-size * 0.56, size * 0.19),
		origin + Vector2(size * 0.24, size * 0.12)
	])
	enemy.draw_colored_polygon(top_wing, panel_dark)
	enemy.draw_colored_polygon(bottom_wing, panel_dark)

	var top_armor := PackedVector2Array([
		origin + Vector2(size * 0.58, -size * 0.33),
		origin + Vector2(size * 0.02, -size * 0.52),
		origin + Vector2(-size * 0.48, -size * 0.31),
		origin + Vector2(-size * 0.34, -size * 0.09),
		origin + Vector2(size * 0.36, -size * 0.10)
	])
	var bottom_armor := PackedVector2Array([
		origin + Vector2(size * 0.58, size * 0.33),
		origin + Vector2(size * 0.02, size * 0.52),
		origin + Vector2(-size * 0.48, size * 0.31),
		origin + Vector2(-size * 0.34, size * 0.09),
		origin + Vector2(size * 0.36, size * 0.10)
	])
	EnemyHunterVisual._draw_hunter_plate(enemy, top_armor, crimson, hot_pink, 0.72)
	EnemyHunterVisual._draw_hunter_plate(enemy, bottom_armor, crimson, hot_pink, 0.72)

	var rear_top := PackedVector2Array([
		origin + Vector2(-size * 1.13, -size * 0.87),
		origin + Vector2(-size * 0.82, -size * 0.69),
		origin + Vector2(-size * 0.64, -size * 0.50),
		origin + Vector2(-size * 0.98, -size * 0.44),
		origin + Vector2(-size * 1.28, -size * 0.60)
	])
	var rear_bottom := PackedVector2Array([
		origin + Vector2(-size * 1.13, size * 0.87),
		origin + Vector2(-size * 0.82, size * 0.69),
		origin + Vector2(-size * 0.64, size * 0.50),
		origin + Vector2(-size * 0.98, size * 0.44),
		origin + Vector2(-size * 1.28, size * 0.60)
	])
	enemy.draw_colored_polygon(rear_top, deep_crimson)
	enemy.draw_colored_polygon(rear_bottom, deep_crimson)
	EnemyHunterVisual._draw_hunter_thruster(enemy, origin + Vector2(-size * 1.06, -size * 0.62), size * 0.13, hot_pink, flicker)
	EnemyHunterVisual._draw_hunter_thruster(enemy, origin + Vector2(-size * 1.06, size * 0.62), size * 0.13, hot_pink, flicker)

	var nose_socket := PackedVector2Array([
		origin + Vector2(size * 1.08, 0.0),
		origin + Vector2(size * 0.78, -size * 0.18),
		origin + Vector2(size * 0.54, 0.0),
		origin + Vector2(size * 0.78, size * 0.18)
	])
	enemy.draw_colored_polygon(nose_socket, Color(0.0, 0.0, 0.0, 0.72))
	enemy.draw_polyline(nose_socket + PackedVector2Array([nose_socket[0]]), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.86), 1.2)
	enemy.draw_circle(origin + Vector2(size * 0.80, 0.0), size * 0.095, Color(cyan.r, cyan.g, cyan.b, 0.22 + pulse * 0.08))
	enemy.draw_circle(origin + Vector2(size * 0.80, 0.0), size * 0.052, Color(cyan.r, cyan.g, cyan.b, 0.92))
	enemy.draw_circle(origin + Vector2(size * 0.80, 0.0), size * 0.020, Color.WHITE)

	# Reference-inspired front blades.
	EnemyHunterVisual._draw_hunter_reference_blades(enemy, origin, size, blade_red, blade_glow, pulse, flicker)

	var core_pos := origin + Vector2(-size * 0.08, 0.0)
	var core_frame := PackedVector2Array()
	for i in range(6):
		var core_angle: float = PI / 6.0 + float(i) * TAU / 6.0
		core_frame.append(core_pos + Vector2(cos(core_angle), sin(core_angle)) * size * 0.33)
	enemy.draw_colored_polygon(core_frame, Color(deep_crimson.r, deep_crimson.g, deep_crimson.b, 0.96))
	enemy.draw_polyline(core_frame + PackedVector2Array([core_frame[0]]), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.86), 1.35)
	enemy.draw_circle(core_pos, size * (0.24 + pulse * 0.025), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.20 + pulse * 0.08))
	enemy.draw_circle(core_pos, size * (0.125 + pulse * 0.010), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.95))
	enemy.draw_circle(core_pos, size * 0.050, white_hot)

	enemy.draw_line(origin + Vector2(size * 0.58, -size * 0.06), origin + Vector2(size * 0.08, -size * 0.02), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.70 * flicker), 1.0)
	enemy.draw_line(origin + Vector2(size * 0.58, size * 0.06), origin + Vector2(size * 0.08, size * 0.02), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.70 * flicker), 1.0)
	enemy.draw_line(origin + Vector2(-size * 0.74, -size * 0.66), origin + Vector2(-size * 0.48, -size * 0.28), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.54), 1.0)
	enemy.draw_line(origin + Vector2(-size * 0.74, size * 0.66), origin + Vector2(-size * 0.48, size * 0.28), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.54), 1.0)

	enemy.draw_polyline(outer + PackedVector2Array([outer[0]]), Color(0.0, 0.0, 0.0, 0.72), 4.0)
	enemy.draw_polyline(outer + PackedVector2Array([outer[0]]), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.98), 2.15)
	enemy.draw_polyline(inner_body + PackedVector2Array([inner_body[0]]), Color(hot_pink.r, hot_pink.g, hot_pink.b, 0.28), 1.0)
	EnemyHunterVisual._draw_hunter_frequency_edges(enemy, outer, size, hot_pink, blade_red, pulse, flicker)


static func _draw_hunter_plate(enemy: Node2D, points: PackedVector2Array, fill_color: Color, line_color: Color, alpha_mul: float = 1.0) -> void:
	enemy.draw_colored_polygon(points, Color(fill_color.r, fill_color.g, fill_color.b, 0.72 * alpha_mul))
	enemy.draw_polyline(points + PackedVector2Array([points[0]]), Color(0.0, 0.0, 0.0, 0.52), 2.0)
	enemy.draw_polyline(points + PackedVector2Array([points[0]]), Color(line_color.r, line_color.g, line_color.b, 0.38 * alpha_mul), 1.0)


static func _draw_hunter_thruster(enemy: Node2D, pos: Vector2, radius: float, color: Color, flicker: float) -> void:
	enemy.draw_circle(pos, radius * 2.15, Color(color.r, color.g, color.b, 0.08 * flicker))
	enemy.draw_circle(pos, radius * 1.20, Color(color.r, color.g, color.b, 0.46 * flicker))
	enemy.draw_circle(pos, radius * 0.54, Color(1.0, 0.82, 0.90, 0.98))
	for i in range(3):
		var offset_y: float = (float(i) - 1.0) * radius * 0.62
		enemy.draw_line(
			pos + Vector2(-radius * 0.72, offset_y),
			pos + Vector2(radius * 0.72, offset_y),
			Color(1.0, 0.92, 0.96, 0.82 * flicker),
			1.0
		)


static func _draw_hunter_motion_fx(enemy: Node2D, size: float, drive_color: Color, plasma_color: Color, pulse: float, flicker: float) -> void:
	# Reference-aware motion wake: stronger magenta/red streaming behind the hull.
	var trail_alpha: float = clampf(0.22 + pulse * 0.16, 0.18, 0.40) * flicker
	var blade_alpha: float = clampf(0.14 + pulse * 0.12, 0.12, 0.28) * flicker
	var trail_len: float = size * (1.16 + pulse * 0.46)
	var long_len: float = size * (1.78 + pulse * 0.62)

	var top_exhaust := PackedVector2Array([
		Vector2(-size * 1.08, -size * 0.62),
		Vector2(-size * 1.56 - trail_len, -size * 0.86),
		Vector2(-size * 1.38 - trail_len * 0.78, -size * 0.52)
	])
	var bottom_exhaust := PackedVector2Array([
		Vector2(-size * 1.08, size * 0.62),
		Vector2(-size * 1.56 - trail_len, size * 0.86),
		Vector2(-size * 1.38 - trail_len * 0.78, size * 0.52)
	])
	enemy.draw_colored_polygon(top_exhaust, Color(plasma_color.r, plasma_color.g, plasma_color.b, blade_alpha))
	enemy.draw_colored_polygon(bottom_exhaust, Color(plasma_color.r, plasma_color.g, plasma_color.b, blade_alpha))

	enemy.draw_line(Vector2(-size * 1.18, -size * 0.62), Vector2(-size * 1.18 - long_len, -size * 0.78), Color(plasma_color.r, plasma_color.g, plasma_color.b, trail_alpha), 2.1)
	enemy.draw_line(Vector2(-size * 1.18, size * 0.62), Vector2(-size * 1.18 - long_len, size * 0.78), Color(plasma_color.r, plasma_color.g, plasma_color.b, trail_alpha), 2.1)
	enemy.draw_line(Vector2(-size * 0.62, 0.0), Vector2(-size * 1.98 - trail_len * 0.70, 0.0), Color(drive_color.r, drive_color.g, drive_color.b, trail_alpha * 0.78), 1.5)
	enemy.draw_line(Vector2(-size * 0.90, -size * 0.34), Vector2(-size * 2.08 - trail_len * 0.42, -size * 0.50), Color(drive_color.r, drive_color.g, drive_color.b, trail_alpha * 0.56), 1.05)
	enemy.draw_line(Vector2(-size * 0.90, size * 0.34), Vector2(-size * 2.08 - trail_len * 0.42, size * 0.50), Color(drive_color.r, drive_color.g, drive_color.b, trail_alpha * 0.56), 1.05)


static func _draw_hunter_afterburner_upgrade(enemy: Node2D, size: float, primary: Color, secondary: Color, pulse: float, flicker: float) -> void:
	# Shorter contrasting afterburner with more depth.
	# primary = bright cyan core, secondary = electric blue outer shell.
	var jet_alpha: float = clampf(0.30 + pulse * 0.16, 0.26, 0.46) * flicker
	var core_alpha: float = clampf(0.56 + pulse * 0.20, 0.50, 0.82) * flicker
	var jet_len: float = size * (0.54 + pulse * 0.22)
	var jet_width: float = size * (0.19 + pulse * 0.028)
	var depth_shift: float = size * 0.05
	var hot_white := Color(0.92, 1.0, 1.0, 1.0)
	var nozzle_shadow := Color(0.0, 0.0, 0.0, 0.20 + pulse * 0.04)
	var centers: Array[Vector2] = [Vector2(-size * 1.16, -size * 0.62), Vector2(-size * 1.16, size * 0.62)]
	for center: Vector2 in centers:
		var sign_y: float = 1.0 if center.y >= 0.0 else -1.0

		# Shadow / underside to help the plume feel volumetric.
		var shadow_flame := PackedVector2Array([
			center + Vector2(-size * 0.02, -jet_width * 0.82 * sign_y + depth_shift * 0.25),
			center + Vector2(-jet_len * 0.72, -jet_width * 1.26 * sign_y + depth_shift * 0.42),
			center + Vector2(-jet_len * 1.10, depth_shift * 0.70),
			center + Vector2(-jet_len * 0.72, jet_width * 1.26 * sign_y + depth_shift * 0.42),
			center + Vector2(-size * 0.02, jet_width * 0.82 * sign_y + depth_shift * 0.25)
		])
		enemy.draw_colored_polygon(shadow_flame, nozzle_shadow)

		# Outer shell: electric-blue rim, shorter and broader near the nozzle.
		var outer_flame := PackedVector2Array([
			center + Vector2(size * 0.04, -jet_width * 0.96 * sign_y),
			center + Vector2(-jet_len * 0.54, -jet_width * 1.40 * sign_y),
			center + Vector2(-jet_len * 0.92, -jet_width * 0.64 * sign_y),
			center + Vector2(-jet_len * 1.16, 0.0),
			center + Vector2(-jet_len * 0.92, jet_width * 0.64 * sign_y),
			center + Vector2(-jet_len * 0.54, jet_width * 1.40 * sign_y),
			center + Vector2(size * 0.04, jet_width * 0.96 * sign_y)
		])

		# Mid shell: bright cyan bloom.
		var mid_flame := PackedVector2Array([
			center + Vector2(size * 0.02, -jet_width * 0.56 * sign_y),
			center + Vector2(-jet_len * 0.42, -jet_width * 0.78 * sign_y),
			center + Vector2(-jet_len * 0.76, -jet_width * 0.34 * sign_y),
			center + Vector2(-jet_len * 0.96, 0.0),
			center + Vector2(-jet_len * 0.76, jet_width * 0.34 * sign_y),
			center + Vector2(-jet_len * 0.42, jet_width * 0.78 * sign_y),
			center + Vector2(size * 0.02, jet_width * 0.56 * sign_y)
		])

		# Hot center spine.
		var inner_flame := PackedVector2Array([
			center + Vector2(0.0, -jet_width * 0.22 * sign_y),
			center + Vector2(-jet_len * 0.30, -jet_width * 0.24 * sign_y),
			center + Vector2(-jet_len * 0.66, -jet_width * 0.10 * sign_y),
			center + Vector2(-jet_len * 0.84, 0.0),
			center + Vector2(-jet_len * 0.66, jet_width * 0.10 * sign_y),
			center + Vector2(-jet_len * 0.30, jet_width * 0.24 * sign_y),
			center + Vector2(0.0, jet_width * 0.22 * sign_y)
		])

		enemy.draw_colored_polygon(outer_flame, Color(secondary.r, secondary.g, secondary.b, jet_alpha * 0.46))
		enemy.draw_colored_polygon(mid_flame, Color(primary.r, primary.g, primary.b, core_alpha * 0.42))
		enemy.draw_colored_polygon(inner_flame, Color(hot_white.r, hot_white.g, hot_white.b, core_alpha * 0.90))

		# Edge lines and spine highlight enhance dimensionality.
		enemy.draw_polyline(outer_flame + PackedVector2Array([outer_flame[0]]), Color(secondary.r, secondary.g, secondary.b, jet_alpha * 0.86), 0.95)
		enemy.draw_line(center, center + Vector2(-jet_len * 0.98, 0.0), Color(hot_white.r, hot_white.g, hot_white.b, core_alpha), 1.10)
		enemy.draw_line(center + Vector2(-jet_len * 0.14, -jet_width * 0.82 * sign_y), center + Vector2(-jet_len * 0.84, -jet_width * 1.02 * sign_y), Color(primary.r, primary.g, primary.b, jet_alpha * 0.72), 0.70)
		enemy.draw_line(center + Vector2(-jet_len * 0.14, jet_width * 0.82 * sign_y), center + Vector2(-jet_len * 0.84, jet_width * 1.02 * sign_y), Color(primary.r, primary.g, primary.b, jet_alpha * 0.72), 0.70)


static func _draw_hunter_motion_ribbons(enemy: Node2D, size: float, primary: Color, secondary: Color, pulse: float, flicker: float) -> void:
	# Peripheral motion streaks so the Hunter looks alive even in gallery preview.
	var alpha: float = clampf(0.10 + pulse * 0.12, 0.10, 0.24) * flicker
	var stretch: float = size * (0.18 + pulse * 0.05)
	var left_x: float = -size * (1.45 + pulse * 0.12)
	enemy.draw_arc(Vector2(-size * 0.05, 0.0), size * 1.06, -2.26, -1.30, 14, Color(primary.r, primary.g, primary.b, alpha), 1.0)
	enemy.draw_arc(Vector2(-size * 0.05, 0.0), size * 1.06, 1.30, 2.26, 14, Color(primary.r, primary.g, primary.b, alpha), 1.0)
	enemy.draw_line(Vector2(-size * 0.40, -size * 0.86), Vector2(left_x - stretch, -size * 1.10), Color(secondary.r, secondary.g, secondary.b, alpha * 0.84), 0.95)
	enemy.draw_line(Vector2(-size * 0.40, size * 0.86), Vector2(left_x - stretch, size * 1.10), Color(secondary.r, secondary.g, secondary.b, alpha * 0.84), 0.95)


static func _draw_hunter_reference_blades(enemy: Node2D, origin: Vector2, size: float, blade_color: Color, glow_color: Color, pulse: float, flicker: float) -> void:
	# Refined to match the latest reference more closely: a single forward energy sword,
	# wide near the emitter, tapering to a sharp tip, with a bright hot core and crackling edges.
	var glow_alpha: float = clampf(0.20 + pulse * 0.14, 0.18, 0.36) * flicker
	var blade_alpha: float = clampf(0.60 + pulse * 0.20, 0.54, 0.88) * flicker
	var inner_alpha: float = clampf(0.72 + pulse * 0.16, 0.68, 0.96) * flicker
	var shimmer: float = sin(enemy.pulse_time * 11.0 + size) * size * 0.018
	var blade_len: float = size * (2.58 + pulse * 0.06)
	var base_x: float = size * 0.90
	var mid_x: float = size * 1.46
	var tip_x: float = base_x + blade_len
	var base_half_w: float = size * 0.22
	var mid_half_w: float = size * 0.16
	var tip_half_w: float = size * 0.015
	var hot_white := Color(1.0, 0.95, 0.98, 1.0)

	# Blade emitter / root glow where the sword emerges from the nose.
	enemy.draw_circle(origin + Vector2(size * 0.98, 0.0), size * 0.11, Color(blade_color.r, blade_color.g, blade_color.b, glow_alpha * 0.75))
	enemy.draw_circle(origin + Vector2(size * 1.04, 0.0), size * 0.06, Color(hot_white.r, hot_white.g, hot_white.b, 0.88))

	# Outer glow shell.
	var outer_blade := PackedVector2Array([
		origin + Vector2(base_x, -base_half_w - size * 0.05 + shimmer),
		origin + Vector2(mid_x, -mid_half_w - size * 0.08 + shimmer * 1.2),
		origin + Vector2(tip_x, -tip_half_w + shimmer * 0.35),
		origin + Vector2(tip_x + size * 0.16, 0.0),
		origin + Vector2(tip_x, tip_half_w - shimmer * 0.35),
		origin + Vector2(mid_x, mid_half_w + size * 0.08 - shimmer * 1.2),
		origin + Vector2(base_x, base_half_w + size * 0.05 - shimmer)
	])
	enemy.draw_colored_polygon(outer_blade, Color(blade_color.r, blade_color.g, blade_color.b, glow_alpha * 0.34))

	# Main sword body.
	var blade_body := PackedVector2Array([
		origin + Vector2(base_x + size * 0.04, -base_half_w + shimmer * 0.8),
		origin + Vector2(mid_x, -mid_half_w + shimmer),
		origin + Vector2(tip_x, -tip_half_w + shimmer * 0.25),
		origin + Vector2(tip_x + size * 0.11, 0.0),
		origin + Vector2(tip_x, tip_half_w - shimmer * 0.25),
		origin + Vector2(mid_x, mid_half_w - shimmer),
		origin + Vector2(base_x + size * 0.04, base_half_w - shimmer * 0.8)
	])
	enemy.draw_colored_polygon(blade_body, Color(blade_color.r, blade_color.g, blade_color.b, blade_alpha * 0.28))
	enemy.draw_polyline(blade_body + PackedVector2Array([blade_body[0]]), Color(blade_color.r, blade_color.g, blade_color.b, blade_alpha), 1.65)

	# Bright inner core.
	var inner_blade := PackedVector2Array([
		origin + Vector2(base_x + size * 0.16, -base_half_w * 0.42 + shimmer * 0.55),
		origin + Vector2(mid_x + size * 0.10, -mid_half_w * 0.34 + shimmer * 0.60),
		origin + Vector2(tip_x - size * 0.02, -tip_half_w * 0.14),
		origin + Vector2(tip_x + size * 0.07, 0.0),
		origin + Vector2(tip_x - size * 0.02, tip_half_w * 0.14),
		origin + Vector2(mid_x + size * 0.10, mid_half_w * 0.34 - shimmer * 0.60),
		origin + Vector2(base_x + size * 0.16, base_half_w * 0.42 - shimmer * 0.55)
	])
	enemy.draw_colored_polygon(inner_blade, Color(hot_white.r, hot_white.g, hot_white.b, inner_alpha * 0.92))

	# Central hot line to emphasize the saber-like energy core.
	enemy.draw_line(
		origin + Vector2(base_x + size * 0.12, 0.0),
		origin + Vector2(tip_x + size * 0.08, 0.0),
		Color(hot_white.r, hot_white.g, hot_white.b, inner_alpha),
		0.95
	)

	# Energy crackle lines inside the blade, matching the reference texture.
	for i in range(4):
		var t0: float = 0.12 + float(i) * 0.18
		var t1: float = t0 + 0.12
		var center_a: Vector2 = origin + Vector2(base_x + blade_len * t0, 0.0)
		var center_b: Vector2 = origin + Vector2(base_x + blade_len * t1, 0.0)
		var amp: float = size * (0.035 + float(i) * 0.004)
		var upper_offset: Vector2 = Vector2(0.0, -amp + sin(enemy.pulse_time * 14.0 + float(i)) * size * 0.01)
		var lower_offset: Vector2 = Vector2(0.0, amp - sin(enemy.pulse_time * 13.0 + float(i) * 0.7) * size * 0.01)
		enemy.draw_line(center_a + upper_offset, center_b, Color(glow_color.r, glow_color.g, glow_color.b, blade_alpha * 0.42), 0.68)
		enemy.draw_line(center_a + lower_offset, center_b, Color(glow_color.r, glow_color.g, glow_color.b, blade_alpha * 0.34), 0.60)

	# Small blade wake so the sword feels active and cutting forward.
	enemy.draw_line(
		origin + Vector2(mid_x + size * 0.10, -mid_half_w - size * 0.03),
		origin + Vector2(tip_x - size * 0.10, -mid_half_w * 0.34),
		Color(blade_color.r, blade_color.g, blade_color.b, glow_alpha * 0.58),
		0.78
	)
	enemy.draw_line(
		origin + Vector2(mid_x + size * 0.10, mid_half_w + size * 0.03),
		origin + Vector2(tip_x - size * 0.10, mid_half_w * 0.34),
		Color(blade_color.r, blade_color.g, blade_color.b, glow_alpha * 0.58),
		0.78
	)


static func _draw_hunter_frequency_edges(enemy: Node2D, points: PackedVector2Array, size: float, primary: Color, orange: Color, pulse: float, flicker: float) -> void:
	# Short broken neon strokes around the silhouette: reads as frequency / unstable lethal field.
	if points.size() < 2:
		return
	var seg_alpha: float = clampf(0.30 + pulse * 0.28, 0.28, 0.62) * flicker
	var count: int = points.size()
	for i in range(count):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		var edge: Vector2 = b - a
		var edge_len: float = edge.length()
		if edge_len <= 0.01:
			continue
		var dir: Vector2 = edge / edge_len
		var normal := Vector2(-dir.y, dir.x)
		var stroke_count: int = 3
		for j in range(stroke_count):
			var local_t: float = (float(j) + 0.22 + pulse * 0.18) / float(stroke_count + 0.35)
			var start_dist: float = clampf(edge_len * local_t, 0.0, edge_len)
			var stroke_len: float = min(edge_len * 0.16, size * 0.22)
			var p0: Vector2 = a + dir * start_dist + normal * size * 0.025
			var p1: Vector2 = a + dir * min(start_dist + stroke_len, edge_len) + normal * size * 0.025
			var c: Color = orange if ((i + j) % 3 == 0) else primary
			enemy.draw_line(p0, p1, Color(c.r, c.g, c.b, seg_alpha * (0.70 + float(j) * 0.10)), 1.05)



static func _draw_hunter_plasma_blades(enemy: Node2D, size: float, blade_color: Color, edge_color: Color, pulse: float, flicker: float) -> void:
	# Legacy helper kept for compatibility. The hunter now uses EnemyHunterVisual._draw_hunter_reference_blades(enemy).
	var ghost_alpha: float = clampf(0.08 + pulse * 0.04, 0.08, 0.16) * flicker
	enemy.draw_line(Vector2(size * 1.12, -size * 0.20), Vector2(size * 1.70, -size * 0.36), Color(blade_color.r, blade_color.g, blade_color.b, ghost_alpha), 0.75)
	enemy.draw_line(Vector2(size * 1.12, size * 0.20), Vector2(size * 1.70, size * 0.36), Color(blade_color.r, blade_color.g, blade_color.b, ghost_alpha), 0.75)
	enemy.draw_line(Vector2(size * 1.34, 0.0), Vector2(size * 1.92, 0.0), Color(edge_color.r, edge_color.g, edge_color.b, ghost_alpha * 0.55), 0.6)


static func _draw_hunter_role_telegraph(enemy: Node2D, size: float) -> void:
	var is_locked: bool = enemy.hunter_state != enemy.HunterState.PATHING and enemy.hunter_target != null and is_instance_valid(enemy.hunter_target)
	var pulse: float = 0.5 + sin(enemy.pulse_time * 6.5) * 0.5

	# Keep the danger radius readable but subtle. The compass marker carries the main read.
	var ring_color: Color = Color(0.08, 0.92, 1.0, 0.095)
	if is_locked:
		ring_color = Color(1.0, 0.22, 0.07, 0.18 + pulse * 0.055)

	enemy.draw_arc(Vector2.ZERO, enemy.aggro_range, 0.0, TAU, 88, ring_color, 1.05, true)

	# Small close orbit ring for the single compass needle. This is intentionally near the hull,
	# not at the detection radius, so it feels like part of the Hunter design instead of UI noise.
	var orbit_radius: float = clampf(size * 1.62, 24.0, 40.0)
	var orbit_color: Color = Color(0.08, 0.92, 1.0, 0.12)
	if is_locked:
		orbit_color = Color(1.0, 0.24, 0.06, 0.18)
	enemy.draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 48, orbit_color, 0.85, true)

	if is_locked:
		EnemyHunterVisual._draw_hunter_lock_compass(enemy, size, orbit_radius)
	else:
		EnemyHunterVisual._draw_hunter_scan_compass(enemy, size, orbit_radius)



static func _draw_hunter_scan_compass(enemy: Node2D, size: float, orbit_radius: float) -> void:
	# One compact sci-fi compass needle. Use enemy.pulse_time so it also animates in gallery previews.
	var scan_angle: float = enemy.pulse_time * 2.45
	var radial: Vector2 = Vector2(cos(scan_angle), sin(scan_angle))
	var pos: Vector2 = radial * orbit_radius

	# Point outward like a scanner needle, not like a large gameplay arrow.
	EnemyHunterVisual._draw_hunter_compass_needle(enemy, pos, radial, Color(0.975, 0.79, 0.842, 0.95), size)



static func _draw_hunter_lock_compass(enemy: Node2D, size: float, orbit_radius: float) -> void:
	if enemy.hunter_target == null or not is_instance_valid(enemy.hunter_target):
		return

	var local_target: Vector2 = enemy.to_local(enemy.hunter_target.global_position)
	if local_target.length_squared() <= 1.0:
		return

	var dir: Vector2 = local_target.normalized()
	var pulse: float = 0.5 + sin(enemy.pulse_time * 9.0) * 0.5
	var pos: Vector2 = dir * orbit_radius

	# Short, subtle lock line. Do not draw a huge arrow beam through the Hunter.
	enemy.draw_line(Vector2.ZERO, dir * minf(enemy.aggro_range, orbit_radius + size * 1.35), Color(1.0, 0.20, 0.05, 0.10 + pulse * 0.08), 1.0, true)
	EnemyHunterVisual._draw_hunter_compass_needle(enemy, pos, dir, Color(1.0, 0.28, 0.05, 0.95), size * (1.0 + pulse * 0.08))



static func _draw_hunter_compass_needle(enemy: Node2D, pos: Vector2, dir: Vector2, color: Color, size: float) -> void:
	if dir.length_squared() <= 0.01:
		return

	var n: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-n.y, n.x)
	var needle_len: float = clampf(size * 0.30, 4.8, 7.8)
	var needle_width: float = clampf(size * 0.04, 1.2, 2.4)

	var tip: Vector2 = pos + n * needle_len
	var tail: Vector2 = pos - n * needle_len * 0.72
	var left: Vector2 = pos + side * needle_width
	var right: Vector2 = pos - side * needle_width
	var center_hot: Vector2 = pos + n * needle_len * 0.18

	# Soft glow diamond.
	var glow: PackedVector2Array = PackedVector2Array([
		pos + n * needle_len * 1.22,
		pos + side * needle_width * 1.75,
		pos - n * needle_len * 0.92,
		pos - side * needle_width * 1.75
	])
	enemy.draw_colored_polygon(glow, Color(color.r, color.g, color.b, color.a * 0.12))

	# Main compass needle: small diamond/arrowhead, matching the neon vector theme.
	var needle_body: PackedVector2Array = PackedVector2Array([tip, left, tail, right])
	enemy.draw_colored_polygon(needle_body, Color(color.r, color.g, color.b, color.a * 0.38))
	enemy.draw_polyline(PackedVector2Array([tip, left, tail, right, tip]), Color(color.r, color.g, color.b, color.a), 1.35, true)

	# Tiny hot core so it reads as a sensor, not a flat UI arrow.
	enemy.draw_circle(center_hot, maxf(1.5, needle_width * 0.38), Color(1.0, 1.0, 1.0, color.a * 0.85))


static func draw(enemy: Node2D) -> void:
	EnemyHunterVisual._draw_cyber_hunter(enemy, Color(1.0, 0.10, 0.40, 1.0), 16.0)
