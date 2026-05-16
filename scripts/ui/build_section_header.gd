extends Control
class_name BuildSectionHeader

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

@export var title: String = "":
	set(value):
		title = value.to_upper()
		queue_redraw()

@export var accent_color: Color = NeonStyle.CYAN:
	set(value):
		accent_color = value
		queue_redraw()

@export var muted: bool = true:
	set(value):
		muted = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 24)

func configure(header_title: String, header_accent: Color = NeonStyle.CYAN, is_muted: bool = true) -> void:
	var next_title := header_title.to_upper()
	if title == next_title and accent_color == header_accent and muted == is_muted:
		return
	title = next_title
	accent_color = header_accent
	muted = is_muted
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if rect.size.x <= 24.0 or rect.size.y <= 8.0:
		return
	var alpha: float = 0.58 if muted else 0.86
	var marker_color: Color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	var text_color: Color = Color(NeonStyle.INK_2.r, NeonStyle.INK_2.g, NeonStyle.INK_2.b, 0.92) if muted else Color(accent_color.r, accent_color.g, accent_color.b, 0.95)
	var line_color: Color = Color(accent_color.r, accent_color.g, accent_color.b, 0.18 if muted else 0.30)
	var y: float = floor(rect.size.y * 0.5) + 0.5
	var marker_x: float = 4.0
	_draw_chevrons(marker_x, y, marker_color)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text_pos: Vector2 = Vector2(28.0, y + 4.0)
	draw_string(font, text_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
	var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var line_start: float = maxf(96.0, text_pos.x + title_width + 10.0)
	var line_end: float = rect.size.x - 12.0
	if line_end > line_start:
		draw_line(Vector2(line_start, y), Vector2(line_end, y), line_color, 1.0, true)
		_draw_diamond(Vector2(line_end + 4.0, y), marker_color)

func _draw_chevrons(x: float, y: float, color: Color) -> void:
	var chevron_w := 6.0
	for i in range(2):
		var offset := float(i) * 6.0
		var points := PackedVector2Array([
			Vector2(x + offset, y - 6.0),
			Vector2(x + offset + chevron_w, y),
			Vector2(x + offset, y + 6.0),
			Vector2(x + offset + 2.0, y + 6.0),
			Vector2(x + offset + chevron_w + 2.0, y),
			Vector2(x + offset + 2.0, y - 6.0),
		])
		draw_colored_polygon(points, color)

func _draw_diamond(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -3.0),
		center + Vector2(3.0, 0.0),
		center + Vector2(0.0, 3.0),
		center + Vector2(-3.0, 0.0),
	])
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), color, 1.0, true)
