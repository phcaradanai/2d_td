extends Node2D

var color: Color = Color.WHITE

func setup(p_color: Color = Color.WHITE, scale_factor: float = 1.0) -> void:
	color = p_color
	scale = Vector2.ZERO
	modulate.a = 1.0
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	# Quick burst animation
	tween.parallel().tween_property(self, "scale", Vector2.ONE * scale_factor, 0.05)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Procedural flash: A bright core and a few rays
	var main_color = color
	var bright_color = Color.WHITE
	
	# 1. Main Flare
	draw_circle(Vector2.ZERO, 8, main_color)
	draw_circle(Vector2.ZERO, 4, bright_color)
	
	# 2. Rays (pointing forward)
	var rays = 3
	for i in range(rays):
		var angle = -0.5 + (float(i) / (rays-1))
		var ray_len = 16.0 + randf() * 8.0
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(Vector2.ZERO, dir * ray_len, main_color, 2.0)
		draw_line(Vector2.ZERO, dir * (ray_len * 0.6), bright_color, 1.0)
