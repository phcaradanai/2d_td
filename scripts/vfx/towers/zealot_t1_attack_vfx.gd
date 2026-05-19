extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(0.10, 0.80, 1.00)
	palette_secondary = Color(1.00, 0.30, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_rapid_tracer(t, a, lend)
