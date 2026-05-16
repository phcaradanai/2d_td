extends Control
class_name TowerRowTrim

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

static var _color_cache: Dictionary = {}

var elements: Array[String] = []
var is_locked := false
var is_affordable := true
var is_selected := false
var is_hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(raw_elements: Array, locked: bool, affordable: bool, selected: bool = false, hovered: bool = false) -> void:
	var next_elements := _normalize_elements(raw_elements)
	if elements == next_elements and is_locked == locked and is_affordable == affordable and is_selected == selected and is_hovered == hovered:
		return
	elements = next_elements
	is_locked = locked
	is_affordable = affordable
	is_selected = selected
	is_hovered = hovered
	queue_redraw()

static func color_for(element_id: String) -> Color:
	var normalized := ElementIconDraw._normalize(element_id)
	if normalized.is_empty():
		normalized = "neutral"
	if not _color_cache.has(normalized):
		if normalized == "neutral":
			_color_cache[normalized] = Color(0.56, 0.66, 0.72, 1.0)
		else:
			_color_cache[normalized] = NeonStyle.element_color(normalized)
	return _color_cache[normalized]

static func _normalize_elements(raw_elements: Array) -> Array[String]:
	var out: Array[String] = []
	for raw in raw_elements:
		var normalized := ElementIconDraw._normalize(str(raw))
		if not normalized.is_empty() and not out.has(normalized):
			out.append(normalized)
	if out.is_empty():
		out.append("neutral")
	return out

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var colors := _trim_colors()
	var alpha := _state_alpha()
	var base_border := Color(NeonStyle.LINE.r, NeonStyle.LINE.g, NeonStyle.LINE.b, 0.18)
	if is_hovered:
		base_border = Color(NeonStyle.LINE_STRONG.r, NeonStyle.LINE_STRONG.g, NeonStyle.LINE_STRONG.b, 0.45)
	if is_selected:
		base_border = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.86)
	_draw_outer_frame(rect, base_border)
	_draw_left_trim(rect, colors, alpha)
	_draw_corner_ticks(rect, colors, alpha)
	if is_selected:
		_draw_inner_highlight(rect)

func _trim_colors() -> Array[Color]:
	var colors: Array[Color] = []
	for element_id in elements.slice(0, 3):
		colors.append(color_for(element_id))
	if colors.is_empty():
		colors.append(color_for("neutral"))
	return colors

func _state_alpha() -> float:
	if is_locked:
		return 0.42
	if not is_affordable:
		return 0.66
	return 1.0

func _draw_outer_frame(rect: Rect2, color: Color) -> void:
	var frame := rect.grow(-1.0)
	draw_rect(frame, color, false, 1.0)
	var top_fade := Color(color.r, color.g, color.b, color.a * 0.35)
	draw_line(frame.position + Vector2(12.0, 1.0), frame.position + Vector2(frame.size.x * 0.44, 1.0), top_fade, 1.0, true)
	draw_line(frame.position + Vector2(frame.size.x * 0.62, frame.size.y - 1.0), frame.position + Vector2(frame.size.x - 12.0, frame.size.y - 1.0), top_fade, 1.0, true)

func _draw_left_trim(rect: Rect2, colors: Array[Color], alpha: float) -> void:
	var bar_width := 4.0
	var top := 4.0
	var available_height := maxf(1.0, rect.size.y - 8.0)
	var segment_height := available_height / float(colors.size())
	for i in range(colors.size()):
		var color := colors[i]
		color.a *= alpha
		var y := top + segment_height * float(i)
		draw_rect(Rect2(Vector2(0.0, y), Vector2(bar_width, segment_height - 1.0)), color)
		var glow := Color(color.r, color.g, color.b, color.a * 0.16)
		draw_rect(Rect2(Vector2(bar_width, y), Vector2(7.0, segment_height - 1.0)), glow)

func _draw_corner_ticks(rect: Rect2, colors: Array[Color], alpha: float) -> void:
	var tick_color := colors[0]
	tick_color.a *= alpha * (1.25 if is_hovered or is_selected else 0.90)
	var lower_color := colors[min(colors.size() - 1, 1)]
	lower_color.a *= alpha * 0.80
	var w := 13.0
	var h := 8.0
	draw_line(Vector2(3.0, 3.0), Vector2(w, 3.0), tick_color, 1.4, true)
	draw_line(Vector2(3.0, 3.0), Vector2(3.0, h), tick_color, 1.4, true)
	draw_line(Vector2(3.0, rect.size.y - 3.0), Vector2(w, rect.size.y - 3.0), lower_color, 1.4, true)
	draw_line(Vector2(3.0, rect.size.y - 3.0), Vector2(3.0, rect.size.y - h), lower_color, 1.4, true)
	draw_line(Vector2(w, 3.0), Vector2(w + 5.0, 8.0), Color(tick_color.r, tick_color.g, tick_color.b, tick_color.a * 0.75), 1.0, true)
	draw_line(Vector2(w, rect.size.y - 3.0), Vector2(w + 5.0, rect.size.y - 8.0), Color(lower_color.r, lower_color.g, lower_color.b, lower_color.a * 0.75), 1.0, true)

func _draw_inner_highlight(rect: Rect2) -> void:
	var highlight := Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.30)
	draw_rect(rect.grow(-3.0), highlight, false, 1.0)
