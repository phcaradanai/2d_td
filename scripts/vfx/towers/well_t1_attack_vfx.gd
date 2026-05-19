extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.25, 0.80, 0.65)
	palette_secondary = Color(0.50, 1.00, 0.85)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_support_pulse(t, a)
