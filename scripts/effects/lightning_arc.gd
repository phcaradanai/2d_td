extends Node2D

var start_pos: Vector2
var end_pos: Vector2
var color: Color = Color(0.5, 0.8, 1.0, 1.0)
var duration: float = 0.2
var elapsed: float = 0.0
var segments: Array[Vector2] = []
var flicker_timer: float = 0.0

func setup(p_start: Vector2, p_end: Vector2, p_color: Color = Color(0.5, 0.8, 1.0, 1.0)) -> void:
	start_pos = p_start
	end_pos = p_end
	color = p_color
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
	flicker_timer += delta
	
	if flicker_timer > 0.04:
		_generate_segments()
		flicker_timer = 0.0
		
	if elapsed >= duration:
		queue_free()
		return
	
	queue_redraw()

func _draw() -> void:
	if segments.size() < 2: return
	
	var alpha = 1.0 - (elapsed / duration)
	var c = color
	c.a = alpha
	
	# Glow line
	var glow_c = c
	glow_c.a *= 0.4
	draw_polyline(segments, glow_c, 6.0, true)
	
	# Core bolt
	draw_polyline(segments, c, 2.0, true)
