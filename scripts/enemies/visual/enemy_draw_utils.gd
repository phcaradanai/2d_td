class_name EnemyDrawUtils
extends RefCounted

static func _scale_polygon(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		var dir := point.normalized()
		out.append(point + dir * amount)
	return out


static func _apply_health_tint(enemy: Node2D, base_color: Color) -> Color:
	match enemy.health_visual_state:
		enemy.HealthVisualState.HEALTH_DAMAGED:
			return base_color.lerp(Color(1.0, 0.45, 0.10, base_color.a), 0.34)
		enemy.HealthVisualState.HEALTH_CRITICAL:
			return base_color.lerp(Color(1.0, 0.08, 0.04, base_color.a), 0.55)
		_:
			return base_color


static func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, count: int = 28, p_rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		var a: float = float(i) / float(count) * TAU
		var p := Vector2(cos(a) * radius_x, sin(a) * radius_y).rotated(p_rotation)
		pts.append(center + p)
	return pts


static func _transform_points(points: PackedVector2Array, angle: float, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var t := Transform2D(angle, offset)
	for p in points:
		out.append(t * p)
	return out



static func _mirror_points_y(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x, -p.y))
	return out

static func _draw_runner_role_telegraph(enemy: Node2D, size: float) -> void:
	var danger_color := Color(1.0, 0.35, 0.05, 1.0)
	var pulse: float = 0.5 + sin(enemy.pulse_time * 12.0) * 0.5
	var dash_charge: float = 1.0 - clampf(enemy.runner_dash_timer / maxf(enemy.runner_dash_cooldown, 0.01), 0.0, 1.0)
	var ring_alpha: float = 0.05 + dash_charge * 0.16

	# Small charge ring: tells the player Runner has a timed burst, without creating a huge range UI.
	enemy.draw_arc(Vector2.ZERO, size * (1.35 + dash_charge * 0.28), -PI * 0.85, PI * 0.85, 36, Color(danger_color.r, danger_color.g, danger_color.b, ring_alpha), 1.1, true)

	if enemy.runner_dash_remaining > 0.0:
		var dash_alpha: float = 0.22 + pulse * 0.18
		enemy.draw_circle(Vector2.ZERO, size * 1.55, Color(danger_color.r, danger_color.g, danger_color.b, 0.08 + pulse * 0.04))
		enemy.draw_line(Vector2(-size * 0.9, 0), Vector2(-size * 3.2, 0), Color(danger_color.r, danger_color.g, danger_color.b, dash_alpha), 4.0, true)
		enemy.draw_line(Vector2(-size * 0.5, -size * 0.45), Vector2(-size * 2.5, -size * 0.85), Color(1.0, 0.75, 0.2, dash_alpha * 0.7), 1.4, true)
		enemy.draw_line(Vector2(-size * 0.5, size * 0.45), Vector2(-size * 2.5, size * 0.85), Color(1.0, 0.75, 0.2, dash_alpha * 0.7), 1.4, true)

	if enemy.runner_panic_active:
		# Panic mode should read as dangerous and unstable: orange/red breathing halo.
		enemy.draw_arc(Vector2.ZERO, size * (1.75 + pulse * 0.22), 0.0, TAU, 40, Color(1.0, 0.12, 0.04, 0.22 + pulse * 0.08), 1.6, true)
		enemy.draw_circle(Vector2(size * 0.58, 0), size * (0.18 + pulse * 0.06), Color(1.0, 0.9, 0.45, 0.75))


