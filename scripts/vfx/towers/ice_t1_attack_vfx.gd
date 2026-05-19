extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.55, 0.90, 1.00)
	palette_secondary = Color(0.85, 0.95, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_frost_beam(t, a, lend)
