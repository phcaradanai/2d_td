const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Ghost Code
# - Stealth / medium ground enemy
# - Darkness armor
# - Visual-only renderer. No gameplay state mutation, particles, timers, tweens, or child nodes.

static func draw_simple(enemy: Node2D, size: float) -> void:
	var alpha := _stealth_alpha(enemy, 0.74)
	var body_color := Color(0.30, 0.18, 0.52, alpha)
	var edge_color := Color(0.72, 0.55, 1.00, alpha * 0.78)
	var core_color := Color(0.86, 0.68, 1.00, alpha)

	var body := PackedVector2Array([
		Vector2(0.00, -size * 0.96),
		Vector2(size * 0.58, -size * 0.38),
		Vector2(size * 0.42, size * 0.52),
		Vector2(0.00, size * 0.82),
		Vector2(-size * 0.42, size * 0.52),
		Vector2(-size * 0.58, -size * 0.38),
	])

	enemy.draw_colored_polygon(B.scale_polygon(body, 1.10), Color(0.03, 0.02, 0.07, alpha * 0.86))
	enemy.draw_colored_polygon(body, body_color)

	enemy.draw_line(Vector2(-size * 0.34, -size * 0.48), Vector2(size * 0.34, -size * 0.48), edge_color, 1.4)
	enemy.draw_line(Vector2(-size * 0.26, size * 0.30), Vector2(size * 0.26, size * 0.30), Color(0.48, 0.86, 1.00, alpha * 0.42), 1.0)
	enemy.draw_circle(Vector2.ZERO, size * 0.22, Color(0.08, 0.04, 0.16, alpha * 0.95))
	enemy.draw_circle(Vector2.ZERO, size * 0.13, core_color)


