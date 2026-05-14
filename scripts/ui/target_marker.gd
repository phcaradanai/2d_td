extends Node2D

@export var color: Color = Color.CYAN
@export var radius: float = 24.0
@export var thickness: float = 2.0
@export var rotation_speed: float = 2.0
@export var pulse_speed: float = 6.0
@export var pulse_magnitude: float = 0.35

var time: float = 0.0

# Throttle: redraw at 20 Hz instead of 60 Hz. The ring is small and subtle;
# 20 FPS is indistinguishable from 60 FPS at gameplay scale.
var _redraw_timer: float = 0.0
const REDRAW_INTERVAL := 0.05  # 20 Hz

func _process(delta: float) -> void:
	time += delta
	rotation += rotation_speed * delta
	_redraw_timer += delta
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer -= REDRAW_INTERVAL
		queue_redraw()

func _draw() -> void:
	var current_radius = radius * (1.0 + sin(time * pulse_speed) * pulse_magnitude)

	# Outer ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, color, thickness)

	# Crosshair ticks
	for i in range(4):
		var angle = i * PI / 2
		var dir = Vector2.from_angle(angle)
		draw_line(dir * (current_radius - 8), dir * (current_radius + 4), color, thickness)

	# Inner dot
	draw_circle(Vector2.ZERO, 2.0, color)
