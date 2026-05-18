const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Cyber Drone — Light armor / air scout.
# Visual-only renderer. Keep this file draw-based and allocation-light.

const LIGHT_ARMOR := Color(1.0, 0.82, 0.32, 0.92)
const LIGHT_EDGE := Color(1.0, 0.94, 0.62, 0.72)
const SKY_CORE := Color(0.44, 0.92, 1.0, 0.95)
const WING_GLOW := Color(0.55, 0.96, 1.0, 0.34)
const BODY_DARK := Color(0.075, 0.085, 0.105, 0.96)
const PLATE_DARK := Color(0.16, 0.14, 0.10, 0.96)
const SHADOW := Color(0.0, 0.0, 0.0, 0.16)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var hp_state := int(enemy.get("health_visual_state"))
	var armor_col := B.apply_health_tint(LIGHT_ARMOR, hp_state)
	var core_col := B.apply_health_tint(SKY_CORE, hp_state)

	# Cheap soft air shadow, separated from body to read as flying.
	enemy.draw_circle(Vector2(0.0, size * 0.74), size * 0.36, SHADOW)

	var body := PackedVector2Array([
		Vector2(0.0, -size * 0.76),
		Vector2(size * 0.64, -size * 0.10),
		Vector2(size * 0.38, size * 0.48),
		Vector2(0.0, size * 0.66),
		Vector2(-size * 0.38, size * 0.48),
		Vector2(-size * 0.64, -size * 0.10),
	])

	var wing_l := PackedVector2Array([
		Vector2(-size * 0.32, -size * 0.10),
		Vector2(-size * 1.00, -size * 0.34),
		Vector2(-size * 0.72, size * 0.18),
		Vector2(-size * 0.30, size * 0.26),
	])
	var wing_r := PackedVector2Array([
		Vector2(size * 0.32, -size * 0.10),
		Vector2(size * 1.00, -size * 0.34),
		Vector2(size * 0.72, size * 0.18),
		Vector2(size * 0.30, size * 0.26),
	])

	enemy.draw_colored_polygon(B.scale_polygon(wing_l, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(B.scale_polygon(wing_r, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(wing_l, Color(armor_col.r, armor_col.g, armor_col.b, 0.42))
	enemy.draw_colored_polygon(wing_r, Color(armor_col.r, armor_col.g, armor_col.b, 0.42))

	enemy.draw_colored_polygon(B.scale_polygon(body, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, BODY_DARK)
	enemy.draw_circle(Vector2.ZERO, size * 0.27, core_col)
	enemy.draw_circle(Vector2(-size * 0.08, -size * 0.08), size * 0.08, Color.WHITE)


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time := float(enemy.get("pulse_time"))
	var hp_state := int(enemy.get("health_visual_state"))
	var pulse := 0.5 + 0.5 * sin(pulse_time * 5.2)
	var tilt := sin(pulse_time * 4.0) * size * 0.035

	var armor_col := B.apply_health_tint(LIGHT_ARMOR, hp_state)
	var edge_col := B.apply_health_tint(LIGHT_EDGE, hp_state)
	var core_col := B.apply_health_tint(SKY_CORE, hp_state)

	# Air-unit shadow: cheap, non-animated enough to imply altitude.
	enemy.draw_circle(Vector2(0.0, size * 0.82), size * 0.48, SHADOW)

	# Light scout wings / rotors. Large shape, low detail, readable at small size.
	var left_wing := PackedVector2Array([
		Vector2(-size * 0.24, -size * 0.26 + tilt),
		Vector2(-size * 1.24, -size * 0.50),
		Vector2(-size * 1.02, -size * 0.04),
		Vector2(-size * 0.54, size * 0.22),
		Vector2(-size * 0.24, size * 0.14 + tilt),
	])
	var right_wing := PackedVector2Array([
		Vector2(size * 0.24, -size * 0.26 - tilt),
		Vector2(size * 1.24, -size * 0.50),
		Vector2(size * 1.02, -size * 0.04),
		Vector2(size * 0.54, size * 0.22),
		Vector2(size * 0.24, size * 0.14 - tilt),
	])

	enemy.draw_colored_polygon(B.scale_polygon(left_wing, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(B.scale_polygon(right_wing, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(left_wing, Color(armor_col.r, armor_col.g, armor_col.b, 0.48))
	enemy.draw_colored_polygon(right_wing, Color(armor_col.r, armor_col.g, armor_col.b, 0.48))

	# Wing energy strips: enough to say "flying drone", not enough to become VFX spam.
	enemy.draw_line(Vector2(-size * 0.36, -size * 0.16 + tilt), Vector2(-size * 1.03, -size * 0.36), edge_col, 1.35)
	enemy.draw_line(Vector2(size * 0.36, -size * 0.16 - tilt), Vector2(size * 1.03, -size * 0.36), edge_col, 1.35)
	enemy.draw_line(Vector2(-size * 0.42, size * 0.10 + tilt), Vector2(-size * 0.86, -size * 0.02), WING_GLOW, 1.0)
	enemy.draw_line(Vector2(size * 0.42, size * 0.10 - tilt), Vector2(size * 0.86, -size * 0.02), WING_GLOW, 1.0)

	# Compact drone chassis: diamond/hex cockpit with black trim.
	var body := PackedVector2Array([
		Vector2(0.0, -size * 0.84),
		Vector2(size * 0.54, -size * 0.24),
		Vector2(size * 0.44, size * 0.36),
		Vector2(0.0, size * 0.68),
		Vector2(-size * 0.44, size * 0.36),
		Vector2(-size * 0.54, -size * 0.24),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, 1.11), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, BODY_DARK)

	var nose_plate := PackedVector2Array([
		Vector2(0.0, -size * 0.70),
		Vector2(size * 0.30, -size * 0.28),
		Vector2(0.0, -size * 0.08),
		Vector2(-size * 0.30, -size * 0.28),
	])
	enemy.draw_colored_polygon(nose_plate, Color(armor_col.r, armor_col.g, armor_col.b, 0.64))

	var lower_plate := PackedVector2Array([
		Vector2(-size * 0.30, size * 0.12),
		Vector2(size * 0.30, size * 0.12),
		Vector2(size * 0.20, size * 0.44),
		Vector2(0.0, size * 0.56),
		Vector2(-size * 0.20, size * 0.44),
	])
	enemy.draw_colored_polygon(lower_plate, PLATE_DARK)

	# Scout sensor/core. Bright but small; focal point without heavy glow.
	enemy.draw_circle(Vector2(0.0, size * 0.02), size * 0.35, Color(core_col.r, core_col.g, core_col.b, 0.24 + pulse * 0.10))
	enemy.draw_circle(Vector2(0.0, size * 0.02), size * 0.24, core_col)
	enemy.draw_circle(Vector2(-size * 0.07, -size * 0.06), size * 0.075, Color.WHITE)

	# Light armor identity marks: small golden antenna/anchor nodes.
	enemy.draw_line(Vector2(0.0, -size * 0.72), Vector2(0.0, -size * 1.02), Color(edge_col.r, edge_col.g, edge_col.b, 0.70), 1.35)
	enemy.draw_circle(Vector2(0.0, -size * 1.04), size * 0.075, Color(edge_col.r, edge_col.g, edge_col.b, 0.72))
	enemy.draw_circle(Vector2(-size * 0.58, -size * 0.22 + tilt), size * 0.07, Color(core_col.r, core_col.g, core_col.b, 0.72))
	enemy.draw_circle(Vector2(size * 0.58, -size * 0.22 - tilt), size * 0.07, Color(core_col.r, core_col.g, core_col.b, 0.72))

	# Minimal hovering pulse under the chassis; tiny symbol, not a persistent aura.
	enemy.draw_arc(Vector2(0.0, size * 0.34), size * 0.34, PI * 0.12, PI * 0.88, 12, Color(core_col.r, core_col.g, core_col.b, 0.22 + pulse * 0.08), 1.0)
