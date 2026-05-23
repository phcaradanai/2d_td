class_name EnemyVisualRenderer
extends RefCounted

static func draw_enemy(enemy: Node2D) -> void:
	if enemy._body_baked:
		# Body is a Sprite2D — only draw dynamic overlays (0-3 calls vs 15-20).
		const SIZE := 16.0
		if enemy.shield_remaining > 0:
			enemy.draw_arc(Vector2.ZERO, SIZE * 1.4, 0, TAU, 12, Color(0.4, 0.8, 1.0, 0.22), 1.5)
		if enemy.active_slow_percent > 0:
			enemy.draw_circle(Vector2.ZERO, SIZE * 1.2, Color(0.6, 0.9, 1.0, 0.16))
		if enemy.is_flashing and enemy.hit_flash_alpha > 0.01:
			enemy.draw_circle(Vector2.ZERO, SIZE * 1.35,
				Color(enemy.hit_flash_color.r, enemy.hit_flash_color.g, enemy.hit_flash_color.b, enemy.hit_flash_alpha))
		return
	# Pre-bake: skip the 50+ draw-call procedural renderer for gameplay enemies.
	# The baked-sprite pop-in animation handles the visual transition seamlessly.
	# Preserve procedural visual only for gallery/catalog preview contexts.
	var is_preview: bool = enemy.is_gallery_preview or bool(enemy.get_meta("catalog_preview_mode", false))
	if not is_preview:
		return
	if enemy.visual_type == "hunter":
		EnemyHunterVisual.draw(enemy)
		return
	enemy.ENEMY_VISUAL_ROUTER.draw_enemy(enemy)

# --- Performance Silhouette Mode ---


static func _draw_simple_silhouette(enemy: Node2D, size: float) -> void:
	var color: Color
	var body_pts: PackedVector2Array
	match enemy.visual_type:
		"basic":
			color = enemy.COLOR_NEON_BASIC
			body_pts = PackedVector2Array([Vector2(0, -size), Vector2(size * 0.7, size * 0.5), Vector2(-size * 0.7, size * 0.5)])
		"fast", "runner":
			color = enemy.COLOR_NEON_FAST if enemy.visual_type == "fast" else Color(1.0, 0.35, 0.05)
			body_pts = PackedVector2Array([Vector2(0, -size * 1.1), Vector2(size * 0.5, size * 0.4), Vector2(0, size * 0.2), Vector2(-size * 0.5, size * 0.4)])
		"tank":
			color = EnemyDrawUtils._apply_health_tint(enemy, enemy.COLOR_NEON_TANK)
			var tank_rect := Rect2(Vector2(-size * 0.9, -size * 0.7), Vector2(size * 1.8, size * 1.4))
			enemy.draw_rect(tank_rect.grow(enemy.ENEMY_OUTLINE_THICKNESS), enemy.ENEMY_OUTLINE_COLOR)
			enemy.draw_rect(tank_rect, Color(color.r, color.g, color.b, 0.9))
			enemy.draw_circle(Vector2.ZERO, size * 0.35, Color.WHITE)
			return
		"bulwark", "shieldbearer":
			color = enemy.COLOR_NEON_BULWARK if enemy.visual_type == "bulwark" else Color(0.3, 0.8, 1.0)
			body_pts = PackedVector2Array()
			for j in 6:
				var a := j * TAU / 6.0 - PI / 6.0
				body_pts.append(Vector2(cos(a), sin(a)) * size * 1.2)
		"hunter":
			color = enemy.COLOR_NEON_HUNTER
			body_pts = PackedVector2Array([Vector2(0, -size * 1.2), Vector2(size * 0.6, size * 0.6), Vector2(0, size * 0.2), Vector2(-size * 0.6, size * 0.6)])
		"swarm":
			color = EnemyDrawUtils._apply_health_tint(enemy, enemy.COLOR_NEON_FAST)
			enemy.draw_circle(Vector2(-size * 0.5, -size * 0.3), size * 0.4 + enemy.ENEMY_OUTLINE_THICKNESS, enemy.ENEMY_OUTLINE_COLOR)
			enemy.draw_circle(Vector2(size * 0.5, -size * 0.3), size * 0.4 + enemy.ENEMY_OUTLINE_THICKNESS, enemy.ENEMY_OUTLINE_COLOR)
			enemy.draw_circle(Vector2(0, size * 0.4), size * 0.4 + enemy.ENEMY_OUTLINE_THICKNESS, enemy.ENEMY_OUTLINE_COLOR)
			enemy.draw_circle(Vector2(-size * 0.5, -size * 0.3), size * 0.4, Color(color.r, color.g, color.b, 0.8))
			enemy.draw_circle(Vector2(size * 0.5, -size * 0.3), size * 0.4, Color(color.r, color.g, color.b, 0.8))
			enemy.draw_circle(Vector2(0, size * 0.4), size * 0.4, Color(color.r, color.g, color.b, 0.8))
			return
		"healer":
			color = Color(0.4, 1.0, 0.4)
			body_pts = PackedVector2Array([Vector2(0, -size), Vector2(size * 0.7, size * 0.5), Vector2(-size * 0.7, size * 0.5)])
		"splitter":
			color = Color(0.8, 0.4, 1.0)
			body_pts = PackedVector2Array([Vector2(0, -size * 1.1), Vector2(size * 0.8, size * 0.5), Vector2(0, 0), Vector2(-size * 0.8, size * 0.5)])
		"cloaked":
			color = Color(0.7, 0.7, 1.0, 0.6)
			body_pts = PackedVector2Array([Vector2(0, -size), Vector2(size * 0.7, size * 0.5), Vector2(-size * 0.7, size * 0.5)])
		"flyer", "fast_flyer", "armored_flyer":
			if enemy.visual_type == "flyer":
				color = enemy.COLOR_NEON_BULWARK
			elif enemy.visual_type == "fast_flyer":
				color = enemy.COLOR_NEON_FAST
			else:
				color = enemy.COLOR_NEON_TANK
			body_pts = PackedVector2Array([Vector2(0, -size * 0.9), Vector2(size * 0.9, 0), Vector2(0, size * 0.9), Vector2(-size * 0.9, 0)])
		"disruptor":
			color = Color(0.6, 0.3, 1.0)
			body_pts = PackedVector2Array([Vector2(0, -size * 1.1), Vector2(size * 0.7, size * 0.5), Vector2(0, size * 0.2), Vector2(-size * 0.7, size * 0.5)])
		_:
			color = Color(0.8, 0.8, 0.8)
			body_pts = PackedVector2Array([Vector2(0, -size), Vector2(size * 0.7, size * 0.5), Vector2(-size * 0.7, size * 0.5)])
	if body_pts.size() > 0:
		color = EnemyDrawUtils._apply_health_tint(enemy, color)
		enemy.draw_colored_polygon(EnemyDrawUtils._scale_polygon(body_pts, enemy.ENEMY_OUTLINE_THICKNESS), enemy.ENEMY_OUTLINE_COLOR)
		enemy.draw_colored_polygon(body_pts, Color(color.r, color.g, color.b, 0.85))
	enemy.draw_circle(Vector2.ZERO, size * 0.3, Color.WHITE)


