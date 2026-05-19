extends Node2D
class_name ImpactEffect

const MAX_ACTIVE: int = 40
static var _active_count: int = 0

var color: Color = Color.WHITE
var glow_color: Color = Color.WHITE
var accent_color: Color = Color.WHITE
var attack_type: String = "single"

func setup(p_color: Color = Color.WHITE, scale_factor: float = 1.0, p_attack_type: String = "single", p_glow_color: Color = Color.WHITE, p_accent_color: Color = Color.WHITE) -> void:
	color = p_color
	glow_color = p_glow_color
	accent_color = p_accent_color
	attack_type = p_attack_type
	
	# Hide legacy ColorRect if it exists
	var rect = get_node_or_null("ColorRect")
	if rect: rect.visible = false
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	# Initial state
	scale = Vector2.ZERO
	modulate.a = 1.0
	
	# Burst animation
	tween.parallel().tween_property(self, "scale", Vector2.ONE * scale_factor * 2.0, 0.2)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(_on_expire)

func _ready() -> void:
	ImpactEffect._active_count += 1
	add_to_group("impact_vfx_pool")

func _on_expire() -> void:
	ImpactEffect._active_count -= 1
	var pool := get_node_or_null("/root/ImpactVFXPool")
	if pool != null and has_meta("pooled"):
		pool.release(self)
	else:
		queue_free()

func _draw() -> void:
	if attack_type == "void_bloom":
		_draw_void_bloom()
		return
	if attack_type == "toxic_bloom":
		_draw_toxic_bloom()
		return

	# Draw multi-directional sparks
	var rays = 6 if attack_type == "splash" else 4
	var size = 8.0
	for i in range(rays):
		var angle = i * TAU / rays
		var spark_len = size * (1.2 if attack_type == "splash" else 0.9)
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(Vector2.ZERO, dir * spark_len, color, 1.5)
		# Secondary smaller spark
		draw_line(dir * (spark_len * 0.4), dir * (spark_len * 0.7), glow_color, 1.0)
	if attack_type == "slow":
		draw_arc(Vector2.ZERO, size * 0.9, 0, TAU, 18, accent_color, 1.5)
	elif attack_type == "splash":
		draw_arc(Vector2.ZERO, size * 1.15, 0, TAU, 18, accent_color, 2.0)
	
	# Inner core
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)

func _draw_void_bloom() -> void:
	var gold := color
	var violet := glow_color
	var green := accent_color
	draw_circle(Vector2.ZERO, 5.0, Color(gold.r, gold.g, gold.b, 0.72))
	draw_circle(Vector2.ZERO, 2.4, Color(1.0, 0.95, 0.72, 0.92))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 28, Color(violet.r, violet.g, violet.b, 0.76), 2.0)
	draw_arc(Vector2.ZERO, 13.0, PI * 0.2, PI * 1.72, 28, Color(violet.r, violet.g, violet.b, 0.42), 1.2)
	for i in range(5):
		var angle := float(i) * TAU / 5.0 + 0.22
		var inner := Vector2.RIGHT.rotated(angle) * 5.0
		var outer := Vector2.RIGHT.rotated(angle) * 13.0
		draw_line(inner, outer, Color(green.r, green.g, green.b, 0.68), 1.0)

func _draw_toxic_bloom() -> void:
	var green := color
	var purple := glow_color
	var spores := accent_color
	draw_circle(Vector2.ZERO, 6.0, Color(purple.r, purple.g, purple.b, 0.30))
	draw_circle(Vector2.ZERO, 3.6, Color(green.r, green.g, green.b, 0.58))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, Color(purple.r, purple.g, purple.b, 0.58), 1.6)
	draw_arc(Vector2.ZERO, 12.0, -0.25, PI * 1.35, 24, Color(green.r, green.g, green.b, 0.32), 1.0)
	var offsets := [
		Vector2(8.0, -2.0),
		Vector2(-7.0, -4.0),
		Vector2(-5.0, 6.0),
		Vector2(5.0, 7.0)
	]
	for offset in offsets:
		draw_circle(offset, 1.3, Color(spores.r, spores.g, spores.b, 0.74))
