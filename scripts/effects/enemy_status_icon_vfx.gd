extends Node2D
class_name EnemyStatusIconVFX

var icon_type: String = "shield"
var color: Color = Color.WHITE
var label_text: String = ""
var time: float = 0.0
var redraw_elapsed: float = 0.0
const REDRAW_INTERVAL := 0.25

func _ready() -> void:
	add_to_group("status_icons")

func setup(p_icon_type: String, p_color: Color, p_label: String = "") -> void:
	icon_type = p_icon_type
	color = p_color
	label_text = p_label
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	if PerformanceFirebreak.disable_status_animations:
		return
	redraw_elapsed += delta
	if redraw_elapsed >= REDRAW_INTERVAL:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	var pulse := 0.65 + sin(time * 6.0) * 0.2
	match icon_type:
		"reload_slow":
			_draw_reload_icon(pulse)
		"shield":
			_draw_shield_icon(pulse)
		"cloaked":
			_draw_cloak_icon(pulse)
		"air":
			_draw_air_icon(pulse)
		# [VISUAL-OPT] Compact role identity icons — replace area aura visuals.
		"healer_id":
			_draw_healer_id_icon(pulse)
		"heal_cast":
			_draw_heal_cast_icon(pulse)
		"disruptor_id":
			_draw_disruptor_id_icon(pulse)
		"bulwark_id":
			_draw_bulwark_id_icon(pulse)
		_:
			draw_circle(Vector2.ZERO, 7, Color(color.r, color.g, color.b, 0.35 * pulse))
	if OS.is_debug_build() and label_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(9, 4), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(color.r, color.g, color.b, 0.9))

func _draw_reload_icon(pulse: float) -> void:
	draw_arc(Vector2.ZERO, 8.0, -PI * 0.25, PI * 1.35, 24, Color(color.r, color.g, color.b, 0.75 * pulse), 2.0)
	draw_line(Vector2(0, 0), Vector2(0, -6), Color(1, 1, 1, 0.85 * pulse), 1.5)
	draw_line(Vector2(0, 0), Vector2(5, 1), Color(1, 1, 1, 0.85 * pulse), 1.5)

func _draw_shield_icon(pulse: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -9), Vector2(8, -4), Vector2(5, 8), Vector2(0, 11), Vector2(-5, 8), Vector2(-8, -4)])
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.18 * pulse))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.8 * pulse), 1.5)

func _draw_cloak_icon(pulse: float) -> void:
	for i in range(4):
		var y := -7.0 + float(i) * 4.5
		draw_line(Vector2(-8 + sin(time * 9.0 + i) * 2.0, y), Vector2(8 + sin(time * 8.0 + i) * 2.0, y), Color(color.r, color.g, color.b, 0.55 * pulse), 1.25)

func _draw_air_icon(pulse: float) -> void:
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 24, Color(color.r, color.g, color.b, 0.55 * pulse), 1.25)
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color(color.r, color.g, color.b, 0.7 * pulse), 1.5)
	draw_line(Vector2(0, -8), Vector2(0, 8), Color(color.r, color.g, color.b, 0.35 * pulse), 1.0)

# [VISUAL-OPT] Compact green cross/plus — healer identity marker.
func _draw_healer_id_icon(pulse: float) -> void:
	var s := 5.5
	var c := Color(color.r, color.g, color.b, 0.9 * pulse)
	draw_line(Vector2(-s, 0.0), Vector2(s, 0.0), c, 2.5)
	draw_line(Vector2(0.0, -s), Vector2(0.0, s), c, 2.5)
	draw_circle(Vector2.ZERO, 1.5, Color(1.0, 1.0, 1.0, 0.7 * pulse))

func _draw_heal_cast_icon(pulse: float) -> void:
	var s := 7.0
	var c := Color(color.r, color.g, color.b, 0.95 * pulse)
	draw_circle(Vector2.ZERO, 9.0, Color(color.r, color.g, color.b, 0.12 * pulse))
	draw_line(Vector2(-s, 0.0), Vector2(s, 0.0), c, 3.0)
	draw_line(Vector2(0.0, -s), Vector2(0.0, s), c, 3.0)
	draw_arc(Vector2.ZERO, 10.0, -PI * 0.15, PI * 1.15, 14, Color(color.r, color.g, color.b, 0.38 * pulse), 1.2)

# [VISUAL-OPT] Compact rotating triangle — disruptor jammer identity marker.
func _draw_disruptor_id_icon(pulse: float) -> void:
	# Slow rotation — one full turn every ~5 s.
	var rot := time * 1.26
	var r := 6.5
	var pts := PackedVector2Array()
	for i in range(3):
		var a := rot + float(i) * TAU / 3.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.85 * pulse), 1.8)
	draw_circle(Vector2.ZERO, 2.0, Color(color.r, color.g, color.b, 0.7 * pulse))

# [VISUAL-OPT] Compact shield outline — bulwark identity marker.
func _draw_bulwark_id_icon(pulse: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -8), Vector2(7, -3), Vector2(4, 7), Vector2(0, 9), Vector2(-4, 7), Vector2(-7, -3)])
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.85 * pulse), 1.8)
	draw_circle(Vector2.ZERO, 2.2, Color(color.r, color.g, color.b, 0.5 * pulse))
