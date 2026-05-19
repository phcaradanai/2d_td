extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.25, 0.35, 0.85)
	palette_secondary = Color(0.10, 0.50, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_shadow_lash(t, a, lend)
