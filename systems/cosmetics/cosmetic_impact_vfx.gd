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
var _sprite_frames: Array[Texture2D] = []

func setup(cfg: Dictionary) -> void:
	_duration = minf(float(cfg.get("duration", MAX_DURATION)), MAX_DURATION)
	_age = 0.0
	_redraw_elapsed = 0.0
	_redraw_interval = clampf(float(cfg.get("_redraw_interval", DEFAULT_REDRAW_INTERVAL)), 0.04, MAX_DURATION)
	_cfg = cfg.duplicate(true)
	_sprite_frames.clear()
	var raw_paths = cfg.get("sprite_paths", [])
	if raw_paths is Array and not raw_paths.is_empty():
		for raw_path in raw_paths:
			var path := str(raw_path)
			if ResourceLoader.exists(path):
				_sprite_frames.append(load(path) as Texture2D)
		scale = Vector2.ONE
		modulate = Color.WHITE
		z_as_relative = false
		z_index = 180
		set_process(true)
		queue_redraw()
		return
	var sprite_dir := str(cfg.get("sprite_dir", ""))
	var sprite_count := int(cfg.get("sprite_count", 0))
	var sprite_prefix := str(cfg.get("sprite_prefix", ""))
	if sprite_dir != "" and sprite_count > 0:
		var start_index := int(cfg.get("sprite_start_index", 0))
		for i in range(sprite_count):
			var path := sprite_dir + sprite_prefix + "%02d.png" % (i + start_index)
			if ResourceLoader.exists(path):
				_sprite_frames.append(load(path) as Texture2D)
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
	if _sprite_frames.size() > 0:
		var progress := _age / maxf(_duration, 0.001)
		var frame_idx := mini(int(progress * _sprite_frames.size()), _sprite_frames.size() - 1)
		var tex := _sprite_frames[frame_idx]
		if tex != null:
			var tex_scale := float(_cfg.get("sprite_scale", 0.25))
			var half := tex.get_size() * tex_scale * 0.5
			draw_texture_rect(tex, Rect2(-half, tex.get_size() * tex_scale), false)
		return
	CosmeticDrawUtilsScript.draw_impact(self, _cfg, _age / maxf(_duration, 0.001))
