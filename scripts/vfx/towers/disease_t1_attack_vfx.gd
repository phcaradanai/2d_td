extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.42, 1.00, 0.22)
	palette_secondary = Color(0.20, 0.70, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_spore_puff(t, a, lend)
