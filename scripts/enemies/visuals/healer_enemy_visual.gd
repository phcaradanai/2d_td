const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color := Color(0.4, 1.0, 0.4)
	color = B.apply_health_tint(color, int(enemy.get("health_visual_state")))
	var body_pts := PackedVector2Array([
		Vector2(0,-size), Vector2(size*0.7,size*0.5), Vector2(-size*0.7,size*0.5)
	])
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(color.r,color.g,color.b,0.85))
	enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float) -> void:
	var color := Color(0.4, 1.0, 0.4)
	var pulse_time: float = float(enemy.get("pulse_time"))
	var pts := PackedVector2Array()
	for i in range(12):
		var a: float = i * PI / 6.0
		var r: float = size if i % 3 != 0 else size * 0.6
		pts.append(Vector2(cos(a), sin(a)) * r)
	var heal_color := Color(0.62, 1.0, 0.86, 1.0)
	var gold       := Color(1.0, 0.88, 0.48, 1.0)
	enemy.draw_colored_polygon(pts, B.COLOR_BODY)
	B.draw_inner_plate(enemy, pts, heal_color, 0.58)
	enemy.draw_polyline(pts+PackedVector2Array([pts[0]]), Color(0,0,0,0.7), 3.0)
	enemy.draw_polyline(pts+PackedVector2Array([pts[0]]), heal_color, 2.0)
	enemy.draw_arc(Vector2.ZERO, size*0.8, pulse_time*2.6, pulse_time*2.6+PI, 24, gold, 2.0)
	enemy.draw_arc(Vector2.ZERO, size*1.2, -pulse_time*1.4, -pulse_time*1.4+PI*0.65, 20, Color(heal_color.r,heal_color.g,heal_color.b,0.48), 1.4)
	B.draw_orbiters(enemy, 4, size*1.14, 2.2, gold, 1.1)
	for i in range(4):
		var a: float = i * PI * 0.5 + PI * 0.25
		B.draw_circuit_line(enemy, Vector2.RIGHT.rotated(a)*size*0.25, Vector2.RIGHT.rotated(a)*size*0.78, heal_color, 1.1)
	B.draw_glow_core(enemy, Vector2.ZERO, size*0.5, heal_color)
