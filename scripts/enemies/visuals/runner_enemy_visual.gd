const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

# Cyber Runner — Nature armored sprint/infiltration unit.
# Visual-only renderer. Keep draw calls compact because runner waves can stack with other fast units.

const NATURE_ARMOR := Color(0.32, 0.92, 0.34, 1.0)
const NATURE_DARK  := Color(0.04, 0.20, 0.10, 1.0)
const NATURE_EDGE  := Color(0.72, 1.00, 0.36, 1.0)
const SIGNAL_CORE  := Color(0.62, 1.00, 0.82, 1.0)
const WARNING_ORANGE := Color(1.0, 0.48, 0.08, 1.0)


static func draw_simple(enemy: Node2D, size: float) -> void:
	var health_state := int(enemy.get("health_visual_state"))
	var armor := B.apply_health_tint(NATURE_ARMOR, health_state)
	var core := B.apply_health_tint(SIGNAL_CORE, health_state)
	var top := B.apply_health_tint(Color(0.84, 1.0, 0.36, 1.0), health_state)
	var side := Color(0.10, 0.30, 0.10, 0.98)
	var underside := Color(0.020, 0.070, 0.030, 0.98)

	# Faceted sprint wedge: readable as a thick ground hull after texture baking.
	var body := PackedVector2Array([
		Vector2(size * 0.95, 0.0),
		Vector2(size * 0.28, -size * 0.46),
		Vector2(-size * 0.72, -size * 0.30),
		Vector2(-size * 0.98, 0.0),
		Vector2(-size * 0.72, size * 0.30),
		Vector2(size * 0.28, size * 0.46),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, B.ENEMY_OUTLINE_THICKNESS), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, underside)
	enemy.draw_colored_polygon(PackedVector2Array([
		Vector2(size * 0.86, -size * 0.02),
		Vector2(size * 0.24, -size * 0.38),
		Vector2(-size * 0.70, -size * 0.24),
		Vector2(-size * 0.42, -size * 0.02),
		Vector2(size * 0.26, -size * 0.06),
	]), Color(top.r, top.g, top.b, 0.64))
	enemy.draw_colored_polygon(PackedVector2Array([
		Vector2(-size * 0.74, size * 0.08),
		Vector2(size * 0.28, size * 0.08),
		Vector2(size * 0.86, 0.0),
		Vector2(size * 0.18, size * 0.34),
		Vector2(-size * 0.72, size * 0.23),
	]), side)
	enemy.draw_colored_polygon(PackedVector2Array([
		Vector2(size * 0.24, -size * 0.08),
		Vector2(size * 0.94, 0.0),
		Vector2(size * 0.24, size * 0.18),
		Vector2(size * 0.02, 0.0),
	]), Color(armor.r, armor.g, armor.b, 0.96))
	enemy.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[0]]), Color(NATURE_EDGE.r, NATURE_EDGE.g, NATURE_EDGE.b, 0.72), 1.1, true)

	# One center line and one compact core preserve identity in performance mode.
	enemy.draw_line(Vector2(-size * 0.58, -size * 0.04), Vector2(size * 0.58, -size * 0.02), Color(NATURE_EDGE.r, NATURE_EDGE.g, NATURE_EDGE.b, 0.52), 1.0, true)
	enemy.draw_line(Vector2(-size * 0.58, size * 0.13), Vector2(size * 0.40, size * 0.10), Color(0.0, 0.0, 0.0, 0.52), 1.1, true)
	enemy.draw_circle(Vector2(size * 0.34, 0.0), size * 0.22, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2(size * 0.34, 0.0), size * 0.15, Color(core.r, core.g, core.b, 0.95))


