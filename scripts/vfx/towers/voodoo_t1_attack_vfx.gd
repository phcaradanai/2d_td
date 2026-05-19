extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.75, 0.15, 0.35)
	palette_secondary = Color(1.00, 0.35, 0.55)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
