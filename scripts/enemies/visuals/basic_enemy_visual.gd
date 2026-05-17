const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color: Color = B.apply_health_tint(B.COLOR_NEON_BASIC, int(enemy.get("health_visual_state")))
	var body_pts := PackedVector2Array([
		Vector2(0, -size), Vector2(size * 0.7, size * 0.5), Vector2(-size * 0.7, size * 0.5)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r, color.g, color.b, 0.85))
	enemy.draw_circle(Vector2.ZERO, size * 0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	var color := B.COLOR_NEON_BASIC
	var pulse_time: float = float(enemy.get("pulse_time"))
	var phase_seed: float = float(enemy.get_instance_id() % 97) * 0.037
	var pulse: float = 0.5 + sin(pulse_time * 4.0 + phase_seed) * 0.5
	var blink: float = 0.5 + sin(pulse_time * 7.5 + phase_seed) * 0.5
	var freq_a: float = 0.5 + sin(pulse_time * 11.0 + phase_seed) * 0.5
	var freq_b: float = 0.5 + sin(pulse_time * 13.0 + phase_seed + 0.8) * 0.5
	var freq_c: float = 0.5 + sin(pulse_time * 15.0 + phase_seed + 1.6) * 0.5
	var seq_speed: float = 3.2
	var seq_1: float = 0.22 + maxf(0.0, sin(pulse_time * seq_speed + phase_seed + 0.00)) * 0.78
	var seq_2: float = 0.22 + maxf(0.0, sin(pulse_time * seq_speed + phase_seed - 0.70)) * 0.78
	var seq_3: float = 0.22 + maxf(0.0, sin(pulse_time * seq_speed + phase_seed - 1.40)) * 0.78
	var seq_4: float = 0.22 + maxf(0.0, sin(pulse_time * seq_speed + phase_seed - 2.10)) * 0.78
	var seq_5: float = 0.22 + maxf(0.0, sin(pulse_time * seq_speed + phase_seed - 2.80)) * 0.78

	var spd: float = float(enemy.get("speed"))
	var base_spd: float = float(enemy.get("base_speed"))
	var move_factor: float = clampf(abs(spd) / maxf(base_spd, 1.0), 0.0, 1.35)

	var is_gallery: bool = bool(enemy.get("is_gallery_preview"))
	var stride_pixels: float = maxf(size * 2.35, 1.0)
	var gait_phase: float
	if is_gallery:
		gait_phase = pulse_time * 1.15 + phase_seed
		move_factor = 0.75
	else:
		gait_phase = float(enemy.call("get_path_progress")) / stride_pixels + phase_seed

	var t_a: float = fposmod(gait_phase, 1.0)
	var t_b: float = fposmod(gait_phase + 0.5, 1.0)
	var stride: float = size * 0.28
	var stance_ratio: float = 0.72

	var a_x: float; var a_lift: float
	if t_a < stance_ratio:
		a_x = lerpf(stride * 0.48, -stride * 0.48, t_a / stance_ratio); a_lift = 0.0
	else:
		var q: float = (t_a - stance_ratio) / (1.0 - stance_ratio)
		a_x = lerpf(-stride * 0.48, stride * 0.48, q); a_lift = sin(q * PI) * size * 0.07

	var b_x: float; var b_lift: float
	if t_b < stance_ratio:
		b_x = lerpf(stride * 0.48, -stride * 0.48, t_b / stance_ratio); b_lift = 0.0
	else:
		var q: float = (t_b - stance_ratio) / (1.0 - stance_ratio)
		b_x = lerpf(-stride * 0.48, stride * 0.48, q); b_lift = sin(q * PI) * size * 0.07

	a_x *= move_factor; b_x *= move_factor; a_lift *= move_factor; b_lift *= move_factor

	var center := Vector2.ZERO
	var draw_scale: float = 1.48
	size *= draw_scale

	var shell_body  := Color(0.145, 0.152, 0.168, 1.0)
	var shell_mid   := Color(0.285, 0.300, 0.334, 1.0)
	var shell_high  := Color(0.385, 0.398, 0.432, 1.0)
	var steel_shadow := Color(0.050, 0.056, 0.070, 0.96)
	var steel_rim    := Color(0.54,  0.58,  0.64,  0.78)
	var accent       := Color(1.0,   0.62,  0.18,  1.0)
	var accent_soft  := Color(accent.r, accent.g, accent.b, 0.46 + blink * 0.16)
	var accent_hot   := Color(accent.r, accent.g, accent.b, 1.0)

	var body_shadow: PackedVector2Array = B.ellipse_points(Vector2(0.0, size * 0.28), size * 1.30, size * 0.78, 36, 0.0)
	enemy.draw_colored_polygon(body_shadow, Color(0.0, 0.0, 0.0, 0.28))

	var rth := center + Vector2(-size * 0.58, -size * 0.42)
	var fth := center + Vector2( size * 0.58, -size * 0.42)
	var rbh := center + Vector2(-size * 0.58,  size * 0.42)
	var fbh := center + Vector2( size * 0.58,  size * 0.42)
	var rtk := Vector2(-size * 0.98 + b_x * 0.55, -size * 0.78 + b_lift)
	var rtf := Vector2(-size * 1.22 + b_x,         -size * 0.82 + b_lift * 0.45)
	var ftk := Vector2( size * 0.98 + a_x * 0.55, -size * 0.78 + a_lift)
	var ftf := Vector2( size * 1.22 + a_x,         -size * 0.82 + a_lift * 0.45)
	var rbk := Vector2(-size * 0.98 + a_x * 0.55,  size * 0.78 - a_lift)
	var rbf := Vector2(-size * 1.22 + a_x,          size * 0.82 - a_lift * 0.45)
	var fbk := Vector2( size * 0.98 + b_x * 0.55,  size * 0.78 - b_lift)
	var fbf := Vector2( size * 1.22 + b_x,          size * 0.82 - b_lift * 0.45)

	B.draw_basic_segmented_leg(enemy, rth, rtk, rtf, shell_mid.darkened(0.12), color, 2.85, 2.7, pulse)
	B.draw_basic_segmented_leg(enemy, fth, ftk, ftf, shell_mid.darkened(0.10), color, 2.85, 2.7, blink)

	var body: PackedVector2Array = B.ellipse_points(center, size * 1.04, size * 0.70, 42, -0.05)
	enemy.draw_colored_polygon(body, shell_body)
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size*0.98,-size*0.04), center+Vector2(-size*0.30,-size*0.46),
		center + Vector2( size*0.10,-size*0.10), center+Vector2(-size*0.12, size*0.46),
		center + Vector2(-size*0.86, size*0.28)]), Color(0.03,0.04,0.05,0.36))
	enemy.draw_polyline(body + PackedVector2Array([body[0]]), Color(steel_shadow.r,steel_shadow.g,steel_shadow.b,0.82), 1.65, true)
	enemy.draw_polyline(body + PackedVector2Array([body[0]]), Color(steel_rim.r,steel_rim.g,steel_rim.b,0.28), 0.46, true)

	var top_panel := PackedVector2Array([
		center+Vector2(-size*0.48,-size*0.38), center+Vector2(0.0,-size*0.52),
		center+Vector2( size*0.48,-size*0.38), center+Vector2(size*0.30,-size*0.04),
		center+Vector2(-size*0.30,-size*0.04)])
	enemy.draw_colored_polygon(top_panel, shell_mid)
	enemy.draw_polyline(top_panel+PackedVector2Array([top_panel[0]]), steel_shadow, 0.96, true)
	enemy.draw_polyline(top_panel+PackedVector2Array([top_panel[0]]), Color(steel_rim.r,steel_rim.g,steel_rim.b,0.62), 0.46, true)
	enemy.draw_polyline(top_panel+PackedVector2Array([top_panel[0]]), Color(color.r,color.g,color.b,0.14+seq_1*0.26), 0.62, true)
	B.draw_sequential_outline(enemy, top_panel, pulse_time*0.42+phase_seed*0.11+0.05, 0.15, Color(color.r,color.g,color.b,0.60), 0.34, true)

	var left_panel := PackedVector2Array([
		center+Vector2(-size*0.78,-size*0.10), center+Vector2(-size*0.48,-size*0.30),
		center+Vector2(-size*0.22,-size*0.08), center+Vector2(-size*0.34, size*0.22),
		center+Vector2(-size*0.70, size*0.18)])
	enemy.draw_colored_polygon(left_panel, Color(0.100,0.115,0.148,1.0))
	enemy.draw_polyline(left_panel+PackedVector2Array([left_panel[0]]), steel_shadow, 0.92, true)
	enemy.draw_polyline(left_panel+PackedVector2Array([left_panel[0]]), Color(color.r,color.g,color.b,0.12+seq_2*0.26), 0.56, true)
	B.draw_sequential_outline(enemy, left_panel, pulse_time*0.42+phase_seed*0.11+0.24, 0.14, Color(color.r,color.g,color.b,0.58), 0.32, true)

	var right_panel := PackedVector2Array([
		center+Vector2( size*0.22,-size*0.08), center+Vector2(size*0.48,-size*0.30),
		center+Vector2( size*0.78,-size*0.10), center+Vector2(size*0.70, size*0.18),
		center+Vector2( size*0.34, size*0.22)])
	enemy.draw_colored_polygon(right_panel, Color(0.160,0.176,0.212,1.0))
	enemy.draw_polyline(right_panel+PackedVector2Array([right_panel[0]]), steel_shadow, 0.92, true)
	enemy.draw_polyline(right_panel+PackedVector2Array([right_panel[0]]), Color(accent.r,accent.g,accent.b,0.12+seq_3*0.26), 0.56, true)
	B.draw_sequential_outline(enemy, right_panel, pulse_time*0.42+phase_seed*0.11+0.42, 0.14, Color(accent.r,accent.g,accent.b,0.58), 0.32, true)

	var rear_hatch := PackedVector2Array([
		center+Vector2(-size*0.22,-size*0.44), center+Vector2(size*0.22,-size*0.44),
		center+Vector2( size*0.14,-size*0.24), center+Vector2(-size*0.14,-size*0.24)])
	enemy.draw_colored_polygon(rear_hatch, shell_high)
	enemy.draw_polyline(rear_hatch+PackedVector2Array([rear_hatch[0]]), Color(color.r,color.g,color.b,0.10+seq_4*0.22), 0.50, true)
	B.draw_sequential_outline(enemy, rear_hatch, pulse_time*0.42+phase_seed*0.11+0.60, 0.12, Color(color.r,color.g,color.b,0.52), 0.28, true)

	var lower_lip := PackedVector2Array([
		center+Vector2(-size*0.42,size*0.38), center+Vector2(size*0.42,size*0.38),
		center+Vector2( size*0.26,size*0.50), center+Vector2(-size*0.26,size*0.50)])
	enemy.draw_colored_polygon(lower_lip, Color(0.070,0.080,0.108,1.0))
	enemy.draw_polyline(lower_lip+PackedVector2Array([lower_lip[0]]), Color(accent.r,accent.g,accent.b,0.10+seq_5*0.22), 0.52, true)
	B.draw_sequential_outline(enemy, lower_lip, pulse_time*0.42+phase_seed*0.11+0.78, 0.12, Color(accent.r,accent.g,accent.b,0.52), 0.28, true)

	# Sym light cuts
	enemy.draw_line(center+Vector2(-size*0.52,-size*0.18), center+Vector2(-size*0.12,-size*0.18), Color(color.r,color.g,color.b,0.14+seq_1*0.30), 0.92, true)
	enemy.draw_line(center+Vector2( size*0.12,-size*0.18), center+Vector2( size*0.52,-size*0.18), Color(accent.r,accent.g,accent.b,0.14+seq_1*0.28), 0.92, true)

	var core_pos := center + Vector2(-size * 0.18, -size * 0.06)
	enemy.draw_circle(core_pos, size*(0.40+pulse*0.030), Color(color.r,color.g,color.b,0.20+pulse*0.12))
	enemy.draw_circle(core_pos, size*0.245, Color(0.050,0.068,0.090,1.0))
	enemy.draw_arc(core_pos, size*0.255, 0.10, 1.40, 8, Color(color.r,color.g,color.b,0.76+freq_a*0.22), 1.70, true)
	enemy.draw_arc(core_pos, size*0.255, 1.85, 3.15, 8, Color(color.r,color.g,color.b,0.58+freq_b*0.22), 1.60, true)
	enemy.draw_arc(core_pos, size*0.255, 3.55, 5.15, 9, Color(color.r,color.g,color.b,0.82+freq_c*0.18), 1.70, true)
	enemy.draw_arc(core_pos, size*0.175, 0.0, TAU, 20, Color(color.r,color.g,color.b,0.38+blink*0.22), 1.15, true)
	enemy.draw_circle(core_pos, size*0.108, Color(color.r,color.g,color.b,0.96+pulse*0.04))
	enemy.draw_circle(core_pos, size*0.035, Color(0.86,1.0,1.0,0.90))
	enemy.draw_circle(core_pos, size*0.52, Color(color.r,color.g,color.b,0.09+pulse*0.05))

	B.draw_basic_segmented_leg(enemy, rbh, rbk, rbf, Color(0.260,0.290,0.345,1.0), color, 3.8, 3.4, blink)
	B.draw_basic_segmented_leg(enemy, fbh, fbk, fbf, Color(0.260,0.290,0.345,1.0), color, 3.8, 3.4, pulse)
