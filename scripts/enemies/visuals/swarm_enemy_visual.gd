const B := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	var color: Color = B.apply_health_tint(B.COLOR_NEON_FAST, int(enemy.get("health_visual_state")))
	enemy.draw_circle(Vector2(-size*0.5,-size*0.3), size*0.4+B.ENEMY_OUTLINE_THICKNESS, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2( size*0.5,-size*0.3), size*0.4+B.ENEMY_OUTLINE_THICKNESS, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2(0, size*0.4),          size*0.4+B.ENEMY_OUTLINE_THICKNESS, B.ENEMY_OUTLINE_COLOR)
	enemy.draw_circle(Vector2(-size*0.5,-size*0.3), size*0.4, Color(color.r,color.g,color.b,0.8))
	enemy.draw_circle(Vector2( size*0.5,-size*0.3), size*0.4, Color(color.r,color.g,color.b,0.8))
	enemy.draw_circle(Vector2(0, size*0.4),          size*0.4, Color(color.r,color.g,color.b,0.8))

static func draw(enemy: Node2D, size: float) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var phase: float = float(enemy.get_instance_id() % 97) * 0.071
	var pulse: float = 0.5 + sin(pulse_time*7.4+phase)*0.5
	var bob: float   = sin(pulse_time*7.0+phase)*size*0.08
	var flicker_raw: float = clampf(0.92+sin(pulse_time*18.5+phase*2.3)*0.16, 0.72, 1.45)
	var swarm_core_flicker_time: float = float(enemy.get("swarm_core_flicker_time"))
	var flicker: float = clampf(flicker_raw + swarm_core_flicker_time*0.8, 0.72, 1.45)
	var swarm_core_glow_color: Color = enemy.get("swarm_core_glow_color")
	var core_color: Color = swarm_core_glow_color.lerp(B.SWARM_CORE_HIGHLIGHT, 0.46+pulse*0.36)
	var origin := Vector2(0.0, bob)

	_draw_hover_fx(enemy, origin, size, pulse, swarm_core_glow_color)
	_draw_thruster_fx(enemy, origin, size, pulse, flicker)
	_draw_forward_motion_fx(enemy, origin, size, pulse, flicker, swarm_core_glow_color)
	_draw_body_layers(enemy, origin, size*0.98, flicker, swarm_core_glow_color)
	_draw_core_layers(enemy, origin+Vector2(size*0.04,0), size*0.82, core_color, pulse, flicker)

	var orbit_count: int = 4 + int(enemy.get_instance_id() % 2)
	for i in range(orbit_count):
		var t: float = float(i) / maxf(1.0, float(orbit_count-1))
		var ring_phase: float = phase + float(i)*TAU/float(orbit_count)
		var orbit_a: float  = pulse_time*(2.45+float(i)*0.18)+ring_phase
		var orbit_r: float  = size*lerpf(1.10,1.58,t)+sin(pulse_time*5.8+ring_phase*1.7)*size*0.06
		var squash: Vector2 = Vector2(1.0, lerpf(0.62,0.82,t))
		var local_off := Vector2(sin(pulse_time*1.7+float(i)*1.13)*size*0.08,
			cos(pulse_time*2.1+float(i)*0.91)*size*0.06)
		var orbit_pos: Vector2 = origin+Vector2(cos(orbit_a),sin(orbit_a))*orbit_r*squash+local_off
		var orb_alpha_mul: float = lerpf(0.58,1.0,1.0-t)
		var orb_flicker: float = clampf(flicker*(0.78+pulse*0.18+float(i)*0.03),0.60,1.35)*orb_alpha_mul
		_draw_swarm_orbiter(enemy, orbit_pos, size*lerpf(0.34,0.48,1.0-t), orb_flicker, swarm_core_glow_color)
		enemy.draw_line(origin, orbit_pos,
			Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.10*orb_alpha_mul), 1.0)

# ── Sub-helpers ───────────────────────────────────────────────────────────────────

