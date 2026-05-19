extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(1.00, 0.92, 0.25)
	palette_secondary = Color(1.00, 1.00, 0.80)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_precision_beam(t, a, lend)
