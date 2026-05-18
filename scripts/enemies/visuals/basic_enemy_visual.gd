const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Basic / Corrupted Node visual identity:
# - baseline corrupted digital virus node
# - earth-armored ground unit with compact stable movement
# - readable dark shell, fractured stone-metal plates, cyan infected core
# - draw-only: no particles, nodes, tweens, timers, or gameplay state changes

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	if result.size() > 0:
		result.append(result[0])
	return result

static func _draw_poly_outline(enemy: Node2D, points: PackedVector2Array, fill: Color, outline: Color, outline_width: float = 1.0) -> void:
	enemy.draw_colored_polygon(points, fill)
	enemy.draw_polyline(_closed(points), outline, outline_width, true)

static func _earth_color(base: Color, health_state: int) -> Color:
	# Earth armor should stay warm/grounded while the infected core remains cyan.
	var healthy := Color(base.r, base.g, base.b, base.a)
	if health_state <= 0:
		return healthy
	if health_state == 1:
		return healthy.lerp(Color(0.98, 0.56, 0.18, healthy.a), 0.28)
	return healthy.lerp(Color(1.0, 0.18, 0.08, healthy.a), 0.42)

static func draw_simple(enemy: Node2D, size: float) -> void:
	var health_state := int(enemy.get("health_visual_state"))
	var core: Color = B.apply_health_tint(B.COLOR_NEON_BASIC, health_state)
	var rim := Color(0.018, 0.020, 0.018, 0.96)
	var shell := _earth_color(Color(0.260, 0.245, 0.195, 0.96), health_state)
	var plate := _earth_color(Color(0.365, 0.335, 0.250, 0.98), health_state)

	var body := PackedVector2Array([
		Vector2(0.0, -size * 0.84),
		Vector2(size * 0.58, -size * 0.55),
		Vector2(size * 0.88, -size * 0.08),
		Vector2(size * 0.66, size * 0.52),
		Vector2(size * 0.24, size * 0.78),
		Vector2(-size * 0.24, size * 0.78),
		Vector2(-size * 0.66, size * 0.52),
		Vector2(-size * 0.88, -size * 0.08),
		Vector2(-size * 0.58, -size * 0.55),
	])

	enemy.draw_colored_polygon(B.scale_polygon(body, 1.10), rim)
	enemy.draw_colored_polygon(body, shell)
	enemy.draw_polyline(_closed(body), Color(core.r, core.g, core.b, 0.32), 0.85, true)

	var top_plate := PackedVector2Array([
		Vector2(-size * 0.34, -size * 0.48),
		Vector2(size * 0.28, -size * 0.48),
		Vector2(size * 0.48, -size * 0.14),
		Vector2(0.0, size * 0.03),
		Vector2(-size * 0.50, -size * 0.12),
	])
	enemy.draw_colored_polygon(top_plate, plate)

	enemy.draw_circle(Vector2.ZERO, size * 0.34, Color(0.020, 0.030, 0.028, 1.0))
	enemy.draw_circle(Vector2.ZERO, size * 0.22, Color(core.r, core.g, core.b, 0.90))
	enemy.draw_circle(Vector2(-size * 0.055, -size * 0.055), size * 0.055, Color(0.86, 1.0, 1.0, 0.88))

