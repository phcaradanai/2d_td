extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.75, 0.85, 1.00)
	palette_secondary = Color(0.55, 0.70, 0.90)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_steam_burst(t, a, lend)
