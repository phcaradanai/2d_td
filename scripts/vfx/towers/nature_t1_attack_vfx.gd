extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"

const CosmeticSpriteRendererScript := preload("res://systems/cosmetics/cosmetic_sprite_renderer.gd")

var _cosmetic_sprite_data: Dictionary = {}
var _cosmetic_sprite_frames: Array[Texture2D] = []

func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.22, 0.95, 0.34)
	palette_secondary = Color(0.45, 1.00, 0.30)
	_reload_sprite_frames()

func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	if _cosmetic_sprite_frames.size() > 0:
		_draw_cosmetic_sprite_vfx(t, a)
		return
	_h_nature_vine(t, a, lend)

func _reload_sprite_frames() -> void:
	_cosmetic_sprite_frames = CosmeticSpriteRendererScript.collect_textures(_cosmetic_sprite_data)

func _draw_cosmetic_sprite_vfx(t: float, a: float) -> void:
	var frame_idx := mini(int(t * _cosmetic_sprite_frames.size()), _cosmetic_sprite_frames.size() - 1)
	var tex := _cosmetic_sprite_frames[frame_idx]
	if tex == null:
		return
	CosmeticSpriteRendererScript.draw_texture(self, _cosmetic_sprite_data, tex, a)
