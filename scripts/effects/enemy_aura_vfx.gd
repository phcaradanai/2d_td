extends Node2D
class_name EnemyAuraVFX

# [VISUAL-OPT] Aura node retained for debug/radius visualization only.
# By default these are hidden (debug_show_* flags = false in EnemyVFXController).
# When visible, drawing is throttled to ~8 fps and uses minimal geometry.

const KIND_HEAL := "heal"
const KIND_EMP := "emp"
const KIND_SHIELD := "shield"
const KIND_DEBUG := "debug"

var radius: float = 96.0
var kind: String = KIND_DEBUG
var exact_radius_visible: bool = false
var active: bool = true
var quality: int = 1
var time: float = 0.0
var fade: float = 1.0

# [VISUAL-OPT] Throttle redraws to ~8 fps instead of every frame.
var _redraw_accum: float = 0.0
const _REDRAW_INTERVAL: float = 0.125

func setup(p_kind: String, p_radius: float, p_quality: int = 1) -> void:
	kind = p_kind
	radius = max(0.0, p_radius)
	quality = p_quality
	queue_redraw()

func set_exact_radius_visible(value: bool) -> void:
	exact_radius_visible = value
	queue_redraw()

func set_active(value: bool) -> void:
	active = value
	queue_redraw()

func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "fade", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	time += delta
	# [VISUAL-OPT] Only redraw at ~8 fps to reduce GPU overhead when visible.
	_redraw_accum += delta
	if _redraw_accum >= _REDRAW_INTERVAL:
		_redraw_accum = 0.0
		queue_redraw()

func _draw() -> void:
	if radius <= 0.0 or fade <= 0.01:
		return
	var pulse := 0.5 + sin(time * 2.2) * 0.5
	var base := _base_color()
	var line_alpha := (0.18 + pulse * 0.10) * fade
	if not active:
		line_alpha *= 0.45
	# [VISUAL-OPT] Removed large filled circle (was biggest cost).
	# Thin ring only, 24 segments instead of 96.
	draw_arc(Vector2.ZERO, radius * (0.995 + pulse * 0.01), 0.0, TAU, 24, Color(base.r, base.g, base.b, line_alpha), 1.5)
	_draw_role_ticks(base, pulse)
	if exact_radius_visible:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55 * fade), 1.25)

func _draw_role_ticks(color: Color, pulse: float) -> void:
	# [VISUAL-OPT] Reduced tick count from 16 to 6 for debug ring decoration.
	var tick_count := 6
	for i in range(tick_count):
		var a := float(i) / float(tick_count) * TAU
		if kind == KIND_HEAL:
			a += time * 0.22
		elif kind == KIND_EMP:
			a += sin(time * 5.0 + i) * 0.035
		elif kind == KIND_SHIELD:
			a += time * 0.08
		var len := 6.0
		var p1 := Vector2.RIGHT.rotated(a) * (radius - len)
		var p2 := Vector2.RIGHT.rotated(a) * (radius + 2.0)
		draw_line(p1, p2, Color(color.r, color.g, color.b, (0.22 + pulse * 0.18) * fade), 1.5)

func _base_color() -> Color:
	match kind:
		KIND_HEAL:
			return Color(0.55, 1.0, 0.9, 1.0)
		KIND_EMP:
			return Color(0.95, 0.18, 0.9, 1.0)
		KIND_SHIELD:
			return Color(0.25, 0.8, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)
