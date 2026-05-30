extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"

var _cosmetic_sprite_data: Dictionary = {}
var _cosmetic_sprite_frames: Array[Texture2D] = []

func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(1.00, 0.92, 0.25)
	palette_secondary = Color(1.00, 1.00, 0.80)
	_reload_sprite_frames()

func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	if _cosmetic_sprite_frames.size() > 0:
		_draw_cosmetic_sprite_vfx(t, a)
		return
	_h_precision_beam(t, a, lend)

func _reload_sprite_frames() -> void:
	_cosmetic_sprite_frames.clear()
	var raw_paths = _cosmetic_sprite_data.get("sprite_paths", [])
	if raw_paths is Array and not raw_paths.is_empty():
		for raw_path in raw_paths:
			var path := str(raw_path)
			if ResourceLoader.exists(path):
				_cosmetic_sprite_frames.append(load(path) as Texture2D)
		return

	var sprite_dir := str(_cosmetic_sprite_data.get("sprite_dir", ""))
	var sprite_count := int(_cosmetic_sprite_data.get("sprite_count", 0))
	var sprite_prefix := str(_cosmetic_sprite_data.get("sprite_prefix", ""))
	var start_index := int(_cosmetic_sprite_data.get("sprite_start_index", 0))
	if sprite_dir == "" or sprite_count <= 0:
		return
	for i in range(sprite_count):
		var path := sprite_dir + sprite_prefix + "%02d.png" % (i + start_index)
		if ResourceLoader.exists(path):
			_cosmetic_sprite_frames.append(load(path) as Texture2D)

func _draw_cosmetic_sprite_vfx(t: float, a: float) -> void:
	var frame_idx := mini(int(t * _cosmetic_sprite_frames.size()), _cosmetic_sprite_frames.size() - 1)
	var tex := _cosmetic_sprite_frames[frame_idx]
	if tex == null:
		return
	var tex_scale := float(_cosmetic_sprite_data.get("sprite_scale", 0.25))
	var half := tex.get_size() * tex_scale * 0.5
	draw_texture_rect(tex, Rect2(-half, tex.get_size() * tex_scale), false, Color(1.0, 1.0, 1.0, a))
