const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color: Color = B.apply_health_tint(B.COLOR_NEON_TANK, int(enemy.get("health_visual_state")))
	var tank_rect := Rect2(Vector2(-size*0.9,-size*0.7), Vector2(size*1.8,size*1.4))
	enemy.draw_rect(tank_rect.grow(B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_rect(tank_rect, Color(color.r,color.g,color.b,0.9))
	enemy.draw_circle(Vector2.ZERO, size*0.35, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	var color := B.COLOR_NEON_TANK
	var pts := PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos(i*PI/4.0), sin(i*PI/4.0)) * size)
	enemy.draw_colored_polygon(pts, B.COLOR_BODY)
	for i in range(8):
		var mid: Vector2 = (pts[i] + pts[(i+1)%8]) * 0.5
		var inner_mid: Vector2 = mid * 0.7
		enemy.draw_line(mid, inner_mid, Color(color.r,color.g,color.b,0.32), 1.4)
		if i % 2 == 0:
			enemy.draw_circle(inner_mid, 2.2, Color(color.r,color.g,color.b,0.45))
	enemy.draw_polyline(pts+PackedVector2Array([pts[0]]), color, 4.0)
	enemy.draw_polyline(pts+PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
	B.draw_glow_core(enemy, Vector2.ZERO, size*0.45, color)
	for i in range(4):
		var a: float = i*PI/2.0 + PI/4.0
		enemy.draw_circle(Vector2(cos(a),sin(a))*size*0.8, 3.0, color)
