extends Control
class_name HUDDrawerHeader

signal pressed()

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

@export var title: String = "PANEL":
	set(value):
		title = value
		queue_redraw()

@export var subtitle: String = "":
	set(value):
		subtitle = value
		queue_redraw()

@export var icon_kind: String = "build":
	set(value):
		icon_kind = value
		queue_redraw()

@export var accent_color: Color = NeonStyle.CYAN:
	set(value):
		accent_color = value
		queue_redraw()

@export var expanded: bool = false:
	set(value):
		expanded = value
		queue_redraw()

@export var tab_mode: bool = false:
	set(value):
		tab_mode = value
		_update_minimum_size()
		queue_redraw()

var _hovered: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_update_minimum_size()
	mouse_entered.connect(func():
		_hovered = true
		queue_redraw())
	mouse_exited.connect(func():
		_hovered = false
		queue_redraw())
	gui_input.connect(_on_gui_input)

func configure(new_title: String, new_icon_kind: String, new_accent: Color, is_expanded: bool = false, is_tab_mode: bool = false) -> void:
	var changed := title != new_title or icon_kind != new_icon_kind or accent_color != new_accent or expanded != is_expanded or tab_mode != is_tab_mode
	title = new_title
	icon_kind = new_icon_kind
	accent_color = new_accent
	expanded = is_expanded
	tab_mode = is_tab_mode
	tooltip_text = "%s drawer" % title.capitalize()
	_update_minimum_size()
	if changed:
		queue_redraw()

func set_expanded(value: bool) -> void:
	if expanded == value:
		return
	expanded = value
	queue_redraw()

func set_subtitle(value: String) -> void:
	if subtitle == value:
		return
	subtitle = value
	queue_redraw()

func set_tab_mode(value: bool) -> void:
	if tab_mode == value:
		return
	tab_mode = value
	_update_minimum_size()
	queue_redraw()

func _update_minimum_size() -> void:
	custom_minimum_size = Vector2(54.0, 138.0) if tab_mode else Vector2(0.0, 44.0)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		pressed.emit()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return
	var alpha := 1.0 if expanded else 0.74
	var hover_bonus := 0.18 if _hovered else 0.0
	var border := Color(accent_color.r, accent_color.g, accent_color.b, (0.38 + hover_bonus) * alpha)
	var fill_alpha := 0.96 if expanded else (0.88 + (0.06 if _hovered else 0.0))
	var fill := Color(NeonStyle.BG_1.r, NeonStyle.BG_1.g, NeonStyle.BG_1.b, fill_alpha)
	if tab_mode:
		_draw_tab_body(rect, fill, border, alpha)
	else:
		draw_rect(rect.grow(-1.0), fill, true)
		draw_rect(rect.grow(-1.0), border, false, 1.0)
	var rail_rect := Rect2(Vector2(1.0, 1.0), Vector2(3.0, rect.size.y - 2.0))
	if tab_mode:
		rail_rect = Rect2(Vector2(1.0, 8.0), Vector2(4.0, rect.size.y - 16.0))
	draw_rect(rail_rect, Color(accent_color.r, accent_color.g, accent_color.b, 0.90 * alpha), true)
	if not tab_mode:
		_draw_corner_ticks(rect.grow(-1.0), border)
	if tab_mode:
		_draw_icon(Vector2(rect.size.x * 0.5, 24.0), alpha, 1.35)
		_draw_stacked_tab_label(rect, alpha)
		_draw_chevron(Vector2(rect.size.x * 0.5, rect.size.y - 15.0), Color(accent_color.r, accent_color.g, accent_color.b, minf(1.0, border.a + 0.26)))
	else:
		_draw_icon(Vector2(25.0, rect.size.y * 0.5), alpha, 1.0)
		var font := ThemeDB.fallback_font
		var title_color := Color(NeonStyle.INK_1.r, NeonStyle.INK_1.g, NeonStyle.INK_1.b, 0.98)
		var text_width := maxf(0.0, rect.size.x - 86.0)
		if subtitle.strip_edges() == "":
			draw_string(font, Vector2(48.0, rect.size.y * 0.5 + 6.0), title, HORIZONTAL_ALIGNMENT_LEFT, text_width, 14, title_color)
		else:
			draw_string(font, Vector2(48.0, rect.size.y * 0.5 - 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, title_color)
			draw_string(
				font,
				Vector2(48.0, rect.size.y * 0.5 + 13.0),
				subtitle,
				HORIZONTAL_ALIGNMENT_LEFT,
				text_width,
				10,
				Color(NeonStyle.INK_3.r, NeonStyle.INK_3.g, NeonStyle.INK_3.b, 0.94 * alpha)
			)
		_draw_chevron(Vector2(rect.size.x - 22.0, rect.size.y * 0.5), border)

func _draw_tab_body(rect: Rect2, fill: Color, border: Color, alpha: float) -> void:
	var cut := 7.0
	var r := rect.grow(-1.0)
	# Flat left edge (attaches to screen), angled cut on right (faces game board)
	var points := PackedVector2Array([
		r.position + Vector2(0.0, 0.0),
		r.position + Vector2(r.size.x - cut, 0.0),
		r.position + Vector2(r.size.x, cut),
		r.position + Vector2(r.size.x, r.size.y - cut),
		r.position + Vector2(r.size.x - cut, r.size.y),
		r.position + Vector2(0.0, r.size.y),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), border, 1.1, true)
	var tick_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.34 * alpha)
	draw_line(r.position + Vector2(5.0, 7.0), r.position + Vector2(r.size.x - cut - 3.0, 7.0), tick_color, 1.0, true)
	draw_line(r.position + Vector2(5.0, r.size.y - 7.0), r.position + Vector2(r.size.x - cut - 3.0, r.size.y - 7.0), tick_color, 1.0, true)

