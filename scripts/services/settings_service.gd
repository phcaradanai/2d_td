extends Node
class_name SettingsService

signal settings_changed(settings: Dictionary)

const DEFAULT_AUDIO := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"master_muted": false,
	"music_muted": false,
	"sfx_muted": false,
	"audio_combat_mode": "balanced",
}

const DEFAULT_DISPLAY := {
	"window_mode": "borderless",
}

const DEFAULT_PERFORMANCE := {
	"visual_quality": "auto",
	"attack_vfx": "normal",
	"floating_damage_numbers": "off",
	"status_effects": "icons_only",
	"screen_shake": "off",
}

var save_manager: Node = null
var audio_manager: Node = null
var display_mode_service: Node = null
var performance_budget_service: Node = null

var _audio_settings: Dictionary = DEFAULT_AUDIO.duplicate(true)
var _display_settings: Dictionary = DEFAULT_DISPLAY.duplicate(true)
var _performance_settings: Dictionary = DEFAULT_PERFORMANCE.duplicate(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind(deps: Dictionary) -> void:
	save_manager = deps.get("save_manager") as Node
	audio_manager = deps.get("audio_manager") as Node
	display_mode_service = deps.get("display_mode_service") as Node
	performance_budget_service = deps.get("performance_budget_service") as Node

func load_and_apply() -> void:
	_audio_settings = _merge(DEFAULT_AUDIO, save_manager.get_audio_settings() if save_manager and save_manager.has_method("get_audio_settings") else {})
	_display_settings = _merge(DEFAULT_DISPLAY, save_manager.get_display_settings() if save_manager and save_manager.has_method("get_display_settings") else {})
	_performance_settings = _merge(DEFAULT_PERFORMANCE, save_manager.get_performance_settings() if save_manager and save_manager.has_method("get_performance_settings") else {})
	_apply_all(false)
	settings_changed.emit(get_settings())

func get_settings() -> Dictionary:
	return {
		"audio": _audio_settings.duplicate(true),
		"display": _display_settings.duplicate(true),
		"performance": _performance_settings.duplicate(true),
	}

func get_display_mode_options() -> Array:
	if display_mode_service and display_mode_service.has_method("get_mode_options"):
		return display_mode_service.get_mode_options()
	return [
		{"id": "windowed", "label": "Windowed"},
		{"id": "borderless", "label": "Borderless"},
		{"id": "fullscreen", "label": "Fullscreen"},
	]

func update_audio_settings(settings: Dictionary) -> void:
	_audio_settings = _merge(_audio_settings, settings)
	_apply_audio()
	if save_manager and save_manager.has_method("update_audio_settings"):
		save_manager.update_audio_settings(_audio_settings)
	settings_changed.emit(get_settings())

func update_display_settings(settings: Dictionary) -> void:
	_display_settings = _merge(_display_settings, settings)
	_apply_display()
	if save_manager and save_manager.has_method("update_display_settings"):
		save_manager.update_display_settings(_display_settings)
	settings_changed.emit(get_settings())

func update_performance_settings(settings: Dictionary) -> void:
	_performance_settings = _merge(_performance_settings, settings)
	_apply_performance()
	if save_manager and save_manager.has_method("update_performance_settings"):
		save_manager.update_performance_settings(_performance_settings)
	settings_changed.emit(get_settings())

func reset_to_defaults() -> void:
	_audio_settings = DEFAULT_AUDIO.duplicate(true)
	_display_settings = DEFAULT_DISPLAY.duplicate(true)
	_performance_settings = DEFAULT_PERFORMANCE.duplicate(true)
	_apply_all(true)
	settings_changed.emit(get_settings())

func _apply_all(save: bool) -> void:
	_apply_audio()
	_apply_display()
	_apply_performance()
	if save and save_manager:
		if save_manager.has_method("update_audio_settings"):
			save_manager.update_audio_settings(_audio_settings)
		if save_manager.has_method("update_display_settings"):
			save_manager.update_display_settings(_display_settings)
		if save_manager.has_method("update_performance_settings"):
			save_manager.update_performance_settings(_performance_settings)

func _apply_audio() -> void:
	if audio_manager and audio_manager.has_method("apply_settings"):
		audio_manager.apply_settings(_audio_settings)

func _apply_display() -> void:
	if display_mode_service and display_mode_service.has_method("apply_settings"):
		display_mode_service.apply_settings(_display_settings)

func _apply_performance() -> void:
	if performance_budget_service and performance_budget_service.has_method("apply_settings"):
		performance_budget_service.apply_settings(_performance_settings)
		if performance_budget_service.has_method("get_settings"):
			_performance_settings = performance_budget_service.get_settings()

func _merge(base: Dictionary, patch: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in patch.keys():
		merged[key] = patch[key]
	return merged
