## Shared visual constants and helper functions for all enemy renderers.
## Pure-math helpers are fully static. Helpers that draw use enemy: Node2D so
## all draw_* calls route through the CanvasItem that owns the draw context.

# ── Shared colour constants (mirror enemy.gd; kept here to avoid circular loads) ──

const COLOR_BODY          := Color(0.08, 0.08, 0.12)
const COLOR_NEON_BASIC    := Color(0.2,  0.8,  1.0)
const COLOR_NEON_FAST     := Color(0.0,  1.0,  0.7)
const COLOR_NEON_TANK     := Color(1.0,  0.45, 0.1)
const COLOR_NEON_BULWARK  := Color(0.1,  0.6,  1.0)
const COLOR_NEON_HUNTER   := Color(1.0,  0.1,  0.4)

const SWARM_PANEL_COLOR    := Color(0.067, 0.094, 0.153, 1.0)
const SWARM_CORE_HIGHLIGHT := Color(0.224, 1.0,   0.478, 1.0)
const SWARM_TRAIL_COLOR    := Color(0.161, 0.475, 1.0,   1.0)
const SWARM_GLOW_LIGHT     := Color(0.718, 1.0,   0.961, 1.0)
const SWARM_ACCENT_AMBER   := Color(1.0,   0.54,  0.12,  1.0)
const SWARM_ACCENT_HOT     := Color(1.0,   0.82,  0.36,  1.0)
const SWARM_ACCENT_DEEP    := Color(1.0,   0.22,  0.08,  1.0)

const ENEMY_OUTLINE_COLOR     := Color(0.0, 0.0, 0.0, 0.74)
const ENEMY_OUTLINE_THICKNESS := 2.0

enum HealthVisualState { HEALTH_OK = 0, HEALTH_DAMAGED = 1, HEALTH_CRITICAL = 2 }

# ── Pure-math helpers ────────────────────────────────────────────────────────────

static var _scale_cache: Dictionary = {}  # hash(points + amount) -> PackedVector2Array

static func scale_polygon(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	# Cache result: polygons are computed from compile-time constants so the
	# same (points, amount) always yields the same output.
	var key: int = hash(str(amount) + str(points))
	if _scale_cache.has(key):
		return _scale_cache[key]
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in range(points.size()):
		var p: Vector2 = points[i]
		out[i] = p + p.normalized() * amount
	_scale_cache[key] = out
	return out

static func apply_health_tint(base_color: Color, health_visual_state: int) -> Color:
	match health_visual_state:
		HealthVisualState.HEALTH_DAMAGED:
			return base_color.lerp(Color(1.0, 0.45, 0.10, base_color.a), 0.34)
		HealthVisualState.HEALTH_CRITICAL:
			return base_color.lerp(Color(1.0, 0.08, 0.04, base_color.a), 0.55)
	return base_color

static func ellipse_points(center: Vector2, rx: float, ry: float, count: int = 28, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		var a: float = float(i) / float(count) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

# ── Drawing helpers (need enemy for draw_* calls and pulse_time access) ──────────

static func draw_glow_core(enemy: Node2D, pos: Vector2, radius: float, color: Color) -> void:
	var perf: bool = bool(enemy.get("PERFORMANCE_VISUAL_MODE"))
	if perf:
		enemy.draw_circle(pos, radius * 0.4, Color.WHITE)
		return
	var pulse_time: float = float(enemy.get("pulse_time"))
	var p: float = (sin(pulse_time * 8.0) * 0.5 + 0.5) * 0.2
	var r: float = radius * (1.0 + p)
	enemy.draw_circle(pos, r * 1.5, Color(color.r, color.g, color.b, 0.15))
	enemy.draw_circle(pos, r,       Color(color.r, color.g, color.b, 0.4))
	enemy.draw_circle(pos, r * 0.4, Color.WHITE)

static func draw_circuit_line(enemy: Node2D, p1: Vector2, p2: Vector2, color: Color, width: float = 1.0) -> void:
	var pulse_time: float = float(enemy.get("pulse_time"))
	var alpha: float = (sin(pulse_time * 12.0 + p1.x) * 0.5 + 0.5) * 0.4 + 0.1
	enemy.draw_line(p1, p2, Color(color.r, color.g, color.b, alpha), width)

static func draw_edge_nodes(enemy: Node2D, points: PackedVector2Array, color: Color, radius: float = 1.8) -> void:
	for p in points:
		enemy.draw_circle(p, radius + 1.0, Color(0.0, 0.0, 0.0, 0.45))
		enemy.draw_circle(p, radius,       Color(color.r, color.g, color.b, 0.78))

static func draw_orbiters(enemy: Node2D, count: int, orbit_radius: float, node_radius: float, color: Color, speed: float = 1.0) -> void:
	if bool(enemy.get("PERFORMANCE_VISUAL_MODE")):
		return
	var pulse_time: float = float(enemy.get("pulse_time"))
	for i in range(count):
		var a: float = float(i) / float(count) * TAU + pulse_time * speed
		var p: Vector2 = Vector2.RIGHT.rotated(a) * orbit_radius
		enemy.draw_circle(p, node_radius + 2.0, Color(color.r, color.g, color.b, 0.08))
		enemy.draw_circle(p, node_radius,        Color(color.r, color.g, color.b, 0.75))
		enemy.draw_line(p * 0.82, p * 1.06,     Color(color.r, color.g, color.b, 0.28), 1.0)

static func draw_inner_plate(enemy: Node2D, points: PackedVector2Array, color: Color, scale_factor: float = 0.66) -> void:
	var inner := PackedVector2Array()
	for p in points:
		inner.append(p * scale_factor)
	enemy.draw_polyline(inner + PackedVector2Array([inner[0]]), Color(color.r, color.g, color.b, 0.28), 1.0)

static func draw_shield_dome(enemy: Node2D, radius: float, color: Color) -> void:
	var perf: bool = bool(enemy.get("PERFORMANCE_VISUAL_MODE"))
	if perf:
		enemy.draw_arc(Vector2.ZERO, radius, 0, TAU, 12, Color(color.r, color.g, color.b, 0.5), 1.5)
		return
	var pulse_time: float = float(enemy.get("pulse_time"))
	var pulse: float = sin(pulse_time * 3.0) * 0.5 + 0.5
	var r_anim: float = radius * (0.98 + pulse * 0.04)
	enemy.draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.04 + pulse * 0.02))
	enemy.draw_arc(Vector2.ZERO, r_anim, 0, TAU, 64, Color(color.r, color.g, color.b, 0.2 + pulse * 0.1), 1.5)
	for i in range(6):
		var a: float = i * (TAU / 6.0) + pulse_time * 0.5
		var node_pos: Vector2 = Vector2(cos(a), sin(a)) * r_anim
		enemy.draw_circle(node_pos, 2.0, Color(color.r, color.g, color.b, 0.4))

