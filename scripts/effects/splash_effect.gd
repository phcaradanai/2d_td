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
	# Outer shockwave ring
	draw_arc(Vector2.ZERO, radius * (elapsed/lifetime), 0, TAU, 48, Color(color.r, color.g, color.b, 1.0), 3.0)
	# Inner glowing field
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.2))
	# Tactical spikes
	for i in range(8):
		var ang = i * TAU / 8
		var inner = Vector2(cos(ang), sin(ang)) * (radius * 0.4)
		var outer = Vector2(cos(ang), sin(ang)) * radius
		draw_line(inner, outer, Color(color.r, color.g, color.b, 0.5), 2.0)