static func _draw_cyber_node(enemy: Node2D, color: Color, size: float) -> void:
	# BASIC / Circuit Grunt refine pass 8
	# Added polish:
	# - extra layered texture / panel detail
	# - contrasting accent color (amber/orange) for more depth
	# - neon frequency-like scan lines and segmented glow blink
	# - preserves grounded top-down crawl from v7

	# Slight upscale so the enemy reads better in gameplay and shows more detail.
	var draw_scale: float = 1.48
	size *= draw_scale

	var phase_seed: float = float(enemy.get_instance_id() % 97) * 0.037
	var pulse: float = 0.5 + sin(enemy.pulse_time * 4.0 + phase_seed) * 0.5
	var blink: float = 0.5 + sin(enemy.pulse_time * 7.5 + phase_seed) * 0.5
	var freq_a: float = 0.5 + sin(enemy.pulse_time * 11.0 + phase_seed) * 0.5
	var freq_b: float = 0.5 + sin(enemy.pulse_time * 13.0 + phase_seed + 0.8) * 0.5
	var freq_c: float = 0.5 + sin(enemy.pulse_time * 15.0 + phase_seed + 1.6) * 0.5

	# Sequential light pulses for shell lines.
	# The bright overlay sits directly on top of the existing neon cuts, making the sequence more obvious.
	var seq_speed: float = 3.2
	var seq_1: float = 0.22 + maxf(0.0, sin(enemy.pulse_time * seq_speed + phase_seed + 0.00)) * 0.78
	var seq_2: float = 0.22 + maxf(0.0, sin(enemy.pulse_time * seq_speed + phase_seed - 0.70)) * 0.78
	var seq_3: float = 0.22 + maxf(0.0, sin(enemy.pulse_time * seq_speed + phase_seed - 1.40)) * 0.78
	var seq_4: float = 0.22 + maxf(0.0, sin(enemy.pulse_time * seq_speed + phase_seed - 2.10)) * 0.78
	var seq_5: float = 0.22 + maxf(0.0, sin(enemy.pulse_time * seq_speed + phase_seed - 2.80)) * 0.78

	var move_factor: float = clampf(abs(enemy.speed) / maxf(enemy.base_speed, 1.0), 0.0, 1.35)

	var stride_pixels: float = maxf(size * 2.35, 1.0)
	var gait_phase: float = enemy.get_path_progress() / stride_pixels + phase_seed
	if enemy.is_gallery_preview:
		gait_phase = enemy.pulse_time * 1.15 + phase_seed
		move_factor = 0.75

	var t_a: float = fposmod(gait_phase, 1.0)
	var t_b: float = fposmod(gait_phase + 0.5, 1.0)
	var stride: float = size * 0.28
	var stance_ratio: float = 0.72

	var a_x: float = 0.0
	var a_lift: float = 0.0
	if t_a < stance_ratio:
		var q_a_stance: float = t_a / stance_ratio
		a_x = lerpf(stride * 0.48, -stride * 0.48, q_a_stance)
		a_lift = 0.0
	else:
		var q_a_recover: float = (t_a - stance_ratio) / (1.0 - stance_ratio)
		a_x = lerpf(-stride * 0.48, stride * 0.48, q_a_recover)
		a_lift = sin(q_a_recover * PI) * size * 0.07

	var b_x: float = 0.0
	var b_lift: float = 0.0
	if t_b < stance_ratio:
		var q_b_stance: float = t_b / stance_ratio
		b_x = lerpf(stride * 0.48, -stride * 0.48, q_b_stance)
		b_lift = 0.0
	else:
		var q_b_recover: float = (t_b - stance_ratio) / (1.0 - stance_ratio)
		b_x = lerpf(-stride * 0.48, stride * 0.48, q_b_recover)
		b_lift = sin(q_b_recover * PI) * size * 0.07

	a_x *= move_factor
	b_x *= move_factor
	a_lift *= move_factor
	b_lift *= move_factor

	var center: Vector2 = Vector2.ZERO

	var shell_dark: Color = Color(0.070, 0.080, 0.108, 1.0)
	var shell_body: Color = Color(0.145, 0.152, 0.168, 1.0)
	var shell_mid: Color = Color(0.285, 0.300, 0.334, 1.0)
	var shell_high: Color = Color(0.385, 0.398, 0.432, 1.0)
	var steel_shadow: Color = Color(0.050, 0.056, 0.070, 0.96)
	var steel_rim: Color = Color(0.54, 0.58, 0.64, 0.78)
	var accent: Color = Color(1.0, 0.62, 0.18, 1.0)
	var accent_soft: Color = Color(accent.r, accent.g, accent.b, 0.46 + blink * 0.16)
	var accent_hot: Color = Color(accent.r, accent.g, accent.b, 1.0)

	# --- Ground contact ---
	var body_shadow: PackedVector2Array = EnemyDrawUtils._ellipse_points(Vector2(0.0, size * 0.28), size * 1.30, size * 0.78, 36, 0.0)
	enemy.draw_colored_polygon(body_shadow, Color(0.0, 0.0, 0.0, 0.28))

	# Local +X is treated as travel direction.
	var rear_top_hip: Vector2 = center + Vector2(-size * 0.58, -size * 0.42)
	var front_top_hip: Vector2 = center + Vector2(size * 0.58, -size * 0.42)
	var rear_bottom_hip: Vector2 = center + Vector2(-size * 0.58, size * 0.42)
	var front_bottom_hip: Vector2 = center + Vector2(size * 0.58, size * 0.42)

	var rear_top_knee: Vector2 = Vector2(-size * 0.98 + b_x * 0.55, -size * 0.78 + b_lift)
	var rear_top_foot: Vector2 = Vector2(-size * 1.22 + b_x, -size * 0.82 + b_lift * 0.45)
	var front_top_knee: Vector2 = Vector2(size * 0.98 + a_x * 0.55, -size * 0.78 + a_lift)
	var front_top_foot: Vector2 = Vector2(size * 1.22 + a_x, -size * 0.82 + a_lift * 0.45)
	var rear_bottom_knee: Vector2 = Vector2(-size * 0.98 + a_x * 0.55, size * 0.78 - a_lift)
	var rear_bottom_foot: Vector2 = Vector2(-size * 1.22 + a_x, size * 0.82 - a_lift * 0.45)
	var front_bottom_knee: Vector2 = Vector2(size * 0.98 + b_x * 0.55, size * 0.78 - b_lift)
	var front_bottom_foot: Vector2 = Vector2(size * 1.22 + b_x, size * 0.82 - b_lift * 0.45)

	# Far/top legs first.
	EnemyVisualRenderer._draw_basic_segmented_leg(enemy, rear_top_hip, rear_top_knee, rear_top_foot, shell_mid.darkened(0.12), color, 2.85, 2.7, pulse)
	EnemyVisualRenderer._draw_basic_segmented_leg(enemy, front_top_hip, front_top_knee, front_top_foot, shell_mid.darkened(0.10), color, 2.85, 2.7, blink)

	# --- Main shell ---
	var body_rx: float = size * 1.04
	var body_ry: float = size * 0.70
	var body_shape: PackedVector2Array = EnemyDrawUtils._ellipse_points(center, body_rx, body_ry, 42, -0.05)
	enemy.draw_colored_polygon(body_shape, shell_body)
	var body_shadow_poly: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.98, -size * 0.04),
		center + Vector2(-size * 0.30, -size * 0.46),
		center + Vector2(size * 0.10, -size * 0.10),
		center + Vector2(-size * 0.12, size * 0.46),
		center + Vector2(-size * 0.86, size * 0.28)
	])
	enemy.draw_colored_polygon(body_shadow_poly, Color(0.03, 0.04, 0.05, 0.36))
	var body_mid_band: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.56, -size * 0.18),
		center + Vector2(size * 0.04, -size * 0.30),
		center + Vector2(size * 0.56, -size * 0.04),
		center + Vector2(size * 0.36, size * 0.18),
		center + Vector2(-size * 0.28, size * 0.14)
	])
	enemy.draw_colored_polygon(body_mid_band, Color(0.42, 0.45, 0.50, 0.24))
	var body_lower_shadow: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.44, size * 0.02),
		center + Vector2(size * 0.34, size * 0.10),
		center + Vector2(size * 0.22, size * 0.38),
		center + Vector2(-size * 0.26, size * 0.34)
	])
	enemy.draw_colored_polygon(body_lower_shadow, Color(0.02, 0.03, 0.04, 0.20))
	var body_upper_sheen: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.34, -size * 0.34),
		center + Vector2(size * 0.10, -size * 0.42),
		center + Vector2(size * 0.34, -size * 0.26),
		center + Vector2(-size * 0.08, -size * 0.18)
	])
	enemy.draw_colored_polygon(body_upper_sheen, Color(0.84, 0.88, 0.96, 0.08))
	var body_spec_poly: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.18, -size * 0.42),
		center + Vector2(size * 0.44, -size * 0.28),
		center + Vector2(size * 0.24, -size * 0.06),
		center + Vector2(-size * 0.28, -size * 0.12)
	])
	enemy.draw_colored_polygon(body_spec_poly, Color(0.92, 0.95, 1.0, 0.08))
	enemy.draw_polyline(body_shape + PackedVector2Array([body_shape[0]]), Color(steel_shadow.r, steel_shadow.g, steel_shadow.b, 0.82), 1.65, true)
	enemy.draw_polyline(body_shape + PackedVector2Array([body_shape[0]]), Color(steel_rim.r, steel_rim.g, steel_rim.b, 0.28), 0.46, true)
	

	# Metallic material shading is now carried mostly by panel fills and shadows.

	# No outer spinning/halo lines. Keep the glow on the character shape itself.

	var top_panel: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.48, -size * 0.38),
		center + Vector2(0.0, -size * 0.52),
		center + Vector2(size * 0.48, -size * 0.38),
		center + Vector2(size * 0.30, -size * 0.04),
		center + Vector2(-size * 0.30, -size * 0.04)
	])
	enemy.draw_colored_polygon(top_panel, shell_mid)
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.34, -size * 0.34),
		center + Vector2(0.0, -size * 0.42),
		center + Vector2(size * 0.34, -size * 0.34),
		center + Vector2(size * 0.18, -size * 0.16),
		center + Vector2(-size * 0.18, -size * 0.16)
	]), Color(0.86, 0.90, 0.98, 0.06))
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.24, -size * 0.06),
		center + Vector2(size * 0.24, -size * 0.06),
		center + Vector2(size * 0.16, size * 0.02),
		center + Vector2(-size * 0.16, size * 0.02)
	]), Color(0.02, 0.03, 0.05, 0.22))
	enemy.draw_polyline(top_panel + PackedVector2Array([top_panel[0]]), steel_shadow, 0.96, true)
	enemy.draw_polyline(top_panel + PackedVector2Array([top_panel[0]]), Color(steel_rim.r, steel_rim.g, steel_rim.b, 0.62), 0.46, true)
	enemy.draw_polyline(top_panel + PackedVector2Array([top_panel[0]]), Color(color.r, color.g, color.b, 0.14 + seq_1 * 0.26), 0.62, true)
	enemy.draw_polyline(top_panel + PackedVector2Array([top_panel[0]]), Color(color.r, color.g, color.b, 0.05 + seq_1 * 0.30), 0.24, true)
	EnemyVisualRenderer._draw_sequential_outline(enemy, top_panel, enemy.pulse_time * 0.42 + phase_seed * 0.11 + 0.05, 0.15, Color(color.r, color.g, color.b, 0.60), 0.34, true)

	var left_panel: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.78, -size * 0.10),
		center + Vector2(-size * 0.48, -size * 0.30),
		center + Vector2(-size * 0.22, -size * 0.08),
		center + Vector2(-size * 0.34, size * 0.22),
		center + Vector2(-size * 0.70, size * 0.18)
	])
	enemy.draw_colored_polygon(left_panel, Color(0.100, 0.115, 0.148, 1.0))
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.68, -size * 0.08),
		center + Vector2(-size * 0.46, -size * 0.24),
		center + Vector2(-size * 0.30, -size * 0.08),
		center + Vector2(-size * 0.46, size * 0.10)
	]), Color(0.86, 0.90, 0.98, 0.05))
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.58, size * 0.02),
		center + Vector2(-size * 0.40, size * 0.16),
		center + Vector2(-size * 0.64, size * 0.16)
	]), Color(0.02, 0.03, 0.05, 0.24))
	enemy.draw_polyline(left_panel + PackedVector2Array([left_panel[0]]), steel_shadow, 0.92, true)
	enemy.draw_polyline(left_panel + PackedVector2Array([left_panel[0]]), Color(steel_rim.r, steel_rim.g, steel_rim.b, 0.60), 0.44, true)
	enemy.draw_polyline(left_panel + PackedVector2Array([left_panel[0]]), Color(color.r, color.g, color.b, 0.12 + seq_2 * 0.26), 0.56, true)
	enemy.draw_polyline(left_panel + PackedVector2Array([left_panel[0]]), Color(color.r, color.g, color.b, 0.04 + seq_2 * 0.28), 0.22, true)
	EnemyVisualRenderer._draw_sequential_outline(enemy, left_panel, enemy.pulse_time * 0.42 + phase_seed * 0.11 + 0.24, 0.14, Color(color.r, color.g, color.b, 0.58), 0.32, true)

	var right_panel: PackedVector2Array = PackedVector2Array([
		center + Vector2(size * 0.22, -size * 0.08),
		center + Vector2(size * 0.48, -size * 0.30),
		center + Vector2(size * 0.78, -size * 0.10),
		center + Vector2(size * 0.70, size * 0.18),
		center + Vector2(size * 0.34, size * 0.22)
	])
	enemy.draw_colored_polygon(right_panel, Color(0.160, 0.176, 0.212, 1.0))
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(size * 0.30, -size * 0.08),
		center + Vector2(size * 0.46, -size * 0.24),
		center + Vector2(size * 0.68, -size * 0.08),
		center + Vector2(size * 0.46, size * 0.10)
	]), Color(0.90, 0.94, 1.0, 0.05))
	enemy.draw_colored_polygon(PackedVector2Array([
		center + Vector2(size * 0.40, size * 0.16),
		center + Vector2(size * 0.58, size * 0.02),
		center + Vector2(size * 0.64, size * 0.16)
	]), Color(0.02, 0.03, 0.05, 0.24))
	enemy.draw_polyline(right_panel + PackedVector2Array([right_panel[0]]), steel_shadow, 0.92, true)
	enemy.draw_polyline(right_panel + PackedVector2Array([right_panel[0]]), Color(steel_rim.r, steel_rim.g, steel_rim.b, 0.58), 0.44, true)
	enemy.draw_polyline(right_panel + PackedVector2Array([right_panel[0]]), Color(accent.r, accent.g, accent.b, 0.12 + seq_3 * 0.26), 0.56, true)
	enemy.draw_polyline(right_panel + PackedVector2Array([right_panel[0]]), Color(accent.r, accent.g, accent.b, 0.04 + seq_3 * 0.28), 0.22, true)
	EnemyVisualRenderer._draw_sequential_outline(enemy, right_panel, enemy.pulse_time * 0.42 + phase_seed * 0.11 + 0.42, 0.14, Color(accent.r, accent.g, accent.b, 0.58), 0.32, true)

	var rear_hatch: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.22, -size * 0.44),
		center + Vector2(size * 0.22, -size * 0.44),
		center + Vector2(size * 0.14, -size * 0.24),
		center + Vector2(-size * 0.14, -size * 0.24)
	])
	enemy.draw_colored_polygon(rear_hatch, shell_high)
	enemy.draw_polyline(rear_hatch + PackedVector2Array([rear_hatch[0]]), steel_shadow, 0.88, true)
	enemy.draw_polyline(rear_hatch + PackedVector2Array([rear_hatch[0]]), Color(steel_rim.r, steel_rim.g, steel_rim.b, 0.54), 0.40, true)
	enemy.draw_polyline(rear_hatch + PackedVector2Array([rear_hatch[0]]), Color(color.r, color.g, color.b, 0.10 + seq_4 * 0.22), 0.50, true)
	enemy.draw_polyline(rear_hatch + PackedVector2Array([rear_hatch[0]]), Color(color.r, color.g, color.b, 0.03 + seq_4 * 0.22), 0.20, true)
	EnemyVisualRenderer._draw_sequential_outline(enemy, rear_hatch, enemy.pulse_time * 0.42 + phase_seed * 0.11 + 0.60, 0.12, Color(color.r, color.g, color.b, 0.52), 0.28, true)

	var lower_lip: PackedVector2Array = PackedVector2Array([
		center + Vector2(-size * 0.42, size * 0.38),
		center + Vector2(size * 0.42, size * 0.38),
		center + Vector2(size * 0.26, size * 0.50),
		center + Vector2(-size * 0.26, size * 0.50)
	])
	enemy.draw_colored_polygon(lower_lip, shell_dark)
	enemy.draw_polyline(lower_lip + PackedVector2Array([lower_lip[0]]), steel_shadow, 0.88, true)
	enemy.draw_polyline(lower_lip + PackedVector2Array([lower_lip[0]]), Color(steel_rim.r, steel_rim.g, steel_rim.b, 0.50), 0.38, true)
	enemy.draw_polyline(lower_lip + PackedVector2Array([lower_lip[0]]), Color(accent.r, accent.g, accent.b, 0.10 + seq_5 * 0.22), 0.52, true)
	enemy.draw_polyline(lower_lip + PackedVector2Array([lower_lip[0]]), Color(accent.r, accent.g, accent.b, 0.03 + seq_5 * 0.22), 0.20, true)
	EnemyVisualRenderer._draw_sequential_outline(enemy, lower_lip, enemy.pulse_time * 0.42 + phase_seed * 0.11 + 0.78, 0.12, Color(accent.r, accent.g, accent.b, 0.52), 0.28, true)

	# Micro panel seams / texture lines.
	enemy.draw_line(center + Vector2(-size * 0.14, -size * 0.40), center + Vector2(-size * 0.28, -size * 0.10), Color(0.02, 0.03, 0.04, 0.34), 1.28, true)
	enemy.draw_line(center + Vector2(-size * 0.14, -size * 0.40), center + Vector2(-size * 0.28, -size * 0.10), Color(color.r, color.g, color.b, 0.10 + seq_1 * 0.22), 0.56, true)
	enemy.draw_line(center + Vector2(-size * 0.14, -size * 0.40), center + Vector2(-size * 0.28, -size * 0.10), Color(color.r, color.g, color.b, 0.03 + seq_1 * 0.18), 0.18, true)
	enemy.draw_line(center + Vector2(size * 0.14, -size * 0.40), center + Vector2(size * 0.28, -size * 0.10), Color(0.02, 0.03, 0.04, 0.34), 1.28, true)
	enemy.draw_line(center + Vector2(size * 0.14, -size * 0.40), center + Vector2(size * 0.28, -size * 0.10), Color(accent.r, accent.g, accent.b, 0.10 + seq_2 * 0.20), 0.56, true)
	enemy.draw_line(center + Vector2(size * 0.14, -size * 0.40), center + Vector2(size * 0.28, -size * 0.10), Color(accent.r, accent.g, accent.b, 0.03 + seq_2 * 0.16), 0.18, true)
	enemy.draw_line(center + Vector2(-size * 0.20, size * 0.10), center + Vector2(-size * 0.02, size * 0.20), Color(0.02, 0.03, 0.04, 0.26), 1.08, true)
	enemy.draw_line(center + Vector2(-size * 0.20, size * 0.10), center + Vector2(-size * 0.02, size * 0.20), Color(color.r, color.g, color.b, 0.08 + seq_3 * 0.18), 0.48, true)
	enemy.draw_line(center + Vector2(size * 0.02, size * 0.10), center + Vector2(size * 0.20, size * 0.20), Color(0.02, 0.03, 0.04, 0.26), 1.08, true)
	enemy.draw_line(center + Vector2(size * 0.02, size * 0.10), center + Vector2(size * 0.20, size * 0.20), Color(accent.r, accent.g, accent.b, 0.08 + seq_3 * 0.16), 0.48, true)

	# Body-mounted contour cuts instead of outer rails.
	enemy.draw_line(center + Vector2(-size * 0.74, -size * 0.02), center + Vector2(-size * 0.44, -size * 0.20), Color(color.r, color.g, color.b, 0.10 + seq_1 * 0.20), 0.64, true)
	enemy.draw_line(center + Vector2(-size * 0.74, -size * 0.02), center + Vector2(-size * 0.44, -size * 0.20), Color(color.r, color.g, color.b, 0.03 + seq_1 * 0.16), 0.20, true)
	enemy.draw_line(center + Vector2(-size * 0.70, size * 0.18), center + Vector2(-size * 0.38, size * 0.00), Color(accent.r, accent.g, accent.b, 0.10 + seq_2 * 0.20), 0.60, true)
	enemy.draw_line(center + Vector2(-size * 0.70, size * 0.18), center + Vector2(-size * 0.38, size * 0.00), Color(accent.r, accent.g, accent.b, 0.03 + seq_2 * 0.16), 0.20, true)
	enemy.draw_line(center + Vector2(size * 0.44, -size * 0.20), center + Vector2(size * 0.74, -size * 0.02), Color(accent.r, accent.g, accent.b, 0.10 + seq_3 * 0.18), 0.60, true)
	enemy.draw_line(center + Vector2(size * 0.44, -size * 0.20), center + Vector2(size * 0.74, -size * 0.02), Color(accent.r, accent.g, accent.b, 0.03 + seq_3 * 0.14), 0.20, true)
	enemy.draw_line(center + Vector2(size * 0.30, size * 0.10), center + Vector2(size * 0.64, size * 0.28), Color(accent.r, accent.g, accent.b, 0.10 + seq_4 * 0.18), 0.58, true)
	enemy.draw_line(center + Vector2(size * 0.30, size * 0.10), center + Vector2(size * 0.64, size * 0.28), Color(accent.r, accent.g, accent.b, 0.03 + seq_4 * 0.14), 0.20, true)

	# Symmetrical shell light cuts.
	var sym_top_y: float = -size * 0.18
	var sym_mid_y: float = -size * 0.04
	var sym_low_y: float = size * 0.12
	enemy.draw_line(center + Vector2(-size * 0.52, sym_top_y), center + Vector2(-size * 0.12, sym_top_y), Color(color.r, color.g, color.b, 0.14 + seq_1 * 0.30), 0.92, true)
	enemy.draw_line(center + Vector2(size * 0.12, sym_top_y), center + Vector2(size * 0.52, sym_top_y), Color(accent.r, accent.g, accent.b, 0.14 + seq_1 * 0.28), 0.92, true)
	enemy.draw_line(center + Vector2(-size * 0.46, sym_mid_y), center + Vector2(-size * 0.08, sym_mid_y), Color(color.r, color.g, color.b, 0.12 + seq_2 * 0.26), 0.82, true)
	enemy.draw_line(center + Vector2(size * 0.08, sym_mid_y), center + Vector2(size * 0.46, sym_mid_y), Color(accent.r, accent.g, accent.b, 0.12 + seq_2 * 0.24), 0.82, true)
	enemy.draw_line(center + Vector2(-size * 0.36, sym_low_y), center + Vector2(-size * 0.02, sym_low_y), Color(color.r, color.g, color.b, 0.10 + seq_3 * 0.22), 0.72, true)
	enemy.draw_line(center + Vector2(size * 0.02, sym_low_y), center + Vector2(size * 0.36, sym_low_y), Color(accent.r, accent.g, accent.b, 0.10 + seq_3 * 0.20), 0.72, true)

	# Small contrast-color accent markers.
	enemy.draw_circle(center + Vector2(size * 0.54, -size * 0.10), size * 0.065, accent_hot)
	enemy.draw_circle(center + Vector2(size * 0.62, size * 0.10), size * 0.055, Color(accent.r, accent.g, accent.b, 0.52 + blink * 0.22))
	enemy.draw_rect(Rect2(center.x + size * 0.22, center.y - size * 0.34, size * 0.18, size * 0.06), accent_soft)

	# Roof-mounted core with segmented ring blink.
	var core_pos: Vector2 = center + Vector2(-size * 0.18, -size * 0.06)
	enemy.draw_circle(core_pos, size * (0.40 + pulse * 0.030), Color(color.r, color.g, color.b, 0.20 + pulse * 0.12))
	enemy.draw_circle(core_pos, size * 0.245, Color(0.050, 0.068, 0.090, 1.0))
	enemy.draw_arc(core_pos, size * 0.255, 0.10, 1.40, 8, Color(color.r, color.g, color.b, 0.76 + freq_a * 0.22), 1.70, true)
	enemy.draw_arc(core_pos, size * 0.255, 1.85, 3.15, 8, Color(color.r, color.g, color.b, 0.58 + freq_b * 0.22), 1.60, true)
	enemy.draw_arc(core_pos, size * 0.255, 3.55, 5.15, 9, Color(color.r, color.g, color.b, 0.82 + freq_c * 0.18), 1.70, true)
	enemy.draw_arc(core_pos, size * 0.175, 0.0, TAU, 20, Color(color.r, color.g, color.b, 0.38 + blink * 0.22), 1.15, true)
	enemy.draw_circle(core_pos, size * 0.108, Color(color.r, color.g, color.b, 0.96 + pulse * 0.04))
	enemy.draw_circle(core_pos, size * 0.035, Color(0.86, 1.0, 1.0, 0.90))

	# Secondary roof sensor.
	var sensor_pos: Vector2 = center + Vector2(size * 0.42, -size * 0.04)

	# Soft halos to read clearly in gameplay without overpowering the silhouette.
	enemy.draw_circle(core_pos, size * 0.52, Color(color.r, color.g, color.b, 0.09 + pulse * 0.05))
	enemy.draw_circle(core_pos, size * 0.72, Color(color.r, color.g, color.b, 0.04 + pulse * 0.03))
	enemy.draw_circle(sensor_pos, size * 0.24, Color(color.r, color.g, color.b, 0.07 + blink * 0.05))
	enemy.draw_circle(center + Vector2(size * 0.54, -size * 0.10), size * 0.18, Color(accent.r, accent.g, accent.b, 0.18 + blink * 0.10))
	enemy.draw_circle(sensor_pos, size * 0.135, Color(0.045, 0.060, 0.082, 1.0))
	enemy.draw_arc(sensor_pos, size * 0.145, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.58 + pulse * 0.18), 1.15, true)
	enemy.draw_circle(sensor_pos, size * 0.055, Color(color.r, color.g, color.b, 0.88 + blink * 0.12))

	# Extra on-body neon cuts kept symmetrical and subtle.
	enemy.draw_line(center + Vector2(-size * 0.24, -size * 0.24), center + Vector2(-size * 0.02, -size * 0.10), Color(color.r, color.g, color.b, 0.10 + seq_4 * 0.20), 0.60, true)
	enemy.draw_line(center + Vector2(size * 0.02, -size * 0.24), center + Vector2(size * 0.24, -size * 0.10), Color(accent.r, accent.g, accent.b, 0.10 + seq_4 * 0.18), 0.60, true)
	enemy.draw_line(center + Vector2(-size * 0.18, size * 0.10), center + Vector2(-size * 0.02, size * 0.18), Color(color.r, color.g, color.b, 0.08 + seq_5 * 0.16), 0.54, true)
	enemy.draw_line(center + Vector2(size * 0.02, size * 0.10), center + Vector2(size * 0.18, size * 0.18), Color(accent.r, accent.g, accent.b, 0.08 + seq_5 * 0.14), 0.54, true)

	# Circuit traces connecting modules.
	enemy.draw_line(center + Vector2(-size * 0.42, -size * 0.06), core_pos + Vector2(-size * 0.14, 0.0), Color(color.r, color.g, color.b, 0.10 + seq_1 * 0.22), 0.72, true)
	enemy.draw_line(center + Vector2(size * 0.30, -size * 0.08), sensor_pos + Vector2(-size * 0.10, 0.0), Color(accent.r, accent.g, accent.b, 0.10 + seq_2 * 0.20), 0.72, true)
	enemy.draw_line(center + Vector2(-size * 0.24, size * 0.18), center + Vector2(-size * 0.04, size * 0.22), Color(color.r, color.g, color.b, 0.08 + seq_3 * 0.16), 0.60, true)
	enemy.draw_line(center + Vector2(size * 0.04, size * 0.18), center + Vector2(size * 0.24, size * 0.22), Color(accent.r, accent.g, accent.b, 0.08 + seq_3 * 0.14), 0.60, true)

	# Tight silhouette cuts directly on the shell.
	enemy.draw_line(center + Vector2(-size * 0.50, -size * 0.24), center + Vector2(-size * 0.24, -size * 0.12), Color(color.r, color.g, color.b, 0.10 + seq_2 * 0.20), 0.64, true)
	enemy.draw_line(center + Vector2(size * 0.24, -size * 0.24), center + Vector2(size * 0.50, -size * 0.12), Color(accent.r, accent.g, accent.b, 0.10 + seq_2 * 0.18), 0.64, true)
	enemy.draw_line(center + Vector2(-size * 0.46, size * 0.12), center + Vector2(-size * 0.18, size * 0.22), Color(color.r, color.g, color.b, 0.08 + seq_3 * 0.16), 0.58, true)
	enemy.draw_line(center + Vector2(size * 0.18, size * 0.12), center + Vector2(size * 0.46, size * 0.22), Color(accent.r, accent.g, accent.b, 0.08 + seq_3 * 0.14), 0.58, true)

	# Tiny edge texture / hatch marks for more surface breakup.
	enemy.draw_line(center + Vector2(-size * 0.66, -size * 0.04), center + Vector2(-size * 0.60, -size * 0.08), Color(color.r, color.g, color.b, 0.06 + seq_1 * 0.10), 0.42, true)
	enemy.draw_line(center + Vector2(size * 0.60, -size * 0.04), center + Vector2(size * 0.66, -size * 0.08), Color(accent.r, accent.g, accent.b, 0.06 + seq_1 * 0.08), 0.42, true)

	# Near/bottom legs after body.
	EnemyVisualRenderer._draw_basic_segmented_leg(enemy, rear_bottom_hip, rear_bottom_knee, rear_bottom_foot, Color(0.260, 0.290, 0.345, 1.0), color, 3.8, 3.4, blink)
	EnemyVisualRenderer._draw_basic_segmented_leg(enemy, front_bottom_hip, front_bottom_knee, front_bottom_foot, Color(0.260, 0.290, 0.345, 1.0), color, 3.8, 3.4, pulse)

	# Feet contact marks.
	var contact_alpha: float = 0.08 + move_factor * 0.08
	enemy.draw_circle(rear_top_foot, 1.25, Color(color.r, color.g, color.b, contact_alpha * 0.80))
	enemy.draw_circle(front_top_foot, 1.25, Color(color.r, color.g, color.b, contact_alpha * 0.80))
	enemy.draw_circle(rear_bottom_foot, 1.55, Color(color.r, color.g, color.b, contact_alpha))
	enemy.draw_circle(front_bottom_foot, 1.55, Color(color.r, color.g, color.b, contact_alpha))

	# Micro LEDs on legs for extra layered neon detail.
	enemy.draw_circle(rear_bottom_knee, 1.90, Color(accent.r, accent.g, accent.b, 0.44 + blink * 0.18))
	enemy.draw_circle(front_bottom_knee, 1.90, Color(accent.r, accent.g, accent.b, 0.44 + freq_b * 0.18))

	var particle_alpha: float = 0.07 + pulse * 0.07
	enemy.draw_rect(Rect2(-size * 1.18, -size * 0.74, 1.6, 1.6), Color(color.r, color.g, color.b, particle_alpha))
	enemy.draw_rect(Rect2(size * 1.08, -size * 0.38, 1.5, 1.5), Color(color.r, color.g, color.b, particle_alpha * 0.82))
	enemy.draw_rect(Rect2(size * 0.86, size * 0.44, 1.3, 1.3), Color(color.r, color.g, color.b, particle_alpha * 0.62))




