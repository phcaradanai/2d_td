extends Node2D

var color: Color = Color(1.0, 0.4, 0.4, 1.0)
var max_radius: float = 100.0
var duration: float = 0.3
var elapsed: float = 0.0
var blades: int = 8
var blade_rotation: float = 0.0

func setup(p_color: Color, p_radius: float, p_duration: float = 0.35) -> void:
	color = p_color
	max_radius = p_radius
	duration = p_duration
	elapsed = 0.0
	blade_rotation = 0.0
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	blade_rotation += delta * 25.0 # Fast spin
	
	if elapsed >= duration:
		_release_to_pool()
		return

	if (Engine.get_process_frames() + get_instance_id()) % 2 == 0:
		queue_redraw()

func _release_to_pool() -> void:
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release"):
		pool.release(self)
	else:
		call_deferred("free")

func reset_for_pool() -> void:
	elapsed = 0.0
	blade_rotation = 0.0
	max_radius = 100.0
	duration = 0.3
	color = Color(1.0, 0.4, 0.4, 1.0)
	modulate = Color.WHITE

func _draw() -> void:
	var t = elapsed / duration
	var current_radius = max_radius * (0.2 + 0.8 * sin(t * PI * 0.5))
	var alpha = 1.0 - (elapsed / duration)
	
	var draw_color = color
	draw_color.a = alpha
	
	# Draw the "spinning blades" ring
	for i in range(blades):
		var angle = (float(i) / blades) * TAU + blade_rotation
		var inner_pt = Vector2.RIGHT.rotated(angle) * (current_radius * 0.2)
		var outer_pt = Vector2.RIGHT.rotated(angle) * current_radius
		
		# Blade shape (triangle-ish)
		var side_angle = 0.2 # Thickness of blade
		var p2 = Vector2.RIGHT.rotated(angle + side_angle) * (current_radius * 0.7)
		var p3 = Vector2.RIGHT.rotated(angle - side_angle) * (current_radius * 0.7)
		
		var pts = PackedVector2Array([inner_pt, p2, outer_pt, p3])
		draw_colored_polygon(pts, draw_color)
	
	# Subtle outer ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, draw_color, 2.0)
