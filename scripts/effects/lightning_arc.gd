extends Node2D

var start_pos: Vector2
var end_pos: Vector2
var color: Color = Color(0.5, 0.8, 1.0, 1.0)
var duration: float = 0.2
var elapsed: float = 0.0
var segments: Array[Vector2] = []

func setup(p_start: Vector2, p_end: Vector2, p_color: Color = Color(0.5, 0.8, 1.0, 1.0)) -> void:
	start_pos = p_start
	end_pos = p_end
	color = p_color
	elapsed = 0.0
	global_position = start_pos
	visible = true
	set_process(true)
	_generate_segments()
	queue_redraw()

func _generate_segments() -> void:
	segments.clear()
	segments.append(Vector2.ZERO) # Local start
	
	var local_end = to_local(end_pos)
	var diff = local_end
	var dist = diff.length()
	var num_points = int(dist / 15.0) + 2
	
	for i in range(1, num_points):
		var t = float(i) / num_points
		var base_p = diff * t
		# Add jaggedness perp to direction
		var perp = Vector2(-diff.y, diff.x).normalized()
		var offset = perp * randf_range(-10.0, 10.0)
		segments.append(base_p + offset)
	
	segments.append(local_end)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		_release_to_pool()
		return
	
	queue_redraw()

func _release_to_pool() -> void:
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release"):
		pool.release(self)
	else:
		call_deferred("free")

func reset_for_pool() -> void:
	elapsed = 0.0
	duration = 0.2
	segments.clear()
	color = Color(0.5, 0.8, 1.0, 1.0)
	modulate = Color.WHITE

func _draw() -> void:
	if segments.size() < 2: return
	
	var alpha = (1.0 - (elapsed / duration)) * 0.28
	var c = color
	c.a = alpha
	
	# Glow line
	var glow_c = c
	glow_c.a = minf(glow_c.a * 0.4, 0.18)
	draw_polyline(segments, glow_c, 6.0, true)
	
	# Core bolt
	draw_polyline(segments, c, 2.0, true)
