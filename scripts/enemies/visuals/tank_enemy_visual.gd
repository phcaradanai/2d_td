const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Tank / Heavy Shell visual identity:
# - reinforced industrial drone
# - slow, heavy, armored ground unit
# - earth-armored plated shell with compact mechanical mass
# - draw-only: no particles, nodes, tweens, timers, or gameplay state changes

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	if result.size() > 0:
		result.append(result[0])
	return result


static func _ellipse_points(center: Vector2, radius: Vector2, segments: int = 22) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(8, segments)
	for i in range(safe_segments):
		var a := TAU * float(i) / float(safe_segments)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


static func _draw_poly_outline(enemy: Node2D, points: PackedVector2Array, fill: Color, outline: Color, outline_width: float = 1.0) -> void:
	enemy.draw_colored_polygon(points, fill)
	enemy.draw_polyline(_closed(points), outline, outline_width, true)


static func _earth_armor_color(base: Color, health_state: int) -> Color:
	# Heavy Shell uses earth armor, so damage tint should feel like heated/breached plating.
	var healthy := Color(base.r, base.g, base.b, base.a)
	if health_state <= 0:
		return healthy
	if health_state == 1:
		return healthy.lerp(Color(0.96, 0.58, 0.18, healthy.a), 0.24)
	return healthy.lerp(Color(1.0, 0.20, 0.08, healthy.a), 0.38)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var health_state := int(enemy.get("health_visual_state"))
	var core: Color = B.apply_health_tint(B.COLOR_NEON_TANK, health_state)
	var outline := Color(0.012, 0.012, 0.010, 0.98)
	var shell := _earth_armor_color(Color(0.250, 0.220, 0.165, 0.98), health_state)
	var plate := _earth_armor_color(Color(0.420, 0.360, 0.245, 1.0), health_state)

	var body := PackedVector2Array([
		Vector2(-size * 1.05, -size * 0.48),
		Vector2(-size * 0.64, -size * 0.76),
		Vector2(size * 0.64, -size * 0.76),
		Vector2(size * 1.05, -size * 0.48),
		Vector2(size * 0.98, size * 0.48),
		Vector2(size * 0.58, size * 0.76),
		Vector2(-size * 0.58, size * 0.76),
		Vector2(-size * 0.98, size * 0.48),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, 1.08), outline)
	enemy.draw_colored_polygon(body, shell)

	var front_plate := PackedVector2Array([
		Vector2(-size * 0.62, -size * 0.42),
		Vector2(size * 0.62, -size * 0.42),
		Vector2(size * 0.42, size * 0.18),
		Vector2(-size * 0.42, size * 0.18),
	])
	_draw_poly_outline(enemy, front_plate, plate, Color(0.035, 0.030, 0.025, 0.82), 0.90)

	enemy.draw_line(Vector2(-size * 0.88, size * 0.54), Vector2(size * 0.88, size * 0.54), Color(0.0, 0.0, 0.0, 0.62), 2.2, true)
	enemy.draw_circle(Vector2.ZERO, size * 0.30, Color(0.018, 0.024, 0.022, 1.0))
	enemy.draw_circle(Vector2.ZERO, size * 0.18, Color(core.r, core.g, core.b, 0.88))
	enemy.draw_circle(Vector2(-size * 0.045, -size * 0.050), size * 0.045, Color(0.92, 1.0, 0.95, 0.86))