static func _draw_cyber_runner(enemy: Node2D, color: Color, size: float) -> void:
	var pts := PackedVector2Array([
		Vector2(size * 1.5, 0),
		Vector2(-size * 1.0, -size * 0.7),
		Vector2(-size * 0.5, 0),
		Vector2(-size * 1.0, size * 0.7)
	])
	
	# Layer 1: Base
	enemy.draw_colored_polygon(pts, enemy.COLOR_BODY)
	var fin_pts := PackedVector2Array([
		Vector2(-size * 0.35, -size * 0.95),
		Vector2(size * 0.2, -size * 0.42),
		Vector2(-size * 0.58, -size * 0.28)
	])
	enemy.draw_colored_polygon(fin_pts, Color(color.r, color.g, color.b, 0.18))
	for i in range(fin_pts.size()):
		fin_pts[i].y *= -1.0
	enemy.draw_colored_polygon(fin_pts, Color(color.r, color.g, color.b, 0.18))
	
	# Layer 2: Speed Trails
	var trail_alpha = 0.3 + (sin(enemy.pulse_time * 20.0) * 0.2)
	enemy.draw_line(Vector2(-size * 0.8, -size * 0.4), Vector2(-size * 2.5, -size * 0.4), Color(color.r, color.g, color.b, trail_alpha), 2.0)
	enemy.draw_line(Vector2(-size * 0.8, size * 0.4), Vector2(-size * 2.5, size * 0.4), Color(color.r, color.g, color.b, trail_alpha), 2.0)
	enemy.draw_polyline(PackedVector2Array([Vector2(-size * 0.2, 0), Vector2(-size * 1.4, -size * 0.9), Vector2(-size * 2.3, -size * 0.9)]), Color(color.r, color.g, color.b, trail_alpha * 0.45), 1.0)
	enemy.draw_polyline(PackedVector2Array([Vector2(-size * 0.2, 0), Vector2(-size * 1.4, size * 0.9), Vector2(-size * 2.3, size * 0.9)]), Color(color.r, color.g, color.b, trail_alpha * 0.45), 1.0)
	
	# Layer 3: Neon Edges
	enemy.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 4.0)
	enemy.draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.5)
	
	# Layer 4: Agile Core
	EnemyVisualRenderer._draw_glow_core(enemy, Vector2(size * 0.4, 0), size * 0.25, color)


