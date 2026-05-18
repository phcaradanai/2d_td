const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Fast Flyer / Interceptor
# State source: enemies.json
# - air / fast
# - armor_element: nature
# - role: high-speed aerial intruder / interceptor
# Design goals:
# - Premium cyber sci-fi interceptor silhouette
# - Reads faster and sharper than the standard Cyber Drone
# - Draw-only, no particles/timers/tweens/child nodes

const BODY_DARK := Color(0.035, 0.060, 0.070, 0.94)
const BODY_MID := Color(0.090, 0.170, 0.130, 0.94)
const ARMOR_NATURE := Color(0.330, 0.920, 0.360, 0.96)
const ARMOR_NATURE_DARK := Color(0.090, 0.360, 0.180, 0.96)
const ENERGY_LIME := Color(0.600, 1.000, 0.300, 0.95)
const ENERGY_CYAN := Color(0.240, 0.950, 0.860, 0.85)
const EDGE_DARK := Color(0.005, 0.014, 0.018, 0.92)
const SHADOW := Color(0.000, 0.000, 0.000, 0.22)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var s := size
	var alpha := _safe_alpha(enemy)

	# Small air shadow: cheap and immediately separates it from ground units.
	enemy.draw_circle(Vector2(0, s * 0.58), s * 0.38, Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW.a * alpha))

	var hull := PackedVector2Array([
		Vector2(0.00, -s * 0.72),
		Vector2(s * 0.54, -s * 0.08),
		Vector2(s * 0.25, s * 0.38),
		Vector2(0.00, s * 0.20),
		Vector2(-s * 0.25, s * 0.38),
		Vector2(-s * 0.54, -s * 0.08),
	])
	enemy.draw_colored_polygon(hull, Color(BODY_DARK.r, BODY_DARK.g, BODY_DARK.b, BODY_DARK.a * alpha))
	enemy.draw_polyline(_closed(hull), Color(EDGE_DARK.r, EDGE_DARK.g, EDGE_DARK.b, EDGE_DARK.a * alpha), 1.8)

	enemy.draw_line(Vector2(-s * 0.58, -s * 0.02), Vector2(-s * 1.02, s * 0.16), Color(ARMOR_NATURE.r, ARMOR_NATURE.g, ARMOR_NATURE.b, 0.70 * alpha), 2.0)
	enemy.draw_line(Vector2(s * 0.58, -s * 0.02), Vector2(s * 1.02, s * 0.16), Color(ARMOR_NATURE.r, ARMOR_NATURE.g, ARMOR_NATURE.b, 0.70 * alpha), 2.0)

	enemy.draw_circle(Vector2(0, -s * 0.12), s * 0.18, Color(ENERGY_LIME.r, ENERGY_LIME.g, ENERGY_LIME.b, 0.82 * alpha))
	enemy.draw_circle(Vector2(0, -s * 0.12), s * 0.08, Color(1.0, 1.0, 0.78, 0.86 * alpha))


