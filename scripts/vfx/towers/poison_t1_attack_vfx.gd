extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.52, 0.12, 0.88)
	palette_secondary = Color(0.75, 0.25, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_poison_spray(t, a, lend)
