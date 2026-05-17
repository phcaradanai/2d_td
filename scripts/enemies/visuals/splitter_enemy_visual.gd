const B     := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")
const Basic := preload("res://scripts/enemies/visuals/basic_enemy_visual.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color := Color(0.8, 0.4, 1.0)
	color = B.apply_health_tint(color, int(enemy.get("health_visual_state")))
	var body_pts := PackedVector2Array([
		Vector2(0,-size*1.1), Vector2(size*0.8,size*0.5), Vector2(0,0), Vector2(-size*0.8,size*0.5)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r,color.g,color.b,0.85))
	enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	var color := Color(0.8, 0.4, 1.0)
	var pulse_time: float = float(enemy.get("pulse_time"))
	# Splitter is the basic node with instability cracks overlaid
	Basic.draw(enemy, size / 1.48)  # basic.draw internally scales by 1.48
	var noise: float = sin(pulse_time * 25.0) * 2.0
	var crack_color := Color(1.0, 0.78, 1.0, 0.86)
	enemy.draw_line(Vector2.ZERO, Vector2(size+noise, size), crack_color, 1.5)
	enemy.draw_line(Vector2.ZERO, Vector2(-size-noise, size), crack_color, 1.5)
	enemy.draw_line(Vector2.ZERO, Vector2(0, -size-noise), crack_color, 1.5)
	var hp: float      = float(enemy.get("hp"))
	var max_hp: float  = float(enemy.get("max_hp"))
	if hp / maxf(max_hp, 1.0) < 0.35:
		var warn: float = 0.35 + sin(pulse_time*18.0)*0.22
		enemy.draw_arc(Vector2.ZERO, size*1.35, 0, TAU, 32, Color(1.0,0.35,0.9,warn), 2.0)