static func _draw_swarm_orbiter(enemy: Node2D, origin: Vector2, size: float, flicker: float, swarm_core_glow_color: Color) -> void:
	_draw_body_layers(enemy, origin, size, flicker, swarm_core_glow_color)
	var orb_core: Color = swarm_core_glow_color.lerp(B.SWARM_GLOW_LIGHT, 0.42)
	_draw_core_layers(enemy, origin+Vector2(size*0.08,-size*0.02), size*0.52, orb_core, 0.55, flicker)

static func _draw_hover_fx(enemy: Node2D, origin: Vector2, size: float, pulse: float, swarm_core_glow_color: Color) -> void:
	var shadow_pos := origin+Vector2(-size*0.16, size*0.90)
	enemy.draw_circle(shadow_pos, size*(0.72+pulse*0.03), Color(0,0,0,0.10+pulse*0.03))
	enemy.draw_arc(origin+Vector2(-size*0.04,size*0.36), size*(0.68+pulse*0.03), PI*0.16, PI*0.84, 18,
		Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.10+pulse*0.03), 1.0)

static func _draw_body_layers(enemy: Node2D, origin: Vector2, size: float, flicker: float, swarm_core_glow_color: Color) -> void:
	var skew_y: float = size*0.05
	var swarm_body_color: Color = enemy.get("swarm_body_color")
	var outer := PackedVector2Array([
		origin+Vector2(size*1.42,0),          origin+Vector2(size*0.76,-size*0.34),
		origin+Vector2(-size*0.18,-size*0.76+skew_y), origin+Vector2(-size*0.94,-size*0.54+skew_y),
		origin+Vector2(-size*0.58,skew_y*0.75),       origin+Vector2(-size*0.94, size*0.54+skew_y),
		origin+Vector2(-size*0.18, size*0.76+skew_y), origin+Vector2(size*0.76, size*0.34)])
	var inner := PackedVector2Array([
		origin+Vector2(size*0.86,0),           origin+Vector2(size*0.24,-size*0.22),
		origin+Vector2(-size*0.20,-size*0.48+skew_y*0.85), origin+Vector2(-size*0.42,skew_y*0.6),
		origin+Vector2(-size*0.20, size*0.48+skew_y*0.85), origin+Vector2(size*0.24, size*0.22)])
	var under_plate := PackedVector2Array([
		origin+Vector2(size*0.38, size*0.14+skew_y*0.55), origin+Vector2(-size*0.16,size*0.08+skew_y*0.72),
		origin+Vector2(-size*0.02,size*0.42+skew_y*0.9),  origin+Vector2(size*0.28, size*0.34+skew_y*0.78)])
	var top_fin := PackedVector2Array([
		origin+Vector2(-size*0.34,-size*0.34+skew_y*0.55), origin+Vector2(-size*1.18,-size*0.98+skew_y),
		origin+Vector2(-size*0.92,-size*0.14+skew_y*0.8),  origin+Vector2(-size*0.48,-size*0.06+skew_y*0.65)])
	var bot_fin := PackedVector2Array([
		origin+Vector2(-size*0.34, size*0.34+skew_y*0.55), origin+Vector2(-size*1.18, size*0.98+skew_y),
		origin+Vector2(-size*0.92, size*0.14+skew_y*0.8),  origin+Vector2(-size*0.48, size*0.06+skew_y*0.65)])
	var sensor := PackedVector2Array([
		origin+Vector2(size*1.04,0), origin+Vector2(size*0.82,-size*0.15), origin+Vector2(size*0.82,size*0.15)])
	enemy.draw_colored_polygon(top_fin, B.SWARM_PANEL_COLOR)
	enemy.draw_colored_polygon(bot_fin, B.SWARM_PANEL_COLOR)
	enemy.draw_colored_polygon(outer, swarm_body_color)
	enemy.draw_colored_polygon(inner, B.SWARM_PANEL_COLOR)
	enemy.draw_colored_polygon(under_plate, Color(B.SWARM_PANEL_COLOR.r,B.SWARM_PANEL_COLOR.g,B.SWARM_PANEL_COLOR.b,0.8))
	enemy.draw_colored_polygon(sensor, Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.86*flicker))
	enemy.draw_polyline(outer+PackedVector2Array([outer[0]]), Color(B.SWARM_TRAIL_COLOR.r,B.SWARM_TRAIL_COLOR.g,B.SWARM_TRAIL_COLOR.b,0.9), 1.35)
	enemy.draw_polyline(top_fin+PackedVector2Array([top_fin[0]]), Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.52*flicker), 1.0)
	enemy.draw_polyline(bot_fin+PackedVector2Array([bot_fin[0]]), Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.52*flicker), 1.0)
	enemy.draw_line(origin+Vector2(-size*0.98,-size*0.72+skew_y), origin+Vector2(-size*0.74,-size*0.30+skew_y),
		Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.98*flicker), 1.25)
	enemy.draw_line(origin+Vector2(-size*0.98, size*0.72+skew_y), origin+Vector2(-size*0.74, size*0.30+skew_y),
		Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.98*flicker), 1.25)
	enemy.draw_line(origin+Vector2(size*0.60,-size*0.04), origin+Vector2(-size*0.04,-size*0.24+skew_y*0.72),
		Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.88*flicker), 1.15)
	enemy.draw_line(origin+Vector2(size*0.60, size*0.04), origin+Vector2(-size*0.04, size*0.24+skew_y*0.72),
		Color(B.SWARM_TRAIL_COLOR.r,B.SWARM_TRAIL_COLOR.g,B.SWARM_TRAIL_COLOR.b,0.78*flicker), 1.15)
	enemy.draw_circle(origin+Vector2(-size*0.60,-size*0.20), size*0.055, Color(B.SWARM_ACCENT_HOT.r,B.SWARM_ACCENT_HOT.g,B.SWARM_ACCENT_HOT.b,0.86*flicker))
	enemy.draw_circle(origin+Vector2(-size*0.68,0),          size*0.065, Color(B.SWARM_ACCENT_HOT.r,B.SWARM_ACCENT_HOT.g,B.SWARM_ACCENT_HOT.b,0.92*flicker))
	enemy.draw_circle(origin+Vector2(-size*0.60, size*0.20), size*0.055, Color(B.SWARM_ACCENT_HOT.r,B.SWARM_ACCENT_HOT.g,B.SWARM_ACCENT_HOT.b,0.86*flicker))

