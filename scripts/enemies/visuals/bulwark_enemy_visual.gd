const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float, color: Color = B.COLOR_NEON_BULWARK) -> void:
	var body_pts := PackedVector2Array()
	for j in 6:
		var a: float = j * TAU / 6.0 - PI / 6.0
		body_pts.append(Vector2(cos(a), sin(a)) * size * 1.2)
	var tinted := B.apply_health_tint(color, int(enemy.get("health_visual_state")))
	enemy.draw_colored_polygon(B.scale_polygon(body_pts, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body_pts, Color(tinted.r, tinted.g, tinted.b, 0.85))
	enemy.draw_circle(Vector2.ZERO, size * 0.3, Color.WHITE)

static func draw(enemy: Node2D, size: float, color: Color = B.COLOR_NEON_BULWARK) -> void:
	var rect := Rect2(-size, -size*0.8, size*2, size*1.6)
	enemy.draw_rect(rect, B.COLOR_BODY)
	enemy.draw_line(Vector2(0,-size*0.8), Vector2(0,size*0.8), color*0.5)
	enemy.draw_rect(Rect2(-size*0.72,-size*0.52, size*0.46,size*1.04), Color(color.r,color.g,color.b,0.12))
	enemy.draw_rect(Rect2( size*0.26,-size*0.52, size*0.46,size*1.04), Color(color.r,color.g,color.b,0.12))
	enemy.draw_line(Vector2(-size,-size*0.8), Vector2(size,-size*0.8), Color(0,0,0,0.75), 2.5)
	enemy.draw_line(Vector2(-size, size*0.8), Vector2(size, size*0.8), Color(0,0,0,0.75), 2.5)
	enemy.draw_polyline(PackedVector2Array([Vector2(size,-size*0.8),Vector2(size,size*0.8)]), color, 3.0)
	enemy.draw_polyline(PackedVector2Array([Vector2(-size,-size*0.8),Vector2(-size,size*0.8)]), color, 3.0)
	for i in range(3):
		var y: float = -size*0.4 + i*(size*0.4)
		B.draw_glow_core(enemy, Vector2(size*0.8,y),  4.0, color)
		B.draw_glow_core(enemy, Vector2(-size*0.8,y), 4.0, color)
	var shield_radius: float = float(enemy.get("shield_radius"))
	B.draw_shield_dome(enemy, shield_radius, color)
