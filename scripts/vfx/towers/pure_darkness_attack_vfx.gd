extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.26
	palette_primary  = Color(0.35, 0.05, 0.65)
	palette_secondary = Color(0.60, 0.10, 0.90)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
