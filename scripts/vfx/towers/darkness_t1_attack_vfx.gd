extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.45, 0.10, 0.85)
	palette_secondary = Color(0.80, 0.20, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
