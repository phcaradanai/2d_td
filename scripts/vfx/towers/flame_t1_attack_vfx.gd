extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(1.0, 0.35, 0.05)
	palette_secondary = Color(1.0, 0.65, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_flame_cone(t, a, lend)
