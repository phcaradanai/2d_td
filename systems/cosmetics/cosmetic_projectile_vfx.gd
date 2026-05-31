extends Node2D

signal finished()

const CosmeticSpriteRendererScript := preload("res://systems/cosmetics/cosmetic_sprite_renderer.gd")
const MAX_DURATION := 0.22

var _cfg: Dictionary = {}
var _sprite_frames: Array[Texture2D] = []
var _age: float = 0.0
var _duration: float = 0.16
var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO

func setup(cfg: Dictionary, start_pos: Vector2, end_pos: Vector2) -> void:
	_cfg = cfg.duplicate(true)
	_sprite_frames.clear()
	_age = 0.0
	_start_pos = start_pos
	_end_pos = end_pos
	_duration = float(cfg.get("_preview_duration", minf(float(cfg.get("duration", 0.16)), MAX_DURATION)))
	global_position = _start_pos
	var diff := _end_pos - _start_pos
	if diff.length_squared() > 0.001:
		global_rotation = diff.angle()
	_load_frames(cfg)
	z_as_relative = false
	z_index = 160
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	var progress := clampf(_age / maxf(_duration, 0.001), 0.0, 1.0)
	global_position = _start_pos.lerp(_end_pos, progress)
	queue_redraw()
	if _age >= _duration:
		set_process(false)
		finished.emit()

func _draw() -> void:
	var progress := clampf(_age / maxf(_duration, 0.001), 0.0, 1.0)
	CosmeticSpriteRendererScript.draw_frame(self, _cfg, _sprite_frames, progress)

func _load_frames(cfg: Dictionary) -> void:
	_sprite_frames = CosmeticSpriteRendererScript.collect_textures(cfg)
