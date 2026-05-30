extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"

var _cosmetic_sprite_data: Dictionary = {}
var _cosmetic_sprite_frames: Array[Texture2D] = []

func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(0.80, 0.65, 0.35)
	palette_secondary = Color(1.00, 0.85, 0.45)
	_reload_sprite_frames()

func _reload_sprite_frames() -> void:
	_cosmetic_sprite_frames.clear()
	var sprite_dir := str(_cosmetic_sprite_data.get("sprite_dir", ""))
	var sprite_count := int(_cosmetic_sprite_data.get("sprite_count", 0))
	var sprite_prefix := str(_cosmetic_sprite_data.get("sprite_prefix", ""))
	if sprite_dir == "" or sprite_count <= 0:
		return
	for i in range(sprite_count):
		var path := sprite_dir + sprite_prefix + "%02d.png" % i
		if ResourceLoader.exists(path):
			_cosmetic_sprite_frames.append(load(path) as Texture2D)

func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	if _cosmetic_sprite_frames.size() > 0:
		var frame_idx := mini(int(t * _cosmetic_sprite_frames.size()), _cosmetic_sprite_frames.size() - 1)
		var tex := _cosmetic_sprite_frames[frame_idx]
		if tex != null:
			var tex_scale := float(_cosmetic_sprite_data.get("sprite_scale", 0.25))
			var half := tex.get_size() * tex_scale * 0.5
			draw_texture_rect(tex, Rect2(-half, tex.get_size() * tex_scale), false, Color(1.0, 1.0, 1.0, a))
		return
	_draw_muzzle_burst(t, a)

func _draw_muzzle_burst(t: float, a: float) -> void:
	var core := 1.0 - t * 0.35
	var flare := PackedVector2Array([
		Vector2(0, -4.5 * core),
		Vector2(14.0 + t * 8.0, -2.0 * core),
		Vector2(22.0 + t * 10.0, 0),
		Vector2(14.0 + t * 8.0, 2.0 * core),
		Vector2(0, 4.5 * core),
	])
	draw_colored_polygon(flare, Color(1.0, 0.46, 0.12, a * 0.24))
	draw_line(Vector2.ZERO, Vector2(22.0 + t * 8.0, 0), Color(1.0, 0.82, 0.38, a * 0.82), 2.4, true)
	for i in range(5):
		var spread := -0.34 + float(i) * 0.17
		var len := (12.0 + float(i % 2) * 5.0) * (1.0 - t * 0.25)
		var end := Vector2(cos(spread) * len, sin(spread) * len)
		draw_line(Vector2.ZERO, end, Color(1.0, 0.60, 0.20, a * (0.58 - float(i) * 0.06)), 1.6, true)
	draw_circle(Vector2.ZERO, 3.5 * core, Color(1.0, 0.90, 0.50, a * 0.74))
