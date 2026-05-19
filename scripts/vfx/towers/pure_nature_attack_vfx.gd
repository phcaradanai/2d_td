extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.12, 0.85, 0.25)
	palette_secondary = Color(0.35, 1.00, 0.45)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_nature_vine(t, a, lend)