static func _draw_cyber_tank(enemy: Node2D, color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a: float = i * PI / 4
		pts.append(Vector2(cos(a), sin(a)) * size)
	
	# Layer 1: Base Heavy Body
	enemy.draw_colored_polygon(pts, enemy.COLOR_BODY)
	
	# Layer 2: Heavy Armor Plates (Beveled)
	for i in range(8):
		var mid = (pts[i] + pts[(i + 1) % 8]) * 0.5
		var inner_mid = mid * 0.7
		enemy.draw_line(mid, inner_mid, Color(color.r, color.g, color.b, 0.32), 1.4)
		if i % 2 == 0:
			enemy.draw_circle(inner_mid, 2.2, Color(color.r, color.g, color.b, 0.45))
		
	# Layer 3: Thick Neon Border
	enemy.draw_polyline(pts + PackedVector2Array([pts[0]]), color, 4.0)
	enemy.draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0) # Separation line
	
	# Layer 4: Heavy Energy Core
	EnemyVisualRenderer._draw_glow_core(enemy, Vector2.ZERO, size * 0.45, color)
	# Secondary lights
	for i in range(4):
		var a = i * PI / 2 + PI / 4
		enemy.draw_circle(Vector2(cos(a), sin(a)) * size * 0.8, 3, color)


