extends CanvasLayer
## Modal Panel Controller — shared base for all access-related dialogs.
##
## Provides:
##   - True viewport centering via CenterContainer
##   - Responsive width (min(max_width, vp.x * 0.9))
##   - ScrollContainer body capped at 55 % of viewport height
##   - Dark backdrop (blocks clicks to background)
##   - Backdrop click-to-close (disable with _backdrop_closeable = false)
##   - ESC key close via _unhandled_key_input (disable with _esc_closeable = false)
##   - Header row: title label + spacer + X close button
##   - Footer VBox: always visible below the scroll body (for action buttons)
##   - signal closed() on any close action
##
## Usage:
##   extends "res://scripts/ui/modal_panel_controller.gd"
##   Set _esc_closeable / _backdrop_closeable before super._ready().
##   Override _build_modal_content() to populate _scroll_content and _footer.
##   Call set_blocking(true) to hide X and disable ESC/backdrop close.

signal closed()

# ── Inline design tokens (no preload dependency) ─────────────────────────────
const _C_BG0   = Color(0.024, 0.031, 0.051, 1.00)
const _C_BG1   = Color(0.043, 0.059, 0.090, 0.96)
const _C_BG2   = Color(0.059, 0.082, 0.129, 1.00)
const _C_INK1  = Color(0.914, 0.969, 0.976, 1.00)
const _C_INK2  = Color(0.643, 0.741, 0.769, 1.00)
const _C_INK3  = Color(0.420, 0.502, 0.533, 1.00)
const _C_CYAN  = Color(0.302, 0.851, 0.902, 1.00)
const _C_WARN  = Color(1.000, 0.710, 0.278, 1.00)
const _C_RED   = Color(1.000, 0.353, 0.420, 1.00)
const _C_OK    = Color(0.357, 0.878, 0.549, 1.00)
const _C_LINE  = Color(0.302, 0.851, 0.902, 0.16)
const _C_LINE2 = Color(0.302, 0.851, 0.902, 0.28)

# ── Config (set by subclass before super._ready()) ────────────────────────────
var _esc_closeable: bool      = true
var _backdrop_closeable: bool = true
var _max_panel_width: float   = 520.0

# ── Internal nodes ────────────────────────────────────────────────────────────
var _backdrop: ColorRect        = null
var _panel: PanelContainer      = null
var _title_label: Label         = null
var _x_button: Button           = null
var _scroll: ScrollContainer    = null
var _scroll_content: VBoxContainer = null
var _footer: VBoxContainer      = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_base_ui()
	_build_modal_content()
	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_on_viewport_resized")
	hide()

# ── Subclass hooks ────────────────────────────────────────────────────────────

## Override in subclass to add content to _scroll_content and _footer.
func _build_modal_content() -> void:
	pass

# ── Public API ────────────────────────────────────────────────────────────────

## Prevent ESC and backdrop from closing; hide X button.
## Used for maintenance / force-update modes where the player must act.
func set_blocking(blocking: bool) -> void:
	_esc_closeable      = not blocking
	_backdrop_closeable = not blocking
	if _x_button:
		_x_button.visible = not blocking

## Set the accent color of the panel border.
func set_panel_accent(color: Color) -> void:
	if _panel:
		_panel.add_theme_stylebox_override("panel", _panel_style(color))

## Update the title bar text.
func set_title(text: String) -> void:
	if _title_label:
		_title_label.text = text

# ── Close handling ────────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not _esc_closeable:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_self()

func _on_close_pressed() -> void:
	_close_self()

func _close_self() -> void:
	hide()
	closed.emit()

# ── Sizing ────────────────────────────────────────────────────────────────────

func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Responsive width
	var w: float = min(_max_panel_width, vp.x * 0.90)
	w = max(w, 280.0)
	_panel.custom_minimum_size.x = w
	# Scroll body height cap
	_update_scroll_height(vp)

func _update_scroll_height(vp: Vector2) -> void:
	var max_h: float = vp.y * 0.55
	# Ask the content for its natural height; fall back to max if not laid out yet.
	var content_h: float = _scroll_content.get_combined_minimum_size().y
	if content_h < 1.0:
		content_h = max_h
	_scroll.custom_minimum_size.y = min(content_h, max_h)

# ── Base UI construction ──────────────────────────────────────────────────────

func _build_base_ui() -> void:
	# Backdrop — full viewport, blocks all clicks behind the modal
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	# CenterContainer — fills viewport, centers its single child
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Panel card — sized by _update_sizing; centered by CenterContainer
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style(_C_CYAN))
	center.add_child(_panel)

	# Inner margin
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	# Outer VBox — header | divider | scroll | footer-divider | footer
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	# Header row: title (fills) + X close button
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", _C_CYAN)
	header.add_child(_title_label)

	_x_button = Button.new()
	_x_button.text = "X"
	_x_button.custom_minimum_size = Vector2(32.0, 32.0)
	_x_button.focus_mode = Control.FOCUS_NONE
	_x_button.add_theme_font_size_override("font_size", 13)
	_x_button.add_theme_color_override("font_color", _C_INK3)
	_x_button.add_theme_color_override("font_hover_color", _C_INK1)
	_x_button.add_theme_stylebox_override("normal",   _btn_flat_style())
	_x_button.add_theme_stylebox_override("hover",    _btn_flat_style(_C_INK3, 0.20))
	_x_button.add_theme_stylebox_override("pressed",  _btn_flat_style())
	_x_button.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	_x_button.pressed.connect(_on_close_pressed)
	header.add_child(_x_button)

	# Divider below header
	_add_separator(outer)

	# ScrollContainer — body content scrolls here
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)

	_scroll_content = VBoxContainer.new()
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_scroll_content)

	# Divider above footer
	_add_separator(outer)

	# Footer — always visible, not scrolled (action buttons go here)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	outer.add_child(_footer)

# ── Backdrop click ────────────────────────────────────────────────────────────

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not _backdrop_closeable:
		return
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			_close_self()

# ── Style helpers (shared by subclasses via inheritance) ──────────────────────

func _panel_style(border: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = _C_BG1
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(6)
	s.shadow_color = Color(border.r, border.g, border.b, 0.22)
	s.shadow_size = 14
	return s

func _btn_style(accent: Color) -> Array:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = _C_BG1
	normal.set_border_width_all(1)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	normal.set_corner_radius_all(0)

	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = _C_BG2
	hover.set_border_width_all(1)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.90)
	hover.set_corner_radius_all(0)
	return [normal, hover]

func _apply_btn_style(btn: Button, accent: Color) -> void:
	var styles: Array = _btn_style(accent)
	btn.add_theme_stylebox_override("normal",   styles[0])
	btn.add_theme_stylebox_override("hover",    styles[1])
	btn.add_theme_stylebox_override("pressed",  styles[0])
	btn.add_theme_stylebox_override("disabled", styles[0])
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",          _C_INK1)
	btn.add_theme_color_override("font_hover_color",    _C_CYAN)
	btn.add_theme_color_override("font_disabled_color", _C_INK3)

func _btn_flat_style(border: Color = Color(0,0,0,0), alpha: float = 0.0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(border.r, border.g, border.b, alpha)
	s.set_border_width_all(0)
	s.set_corner_radius_all(4)
	return s

func _add_separator(parent: Control) -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_color_override("color", _C_LINE2)
	parent.add_child(sep)

func _make_label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl
