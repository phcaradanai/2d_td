extends CanvasLayer
class_name SettingsMenu

signal close_requested()

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

var settings_service: Node = null
var _updating: bool = false
var _options: Dictionary = {}
var _sliders: Dictionary = {}

func _ready() -> void:
	layer = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func bind_settings_service(service: Node) -> void:
	settings_service = service
	if settings_service and settings_service.has_signal("settings_changed"):
		if not settings_service.settings_changed.is_connected(_on_service_settings_changed):
			settings_service.settings_changed.connect(_on_service_settings_changed)
	refresh_from_service()

func open() -> void:
	refresh_from_service()
	show()
	var close_btn := get_node_or_null("Root/Panel/Margin/VBox/Footer/CloseButton")
	if close_btn is Control:
		(close_btn as Control).grab_focus()

func close() -> void:
	hide()
	close_requested.emit()

func refresh_from_service() -> void:
	if settings_service == null or not settings_service.has_method("get_settings"):
		return
	_on_service_settings_changed(settings_service.get_settings())

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", NeonStyle.panel(NeonStyle.BG_1, NeonStyle.LINE_STRONG, true))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 620)
	panel.offset_left = -260
	panel.offset_top = -310
	panel.offset_right = 260
	panel.offset_bottom = 310
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonStyle.apply_terminal_label(title, 18, NeonStyle.CYAN_2, true)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Display, visuals, and audio"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NeonStyle.apply_terminal_label(subtitle, 11, NeonStyle.INK_3)
	vbox.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	_add_section(content, "DISPLAY")
	_add_option(content, "Window Mode", "display.window_mode", _display_options())
	_add_section(content, "PERFORMANCE")
	_add_option(content, "Visual Quality", "performance.visual_quality", [["auto", "Auto"], ["low", "Low"], ["balanced", "Balanced"], ["high", "High"]])
	_add_option(content, "Attack VFX", "performance.attack_vfx", [["minimal", "Minimal"], ["normal", "Normal"], ["full", "Full"]])
	_add_option(content, "Floating Damage Numbers", "performance.floating_damage_numbers", [["off", "Off"], ["limited", "Limited"], ["full", "Full"]])
	_add_option(content, "Status Effects", "performance.status_effects", [["icons_only", "Icons Only"], ["icons_minimal_pulse", "Icons + Minimal Pulse"]])
	_add_option(content, "Screen Shake", "performance.screen_shake", [["off", "Off"], ["minimal", "Minimal"], ["full", "Full"]])
	_add_section(content, "AUDIO")
	_add_slider(content, "Master Volume", "audio.master_volume")
	_add_slider(content, "Music Volume", "audio.music_volume")
	_add_slider(content, "SFX Volume", "audio.sfx_volume")

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 10)
	vbox.add_child(footer)

	var reset_btn := Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "Reset Defaults"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.custom_minimum_size.y = 38
	NeonStyle.style_button(reset_btn, NeonStyle.INK_3, false)
	reset_btn.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.custom_minimum_size.y = 38
	NeonStyle.style_button(close_btn, NeonStyle.CYAN, true)
	close_btn.pressed.connect(close)
	footer.add_child(close_btn)

func _display_options() -> Array:
	if settings_service and settings_service.has_method("get_display_mode_options"):
		var options := []
		for option in settings_service.get_display_mode_options():
			if option is Dictionary:
				options.append([str(option.get("id", "")), str(option.get("label", ""))])
		if not options.is_empty():
			return options
	return [["windowed", "Windowed"], ["borderless", "Borderless"], ["fullscreen", "Fullscreen"]]

func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	NeonStyle.apply_eyebrow(label)
	parent.add_child(label)

func _add_option(parent: VBoxContainer, label_text: String, key_path: String, defs: Array) -> void:
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	NeonStyle.apply_terminal_label(label, 12, NeonStyle.INK_2)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(240, 34)
	for i in range(defs.size()):
		var def: Array = defs[i]
		option.add_item(str(def[1]))
		option.set_item_metadata(i, str(def[0]))
	option.item_selected.connect(_on_option_selected.bind(key_path, option))
	row.add_child(option)
	_options[key_path] = option

func _add_slider(parent: VBoxContainer, label_text: String, key_path: String) -> void:
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 14)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	NeonStyle.apply_terminal_label(label, 12, NeonStyle.INK_2)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(240, 34)
	slider.value_changed.connect(_on_slider_changed.bind(key_path))
	row.add_child(slider)
	_sliders[key_path] = slider

func _on_service_settings_changed(settings: Dictionary) -> void:
	_updating = true
	for key_path in _options.keys():
		var option: OptionButton = _options[key_path]
		_select_option(option, str(_read_key_path(settings, key_path, "")))
	for key_path in _sliders.keys():
		var slider: HSlider = _sliders[key_path]
		slider.value = float(_read_key_path(settings, key_path, slider.value))
	_updating = false

func _on_option_selected(_index: int, key_path: String, option: OptionButton) -> void:
	if _updating or settings_service == null:
		return
	_write_setting(key_path, str(option.get_item_metadata(option.selected)))

func _on_slider_changed(value: float, key_path: String) -> void:
	if _updating or settings_service == null:
		return
	_write_setting(key_path, value)

func _write_setting(key_path: String, value: Variant) -> void:
	var parts := key_path.split(".")
	if parts.size() != 2:
		return
	var category := parts[0]
	var key := parts[1]
	match category:
		"audio":
			settings_service.update_audio_settings({key: value})
		"display":
			settings_service.update_display_settings({key: value})
		"performance":
			settings_service.update_performance_settings({key: value})

func _on_reset_pressed() -> void:
	if settings_service and settings_service.has_method("reset_to_defaults"):
		settings_service.reset_to_defaults()

func _select_option(option: OptionButton, metadata: String) -> void:
	for i in range(option.item_count):
		if str(option.get_item_metadata(i)) == metadata:
			option.select(i)
			return
	option.select(0)

func _read_key_path(settings: Dictionary, key_path: String, fallback: Variant) -> Variant:
	var parts := key_path.split(".")
	if parts.size() != 2:
		return fallback
	var category = settings.get(parts[0], {})
	if not (category is Dictionary):
		return fallback
	return category.get(parts[1], fallback)