static func _draw_cyber_bulwark(enemy: Node2D, color: Color, size: float) -> void:
	var rect = Rect2(-size, -size * 0.8, size * 2, size * 1.6)
	
	# Layer 1: Base Silhouette
	enemy.draw_rect(rect, enemy.COLOR_BODY)
	
	# Layer 2: Plate Segments
	enemy.draw_line(Vector2(0, -size * 0.8), Vector2(0, size * 0.8), color * 0.5)
	enemy.draw_rect(Rect2(-size * 0.72, -size * 0.52, size * 0.46, size * 1.04), Color(color.r, color.g, color.b, 0.12))
	enemy.draw_rect(Rect2(size * 0.26, -size * 0.52, size * 0.46, size * 1.04), Color(color.r, color.g, color.b, 0.12))
	enemy.draw_line(Vector2(-size, -size * 0.8), Vector2(size, -size * 0.8), Color(0, 0, 0, 0.75), 2.5)
	enemy.draw_line(Vector2(-size, size * 0.8), Vector2(size, size * 0.8), Color(0, 0, 0, 0.75), 2.5)
	
	# Layer 3: Shield Rails
	enemy.draw_polyline(PackedVector2Array([
		Vector2(size, -size * 0.8), Vector2(size, size * 0.8)
	]), color, 3.0)
	enemy.draw_polyline(PackedVector2Array([
		Vector2(-size, -size * 0.8), Vector2(-size, size * 0.8)
	]), color, 3.0)
	
	# Layer 4: Emitter Nodes
	for i in range(3):
		var y = - size * 0.4 + i * (size * 0.4)
		EnemyVisualRenderer._draw_glow_core(enemy, Vector2(size * 0.8, y), 4, color)
		EnemyVisualRenderer._draw_glow_core(enemy, Vector2(-size * 0.8, y), 4, color)
	
	# Shield Field (Dome)
	EnemyVisualRenderer._draw_shield_dome(enemy, enemy.shield_radius, color)


