extends Node

# UI Theme Colors
const COLOR_PANEL_BG = Color(0.015, 0.03, 0.055, 0.94)
const COLOR_PANEL_BORDER = Color(0.18, 0.68, 0.9, 0.62)
const COLOR_BUTTON_NORMAL = Color(0.035, 0.075, 0.145, 1.0)
const COLOR_BUTTON_HOVER = Color(0.065, 0.17, 0.27, 1.0)
const COLOR_BUTTON_PRESSED = Color(0.018, 0.045, 0.09, 1.0)
const COLOR_ACCENT = Color(0.30, 0.90, 1.0, 1.0)
const COLOR_GOLD = Color(1.0, 0.80, 0.22, 1.0)
const COLOR_CORE = Color(1.0, 0.48, 0.32, 1.0)

func apply_theme(root: Node) -> void:
	_process_node(root)

func _process_node(node: Node) -> void:
	if node is PanelContainer:
		_apply_panel_style(node)
	elif node is Button:
		_apply_button_style(node)
	elif node is Label:
		_apply_label_style(node)
	
	for child in node.get_children():
		_process_node(child)

func _apply_panel_style(panel: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_PANEL_BORDER
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	
	style.shadow_color = Color(0, 0.85, 1.0, 0.12)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)

func _apply_button_style(btn: Button) -> void:
	var is_primary := btn.name == "StartWaveButton"
	var normal_color := Color(0.035, 0.13, 0.22, 1.0) if is_primary else COLOR_BUTTON_NORMAL
	var hover_color := Color(0.07, 0.25, 0.36, 1.0) if is_primary else COLOR_BUTTON_HOVER
	var border_color := Color(0.33, 0.82, 1.0, 0.9) if is_primary else COLOR_PANEL_BORDER

	var normal = StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = border_color
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = normal.duplicate()
	hover.bg_color = hover_color
	hover.border_color = COLOR_ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = normal.duplicate()
	pressed.bg_color = COLOR_BUTTON_PRESSED
	pressed.border_width_top = 3
	pressed.border_width_bottom = 0
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.035, 0.045, 0.065, 0.95)
	disabled.border_color = Color(0.22, 0.32, 0.42, 0.55)
	btn.add_theme_stylebox_override("disabled", disabled)
	
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	btn.add_theme_color_override("font_hover_color", COLOR_ACCENT)
	btn.add_theme_color_override("font_disabled_color", Color(0.58, 0.66, 0.74, 0.95))
	if is_primary:
		btn.add_theme_color_override("font_color", Color(0.80, 0.96, 1.0))
		btn.add_theme_font_size_override("font_size", 13)

func _apply_label_style(label: Label) -> void:
	if label.name == "Title" or label.name == "CenterMessageLabel":
		label.add_theme_color_override("font_color", COLOR_ACCENT)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	elif label.name == "GoldLabel":
		label.add_theme_color_override("font_color", COLOR_GOLD)
		label.add_theme_font_size_override("font_size", 15)
	elif label.name == "LivesLabel":
		label.add_theme_color_override("font_color", COLOR_CORE)
		label.add_theme_font_size_override("font_size", 15)
	elif label.name == "StatusLabel":
		label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
		label.add_theme_font_size_override("font_size", 15)