static func _draw_core_layers(enemy: Node2D, origin: Vector2, size: float, core_color: Color, pulse: float, flicker: float) -> void:
	var glow_core := PackedVector2Array()
	var core      := PackedVector2Array()
	var hot_core  := PackedVector2Array()
	var radius_glow: float = size*(0.68+pulse*0.12)
	for i in range(6):
		var a: float = PI/6.0 + float(i)*TAU/6.0
		var dir := Vector2(cos(a),sin(a))
		glow_core.append(origin+dir*radius_glow)
		core.append(origin+dir*size*0.34)
		hot_core.append(origin+dir*size*(0.17+pulse*0.03))
	enemy.draw_colored_polygon(glow_core, Color(core_color.r,core_color.g,core_color.b,0.34*flicker))
	enemy.draw_colored_polygon(core,      Color(core_color.r,core_color.g,core_color.b,0.98*flicker))
	enemy.draw_polyline(core+PackedVector2Array([core[0]]), Color(B.SWARM_GLOW_LIGHT.r,B.SWARM_GLOW_LIGHT.g,B.SWARM_GLOW_LIGHT.b,1.0*flicker), 1.45)
	enemy.draw_colored_polygon(hot_core, Color(B.SWARM_GLOW_LIGHT.r,B.SWARM_GLOW_LIGHT.g,B.SWARM_GLOW_LIGHT.b,1.0*flicker))

