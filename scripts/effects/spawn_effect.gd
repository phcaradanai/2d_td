extends Node2D

var color: Color = Color(0.4, 0.7, 1.0, 0.6) # Cyan/Blue portal glow
var size: float = 24.0

func setup(p_color: Color, p_size: float = 24.0) -> void:
	color = p_color
	size = p_size
	
	scale = Vector2.ZERO
	modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	var out_tween = create_tween().set_parallel(true)
	out_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	out_tween.tween_interval(0.4) # Stay a bit
	out_tween.chain().tween_property(self, "scale", Vector2(0.5, 1.5), 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	out_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	out_tween.chain().tween_callback(queue_free)

func _draw() -> void:
	# Draw a glowing ring/portal
	draw_arc(Vector2.ZERO, size, 0, TAU, 32, color, 3.0, true)
	draw_circle(Vector2.ZERO, size * 0.6, Color(color.r, color.g, color.b, 0.2))
	
	# Small particles/rays
	for i in range(4):
		var angle = (float(i)/4.0) * TAU + (Time.get_ticks_msec() * 0.005)
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(dir * size * 0.8, dir * size * 1.2, color, 1.5)
