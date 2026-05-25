extends Node2D

signal finished()

const CosmeticDrawUtilsScript := preload("res://systems/cosmetics/cosmetic_draw_utils.gd")
const MAX_DURATION := 0.25
const DEFAULT_REDRAW_INTERVAL := 0.06

var _duration: float = MAX_DURATION
var _age: float = 0.0
var _redraw_elapsed: float = 0.0
var _redraw_interval: float = DEFAULT_REDRAW_INTERVAL
var _cfg: Dictionary = {}

func setup(cfg: Dictionary) -> void:
	_duration = minf(float(cfg.get("duration", MAX_DURATION)), MAX_DURATION)
	_age = 0.0
	_redraw_elapsed = 0.0
	_redraw_interval = clampf(float(cfg.get("_redraw_interval", DEFAULT_REDRAW_INTERVAL)), 0.04, MAX_DURATION)
	_cfg = cfg.duplicate(true)
	scale = Vector2.ONE
	modulate = Color.WHITE
	z_as_relative = false
	z_index = 180
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		set_process(false)
		finished.emit()
		return
	_redraw_elapsed += delta
	if _redraw_elapsed >= _redraw_interval:
		_redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	CosmeticDrawUtilsScript.draw_impact(self, _cfg, _age / maxf(_duration, 0.001))
