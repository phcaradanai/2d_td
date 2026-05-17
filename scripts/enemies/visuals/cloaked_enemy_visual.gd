const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color := Color(0.7, 0.7, 1.0, 0.6)
	var body_pts := PackedVector2Array([
		Vector2(0,-size), Vector2(size*0.7,size*0.5), Vector2(-size*0.7,size*0.5)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r,color.g,color.b,0.85))
	enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	var color := Color(0.7, 0.7, 1.0)
	var pulse_time: float = float(enemy.get("pulse_time"))
	var pts := PackedVector2Array()
	for i in range(4):
		var a: float = i * PI / 2.0 + PI / 4.0
		pts.append(Vector2(cos(a), sin(a)) * size)
	var d: float = (sin(pulse_time*15.0)*0.5+0.5)*0.2
	for i in range(pts.size()):
		var p1: Vector2 = pts[i]          + Vector2(sin(pulse_time*18.0+i)*2.0, 0)
		var p2: Vector2 = pts[(i+1)%pts.size()] + Vector2(sin(pulse_time*17.0+i)*-2.0, 0)
		enemy.draw_line(p1, p2, Color(color.r,color.g,color.b,0.22+d), 1.5)
	for i in range(4):
		var y: float = -size*0.65 + i*size*0.42
		enemy.draw_line(Vector2(-size*0.55,y), Vector2(size*0.55, y+sin(pulse_time*12.0+i)*1.5),
			Color(color.r,color.g,color.b,0.11+d*0.45), 1.0)
	enemy.draw_circle(Vector2.ZERO, size*(0.2+d), Color(color.r,color.g,color.b,0.15))
