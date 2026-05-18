const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Data Swarm
# - Role: many weak corrupted code fragments
# - Armor: Water
# - Visual budget: intentionally cheap because this type can appear in large counts.

static func draw_simple(enemy: Node2D, size: float) -> void:
	var state: int = int(enemy.get("health_visual_state"))
	var water: Color = B.apply_health_tint(Color(0.18, 0.78, 0.95, 0.92), state)
	var deep: Color = B.apply_health_tint(Color(0.05, 0.25, 0.36, 0.95), state)
	var glow: Color = Color(0.55, 0.95, 1.0, 0.72)

	var a := Vector2(-size * 0.52, -size * 0.22)
	var b := Vector2( size * 0.42, -size * 0.06)
	var c := Vector2(-size * 0.10,  size * 0.42)

	_draw_fragment_simple(enemy, a, size * 0.34, water, glow)
	_draw_fragment_simple(enemy, b, size * 0.30, water, glow)
	_draw_fragment_simple(enemy, c, size * 0.28, deep, glow)

	enemy.draw_line(a, b, Color(glow.r, glow.g, glow.b, 0.24), 1.0)
	enemy.draw_line(b, c, Color(glow.r, glow.g, glow.b, 0.18), 1.0)


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var phase: float = float(enemy.get_instance_id() % 83) * 0.097
	var pulse: float = 0.5 + sin(pulse_time * 5.8 + phase) * 0.5
	var bob: float = sin(pulse_time * 4.2 + phase) * size * 0.045

	var state: int = int(enemy.get("health_visual_state"))
	var water_body: Color = B.apply_health_tint(Color(0.08, 0.40, 0.58, 0.92), state)
	var water_panel: Color = B.apply_health_tint(Color(0.10, 0.62, 0.76, 0.86), state)
	var water_core: Color = B.apply_health_tint(Color(0.52, 0.94, 1.0, 0.98), state)
	var deep_trim := Color(0.025, 0.065, 0.10, 0.95)

	var origin := Vector2(0.0, bob)

	# Small ground shadow only; no large aura/particle field.
	enemy.draw_circle(origin + Vector2(-size * 0.06, size * 0.78), size * (0.84 + pulse * 0.04), Color(0, 0, 0, 0.12))

	# Three main fragments = readable "swarm" without drawing many orbiting objects.
	var p0 := origin + Vector2(-size * 0.48, -size * 0.18)
	var p1 := origin + Vector2( size * 0.36, -size * 0.03)
	var p2 := origin + Vector2(-size * 0.02,  size * 0.42)

	# Lightweight data links between fragments.
	var link_alpha: float = 0.24 + pulse * 0.10
	enemy.draw_line(p0, p1, Color(water_core.r, water_core.g, water_core.b, link_alpha), 1.15)
	enemy.draw_line(p1, p2, Color(water_core.r, water_core.g, water_core.b, link_alpha * 0.82), 1.0)
	enemy.draw_line(p2, p0, Color(water_core.r, water_core.g, water_core.b, link_alpha * 0.58), 1.0)

	# Main corrupted-code fragments. Larger shapes first, small readable accents second.
	_draw_fragment(enemy, p0, size * 0.48, water_body, water_panel, water_core, deep_trim, pulse, -0.16)
	_draw_fragment(enemy, p1, size * 0.42, water_body.lightened(0.06), water_panel, water_core, deep_trim, 1.0 - pulse, 0.10)
	_draw_fragment(enemy, p2, size * 0.38, water_body.darkened(0.04), water_panel.darkened(0.05), water_core, deep_trim, pulse * 0.75, 0.02)

	# Direction cue: tiny water/data chevrons, cheaper than plume particles.
	var cue_color := Color(water_core.r, water_core.g, water_core.b, 0.30 + pulse * 0.12)
	enemy.draw_line(origin + Vector2(size * 0.72, -size * 0.16), origin + Vector2(size * 0.96, 0.0), cue_color, 1.05)
	enemy.draw_line(origin + Vector2(size * 0.72,  size * 0.16), origin + Vector2(size * 0.96, 0.0), cue_color, 1.05)


static func _draw_fragment_simple(enemy: Node2D, origin: Vector2, radius: float, color: Color, glow: Color) -> void:
	enemy.draw_circle(origin, radius + B.ENEMY_OUTLINE_THICKNESS, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(origin, radius, color)
	enemy.draw_circle(origin + Vector2(radius * 0.14, -radius * 0.10), radius * 0.34, glow)


static func _draw_fragment(
	enemy: Node2D,
	origin: Vector2,
	size: float,
	body_color: Color,
	panel_color: Color,
	core_color: Color,
	trim_color: Color,
	pulse: float,
	skew: float
) -> void:
	var body := PackedVector2Array([
		origin + Vector2( size * 0.72, -size * 0.06 + skew * size),
		origin + Vector2( size * 0.28, -size * 0.48),
		origin + Vector2(-size * 0.34, -size * 0.42 - skew * size * 0.45),
		origin + Vector2(-size * 0.58,  size * 0.04),
		origin + Vector2(-size * 0.22,  size * 0.48),
		origin + Vector2( size * 0.42,  size * 0.34 + skew * size * 0.35),
	])

	var panel := PackedVector2Array([
		origin + Vector2( size * 0.36, -size * 0.08),
		origin + Vector2( size * 0.10, -size * 0.25),
		origin + Vector2(-size * 0.22, -size * 0.12),
		origin + Vector2(-size * 0.14,  size * 0.18),
		origin + Vector2( size * 0.20,  size * 0.18),
	])

	# Hard outline first for premium/readable small silhouettes.
	enemy.draw_colored_polygon(_offset_polygon(body, Vector2(0, B.ENEMY_OUTLINE_THICKNESS * 0.35)), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, body_color)
	enemy.draw_colored_polygon(panel, panel_color)
	enemy.draw_polyline(body + PackedVector2Array([body[0]]), trim_color, 1.25)

	# Minimal "code shard" cuts. Only two lines per fragment.
	enemy.draw_line(
		origin + Vector2(-size * 0.28, -size * 0.12),
		origin + Vector2( size * 0.26, -size * 0.02),
		Color(core_color.r, core_color.g, core_color.b, 0.44),
		1.0
	)
	enemy.draw_line(
		origin + Vector2(-size * 0.18, size * 0.18),
		origin + Vector2( size * 0.22, size * 0.08),
		Color(core_color.r, core_color.g, core_color.b, 0.30),
		1.0
	)

	var core_r: float = size * (0.16 + pulse * 0.025)
	enemy.draw_circle(origin + Vector2(size * 0.18, -size * 0.02), core_r * 1.75, Color(core_color.r, core_color.g, core_color.b, 0.16))
	enemy.draw_circle(origin + Vector2(size * 0.18, -size * 0.02), core_r, core_color)
	enemy.draw_circle(origin + Vector2(size * 0.22, -size * 0.07), core_r * 0.36, Color(0.86, 1.0, 1.0, 0.95))


static func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result
