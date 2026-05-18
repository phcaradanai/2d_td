const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Bulwark Alpha — heavy frontline shield generator.
# Visual-only renderer. Keep this file draw-based: no nodes, timers, tweens, or gameplay mutation.

const BODY_DARK := Color(0.08, 0.075, 0.065, 1.0)
const ARMOR_BASE := Color(0.52, 0.46, 0.32, 1.0)
const ARMOR_WARM := Color(0.78, 0.68, 0.38, 1.0)
const LIGHT_CORE := Color(1.0, 0.92, 0.54, 1.0)
const LIGHT_GLOW := Color(1.0, 0.86, 0.34, 0.38)
const SHIELD_SOFT := Color(0.95, 0.92, 0.62, 0.20)
const TRIM_DARK := Color(0.015, 0.018, 0.018, 0.92)


static func _tint(enemy: Node2D, color: Color) -> Color:
	return B.apply_health_tint(color, int(enemy.get("health_visual_state")))


static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p)
	return out


static func _scaled(points: PackedVector2Array, scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * scale)
	return out


static func _ellipse_points(rx: float, ry: float, count: int = 18, y_offset: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry + y_offset))
	return pts


static func _draw_plate(enemy: Node2D, pts: PackedVector2Array, fill: Color, trim: Color = TRIM_DARK) -> void:
	enemy.draw_colored_polygon(_scaled(pts, 1.08), trim)
	enemy.draw_colored_polygon(pts, fill)


static func _draw_light_core(enemy: Node2D, pos: Vector2, radius: float) -> void:
	enemy.draw_circle(pos, radius * 1.55, LIGHT_GLOW)
	enemy.draw_circle(pos, radius * 1.03, TRIM_DARK)
	enemy.draw_circle(pos, radius * 0.72, LIGHT_CORE)
	enemy.draw_circle(pos + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.22, Color(1, 1, 0.86, 0.95))


static func draw_simple(enemy: Node2D, size: float, color: Color = B.COLOR_NEON_BULWARK) -> void:
	var armor := _tint(enemy, ARMOR_BASE)
	var body := _poly([
		Vector2(-size * 1.02, -size * 0.62),
		Vector2(-size * 0.54, -size * 0.94),
		Vector2( size * 0.54, -size * 0.94),
		Vector2( size * 1.02, -size * 0.62),
		Vector2( size * 1.02,  size * 0.62),
		Vector2( size * 0.54,  size * 0.94),
		Vector2(-size * 0.54,  size * 0.94),
		Vector2(-size * 1.02,  size * 0.62),
	])

	enemy.draw_colored_polygon(_scaled(body, 1.1), TRIM_DARK)
	enemy.draw_colored_polygon(body, armor)

	# Cheap shield identity: compact halo, not the full gameplay aura radius.
	enemy.draw_arc(Vector2.ZERO, size * 1.18, -PI * 0.88, PI * 0.88, 18, Color(color.r, color.g, color.b, 0.38), 2.0)
	enemy.draw_line(Vector2(-size * 0.58, -size * 0.52), Vector2(-size * 0.58, size * 0.52), TRIM_DARK, 2.0)
	enemy.draw_line(Vector2( size * 0.58, -size * 0.52), Vector2( size * 0.58, size * 0.52), TRIM_DARK, 2.0)
	_draw_light_core(enemy, Vector2.ZERO, size * 0.24)