static func draw_sequential_outline(enemy: Node2D, points: PackedVector2Array, phase: float, segment_ratio: float, color: Color, width: float = 1.0, closed: bool = true) -> void:
	if points.size() < 2:
		return
	var segment_count: int = points.size() if closed else points.size() - 1
	if segment_count <= 0:
		return
	var seg_lengths: Array = []
	var total_length: float = 0.0
	for i in range(segment_count):
		var seg_len: float = points[i].distance_to(points[(i + 1) % points.size()])
		seg_lengths.append(seg_len)
		total_length += seg_len
	if total_length <= 0.001:
		return
	var highlight_len: float = clampf(segment_ratio, 0.02, 1.0) * total_length
	var start_d: float = fposmod(phase, 1.0) * total_length
	var remaining: float = highlight_len
	var cursor: float = start_d
	while remaining > 0.0:
		var range_start: float = cursor
		var range_end: float = minf(total_length, cursor + remaining)
		var sampled := PackedVector2Array()
		var accum: float = 0.0
		for i in range(segment_count):
			var seg_start: float = accum
			var seg_end: float = accum + float(seg_lengths[i])
			if range_end > seg_start and range_start < seg_end and seg_end > seg_start:
				var denom: float = seg_end - seg_start
				var t1: float = clampf((maxf(range_start, seg_start) - seg_start) / denom, 0.0, 1.0)
				var t2: float = clampf((minf(range_end, seg_end) - seg_start) / denom, 0.0, 1.0)
				var p1: Vector2 = points[i].lerp(points[(i + 1) % points.size()], t1)
				var p2: Vector2 = points[i].lerp(points[(i + 1) % points.size()], t2)
				if sampled.is_empty() or sampled[sampled.size() - 1].distance_to(p1) > 0.01:
					sampled.append(p1)
				sampled.append(p2)
			accum = seg_end
		if sampled.size() >= 2:
			var seg_total: int = sampled.size() - 1
			for j in range(seg_total):
				var p0: Vector2 = sampled[j]
				var p1: Vector2 = sampled[j + 1]
				var raw_t: float = float(j) / float(max(seg_total - 1, 1))
				var t: float = raw_t * raw_t * (3.0 - 2.0 * raw_t)
				var tail_color := Color(color.r * 0.58, color.g * 0.58, color.b * 0.58, 1.0)
				var head_color := color.lerp(Color(0.92, 0.95, 1.0, 1.0), 0.18)
				var ramp_color := tail_color.lerp(head_color, t)
				enemy.draw_line(p0, p1, Color(ramp_color.r, ramp_color.g, ramp_color.b, color.a * (0.02 + 0.14 * t)), width * (2.0 + 0.1 * t), true)
				enemy.draw_line(p0, p1, Color(ramp_color.r, ramp_color.g, ramp_color.b, color.a * (0.06 + 0.26 * t)), width * (1.20 + 0.08 * t), true)
				enemy.draw_line(p0, p1, Color(ramp_color.r, ramp_color.g, ramp_color.b, color.a * (0.16 + 0.46 * t)), width * (0.62 + 0.06 * t), true)
			var head_pos: Vector2 = sampled[sampled.size() - 1]
			var head_glow: Color = color.lerp(Color(0.92, 0.95, 1.0, 1.0), 0.22)
			enemy.draw_circle(head_pos, width * 1.10, Color(head_glow.r, head_glow.g, head_glow.b, color.a * 0.18))
			enemy.draw_circle(head_pos, width * 0.60, Color(head_glow.r, head_glow.g, head_glow.b, color.a * 0.28))
		remaining -= (range_end - range_start)
		cursor = 0.0

