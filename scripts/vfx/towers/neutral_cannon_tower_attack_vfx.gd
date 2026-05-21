extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"

func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(0.80, 0.65, 0.35)
	palette_secondary = Color(1.00, 0.85, 0.45)

func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_draw_muzzle_burst(t, a)

func _draw_muzzle_burst(t: float, a: float) -> void:
	var core := 1.0 - t * 0.35
	var flare := PackedVector2Array([
		Vector2(0, -4.5 * core),
		Vector2(14.0 + t * 8.0, -2.0 * core),
		Vector2(22.0 + t * 10.0, 0),
		Vector2(14.0 + t * 8.0, 2.0 * core),
		Vector2(0, 4.5 * core),
	])
	draw_colored_polygon(flare, Color(1.0, 0.46, 0.12, a * 0.24))
	draw_line(Vector2.ZERO, Vector2(22.0 + t * 8.0, 0), Color(1.0, 0.82, 0.38, a * 0.82), 2.4, true)
	for i in range(5):
		var spread := -0.34 + float(i) * 0.17
		var len := (12.0 + float(i % 2) * 5.0) * (1.0 - t * 0.25)
		var end := Vector2(cos(spread) * len, sin(spread) * len)
		draw_line(Vector2.ZERO, end, Color(1.0, 0.60, 0.20, a * (0.58 - float(i) * 0.06)), 1.6, true)
	draw_circle(Vector2.ZERO, 3.5 * core, Color(1.0, 0.90, 0.50, a * 0.74))