static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var phase := pulse_time * 2.2
	var shimmer := (sin(phase) * 0.5 + 0.5)
	var alpha := _stealth_alpha(enemy, 0.82)

	var darkness_shell := Color(0.16, 0.08, 0.27, alpha)
	var deep_plate := Color(0.24, 0.12, 0.42, alpha * 0.96)
	var violet_edge := Color(0.70, 0.46, 1.00, alpha * 0.72)
	var cyan_glitch := Color(0.38, 0.90, 1.00, alpha * 0.38)
	var ghost_core := Color(0.92, 0.76, 1.00, alpha)

	# Cheap ground shadow; keeps the medium unit readable without making it look airborne.
	enemy.draw_circle(Vector2(0, size * 0.46), size * 0.62, Color(0.01, 0.01, 0.03, 0.20 * alpha))

	# Hooded spectral cyber chassis: stealth identity, but still a solid ground target.
	var shell := PackedVector2Array([
		Vector2(0.00, -size * 1.05),
		Vector2(size * 0.52, -size * 0.62),
		Vector2(size * 0.70, -size * 0.04),
		Vector2(size * 0.44, size * 0.55),
		Vector2(size * 0.14, size * 0.78),
		Vector2(0.00, size * 0.66),
		Vector2(-size * 0.14, size * 0.78),
		Vector2(-size * 0.44, size * 0.55),
		Vector2(-size * 0.70, -size * 0.04),
		Vector2(-size * 0.52, -size * 0.62),
	])

	var inner := PackedVector2Array([
		Vector2(0.00, -size * 0.78),
		Vector2(size * 0.38, -size * 0.44),
		Vector2(size * 0.40, size * 0.26),
		Vector2(size * 0.15, size * 0.52),
		Vector2(0.00, size * 0.42),
		Vector2(-size * 0.15, size * 0.52),
		Vector2(-size * 0.40, size * 0.26),
		Vector2(-size * 0.38, -size * 0.44),
	])

	enemy.draw_colored_polygon(B.scale_polygon(shell, 1.08), Color(0.02, 0.01, 0.05, alpha * 0.92))
	enemy.draw_colored_polygon(shell, darkness_shell)
	enemy.draw_colored_polygon(inner, deep_plate)

	# Broken stealth rim: a few clean edges instead of noisy flicker lines.
	enemy.draw_line(shell[9], shell[0], violet_edge, 1.6)
	enemy.draw_line(shell[0], shell[1], violet_edge, 1.6)
	enemy.draw_line(shell[2], shell[3], Color(violet_edge.r, violet_edge.g, violet_edge.b, alpha * 0.42), 1.2)
	enemy.draw_line(shell[7], shell[8], Color(violet_edge.r, violet_edge.g, violet_edge.b, alpha * 0.42), 1.2)

	# Minimal glitch bands, offset subtly so the unit feels cloaked without heavy animation.
	var offset_a := sin(phase * 2.7) * size * 0.035
	var offset_b := sin(phase * 2.1 + 1.4) * size * 0.045
	enemy.draw_line(Vector2(-size * 0.42 + offset_a, -size * 0.31), Vector2(size * 0.30 + offset_a, -size * 0.31), cyan_glitch, 1.0)
	enemy.draw_line(Vector2(-size * 0.24 + offset_b, size * 0.17), Vector2(size * 0.44 + offset_b, size * 0.17), Color(0.80, 0.55, 1.00, alpha * 0.34), 1.0)

	# Split cloak fins / data shards on sides; helps distinguish from hunter darkness units.
	var left_fin := PackedVector2Array([
		Vector2(-size * 0.68, -size * 0.18),
		Vector2(-size * 0.94, size * 0.10),
		Vector2(-size * 0.58, size * 0.20),
	])
	var right_fin := PackedVector2Array([
		Vector2(size * 0.68, -size * 0.18),
		Vector2(size * 0.94, size * 0.10),
		Vector2(size * 0.58, size * 0.20),
	])
	enemy.draw_colored_polygon(left_fin, Color(0.20, 0.10, 0.34, alpha * 0.58))
	enemy.draw_colored_polygon(right_fin, Color(0.20, 0.10, 0.34, alpha * 0.58))
	enemy.draw_line(left_fin[0], left_fin[1], Color(0.58, 0.38, 1.00, alpha * 0.34), 1.0)
	enemy.draw_line(right_fin[0], right_fin[1], Color(0.58, 0.38, 1.00, alpha * 0.34), 1.0)

	# Ghost-code lens: small, premium focal point. No large aura.
	enemy.draw_circle(Vector2.ZERO, size * 0.25, Color(0.05, 0.02, 0.11, alpha * 0.96))
	enemy.draw_circle(Vector2.ZERO, size * (0.15 + shimmer * 0.018), ghost_core)
	enemy.draw_circle(Vector2(size * 0.045, -size * 0.045), size * 0.045, Color(1.0, 0.92, 1.0, alpha * 0.78))

	# Small stealth mask notch, readable in catalog and gameplay.
	enemy.draw_line(Vector2(-size * 0.15, -size * 0.03), Vector2(size * 0.15, -size * 0.03), Color(0.02, 0.01, 0.05, alpha * 0.85), 1.4)

	# Controlled cloak halo. Compact only; do not draw detection/range rings.
	enemy.draw_arc(Vector2.ZERO, size * 0.58, -0.55, 0.55, 10, Color(0.75, 0.55, 1.00, alpha * 0.22), 1.0)
	enemy.draw_arc(Vector2.ZERO, size * 0.58, PI - 0.55, PI + 0.55, 10, Color(0.75, 0.55, 1.00, alpha * 0.22), 1.0)


static func _stealth_alpha(enemy: Node2D, fallback: float) -> float:
	# enemy.gd may expose is_cloaked/is_stealthed/stealth_alpha depending on branch.
	# Use get() safely so this renderer stays visual-only and branch-tolerant.
	var direct_alpha = enemy.get("stealth_alpha")
	if typeof(direct_alpha) == TYPE_FLOAT or typeof(direct_alpha) == TYPE_INT:
		return clamp(float(direct_alpha), 0.35, fallback)

	var is_cloaked = enemy.get("is_cloaked")
	if typeof(is_cloaked) == TYPE_BOOL and bool(is_cloaked):
		return min(fallback, 0.58)

	var is_stealthed = enemy.get("is_stealthed")
	if typeof(is_stealthed) == TYPE_BOOL and bool(is_stealthed):
		return min(fallback, 0.58)

	return fallback
