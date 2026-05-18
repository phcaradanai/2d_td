const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# EMP Wasp — air/support/disruptor, Darkness armor.
# Draw-only visual. No particles, no child nodes, no gameplay mutation.

const ARMOR_DARK      := Color(0.13, 0.08, 0.20, 0.96)
const ARMOR_MID       := Color(0.34, 0.18, 0.56, 0.92)
const ARMOR_EDGE      := Color(0.70, 0.36, 1.00, 0.90)
const EMP_CYAN        := Color(0.35, 1.00, 1.00, 0.95)
const EMP_BLUE        := Color(0.20, 0.55, 1.00, 0.72)
const WARNING_MAGENTA := Color(1.00, 0.22, 0.82, 0.88)
const SHADOW_COLOR    := Color(0.02, 0.01, 0.05, 0.26)

static func draw_simple(enemy: Node2D, size: float) -> void:
	var visual_state: int = int(enemy.get("health_visual_state"))
	var armor := B.apply_health_tint(ARMOR_MID, visual_state)
	var s := size * 0.92

	# Cheap air shadow.
	enemy.draw_circle(Vector2(0.0, s * 0.74), s * 0.48, SHADOW_COLOR)

	# Wasp-like dart body with dark outline.
	var body := PackedVector2Array([
		Vector2(0.0, -s * 1.05),
		Vector2(s * 0.52, -s * 0.18),
		Vector2(s * 0.34,  s * 0.62),
		Vector2(0.0,  s * 0.94),
		Vector2(-s * 0.34, s * 0.62),
		Vector2(-s * 0.52, -s * 0.18),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, 1.10), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, armor)

	# Minimal EMP wings/antennae.
	enemy.draw_line(Vector2(-s * 0.34, -s * 0.08), Vector2(-s * 0.92, -s * 0.40), EMP_BLUE, 1.4)
	enemy.draw_line(Vector2( s * 0.34, -s * 0.08), Vector2( s * 0.92, -s * 0.40), EMP_BLUE, 1.4)
	enemy.draw_line(Vector2(-s * 0.16, -s * 0.62), Vector2(-s * 0.44, -s * 0.94), WARNING_MAGENTA, 1.1)
	enemy.draw_line(Vector2( s * 0.16, -s * 0.62), Vector2( s * 0.44, -s * 0.94), WARNING_MAGENTA, 1.1)

	enemy.draw_circle(Vector2(0.0, -s * 0.08), s * 0.23, EMP_CYAN)
	enemy.draw_circle(Vector2(0.0, -s * 0.08), s * 0.10, Color(1.0, 1.0, 1.0, 0.88))


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var visual_state: int = int(enemy.get("health_visual_state"))
	var pulse := sin(pulse_time * 6.0) * 0.5 + 0.5
	var blink := sin(pulse_time * 13.0) * 0.5 + 0.5
	var s := size

	var armor_mid := B.apply_health_tint(ARMOR_MID, visual_state)
	var armor_dark := B.apply_health_tint(ARMOR_DARK, visual_state)

	# Soft ground shadow makes it read as air without expensive effects.
	enemy.draw_circle(Vector2(0.0, s * 0.86), s * 0.62, SHADOW_COLOR)

	# Compact EMP field icon. This intentionally represents the disrupt aura
	# without drawing the real gameplay radius.
	var field_alpha := 0.16 + pulse * 0.08
	enemy.draw_arc(Vector2.ZERO, s * 1.10, -0.55, 0.55, 14, Color(EMP_CYAN.r, EMP_CYAN.g, EMP_CYAN.b, field_alpha), 1.3)
	enemy.draw_arc(Vector2.ZERO, s * 1.10, PI - 0.55, PI + 0.55, 14, Color(EMP_CYAN.r, EMP_CYAN.g, EMP_CYAN.b, field_alpha), 1.3)

	# Rear stabilizer fins.
	var rear_left := PackedVector2Array([
		Vector2(-s * 0.22, s * 0.34),
		Vector2(-s * 0.88, s * 0.70),
		Vector2(-s * 0.40, s * 0.78),
	])
	var rear_right := PackedVector2Array([
		Vector2(s * 0.22, s * 0.34),
		Vector2(s * 0.88, s * 0.70),
		Vector2(s * 0.40, s * 0.78),
	])
	enemy.draw_colored_polygon(B.scale_polygon(rear_left, 1.12), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(B.scale_polygon(rear_right, 1.12), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(rear_left, Color(0.18, 0.10, 0.30, 0.88))
	enemy.draw_colored_polygon(rear_right, Color(0.18, 0.10, 0.30, 0.88))

	# Angular wasp wings / signal vanes.
	var left_wing := PackedVector2Array([
		Vector2(-s * 0.24, -s * 0.24),
		Vector2(-s * 1.28, -s * 0.72),
		Vector2(-s * 1.02, -s * 0.16),
		Vector2(-s * 0.40,  s * 0.10),
	])
	var right_wing := PackedVector2Array([
		Vector2(s * 0.24, -s * 0.24),
		Vector2(s * 1.28, -s * 0.72),
		Vector2(s * 1.02, -s * 0.16),
		Vector2(s * 0.40,  s * 0.10),
	])
	enemy.draw_colored_polygon(B.scale_polygon(left_wing, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(B.scale_polygon(right_wing, 1.08), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(left_wing, Color(0.18, 0.10, 0.34, 0.70))
	enemy.draw_colored_polygon(right_wing, Color(0.18, 0.10, 0.34, 0.70))
	enemy.draw_line(Vector2(-s * 0.52, -s * 0.28), Vector2(-s * 1.12, -s * 0.58), EMP_BLUE, 1.2)
	enemy.draw_line(Vector2( s * 0.52, -s * 0.28), Vector2( s * 1.12, -s * 0.58), EMP_BLUE, 1.2)

	# Main armored darkness chassis.
	var body := PackedVector2Array([
		Vector2(0.0, -s * 1.15),
		Vector2(s * 0.46, -s * 0.58),
		Vector2(s * 0.56,  s * 0.10),
		Vector2(s * 0.26,  s * 0.82),
		Vector2(0.0,  s * 1.02),
		Vector2(-s * 0.26, s * 0.82),
		Vector2(-s * 0.56, s * 0.10),
		Vector2(-s * 0.46, -s * 0.58),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, 1.12), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, armor_dark)

	var inner_plate := PackedVector2Array([
		Vector2(0.0, -s * 0.82),
		Vector2(s * 0.30, -s * 0.42),
		Vector2(s * 0.34,  s * 0.28),
		Vector2(0.0,  s * 0.66),
		Vector2(-s * 0.34, s * 0.28),
		Vector2(-s * 0.30, -s * 0.42),
	])
	enemy.draw_colored_polygon(inner_plate, armor_mid)

	# EMP emitter nose and stinger read as "wasp" + disruptor.
	enemy.draw_line(Vector2(-s * 0.16, -s * 0.82), Vector2(-s * 0.54, -s * 1.16), WARNING_MAGENTA, 1.4)
	enemy.draw_line(Vector2( s * 0.16, -s * 0.82), Vector2( s * 0.54, -s * 1.16), WARNING_MAGENTA, 1.4)
	enemy.draw_line(Vector2(0.0, s * 0.76), Vector2(0.0, s * 1.22), Color(EMP_CYAN.r, EMP_CYAN.g, EMP_CYAN.b, 0.70), 1.4)
	enemy.draw_circle(Vector2(0.0, s * 1.22), s * 0.08, WARNING_MAGENTA)

	# Center EMP lens.
	enemy.draw_circle(Vector2.ZERO, s * 0.34, Color(0.05, 0.02, 0.08, 0.96))
	enemy.draw_circle(Vector2.ZERO, s * (0.24 + pulse * 0.03), Color(EMP_CYAN.r, EMP_CYAN.g, EMP_CYAN.b, 0.88))
	enemy.draw_circle(Vector2.ZERO, s * 0.10, Color(1.0, 1.0, 1.0, 0.82))

	# Small cyber circuit accents; few draw calls, high readability.
	enemy.draw_line(Vector2(-s * 0.26, -s * 0.34), Vector2(-s * 0.12, -s * 0.10), ARMOR_EDGE, 1.0)
	enemy.draw_line(Vector2( s * 0.26, -s * 0.34), Vector2( s * 0.12, -s * 0.10), ARMOR_EDGE, 1.0)
	enemy.draw_line(Vector2(-s * 0.24,  s * 0.34), Vector2(-s * 0.08,  s * 0.56), Color(EMP_CYAN.r, EMP_CYAN.g, EMP_CYAN.b, 0.56), 1.0)
	enemy.draw_line(Vector2( s * 0.24,  s * 0.34), Vector2( s * 0.08,  s * 0.56), Color(EMP_CYAN.r, EMP_CYAN.g, EMP_CYAN.b, 0.56), 1.0)

	# Tiny warning blink, not a full aura.
	if blink > 0.68:
		enemy.draw_circle(Vector2(-s * 0.34, -s * 0.02), s * 0.055, WARNING_MAGENTA)
		enemy.draw_circle(Vector2( s * 0.34, -s * 0.02), s * 0.055, WARNING_MAGENTA)
