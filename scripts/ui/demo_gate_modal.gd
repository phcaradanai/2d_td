extends CanvasLayer
## Demo Gate Modal — self-contained, no preload dependencies.
##
## Modes:
##   MODE_LOCKED         -- player tapped a premium-locked level card
##   MODE_DEMO_COMPLETE  -- demo wave cap reached after clearing
##   MODE_MAINTENANCE    -- server maintenance, all play blocked
##   MODE_FORCE_UPDATE   -- client build too old, must update
##
## Signals:
##   back_to_menu()     -- player chose Back to Menu
##   unlock_requested() -- player pressed the CTA unlock button

signal back_to_menu()
signal unlock_requested()

const MODE_LOCKED        = 0
const MODE_DEMO_COMPLETE = 1
const MODE_MAINTENANCE   = 2
const MODE_FORCE_UPDATE  = 3

# Inline design tokens — mirrors NeonStyle so this file has no preload.
const _C_BG0   = Color(0.024, 0.031, 0.051, 1.00)
const _C_BG1   = Color(0.043, 0.059, 0.090, 0.96)
const _C_INK1  = Color(0.914, 0.969, 0.976, 1.00)
const _C_INK2  = Color(0.643, 0.741, 0.769, 1.00)
const _C_INK3  = Color(0.420, 0.502, 0.533, 1.00)
const _C_WARN  = Color(1.000, 0.710, 0.278, 1.00)
const _C_CYAN  = Color(0.302, 0.851, 0.902, 1.00)
const _C_RED   = Color(1.000, 0.353, 0.420, 1.00)
const _C_LINE  = Color(0.302, 0.851, 0.902, 0.16)
const _C_LINE2 = Color(0.302, 0.851, 0.902, 0.28)

var _dim: ColorRect = null
var _card: PanelContainer = null
var _header_label: Label = null
var _title_label: Label = null
var _body_label: Label = null
var _stats_container: VBoxContainer = null
var _cta_button: Button = null
var _back_button: Button = null

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

# ── Public API ────────────────────────────────────────────────────────────────

func show_locked(level_name: String) -> void:
	_apply_mode(MODE_LOCKED, level_name, {})
	show()

func show_demo_complete(summary: Dictionary) -> void:
	_apply_mode(MODE_DEMO_COMPLETE, "", summary)
	show()

func show_maintenance(announcement: String) -> void:
	_apply_mode(MODE_MAINTENANCE, announcement, {})
	show()

func show_force_update() -> void:
	_apply_mode(MODE_FORCE_UPDATE, "", {})
	show()

# ── Private ───────────────────────────────────────────────────────────────────

func _apply_mode(mode: int, extra: String, summary: Dictionary) -> void:
	_stats_container.hide()
	for child in _stats_container.get_children():
		child.queue_free()

	# Reset border to default WARN colour; override per-mode below.
	_set_card_border(_C_WARN)
	_cta_button.show()
	_back_button.show()

	if mode == MODE_LOCKED:
		_header_label.text = "[ FULL VERSION ]"
		_header_label.add_theme_color_override("font_color", _C_WARN)
		_title_label.text = "FULL VERSION"
		_title_label.add_theme_color_override("font_color", _C_WARN)
		if extra != "":
			_body_label.text = extra + " is only available in the Full Version."
		else:
			_body_label.text = "This level requires the Full Version."
		_cta_button.text = "UNLOCK FULL VERSION"
		_apply_button_style(_cta_button, _C_WARN)
		_apply_button_style(_back_button, _C_CYAN)

	elif mode == MODE_DEMO_COMPLETE:
		_set_card_border(_C_CYAN)
		_header_label.text = "[ DEMO COMPLETE ]"
		_header_label.add_theme_color_override("font_color", _C_CYAN)
		_title_label.text = "DEMO COMPLETE"
		_title_label.add_theme_color_override("font_color", _C_CYAN)
		_body_label.text = "You have reached the end of the demo.\nUnlock the full version to keep playing!"
		_cta_button.text = "UNLOCK FULL VERSION"
		_apply_button_style(_cta_button, _C_WARN)
		_apply_button_style(_back_button, _C_CYAN)
		var level_str: String = str(summary.get("level_id", ""))
		_add_stat_row("Level",           level_str.replace("level_", "L").to_upper())
		_add_stat_row("Waves Cleared",   str(summary.get("waves_cleared", 0)))
		_add_stat_row("Gold Remaining",  str(summary.get("gold", 0)))
		_add_stat_row("Lives Remaining", str(summary.get("lives", 0)))
		_stats_container.show()

	elif mode == MODE_MAINTENANCE:
		_set_card_border(_C_RED)
		_header_label.text = "[ MAINTENANCE ]"
		_header_label.add_theme_color_override("font_color", _C_RED)
		_title_label.text = "MAINTENANCE"
		_title_label.add_theme_color_override("font_color", _C_RED)
		if extra != "":
			_body_label.text = extra
		else:
			_body_label.text = "The game is currently under maintenance.\nPlease check back shortly."
		_cta_button.hide()
		_apply_button_style(_back_button, _C_CYAN)

	elif mode == MODE_FORCE_UPDATE:
		_set_card_border(_C_RED)
		_header_label.text = "[ UPDATE REQUIRED ]"
		_header_label.add_theme_color_override("font_color", _C_RED)
		_title_label.text = "UPDATE REQUIRED"
		_title_label.add_theme_color_override("font_color", _C_RED)
		_body_label.text = "This version of the game is no longer supported.\nPlease update to continue playing."
		_cta_button.hide()
		_apply_button_style(_back_button, _C_RED)

