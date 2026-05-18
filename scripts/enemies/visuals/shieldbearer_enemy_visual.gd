# Shieldbearer Enemy Visual
# State source: support + shield + heavy, Light armor.
# Design intent:
# - Premium cyber escort shield projector.
# - Smaller and more technical than Bulwark Alpha.
# - Communicates shield_aura with compact shield geometry, not full radius VFX.
# - Draw-only: no particles, no timers, no tweens, no child nodes.

const BLACK_TRIM := Color(0.015, 0.018, 0.026, 1.0)
const DEEP_METAL := Color(0.085, 0.095, 0.120, 1.0)
const MID_METAL := Color(0.180, 0.170, 0.135, 1.0)

const LIGHT_ARMOR := Color(0.83, 0.68, 0.30, 1.0)
const LIGHT_PLATE := Color(1.00, 0.86, 0.38, 1.0)
const LIGHT_SHADE := Color(0.45, 0.34, 0.14, 1.0)

const SHIELD_CYAN := Color(0.48, 0.92, 1.00, 1.0)
const SHIELD_GOLD := Color(1.00, 0.93, 0.52, 1.0)
const WHITE_HOT := Color(1.00, 0.98, 0.80, 1.0)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var hp_tint := _health_tint(enemy)
	var s := size * 0.94

	# Simplified escort chassis: shield shape + compact core.
	var body := PackedVector2Array([
		Vector2(-0.78 * s, -0.26 * s),
		Vector2(-0.42 * s, -0.56 * s),
		Vector2(0.42 * s, -0.56 * s),
		Vector2(0.78 * s, -0.26 * s),
		Vector2(0.70 * s, 0.28 * s),
		Vector2(0.30 * s, 0.54 * s),
		Vector2(-0.30 * s, 0.54 * s),
		Vector2(-0.70 * s, 0.28 * s),
	])

	enemy.draw_colored_polygon(body, BLACK_TRIM)
	enemy.draw_colored_polygon(_scale_around(body, Vector2.ZERO, 0.82), _mix(LIGHT_ARMOR, hp_tint, 0.15))

	# Cheap personal shield crown. This differentiates it from Bulwark/Tank in performance mode.
	enemy.draw_arc(Vector2.ZERO, s * 0.74, deg_to_rad(205), deg_to_rad(335), 16, Color(SHIELD_GOLD.r, SHIELD_GOLD.g, SHIELD_GOLD.b, 0.74), max(1.1, size * 0.075), true)
	enemy.draw_arc(Vector2.ZERO, s * 0.58, deg_to_rad(220), deg_to_rad(320), 12, Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, 0.52), max(1.0, size * 0.055), true)

	enemy.draw_circle(Vector2.ZERO, s * 0.20, DEEP_METAL)
	enemy.draw_circle(Vector2.ZERO, s * 0.125, SHIELD_CYAN)
	enemy.draw_circle(Vector2(0.045 * s, -0.045 * s), s * 0.038, WHITE_HOT)


