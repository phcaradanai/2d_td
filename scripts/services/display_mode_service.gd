extends Node
## DisplayModeService
##
## Owns desktop window mode changes. Gameplay/layout code should continue to
## react to actual viewport size instead of reading display settings directly.

signal display_mode_changed(settings: Dictionary)

const MODE_WINDOWED := "windowed"
const MODE_BORDERLESS := "borderless"
const MODE_FULLSCREEN := "fullscreen"
const MODE_EXCLUSIVE_FULLSCREEN := "exclusive_fullscreen"
const MODE_MAXIMIZED := "maximized"

const DEFAULT_MODE := MODE_BORDERLESS
const MIN_WINDOW_SIZE := Vector2i(1280, 720)
const DESIGN_WINDOW_SIZE := Vector2i(1600, 900)

var _current_mode: String = DEFAULT_MODE
var _last_windowed_size: Vector2i = DESIGN_WINDOW_SIZE
var _last_windowed_position: Vector2i = Vector2i.ZERO
var _applying: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(_is_desktop_window_supported())

func get_default_settings() -> Dictionary:
	return {"window_mode": DEFAULT_MODE}

func get_current_settings() -> Dictionary:
	return {"window_mode": _current_mode}

func get_mode_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"id": MODE_WINDOWED, "label": "Windowed"},
		{"id": MODE_BORDERLESS, "label": "Borderless"},
		{"id": MODE_FULLSCREEN, "label": "Fullscreen"},
	]
	if _supports_exclusive_fullscreen():
		options.append({"id": MODE_EXCLUSIVE_FULLSCREEN, "label": "Exclusive Fullscreen"})
	return options

func apply_settings(settings: Dictionary, emit_changed: bool = false) -> void:
	apply_window_mode(str(settings.get("window_mode", DEFAULT_MODE)), emit_changed)

func apply_window_mode(mode: String, emit_changed: bool = true) -> void:
	mode = _normalize_mode(mode)
	_current_mode = mode

	if not _is_desktop_window_supported():
		if emit_changed:
			display_mode_changed.emit(get_current_settings())
		return

	_applying = true
	match mode:
		MODE_WINDOWED:
			_apply_windowed()
		MODE_FULLSCREEN:
			_apply_fullscreen()
		MODE_EXCLUSIVE_FULLSCREEN:
			_apply_exclusive_fullscreen()
		MODE_MAXIMIZED:
			_apply_maximized_windowed()
		_:
			_apply_borderless_windowed()
	_applying = false

	if emit_changed:
		display_mode_changed.emit(get_current_settings())

func toggle_window_mode() -> void:
	if not _is_desktop_window_supported():
		return
	var current := DisplayServer.window_get_mode()
	if _current_mode == MODE_WINDOWED or current == DisplayServer.WINDOW_MODE_WINDOWED and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		apply_window_mode(MODE_BORDERLESS)
	else:
		apply_window_mode(MODE_WINDOWED)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F11 \
			and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		toggle_window_mode()
		get_viewport().set_input_as_handled()

func _apply_windowed() -> void:
	_capture_windowed_geometry()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var usable := _get_usable_screen_rect()
	var target_size := _last_windowed_size
	if target_size.x <= 0 or target_size.y <= 0:
		target_size = DESIGN_WINDOW_SIZE
	target_size.x = clampi(target_size.x, MIN_WINDOW_SIZE.x, max(MIN_WINDOW_SIZE.x, usable.size.x))
	target_size.y = clampi(target_size.y, MIN_WINDOW_SIZE.y, max(MIN_WINDOW_SIZE.y, usable.size.y))
	DisplayServer.window_set_size(target_size)
	DisplayServer.window_set_position(_center_position_for_size(target_size, usable))

func _apply_borderless_windowed() -> void:
	_capture_windowed_geometry()
	var usable := _get_usable_screen_rect()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(usable.position)
	DisplayServer.window_set_size(Vector2i(
		max(MIN_WINDOW_SIZE.x, usable.size.x),
		max(MIN_WINDOW_SIZE.y, usable.size.y)
	))

func _apply_fullscreen() -> void:
	_capture_windowed_geometry()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_exclusive_fullscreen() -> void:
	_capture_windowed_geometry()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _apply_maximized_windowed() -> void:
	_capture_windowed_geometry()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _capture_windowed_geometry() -> void:
	if _applying:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		var size := DisplayServer.window_get_size()
		if size.x > 0 and size.y > 0:
			_last_windowed_size = size
		_last_windowed_position = DisplayServer.window_get_position()

func _get_usable_screen_rect() -> Rect2i:
	var screen := DisplayServer.window_get_current_screen()
	var rect := DisplayServer.screen_get_usable_rect(screen)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = Rect2i(Vector2i.ZERO, DisplayServer.screen_get_size(screen))
	return rect

func _center_position_for_size(size: Vector2i, usable: Rect2i) -> Vector2i:
	return usable.position + Vector2i(
		max(0, int((usable.size.x - size.x) * 0.5)),
		max(0, int((usable.size.y - size.y) * 0.5))
	)

func _normalize_mode(mode: String) -> String:
	match mode:
		MODE_WINDOWED, MODE_BORDERLESS, MODE_FULLSCREEN, MODE_EXCLUSIVE_FULLSCREEN, MODE_MAXIMIZED:
			if mode == MODE_EXCLUSIVE_FULLSCREEN and not _supports_exclusive_fullscreen():
				return MODE_FULLSCREEN
			return mode
		_:
			return DEFAULT_MODE

func _is_desktop_window_supported() -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		return false
	if OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios"):
		return false
	var os_name := OS.get_name()
	if os_name in ["Web", "Android", "iOS"]:
		return false
	return os_name in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]

func _supports_exclusive_fullscreen() -> bool:
	return _is_desktop_window_supported() and OS.get_name() in ["Windows", "Linux"]
