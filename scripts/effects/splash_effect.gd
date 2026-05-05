extends Node2D

var radius: float = 50.0
var color: Color = Color(1.0, 0.4, 0.1, 0.6)
var lifetime: float = 0.3
var elapsed: float = 0.0

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")

func setup(p_radius: float, p_color: Color = Color(1.0, 0.4, 0.1, 0.6)) -> void:
	radius = p_radius
	color = p_color
	# Initial flash
	var tween = create_tween()
	scale = Vector2(0.2, 0.2)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return
		
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
	else:
		# Fade out
		modulate.a = 1.0 - (elapsed / lifetime)
		queue_redraw()

func _draw() -> void:
	var progress = elapsed / lifetime
	# Outer shockwave ring - expands
	draw_arc(Vector2.ZERO, radius * progress, 0, TAU, 48, Color(color.r, color.g, color.b, 1.0 - progress), 4.0)
	# Inner glowing field
	draw_circle(Vector2.ZERO, radius * (1.0 - progress * 0.5), Color(color.r, color.g, color.b, 0.2 * (1.0 - progress)))
	
	# Shrapnel/Debris
	var seed_val = int(global_position.x + global_position.y)
	seed(seed_val)
	for i in range(12):
		var ang = i * TAU / 12 + (progress * 0.5)
		var dist = radius * (0.3 + progress * 0.7)
		var size = 4.0 * (1.0 - progress)
		var p = Vector2(cos(ang), sin(ang)) * dist
		draw_rect(Rect2(p.x - size/2, p.y - size/2, size, size), color)
		# Add a small white core to some debris
		if i % 3 == 0:
			draw_rect(Rect2(p.x - size/4, p.y - size/4, size/2, size/2), Color.WHITE)
	# Reset seed
	seed(Time.get_ticks_msec())
