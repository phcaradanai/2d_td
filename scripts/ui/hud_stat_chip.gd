extends Control
class_name HUDStatChip

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")
const CreditIconDraw = preload("res://scripts/ui/credit_icon_draw.gd")

@export var icon_kind: String = "status":
	set(value):
		icon_kind = value
		queue_redraw()

@export var value_text: String = "":
	set(value):
		value_text = value
		_update_minimum_width()
		queue_redraw()

@export var accent_color: Color = NeonStyle.CYAN:
	set(value):
		accent_color = value
		queue_redraw()

@export var muted: bool = false:
	set(value):
		muted = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 38
	_update_minimum_width()

func configure(kind: String, text: String, accent: Color, is_muted: bool = false) -> void:
	var changed := icon_kind != kind or value_text != text or accent_color != accent or muted != is_muted
	icon_kind = kind
	value_text = text
	accent_color = accent
	muted = is_muted
	_update_minimum_width()
	if changed:
		queue_redraw()

func set_value(text: String, accent: Color = accent_color, is_muted: bool = muted) -> void:
	configure(icon_kind, text, accent, is_muted)

func _update_minimum_width() -> void:
	var font: Font = ThemeDB.fallback_font
	var width := font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x + 48.0
	custom_minimum_size.x = clampf(width, 72.0, 250.0)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return
	var alpha := 0.62 if muted else 1.0
	var border := Color(accent_color.r, accent_color.g, accent_color.b, 0.34 * alpha)
	var fill := Color(NeonStyle.BG_1.r, NeonStyle.BG_1.g, NeonStyle.BG_1.b, 0.84)
	var inner := rect.grow(-1.0)
	draw_rect(inner, fill, true)
	draw_rect(inner, border, false, 1.0)
	_draw_corner_ticks(inner, border)
	var icon_center := Vector2(18.0, rect.size.y * 0.5)
	_draw_icon(icon_center, accent_color, alpha)
	var text_color := _text_color(alpha)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(36.0, rect.size.y * 0.5 + 5.0),
		value_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 42.0,
		13,
		text_color
	)

func _text_color(alpha: float) -> Color:
	if icon_kind == "credits":
		return Color(NeonStyle.WARN.r, NeonStyle.WARN.g, NeonStyle.WARN.b, alpha)
	if icon_kind == "interest":
		return Color(NeonStyle.EL_INTEREST.r, NeonStyle.EL_INTEREST.g, NeonStyle.EL_INTEREST.b, alpha)
	if icon_kind == "core":
		return Color(NeonStyle.CYAN_2.r, NeonStyle.CYAN_2.g, NeonStyle.CYAN_2.b, alpha)
	return Color(NeonStyle.INK_1.r, NeonStyle.INK_1.g, NeonStyle.INK_1.b, alpha)

func _draw_corner_ticks(rect: Rect2, color: Color) -> void:
	var tick := 6.0
	var tick_color := Color(color.r, color.g, color.b, color.a * 0.75)
	draw_line(rect.position, rect.position + Vector2(tick, 0.0), tick_color, 1.0, true)
	draw_line(rect.position, rect.position + Vector2(0.0, tick), tick_color, 1.0, true)
	draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x - tick, rect.size.y), tick_color, 1.0, true)
	draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x, rect.size.y - tick), tick_color, 1.0, true)

func _icon_color(base: Color, alpha: float) -> Color:
	return Color(base.r, base.g, base.b, alpha)

func _draw_icon(center: Vector2, color: Color, alpha: float) -> void:
	match icon_kind:
		"credits":
			_draw_coin(center, color, alpha)
		"core":
			_draw_core(center, color, alpha)
		"wave":
			_draw_radar(center, color, alpha)
		"next":
			_draw_next(center, color, alpha)
		"interest":
			_draw_interest(center, color, alpha)
		_:
			_draw_status(center, color, alpha)

func _draw_coin(center: Vector2, color: Color, alpha: float) -> void:
	CreditIconDraw.draw_coin(self, center, alpha, 8.0)

func _draw_core(center: Vector2, color: Color, alpha: float) -> void:
	var c := _icon_color(NeonStyle.CYAN_2, alpha)
	var points := PackedVector2Array([
		center + Vector2(0.0, 8.0),
		center + Vector2(-8.0, 0.0),
		center + Vector2(-4.0, -7.0),
		center + Vector2(0.0, -3.0),
		center + Vector2(4.0, -7.0),
		center + Vector2(8.0, 0.0),
	])
	draw_colored_polygon(points, Color(c.r, c.g, c.b, 0.17 * alpha))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), c, 1.4, true)

func _draw_radar(center: Vector2, color: Color, alpha: float) -> void:
	var c := _icon_color(color, alpha)
	draw_arc(center, 8.0, PI * 1.12, PI * 1.88, 16, c, 1.2, true)
	draw_arc(center, 5.0, PI * 1.12, PI * 1.88, 12, Color(c.r, c.g, c.b, 0.70 * alpha), 1.0, true)
	draw_line(center, center + Vector2(7.0, -5.0), c, 1.2, true)
	draw_circle(center, 2.0, c)

func _draw_status(center: Vector2, color: Color, alpha: float) -> void:
	var c := _icon_color(color, alpha)
	draw_circle(center, 7.0, Color(c.r, c.g, c.b, 0.14 * alpha))
	draw_arc(center, 7.0, 0.0, TAU, 18, c, 1.2, true)
	draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), c, 1.2, true)

func _draw_next(center: Vector2, color: Color, alpha: float) -> void:
	var c := _icon_color(color, alpha)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -7.0),
		center + Vector2(7.0, 0.0),
		center + Vector2(0.0, 7.0),
		center + Vector2(-7.0, 0.0),
	])
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), c, 1.3, true)
	draw_line(center + Vector2(-2.0, -4.0), center + Vector2(3.0, 0.0), c, 1.2, true)
	draw_line(center + Vector2(3.0, 0.0), center + Vector2(-2.0, 4.0), c, 1.2, true)

func _draw_interest(center: Vector2, color: Color, alpha: float) -> void:
	var c := _icon_color(NeonStyle.EL_INTEREST, alpha)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -8.0),
		center + Vector2(8.0, 0.0),
		center + Vector2(0.0, 8.0),
		center + Vector2(-8.0, 0.0),
	])
	draw_colored_polygon(diamond, Color(c.r, c.g, c.b, 0.12 * alpha))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), c, 1.3, true)
	draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), c, 1.1, true)