static func draw(enemy: Node2D, size: float) -> void:
	var t := _time(enemy)
	var pulse := 0.5 + 0.5 * sin(t * 2.8)
	var hp_tint := _health_tint(enemy)
	var s := size

	# Ground contact shadow: one polygon, no blur/particles.
	var shadow := PackedVector2Array([
		Vector2(-0.92 * s, 0.50 * s),
		Vector2(-0.42 * s, 0.38 * s),
		Vector2(0.42 * s, 0.38 * s),
		Vector2(0.92 * s, 0.50 * s),
		Vector2(0.40 * s, 0.62 * s),
		Vector2(-0.40 * s, 0.62 * s),
	])
	enemy.draw_colored_polygon(shadow, Color(0, 0, 0, 0.24))

	# Stable support feet. It is heavy/support, but not a wall like Bulwark.
	_draw_projector_foot(enemy, Vector2(-0.46 * s, 0.28 * s), Vector2(-0.78 * s, 0.56 * s), s)
	_draw_projector_foot(enemy, Vector2(0.46 * s, 0.28 * s), Vector2(0.78 * s, 0.56 * s), s)

	# Outer shield-projector chassis: shield/crest silhouette.
	var hull := PackedVector2Array([
		Vector2(-0.92 * s, -0.24 * s),
		Vector2(-0.58 * s, -0.58 * s),
		Vector2(-0.08 * s, -0.72 * s),
		Vector2(0.48 * s, -0.60 * s),
		Vector2(0.88 * s, -0.24 * s),
		Vector2(0.78 * s, 0.28 * s),
		Vector2(0.36 * s, 0.60 * s),
		Vector2(-0.24 * s, 0.64 * s),
		Vector2(-0.76 * s, 0.32 * s),
	])
	enemy.draw_colored_polygon(hull, BLACK_TRIM)

	var hull_inner := PackedVector2Array([
		Vector2(-0.72 * s, -0.19 * s),
		Vector2(-0.45 * s, -0.43 * s),
		Vector2(-0.05 * s, -0.54 * s),
		Vector2(0.36 * s, -0.46 * s),
		Vector2(0.67 * s, -0.18 * s),
		Vector2(0.60 * s, 0.18 * s),
		Vector2(0.28 * s, 0.42 * s),
		Vector2(-0.18 * s, 0.46 * s),
		Vector2(-0.58 * s, 0.22 * s),
	])
	enemy.draw_colored_polygon(hull_inner, _mix(LIGHT_ARMOR, hp_tint, 0.16))

	# Dark under-frame gives premium contrast and prevents "yellow blob" readability loss.
	var under_frame := PackedVector2Array([
		Vector2(-0.54 * s, -0.02 * s),
		Vector2(-0.22 * s, -0.24 * s),
		Vector2(0.28 * s, -0.22 * s),
		Vector2(0.54 * s, 0.02 * s),
		Vector2(0.32 * s, 0.30 * s),
		Vector2(-0.28 * s, 0.32 * s),
	])
	enemy.draw_colored_polygon(under_frame, DEEP_METAL)

	# Projector emitters: the key "support shield" identity.
	_draw_shield_emitter(enemy, Vector2(-0.70 * s, 0.00 * s), -1.0, s, pulse)
	_draw_shield_emitter(enemy, Vector2(0.70 * s, 0.00 * s), 1.0, s, pulse)

	# Clean armor plates. Few big shapes are more readable than many tiny lines.
	var crown_plate := PackedVector2Array([
		Vector2(-0.32 * s, -0.44 * s),
		Vector2(0.26 * s, -0.48 * s),
		Vector2(0.48 * s, -0.25 * s),
		Vector2(0.17 * s, -0.10 * s),
		Vector2(-0.42 * s, -0.16 * s),
	])
	enemy.draw_colored_polygon(crown_plate, _mix(LIGHT_PLATE, hp_tint, 0.10))
	enemy.draw_polyline(_closed(crown_plate), Color(0.25, 0.18, 0.06, 0.86), max(1.0, s * 0.042), true)

	var lower_plate := PackedVector2Array([
		Vector2(-0.45 * s, 0.12 * s),
		Vector2(0.38 * s, 0.08 * s),
		Vector2(0.48 * s, 0.28 * s),
		Vector2(0.18 * s, 0.42 * s),
		Vector2(-0.34 * s, 0.38 * s),
		Vector2(-0.55 * s, 0.22 * s),
	])
	enemy.draw_colored_polygon(lower_plate, _mix(LIGHT_SHADE, hp_tint, 0.10))
	enemy.draw_polyline(_closed(lower_plate), Color(0.04, 0.035, 0.025, 0.76), max(1.0, s * 0.038), true)

	# Compact shield geometry. This reads as aura/support while avoiding expensive large radius visuals.
	var gold_alpha := 0.30 + 0.16 * pulse
	var cyan_alpha := 0.22 + 0.14 * pulse
	enemy.draw_arc(Vector2.ZERO, s * 0.98, deg_to_rad(202), deg_to_rad(338), 28, Color(SHIELD_GOLD.r, SHIELD_GOLD.g, SHIELD_GOLD.b, gold_alpha), max(1.20, s * 0.058), true)
	enemy.draw_arc(Vector2.ZERO, s * 0.80, deg_to_rad(214), deg_to_rad(326), 22, Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, cyan_alpha), max(1.05, s * 0.046), true)

	# Small shield anchor nodes at the end of the halo.
	enemy.draw_circle(Vector2(-0.78 * s, -0.32 * s), s * 0.055, Color(SHIELD_GOLD.r, SHIELD_GOLD.g, SHIELD_GOLD.b, 0.72))
	enemy.draw_circle(Vector2(0.78 * s, -0.32 * s), s * 0.055, Color(SHIELD_GOLD.r, SHIELD_GOLD.g, SHIELD_GOLD.b, 0.72))

	# Central projector lens.
	enemy.draw_circle(Vector2.ZERO, s * 0.32, Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, 0.14 + 0.08 * pulse))
	enemy.draw_circle(Vector2.ZERO, s * 0.220, BLACK_TRIM)
	enemy.draw_circle(Vector2.ZERO, s * 0.160, Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, 0.88))
	enemy.draw_circle(Vector2.ZERO, s * 0.080, Color(0.90, 1.00, 1.00, 0.94))
	enemy.draw_circle(Vector2(0.050 * s, -0.050 * s), s * 0.040, WHITE_HOT)

	# Minimal circuit ticks. Only 4 lines so many Shieldbearers remain cheap.
	var tick := Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, 0.46 + 0.18 * pulse)
	enemy.draw_line(Vector2(-0.34 * s, -0.02 * s), Vector2(-0.21 * s, -0.02 * s), tick, max(1.0, s * 0.030), true)
	enemy.draw_line(Vector2(0.21 * s, -0.02 * s), Vector2(0.34 * s, -0.02 * s), tick, max(1.0, s * 0.030), true)
	enemy.draw_line(Vector2(-0.15 * s, 0.23 * s), Vector2(-0.06 * s, 0.14 * s), tick, max(1.0, s * 0.028), true)
	enemy.draw_line(Vector2(0.15 * s, 0.23 * s), Vector2(0.06 * s, 0.14 * s), tick, max(1.0, s * 0.028), true)

	# Final crisp outline.
	enemy.draw_polyline(_closed(hull), Color(0.0, 0.0, 0.0, 0.88), max(1.45, s * 0.078), true)


