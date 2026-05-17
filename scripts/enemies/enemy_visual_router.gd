## Routes _draw() calls to the correct per-type visual renderer.
## All draw_* calls go through the enemy Node2D (CanvasItem owner).
## No child nodes, particles, tweens, or timers are created here.

const _Basic        := preload("res://scripts/enemies/visuals/basic_enemy_visual.gd")
const _Fast         := preload("res://scripts/enemies/visuals/fast_enemy_visual.gd")
const _Tank         := preload("res://scripts/enemies/visuals/tank_enemy_visual.gd")
const _Bulwark      := preload("res://scripts/enemies/visuals/bulwark_enemy_visual.gd")
const _Hunter       := preload("res://scripts/enemies/visuals/hunter_enemy_visual.gd")
const _Swarm        := preload("res://scripts/enemies/visuals/swarm_enemy_visual.gd")
const _Runner       := preload("res://scripts/enemies/visuals/runner_enemy_visual.gd")
const _Shieldbearer := preload("res://scripts/enemies/visuals/shieldbearer_enemy_visual.gd")
const _Healer       := preload("res://scripts/enemies/visuals/healer_enemy_visual.gd")
const _Splitter     := preload("res://scripts/enemies/visuals/splitter_enemy_visual.gd")
const _Cloaked      := preload("res://scripts/enemies/visuals/cloaked_enemy_visual.gd")
const _Flyer        := preload("res://scripts/enemies/visuals/flyer_enemy_visual.gd")
const _FastFlyer    := preload("res://scripts/enemies/visuals/fast_flyer_enemy_visual.gd")
const _ArmoredFlyer := preload("res://scripts/enemies/visuals/armored_flyer_enemy_visual.gd")
const _Disruptor    := preload("res://scripts/enemies/visuals/disruptor_enemy_visual.gd")

static func draw_enemy(enemy: Node2D) -> void:
	const SIZE: float = 16.0
	var visual_type: String = str(enemy.get("visual_type"))
	var perf: bool = bool(enemy.get("PERFORMANCE_VISUAL_MODE"))

	if perf:
		_dispatch_simple(enemy, visual_type, SIZE)
		_draw_status_overlays_simple(enemy, SIZE)
		return

	_draw_air_shadow(enemy, visual_type, SIZE)
	_dispatch_full(enemy, visual_type, SIZE)
	_draw_status_overlays_full(enemy, SIZE)

# ── Simple-mode dispatch ─────────────────────────────────────────────────────────

static func _dispatch_simple(enemy: Node2D, vt: String, size: float) -> void:
	match vt:
		"basic":      _Basic.draw_simple(enemy, size)
		"fast":       _Fast.draw_simple(enemy, size)
		"tank":       _Tank.draw_simple(enemy, size)
		"bulwark":    _Bulwark.draw_simple(enemy, size)
		"hunter":     _Hunter.draw_simple(enemy, size)
		"swarm":      _Swarm.draw_simple(enemy, size)
		"runner":     _Runner.draw_simple(enemy, size)
		"shieldbearer": _Shieldbearer.draw_simple(enemy, size)
		"healer":     _Healer.draw_simple(enemy, size)
		"splitter":   _Splitter.draw_simple(enemy, size)
		"cloaked":    _Cloaked.draw_simple(enemy, size)
		"flyer":      _Flyer.draw_simple(enemy, size)
		"fast_flyer": _FastFlyer.draw_simple(enemy, size)
		"armored_flyer": _ArmoredFlyer.draw_simple(enemy, size)
		"disruptor":  _Disruptor.draw_simple(enemy, size)
		_:
			var fallback_pts := PackedVector2Array([Vector2(0,-size), Vector2(size*0.7,size*0.5), Vector2(-size*0.7,size*0.5)])
			enemy.draw_colored_polygon(fallback_pts, Color(0.8,0.8,0.8,0.85))
			enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

# ── Full-fidelity dispatch ───────────────────────────────────────────────────────

