extends Node2D

var color: Color = Color.WHITE
var accent_color: Color = Color.WHITE
var attack_type: String = "single"
var _active_tween: Tween = null

func setup(p_color: Color = Color.WHITE, scale_factor: float = 1.0, p_attack_type: String = "single", p_accent_color: Color = Color.WHITE) -> void:
	color = p_color
	accent_color = p_accent_color
	attack_type = p_attack_type
	scale = Vector2.ZERO
	modulate.a = 1.0
	visible = true
	
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	# Quick burst animation
	_active_tween.parallel().tween_property(self, "scale", Vector2.ONE * scale_factor, 0.05)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	_active_tween.tween_callback(_release_to_pool)
	queue_redraw()

func _release_to_pool() -> void:
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release"):
		pool.release(self)
	else:
		call_deferred("free")

func reset_for_pool() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	color = Color.WHITE
	accent_color = Color.WHITE
	attack_type = "single"
	scale = Vector2.ONE
	modulate = Color.WHITE

func _draw() -> void:
	# Procedural flash: A bright core and a few rays
	var main_color = color
	var bright_color = Color.WHITE
	if attack_type == "void_bloom":
		draw_circle(Vector2.ZERO, 6, Color(main_color.r, main_color.g, main_color.b, 0.78))
		draw_arc(Vector2.ZERO, 10, -0.4, PI * 1.4, 24, Color(accent_color.r, accent_color.g, accent_color.b, 0.62), 1.4)
		draw_circle(Vector2.ZERO, 2.5, bright_color)
		return
	if attack_type == "toxic_bloom":
		draw_circle(Vector2.ZERO, 5, Color(main_color.r, main_color.g, main_color.b, 0.68))
		draw_arc(Vector2.ZERO, 8, -0.35, PI * 1.25, 18, Color(accent_color.r, accent_color.g, accent_color.b, 0.52), 1.2)
		draw_circle(Vector2.ZERO, 2.0, Color(0.78, 1.0, 0.45, 0.9))
		return
	
	# 1. Main Flare
	draw_circle(Vector2.ZERO, 8, main_color)
	draw_circle(Vector2.ZERO, 4, bright_color)
	
	# 2. Rays (pointing forward)
	var rays = 4 if attack_type == "splash" else 3
	for i in range(rays):
		var angle = -0.5 + (float(i) / max(1.0, float(rays - 1)))
		var ray_len = 18.0 if attack_type == "splash" else 14.0
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(Vector2.ZERO, dir * ray_len, main_color, 2.0)
		draw_line(Vector2.ZERO, dir * (ray_len * 0.6), bright_color, 1.0)
	if accent_color != Color.WHITE:
		draw_line(Vector2.ZERO, Vector2(12, 0), accent_color, 1.5)
