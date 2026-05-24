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
	var bs := _boss_scale(enemy)
	var s := size * (bs if bs > 1.0 else 1.0)
	match vt:
		"basic":      _Basic.draw_simple(enemy, s)
		"fast":       _Fast.draw_simple(enemy, s)
		"tank":       _Tank.draw_simple(enemy, s)
		"bulwark":    _Bulwark.draw_simple(enemy, s)
		"hunter":     _Hunter.draw_simple(enemy, s)
		"swarm":      _Swarm.draw_simple(enemy, s)
		"runner":     _Runner.draw_simple(enemy, s)
		"shieldbearer": _Shieldbearer.draw_simple(enemy, s)
		"healer":     _Healer.draw_simple(enemy, s)
		"splitter":   _Splitter.draw_simple(enemy, s)
		"cloaked":    _Cloaked.draw_simple(enemy, s)
		"flyer":      _Flyer.draw_simple(enemy, s)
		"fast_flyer": _FastFlyer.draw_simple(enemy, s)
		"armored_flyer": _ArmoredFlyer.draw_simple(enemy, s)
		"disruptor":  _Disruptor.draw_simple(enemy, s)
		_:
			var fallback_pts := PackedVector2Array([Vector2(0,-size), Vector2(size*0.7,size*0.5), Vector2(-size*0.7,size*0.5)])
			enemy.draw_colored_polygon(fallback_pts, Color(0.8,0.8,0.8,0.85))
			enemy.draw_circle(Vector2.ZERO, size*0.3, Color.WHITE)

# ── Full-fidelity dispatch ───────────────────────────────────────────────────────

static func _boss_scale(enemy: Node2D) -> float:
	match str(enemy.get("enemy_type")):
		# Original bosses (bulwark visual)
		"boss":              return 1.60
		"boss_tyrant":       return 1.65
		"boss_phantom":      return 1.55
		"boss_herald":       return 1.75
		"boss_colossus":     return 2.00
		# Creep bosses
		"boss_basic":        return 1.80
		"boss_fast":         return 1.60
		"boss_swarm":        return 1.80
		"boss_runner":       return 1.65
		"boss_tank":         return 1.55
		"boss_hunter":       return 1.65
		"boss_shieldbearer": return 1.70
		"boss_healer":       return 1.70
		"boss_splitter":     return 1.75
		"boss_cloaked":      return 1.60
		"boss_flyer":        return 1.65
		"boss_fast_flyer":   return 1.55
		"boss_armored_flyer":return 1.70
		"boss_disruptor":    return 1.75
	return 1.0

static func _dispatch_full(enemy: Node2D, vt: String, size: float) -> void:
	var bs := _boss_scale(enemy)
	var s := size * (bs if bs > 1.0 else 1.0)
	match vt:
		"basic":      _Basic.draw(enemy, s)
		"fast":       _Fast.draw(enemy, s)
		"tank":       _Tank.draw(enemy, s * 1.4)
		"bulwark":    _Bulwark.draw(enemy, s)
		"hunter":     _Hunter.draw(enemy, s * 1.3)
		"swarm":      _Swarm.draw(enemy, s * 0.86)
		"runner":     _Runner.draw(enemy, s)
		"shieldbearer": _Shieldbearer.draw(enemy, s * 1.3)
		"healer":     _Healer.draw(enemy, s * 1.1)
		"splitter":   _Splitter.draw(enemy, s * 1.3)
		"cloaked":    _Cloaked.draw(enemy, s)
		"flyer":      _Flyer.draw(enemy, s)
		"fast_flyer": _FastFlyer.draw(enemy, s * 0.8)
		"armored_flyer": _ArmoredFlyer.draw(enemy, s * 1.5)
		"disruptor":  _Disruptor.draw(enemy, s * 1.2)

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
	_draw_affix_overlay(enemy, size)
	var shield: float = float(enemy.get("shield_remaining"))
	var slow: float   = float(enemy.get("active_slow_percent"))
	var flash: bool   = bool(enemy.get("is_flashing"))
	var hit_color: Color = enemy.get("hit_flash_color")
	var hit_alpha: float = clampf(float(enemy.get("hit_flash_alpha")), 0.0, 0.22)
	if shield > 0:
		enemy.draw_arc(Vector2.ZERO, size*1.4, 0, TAU, 12, Color(0.4,0.8,1.0,0.22), 1.5)
	if slow > 0:
		enemy.draw_circle(Vector2.ZERO, size*1.2, Color(0.6,0.9,1.0,0.16))
	if flash and hit_alpha > 0.01:
		enemy.draw_circle(Vector2.ZERO, size*1.35, Color(hit_color.r, hit_color.g, hit_color.b, hit_alpha))

static func _draw_affix_overlay(enemy: Node2D, size: float) -> void:
	var tint = enemy.get("affix_tint")
	if not tint is Color or tint == Color.WHITE:
		return
	var is_boss: bool = (enemy.get("tags") is Array) and (enemy.get("tags") as Array).has("boss")
	var alpha := 0.50 if is_boss else 0.32
	var radius := size * (1.15 if is_boss else 1.05)
	enemy.draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, alpha))

static func _draw_status_overlays_full(enemy: Node2D, size: float) -> void:
	_draw_affix_overlay(enemy, size)
	var shield: float    = float(enemy.get("shield_remaining"))
	var slow: float      = float(enemy.get("active_slow_percent"))
	var flash: bool      = bool(enemy.get("is_flashing"))
	var pulse_time: float = float(enemy.get("pulse_time"))
	var hit_color: Color = enemy.get("hit_flash_color")
	var hit_alpha: float = clampf(float(enemy.get("hit_flash_alpha")), 0.0, 0.22)

	if shield > 0:
		var p_pulse: float = sin(pulse_time*0.7)*0.025+0.985
		enemy.draw_arc(Vector2.ZERO, size*1.4*p_pulse, 0, TAU, 16, Color(0.4,0.8,1.0,0.24), 1.5)
		enemy.draw_circle(Vector2.ZERO, size*1.4, Color(0.4,0.8,1.0,0.045))
	if slow > 0:
		enemy.draw_circle(Vector2.ZERO, size*1.2, Color(0.6,0.9,1.0,0.18))
		enemy.draw_arc(Vector2.ZERO, size*1.1, 0, TAU, 24, Color(0.6,0.9,1.0,0.24), 1.5)
	if flash and hit_alpha > 0.01:
		enemy.draw_circle(Vector2.ZERO, size*1.35, Color(hit_color.r, hit_color.g, hit_color.b, hit_alpha))
		enemy.draw_arc(Vector2.ZERO, size*1.45, 0, TAU, 24, Color(hit_color.r, hit_color.g, hit_color.b, hit_alpha * 0.75), 1.25)
