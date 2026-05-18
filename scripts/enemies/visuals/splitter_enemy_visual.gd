const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Splitter / Fragmenter visual identity:
# - heavy unstable fire-armored entity
# - cracked containment shell with volatile core
# - reads as "will split on death" without adding particles or gameplay work
# - draw-only: no nodes, particles, tweens, timers, or gameplay state changes

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	if result.size() > 0:
		result.append(result[0])
	return result

static func _draw_poly_outline(enemy: Node2D, points: PackedVector2Array, fill: Color, outline: Color, outline_width: float = 1.0) -> void:
	enemy.draw_colored_polygon(points, fill)
	enemy.draw_polyline(_closed(points), outline, outline_width, true)

static func _fire_color(base: Color, health_state: int) -> Color:
	# Fire armor should stay hot/volatile, while damage tint can still communicate low HP.
	var c := Color(base.r, base.g, base.b, base.a)
	if health_state == 1:
		c = c.lerp(Color(1.0, 0.58, 0.18, c.a), 0.22)
	elif health_state >= 2:
		c = c.lerp(Color(1.0, 0.18, 0.08, c.a), 0.38)
	return c

static func _draw_containment_crack(enemy: Node2D, start: Vector2, mid: Vector2, end: Vector2, color: Color, width: float) -> void:
	enemy.draw_line(start, mid, color, width)
	enemy.draw_line(mid, end, color, width * 0.82)

static func draw_simple(enemy: Node2D, size: float) -> void:
	var health_state: int = int(enemy.get("health_visual_state"))

	var shell := _fire_color(Color(0.78, 0.30, 0.10, 0.94), health_state)
	var hot := _fire_color(Color(1.0, 0.55, 0.12, 0.92), health_state)
	var core := Color(1.0, 0.82, 0.30, 0.96)
	var outline := Color(0.09, 0.035, 0.02, 0.95)

	# Compact heavy diamond/hex shell: cheap but distinct from Basic.
	var body := PackedVector2Array([
		Vector2(0.0, -size * 1.04),
		Vector2(size * 0.84, -size * 0.36),
		Vector2(size * 0.72, size * 0.58),
		Vector2(0.0, size * 0.96),
		Vector2(-size * 0.72, size * 0.58),
		Vector2(-size * 0.84, -size * 0.36),
	])
	_draw_poly_outline(enemy, B.scale_polygon(body, 1.08), outline, outline, 1.0)
	_draw_poly_outline(enemy, body, shell, Color(0.18, 0.07, 0.025, 0.90), 1.0)

	# Split warning: three fragment cells inside one unstable body.
	enemy.draw_circle(Vector2.ZERO, size * 0.36, Color(0.20, 0.06, 0.02, 0.86))
	enemy.draw_circle(Vector2.ZERO, size * 0.23, core)
	enemy.draw_circle(Vector2(-size * 0.34, size * 0.22), size * 0.13, hot)
	enemy.draw_circle(Vector2(size * 0.34, size * 0.22), size * 0.13, hot)

	var crack := Color(1.0, 0.76, 0.32, 0.80)
	enemy.draw_line(Vector2(0.0, -size * 0.72), Vector2(0.0, -size * 0.25), crack, 1.2)
	enemy.draw_line(Vector2(-size * 0.18, size * 0.03), Vector2(-size * 0.46, size * 0.36), crack, 1.0)
	enemy.draw_line(Vector2(size * 0.18, size * 0.03), Vector2(size * 0.46, size * 0.36), crack, 1.0)

