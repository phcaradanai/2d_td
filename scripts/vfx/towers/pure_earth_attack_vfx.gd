extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.65, 0.45, 0.18)
	palette_secondary = Color(0.85, 0.65, 0.30)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_earth_impact(t, a)
