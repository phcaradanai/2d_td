extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.50, 0.45, 0.35)
	palette_secondary = Color(1.0, 0.75, 0.30)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
