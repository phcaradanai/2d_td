const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Repair Drone / Healer
# Design intent:
# - Support + healing identity from enemies.json.
# - Water armor palette: aqua / blue / clean repair glow.
# - Premium cyber-medical drone silhouette, not a generic green triangle.
# - Draw-only, no particles/timers/tweens/child nodes.

const BODY_DARK := Color(0.035, 0.075, 0.095, 0.96)
const WATER_ARMOR := Color(0.25, 0.82, 0.92, 0.92)
const WATER_CORE := Color(0.60, 1.00, 0.88, 1.0)
const REPAIR_WHITE := Color(0.86, 1.00, 0.96, 0.95)
const MED_GOLD := Color(0.94, 0.82, 0.42, 0.92)
const TRIM_BLUE := Color(0.10, 0.36, 0.56, 0.86)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var armor := B.apply_health_tint(WATER_ARMOR, int(enemy.get("health_visual_state")))
	var body := _body_points(size)

	# Strong readable cyber-medical silhouette.
	enemy.draw_colored_polygon(B.scale_polygon(body, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, Color(BODY_DARK.r, BODY_DARK.g, BODY_DARK.b, 0.92))

	# Cheap side repair pods.
	enemy.draw_circle(Vector2(-size * 0.62, size * 0.04), size * 0.18, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2(size * 0.62, size * 0.04), size * 0.18, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2(-size * 0.62, size * 0.04), size * 0.105, Color(armor.r, armor.g, armor.b, 0.88))
	enemy.draw_circle(Vector2(size * 0.62, size * 0.04), size * 0.105, Color(armor.r, armor.g, armor.b, 0.88))

	# Center repair core + compact plus mark.
	enemy.draw_circle(Vector2.ZERO, size * 0.34, Color(armor.r, armor.g, armor.b, 0.24))
	enemy.draw_circle(Vector2.ZERO, size * 0.21, WATER_CORE)
	_draw_plus(enemy, Vector2.ZERO, size * 0.18, REPAIR_WHITE, max(1.4, size * 0.095))


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var pulse := 0.5 + 0.5 * sin(pulse_time * 2.2)
	var armor := B.apply_health_tint(WATER_ARMOR, int(enemy.get("health_visual_state")))

	var body := _body_points(size)
	var inner := _inner_plate_points(size)

	# Ground shadow: small and cheap, gives premium depth without a particle.
	enemy.draw_circle(Vector2(0.0, size * 0.40), size * 0.74, Color(0.0, 0.0, 0.0, 0.16))

	# Main armored medical drone shell.
	enemy.draw_colored_polygon(B.scale_polygon(body, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, BODY_DARK)

	# Water armor panels.
	enemy.draw_colored_polygon(inner, Color(armor.r, armor.g, armor.b, 0.34))
	enemy.draw_polyline(_closed(inner), Color(armor.r, armor.g, armor.b, 0.82), 1.6)

	# Dark top/bottom clamp plates to make it feel cyber-mechanical.
	var top_plate := PackedVector2Array([
		Vector2(-size * 0.38, -size * 0.54),
		Vector2(size * 0.38, -size * 0.54),
		Vector2(size * 0.25, -size * 0.31),
		Vector2(-size * 0.25, -size * 0.31),
	])
	var bottom_plate := PackedVector2Array([
		Vector2(-size * 0.34, size * 0.44),
		Vector2(size * 0.34, size * 0.44),
		Vector2(size * 0.23, size * 0.62),
		Vector2(-size * 0.23, size * 0.62),
	])
	enemy.draw_colored_polygon(top_plate, Color(TRIM_BLUE.r, TRIM_BLUE.g, TRIM_BLUE.b, 0.78))
	enemy.draw_colored_polygon(bottom_plate, Color(TRIM_BLUE.r, TRIM_BLUE.g, TRIM_BLUE.b, 0.62))

	# Repair emitter pods: signature support identity, cheaper than aura/radius rings.
	_draw_emitter(enemy, Vector2(-size * 0.76, size * 0.02), size, armor, -1.0)
	_draw_emitter(enemy, Vector2(size * 0.76, size * 0.02), size, armor, 1.0)

	# Compact healing halo around the body only. Do not draw skill radius here.
	var halo_alpha := 0.22 + pulse * 0.10
	enemy.draw_arc(Vector2.ZERO, size * 0.82, -0.45, PI + 0.32, 18, Color(WATER_CORE.r, WATER_CORE.g, WATER_CORE.b, halo_alpha), 1.25)
	enemy.draw_arc(Vector2.ZERO, size * 0.66, PI * 0.15, PI * 0.88, 14, Color(MED_GOLD.r, MED_GOLD.g, MED_GOLD.b, 0.34), 1.15)

	# Minimal circuit repair lines.
	enemy.draw_line(Vector2(-size * 0.38, 0.0), Vector2(-size * 0.18, 0.0), Color(WATER_CORE.r, WATER_CORE.g, WATER_CORE.b, 0.62), 1.25)
	enemy.draw_line(Vector2(size * 0.18, 0.0), Vector2(size * 0.38, 0.0), Color(WATER_CORE.r, WATER_CORE.g, WATER_CORE.b, 0.62), 1.25)
	enemy.draw_line(Vector2(0.0, -size * 0.34), Vector2(0.0, -size * 0.18), Color(WATER_CORE.r, WATER_CORE.g, WATER_CORE.b, 0.48), 1.1)

	# Central repair core: main readable focal point.
	enemy.draw_circle(Vector2.ZERO, size * 0.45, Color(WATER_CORE.r, WATER_CORE.g, WATER_CORE.b, 0.16 + pulse * 0.05))
	enemy.draw_circle(Vector2.ZERO, size * 0.30, Color(0.02, 0.12, 0.14, 0.96))
	enemy.draw_circle(Vector2.ZERO, size * 0.22, WATER_CORE)
	enemy.draw_circle(Vector2(-size * 0.06, -size * 0.07), size * 0.055, Color(1.0, 1.0, 1.0, 0.84))

	# Plus mark: instantly communicates healer/repair without expensive VFX.
	_draw_plus(enemy, Vector2.ZERO, size * 0.24, REPAIR_WHITE, max(1.7, size * 0.105))


static func _body_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -size * 0.72),
		Vector2(size * 0.52, -size * 0.48),
		Vector2(size * 0.72, 0.0),
		Vector2(size * 0.46, size * 0.56),
		Vector2(0.0, size * 0.72),
		Vector2(-size * 0.46, size * 0.56),
		Vector2(-size * 0.72, 0.0),
		Vector2(-size * 0.52, -size * 0.48),
	])


