extends Node2D

var velocity: Vector2
var color: Color = Color(0.8, 0.1, 0.1, 0.8)
var lifetime: float = 0.6
var elapsed: float = 0.0
var size: float = 2.0

func _ready() -> void:
	if has_meta("pooled"):
		return
	reset_particle()

func reset_particle() -> void:
	velocity = Vector2(randf_range(-20, 20), randf_range(10, 40))
	size = randf_range(1.5, 3.5)
	elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		_release_to_pool()
		return
	
	global_position += velocity * delta
	velocity.y += 100 * delta
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
	velocity = Vector2.ZERO
	size = 2.0
	modulate = Color.WHITE

func _draw() -> void:
	var alpha = 1.0 - (elapsed / lifetime)
	var c = color
	c.a = alpha
	draw_circle(Vector2.ZERO, size, c)
