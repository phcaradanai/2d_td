extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.75, 0.45, 1.00)
	palette_secondary = Color(0.45, 0.08, 0.75)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_trickery_shimmer(t, a, lend)