static func _dispatch_full(enemy: Node2D, vt: String, size: float) -> void:
	match vt:
		"basic":      _Basic.draw(enemy, size)
		"fast":       _Fast.draw(enemy, size)
		"tank":       _Tank.draw(enemy, size * 1.4)
		"bulwark":    _Bulwark.draw(enemy, size * 1.6)
		"hunter":     _Hunter.draw(enemy, size * 1.3)
		"swarm":      _Swarm.draw(enemy, size * 0.86)
		"runner":     _Runner.draw(enemy, size)
		"shieldbearer": _Shieldbearer.draw(enemy, size * 1.3)
		"healer":     _Healer.draw(enemy, size * 1.1)
		"splitter":   _Splitter.draw(enemy, size * 1.3)
		"cloaked":    _Cloaked.draw(enemy, size)
		"flyer":      _Flyer.draw(enemy, size)
		"fast_flyer": _FastFlyer.draw(enemy, size * 0.8)
		"armored_flyer": _ArmoredFlyer.draw(enemy, size * 1.5)
		"disruptor":  _Disruptor.draw(enemy, size * 1.2)

# ── Air-unit shadow/hover ring (non-swarm only) ──────────────────────────────────

static func _draw_air_shadow(enemy: Node2D, vt: String, size: float) -> void:
	const AIR_TYPES := ["flyer","fast_flyer","armored_flyer","disruptor"]
	if not vt in AIR_TYPES:
		return
	var pulse_time: float = float(enemy.get("pulse_time"))
	var hover_offset: float = sin(pulse_time*4.0)*2.0
	enemy.draw_circle(Vector2(0,12), size*0.75, Color(0,0,0,0.16))
	enemy.draw_arc(Vector2(0,hover_offset), size*1.15, 0, TAU, 28, Color(0.45,0.9,1.0,0.18), 1.2)

# ── Status overlays ───────────────────────────────────────────────────────────────

static func _draw_status_overlays_simple(enemy: Node2D, size: float) -> void:
	var shield: float = float(enemy.get("shield_remaining"))
	var slow: float   = float(enemy.get("active_slow_percent"))
	var flash: bool   = bool(enemy.get("is_flashing"))
	if shield > 0:
		enemy.draw_arc(Vector2.ZERO, size*1.4, 0, TAU, 12, Color(0.4,0.8,1.0,0.5), 1.5)
	if slow > 0:
		enemy.draw_circle(Vector2.ZERO, size*1.2, Color(0.6,0.9,1.0,0.2))
	if flash:
		enemy.draw_circle(Vector2.ZERO, size*1.5, Color(1,1,1,0.4))

static func _draw_status_overlays_full(enemy: Node2D, size: float) -> void:
	var shield: float    = float(enemy.get("shield_remaining"))
	var slow: float      = float(enemy.get("active_slow_percent"))
	var flash: bool      = bool(enemy.get("is_flashing"))
	var is_runner: bool  = bool(enemy.get("is_runner"))
	var is_hunter: bool  = bool(enemy.get("is_hunter"))
	var pulse_time: float = float(enemy.get("pulse_time"))

	if shield > 0:
		var p_pulse: float = sin(pulse_time*5.0)*0.1+0.9
		enemy.draw_arc(Vector2.ZERO, size*1.4*p_pulse, 0, TAU, 16, Color(0.4,0.8,1.0,0.4), 1.5)
		enemy.draw_circle(Vector2.ZERO, size*1.4, Color(0.4,0.8,1.0,0.08))
	if slow > 0:
		enemy.draw_circle(Vector2.ZERO, size*1.2, Color(0.6,0.9,1.0,0.25))
		enemy.draw_arc(Vector2.ZERO, size*1.1, 0, TAU, 24, Color(0.6,0.9,1.0,0.4), 2.0)
	if flash:
		enemy.draw_circle(Vector2.ZERO, size*1.5, Color(1,1,1,0.4))
		enemy.draw_arc(Vector2.ZERO, size*1.6, 0, TAU, 32, Color(1,1,1,0.6), 2.0)
