extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.55, 1.00, 0.20)
	palette_secondary = Color(0.30, 0.80, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_acid_splash(t, a, lend)
