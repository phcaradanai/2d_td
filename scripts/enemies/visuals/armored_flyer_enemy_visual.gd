const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Armored Flyer / Heavy Drone
# - air / heavy / armored
# - earth armor
# - tough aerial unit designed to absorb anti-air fire
# Visual-only renderer: no particles, timers, tweens, child nodes, or gameplay mutation.

const EARTH_ARMOR := Color(0.46, 0.38, 0.24, 0.98)
const EARTH_PLATE := Color(0.64, 0.53, 0.32, 0.96)
const DARK_METAL := Color(0.065, 0.070, 0.082, 0.98)
const DEEP_TRIM := Color(0.020, 0.018, 0.014, 0.96)
const CORE_CYAN := Color(0.42, 0.90, 1.00, 0.92)
const ENGINE_GLOW := Color(0.95, 0.66, 0.26, 0.42)
const AIR_SHADOW := Color(0.0, 0.0, 0.0, 0.20)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	if result.size() > 0:
		result.append(result[0])
	return result


static func _outline_poly(enemy: Node2D, points: PackedVector2Array, fill: Color, outline: Color, width: float = 1.0) -> void:
	enemy.draw_colored_polygon(points, fill)
	enemy.draw_polyline(_closed(points), outline, width, true)


static func _earth_tint(color: Color, health_state: int) -> Color:
	if health_state <= 0:
		return color
	if health_state == 1:
		return color.lerp(Color(0.95, 0.55, 0.18, color.a), 0.22)
	return color.lerp(Color(1.0, 0.22, 0.08, color.a), 0.36)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var hp_state := int(enemy.get("health_visual_state"))
	var armor := _earth_tint(EARTH_ARMOR, hp_state)
	var plate := _earth_tint(EARTH_PLATE, hp_state)
	var core := B.apply_health_tint(CORE_CYAN, hp_state)

	# Heavy air shadow: bigger and lower than the scout/interceptor versions.
	enemy.draw_circle(Vector2(0.0, size * 0.84), size * 0.52, AIR_SHADOW)

	var left_pod := PackedVector2Array([
		Vector2(-size * 0.34, -size * 0.16),
		Vector2(-size * 1.12, -size * 0.42),
		Vector2(-size * 1.04, size * 0.22),
		Vector2(-size * 0.34, size * 0.42),
	])
	var right_pod := PackedVector2Array([
		Vector2(size * 0.34, -size * 0.16),
		Vector2(size * 1.12, -size * 0.42),
		Vector2(size * 1.04, size * 0.22),
		Vector2(size * 0.34, size * 0.42),
	])
	var body := PackedVector2Array([
		Vector2(0.0, -size * 0.82),
		Vector2(size * 0.58, -size * 0.44),
		Vector2(size * 0.66, size * 0.42),
		Vector2(size * 0.30, size * 0.72),
		Vector2(-size * 0.30, size * 0.72),
		Vector2(-size * 0.66, size * 0.42),
		Vector2(-size * 0.58, -size * 0.44),
	])

	enemy.draw_colored_polygon(B.scale_polygon(left_pod, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(B.scale_polygon(right_pod, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(left_pod, Color(armor.r, armor.g, armor.b, 0.62))
	enemy.draw_colored_polygon(right_pod, Color(armor.r, armor.g, armor.b, 0.62))

	enemy.draw_colored_polygon(B.scale_polygon(body, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, DARK_METAL)

	var plate_poly := PackedVector2Array([
		Vector2(0.0, -size * 0.56),
		Vector2(size * 0.42, -size * 0.26),
		Vector2(size * 0.38, size * 0.30),
		Vector2(0.0, size * 0.50),
		Vector2(-size * 0.38, size * 0.30),
		Vector2(-size * 0.42, -size * 0.26),
	])
	enemy.draw_colored_polygon(plate_poly, plate)

	enemy.draw_circle(Vector2.ZERO, size * 0.28, DEEP_TRIM)
	enemy.draw_circle(Vector2.ZERO, size * 0.17, core)
	enemy.draw_circle(Vector2(-size * 0.055, -size * 0.065), size * 0.055, Color.WHITE)


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time := float(enemy.get("pulse_time"))
	var hp_state := int(enemy.get("health_visual_state"))
	var pulse := 0.5 + 0.5 * sin(pulse_time * 3.2)
	var hover := sin(pulse_time * 2.4) * size * 0.035

	var armor := _earth_tint(EARTH_ARMOR, hp_state)
	var plate := _earth_tint(EARTH_PLATE, hp_state)
	var core := B.apply_health_tint(CORE_CYAN, hp_state)
	var engine := B.apply_health_tint(ENGINE_GLOW, hp_state)

	# Heavy floating mass, but still cheap: one shadow circle only.
	enemy.draw_circle(Vector2(0.0, size * 0.88), size * 0.62, AIR_SHADOW)

	# Armored lift pods. These are not thin wings; they read as heavy anti-air armor.
	var left_pod := PackedVector2Array([
		Vector2(-size * 0.36, -size * 0.28 + hover),
		Vector2(-size * 1.34, -size * 0.52),
		Vector2(-size * 1.24, size * 0.18),
		Vector2(-size * 0.78, size * 0.48),
		Vector2(-size * 0.34, size * 0.34 + hover),
	])
	var right_pod := PackedVector2Array([
		Vector2(size * 0.36, -size * 0.28 + hover),
		Vector2(size * 1.34, -size * 0.52),
		Vector2(size * 1.24, size * 0.18),
		Vector2(size * 0.78, size * 0.48),
		Vector2(size * 0.34, size * 0.34 + hover),
	])
	enemy.draw_colored_polygon(B.scale_polygon(left_pod, 1.07), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(B.scale_polygon(right_pod, 1.07), B.ENEMY_OUTLINE_COLOR)
	_outline_poly(enemy, left_pod, Color(armor.r, armor.g, armor.b, 0.70), DEEP_TRIM, 0.95)
	_outline_poly(enemy, right_pod, Color(armor.r, armor.g, armor.b, 0.70), DEEP_TRIM, 0.95)

	# Lift engines: small embedded glows, not trails/particles.
	enemy.draw_circle(Vector2(-size * 0.94, size * 0.14), size * (0.145 + pulse * 0.018), engine)
	enemy.draw_circle(Vector2(size * 0.94, size * 0.14), size * (0.145 + pulse * 0.018), engine)
	enemy.draw_circle(Vector2(-size * 0.94, size * 0.14), size * 0.075, Color(0.96, 0.88, 0.58, 0.62))
	enemy.draw_circle(Vector2(size * 0.94, size * 0.14), size * 0.075, Color(0.96, 0.88, 0.58, 0.62))

	# Central armored hull: squat, broad, and protected.
	var hull := PackedVector2Array([
		Vector2(0.0, -size * 0.92 + hover),
		Vector2(size * 0.66, -size * 0.56),
		Vector2(size * 0.78, size * 0.30),
		Vector2(size * 0.40, size * 0.76),
		Vector2(0.0, size * 0.88),
		Vector2(-size * 0.40, size * 0.76),
		Vector2(-size * 0.78, size * 0.30),
		Vector2(-size * 0.66, -size * 0.56),
	])
	enemy.draw_colored_polygon(B.scale_polygon(hull, 1.075), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(hull, DARK_METAL)

	var front_armor := PackedVector2Array([
		Vector2(0.0, -size * 0.66 + hover),
		Vector2(size * 0.48, -size * 0.35),
		Vector2(size * 0.44, size * 0.28),
		Vector2(size * 0.20, size * 0.56),
		Vector2(-size * 0.20, size * 0.56),
		Vector2(-size * 0.44, size * 0.28),
		Vector2(-size * 0.48, -size * 0.35),
	])
	_outline_poly(enemy, front_armor, plate, Color(0.06, 0.048, 0.032, 0.88), 1.05)

	# Reinforced earth plates, few but clear.
	enemy.draw_line(Vector2(-size * 0.42, -size * 0.18), Vector2(size * 0.42, -size * 0.18), Color(0.95, 0.78, 0.38, 0.34), 1.15, true)
	enemy.draw_line(Vector2(-size * 0.34, size * 0.22), Vector2(size * 0.34, size * 0.22), Color(0.0, 0.0, 0.0, 0.36), 1.0, true)
	enemy.draw_line(Vector2(-size * 0.58, -size * 0.44), Vector2(-size * 0.22, size * 0.52), Color(0.0, 0.0, 0.0, 0.28), 1.0, true)
	enemy.draw_line(Vector2(size * 0.58, -size * 0.44), Vector2(size * 0.22, size * 0.52), Color(0.0, 0.0, 0.0, 0.28), 1.0, true)

	# Protected anti-air core: brighter but encased.
	enemy.draw_circle(Vector2.ZERO, size * 0.34, DEEP_TRIM)
	enemy.draw_circle(Vector2.ZERO, size * 0.245, Color(core.r, core.g, core.b, 0.38 + pulse * 0.10))
	enemy.draw_circle(Vector2.ZERO, size * 0.145, Color(core.r, core.g, core.b, 0.92))
	enemy.draw_circle(Vector2(-size * 0.055, -size * 0.070), size * 0.050, Color.WHITE)

	# Small armored sensor crown; helps differentiate from the standard Cyber Drone.
	var crown := PackedVector2Array([
		Vector2(-size * 0.20, -size * 0.70 + hover),
		Vector2(0.0, -size * 0.94 + hover),
		Vector2(size * 0.20, -size * 0.70 + hover),
	])
	_outline_poly(enemy, crown, Color(0.76, 0.64, 0.38, 0.90), DEEP_TRIM, 0.85)
