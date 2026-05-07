extends Node

# UI Theme Colors
const COLOR_PANEL_BG = Color(0.02, 0.04, 0.08, 0.9)
const COLOR_PANEL_BORDER = Color(0.2, 0.8, 1.0, 0.6)
const COLOR_BUTTON_NORMAL = Color(0.05, 0.1, 0.2, 1.0)
const COLOR_BUTTON_HOVER = Color(0.1, 0.3, 0.5, 1.0)
const COLOR_BUTTON_PRESSED = Color(0.02, 0.05, 0.1, 1.0)
const COLOR_ACCENT = Color(0.0, 1.0, 1.0, 1.0) # Full Neon Cyan

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
	
	# Glow effect
	style.shadow_color = Color(0, 1, 1, 0.1)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

func _apply_button_style(btn: Button) -> void:
	# Normal
	var normal = StyleBoxFlat.new()
	normal.bg_color = COLOR_BUTTON_NORMAL
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = COLOR_PANEL_BORDER
	normal.corner_radius_top_left = 2
	normal.corner_radius_top_right = 2
	normal.corner_radius_bottom_left = 2
	normal.corner_radius_bottom_right = 2
	btn.add_theme_stylebox_override("normal", normal)
	
	# Hover
	var hover = normal.duplicate()
	hover.bg_color = COLOR_BUTTON_HOVER
	hover.border_color = COLOR_ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	
	# Pressed
	var pressed = normal.duplicate()
	pressed.bg_color = COLOR_BUTTON_PRESSED
	pressed.border_width_top = 3
	pressed.border_width_bottom = 0
	btn.add_theme_stylebox_override("pressed", pressed)
	
	# Focus (None)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", COLOR_ACCENT)

func _apply_label_style(label: Label) -> void:
	if label.name == "Title" or label.name == "CenterMessageLabel":
		label.add_theme_color_override("font_color", COLOR_ACCENT)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
