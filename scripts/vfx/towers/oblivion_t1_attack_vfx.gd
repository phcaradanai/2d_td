extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.65, 0.20, 1.00)
	palette_secondary = Color(0.90, 0.50, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
