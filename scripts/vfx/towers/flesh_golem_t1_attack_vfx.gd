extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.55, 0.70, 0.35)
	palette_secondary = Color(0.30, 0.60, 0.20)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
