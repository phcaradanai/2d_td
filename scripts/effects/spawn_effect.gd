extends Node2D

var color: Color = Color(0.4, 0.7, 1.0, 0.6) # Cyan/Blue portal glow
var size: float = 24.0
var mode: String = "portal"
var time_alive: float = 0.0

func setup(p_color: Color, p_size: float = 24.0, p_mode: String = "portal") -> void:
	color = p_color
	size = p_size
	mode = p_mode
	
	scale = Vector2.ZERO
	modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	var intro_duration := 0.18 if mode == "swarm" else 0.25
	tween.tween_property(self, "scale", Vector2.ONE, intro_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, min(intro_duration, 0.2))
	
	var out_tween = create_tween().set_parallel(true)
	out_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	out_tween.tween_interval(0.24 if mode == "swarm" else 0.4)
	out_tween.chain().tween_property(self, "scale", Vector2(0.55, 1.35) if mode == "swarm" else Vector2(0.5, 1.5), 0.16 if mode == "swarm" else 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	out_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16 if mode == "swarm" else 0.2)
	out_tween.chain().tween_callback(queue_free)

func _process(delta: float) -> void:
	time_alive += delta
	queue_redraw()

func _draw() -> void:
	if mode == "swarm":
		_draw_swarm_materialize()
		return
	_draw_portal()

func _draw_portal() -> void:
	# Draw a glowing ring/portal
	draw_arc(Vector2.ZERO, size, 0, TAU, 32, color, 3.0, true)
	draw_circle(Vector2.ZERO, size * 0.6, Color(color.r, color.g, color.b, 0.2))
	
	# Small particles/rays
	for i in range(4):
		var angle = (float(i)/4.0) * TAU + (Time.get_ticks_msec() * 0.005)
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(dir * size * 0.8, dir * size * 1.2, color, 1.5)

func _draw_swarm_materialize() -> void:
	var cyan := Color(0.0, 0.941, 1.0, 1.0)
	var green := Color(0.224, 1.0, 0.478, 1.0)
	var glow := Color(0.718, 1.0, 0.961, 1.0)
	var phase := clampf(time_alive / 0.42, 0.0, 1.0)
	for i in range(5):
		var x := (-2.0 + float(i)) * size * 0.18
		var h := size * (0.7 + float(i % 2) * 0.24) * (1.0 - phase * 0.35)
		draw_line(Vector2(x, -h), Vector2(x, h), Color(cyan.r, cyan.g, cyan.b, 0.18 * (1.0 - phase)), 1.0)
	for i in range(7):
		var a := float(i) / 7.0 * TAU + time_alive * 5.0
		var r := size * (0.34 + float(i % 3) * 0.12) * (1.0 - phase * 0.45)
		var p := Vector2(cos(a), sin(a)) * r
		if i % 2 == 0:
			_draw_hex(p, size * 0.09, Color(cyan.r, cyan.g, cyan.b, 0.5))
		else:
			var dir := Vector2.RIGHT.rotated(a)
			draw_colored_polygon(PackedVector2Array([
				p + dir * size * 0.12,
				p + dir.rotated(2.35) * size * 0.08,
				p + dir.rotated(-2.35) * size * 0.08
			]), Color(green.r, green.g, green.b, 0.35))
	draw_arc(Vector2.ZERO, size * (0.42 + phase * 0.08), 0, TAU, 6, Color(glow.r, glow.g, glow.b, 0.55 * (1.0 - phase * 0.5)), 1.2)
	draw_circle(Vector2.ZERO, size * 0.12, Color(glow.r, glow.g, glow.b, 0.38))

func _draw_hex(center: Vector2, radius: float, draw_color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var a := PI / 6.0 + float(i) * TAU / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts + PackedVector2Array([pts[0]]), draw_color, 1.0)
