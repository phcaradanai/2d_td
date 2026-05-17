const B     := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")
const Flyer := preload("res://scripts/enemies/visuals/flyer_enemy_visual.gd")

const DISRUPTOR_COLOR := Color(0.6, 0.3, 1.0)

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color := B.apply_health_tint(DISRUPTOR_COLOR, int(enemy.get("health_visual_state")))
	var body_pts := PackedVector2Array([
		Vector2(0,-size*1.1), Vector2(size*0.7,size*0.5), Vector2(0,size*0.2), Vector2(-size*0.7,size*0.5)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r,color.g,color.b,0.85))
	enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var color := DISRUPTOR_COLOR
	Flyer._draw_drone(enemy, size, color, false)
	var cyan := Color(0.35,1.0,1.0,1.0)
	enemy.draw_line(Vector2(size*0.25,-size*0.55), Vector2(size*1.2,-size*1.0),  cyan, 1.6)
	enemy.draw_line(Vector2(size*0.25, size*0.55), Vector2(size*1.2, size*1.0),  cyan, 1.6)
	enemy.draw_line(Vector2(size*1.0,-size*0.82), Vector2(size*1.28,-size*1.08), Color(1.0,0.2,0.82,0.8), 1.0)
	enemy.draw_line(Vector2(size*1.0, size*0.82), Vector2(size*1.28, size*1.08), Color(1.0,0.2,0.82,0.8), 1.0)
	var r_pulse: float = sin(pulse_time*10.0)*0.5+0.5
	enemy.draw_arc(Vector2.ZERO, size*(1.2+r_pulse*0.3), 0, TAU, 32, Color(color.r,color.g,color.b,0.4-r_pulse*0.3), 2.0)
	enemy.draw_arc(Vector2.ZERO, size*(1.5+r_pulse*0.5), 0, TAU, 32, Color(color.r,color.g,color.b,0.2-r_pulse*0.2), 1.5)
