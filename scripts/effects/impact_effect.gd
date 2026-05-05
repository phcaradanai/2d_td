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
	# Draw a cross burst
	var size = 6.0
	draw_line(Vector2(-size, 0), Vector2(size, 0), color, 2.0)
	draw_line(Vector2(0, -size), Vector2(0, size), color, 2.0)
	# Inner glow
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