func _add_stat_row(key: String, value: String) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_stats_container.add_child(hbox)

	var k: Label = Label.new()
	k.text = key + ":"
	k.add_theme_color_override("font_color", _C_INK3)
	k.add_theme_font_size_override("font_size", 15)
	k.custom_minimum_size = Vector2(160.0, 0.0)
	hbox.add_child(k)

	var v: Label = Label.new()
	v.text = value
	v.add_theme_color_override("font_color", _C_INK1)
	v.add_theme_font_size_override("font_size", 15)
	hbox.add_child(v)

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var anchor: Control = Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(420.0, 0.0)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.add_theme_stylebox_override("panel", _card_style(_C_WARN))
	anchor.add_child(_card)

	var outer: MarginContainer = MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   32)
	outer.add_theme_constant_override("margin_right",  32)
	outer.add_theme_constant_override("margin_top",    32)
	outer.add_theme_constant_override("margin_bottom", 32)
	_card.add_child(outer)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	outer.add_child(vbox)

	_header_label = Label.new()
	_header_label.text = "[ LOCKED ]"
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", _C_WARN)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_header_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", _C_WARN)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", _C_INK2)
	vbox.add_child(_body_label)

	var stats_bg: PanelContainer = PanelContainer.new()
	stats_bg.add_theme_stylebox_override("panel", _stats_panel_style())
	vbox.add_child(stats_bg)

	var stats_margin: MarginContainer = MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left",   16)
	stats_margin.add_theme_constant_override("margin_right",  16)
	stats_margin.add_theme_constant_override("margin_top",    16)
	stats_margin.add_theme_constant_override("margin_bottom", 16)
	stats_bg.add_child(stats_margin)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 8)
	stats_margin.add_child(_stats_container)

	var div: HSeparator = HSeparator.new()
	div.add_theme_color_override("color", _C_LINE2)
	vbox.add_child(div)

	_cta_button = Button.new()
	_cta_button.custom_minimum_size = Vector2(0.0, 52.0)
	_cta_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(_cta_button, _C_WARN)
	_cta_button.pressed.connect(_on_cta_pressed)
	vbox.add_child(_cta_button)

	_back_button = Button.new()
	_back_button.text = "BACK TO MENU"
	_back_button.custom_minimum_size = Vector2(0.0, 44.0)
	_back_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(_back_button, _C_CYAN)
	_back_button.pressed.connect(_on_back_pressed)
	vbox.add_child(_back_button)

func _on_cta_pressed() -> void:
	unlock_requested.emit()
	hide()

func _on_back_pressed() -> void:
	back_to_menu.emit()
	hide()

func _set_card_border(color: Color) -> void:
	_card.add_theme_stylebox_override("panel", _card_style(color))

func _card_style(border: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = _C_BG1
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(6)
	s.shadow_color = Color(border.r, border.g, border.b, 0.22)
	s.shadow_size = 12
	return s

func _stats_panel_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = _C_BG0
	s.set_border_width_all(1)
	s.border_color = _C_LINE
	s.set_corner_radius_all(4)
	return s

func _apply_button_style(btn: Button, accent: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = _C_BG1
	normal.set_border_width_all(1)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	normal.set_corner_radius_all(0)

	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(0.059, 0.082, 0.129, 1.0)
	hover.set_border_width_all(1)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.90)
	hover.set_corner_radius_all(0)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  normal)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       _C_INK1)
	btn.add_theme_color_override("font_hover_color", _C_CYAN)
