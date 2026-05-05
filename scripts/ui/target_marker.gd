extends Node2D

@export var color: Color = Color.CYAN
@export var radius: float = 24.0
@export var thickness: float = 2.0
@export var rotation_speed: float = 2.0
@export var pulse_speed: float = 4.0
@export var pulse_magnitude: float = 0.2

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	rotation += rotation_speed * delta
	queue_redraw()

func _draw() -> void:
	var current_radius = radius * (1.0 + sin(time * pulse_speed) * pulse_magnitude)
	
	# Draw outer ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, color, thickness)
	
	# Draw crosshair ticks
	for i in range(4):
		var angle = i * PI / 2
		var dir = Vector2.from_angle(angle)
		var start = dir * (current_radius - 8)
		var end = dir * (current_radius + 4)
		draw_line(start, end, color, thickness)
	
	# Draw inner circle/dot
	draw_circle(Vector2.ZERO, 2.0, color)