static func _draw_cyber_healer(enemy: Node2D, _color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var a = i * PI / 6
		var r = size if i % 3 != 0 else size * 0.6
		pts.append(Vector2(cos(a), sin(a)) * r)
	
	var heal_color := Color(0.62, 1.0, 0.86, 1.0)
	var gold := Color(1.0, 0.88, 0.48, 1.0)
	enemy.draw_colored_polygon(pts, enemy.COLOR_BODY)
	EnemyVisualRenderer._draw_inner_plate(enemy, pts, heal_color, 0.58)
	enemy.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.7), 3.0)
	enemy.draw_polyline(pts + PackedVector2Array([pts[0]]), heal_color, 2.0)
	# Rotating healing ring
	enemy.draw_arc(Vector2.ZERO, size * 0.8, enemy.pulse_time * 2.6, enemy.pulse_time * 2.6 + PI, 24, gold, 2.0)
	enemy.draw_arc(Vector2.ZERO, size * 1.2, -enemy.pulse_time * 1.4, -enemy.pulse_time * 1.4 + PI * 0.65, 20, Color(heal_color.r, heal_color.g, heal_color.b, 0.48), 1.4)
	EnemyVisualRenderer._draw_orbiters(enemy, 4, size * 1.14, 2.2, gold, 1.1)
	for i in range(4):
		var a := i * PI * 0.5 + PI * 0.25
		EnemyVisualRenderer._draw_circuit_line(enemy, Vector2.RIGHT.rotated(a) * size * 0.25, Vector2.RIGHT.rotated(a) * size * 0.78, heal_color, 1.1)
	EnemyVisualRenderer._draw_glow_core(enemy, Vector2.ZERO, size * 0.5, heal_color)


static func _draw_cyber_splitter(enemy: Node2D, color: Color, size: float) -> void:
	EnemyVisualRenderer._draw_cyber_node(enemy, color, size)
	# Unstable Cracks
	var noise = sin(enemy.pulse_time * 25.0) * 2.0
	var crack_color := Color(1.0, 0.78, 1.0, 0.86)
	enemy.draw_line(Vector2.ZERO, Vector2(size + noise, size), crack_color, 1.5)
	enemy.draw_line(Vector2.ZERO, Vector2(-size - noise, size), crack_color, 1.5)
	enemy.draw_line(Vector2.ZERO, Vector2(0, -size - noise), crack_color, 1.5)
	if enemy.hp / max(enemy.max_hp, 1.0) < 0.35:
		var warn := 0.35 + sin(enemy.pulse_time * 18.0) * 0.22
		enemy.draw_arc(Vector2.ZERO, size * 1.35, 0, TAU, 32, Color(1.0, 0.35, 0.9, warn), 2.0)


