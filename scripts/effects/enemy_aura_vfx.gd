extends Node2D
class_name EnemyAuraVFX

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
	queue_redraw()

func _draw() -> void:
	if radius <= 0.0 or fade <= 0.01:
		return
	var pulse := 0.5 + sin(time * 2.2) * 0.5
	var base := _base_color()
	var line_alpha := (0.12 + pulse * 0.08) * fade
	var fill_alpha := (0.025 + pulse * 0.012) * fade
	if not active:
		line_alpha *= 0.45
		fill_alpha *= 0.35
	draw_circle(Vector2.ZERO, radius, Color(base.r, base.g, base.b, fill_alpha))
	draw_arc(Vector2.ZERO, radius * (0.995 + pulse * 0.01), 0.0, TAU, 96, Color(base.r, base.g, base.b, line_alpha), 2.0)
	_draw_role_ticks(base, pulse)
	if exact_radius_visible:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(1.0, 1.0, 1.0, 0.55 * fade), 1.25)

func _draw_role_ticks(color: Color, pulse: float) -> void:
	var tick_count := 16
	if quality <= 0:
		tick_count = 8
	for i in range(tick_count):
		var a := float(i) / float(tick_count) * TAU
		if kind == KIND_HEAL:
			a += time * 0.22
		elif kind == KIND_EMP:
			a += sin(time * 5.0 + i) * 0.035
		elif kind == KIND_SHIELD:
			a += time * 0.08
		var len := 7.0
		if kind == KIND_EMP and i % 3 == 0:
			len = 13.0
		var p1 := Vector2.RIGHT.rotated(a) * (radius - len)
		var p2 := Vector2.RIGHT.rotated(a) * (radius + 2.0)
		draw_line(p1, p2, Color(color.r, color.g, color.b, (0.18 + pulse * 0.18) * fade), 1.5)
	if kind == KIND_SHIELD:
		for i in range(6):
			var a := float(i) / 6.0 * TAU + time * 0.12
			draw_arc(Vector2.ZERO, radius * 0.72, a, a + 0.32, 8, Color(color.r, color.g, color.b, 0.22 * fade), 2.0)
	elif kind == KIND_EMP:
		for i in range(5):
			var a := float(i) / 5.0 * TAU + sin(time * 7.0 + i) * 0.2
			var p1 := Vector2.RIGHT.rotated(a) * radius * 0.55
			var p2 := Vector2.RIGHT.rotated(a + 0.08) * radius * 0.95
			draw_line(p1, p2, Color(1.0, 0.16, 0.55, 0.18 * fade), 1.0)

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
