extends Node2D
class_name SplashEffect

const MAX_ACTIVE: int = 30
static var _active_count: int = 0

var radius: float = 50.0
var color: Color = Color(1.0, 0.4, 0.1, 0.6)
var lifetime: float = 0.3
var elapsed: float = 0.0

# Throttle redraws — 30 Hz is plenty for a short-lived expanding ring.
# At 60 FPS this halves the draw calls produced by every cannon splash.
var _redraw_timer: float = 0.0
const REDRAW_INTERVAL := 0.033  # ~30 Hz

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")

func _ready() -> void:
	SplashEffect._active_count += 1

func _on_expire() -> void:
	SplashEffect._active_count -= 1
	queue_free()

func setup(p_radius: float, p_color: Color = Color(1.0, 0.4, 0.1, 0.6)) -> void:
	radius = p_radius
	color = p_color
	var tween = create_tween()
	scale = Vector2(0.2, 0.2)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return

	elapsed += delta
	if elapsed >= lifetime:
		_on_expire()
		return

	modulate.a = 1.0 - (elapsed / lifetime)
	_redraw_timer += delta
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer -= REDRAW_INTERVAL
		queue_redraw()

func _draw() -> void:
	var progress = elapsed / lifetime
	# Expanding shockwave ring
	draw_arc(Vector2.ZERO, radius * progress, 0, TAU, 48, Color(color.r, color.g, color.b, 1.0 - progress), 4.0)
	# Fading inner field
	draw_circle(Vector2.ZERO, radius * (1.0 - progress * 0.5), Color(color.r, color.g, color.b, 0.2 * (1.0 - progress)))

	# Debris shrapnel
	var seed_val = int(global_position.x + global_position.y)
	seed(seed_val)
	for i in range(12):
		var ang = i * TAU / 12 + (progress * 0.5)
		var dist = radius * (0.3 + progress * 0.7)
		var size = 4.0 * (1.0 - progress)
		var p = Vector2(cos(ang), sin(ang)) * dist
		draw_rect(Rect2(p.x - size * 0.5, p.y - size * 0.5, size, size), color)
		if i % 3 == 0:
			draw_rect(Rect2(p.x - size * 0.25, p.y - size * 0.25, size * 0.5, size * 0.5), Color.WHITE)
	seed(Time.get_ticks_msec())