static func draw(enemy: Node2D, size: float) -> void:
	var health_state := int(enemy.get("health_visual_state"))
	var pulse_time := float(enemy.get("pulse_time"))
	var pulse := 0.5 + sin(pulse_time * 8.5) * 0.5
	var stride := sin(pulse_time * 14.0) * size * 0.08

	var armor := B.apply_health_tint(NATURE_ARMOR, health_state)
	var edge := B.apply_health_tint(NATURE_EDGE, health_state)
	var core := B.apply_health_tint(SIGNAL_CORE, health_state)

	# Soft ground shadow: small and cheap, helps ground readability.
	enemy.draw_circle(Vector2(-size * 0.08, size * 0.58), size * 0.74, Color(0.0, 0.0, 0.0, 0.18))

	# Rear speed fins / compressed signal tail. Lines only, no particles.
	enemy.draw_line(Vector2(-size * 0.55, -size * 0.18), Vector2(-size * 1.55, -size * 0.34), Color(edge.r, edge.g, edge.b, 0.20), 2.0, true)
	enemy.draw_line(Vector2(-size * 0.55, size * 0.18), Vector2(-size * 1.55, size * 0.34), Color(edge.r, edge.g, edge.b, 0.20), 2.0, true)
	enemy.draw_line(Vector2(-size * 0.76, 0.0), Vector2(-size * 1.85, 0.0), Color(NATURE_ARMOR.r, NATURE_ARMOR.g, NATURE_ARMOR.b, 0.14), 3.0, true)

	# Long arrow-like shell: should read faster and sharper than Signal Runner.
	var body := PackedVector2Array([
		Vector2(size * 1.08, 0.0),
		Vector2(size * 0.48, -size * 0.42),
		Vector2(-size * 0.24, -size * 0.38),
		Vector2(-size * 0.92, -size * 0.16),
		Vector2(-size * 1.08, 0.0),
		Vector2(-size * 0.92, size * 0.16),
		Vector2(-size * 0.24, size * 0.38),
		Vector2(size * 0.48, size * 0.42),
	])
	enemy.draw_colored_polygon(B.scale_polygon(body, B.ENEMY_OUTLINE_THICKNESS + 0.75), B.ENEMY_OUTLINE_COLOR)
	enemy.draw_colored_polygon(body, Color(armor.r * 0.72, armor.g * 0.78, armor.b * 0.72, 0.96))

	# Top armor plates: few large readable panels, not noisy circuitry.
	var front_plate := PackedVector2Array([
		Vector2(size * 0.98, 0.0),
		Vector2(size * 0.42, -size * 0.25),
		Vector2(size * 0.08, 0.0),
		Vector2(size * 0.42, size * 0.25),
	])
	var rear_plate := PackedVector2Array([
		Vector2(-size * 0.05, -size * 0.25),
		Vector2(-size * 0.70, -size * 0.10),
		Vector2(-size * 0.82, 0.0),
		Vector2(-size * 0.70, size * 0.10),
		Vector2(-size * 0.05, size * 0.25),
		Vector2(size * 0.12, 0.0),
	])
	enemy.draw_colored_polygon(front_plate, Color(edge.r, edge.g, edge.b, 0.46))
	enemy.draw_colored_polygon(rear_plate, Color(0.08, 0.28, 0.13, 0.86))

	# Black center spine makes orientation obvious at small size.
	enemy.draw_line(Vector2(-size * 0.86, 0.0), Vector2(size * 0.82, 0.0), Color(0.0, 0.0, 0.0, 0.55), 2.0, true)
	enemy.draw_line(Vector2(-size * 0.60, 0.0), Vector2(size * 0.72, 0.0), Color(edge.r, edge.g, edge.b, 0.45 + pulse * 0.15), 1.0, true)

	# Two low sprint stabilizers show it is a ground unit, not a flyer.
	_draw_sprint_leg(enemy, Vector2(-size * 0.28, -size * 0.34), -1.0, size, stride, edge)
	_draw_sprint_leg(enemy, Vector2(-size * 0.28, size * 0.34), 1.0, size, -stride, edge)
	_draw_sprint_leg(enemy, Vector2(size * 0.34, -size * 0.31), -1.0, size * 0.82, -stride * 0.65, edge)
	_draw_sprint_leg(enemy, Vector2(size * 0.34, size * 0.31), 1.0, size * 0.82, stride * 0.65, edge)

	# Compact forward core / sensor. Runner is fast, so core is small and aggressive.
	enemy.draw_circle(Vector2(size * 0.44, 0.0), size * 0.26, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2(size * 0.44, 0.0), size * 0.19, Color(core.r, core.g, core.b, 0.88))
	enemy.draw_circle(Vector2(size * 0.50, -size * 0.05), size * (0.055 + pulse * 0.018), Color(1.0, 1.0, 0.82, 0.70))

	# Small dash readiness telegraph from gameplay state. Kept compact; no big aura radius.
	_draw_runner_role_telegraph(enemy, size, pulse)


