extends PanelContainer

signal closed()
signal cosmetics_requested()

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

func _ready() -> void:
	_build()

func _build() -> void:
	custom_minimum_size = Vector2(520, 380)
	add_theme_stylebox_override("panel", NeonStyle.panel(Color(0.018, 0.026, 0.045, 0.985), Color(1.0, 0.74, 0.22, 0.58), true))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)

	var title := Label.new()
	title.text = "REWARD"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	title_col.add_child(title)

	var sub := Label.new()
	sub.text = "UNLOCKS · COLLECTION · VISUAL LOADOUTS"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86, 0.82))
	title_col.add_child(sub)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 34)
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	header.add_child(close_btn)

	var cosmetics_btn := Button.new()
	cosmetics_btn.text = "COSMETICS"
	cosmetics_btn.custom_minimum_size = Vector2(0, 52)
	NeonStyle.style_button(cosmetics_btn, Color(0.45, 0.95, 1.0), true)
	cosmetics_btn.pressed.connect(func() -> void:
		cosmetics_requested.emit()
	)
	box.add_child(cosmetics_btn)

	var coming := Label.new()
	coming.text = "More reward categories will live here as progression expands."
	coming.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coming.add_theme_font_size_override("font_size", 12)
	coming.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82, 0.75))
	box.add_child(coming)