static func _draw_cyber_cloaked(enemy: Node2D, color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(4):
		var a = i * PI / 2 + PI / 4
		pts.append(Vector2(cos(a), sin(a)) * size)
	# Distortion effect
	var d = (sin(enemy.pulse_time * 15.0) * 0.5 + 0.5) * 0.2
	for i in range(pts.size()):
		var p1 := pts[i] + Vector2(sin(enemy.pulse_time * 18.0 + i) * 2.0, 0)
		var p2 := pts[(i + 1) % pts.size()] + Vector2(sin(enemy.pulse_time * 17.0 + i) * -2.0, 0)
		enemy.draw_line(p1, p2, Color(color.r, color.g, color.b, 0.22 + d), 1.5)
	for i in range(4):
		var y := -size * 0.65 + i * size * 0.42
		enemy.draw_line(Vector2(-size * 0.55, y), Vector2(size * 0.55, y + sin(enemy.pulse_time * 12.0 + i) * 1.5), Color(color.r, color.g, color.b, 0.11 + d * 0.45), 1.0)
	enemy.draw_circle(Vector2.ZERO, size * (0.2 + d), Color(color.r, color.g, color.b, 0.15))


static func _draw_cyber_drone(enemy: Node2D, color: Color, size: float, is_fast: bool) -> void:
	# Base
	enemy.draw_circle(Vector2(0, size * 0.7), size * 0.36, Color(0.0, 0.0, 0.0, 0.14))
	enemy.draw_circle(Vector2.ZERO, size * 0.6, enemy.COLOR_BODY)
	enemy.draw_arc(Vector2.ZERO, size * 0.6, 0, TAU, 24, color, 2.0)
	enemy.draw_arc(Vector2.ZERO, size * 0.88, enemy.pulse_time * 2.0, enemy.pulse_time * 2.0 + PI, 24, Color(color.r, color.g, color.b, 0.28), 1.0)
	
	# Rotor arms
	for i in range(4):
		var a = i * PI / 2 + (enemy.pulse_time * 15.0)
		enemy.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * size, color, 2.0)
		enemy.draw_circle(Vector2(cos(a), sin(a)) * size, 3, Color.WHITE)
	
	if is_fast:
		var trail = (sin(enemy.pulse_time * 30.0) * 0.5 + 0.5) * 10.0
		enemy.draw_line(Vector2(-size, 0), Vector2(-size - trail, 0), color, 3.0)
		enemy.draw_line(Vector2(-size * 0.45, -size * 0.35), Vector2(-size - trail * 0.7, -size * 0.6), Color(color.r, color.g, color.b, 0.35), 1.4)
		enemy.draw_line(Vector2(-size * 0.45, size * 0.35), Vector2(-size - trail * 0.7, size * 0.6), Color(color.r, color.g, color.b, 0.35), 1.4)
	
	EnemyVisualRenderer._draw_glow_core(enemy, Vector2.ZERO, size * 0.3, color)


static func _draw_cyber_disruptor(enemy: Node2D, color: Color, size: float) -> void:
	EnemyVisualRenderer._draw_cyber_drone(enemy, color, size, false)
	var cyan := Color(0.35, 1.0, 1.0, 1.0)
	enemy.draw_line(Vector2(size * 0.25, -size * 0.55), Vector2(size * 1.2, -size * 1.0), cyan, 1.6)
	enemy.draw_line(Vector2(size * 0.25, size * 0.55), Vector2(size * 1.2, size * 1.0), cyan, 1.6)
	enemy.draw_line(Vector2(size * 1.0, -size * 0.82), Vector2(size * 1.28, -size * 1.08), Color(1.0, 0.2, 0.82, 0.8), 1.0)
	enemy.draw_line(Vector2(size * 1.0, size * 0.82), Vector2(size * 1.28, size * 1.08), Color(1.0, 0.2, 0.82, 0.8), 1.0)
	# EMP interference rings
	var r_pulse = (sin(enemy.pulse_time * 10.0) * 0.5 + 0.5)
	enemy.draw_arc(Vector2.ZERO, size * (1.2 + r_pulse * 0.3), 0, TAU, 32, Color(color.r, color.g, color.b, 0.4 - r_pulse * 0.3), 2.0)
	enemy.draw_arc(Vector2.ZERO, size * (1.5 + r_pulse * 0.5), 0, TAU, 32, Color(color.r, color.g, color.b, 0.2 - r_pulse * 0.2), 1.5)


static func _draw_glow_core(enemy: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	if enemy.PERFORMANCE_VISUAL_MODE:
		enemy.draw_circle(pos, radius * 0.4, Color.WHITE)
		return
	var p = (sin(enemy.pulse_time * 8.0) * 0.5 + 0.5) * 0.2
	var r = radius * (1.0 + p)
	# Outer glow
	enemy.draw_circle(pos, r * 1.5, Color(color.r, color.g, color.b, 0.15))
	# Mid glow
	enemy.draw_circle(pos, r, Color(color.r, color.g, color.b, 0.4))
	# Hot core
	enemy.draw_circle(pos, r * 0.4, Color.WHITE)


static func _draw_circuit_line(enemy: Node2D, p1: Vector2, p2: Vector2, color: Color, width: float = 1.0) -> void:
	var alpha = (sin(enemy.pulse_time * 12.0 + p1.x) * 0.5 + 0.5) * 0.4 + 0.1
	enemy.draw_line(p1, p2, Color(color.r, color.g, color.b, alpha), width)


static func _draw_edge_nodes(enemy: Node2D, points: PackedVector2Array, color: Color, radius: float = 1.8) -> void:
	for p in points:
		enemy.draw_circle(p, radius + 1.0, Color(0.0, 0.0, 0.0, 0.45))
		enemy.draw_circle(p, radius, Color(color.r, color.g, color.b, 0.78))


static func _draw_orbiters(enemy: Node2D, count: int, orbit_radius: float, node_radius: float, color: Color, p_speed: float = 1.0) -> void:
	if enemy.PERFORMANCE_VISUAL_MODE: return
	for i in range(count):
		var a: float = float(i) / float(count) * TAU + enemy.pulse_time * p_speed
		var p := Vector2.RIGHT.rotated(a) * orbit_radius
		enemy.draw_circle(p, node_radius + 2.0, Color(color.r, color.g, color.b, 0.08))
		enemy.draw_circle(p, node_radius, Color(color.r, color.g, color.b, 0.75))
		enemy.draw_line(p * 0.82, p * 1.06, Color(color.r, color.g, color.b, 0.28), 1.0)


static func _draw_inner_plate(enemy: Node2D, points: PackedVector2Array, color: Color, scale_factor: float = 0.66) -> void:
	var inner := PackedVector2Array()
	for p in points:
		inner.append(p * scale_factor)
	enemy.draw_polyline(inner + PackedVector2Array([inner[0]]), Color(color.r, color.g, color.b, 0.28), 1.0)


static func _draw_shield_dome(enemy: Node2D, radius: float, color: Color) -> void:
	if enemy.PERFORMANCE_VISUAL_MODE:
		enemy.draw_arc(Vector2.ZERO, radius, 0, TAU, 12, Color(color.r, color.g, color.b, 0.5), 1.5)
		return
	var pulse = sin(enemy.pulse_time * 3.0) * 0.5 + 0.5
	var r_anim = radius * (0.98 + pulse * 0.04)
	# Layer 1: Faint Fill
	enemy.draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.04 + pulse * 0.02))
	# Layer 2: Main Ring
	enemy.draw_arc(Vector2.ZERO, r_anim, 0, TAU, 64, Color(color.r, color.g, color.b, 0.2 + pulse * 0.1), 1.5)
	# Layer 3: Shimmer Nodes
	var node_count = 6
	for i in range(node_count):
		var a = i * (TAU / node_count) + (enemy.pulse_time * 0.5)
		var node_pos = Vector2(cos(a), sin(a)) * r_anim
		enemy.draw_circle(node_pos, 2.0, Color(color.r, color.g, color.b, 0.4))



