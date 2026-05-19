extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(1.0, 0.30, 0.05)
	palette_secondary = Color(1.0, 0.70, 0.10)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