func _draw_stacked_tab_label(rect: Rect2, alpha: float) -> void:
	var words := _tab_words()
	var font := ThemeDB.fallback_font
	var color := Color(NeonStyle.INK_1.r, NeonStyle.INK_1.g, NeonStyle.INK_1.b, 0.94 * alpha)
	var y := rect.size.y * 0.5 - 4.0
	if words.size() == 1:
		draw_string(font, Vector2(4.0, y), words[0], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 11.0, 10, color)
		return
	draw_string(font, Vector2(4.0, y - 9.0), words[0], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 11.0, 10, color)
	draw_string(font, Vector2(4.0, y + 6.0), words[1], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 11.0, 10, color)

func _tab_words() -> Array[String]:
	var normalized := title.strip_edges().to_upper()
	if normalized == "BUILD TOWERS":
		return ["BUILD", "TOWERS"]
	if normalized == "DAMAGE STATS":
		return ["DAMAGE", "STATS"]
	var parts := normalized.split(" ", false)
	if parts.size() >= 2:
		return [str(parts[0]), str(parts[1])]
	return [normalized]

func _draw_corner_ticks(rect: Rect2, color: Color) -> void:
	var tick := 7.0
	draw_line(rect.position, rect.position + Vector2(tick, 0.0), color, 1.0, true)
	draw_line(rect.position, rect.position + Vector2(0.0, tick), color, 1.0, true)
	draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x - tick, rect.size.y), color, 1.0, true)
	draw_line(rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x, rect.size.y - tick), color, 1.0, true)

func _draw_icon(center: Vector2, alpha: float, scale: float = 1.0) -> void:
	var c := Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	if icon_kind == "damage":
		var w := 4.0 * scale
		var base_y := center.y + 8.0 * scale
		var heights: Array[float] = [7.0, 13.0, 10.0]
		for i in range(3):
			var h: float = heights[i] * scale
			var x := center.x - 10.0 * scale + float(i) * 8.0 * scale
			draw_rect(Rect2(Vector2(x, base_y - h), Vector2(w, h)), Color(c.r, c.g, c.b, 0.24 * alpha), true)
			draw_rect(Rect2(Vector2(x, base_y - h), Vector2(w, h)), c, false, 1.1)
		draw_line(center + Vector2(-12.0, 9.0) * scale, center + Vector2(12.0, 9.0) * scale, c, 1.1, true)
		draw_line(center + Vector2(-10.0, -8.0) * scale, center + Vector2(10.0, -8.0) * scale, Color(c.r, c.g, c.b, 0.45 * alpha), 1.0, true)
		return
	var base := Rect2(center + Vector2(-9.0, 3.5) * scale, Vector2(18.0, 6.5) * scale)
	draw_rect(base, Color(c.r, c.g, c.b, 0.16 * alpha), true)
	draw_rect(base, c, false, 1.2)
	draw_line(center + Vector2(-6.0, 3.5) * scale, center + Vector2(0.0, -9.0) * scale, c, 1.3, true)
	draw_line(center + Vector2(6.0, 3.5) * scale, center + Vector2(0.0, -9.0) * scale, c, 1.3, true)
	draw_line(center + Vector2(-10.0, 10.0) * scale, center + Vector2(10.0, 10.0) * scale, c, 1.1, true)
	draw_circle(center + Vector2(0.0, -9.0) * scale, 2.5 * scale, c)

func _draw_chevron(center: Vector2, color: Color) -> void:
	if expanded:
		draw_line(center + Vector2(-5.0, -2.0), center, color, 1.5, true)
		draw_line(center, center + Vector2(5.0, -2.0), color, 1.5, true)
	else:
		draw_line(center + Vector2(-2.0, -5.0), center + Vector2(3.0, 0.0), color, 1.5, true)
		draw_line(center + Vector2(3.0, 0.0), center + Vector2(-2.0, 5.0), color, 1.5, true)
