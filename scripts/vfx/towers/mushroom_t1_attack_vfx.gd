extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.65, 0.50, 0.85)
	palette_secondary = Color(0.45, 0.28, 0.70)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_spore_puff(t, a, lend)
