extends Node2D

var color: Color = Color(1.0, 0.2, 0.2, 0.8)

func _ready() -> void:
	# Hide legacy ColorRect if it exists
	var rect = get_node_or_null("ColorRect")
	if rect: rect.visible = false
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	# Initial state
	scale = Vector2.ONE
	modulate.a = 1.0
	
	# Expansion and fade
	tween.parallel().tween_property(self, "scale", Vector2(3.0, 3.0), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Draw shards flying out
	var num_shards = 4
	for i in range(num_shards):
		var ang = i * TAU / num_shards
		var pos = Vector2(cos(ang), sin(ang)) * 8.0
		var shard_pts = [
			pos + Vector2(2, 0),
			pos + Vector2(-2, -2),
			pos + Vector2(-2, 2)
		]
		draw_colored_polygon(shard_pts, color)
