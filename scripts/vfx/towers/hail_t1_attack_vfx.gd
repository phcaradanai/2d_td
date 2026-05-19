extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.15
	palette_primary  = Color(0.65, 0.85, 1.00)
	palette_secondary = Color(0.90, 0.95, 1.00)
func _draw_vfx(_t: float, a: float, lend: Vector2) -> void:
	_h_electric_arc(a, lend, false)