static func draw(enemy: Node2D, size: float) -> void:
	var health_state := int(enemy.get("health_visual_state"))
	var core: Color = B.apply_health_tint(B.COLOR_NEON_BASIC, health_state)
	var pulse_time: float = float(enemy.get("pulse_time"))
	var phase_seed: float = float(enemy.get_instance_id() % 97) * 0.037
	var pulse: float = 0.5 + sin(pulse_time * 3.4 + phase_seed) * 0.5
	var blink: float = 0.5 + sin(pulse_time * 5.8 + phase_seed) * 0.5

	var spd: float = float(enemy.get("speed"))
	var base_spd: float = float(enemy.get("base_speed"))
	var move_factor: float = clampf(abs(spd) / maxf(base_spd, 1.0), 0.0, 1.20)

	var is_gallery: bool = bool(enemy.get("is_gallery_preview"))
	var draw_size: float = size * 1.42
	var stride_pixels: float = maxf(draw_size * 2.60, 1.0)
	var gait_phase: float
	if is_gallery:
		gait_phase = pulse_time * 0.90 + phase_seed
		move_factor = 0.62
	else:
		gait_phase = float(enemy.call("get_path_progress")) / stride_pixels + phase_seed

	var t_a: float = fposmod(gait_phase, 1.0)
	var t_b: float = fposmod(gait_phase + 0.5, 1.0)
	var stride: float = draw_size * 0.22
	var stance_ratio: float = 0.74

	var a_x: float
	var a_lift: float
	if t_a < stance_ratio:
		a_x = lerpf(stride * 0.42, -stride * 0.42, t_a / stance_ratio)
		a_lift = 0.0
	else:
		var q_a: float = (t_a - stance_ratio) / (1.0 - stance_ratio)
		a_x = lerpf(-stride * 0.42, stride * 0.42, q_a)
		a_lift = sin(q_a * PI) * draw_size * 0.045

	var b_x: float
	var b_lift: float
	if t_b < stance_ratio:
		b_x = lerpf(stride * 0.42, -stride * 0.42, t_b / stance_ratio)
		b_lift = 0.0
	else:
		var q_b: float = (t_b - stance_ratio) / (1.0 - stance_ratio)
		b_x = lerpf(-stride * 0.42, stride * 0.42, q_b)
		b_lift = sin(q_b * PI) * draw_size * 0.045

	a_x *= move_factor
	b_x *= move_factor
	a_lift *= move_factor
	b_lift *= move_factor

	var shell_dark := _earth_color(Color(0.115, 0.108, 0.088, 1.0), health_state)
	var shell_base := _earth_color(Color(0.245, 0.228, 0.176, 1.0), health_state)
	var shell_mid := _earth_color(Color(0.370, 0.335, 0.245, 1.0), health_state)
	var shell_high := _earth_color(Color(0.500, 0.445, 0.310, 1.0), health_state)
	var crack_glow := Color(core.r, core.g, core.b, 0.22 + pulse * 0.14)
	var outline := Color(0.010, 0.012, 0.012, 0.96)
	var dust_accent := Color(0.95, 0.62, 0.24, 0.38 + blink * 0.16)

	# Grounded contact shadow: cheap, stable, and reinforces ground movement.
	var shadow := B.ellipse_points(Vector2(0.0, draw_size * 0.34), draw_size * 1.10, draw_size * 0.50, 28, 0.0)
	enemy.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.24))

	# Mechanical legs: subdued so Basic stays readable and baseline.
	var rear_left_hip := Vector2(-draw_size * 0.52, -draw_size * 0.32)
	var front_left_hip := Vector2(draw_size * 0.52, -draw_size * 0.32)
	var rear_right_hip := Vector2(-draw_size * 0.52, draw_size * 0.34)
	var front_right_hip := Vector2(draw_size * 0.52, draw_size * 0.34)

	B.draw_basic_segmented_leg(
		enemy,
		rear_left_hip,
		Vector2(-draw_size * 0.82 + b_x * 0.45, -draw_size * 0.56 + b_lift),
		Vector2(-draw_size * 1.02 + b_x, -draw_size * 0.58 + b_lift * 0.35),
		shell_mid.darkened(0.16),
		core,
		2.35,
		2.25,
		pulse
	)
	B.draw_basic_segmented_leg(
		enemy,
		front_left_hip,
		Vector2(draw_size * 0.82 + a_x * 0.45, -draw_size * 0.56 + a_lift),
		Vector2(draw_size * 1.02 + a_x, -draw_size * 0.58 + a_lift * 0.35),
		shell_mid.darkened(0.13),
		core,
		2.35,
		2.25,
		blink
	)

	# Main corrupted node shell: earth armor, compact and predictable.
	var body := PackedVector2Array([
		Vector2(0.0, -draw_size * 0.78),
		Vector2(draw_size * 0.50, -draw_size * 0.60),
		Vector2(draw_size * 0.84, -draw_size * 0.20),
		Vector2(draw_size * 0.74, draw_size * 0.34),
		Vector2(draw_size * 0.34, draw_size * 0.66),
		Vector2(-draw_size * 0.34, draw_size * 0.66),
		Vector2(-draw_size * 0.74, draw_size * 0.34),
		Vector2(-draw_size * 0.84, -draw_size * 0.20),
		Vector2(-draw_size * 0.50, -draw_size * 0.60),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, 1.055), outline)
	enemy.draw_colored_polygon(body, shell_base)
	enemy.draw_polyline(_closed(body), Color(core.r, core.g, core.b, 0.22), 0.70, true)

	# Larger armor plates: fewer shapes, stronger premium readability.
	var crown := PackedVector2Array([
		Vector2(-draw_size * 0.34, -draw_size * 0.52),
		Vector2(0.0, -draw_size * 0.64),
		Vector2(draw_size * 0.34, -draw_size * 0.52),
		Vector2(draw_size * 0.24, -draw_size * 0.23),
		Vector2(0.0, -draw_size * 0.12),
		Vector2(-draw_size * 0.24, -draw_size * 0.23),
	])
	_draw_poly_outline(enemy, crown, shell_high, Color(0.035, 0.035, 0.030, 0.72), 0.90)

	var left_plate := PackedVector2Array([
		Vector2(-draw_size * 0.68, -draw_size * 0.15),
		Vector2(-draw_size * 0.32, -draw_size * 0.28),
		Vector2(-draw_size * 0.12, -draw_size * 0.04),
		Vector2(-draw_size * 0.27, draw_size * 0.30),
		Vector2(-draw_size * 0.61, draw_size * 0.24),
	])
	_draw_poly_outline(enemy, left_plate, shell_dark.lightened(0.07), Color(0.025, 0.025, 0.022, 0.72), 0.78)

	var right_plate := PackedVector2Array([
		Vector2(draw_size * 0.12, -draw_size * 0.04),
		Vector2(draw_size * 0.32, -draw_size * 0.28),
		Vector2(draw_size * 0.68, -draw_size * 0.15),
		Vector2(draw_size * 0.61, draw_size * 0.24),
		Vector2(draw_size * 0.27, draw_size * 0.30),
	])
	_draw_poly_outline(enemy, right_plate, shell_mid, Color(0.025, 0.025, 0.022, 0.72), 0.78)

	var lower_plate := PackedVector2Array([
		Vector2(-draw_size * 0.30, draw_size * 0.35),
		Vector2(draw_size * 0.30, draw_size * 0.35),
		Vector2(draw_size * 0.18, draw_size * 0.52),
		Vector2(-draw_size * 0.18, draw_size * 0.52),
	])
	_draw_poly_outline(enemy, lower_plate, Color(0.078, 0.074, 0.064, 1.0), Color(0.0, 0.0, 0.0, 0.70), 0.68)

	# Corruption cracks: small amount only, communicates "digital virus node" without visual spam.
	enemy.draw_line(Vector2(-draw_size * 0.28, -draw_size * 0.39), Vector2(-draw_size * 0.08, -draw_size * 0.20), crack_glow, 0.88, true)
	enemy.draw_line(Vector2(draw_size * 0.18, -draw_size * 0.28), Vector2(draw_size * 0.38, -draw_size * 0.07), Color(core.r, core.g, core.b, 0.18 + blink * 0.10), 0.78, true)
	enemy.draw_line(Vector2(-draw_size * 0.48, draw_size * 0.03), Vector2(-draw_size * 0.26, draw_size * 0.15), dust_accent, 0.72, true)
	enemy.draw_line(Vector2(draw_size * 0.26, draw_size * 0.15), Vector2(draw_size * 0.48, draw_size * 0.03), dust_accent, 0.72, true)

	# Infected core: central identity, controlled draw count.
	var core_pos := Vector2.ZERO
	enemy.draw_circle(core_pos, draw_size * (0.37 + pulse * 0.025), Color(core.r, core.g, core.b, 0.15 + pulse * 0.08))
	enemy.draw_circle(core_pos, draw_size * 0.255, Color(0.018, 0.030, 0.032, 1.0))
	enemy.draw_arc(core_pos, draw_size * 0.272, -0.40, 2.25, 14, Color(core.r, core.g, core.b, 0.66 + pulse * 0.18), 1.45, true)
	enemy.draw_arc(core_pos, draw_size * 0.190, 2.90, 5.90, 14, Color(core.r, core.g, core.b, 0.42 + blink * 0.16), 1.00, true)
	enemy.draw_circle(core_pos, draw_size * 0.116, Color(core.r, core.g, core.b, 0.95))
	enemy.draw_circle(core_pos + Vector2(-draw_size * 0.038, -draw_size * 0.050), draw_size * 0.036, Color(0.88, 1.0, 1.0, 0.88))

	# Front legs last so lower pair feels grounded over the shell edge.
	B.draw_basic_segmented_leg(
		enemy,
		rear_right_hip,
		Vector2(-draw_size * 0.80 + a_x * 0.45, draw_size * 0.58 - a_lift),
		Vector2(-draw_size * 1.00 + a_x, draw_size * 0.60 - a_lift * 0.35),
		shell_mid.darkened(0.08),
		core,
		2.90,
		2.65,
		blink
	)
	B.draw_basic_segmented_leg(
		enemy,
		front_right_hip,
		Vector2(draw_size * 0.80 + b_x * 0.45, draw_size * 0.58 - b_lift),
		Vector2(draw_size * 1.00 + b_x, draw_size * 0.60 - b_lift * 0.35),
		shell_mid.darkened(0.06),
		core,
		2.90,
		2.65,
		pulse
	)
