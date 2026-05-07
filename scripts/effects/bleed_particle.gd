extends Node2D

var velocity: Vector2
var color: Color = Color(0.8, 0.1, 0.1, 0.8)
var lifetime: float = 0.6
var elapsed: float = 0.0
var size: float = 2.0

func _ready() -> void:
	velocity = Vector2(randf_range(-20, 20), randf_range(10, 40))
	size = randf_range(1.5, 3.5)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	
	global_position += velocity * delta
	# Gravity-ish
	velocity.y += 100 * delta
	
	queue_redraw()

func _draw() -> void:
	var alpha = 1.0 - (elapsed / lifetime)
	var c = color
	c.a = alpha
	draw_circle(Vector2.ZERO, size, c)