static func _draw_sprint_leg(enemy: Node2D, root: Vector2, side: float, size: float, stride: float, edge: Color) -> void:
	var joint := root + Vector2(-size * 0.14 + stride, side * size * 0.24)
	var foot := joint + Vector2(-size * 0.24, side * size * 0.14)
	enemy.draw_line(root, joint, B.ENEMY_OUTLINE_COLOR, 2.3, true)
	enemy.draw_line(joint, foot, B.ENEMY_OUTLINE_COLOR, 2.1, true)
	enemy.draw_line(root, joint, Color(edge.r, edge.g, edge.b, 0.50), 1.0, true)
	enemy.draw_line(joint, foot, Color(0.12, 0.38, 0.14, 0.70), 0.9, true)


static func _draw_runner_role_telegraph(enemy: Node2D, size: float, pulse: float) -> void:
	var dash_cooldown := float(enemy.get("runner_dash_cooldown"))
	var dash_timer := float(enemy.get("runner_dash_timer"))
	var dash_remaining := float(enemy.get("runner_dash_remaining"))
	var panic_active := bool(enemy.get("runner_panic_active"))

	var dash_charge := 1.0 - clampf(dash_timer / maxf(dash_cooldown, 0.01), 0.0, 1.0)

	# Small top chevron = dash charge, much cheaper/readable than a large aura.
	if dash_charge > 0.08:
		var alpha := 0.10 + dash_charge * 0.32
		var y := -size * (0.58 + dash_charge * 0.10)
		enemy.draw_line(Vector2(-size * 0.30, y), Vector2(size * 0.05, y - size * 0.12), Color(NATURE_EDGE.r, NATURE_EDGE.g, NATURE_EDGE.b, alpha), 1.2, true)
		enemy.draw_line(Vector2(size * 0.05, y - size * 0.12), Vector2(size * 0.40, y), Color(NATURE_EDGE.r, NATURE_EDGE.g, NATURE_EDGE.b, alpha), 1.2, true)

	if dash_remaining > 0.0:
		var dash_alpha := 0.20 + pulse * 0.16
		enemy.draw_line(Vector2(-size * 0.70, 0.0), Vector2(-size * 2.25, 0.0), Color(NATURE_EDGE.r, NATURE_EDGE.g, NATURE_EDGE.b, dash_alpha), 3.0, true)
		enemy.draw_line(Vector2(-size * 0.52, -size * 0.24), Vector2(-size * 1.72, -size * 0.52), Color(0.82, 1.0, 0.34, dash_alpha * 0.55), 1.2, true)
		enemy.draw_line(Vector2(-size * 0.52, size * 0.24), Vector2(-size * 1.72, size * 0.52), Color(0.82, 1.0, 0.34, dash_alpha * 0.55), 1.2, true)

	if panic_active:
		enemy.draw_arc(Vector2.ZERO, size * (1.02 + pulse * 0.08), -PI * 0.78, PI * 0.78, 24, Color(WARNING_ORANGE.r, WARNING_ORANGE.g, WARNING_ORANGE.b, 0.20 + pulse * 0.06), 1.2, true)
		enemy.draw_circle(Vector2(size * 0.58, 0.0), size * (0.11 + pulse * 0.035), Color(1.0, 0.86, 0.36, 0.72))
