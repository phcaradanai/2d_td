const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Viral Predator
# - Darkness armor
# - Anti-hero / fast / danger identity
# - Draw-only, no particles/timers/tweens/child nodes

static func draw_simple(enemy: Node2D, size: float) -> void:
	var hp_state: int = int(enemy.get("health_visual_state"))
	var base := B.apply_health_tint(Color(0.62, 0.05, 0.92, 1.0), hp_state)
	var core := B.apply_health_tint(Color(1.0, 0.12, 0.36, 1.0), hp_state)
	var body := PackedVector2Array([
		Vector2(size * 1.16, 0.0),
		Vector2(size * 0.42, -size * 0.42),
		Vector2(-size * 0.70, -size * 0.70),
		Vector2(-size * 0.36, 0.0),
		Vector2(-size * 0.70, size * 0.70),
		Vector2(size * 0.42, size * 0.42)
	])
	var body_outline := B.scale_polygon(body, B.ENEMY_OUTLINE_THICKNESS)
	enemy.draw_colored_polygon(body_outline, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, Color(base.r, base.g, base.b, 0.88))
	enemy.draw_line(Vector2(-size * 0.44, -size * 0.48), Vector2(size * 0.48, 0.0), Color(0.02, 0.0, 0.035, 0.72), 1.45)
	enemy.draw_line(Vector2(-size * 0.44, size * 0.48), Vector2(size * 0.48, 0.0), Color(0.02, 0.0, 0.035, 0.72), 1.45)
	enemy.draw_circle(Vector2(size * 0.30, 0.0), size * 0.16, Color(core.r, core.g, core.b, 0.88))
	enemy.draw_circle(Vector2(size * 0.30, 0.0), size * 0.055, Color(1.0, 0.86, 0.94, 0.95))


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var hp_state: int = int(enemy.get("health_visual_state"))
	var phase: float = float(enemy.get_instance_id() % 97) * 0.071
	var pulse: float = 0.5 + sin(pulse_time * 6.0 + phase) * 0.5
	var blink: float = 0.5 + sin(pulse_time * 13.0 + phase * 1.7) * 0.5
	var gait: float = sin(pulse_time * 8.0 + phase) * size * 0.045
	var origin := Vector2(sin(pulse_time * 4.4 + phase) * size * 0.018, sin(pulse_time * 7.0 + phase) * size * 0.025)

	var dark_shell := B.apply_health_tint(Color(0.070, 0.045, 0.115, 1.0), hp_state)
	var night_plate := B.apply_health_tint(Color(0.145, 0.065, 0.230, 1.0), hp_state)
	var void_trim := Color(0.012, 0.006, 0.026, 1.0)
	var predator_violet := B.apply_health_tint(Color(0.66, 0.06, 0.98, 1.0), hp_state)
	var danger_red := B.apply_health_tint(Color(1.0, 0.10, 0.31, 1.0), hp_state)
	var hot_core := Color(1.0, 0.66, 0.90, 1.0)
	var cyan_ping := Color(0.23, 0.95, 1.0, 1.0)

	_draw_ground_shadow(enemy, origin, size)
	_draw_stalker_legs(enemy, origin, size, void_trim, predator_violet, gait)
	_draw_predator_hull(enemy, origin, size, dark_shell, night_plate, void_trim, predator_violet, danger_red, pulse)
	_draw_hunter_core(enemy, origin, size, danger_red, hot_core, cyan_ping, pulse, blink)
	_draw_claws(enemy, origin, size, danger_red, hot_core, pulse)
	_draw_tail_spikes(enemy, origin, size, void_trim, predator_violet, danger_red)
	_draw_role_marker(enemy, size, pulse_time, pulse)


static func _draw_ground_shadow(enemy: Node2D, origin: Vector2, size: float) -> void:
	var shadow := PackedVector2Array()
	for i in range(12):
		var a: float = float(i) * TAU / 12.0
		shadow.append(origin + Vector2(cos(a) * size * 1.26, sin(a) * size * 0.42) + Vector2(0.0, size * 0.55))
	enemy.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.24))


static func _draw_stalker_legs(enemy: Node2D, origin: Vector2, size: float, trim: Color, neon: Color, gait: float) -> void:
	var anchors := [
		Vector2(-size * 0.46, -size * 0.38),
		Vector2(size * 0.02, -size * 0.34),
		Vector2(-size * 0.46, size * 0.38),
		Vector2(size * 0.02, size * 0.34)
	]
	for i in range(anchors.size()):
		var side: float = -1.0 if i < 2 else 1.0
		var stride: float = gait if (i % 2 == 0) else -gait
		var hip: Vector2 = origin + anchors[i]
		var knee: Vector2 = hip + Vector2(-size * 0.24 + stride, side * size * 0.30)
		var foot: Vector2 = knee + Vector2(size * 0.16 + stride * 0.35, side * size * 0.24)
		enemy.draw_line(hip, knee, trim, 3.1)
		enemy.draw_line(knee, foot, trim, 2.45)
		enemy.draw_line(hip, knee, Color(neon.r, neon.g, neon.b, 0.34), 1.05)
		enemy.draw_circle(foot, size * 0.045, Color(0.0, 0.0, 0.0, 0.54))


