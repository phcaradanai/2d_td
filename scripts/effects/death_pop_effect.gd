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
	# Draw shards flying out with variation
	var num_shards = 8
	# Use a stable seed for the draw call based on position
	var seed_val = int(global_position.x * 10 + global_position.y)
	seed(seed_val)
	
	for i in range(num_shards):
		var ang = i * TAU / num_shards + randf() * 0.5
		var dist = 8.0 + randf() * 4.0
		var pos = Vector2(cos(ang), sin(ang)) * dist
		var s = 2.0 + randf() * 2.0
		
		var shard_pts = PackedVector2Array([
			pos + Vector2(s, 0).rotated(randf() * TAU),
			pos + Vector2(-s, -s).rotated(randf() * TAU),
			pos + Vector2(-s, s).rotated(randf() * TAU)
		])
		draw_colored_polygon(shard_pts, color)
		# Add a tiny white dot to some shards
		if i % 2 == 0:
			draw_circle(pos, 1.0, Color.WHITE)
	
	# Expanding ring
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 24, Color(color.r, color.g, color.b, 0.4), 1.0)
	
	# Reset seed
	seed(Time.get_ticks_msec())
