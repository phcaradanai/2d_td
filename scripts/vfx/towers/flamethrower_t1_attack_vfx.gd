extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(1.0, 0.22, 0.00)
	palette_secondary = Color(1.0, 0.50, 0.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_flame_cone(t, a, lend)