static func _draw_predator_hull(
	enemy: Node2D,
	origin: Vector2,
	size: float,
	dark_shell: Color,
	night_plate: Color,
	void_trim: Color,
	predator_violet: Color,
	danger_red: Color,
	pulse: float
) -> void:
	var outer := PackedVector2Array([
		origin + Vector2(size * 1.38, 0.0),
		origin + Vector2(size * 0.56, -size * 0.42),
		origin + Vector2(-size * 0.34, -size * 0.58),
		origin + Vector2(-size * 1.04, -size * 0.86),
		origin + Vector2(-size * 0.62, 0.0),
		origin + Vector2(-size * 1.04, size * 0.86),
		origin + Vector2(-size * 0.34, size * 0.58),
		origin + Vector2(size * 0.56, size * 0.42)
	])
	var outline := B.scale_polygon(outer, B.ENEMY_OUTLINE_THICKNESS + 0.08)
	enemy.draw_colored_polygon(outline, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(outer, dark_shell)

	var inner_spine := PackedVector2Array([
		origin + Vector2(size * 1.06, 0.0),
		origin + Vector2(size * 0.34, -size * 0.15),
		origin + Vector2(-size * 0.40, -size * 0.12),
		origin + Vector2(-size * 0.58, 0.0),
		origin + Vector2(-size * 0.40, size * 0.12),
		origin + Vector2(size * 0.34, size * 0.15)
	])
	enemy.draw_colored_polygon(inner_spine, Color(0.0, 0.0, 0.0, 0.50))

	var top_plate := PackedVector2Array([
		origin + Vector2(size * 0.55, -size * 0.36),
		origin + Vector2(-size * 0.26, -size * 0.47),
		origin + Vector2(-size * 0.82, -size * 0.72),
		origin + Vector2(-size * 0.48, -size * 0.24),
		origin + Vector2(size * 0.36, -size * 0.13)
	])
	var bot_plate := PackedVector2Array([
		origin + Vector2(size * 0.55, size * 0.36),
		origin + Vector2(-size * 0.26, size * 0.47),
		origin + Vector2(-size * 0.82, size * 0.72),
		origin + Vector2(-size * 0.48, size * 0.24),
		origin + Vector2(size * 0.36, size * 0.13)
	])
	enemy.draw_colored_polygon(top_plate, night_plate)
	enemy.draw_colored_polygon(bot_plate, night_plate)
	enemy.draw_polyline(_closed(top_plate), Color(predator_violet.r, predator_violet.g, predator_violet.b, 0.40), 1.0)
	enemy.draw_polyline(_closed(bot_plate), Color(predator_violet.r, predator_violet.g, predator_violet.b, 0.40), 1.0)

	var mask := PackedVector2Array([
		origin + Vector2(size * 0.92, -size * 0.20),
		origin + Vector2(size * 1.28, 0.0),
		origin + Vector2(size * 0.92, size * 0.20),
		origin + Vector2(size * 0.58, size * 0.10),
		origin + Vector2(size * 0.58, -size * 0.10)
	])
	enemy.draw_colored_polygon(mask, void_trim)
	enemy.draw_polyline(_closed(mask), Color(danger_red.r, danger_red.g, danger_red.b, 0.62 + pulse * 0.18), 1.1)

	enemy.draw_polyline(_closed(outer), Color(0.0, 0.0, 0.0, 0.82), 3.25)
	enemy.draw_polyline(_closed(outer), Color(predator_violet.r, predator_violet.g, predator_violet.b, 0.70), 1.35)


static func _draw_hunter_core(
	enemy: Node2D,
	origin: Vector2,
	size: float,
	danger_red: Color,
	hot_core: Color,
	cyan_ping: Color,
	pulse: float,
	blink: float
) -> void:
	var core_pos := origin + Vector2(size * 0.18, 0.0)
	var frame := PackedVector2Array()
	for i in range(6):
		var a: float = PI / 6.0 + float(i) * TAU / 6.0
		frame.append(core_pos + Vector2(cos(a), sin(a)) * size * 0.31)
	enemy.draw_colored_polygon(frame, Color(0.015, 0.0, 0.035, 0.96))
	enemy.draw_polyline(_closed(frame), Color(danger_red.r, danger_red.g, danger_red.b, 0.84), 1.25)
	enemy.draw_circle(core_pos, size * (0.22 + pulse * 0.025), Color(danger_red.r, danger_red.g, danger_red.b, 0.18 + pulse * 0.06))
	enemy.draw_circle(core_pos, size * 0.125, Color(danger_red.r, danger_red.g, danger_red.b, 0.92))
	enemy.draw_circle(core_pos + Vector2(size * 0.035, -size * 0.030), size * 0.045, Color(hot_core.r, hot_core.g, hot_core.b, 0.96))
	if blink > 0.76:
		enemy.draw_circle(core_pos + Vector2(size * 0.22, 0.0), size * 0.030, Color(cyan_ping.r, cyan_ping.g, cyan_ping.b, 0.75))


static func _draw_claws(enemy: Node2D, origin: Vector2, size: float, danger_red: Color, hot_core: Color, pulse: float) -> void:
	var top_claw := PackedVector2Array([
		origin + Vector2(size * 0.82, -size * 0.18),
		origin + Vector2(size * 1.22, -size * 0.40),
		origin + Vector2(size * 1.02, -size * 0.12)
	])
	var bot_claw := PackedVector2Array([
		origin + Vector2(size * 0.82, size * 0.18),
		origin + Vector2(size * 1.22, size * 0.40),
		origin + Vector2(size * 1.02, size * 0.12)
	])
	var alpha: float = 0.50 + pulse * 0.22
	enemy.draw_colored_polygon(top_claw, Color(danger_red.r, danger_red.g, danger_red.b, alpha))
	enemy.draw_colored_polygon(bot_claw, Color(danger_red.r, danger_red.g, danger_red.b, alpha))
	enemy.draw_line(origin + Vector2(size * 0.92, 0.0), origin + Vector2(size * 1.34, 0.0), Color(hot_core.r, hot_core.g, hot_core.b, 0.72), 1.05)


static func _draw_tail_spikes(enemy: Node2D, origin: Vector2, size: float, trim: Color, violet: Color, red: Color) -> void:
	var upper := PackedVector2Array([
		origin + Vector2(-size * 0.75, -size * 0.50),
		origin + Vector2(-size * 1.34, -size * 0.72),
		origin + Vector2(-size * 0.98, -size * 0.34)
	])
	var lower := PackedVector2Array([
		origin + Vector2(-size * 0.75, size * 0.50),
		origin + Vector2(-size * 1.34, size * 0.72),
		origin + Vector2(-size * 0.98, size * 0.34)
	])
	enemy.draw_colored_polygon(upper, trim)
	enemy.draw_colored_polygon(lower, trim)
	enemy.draw_polyline(_closed(upper), Color(violet.r, violet.g, violet.b, 0.55), 0.9)
	enemy.draw_polyline(_closed(lower), Color(violet.r, violet.g, violet.b, 0.55), 0.9)
	enemy.draw_line(origin + Vector2(-size * 0.88, 0.0), origin + Vector2(-size * 1.22, 0.0), Color(red.r, red.g, red.b, 0.40), 1.0)


static func _draw_role_marker(enemy: Node2D, size: float, pulse_time: float, pulse: float) -> void:
	var hunter_state: int = int(enemy.get("hunter_state"))
	var hunter_target = enemy.get("hunter_target")
	var is_locked: bool = hunter_state != 0 and hunter_target != null and is_instance_valid(hunter_target)

	var radius: float = size * 1.58
	var base_color := Color(0.55, 0.05, 1.0, 0.11)
	if is_locked:
		base_color = Color(1.0, 0.11, 0.25, 0.18 + pulse * 0.08)
	enemy.draw_arc(Vector2.ZERO, radius, -PI * 0.12, TAU - PI * 0.12, 34, base_color, 0.85, true)

	if is_locked:
		var angle_to_target: float = 0.0
		var target_pos = hunter_target.get("global_position") if hunter_target != null else null
		if target_pos is Vector2:
			angle_to_target = (target_pos - enemy.global_position).angle()
		var dir := Vector2(cos(angle_to_target), sin(angle_to_target))
		var p0 := dir * (radius * 0.70)
		var p1 := dir * (radius * 1.05)
		enemy.draw_line(p0, p1, Color(1.0, 0.14, 0.24, 0.72), 1.45)
		enemy.draw_circle(p1, size * 0.06, Color(1.0, 0.72, 0.82, 0.72))
	else:
		var scan_angle: float = pulse_time * 2.4
		var dir := Vector2(cos(scan_angle), sin(scan_angle))
		enemy.draw_line(dir * (radius * 0.58), dir * radius, Color(0.60, 0.12, 1.0, 0.34), 1.0)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p)
	if points.size() > 0:
		result.append(points[0])
	return result
