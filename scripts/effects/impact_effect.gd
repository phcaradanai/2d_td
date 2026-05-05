extends Node2D

var color: Color = Color.WHITE

func setup(p_color: Color = Color.WHITE, scale_factor: float = 1.0) -> void:
	color = p_color
	
	# Hide legacy ColorRect if it exists
	var rect = get_node_or_null("ColorRect")
	if rect: rect.visible = false
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	# Initial state
	scale = Vector2.ZERO
	modulate.a = 1.0
	
	# Burst animation
	tween.parallel().tween_property(self, "scale", Vector2.ONE * scale_factor * 2.0, 0.2)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Draw multi-directional sparks
	var rays = 8
	var size = 8.0
	for i in range(rays):
		var angle = i * TAU / rays
		var spark_len = size * (0.8 + randf() * 0.4)
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(Vector2.ZERO, dir * spark_len, color, 1.5)
		# Secondary smaller spark
		draw_line(dir * (spark_len * 0.4), dir * (spark_len * 0.7), Color.WHITE, 1.0)
	
	# Inner core
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