static func draw(enemy: Node2D, size: float, color: Color = B.COLOR_NEON_BULWARK) -> void:
	var pulse := 0.5 + 0.5 * sin(float(enemy.get("animation_time")) * 2.2)
	var armor := _tint(enemy, ARMOR_BASE)
	var warm := _tint(enemy, ARMOR_WARM)

	# Grounded compact shadow: helps this read as a slow frontline land unit.
	enemy.draw_colored_polygon(_ellipse_points(size * 1.18, size * 0.25, 18, size * 0.42), Color(0, 0, 0, 0.22))

	# Heavy generator chassis: broad octagonal shell, thicker than Basic/Tank center.
	var hull := _poly([
		Vector2(-size * 1.18, -size * 0.58),
		Vector2(-size * 0.74, -size * 0.96),
		Vector2( size * 0.74, -size * 0.96),
		Vector2( size * 1.18, -size * 0.58),
		Vector2( size * 1.18,  size * 0.58),
		Vector2( size * 0.74,  size * 0.96),
		Vector2(-size * 0.74,  size * 0.96),
		Vector2(-size * 1.18,  size * 0.58),
	])
	_draw_plate(enemy, hull, armor)

	# Side shield emitters. Big, readable modules instead of noisy micro detail.
	var left_emitter := _poly([
		Vector2(-size * 1.18, -size * 0.42),
		Vector2(-size * 0.82, -size * 0.66),
		Vector2(-size * 0.58, -size * 0.40),
		Vector2(-size * 0.58,  size * 0.40),
		Vector2(-size * 0.82,  size * 0.66),
		Vector2(-size * 1.18,  size * 0.42),
	])
	var right_emitter := _poly([
		Vector2(size * 1.18, -size * 0.42),
		Vector2(size * 0.82, -size * 0.66),
		Vector2(size * 0.58, -size * 0.40),
		Vector2(size * 0.58,  size * 0.40),
		Vector2(size * 0.82,  size * 0.66),
		Vector2(size * 1.18,  size * 0.42),
	])
	_draw_plate(enemy, left_emitter, warm)
	_draw_plate(enemy, right_emitter, warm)

	# Inner reactor cradle.
	var cradle := _poly([
		Vector2(-size * 0.48, -size * 0.56),
		Vector2( size * 0.48, -size * 0.56),
		Vector2( size * 0.70, -size * 0.20),
		Vector2( size * 0.70,  size * 0.20),
		Vector2( size * 0.48,  size * 0.56),
		Vector2(-size * 0.48,  size * 0.56),
		Vector2(-size * 0.70,  size * 0.20),
		Vector2(-size * 0.70, -size * 0.20),
	])
	_draw_plate(enemy, cradle, Color(0.12, 0.12, 0.10, 1.0))

	# Compact shield halo: communicates aura role without drawing the full expensive area.
	var halo_alpha := 0.16 + pulse * 0.08
	enemy.draw_arc(Vector2.ZERO, size * 1.42, -PI * 0.82, PI * 0.82, 24, Color(color.r, color.g, color.b, halo_alpha), 2.6)
	enemy.draw_arc(Vector2.ZERO, size * 1.16, -PI * 0.78, PI * 0.78, 18, Color(1.0, 0.95, 0.58, 0.13 + pulse * 0.05), 1.6)

	# Shield-anchor struts.
	enemy.draw_line(Vector2(-size * 0.72, -size * 0.46), Vector2(-size * 1.03, -size * 0.14), TRIM_DARK, 2.4)
	enemy.draw_line(Vector2(-size * 0.72,  size * 0.46), Vector2(-size * 1.03,  size * 0.14), TRIM_DARK, 2.4)
	enemy.draw_line(Vector2( size * 0.72, -size * 0.46), Vector2( size * 1.03, -size * 0.14), TRIM_DARK, 2.4)
	enemy.draw_line(Vector2( size * 0.72,  size * 0.46), Vector2( size * 1.03,  size * 0.14), TRIM_DARK, 2.4)

	# Minimal circuit seams: only major lines, no dense micro-noise.
	enemy.draw_line(Vector2(-size * 0.40, -size * 0.56), Vector2(-size * 0.18, -size * 0.20), Color(color.r, color.g, color.b, 0.38), 1.4)
	enemy.draw_line(Vector2( size * 0.40, -size * 0.56), Vector2( size * 0.18, -size * 0.20), Color(color.r, color.g, color.b, 0.38), 1.4)
	enemy.draw_line(Vector2(-size * 0.40,  size * 0.56), Vector2(-size * 0.18,  size * 0.20), Color(color.r, color.g, color.b, 0.34), 1.4)
	enemy.draw_line(Vector2( size * 0.40,  size * 0.56), Vector2( size * 0.18,  size * 0.20), Color(color.r, color.g, color.b, 0.34), 1.4)

	# Reactor + two emitter lenses.
	_draw_light_core(enemy, Vector2.ZERO, size * 0.30)
	enemy.draw_circle(Vector2(-size * 0.88, 0), size * 0.12, Color(color.r, color.g, color.b, 0.60))
	enemy.draw_circle(Vector2( size * 0.88, 0), size * 0.12, Color(color.r, color.g, color.b, 0.60))

	# Heavy lower armor lip for stronger frontline silhouette.
	enemy.draw_line(Vector2(-size * 0.82, size * 0.78), Vector2(size * 0.82, size * 0.78), TRIM_DARK, 3.0)
	enemy.draw_line(Vector2(-size * 0.55, -size * 0.80), Vector2(size * 0.55, -size * 0.80), Color(1.0, 0.91, 0.52, 0.32), 1.5)