static func _draw_sequential_outline(enemy: Node2D, points: PackedVector2Array, phase: float, segment_ratio: float, color: Color, width: float = 1.0, closed: bool = true) -> void:
	if points.size() < 2:
		return

	var segment_count: int = points.size() if closed else points.size() - 1
	if segment_count <= 0:
		return

	var seg_lengths: Array = []
	var total_length: float = 0.0
	for i in range(segment_count):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var seg_len: float = a.distance_to(b)
		seg_lengths.append(seg_len)
		total_length += seg_len

	if total_length <= 0.001:
		return

	var highlight_len: float = clampf(segment_ratio, 0.02, 1.0) * total_length
	var start_d: float = fposmod(phase, 1.0) * total_length
	var remaining: float = highlight_len
	var cursor: float = start_d

	while remaining > 0.0:
		var range_start: float = cursor
		var range_end: float = minf(total_length, cursor + remaining)
		var sampled := PackedVector2Array()
		var accum: float = 0.0

		for i in range(segment_count):
			var seg_start: float = accum
			var seg_end: float = accum + float(seg_lengths[i])
			if range_end > seg_start and range_start < seg_end and seg_end > seg_start:
				var denom: float = seg_end - seg_start
				var t1: float = clampf((maxf(range_start, seg_start) - seg_start) / denom, 0.0, 1.0)
				var t2: float = clampf((minf(range_end, seg_end) - seg_start) / denom, 0.0, 1.0)
				var p1: Vector2 = points[i].lerp(points[(i + 1) % points.size()], t1)
				var p2: Vector2 = points[i].lerp(points[(i + 1) % points.size()], t2)
				if sampled.is_empty() or sampled[sampled.size() - 1].distance_to(p1) > 0.01:
					sampled.append(p1)
				sampled.append(p2)
			accum = seg_end

		if sampled.size() >= 2:
			var seg_total: int = sampled.size() - 1
			for j in range(seg_total):
				var p0: Vector2 = sampled[j]
				var p1: Vector2 = sampled[j + 1]
				var raw_t: float = float(j) / float(max(seg_total - 1, 1))
				var t: float = raw_t * raw_t * (3.0 - 2.0 * raw_t)
				var tail_color: Color = Color(color.r * 0.58, color.g * 0.58, color.b * 0.58, 1.0)
				var head_color: Color = color.lerp(Color(0.92, 0.95, 1.0, 1.0), 0.18)
				var ramp_color: Color = tail_color.lerp(head_color, t)
				var halo_alpha: float = color.a * (0.02 + 0.14 * t)
				var glow_alpha: float = color.a * (0.06 + 0.26 * t)
				var core_alpha: float = color.a * (0.16 + 0.46 * t)
				enemy.draw_line(p0, p1, Color(ramp_color.r, ramp_color.g, ramp_color.b, halo_alpha), width * (2.0 + 0.1 * t), true)
				enemy.draw_line(p0, p1, Color(ramp_color.r, ramp_color.g, ramp_color.b, glow_alpha), width * (1.20 + 0.08 * t), true)
				enemy.draw_line(p0, p1, Color(ramp_color.r, ramp_color.g, ramp_color.b, core_alpha), width * (0.62 + 0.06 * t), true)

			var head_pos: Vector2 = sampled[sampled.size() - 1]
			var head_glow: Color = color.lerp(Color(0.92, 0.95, 1.0, 1.0), 0.22)
			enemy.draw_circle(head_pos, width * 1.10, Color(head_glow.r, head_glow.g, head_glow.b, color.a * 0.18))
			enemy.draw_circle(head_pos, width * 0.60, Color(head_glow.r, head_glow.g, head_glow.b, color.a * 0.28))

		remaining -= (range_end - range_start)
		cursor = 0.0


static func _draw_basic_segmented_leg(enemy: Node2D, 
	hip: Vector2,
	knee: Vector2,
	foot: Vector2,
	base_color: Color,
	glow_color: Color,
	thickness: float,
	claw_size: float = 3.6,
	pulse_alpha: float = 1.0
) -> void:
	var leg_dir: Vector2 = (foot - knee).normalized()
	var side: Vector2 = leg_dir.orthogonal().normalized()

	# contact shadow
	enemy.draw_circle(foot + Vector2(0.0, 1.8), claw_size * 1.45, Color(0.0, 0.0, 0.0, 0.22))

	# black mechanical under-frame
	enemy.draw_line(hip, knee, Color(0.0, 0.0, 0.0, 0.72), thickness + 3.4, true)
	enemy.draw_line(knee, foot, Color(0.0, 0.0, 0.0, 0.72), thickness + 3.0, true)

	# metal bone segments
	enemy.draw_line(hip, knee, base_color, thickness, true)
	enemy.draw_line(knee, foot, base_color.darkened(0.05), thickness * 0.92, true)

	# cyan cable running through the leg
	var cable_start: Vector2 = hip.lerp(knee, 0.22)
	var cable_mid: Vector2 = knee.lerp(foot, 0.38)
	enemy.draw_line(cable_start, cable_mid, Color(glow_color.r, glow_color.g, glow_color.b, 0.20 + 0.20 * pulse_alpha), 1.15, true)

	# joint housings
	enemy.draw_circle(hip, thickness * 0.58 + 1.6, Color(0.0, 0.0, 0.0, 0.68))
	enemy.draw_circle(knee, thickness * 0.52 + 1.3, Color(0.0, 0.0, 0.0, 0.68))
	enemy.draw_circle(hip, thickness * 0.58, Color(0.20, 0.22, 0.28, 1.0))
	enemy.draw_circle(knee, thickness * 0.52, Color(0.16, 0.18, 0.23, 1.0))

	# neon joint pulse
	enemy.draw_circle(hip, 1.50 + pulse_alpha * 0.35, Color(glow_color.r, glow_color.g, glow_color.b, 0.72 + pulse_alpha * 0.22))
	enemy.draw_circle(knee, 1.25 + pulse_alpha * 0.28, Color(glow_color.r, glow_color.g, glow_color.b, 0.62 + pulse_alpha * 0.18))

	# armored plate on lower leg
	var plate_center: Vector2 = knee.lerp(foot, 0.52)
	var plate: PackedVector2Array = PackedVector2Array([
		plate_center - leg_dir * claw_size * 0.85 + side * claw_size * 0.42,
		plate_center + leg_dir * claw_size * 0.62 + side * claw_size * 0.32,
		plate_center + leg_dir * claw_size * 0.82 - side * claw_size * 0.34,
		plate_center - leg_dir * claw_size * 0.68 - side * claw_size * 0.44
	])
	enemy.draw_colored_polygon(plate, Color(0.27, 0.29, 0.34, 1.0))
	enemy.draw_polyline(plate + PackedVector2Array([plate[0]]), Color(0.0, 0.0, 0.0, 0.62), 1.0)

	# sharp claw / contact point
	var claw: PackedVector2Array = PackedVector2Array([
		foot + leg_dir * claw_size * 0.32,
		foot - leg_dir * claw_size * 1.08 + side * claw_size * 0.48,
		foot - leg_dir * claw_size * 1.08 - side * claw_size * 0.48
	])
	enemy.draw_colored_polygon(claw, Color(0.76, 0.80, 0.87, 1.0))
	enemy.draw_polyline(claw + PackedVector2Array([claw[0]]), Color(0.0, 0.0, 0.0, 0.70), 1.0)
	enemy.draw_line(foot, foot + leg_dir * claw_size * 0.52, Color(glow_color.r, glow_color.g, glow_color.b, 0.28 + pulse_alpha * 0.20), 1.0, true)


static func _draw_basic_motion_streak(enemy: Node2D, start_pos: Vector2, end_pos: Vector2, color: Color, alpha: float, width: float = 1.0) -> void:
	enemy.draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, alpha), width, true)
	enemy.draw_circle(end_pos, width * 0.70, Color(color.r, color.g, color.b, alpha * 0.82))


