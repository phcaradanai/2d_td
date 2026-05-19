extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.15
	palette_primary  = Color(0.50, 0.40, 1.00)
	palette_secondary = Color(0.90, 0.80, 1.00)
func _draw_vfx(_t: float, a: float, lend: Vector2) -> void:
	_h_electric_arc(a, lend, true)
