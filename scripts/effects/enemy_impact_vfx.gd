extends Node2D
class_name EnemyImpactVFX

var color: Color = Color.WHITE
var duration: float = 0.45
var time: float = 0.0
var mode: String = "impact"
var amount: float = 0.0
var debug_text: String = ""

func setup(p_mode: String, p_color: Color, p_duration: float = 0.45, p_amount: float = 0.0, p_debug_text: String = "") -> void:
	mode = p_mode
	color = p_color
	duration = p_duration
	amount = p_amount
	debug_text = p_debug_text

func _process(delta: float) -> void:
	time += delta
	if time >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t := clampf(time / duration, 0.0, 1.0)
	var a := 1.0 - t
	if mode == "heal_received":
		_draw_heal_received(t, a)
	elif mode == "shield_spark":
		_draw_shield_spark(t, a)
	elif mode == "split_burst":
		_draw_split_burst(t, a)
	else:
		draw_circle(Vector2.ZERO, 10.0 + t * 18.0, Color(color.r, color.g, color.b, 0.18 * a))
		draw_arc(Vector2.ZERO, 10.0 + t * 18.0, 0, TAU, 32, Color(color.r, color.g, color.b, 0.65 * a), 2.0)

func _draw_heal_received(t: float, a: float) -> void:
	draw_line(Vector2(0, -42 + t * 18), Vector2.ZERO, Color(1.0, 0.95, 0.65, 0.55 * a), 2.0)
	draw_arc(Vector2.ZERO, 8.0 + t * 20.0, 0, TAU, 40, Color(0.45, 1.0, 0.85, 0.55 * a), 2.0)
	for i in range(5):
		var x := sin(float(i) * 2.1 + time * 10.0) * 9.0
		var y := -34.0 + t * 38.0 + float(i) * 2.5
		draw_circle(Vector2(x, y), 1.8, Color(0.9, 1.0, 0.82, 0.8 * a))
	if OS.is_debug_build() and amount > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(10, -20 - t * 12.0), "+%d" % int(round(amount)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 1.0, 0.72, a))

func _draw_shield_spark(t: float, a: float) -> void:
	var alpha := minf(color.a, 0.24) * a
	draw_arc(Vector2.ZERO, 12.0 + t * 8.0, -PI * 0.15, PI * 1.15, 18, Color(color.r, color.g, color.b, alpha), 1.5)
	if OS.is_debug_build() and debug_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(8, -18), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(color.r, color.g, color.b, minf(a, 0.65)))

func _draw_split_burst(t: float, a: float) -> void:
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var p1 := Vector2.RIGHT.rotated(angle) * (8.0 + t * 12.0)
		var p2 := Vector2.RIGHT.rotated(angle + sin(i) * 0.08) * (18.0 + t * 42.0)
		draw_line(p1, p2, Color(color.r, color.g, color.b, 0.75 * a), 2.0)
	draw_arc(Vector2.ZERO, 10.0 + t * 38.0, 0, TAU, 48, Color(1.0, 0.85, 1.0, 0.45 * a), 2.0)