static func _draw_forward_motion_fx(enemy: Node2D, origin: Vector2, size: float, pulse: float, flicker: float, swarm_core_glow_color: Color) -> void:
	var nose := origin+Vector2(size*1.20,0)
	enemy.draw_arc(nose+Vector2(size*(0.30+pulse*0.05),0), size*(0.36+pulse*0.06), -0.58, 0.58, 18,
		Color(B.SWARM_GLOW_LIGHT.r,B.SWARM_GLOW_LIGHT.g,B.SWARM_GLOW_LIGHT.b,0.28*flicker), 1.25)
	enemy.draw_arc(nose+Vector2(size*(0.48+pulse*0.06),0), size*(0.58+pulse*0.04), -0.42, 0.42, 16,
		Color(swarm_core_glow_color.r,swarm_core_glow_color.g,swarm_core_glow_color.b,0.13*flicker), 1.0)
	var slash_color := Color(B.SWARM_GLOW_LIGHT.r,B.SWARM_GLOW_LIGHT.g,B.SWARM_GLOW_LIGHT.b,0.46*flicker)
	enemy.draw_polyline(PackedVector2Array([nose+Vector2(size*0.04,-size*0.30), nose+Vector2(size*0.42,-size*0.10), nose+Vector2(size*0.14,-size*0.01)]), slash_color, 1.1)
	enemy.draw_polyline(PackedVector2Array([nose+Vector2(size*0.04, size*0.30), nose+Vector2(size*0.42, size*0.10), nose+Vector2(size*0.14, size*0.01)]), slash_color, 1.1)

static func _draw_thruster_fx(enemy: Node2D, origin: Vector2, size: float, pulse: float, flicker: float) -> void:
	var plume_len: float = size*(1.18+pulse*0.24)
	var plume_w: float   = size*(0.20+pulse*0.04)
	var rear_ports: Array = [
		origin+Vector2(-size*0.62,-size*0.22),
		origin+Vector2(-size*0.72, 0.0),
		origin+Vector2(-size*0.62, size*0.22)
	]
	for i in range(rear_ports.size()):
		var port: Vector2 = rear_ports[i]
		var center_boost: float = 1.18 if i==1 else 1.0
		var spread: float = plume_w*(0.86 if i==1 else 0.72)
		var length: float = plume_len*center_boost
		var outer_plume := PackedVector2Array([
			port+Vector2(0,-spread), port+Vector2(-length,-spread*0.36),
			port+Vector2(-length*1.12,0), port+Vector2(-length,spread*0.36), port+Vector2(0,spread)])
		var inner_plume := PackedVector2Array([
			port+Vector2(-size*0.03,-spread*0.44), port+Vector2(-length*0.68,-spread*0.18),
			port+Vector2(-length*0.82,0), port+Vector2(-length*0.68,spread*0.18), port+Vector2(-size*0.03,spread*0.44)])
		var hot_core := PackedVector2Array([
			port+Vector2(-size*0.22,-spread*0.18), port+Vector2(-length*1.42,0.18), port+Vector2(-size*0.22,spread*0.18)])
		enemy.draw_colored_polygon(outer_plume, Color(B.SWARM_TRAIL_COLOR.r,B.SWARM_TRAIL_COLOR.g,B.SWARM_TRAIL_COLOR.b,0.16+pulse*0.05))
		enemy.draw_colored_polygon(inner_plume, Color(B.SWARM_ACCENT_AMBER.r,B.SWARM_ACCENT_AMBER.g,B.SWARM_ACCENT_AMBER.b,0.18+pulse*0.08))
		enemy.draw_colored_polygon(hot_core,    Color(B.SWARM_ACCENT_HOT.r,B.SWARM_ACCENT_HOT.g,B.SWARM_ACCENT_HOT.b,0.34+pulse*0.14))
		enemy.draw_circle(port, size*0.095, Color(B.SWARM_GLOW_LIGHT.r,B.SWARM_GLOW_LIGHT.g,B.SWARM_GLOW_LIGHT.b,0.9*flicker))
		enemy.draw_circle(port+Vector2(-size*0.04,0), size*0.17, Color(B.SWARM_ACCENT_AMBER.r,B.SWARM_ACCENT_AMBER.g,B.SWARM_ACCENT_AMBER.b,0.20*flicker))
