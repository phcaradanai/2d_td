extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(1.00, 0.65, 0.25)
	palette_secondary = Color(1.00, 0.85, 0.55)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_light_pulse(t, a, lend)
