extends "res://scripts/ui/modal_panel_controller.gd"
## Demo Gate Modal
##
## Modes:
##   MODE_LOCKED         -- player tapped a premium-locked level card
##   MODE_DEMO_COMPLETE  -- demo wave cap reached after clearing
##   MODE_MAINTENANCE    -- server maintenance, all play blocked
##   MODE_FORCE_UPDATE   -- client build too old, must update
##
## Signals (own):
##   back_to_menu()     -- player chose Back to Menu
##   unlock_requested() -- player pressed the CTA unlock button
## Signal (from base):
##   closed()           -- X button or ESC closed the modal

signal back_to_menu()
signal unlock_requested()

const MODE_LOCKED        = 0
const MODE_DEMO_COMPLETE = 1
const MODE_MAINTENANCE   = 2
const MODE_FORCE_UPDATE  = 3

var _mode_header: Label      = null
var _mode_title: Label       = null
var _body_label: Label       = null
var _stats_container: VBoxContainer = null
var _stats_bg: PanelContainer = null
var _cta_button: Button      = null
var _back_button: Button     = null

func _ready() -> void:
	_max_panel_width = 480.0
	super._ready()

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

# ── Build content (called once by base class _ready) ─────────────────────────

func _build_modal_content() -> void:
	# ── Scroll body ──────────────────────────────────────────────────────────
	_mode_header = _make_label("", 16, _C_WARN)
	_mode_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_content.add_child(_mode_header)

	_mode_title = _make_label("", 26, _C_WARN)
	_mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_content.add_child(_mode_title)

	_body_label = _make_label("", 15, _C_INK2, true)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_content.add_child(_body_label)

	# Stats box (demo-complete summary)
	_stats_bg = PanelContainer.new()
	var stats_bg: PanelContainer = _stats_bg
	var stats_bg_style: StyleBoxFlat = StyleBoxFlat.new()
	stats_bg_style.bg_color = _C_BG0
	stats_bg_style.set_border_width_all(1)
	stats_bg_style.border_color = _C_LINE
	stats_bg_style.set_corner_radius_all(4)
	stats_bg.add_theme_stylebox_override("panel", stats_bg_style)
	_scroll_content.add_child(stats_bg)

	var stats_margin: MarginContainer = MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left",   14)
	stats_margin.add_theme_constant_override("margin_right",  14)
	stats_margin.add_theme_constant_override("margin_top",    12)
	stats_margin.add_theme_constant_override("margin_bottom", 12)
	stats_bg.add_child(stats_margin)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 8)
	stats_margin.add_child(_stats_container)

	# ── Footer buttons ────────────────────────────────────────────────────────
	_cta_button = Button.new()
	_cta_button.custom_minimum_size = Vector2(0.0, 48.0)
	_cta_button.add_theme_font_size_override("font_size", 16)
	_apply_btn_style(_cta_button, _C_WARN)
	_cta_button.pressed.connect(_on_cta_pressed)
	_footer.add_child(_cta_button)

	_back_button = Button.new()
	_back_button.text = "BACK TO MENU"
	_back_button.custom_minimum_size = Vector2(0.0, 40.0)
	_back_button.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(_back_button, _C_CYAN)
	_back_button.pressed.connect(_on_back_pressed)
	_footer.add_child(_back_button)

# ── Mode application ──────────────────────────────────────────────────────────

func _apply_mode(mode: int, extra: String, summary: Dictionary) -> void:
	# Clear stats
	for child in _stats_container.get_children():
		child.queue_free()
	_stats_bg.hide()

	_cta_button.show()
	_back_button.show()

	if mode == MODE_LOCKED:
		set_blocking(false)
		set_panel_accent(_C_WARN)
		set_title("ACCESS RESTRICTED")
		_mode_header.text = "[ ACCESS RESTRICTED ]"
		_mode_header.add_theme_color_override("font_color", _C_WARN)
		_mode_title.text = "ACCESS RESTRICTED"
		_mode_title.add_theme_color_override("font_color", _C_WARN)
		_body_label.text = (extra + " is not included in your current access profile.") if extra != "" \
			else "This level is not included in your current access profile."
		_cta_button.text = "UNLOCK FULL VERSION"
		_apply_btn_style(_cta_button, _C_WARN)
		_apply_btn_style(_back_button, _C_CYAN)

	elif mode == MODE_DEMO_COMPLETE:
		set_blocking(false)
		set_panel_accent(_C_CYAN)
		set_title("DEMO COMPLETE")
		_mode_header.text = "[ DEMO COMPLETE ]"
		_mode_header.add_theme_color_override("font_color", _C_CYAN)
		_mode_title.text = "DEMO COMPLETE"
		_mode_title.add_theme_color_override("font_color", _C_CYAN)
		_body_label.text = "You have reached the end of the demo.\nUnlock the full version to keep playing!"
		_cta_button.text = "UNLOCK FULL VERSION"
		_apply_btn_style(_cta_button, _C_WARN)
		_apply_btn_style(_back_button, _C_CYAN)
		var level_str: String = str(summary.get("level_id", ""))
		_add_stat_row("Level",           level_str.replace("level_", "L").to_upper())
		_add_stat_row("Waves Cleared",   str(summary.get("waves_cleared", 0)))
		_add_stat_row("Gold Remaining",  str(summary.get("gold", 0)))
		_add_stat_row("Lives Remaining", str(summary.get("lives", 0)))
		_stats_bg.show()

	elif mode == MODE_MAINTENANCE:
		set_blocking(true)
		set_panel_accent(_C_RED)
		set_title("MAINTENANCE")
		_mode_header.text = "[ MAINTENANCE ]"
		_mode_header.add_theme_color_override("font_color", _C_RED)
		_mode_title.text = "MAINTENANCE"
		_mode_title.add_theme_color_override("font_color", _C_RED)
		_body_label.text = extra if extra != "" else \
			"The game is currently under maintenance.\nPlease check back shortly."
		_cta_button.hide()
		_apply_btn_style(_back_button, _C_CYAN)

	elif mode == MODE_FORCE_UPDATE:
		set_blocking(true)
		set_panel_accent(_C_RED)
		set_title("UPDATE REQUIRED")
		_mode_header.text = "[ UPDATE REQUIRED ]"
		_mode_header.add_theme_color_override("font_color", _C_RED)
		_mode_title.text = "UPDATE REQUIRED"
		_mode_title.add_theme_color_override("font_color", _C_RED)
		_body_label.text = "This version of the game is no longer supported.\nPlease update to continue playing."
		_cta_button.hide()
		_apply_btn_style(_back_button, _C_RED)

	call_deferred("_on_viewport_resized")

func _add_stat_row(key: String, value: String) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_stats_container.add_child(hbox)

	var k: Label = Label.new()
	k.text = key + ":"
	k.add_theme_color_override("font_color", _C_INK3)
	k.add_theme_font_size_override("font_size", 14)
	k.custom_minimum_size = Vector2(150.0, 0.0)
	hbox.add_child(k)

	var v: Label = Label.new()
	v.text = value
	v.add_theme_color_override("font_color", _C_INK1)
	v.add_theme_font_size_override("font_size", 14)
	hbox.add_child(v)

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_cta_pressed() -> void:
	hide()
	unlock_requested.emit()

func _on_back_pressed() -> void:
	hide()
	back_to_menu.emit()