static func _inner_plate_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -size * 0.52),
		Vector2(size * 0.40, -size * 0.31),
		Vector2(size * 0.49, size * 0.02),
		Vector2(size * 0.31, size * 0.39),
		Vector2(0.0, size * 0.50),
		Vector2(-size * 0.31, size * 0.39),
		Vector2(-size * 0.49, size * 0.02),
		Vector2(-size * 0.40, -size * 0.31),
	])


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	if points.size() > 0:
		result.append(points[0])
	return result


static func _draw_plus(enemy: Node2D, center: Vector2, radius: float, color: Color, width: float) -> void:
	enemy.draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), color, width)
	enemy.draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), color, width)


static func _draw_emitter(enemy: Node2D, center: Vector2, size: float, armor: Color, direction: float) -> void:
	var pod := PackedVector2Array([
		center + Vector2(-direction * size * 0.08, -size * 0.27),
		center + Vector2(direction * size * 0.22, -size * 0.15),
		center + Vector2(direction * size * 0.22, size * 0.15),
		center + Vector2(-direction * size * 0.08, size * 0.27),
		center + Vector2(-direction * size * 0.25, size * 0.12),
		center + Vector2(-direction * size * 0.25, -size * 0.12),
	])
	enemy.draw_colored_polygon(B.scale_polygon(pod, 1.05), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(pod, Color(0.05, 0.10, 0.12, 0.96))
	enemy.draw_circle(center + Vector2(direction * size * 0.12, 0.0), size * 0.12, Color(armor.r, armor.g, armor.b, 0.70))
	enemy.draw_circle(center + Vector2(direction * size * 0.12, 0.0), size * 0.055, REPAIR_WHITE)