static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var health_state: int = int(enemy.get("health_visual_state"))
	var hp: float = float(enemy.get("hp"))
	var max_hp: float = maxf(float(enemy.get("max_hp")), 1.0)
	var hp_ratio: float = clampf(hp / max_hp, 0.0, 1.0)

	var pulse: float = 0.5 + 0.5 * sin(pulse_time * 5.6)
	var warning: float = 1.0 - hp_ratio

	var outline := Color(0.065, 0.026, 0.012, 0.98)
	var deep_metal := Color(0.16, 0.06, 0.025, 0.95)
	var armor_dark := _fire_color(Color(0.42, 0.16, 0.06, 0.96), health_state)
	var armor_mid := _fire_color(Color(0.72, 0.27, 0.09, 0.96), health_state)
	var armor_hot := _fire_color(Color(1.0, 0.48, 0.11, 0.94), health_state)
	var core_hot := Color(1.0, 0.80, 0.22, 0.92)
	var crack_color := Color(1.0, 0.74, 0.24, 0.72 + pulse * 0.18)

	# Heavy unstable containment shell. Larger/wider than Basic, but not Tank-like tread mass.
	var outer := PackedVector2Array([
		Vector2(0.0, -size * 1.16),
		Vector2(size * 0.70, -size * 0.78),
		Vector2(size * 1.02, -size * 0.12),
		Vector2(size * 0.82, size * 0.64),
		Vector2(size * 0.30, size * 1.03),
		Vector2(-size * 0.30, size * 1.03),
		Vector2(-size * 0.82, size * 0.64),
		Vector2(-size * 1.02, -size * 0.12),
		Vector2(-size * 0.70, -size * 0.78),
	])
	_draw_poly_outline(enemy, B.scale_polygon(outer, 1.10), outline, outline, 1.2)
	_draw_poly_outline(enemy, outer, armor_dark, Color(0.21, 0.075, 0.025, 0.92), 1.1)

	# Side fragment armor plates imply it can break into smaller nodes.
	var left_plate := PackedVector2Array([
		Vector2(-size * 0.86, -size * 0.20),
		Vector2(-size * 0.48, -size * 0.54),
		Vector2(-size * 0.22, size * 0.04),
		Vector2(-size * 0.48, size * 0.48),
		Vector2(-size * 0.84, size * 0.36),
	])
	var right_plate := PackedVector2Array([
		Vector2(size * 0.86, -size * 0.20),
		Vector2(size * 0.48, -size * 0.54),
		Vector2(size * 0.22, size * 0.04),
		Vector2(size * 0.48, size * 0.48),
		Vector2(size * 0.84, size * 0.36),
	])
	_draw_poly_outline(enemy, left_plate, armor_mid, deep_metal, 0.9)
	_draw_poly_outline(enemy, right_plate, armor_mid, deep_metal, 0.9)

	# Top/bottom clamp plates keep it cyber-industrial instead of organic.
	var top_clamp := PackedVector2Array([
		Vector2(-size * 0.44, -size * 0.78),
		Vector2(0.0, -size * 1.02),
		Vector2(size * 0.44, -size * 0.78),
		Vector2(size * 0.26, -size * 0.52),
		Vector2(-size * 0.26, -size * 0.52),
	])
	var bottom_clamp := PackedVector2Array([
		Vector2(-size * 0.36, size * 0.62),
		Vector2(size * 0.36, size * 0.62),
		Vector2(size * 0.24, size * 0.88),
		Vector2(0.0, size * 0.98),
		Vector2(-size * 0.24, size * 0.88),
	])
	_draw_poly_outline(enemy, top_clamp, Color(0.92, 0.35, 0.10, 0.94), deep_metal, 0.8)
	_draw_poly_outline(enemy, bottom_clamp, Color(0.56, 0.20, 0.07, 0.94), deep_metal, 0.8)

	# Volatile multi-core. Three inner nodes preview split_on_death without spawning visual objects.
	enemy.draw_circle(Vector2.ZERO, size * 0.46, Color(0.12, 0.04, 0.015, 0.92))
	enemy.draw_circle(Vector2.ZERO, size * (0.34 + pulse * 0.025), Color(0.92, 0.25, 0.06, 0.86))
	enemy.draw_circle(Vector2.ZERO, size * 0.23, core_hot)
	enemy.draw_circle(Vector2(-size * 0.31, size * 0.23), size * 0.15, armor_hot)
	enemy.draw_circle(Vector2(size * 0.31, size * 0.23), size * 0.15, armor_hot)
	enemy.draw_line(Vector2(-size * 0.19, size * 0.14), Vector2(-size * 0.06, size * 0.05), Color(1.0, 0.67, 0.20, 0.62), 1.0)
	enemy.draw_line(Vector2(size * 0.19, size * 0.14), Vector2(size * 0.06, size * 0.05), Color(1.0, 0.67, 0.20, 0.62), 1.0)

	# Containment cracks: few bold lines, no noisy web of micro-lines.
	_draw_containment_crack(
		enemy,
		Vector2(0.0, -size * 0.88),
		Vector2(size * 0.06, -size * 0.44),
		Vector2(-size * 0.07, -size * 0.16),
		crack_color,
		1.35
	)
	_draw_containment_crack(
		enemy,
		Vector2(-size * 0.16, size * 0.03),
		Vector2(-size * 0.48, size * 0.33),
		Vector2(-size * 0.66, size * 0.50),
		crack_color,
		1.15
	)
	_draw_containment_crack(
		enemy,
		Vector2(size * 0.16, size * 0.03),
		Vector2(size * 0.48, size * 0.33),
		Vector2(size * 0.66, size * 0.50),
		crack_color,
		1.15
	)

	# Small cyber vents, not particle flames.
	var vent_alpha: float = 0.45 + pulse * 0.20
	enemy.draw_line(Vector2(-size * 0.58, -size * 0.03), Vector2(-size * 0.76, -size * 0.03), Color(1.0, 0.42, 0.09, vent_alpha), 1.4)
	enemy.draw_line(Vector2(size * 0.58, -size * 0.03), Vector2(size * 0.76, -size * 0.03), Color(1.0, 0.42, 0.09, vent_alpha), 1.4)
	enemy.draw_line(Vector2(-size * 0.24, size * 0.76), Vector2(size * 0.24, size * 0.76), Color(1.0, 0.52, 0.12, 0.42), 1.2)

	# Low-HP warning ring is compact and conditional, communicating imminent fragmentation.
	if hp_ratio < 0.35:
		var warn_alpha: float = 0.25 + warning * 0.32 + pulse * 0.12
		enemy.draw_arc(Vector2.ZERO, size * 1.22, -PI * 0.18, PI * 0.80, 18, Color(1.0, 0.22, 0.06, warn_alpha), 1.5)
		enemy.draw_arc(Vector2.ZERO, size * 1.22, PI * 0.92, PI * 1.84, 18, Color(1.0, 0.58, 0.12, warn_alpha * 0.82), 1.2)
