extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(0.20, 0.60, 1.00)
	palette_secondary = Color(0.40, 0.80, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_water_jet(t, a, lend)
