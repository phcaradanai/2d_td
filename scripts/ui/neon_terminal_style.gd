extends RefCounted

const BG := Color(0.006, 0.013, 0.026, 0.98)
const PANEL := Color(0.010, 0.027, 0.052, 0.92)
const PANEL_DENSE := Color(0.006, 0.018, 0.036, 0.96)
const CYAN := Color(0.30, 0.90, 1.00, 1.00)
const CYAN_DIM := Color(0.15, 0.58, 0.72, 0.72)
const CYAN_FAINT := Color(0.12, 0.48, 0.62, 0.28)
const TEXT := Color(0.84, 0.95, 1.00, 1.00)
const TEXT_DIM := Color(0.47, 0.63, 0.74, 0.92)
const GOLD := Color(1.00, 0.83, 0.22, 1.00)
const CORAL := Color(1.00, 0.44, 0.30, 1.00)
const GREEN := Color(0.42, 1.00, 0.62, 1.00)

static func panel(bg: Color = PANEL, border: Color = CYAN_DIM, active: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = CYAN if active else border
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.20 if active else 0.08)
	s.shadow_size = 10 if active else 3
	s.shadow_offset = Vector2.ZERO
	return s

static func button(bg: Color = Color(0.014, 0.052, 0.090, 0.98), border: Color = CYAN_DIM, active: bool = false) -> StyleBoxFlat:
	var s := panel(bg, border, active)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s

static func apply_terminal_label(label: Label, size: int = 13, color: Color = TEXT, shadow: bool = false) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if shadow:
		label.add_theme_color_override("font_shadow_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.24))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("shadow_size", 4)

static func style_button(btn: Button, accent: Color = CYAN, active: bool = false) -> void:
	var normal := button(Color(0.012, 0.050, 0.086, 0.98), Color(accent.r, accent.g, accent.b, 0.58), active)
	var hover := button(Color(0.022, 0.092, 0.138, 1.0), Color(accent.r, accent.g, accent.b, 0.96), true)
	var pressed := button(Color(0.006, 0.026, 0.048, 1.0), Color(accent.r, accent.g, accent.b, 0.82), active)
	var disabled := button(Color(0.018, 0.024, 0.034, 0.92), Color(0.19, 0.28, 0.34, 0.45), false)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", accent)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	btn.add_theme_font_size_override("font_size", 13)

static func style_line_edit(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", button(Color(0.004, 0.020, 0.042, 0.96), CYAN_DIM, false))
	input.add_theme_stylebox_override("focus", button(Color(0.006, 0.030, 0.060, 0.98), CYAN, true))
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", TEXT_DIM)
	input.add_theme_color_override("caret_color", CYAN)
	input.add_theme_font_size_override("font_size", 15)

