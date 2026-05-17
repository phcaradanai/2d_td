const B    := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")
const Fast := preload("res://scripts/enemies/visuals/fast_enemy_visual.gd")

const RUNNER_COLOR := Color(1.0, 0.35, 0.05)

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color := B.apply_health_tint(RUNNER_COLOR, int(enemy.get("health_visual_state")))
	var body_pts := PackedVector2Array([
		Vector2(0,-size*1.1), Vector2(size*0.5,size*0.4), Vector2(0,size*0.2), Vector2(-size*0.5,size*0.4)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r,color.g,color.b,0.85))
	enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	Fast._draw_runner_shape(enemy, size, RUNNER_COLOR)
	_draw_runner_role_telegraph(enemy, size)

static func _draw_runner_role_telegraph(enemy: Node2D, size: float) -> void:
	var danger_color := Color(1.0, 0.35, 0.05, 1.0)
	var pulse_time: float = float(enemy.get("pulse_time"))
	var pulse: float = 0.5 + sin(pulse_time * 12.0) * 0.5
	var dash_cooldown: float = float(enemy.get("runner_dash_cooldown"))
	var dash_timer: float   = float(enemy.get("runner_dash_timer"))
	var dash_remaining: float = float(enemy.get("runner_dash_remaining"))
	var panic_active: bool  = bool(enemy.get("runner_panic_active"))
	var dash_charge: float  = 1.0 - clampf(dash_timer / maxf(dash_cooldown, 0.01), 0.0, 1.0)
	var ring_alpha: float   = 0.05 + dash_charge * 0.16

	enemy.draw_arc(Vector2.ZERO, size*(1.35+dash_charge*0.28), -PI*0.85, PI*0.85, 36,
		Color(danger_color.r,danger_color.g,danger_color.b,ring_alpha), 1.1, true)

	if dash_remaining > 0.0:
		var dash_alpha: float = 0.22 + pulse * 0.18
		enemy.draw_circle(Vector2.ZERO, size*1.55, Color(danger_color.r,danger_color.g,danger_color.b,0.08+pulse*0.04))
		enemy.draw_line(Vector2(-size*0.9,0), Vector2(-size*3.2,0), Color(danger_color.r,danger_color.g,danger_color.b,dash_alpha), 4.0, true)
		enemy.draw_line(Vector2(-size*0.5,-size*0.45), Vector2(-size*2.5,-size*0.85), Color(1.0,0.75,0.2,dash_alpha*0.7), 1.4, true)
		enemy.draw_line(Vector2(-size*0.5, size*0.45), Vector2(-size*2.5, size*0.85), Color(1.0,0.75,0.2,dash_alpha*0.7), 1.4, true)

	if panic_active:
		enemy.draw_arc(Vector2.ZERO, size*(1.75+pulse*0.22), 0.0, TAU, 40, Color(1.0,0.12,0.04,0.22+pulse*0.08), 1.6, true)
		enemy.draw_circle(Vector2(size*0.58,0), size*(0.18+pulse*0.06), Color(1.0,0.9,0.45,0.75))
