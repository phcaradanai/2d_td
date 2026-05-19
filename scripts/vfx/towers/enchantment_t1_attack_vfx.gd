extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.26
	palette_primary  = Color(0.55, 1.00, 0.65)
	palette_secondary = Color(1.00, 0.95, 0.60)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_magic_enchant(t, a, lend)