static func draw_basic_segmented_leg(enemy: Node2D, hip: Vector2, knee: Vector2, foot: Vector2,
		base_color: Color, glow_color: Color, thickness: float,
		claw_size: float = 3.6, pulse_alpha: float = 1.0) -> void:
	var leg_dir: Vector2 = (foot - knee).normalized()
	var side: Vector2 = leg_dir.orthogonal().normalized()
	enemy.draw_circle(foot + Vector2(0.0, 1.8), claw_size * 1.45, Color(0.0, 0.0, 0.0, 0.22))
	enemy.draw_line(hip, knee, Color(0.0, 0.0, 0.0, 0.72), thickness + 3.4, true)
	enemy.draw_line(knee, foot, Color(0.0, 0.0, 0.0, 0.72), thickness + 3.0, true)
	enemy.draw_line(hip, knee, base_color, thickness, true)
	enemy.draw_line(knee, foot, base_color.darkened(0.05), thickness * 0.92, true)
	var cable_start: Vector2 = hip.lerp(knee, 0.22)
	var cable_mid: Vector2 = knee.lerp(foot, 0.38)
	enemy.draw_line(cable_start, cable_mid, Color(glow_color.r, glow_color.g, glow_color.b, 0.20 + 0.20 * pulse_alpha), 1.15, true)
	enemy.draw_circle(hip,  thickness * 0.58 + 1.6, Color(0.0, 0.0, 0.0, 0.68))
	enemy.draw_circle(knee, thickness * 0.52 + 1.3, Color(0.0, 0.0, 0.0, 0.68))
	enemy.draw_circle(hip,  thickness * 0.58, Color(0.20, 0.22, 0.28, 1.0))
	enemy.draw_circle(knee, thickness * 0.52, Color(0.16, 0.18, 0.23, 1.0))
	enemy.draw_circle(hip,  1.50 + pulse_alpha * 0.35, Color(glow_color.r, glow_color.g, glow_color.b, 0.72 + pulse_alpha * 0.22))
	enemy.draw_circle(knee, 1.25 + pulse_alpha * 0.28, Color(glow_color.r, glow_color.g, glow_color.b, 0.62 + pulse_alpha * 0.18))
	var plate_center: Vector2 = knee.lerp(foot, 0.52)
	var plate := PackedVector2Array([
		plate_center - leg_dir * claw_size * 0.85 + side * claw_size * 0.42,
		plate_center + leg_dir * claw_size * 0.62 + side * claw_size * 0.32,
		plate_center + leg_dir * claw_size * 0.82 - side * claw_size * 0.34,
		plate_center - leg_dir * claw_size * 0.68 - side * claw_size * 0.44
	])
	enemy.draw_colored_polygon(plate, Color(0.27, 0.29, 0.34, 1.0))
	enemy.draw_polyline(plate + PackedVector2Array([plate[0]]), Color(0.0, 0.0, 0.0, 0.62), 1.0)
	var claw := PackedVector2Array([
		foot + leg_dir * claw_size * 0.32,
		foot - leg_dir * claw_size * 1.08 + side * claw_size * 0.48,
		foot - leg_dir * claw_size * 1.08 - side * claw_size * 0.48
	])
	enemy.draw_colored_polygon(claw, Color(0.76, 0.80, 0.87, 1.0))
	enemy.draw_polyline(claw + PackedVector2Array([claw[0]]), Color(0.0, 0.0, 0.0, 0.70), 1.0)
	enemy.draw_line(foot, foot + leg_dir * claw_size * 0.52, Color(glow_color.r, glow_color.g, glow_color.b, 0.28 + pulse_alpha * 0.20), 1.0, true)

static func draw_basic_motion_streak(enemy: Node2D, start_pos: Vector2, end_pos: Vector2, color: Color, alpha: float, width: float = 1.0) -> void:
	enemy.draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, alpha), width, true)
	enemy.draw_circle(end_pos, width * 0.70, Color(color.r, color.g, color.b, alpha * 0.82))
