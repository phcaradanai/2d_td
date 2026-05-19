extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(1.00, 0.55, 0.10)
	palette_secondary = Color(1.00, 0.85, 0.30)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_support_pulse(t, a)