static func draw(enemy: Node2D, size: float) -> void:
	var s := size
	var alpha := _safe_alpha(enemy)
	var t := Time.get_ticks_msec() * 0.001
	var pulse := 0.5 + 0.5 * sin(t * 5.2)
	var blink := 0.5 + 0.5 * sin(t * 9.0 + 0.8)

	# Lift shadow. One circle is cheaper and cleaner than hover particles.
	enemy.draw_circle(Vector2(0, s * 0.64), s * (0.34 + pulse * 0.035), Color(0, 0, 0, 0.18 * alpha))

	# Rear speed fins / short contrails. Small, compact, no particles.
	var trail_col := Color(ENERGY_LIME.r, ENERGY_LIME.g, ENERGY_LIME.b, (0.22 + pulse * 0.12) * alpha)
	enemy.draw_line(Vector2(-s * 0.18, s * 0.40), Vector2(-s * 0.52, s * 0.82), trail_col, 1.2)
	enemy.draw_line(Vector2(s * 0.18, s * 0.40), Vector2(s * 0.52, s * 0.82), trail_col, 1.2)
	enemy.draw_line(Vector2(0, s * 0.32), Vector2(0, s * 0.84), Color(ENERGY_CYAN.r, ENERGY_CYAN.g, ENERGY_CYAN.b, 0.12 * alpha), 1.0)

	# Main interceptor hull: sharp, forward-biased, very different from the rounder flyer.
	var hull := PackedVector2Array([
		Vector2(0.00, -s * 0.88),
		Vector2(s * 0.36, -s * 0.42),
		Vector2(s * 0.72, -s * 0.08),
		Vector2(s * 0.36, s * 0.34),
		Vector2(s * 0.12, s * 0.52),
		Vector2(0.00, s * 0.38),
		Vector2(-s * 0.12, s * 0.52),
		Vector2(-s * 0.36, s * 0.34),
		Vector2(-s * 0.72, -s * 0.08),
		Vector2(-s * 0.36, -s * 0.42),
	])
	enemy.draw_colored_polygon(hull, Color(BODY_DARK.r, BODY_DARK.g, BODY_DARK.b, BODY_DARK.a * alpha))
	enemy.draw_polyline(_closed(hull), Color(EDGE_DARK.r, EDGE_DARK.g, EDGE_DARK.b, EDGE_DARK.a * alpha), 2.2)

	# Nature armor plates. Kept large and readable instead of noisy micro-lines.
	var left_wing := PackedVector2Array([
		Vector2(-s * 0.34, -s * 0.35),
		Vector2(-s * 1.12, -s * 0.08),
		Vector2(-s * 0.72, s * 0.16),
		Vector2(-s * 0.28, s * 0.04),
	])
	var right_wing := PackedVector2Array([
		Vector2(s * 0.34, -s * 0.35),
		Vector2(s * 1.12, -s * 0.08),
		Vector2(s * 0.72, s * 0.16),
		Vector2(s * 0.28, s * 0.04),
	])
	enemy.draw_colored_polygon(left_wing, Color(ARMOR_NATURE_DARK.r, ARMOR_NATURE_DARK.g, ARMOR_NATURE_DARK.b, ARMOR_NATURE_DARK.a * alpha))
	enemy.draw_colored_polygon(right_wing, Color(ARMOR_NATURE_DARK.r, ARMOR_NATURE_DARK.g, ARMOR_NATURE_DARK.b, ARMOR_NATURE_DARK.a * alpha))
	enemy.draw_polyline(_closed(left_wing), Color(EDGE_DARK.r, EDGE_DARK.g, EDGE_DARK.b, 0.75 * alpha), 1.6)
	enemy.draw_polyline(_closed(right_wing), Color(EDGE_DARK.r, EDGE_DARK.g, EDGE_DARK.b, 0.75 * alpha), 1.6)

	# Bright leading edges: communicates speed without heavy VFX.
	var edge_col := Color(ARMOR_NATURE.r, ARMOR_NATURE.g, ARMOR_NATURE.b, (0.55 + blink * 0.18) * alpha)
	enemy.draw_line(Vector2(-s * 0.46, -s * 0.22), Vector2(-s * 0.98, -s * 0.06), edge_col, 1.4)
	enemy.draw_line(Vector2(s * 0.46, -s * 0.22), Vector2(s * 0.98, -s * 0.06), edge_col, 1.4)

	# Inner armored spine.
	var spine := PackedVector2Array([
		Vector2(0, -s * 0.66),
		Vector2(s * 0.20, -s * 0.22),
		Vector2(s * 0.16, s * 0.20),
		Vector2(0, s * 0.34),
		Vector2(-s * 0.16, s * 0.20),
		Vector2(-s * 0.20, -s * 0.22),
	])
	enemy.draw_colored_polygon(spine, Color(BODY_MID.r, BODY_MID.g, BODY_MID.b, BODY_MID.a * alpha))
	enemy.draw_polyline(_closed(spine), Color(ARMOR_NATURE.r, ARMOR_NATURE.g, ARMOR_NATURE.b, 0.44 * alpha), 1.2)

	# Nose sensor and speed core.
	enemy.draw_circle(Vector2(0, -s * 0.42), s * 0.18, Color(ENERGY_LIME.r, ENERGY_LIME.g, ENERGY_LIME.b, (0.35 + pulse * 0.18) * alpha))
	enemy.draw_circle(Vector2(0, -s * 0.42), s * 0.105, Color(ENERGY_LIME.r, ENERGY_LIME.g, ENERGY_LIME.b, 0.92 * alpha))
	enemy.draw_circle(Vector2(s * 0.035, -s * 0.465), s * 0.035, Color(1.0, 1.0, 0.80, 0.80 * alpha))

	# Tiny air-intake nodes, readable in catalog but still cheap.
	var node_col := Color(ENERGY_CYAN.r, ENERGY_CYAN.g, ENERGY_CYAN.b, 0.62 * alpha)
	enemy.draw_circle(Vector2(-s * 0.30, s * 0.10), s * 0.055, node_col)
	enemy.draw_circle(Vector2(s * 0.30, s * 0.10), s * 0.055, node_col)

	# Minimal interceptor chevron on tail.
	var chev_col := Color(ENERGY_LIME.r, ENERGY_LIME.g, ENERGY_LIME.b, 0.36 * alpha)
	enemy.draw_line(Vector2(-s * 0.14, s * 0.28), Vector2(0, s * 0.40), chev_col, 1.0)
	enemy.draw_line(Vector2(s * 0.14, s * 0.28), Vector2(0, s * 0.40), chev_col, 1.0)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out


static func _safe_alpha(enemy: Node2D) -> float:
	if "modulate" in enemy:
		return enemy.modulate.a
	return 1.0
