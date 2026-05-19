extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.25
	palette_primary  = Color(0.30, 0.75, 0.20)
	palette_secondary = Color(0.15, 0.55, 0.08)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_nature_vine(t, a, lend)
