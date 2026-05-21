extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"

func configure(_data: Dictionary) -> void:
	lifetime = 0.24
	palette_primary  = Color(0.80, 0.65, 0.35)
	palette_secondary = Color(1.00, 0.85, 0.45)

func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	var distance := maxf(lend.length(), 1.0)
	var arc_height := clampf(distance * 0.14, 12.0, 36.0)
	var pts := PackedVector2Array()
	for i in range(9):
		var f := float(i) / 8.0
		var x := lend.x * f
		var y := -sin(f * PI) * arc_height
		pts.append(Vector2(x, y))

	if pts.size() >= 2:
		draw_polyline(pts, Color(0.05, 0.025, 0.0, a * 0.30), 5.0, true)
		draw_polyline(pts, Color(palette_primary.r, palette_primary.g, palette_primary.b, a * 0.72), 2.7, true)
		draw_polyline(pts, Color(1.0, 0.88, 0.46, a * 0.90), 1.1, true)

	var shell_pos := pts[pts.size() - 1] if pts.size() > 0 else lend
	var shell_dir := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() if pts.size() >= 2 else Vector2.RIGHT
	var shell_side := shell_dir.rotated(PI * 0.5)
	var shell := PackedVector2Array([
		shell_pos + shell_dir * 8.0,
		shell_pos - shell_dir * 4.5 + shell_side * 3.5,
		shell_pos - shell_dir * 7.5,
		shell_pos - shell_dir * 4.5 - shell_side * 3.5,
	])
	draw_colored_polygon(shell, Color(0.12, 0.07, 0.02, a * 0.82))
	draw_polyline(PackedVector2Array([shell[0], shell[1], shell[2], shell[3], shell[0]]), Color(1.0, 0.78, 0.35, a * 0.92), 1.4, true)

	_draw_muzzle_burst(t, a)

static func _ring_alpha(a: float, scale: float) -> Color:
	return Color(1.0, 0.74, 0.30, a * scale)

func _draw_muzzle_burst(t: float, a: float) -> void:
	var r := 8.0 + t * 18.0
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.36, 0.08, a * 0.12))
	draw_arc(Vector2.ZERO, r, -0.72, 0.72, 16, _ring_alpha(a, 0.86), 2.6, true)
	draw_arc(Vector2.ZERO, r + 5.0, -0.48, 0.48, 14, Color(1.0, 0.94, 0.62, a * 0.34), 1.4, true)
	for i in range(5):
		var spread := -0.42 + float(i) * 0.21
		var len := (20.0 + float(i % 2) * 7.0) * (1.0 - t * 0.35)
		var end := Vector2(cos(spread) * len, sin(spread) * len)
		draw_line(Vector2.ZERO, end, Color(1.0, 0.62, 0.20, a * (0.78 - float(i) * 0.08)), 2.2, true)
	draw_circle(Vector2.ZERO, 4.5 * (1.0 - t * 0.45), Color(1.0, 0.90, 0.48, a * 0.82))