static func _draw_projector_foot(enemy: Node2D, root: Vector2, foot: Vector2, s: float) -> void:
	var knee := Vector2((root.x + foot.x) * 0.5, root.y + 0.15 * s)
	enemy.draw_line(root, knee, BLACK_TRIM, max(1.35, s * 0.062), true)
	enemy.draw_line(knee, foot, BLACK_TRIM, max(1.35, s * 0.062), true)
	enemy.draw_line(root, knee, MID_METAL, max(1.0, s * 0.030), true)
	enemy.draw_line(knee, foot, MID_METAL, max(1.0, s * 0.030), true)

	var foot_pad := PackedVector2Array([
		foot + Vector2(-0.14 * s, -0.03 * s),
		foot + Vector2(0.14 * s, -0.03 * s),
		foot + Vector2(0.18 * s, 0.06 * s),
		foot + Vector2(-0.12 * s, 0.08 * s),
	])
	enemy.draw_colored_polygon(foot_pad, BLACK_TRIM)


static func _draw_shield_emitter(enemy: Node2D, pos: Vector2, side: float, s: float, pulse: float) -> void:
	var pod := PackedVector2Array([
		pos + Vector2(-0.18 * side * s, -0.22 * s),
		pos + Vector2(0.15 * side * s, -0.17 * s),
		pos + Vector2(0.25 * side * s, 0.02 * s),
		pos + Vector2(0.14 * side * s, 0.22 * s),
		pos + Vector2(-0.16 * side * s, 0.18 * s),
		pos + Vector2(-0.25 * side * s, -0.02 * s),
	])
	enemy.draw_colored_polygon(pod, BLACK_TRIM)
	enemy.draw_colored_polygon(_scale_around(pod, pos, 0.72), Color(0.88, 0.72, 0.30, 1.0))

	# Forward-facing lens shows this is a projector, not just armor.
	var lens_pos := pos + Vector2(0.15 * side * s, -0.01 * s)
	enemy.draw_circle(lens_pos, s * 0.090, Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, 0.22 + 0.12 * pulse))
	enemy.draw_circle(lens_pos, s * 0.060, Color(SHIELD_CYAN.r, SHIELD_CYAN.g, SHIELD_CYAN.b, 0.78 + 0.16 * pulse))
	enemy.draw_circle(lens_pos + Vector2(0.018 * side * s, -0.018 * s), s * 0.024, WHITE_HOT)

	# Short local shield prongs; cheap but premium.
	var prong_color := Color(SHIELD_GOLD.r, SHIELD_GOLD.g, SHIELD_GOLD.b, 0.46 + 0.18 * pulse)
	enemy.draw_line(
		lens_pos + Vector2(0.07 * side * s, -0.13 * s),
		lens_pos + Vector2(0.20 * side * s, -0.22 * s),
		prong_color,
		max(1.0, s * 0.032),
		true
	)
	enemy.draw_line(
		lens_pos + Vector2(0.07 * side * s, 0.13 * s),
		lens_pos + Vector2(0.20 * side * s, 0.22 * s),
		prong_color,
		max(1.0, s * 0.032),
		true
	)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if closed.size() > 0:
		closed.append(closed[0])
	return closed


static func _scale_around(points: PackedVector2Array, pivot: Vector2, scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(pivot + (point - pivot) * scale)
	return out


static func _time(enemy: Node2D) -> float:
	if enemy.has_method("get_visual_time"):
		return float(enemy.call("get_visual_time"))
	if "visual_time" in enemy:
		return float(enemy.visual_time)
	return float(Time.get_ticks_msec()) / 1000.0


static func _health_tint(enemy: Node2D) -> Color:
	var ratio := 1.0
	if "health_ratio" in enemy:
		ratio = float(enemy.health_ratio)
	elif "current_hp" in enemy and "max_hp" in enemy and float(enemy.max_hp) > 0.0:
		ratio = float(enemy.current_hp) / float(enemy.max_hp)

	if ratio < 0.22:
		return Color(1.0, 0.20, 0.12, 1.0)
	if ratio < 0.60:
		return Color(1.0, 0.55, 0.16, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)


static func _mix(a: Color, b: Color, amount: float) -> Color:
	return Color(
		lerp(a.r, b.r, amount),
		lerp(a.g, b.g, amount),
		lerp(a.b, b.b, amount),
		lerp(a.a, b.a, amount)
	)
