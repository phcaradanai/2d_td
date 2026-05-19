extends Node2D

# [VISUAL-OPT] Defaults reduced: duration 0.4→0.28, particle_count 8→4.
var color: Color = Color(1.0, 0.2, 0.2, 0.8)
var mode: String = "default"
var duration: float = 0.28
var particle_count: int = 4

func setup(p_mode: String = "default", p_color: Color = Color(1.0, 0.2, 0.2, 0.8), p_duration: float = 0.28, p_particle_count: int = 4) -> void:
	mode = p_mode
	color = p_color
	duration = p_duration
	particle_count = p_particle_count

func _ready() -> void:
	if PerformanceFirebreak.disable_death_effects:
		queue_free()
		return
	# Hide legacy ColorRect if it exists
	var rect = get_node_or_null("ColorRect")
	if rect: rect.visible = false

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)

	# Initial state
	scale = Vector2.ONE
	modulate.a = 1.0

	# [VISUAL-OPT] Expansion scale reduced: 3.0→1.8 default, 2.35→1.6 swarm_death.
	var target_scale := Vector2(1.8, 1.8)
	if mode == "swarm_hit":
		target_scale = Vector2(1.3, 1.3)
	elif mode == "swarm_death":
		target_scale = Vector2(1.6, 1.6)
	tween.parallel().tween_property(self, "scale", target_scale, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_callback(queue_free)

func _draw() -> void:
	if mode == "swarm_hit":
		_draw_swarm_hit()
		return
	if mode == "swarm_death":
		_draw_swarm_death()
		return
	_draw_default_pop()

func _draw_default_pop() -> void:
	# [VISUAL-OPT] Capped shards at 4 max. Removed large expanding ring.
	var num_shards = mini(particle_count, 4)
	var seed_val = int(global_position.x * 10 + global_position.y)
	seed(seed_val)

	for i in range(num_shards):
		var ang = i * TAU / num_shards + randf() * 0.5
		var dist = 7.0 + randf() * 3.0
		var pos = Vector2(cos(ang), sin(ang)) * dist
		var s = 2.0 + randf() * 1.5

		var shard_pts = PackedVector2Array([
			pos + Vector2(s, 0).rotated(randf() * TAU),
			pos + Vector2(-s, -s).rotated(randf() * TAU),
			pos + Vector2(-s, s).rotated(randf() * TAU)
		])
		draw_colored_polygon(shard_pts, color)

	# Small core flash instead of large ring
	draw_circle(Vector2.ZERO, 3.5, Color(color.r, color.g, color.b, 0.55))

	# Reset seed
	seed(Time.get_ticks_msec())

func _draw_swarm_hit() -> void:
	var seed_val = int(global_position.x * 13 + global_position.y * 7)
	seed(seed_val)
	for i in range(particle_count):
		var ang := float(i) / float(max(particle_count, 1)) * TAU + randf_range(-0.18, 0.18)
		var dir := Vector2.RIGHT.rotated(ang)
		var inner := dir * randf_range(2.0, 4.0)
		var outer := dir * randf_range(5.0, 8.0)
		draw_line(inner, outer, Color(color.r, color.g, color.b, 0.72), 1.0)
		if i % 2 == 0:
			var s := randf_range(1.2, 1.8)
			var p := outer
			draw_colored_polygon(PackedVector2Array([
				p + dir * s,
				p + dir.rotated(2.3) * s,
				p + dir.rotated(-2.3) * s
			]), Color(0.718, 1.0, 0.961, 0.78))
	draw_circle(Vector2.ZERO, 2.0, Color(0.718, 1.0, 0.961, 0.8))
	seed(Time.get_ticks_msec())

func _draw_swarm_death() -> void:
	# [VISUAL-OPT] Arc segments reduced from 6 to 4.
	var seed_val = int(global_position.x * 17 + global_position.y * 11)
	seed(seed_val)
	for i in range(particle_count):
		var ang := float(i) / float(max(particle_count, 1)) * TAU + randf_range(-0.28, 0.28)
		var dir := Vector2.RIGHT.rotated(ang)
		var pos := dir * randf_range(4.0, 11.0)
		if i % 2 == 0:
			draw_circle(pos, randf_range(0.8, 1.3), Color(0.718, 1.0, 0.961, 0.82))
		else:
			var s := randf_range(1.4, 2.4)
			draw_colored_polygon(PackedVector2Array([
				pos + dir * s,
				pos + dir.rotated(2.2) * s,
				pos + dir.rotated(-2.2) * s
			]), Color(color.r, color.g, color.b, 0.66))
	draw_arc(Vector2.ZERO, 5.5, 0, TAU, 4, Color(color.r, color.g, color.b, 0.34), 1.0)
	seed(Time.get_ticks_msec())
