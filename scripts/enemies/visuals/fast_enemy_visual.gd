const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Fast / Signal Runner visual identity:
# - accelerated corrupted data packet
# - fragile, high-speed ground unit
# - nature-armored signal shell with lean arrow silhouette
# - draw-only: no particles, nodes, tweens, timers, or gameplay state changes

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	if result.size() > 0:
		result.append(result[0])
	return result


static func _ellipse_points(center: Vector2, radius: Vector2, segments: int = 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(8, segments)
	for i in range(safe_segments):
		var a := TAU * float(i) / float(safe_segments)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points

static func _draw_poly_outline(enemy: Node2D, points: PackedVector2Array, fill: Color, outline: Color, outline_width: float = 1.0) -> void:
	enemy.draw_colored_polygon(points, fill)
	enemy.draw_polyline(_closed(points), outline, outline_width, true)

static func _nature_color(base: Color, health_state: int) -> Color:
	# Nature armor should stay agile/green while damage tint remains visible.
	return B.apply_health_tint(base, health_state)

static func draw_simple(enemy: Node2D, size: float) -> void:
	var health_state: int = int(enemy.get("health_visual_state"))
	var shell := _nature_color(Color(0.20, 0.92, 0.48, 0.88), health_state)
	var dark := Color(0.015, 0.035, 0.030, 0.92)
	var core := Color(0.76, 1.00, 0.68, 0.95)
	var top := Color(0.68, 1.0, 0.42, 0.82)
	var side := Color(0.07, 0.28, 0.12, 0.94)
	var lower := Color(0.018, 0.075, 0.040, 0.96)

	# Faceted arrow-packet hull: top, lower side, and nose planes survive baking.
	var body := PackedVector2Array([
		Vector2(size * 1.10, 0.0),
		Vector2(size * 0.16, -size * 0.42),
		Vector2(-size * 0.82, -size * 0.30),
		Vector2(-size * 0.42, 0.0),
		Vector2(-size * 0.82, size * 0.30),
		Vector2(size * 0.16, size * 0.42),
	])

	_draw_poly_outline(enemy, B.scale_polygon(body, 1.10), dark, Color(0.0, 0.0, 0.0, 0.72), 1.0)
	enemy.draw_colored_polygon(body, lower)
	enemy.draw_colored_polygon(PackedVector2Array([
		Vector2(size * 1.02, -size * 0.02),
		Vector2(size * 0.14, -size * 0.36),
		Vector2(-size * 0.72, -size * 0.24),
		Vector2(-size * 0.30, -size * 0.03),
		Vector2(size * 0.30, -size * 0.06),
	]), Color(top.r, top.g, top.b, 0.58))
	enemy.draw_colored_polygon(PackedVector2Array([
		Vector2(-size * 0.76, size * 0.10),
		Vector2(size * 0.26, size * 0.08),
		Vector2(size * 0.94, size * 0.00),
		Vector2(size * 0.15, size * 0.36),
		Vector2(-size * 0.74, size * 0.24),
	]), side)
	enemy.draw_colored_polygon(PackedVector2Array([
		Vector2(size * 0.30, -size * 0.08),
		Vector2(size * 1.05, 0.0),
		Vector2(size * 0.28, size * 0.18),
		Vector2(size * 0.08, 0.0),
	]), Color(shell.r, shell.g, shell.b, 0.96))
	enemy.draw_polyline(_closed(body), Color(shell.r, shell.g, shell.b, 0.92), 1.25, true)

	enemy.draw_line(Vector2(-size * 0.58, -size * 0.05), Vector2(size * 0.42, -size * 0.02), Color(core.r, core.g, core.b, 0.62), 1.1)
	enemy.draw_line(Vector2(-size * 0.58, size * 0.13), Vector2(size * 0.34, size * 0.12), Color(0.0, 0.0, 0.0, 0.50), 1.2)
	enemy.draw_circle(Vector2(size * 0.32, 0.0), size * 0.18, Color(0.02, 0.08, 0.05, 0.92))
	enemy.draw_circle(Vector2(size * 0.32, 0.0), size * 0.105, core)

static func draw(enemy: Node2D, size: float) -> void:
	var health_state: int = int(enemy.get("health_visual_state"))
	var pulse_time: float = float(enemy.get("pulse_time"))

	var nature := _nature_color(Color(0.22, 0.94, 0.46, 0.95), health_state)
	var lime := Color(0.72, 1.00, 0.52, 0.95)
	var dark := Color(0.012, 0.025, 0.022, 0.96)
	var shadow := Color(0.0, 0.0, 0.0, 0.26)

	# Keep animation cheap: two waves total, used only for subtle speed read.
	var pulse := 0.5 + 0.5 * sin(pulse_time * 9.0)
	var streak := 0.42 + 0.18 * sin(pulse_time * 14.0)

	# Ground shadow, narrow to sell speed without expensive blur/particles.
	enemy.draw_colored_polygon(_ellipse_points(Vector2(-size * 0.20, size * 0.50), Vector2(size * 1.20, size * 0.16), 18), shadow)

	# Main body: a lean signal-packet arrow. Distinct from Basic's compact node.
	var outer := PackedVector2Array([
		Vector2(size * 1.34, 0.0),
		Vector2(size * 0.44, -size * 0.52),
		Vector2(-size * 0.78, -size * 0.40),
		Vector2(-size * 1.10, -size * 0.16),
		Vector2(-size * 0.62, 0.0),
		Vector2(-size * 1.10, size * 0.16),
		Vector2(-size * 0.78, size * 0.40),
		Vector2(size * 0.44, size * 0.52),
	])

	var inner := PackedVector2Array([
		Vector2(size * 0.92, 0.0),
		Vector2(size * 0.30, -size * 0.30),
		Vector2(-size * 0.52, -size * 0.23),
		Vector2(-size * 0.28, 0.0),
		Vector2(-size * 0.52, size * 0.23),
		Vector2(size * 0.30, size * 0.30),
	])

	_draw_poly_outline(enemy, B.scale_polygon(outer, 1.09), Color(0.0, 0.0, 0.0, 0.74), Color(0.0, 0.0, 0.0, 0.70), 1.0)
	_draw_poly_outline(enemy, outer, dark, Color(0.0, 0.0, 0.0, 0.92), 1.45)

	# Nature armor plates: slim, bright, and fewer than before for readability.
	var shell_fill := Color(nature.r * 0.28, nature.g * 0.34, nature.b * 0.25, 0.92)
	_draw_poly_outline(enemy, inner, shell_fill, Color(nature.r, nature.g, nature.b, 0.76), 1.15)

	var top_plate := PackedVector2Array([
		Vector2(size * 0.24, -size * 0.36),
		Vector2(size * 0.66, -size * 0.20),
		Vector2(size * 0.22, -size * 0.09),
		Vector2(-size * 0.32, -size * 0.18),
	])
	var bottom_plate := PackedVector2Array([
		Vector2(size * 0.24, size * 0.36),
		Vector2(size * 0.66, size * 0.20),
		Vector2(size * 0.22, size * 0.09),
		Vector2(-size * 0.32, size * 0.18),
	])
	_draw_poly_outline(enemy, top_plate, Color(0.09, 0.22, 0.13, 0.88), Color(nature.r, nature.g, nature.b, 0.44), 0.9)
	_draw_poly_outline(enemy, bottom_plate, Color(0.09, 0.22, 0.13, 0.88), Color(nature.r, nature.g, nature.b, 0.44), 0.9)

	# Packet tail fins: small, not wing-like, to avoid confusing it with flyers.
	var tail_alpha := 0.32 + pulse * 0.08
	var top_fin := PackedVector2Array([
		Vector2(-size * 0.64, -size * 0.36),
		Vector2(-size * 1.18, -size * 0.72),
		Vector2(-size * 0.86, -size * 0.24),
	])
	var bottom_fin := PackedVector2Array([
		Vector2(-size * 0.64, size * 0.36),
		Vector2(-size * 1.18, size * 0.72),
		Vector2(-size * 0.86, size * 0.24),
	])
	enemy.draw_colored_polygon(top_fin, Color(nature.r, nature.g, nature.b, tail_alpha))
	enemy.draw_colored_polygon(bottom_fin, Color(nature.r, nature.g, nature.b, tail_alpha))

	# Two clean speed trails. No particles, no many tiny streaks.
	enemy.draw_line(Vector2(-size * 0.74, -size * 0.20), Vector2(-size * (1.70 + streak), -size * 0.28), Color(nature.r, nature.g, nature.b, 0.34), 1.45)
	enemy.draw_line(Vector2(-size * 0.74, size * 0.20), Vector2(-size * (1.70 + streak), size * 0.28), Color(nature.r, nature.g, nature.b, 0.34), 1.45)
	enemy.draw_line(Vector2(-size * 0.38, 0.0), Vector2(-size * (1.34 + streak * 0.5), 0.0), Color(lime.r, lime.g, lime.b, 0.20), 1.0)

	# Central signal spine: communicates "accelerated data packet".
	enemy.draw_line(Vector2(-size * 0.50, 0.0), Vector2(size * 0.86, 0.0), Color(0.0, 0.0, 0.0, 0.68), 2.25)
	enemy.draw_line(Vector2(-size * 0.48, 0.0), Vector2(size * 0.82, 0.0), Color(lime.r, lime.g, lime.b, 0.70), 1.1)

	# Focal core is forward and small: fragile but fast.
	var core_pos := Vector2(size * 0.46, 0.0)
	enemy.draw_circle(core_pos, size * 0.255, Color(0.0, 0.0, 0.0, 0.72))
	enemy.draw_circle(core_pos, size * (0.185 + pulse * 0.015), Color(nature.r, nature.g, nature.b, 0.58))
	enemy.draw_circle(core_pos, size * 0.105, Color(lime.r, lime.g, lime.b, 0.95))
	enemy.draw_circle(core_pos + Vector2(size * 0.035, -size * 0.035), size * 0.026, Color(1.0, 1.0, 0.86, 0.92))

	# Tiny ground-contact prongs; enough to read as ground unit, not flying.
	var leg_color := Color(0.06, 0.20, 0.10, 0.90)
	enemy.draw_line(Vector2(-size * 0.26, -size * 0.24), Vector2(-size * 0.54, -size * 0.48), leg_color, 1.25)
	enemy.draw_line(Vector2(-size * 0.26, size * 0.24), Vector2(-size * 0.54, size * 0.48), leg_color, 1.25)
	enemy.draw_line(Vector2(size * 0.26, -size * 0.23), Vector2(size * 0.08, -size * 0.46), leg_color, 1.15)
	enemy.draw_line(Vector2(size * 0.26, size * 0.23), Vector2(size * 0.08, size * 0.46), leg_color, 1.15)

	# One outer trim pass only: premium edge without noisy repeated outlines.
	enemy.draw_polyline(_closed(outer), Color(nature.r, nature.g, nature.b, 0.34 + pulse * 0.12), 1.0, true)
