const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color := B.COLOR_NEON_FAST
	var body_pts := PackedVector2Array([
		Vector2(0, -size*1.1), Vector2(size*0.5, size*0.4), Vector2(0, size*0.2), Vector2(-size*0.5, size*0.4)
	])
	color = B.apply_health_tint(color, int(enemy.get("health_visual_state")))
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r, color.g, color.b, 0.85))
	enemy.draw_circle(Vector2.ZERO, size * 0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	_draw_runner_shape(enemy, size, B.COLOR_NEON_FAST)

static func _draw_runner_shape(enemy: Node2D, size: float, color: Color) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var pts := PackedVector2Array([
		Vector2(size*1.5, 0), Vector2(-size*1.0, -size*0.7),
		Vector2(-size*0.5, 0), Vector2(-size*1.0, size*0.7)
	])
	enemy.draw_colored_polygon(pts, B.COLOR_BODY)
	var fin_pts := PackedVector2Array([
		Vector2(-size*0.35,-size*0.95), Vector2(size*0.2,-size*0.42), Vector2(-size*0.58,-size*0.28)
	])
	enemy.draw_colored_polygon(fin_pts, Color(color.r,color.g,color.b,0.18))
	for i in range(fin_pts.size()):
		fin_pts[i].y *= -1.0
	enemy.draw_colored_polygon(fin_pts, Color(color.r,color.g,color.b,0.18))
	var trail_alpha: float = 0.3 + sin(pulse_time*20.0)*0.2
	enemy.draw_line(Vector2(-size*0.8,-size*0.4), Vector2(-size*2.5,-size*0.4), Color(color.r,color.g,color.b,trail_alpha), 2.0)
	enemy.draw_line(Vector2(-size*0.8, size*0.4), Vector2(-size*2.5, size*0.4), Color(color.r,color.g,color.b,trail_alpha), 2.0)
	enemy.draw_polyline(PackedVector2Array([Vector2(-size*0.2,0),Vector2(-size*1.4,-size*0.9),Vector2(-size*2.3,-size*0.9)]), Color(color.r,color.g,color.b,trail_alpha*0.45), 1.0)
	enemy.draw_polyline(PackedVector2Array([Vector2(-size*0.2,0),Vector2(-size*1.4, size*0.9),Vector2(-size*2.3, size*0.9)]), Color(color.r,color.g,color.b,trail_alpha*0.45), 1.0)
	enemy.draw_polyline(pts+PackedVector2Array([pts[0]]), Color(0,0,0,0.8), 4.0)
	enemy.draw_polyline(pts+PackedVector2Array([pts[0]]), color, 2.5)
	B.draw_glow_core(enemy, Vector2(size*0.4, 0), size*0.25, color)