static func draw(enemy: Node2D, size: float) -> void:
	var health_state := int(enemy.get("health_visual_state"))
	var core: Color = B.apply_health_tint(B.COLOR_NEON_TANK, health_state)
	var pulse_time: float = float(enemy.get("pulse_time"))
	var phase_seed: float = float(enemy.get_instance_id() % 89) * 0.041
	var pulse: float = 0.5 + sin(pulse_time * 2.15 + phase_seed) * 0.5
	var blink: float = 0.5 + sin(pulse_time * 3.40 + phase_seed) * 0.5

	var draw_size: float = size * 1.62
	var shell_dark := _earth_armor_color(Color(0.105, 0.094, 0.076, 1.0), health_state)
	var shell_base := _earth_armor_color(Color(0.250, 0.220, 0.162, 1.0), health_state)
	var shell_mid := _earth_armor_color(Color(0.380, 0.320, 0.220, 1.0), health_state)
	var shell_high := _earth_armor_color(Color(0.560, 0.470, 0.300, 1.0), health_state)
	var outline := Color(0.006, 0.007, 0.006, 0.98)
	var seam := Color(0.030, 0.026, 0.021, 0.88)
	var crack_glow := Color(core.r, core.g, core.b, 0.16 + pulse * 0.10)
	var molten_accent := Color(1.0, 0.58, 0.18, 0.22 + blink * 0.12)

	# Cheap ground shadow: Heavy Shell must feel weighty and slow.
	var shadow := _ellipse_points(Vector2(0.0, draw_size * 0.48), Vector2(draw_size * 1.16, draw_size * 0.36), 26)
	enemy.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.32))

	# Low track blocks behind body. These replace insect-like legs and make Tank read as industrial armor.
	var left_track := PackedVector2Array([
		Vector2(-draw_size * 1.00, -draw_size * 0.18),
		Vector2(-draw_size * 0.58, -draw_size * 0.34),
		Vector2(-draw_size * 0.42, draw_size * 0.58),
		Vector2(-draw_size * 0.88, draw_size * 0.58),
		Vector2(-draw_size * 1.08, draw_size * 0.28),
	])
	var right_track := PackedVector2Array([
		Vector2(draw_size * 0.58, -draw_size * 0.34),
		Vector2(draw_size * 1.00, -draw_size * 0.18),
		Vector2(draw_size * 1.08, draw_size * 0.28),
		Vector2(draw_size * 0.88, draw_size * 0.58),
		Vector2(draw_size * 0.42, draw_size * 0.58),
	])
	_draw_poly_outline(enemy, B.scale_polygon(left_track, 1.035), shell_dark, outline, 1.05)
	_draw_poly_outline(enemy, B.scale_polygon(right_track, 1.035), shell_dark, outline, 1.05)

	for i in range(3):
		var x_l := lerpf(-draw_size * 0.87, -draw_size * 0.55, float(i) / 2.0)
		var x_r := lerpf(draw_size * 0.55, draw_size * 0.87, float(i) / 2.0)
		var y := draw_size * (0.30 + 0.025 * sin(pulse_time * 2.0 + float(i)))
		enemy.draw_circle(Vector2(x_l, y), draw_size * 0.075, Color(0.020, 0.020, 0.018, 1.0))
		enemy.draw_circle(Vector2(x_l, y), draw_size * 0.035, Color(core.r, core.g, core.b, 0.20))
		enemy.draw_circle(Vector2(x_r, y), draw_size * 0.075, Color(0.020, 0.020, 0.018, 1.0))
		enemy.draw_circle(Vector2(x_r, y), draw_size * 0.035, Color(core.r, core.g, core.b, 0.20))

	# Main heavy shell: wide, squat, unmistakably armored.
	var body := PackedVector2Array([
		Vector2(-draw_size * 0.82, -draw_size * 0.55),
		Vector2(-draw_size * 0.46, -draw_size * 0.82),
		Vector2(draw_size * 0.46, -draw_size * 0.82),
		Vector2(draw_size * 0.82, -draw_size * 0.55),
		Vector2(draw_size * 0.94, draw_size * 0.22),
		Vector2(draw_size * 0.58, draw_size * 0.66),
		Vector2(-draw_size * 0.58, draw_size * 0.66),
		Vector2(-draw_size * 0.94, draw_size * 0.22),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, 1.06), outline)
	enemy.draw_colored_polygon(body, shell_base)
	enemy.draw_polyline(_closed(body), Color(core.r, core.g, core.b, 0.16), 0.78, true)

	# Thick armor plates: fewer, larger shapes for premium readability.
	var top_plate := PackedVector2Array([
		Vector2(-draw_size * 0.38, -draw_size * 0.64),
		Vector2(0.0, -draw_size * 0.76),
		Vector2(draw_size * 0.38, -draw_size * 0.64),
		Vector2(draw_size * 0.30, -draw_size * 0.32),
		Vector2(0.0, -draw_size * 0.22),
		Vector2(-draw_size * 0.30, -draw_size * 0.32),
	])
	_draw_poly_outline(enemy, top_plate, shell_high, seam, 0.95)

	var left_plate := PackedVector2Array([
		Vector2(-draw_size * 0.72, -draw_size * 0.40),
		Vector2(-draw_size * 0.38, -draw_size * 0.30),
		Vector2(-draw_size * 0.24, draw_size * 0.12),
		Vector2(-draw_size * 0.45, draw_size * 0.44),
		Vector2(-draw_size * 0.78, draw_size * 0.26),
	])
	var right_plate := PackedVector2Array([
		Vector2(draw_size * 0.38, -draw_size * 0.30),
		Vector2(draw_size * 0.72, -draw_size * 0.40),
		Vector2(draw_size * 0.78, draw_size * 0.26),
		Vector2(draw_size * 0.45, draw_size * 0.44),
		Vector2(draw_size * 0.24, draw_size * 0.12),
	])
	_draw_poly_outline(enemy, left_plate, shell_mid.darkened(0.10), seam, 0.90)
	_draw_poly_outline(enemy, right_plate, shell_mid, seam, 0.90)

	var lower_bumper := PackedVector2Array([
		Vector2(-draw_size * 0.56, draw_size * 0.34),
		Vector2(draw_size * 0.56, draw_size * 0.34),
		Vector2(draw_size * 0.42, draw_size * 0.54),
		Vector2(-draw_size * 0.42, draw_size * 0.54),
	])
	_draw_poly_outline(enemy, lower_bumper, shell_dark.lightened(0.05), Color(0.0, 0.0, 0.0, 0.70), 0.80)

	# Reinforcement seams and fractured earth/metal details.
	enemy.draw_line(Vector2(-draw_size * 0.56, -draw_size * 0.10), Vector2(-draw_size * 0.28, draw_size * 0.02), Color(0.0, 0.0, 0.0, 0.36), 1.35, true)
	enemy.draw_line(Vector2(draw_size * 0.56, -draw_size * 0.10), Vector2(draw_size * 0.28, draw_size * 0.02), Color(0.0, 0.0, 0.0, 0.36), 1.35, true)
	enemy.draw_line(Vector2(-draw_size * 0.30, -draw_size * 0.50), Vector2(-draw_size * 0.12, -draw_size * 0.30), crack_glow, 0.95, true)
	enemy.draw_line(Vector2(draw_size * 0.18, -draw_size * 0.44), Vector2(draw_size * 0.38, -draw_size * 0.26), molten_accent, 0.90, true)
	enemy.draw_line(Vector2(-draw_size * 0.64, draw_size * 0.18), Vector2(-draw_size * 0.42, draw_size * 0.30), molten_accent, 0.82, true)
	enemy.draw_line(Vector2(draw_size * 0.42, draw_size * 0.30), Vector2(draw_size * 0.64, draw_size * 0.18), molten_accent, 0.82, true)

	# Heavy reactor core: smaller than Basic's focal core, protected by armor ring.
	enemy.draw_circle(Vector2.ZERO, draw_size * (0.34 + pulse * 0.020), Color(core.r, core.g, core.b, 0.12 + pulse * 0.06))
	enemy.draw_circle(Vector2.ZERO, draw_size * 0.265, Color(0.018, 0.024, 0.022, 1.0))
	enemy.draw_arc(Vector2.ZERO, draw_size * 0.286, -0.60, 1.85, 14, Color(core.r, core.g, core.b, 0.62 + pulse * 0.16), 1.55, true)
	enemy.draw_arc(Vector2.ZERO, draw_size * 0.205, 2.35, 5.20, 13, Color(core.r, core.g, core.b, 0.36 + blink * 0.14), 1.05, true)
	enemy.draw_circle(Vector2.ZERO, draw_size * 0.112, Color(core.r, core.g, core.b, 0.92))
	enemy.draw_circle(Vector2(-draw_size * 0.038, -draw_size * 0.048), draw_size * 0.034, Color(0.92, 1.0, 0.96, 0.84))

	# Four armored rivets create weight without many tiny decorative lines.
	var rivet_alpha := 0.34 + pulse * 0.10
	for p in [
		Vector2(-draw_size * 0.62, -draw_size * 0.28),
		Vector2(draw_size * 0.62, -draw_size * 0.28),
		Vector2(-draw_size * 0.54, draw_size * 0.34),
		Vector2(draw_size * 0.54, draw_size * 0.34),
	]:
		enemy.draw_circle(p, draw_size * 0.050, Color(0.020, 0.018, 0.015, 0.94))
		enemy.draw_circle(p, draw_size * 0.023, Color(core.r, core.g, core.b, rivet_alpha))
