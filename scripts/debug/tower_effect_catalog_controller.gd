# scripts/debug/tower_effect_catalog_controller.gd
class_name TowerEffectCatalogController
extends Node

@warning_ignore("unused_signal")
signal filters_changed
@warning_ignore("unused_signal")
signal replay_selected_requested
@warning_ignore("unused_signal")
signal vfx_toggle_changed(vfx_type: String, enabled: bool)
signal auto_play_tick

var search_text: String = ""
var element_filter: String = "all"
var tier_filter: String = "all"
var attack_filter: String = "all"

var show_models: bool = true
var show_attack_vfx: bool = true
var show_status_fx: bool = true
var show_support_fx: bool = true
var auto_play_enabled: bool = false
var paused: bool = false

var _fps_label: Label = null
var _vfx_count_label: Label = null
var _auto_play_timer: Timer = null

func _ready() -> void:
	setup_timer()

func setup_timer() -> void:
	_auto_play_timer = Timer.new()
	_auto_play_timer.wait_time = 0.8
	_auto_play_timer.autostart = false
	_auto_play_timer.timeout.connect(_on_auto_play_tick)
	add_child(_auto_play_timer)

func set_status_labels(fps: Label, vfx_count: Label) -> void:
	_fps_label = fps
	_vfx_count_label = vfx_count

func _process(_delta: float) -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if _vfx_count_label:
		_vfx_count_label.text = "VFX: %d" % BaseTowerAttackVFX._active_count

func set_auto_play(enabled: bool) -> void:
	auto_play_enabled = enabled
	if enabled and not paused:
		_auto_play_timer.start()
	else:
		_auto_play_timer.stop()

func set_paused(p: bool) -> void:
	paused = p
	if p:
		_auto_play_timer.stop()
	elif auto_play_enabled:
		_auto_play_timer.start()

func _on_auto_play_tick() -> void:
	if not paused and auto_play_enabled:
		auto_play_tick.emit()
