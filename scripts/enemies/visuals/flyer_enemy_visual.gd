const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	_draw_diamond_simple(enemy, size, B.COLOR_NEON_BULWARK)

static func draw(enemy: Node2D, size: float) -> void:
	_draw_drone(enemy, size, B.COLOR_NEON_BULWARK, false)

static func _draw_diamond_simple(enemy: Node2D, size: float, color: Color) -> void:
	var col := B.apply_health_tint(color, int(enemy.get("health_visual_state")))
	var body_pts := PackedVector2Array([
		Vector2(0,-size*0.9), Vector2(size*0.9,0), Vector2(0,size*0.9), Vector2(-size*0.9,0)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(col.r,col.g,col.b,0.85))
	enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

static func _draw_drone(enemy: Node2D, size: float, color: Color, is_fast: bool) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	enemy.draw_circle(Vector2(0,size*0.7), size*0.36, Color(0,0,0,0.14))
	enemy.draw_circle(Vector2.ZERO, size*0.6, B.COLOR_BODY)
	enemy.draw_arc(Vector2.ZERO, size*0.6, 0, TAU, 24, color, 2.0)
	enemy.draw_arc(Vector2.ZERO, size*0.88, pulse_time*2.0, pulse_time*2.0+PI, 24, Color(color.r,color.g,color.b,0.28), 1.0)
	for i in range(4):
		var a: float = i*PI/2.0 + (pulse_time*15.0)
		enemy.draw_line(Vector2.ZERO, Vector2(cos(a),sin(a))*size, color, 2.0)
		enemy.draw_circle(Vector2(cos(a),sin(a))*size, 3.0, Color.WHITE)
	if is_fast:
		var trail: float = (sin(pulse_time*30.0)*0.5+0.5)*10.0
		enemy.draw_line(Vector2(-size,0), Vector2(-size-trail,0), color, 3.0)
		enemy.draw_line(Vector2(-size*0.45,-size*0.35), Vector2(-size-trail*0.7,-size*0.6), Color(color.r,color.g,color.b,0.35), 1.4)
		enemy.draw_line(Vector2(-size*0.45, size*0.35), Vector2(-size-trail*0.7, size*0.6), Color(color.r,color.g,color.b,0.35), 1.4)
	B.draw_glow_core(enemy, Vector2.ZERO, size*0.3, color)
