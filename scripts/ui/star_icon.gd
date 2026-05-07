extends Control
class_name StarIcon

# StarIcon
# Procedural star rendering for consistent visual across platforms (Web/Mobile).
# Avoids issues with unicode/emoji stars in browser exports.

@export var filled: bool = false:
	set(v):
		filled = v
		queue_redraw()

@export var filled_color: Color = Color(1.0, 0.8, 0.2) # Gold/Neon Yellow
@export var empty_color: Color = Color(0.4, 0.5, 0.6, 0.3) # Dim blue-gray outline

func _draw() -> void:
	var s = get_size()
	var center = s / 2.0
	var radius = min(s.x, s.y) / 2.0 - 2.0
	
	if radius <= 0: return
	
	var points = PackedVector2Array()
	# 5-pointed star has 10 vertices
	for i in range(10):
		var angle = deg_to_rad(i * 36 - 90)
		var r = radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	
	if filled:
		# Filled star with neon-like border
		draw_colored_polygon(points, filled_color)
		draw_polyline(points + PackedVector2Array([points[0]]), filled_color.lightened(0.4), 1.5, true)
	else:
		# Empty star outline
		draw_polyline(points + PackedVector2Array([points[0]]), empty_color, 2.0, true)
