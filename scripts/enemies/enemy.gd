extends PathFollow2D
## Set true only when tracing combat feature internals.
## Off by default — healer/disruptor/runner ticks fire every few hundred ms;
## with 10+ special enemies on wave 27 this generates thousands of log lines/min.
static var _verbose_combat: bool = false

const CatalogPreviewMode = preload("res://scripts/debug/catalog_preview_mode.gd")

signal died(enemy, reward_gold)
signal reached_base(enemy, damage, global_pos)
signal healed(target, amount, source)
signal healer_heal_tick(healer, targets, amount)
signal enemy_healed(target, healer, amount, hp_before, hp_after)
signal shield_applied(target, raw_damage, final_damage, source)
signal disrupted_tower(tower, penalty, source)
signal disruption_removed(tower, source)
signal split_triggered(source, child_type, count)
signal stealth_targeting_deferred(cloaked_enemy, preferred_target)
signal enemy_modifier_changed(enemy, modifier_name, value)

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]

const SWARM_ACCENT_AMBER := Color(1.0, 0.54, 0.12, 1.0)
const SWARM_ACCENT_HOT := Color(1.0, 0.82, 0.36, 1.0)
const SWARM_ACCENT_DEEP := Color(1.0, 0.22, 0.08, 1.0)

var hp: float = 30.0
var max_hp: float = 30.0
var base_speed: float = 100.0
var speed: float = 100.0
var formation_speed_multiplier: float = 1.0
var formation_target_multiplier: float = 1.0
var formation_config_multiplier: float = 1.0
var status_speed_multiplier: float = 1.0
var formation_release_rate: float = 2.5
var reward_gold: int = 5
var base_damage: int = 1
var enemy_type: String = "basic"
var enemy_category: String = ENEMY_CATEGORY_LAND
var visual_type: String = "basic"
var display_name: String = "Enemy"

var is_active: bool = false
var reached_base_flag: bool = false
var is_dead_flag: bool = false
var use_dynamic_pathing: bool = false
var pathfinding_manager: Node = null
var dynamic_path: PackedVector2Array = PackedVector2Array()
var dynamic_path_index: int = 0
var last_path_grid_version: int = -1
var dynamic_target_reached_distance: float = 8.0
var dynamic_travel_distance: float = 0.0

# Effects status
var active_slow_percent: float = 0.0
var slow_remaining: float = 0.0
var shield_remaining: float = 0.0
var active_shield_reduction: float = 0.0
var active_shield_source: Node = null
var is_flashing: bool = false
var vulnerability_multiplier: float = 1.0
var vulnerability_remaining: float = 0.0
var armor_reduction_bonus_percent: float = 0.0
var armor_reduction_remaining: float = 0.0
var root_slow_percent: float = 0.0
var root_remaining: float = 0.0
var active_dot_effects: Array[Dictionary] = []
var delayed_damage_effects: Array[Dictionary] = []
var bleed_particle_timer: float = 0.0

# Special Archetypes
var is_bulwark: bool = false
var is_hunter: bool = false
var is_runner: bool = false

# Runner role: no longer just “faster Fast”.
# Runner moves at medium-high baseline speed, then creates danger windows with dash bursts
# and a low-HP panic sprint. These values can be overridden from enemies.json skill_params.
var runner_dash_cooldown: float = 3.2
var runner_dash_timer: float = 0.8
var runner_dash_duration: float = 0.34
var runner_dash_remaining: float = 0.0
var runner_dash_speed_multiplier: float = 1.95
var runner_dash_damage_reduction: float = 0.35
var runner_panic_threshold: float = 0.40
var runner_panic_speed_multiplier: float = 1.45
var runner_panic_active: bool = false
var runner_base_speed_scale: float = 0.92

var last_damage_source: String = ""
var tags: Array = []

# Visual State
var pulse_time: float = 0.0
var _draw_timer: float = 0.0
var swarm_core_flicker_time: float = 0.0
var swarm_pack_density: float = 0.0
var swarm_pack_check_timer: float = 0.0
var hit_flash_color: Color = Color(1.0, 0.62, 0.26, 0.0)
var hit_flash_alpha: float = 0.0
var _hit_flash_tween: Tween = null
var _hit_pulse_tween: Tween = null
var _hit_shake_tween: Tween = null
const PERFORMANCE_VISUAL_MODE := true   # Simplified silhouette rendering for 60 FPS
const ENEMY_VISUAL_REDRAW_INTERVAL := 0.125  # 8 FPS visual update (was 1/30 = 30 FPS)
const ENEMY_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.74)
const ENEMY_OUTLINE_THICKNESS := 2.0
const SHOW_FLOATING_DAMAGE_NUMBERS := false
enum HealthVisualState { HEALTH_OK, HEALTH_DAMAGED, HEALTH_CRITICAL }
var health_visual_state: int = HealthVisualState.HEALTH_OK

# Baker-style body sprite — replaces procedural _draw() body (15→1 draw call).
var _body_sprite: Sprite2D = null
var _body_baked: bool = false
var _baked_health_state: int = -1
var _bake_scale: Vector2 = Vector2(0.5, 0.5)   # set in _apply_baked_enemy_texture

# Sprite animation state (no queue_redraw needed — GPU-side transforms only)
var _hit_impact_tween: Tween = null
var _hit_impact_active: bool = false
var _hit_jitter_tween: Tween = null
var _shadow_node: Node2D = null
var _last_sprite_hit_impact_msec: int = -1000000
var _last_hit_spark_msec: int = -1000000
const SPRITE_HIT_IMPACT_COOLDOWN_MSEC := 130
const HIT_SPARK_COOLDOWN_MSEC := 80
const CROWDED_HIT_SPARK_COOLDOWN_MSEC := 180
const CROWDED_ENEMY_RADIUS := 54.0
const CROWDED_ENEMY_THRESHOLD := 7

# Per-enemy organic motion — set once in setup(), never changes.
# Desync bobs, drift ⊥ to path, tilt on step — all GPU-side Sprite2D transforms.
var _anim_phase: float = 0.0       # unique bob phase per enemy (0..TAU)
var _perp_drift_amp: float = 0.0   # lateral drift amplitude in local-Y px
var _perp_drift_freq: float = 0.0  # drift cycles per px of path progress
var _visual_heading_angle: float = 0.0

# Lazy separation — scan nearby enemies every ~0.4 s, smoothly push apart visually.
# Visual angle is locked, so this is a screen-local Y offset and never moves gameplay hitboxes.
var _sep_lateral: float = 0.0      # current smoothed lateral offset (px)
var _sep_target: float = 0.0       # target lateral from last avoidance scan
var _sep_check_timer: float = 0.0  # countdown to next scan
var _spawn_spread_lateral: float = 0.0 # early visual-only lane offset; fades with progress

const SEP_SCAN_INTERVAL   := 0.38   # base seconds between scans per enemy
const SEP_SCAN_RADIUS_SQ  := 784.0  # 28 px² — world-space proximity filter
const SEP_PUSH_MAX        := 7.0    # max px pushed per overlapping neighbour
const SEP_ROAD_HALF       := 14.0   # max combined lateral offset from path center
const SPAWN_SPREAD_FADE_DISTANCE := 220.0

# Smart Visual LOD — prioritises CPU for hero moments, saves it for background creeps.
# LOW (0): healthy, not in combat  → animate every 3rd frame, no glow
# HIGH (2): low HP, hit recently   → animate every frame, red pulse glow
const ANIM_LOD_LOW  := 0
const ANIM_LOD_HIGH := 2
var _anim_lod: int = ANIM_LOD_LOW
var _anim_frame_counter: int = 0   # incremented in _process, used to skip frames
var _death_glow_tween: Tween = null

# Shield and disrupt aura scan intervals — prevent O(n) group walks every frame.
# 0.25 s matches human-visible refresh; gameplay feel is unchanged.
const SHIELD_AURA_INTERVAL := 0.25
const DISRUPT_AURA_INTERVAL := 0.25
## DOT tick interval — reduces per-frame damage array walks on all enemies.
## Total damage-per-second is unchanged: damage_per_second × tick_delta = same DPS.
const DOT_TICK_INTERVAL: float = 0.10
var _dot_tick_timer: float = 0.0
var _dot_tick_accum: float = 0.0
var _shield_aura_timer: float = 0.0
var _disrupt_aura_timer: float = 0.0

const COLOR_BODY = Color(0.08, 0.08, 0.12) # Dark Gunmetal
const COLOR_NEON_BASIC = Color(0.2, 0.8, 1.0) # Electric Cyan
const COLOR_NEON_FAST = Color(0.0, 1.0, 0.7) # Teal/Green
const COLOR_NEON_TANK = Color(1.0, 0.45, 0.1) # Amber/Orange
const COLOR_NEON_BULWARK = Color(0.1, 0.6, 1.0) # Blue
const COLOR_NEON_HUNTER = Color(1.0, 0.1, 0.4) # Magenta/Red
const SWARM_PANEL_COLOR := Color(0.067, 0.094, 0.153, 1.0) # #111827
const SWARM_CORE_HIGHLIGHT := Color(0.224, 1.0, 0.478, 1.0) # #39FF7A
const SWARM_TRAIL_COLOR := Color(0.161, 0.475, 1.0, 1.0) # #2979FF
const SWARM_GLOW_LIGHT := Color(0.718, 1.0, 0.961, 1.0) # #B7FFF5
@export var swarm_body_color: Color = Color(0.102, 0.122, 0.169, 1.0) # #1A1F2B
@export var swarm_core_glow_color: Color = Color(0.08, 1.0, 1.0, 1.0) # ultra neon cyan
@export var swarm_trail_length: float = 2.7
@export var swarm_trail_alpha: float = 0.26
@export var swarm_hover_glow_strength: float = 0.22
@export var swarm_death_particle_count: int = 5 # [VISUAL-OPT] Reduced from 18 — cheaper death burst.

# Bulwark Stats
var shield_radius: float = 90.0
var shield_reduction: float = 0.30

# Hunter Stats
enum HunterState {PATHING, AGGRO_CHASING, AGGRO_ATTACKING}
var hunter_state: HunterState = HunterState.PATHING
var aggro_range: float = 105.0
var hunter_attack_range: float = 46.0
var hunter_attack_damage: float = 28.0
var hunter_attack_cooldown: float = 1.0
var hunter_attack_timer: float = 0.0
var hunter_target: Node2D = null
var hunter_scan_rotation: float = 0.0
var hunter_lock_fx_time: float = 0.0
var hunter_chase_speed_multiplier: float = 1.18

# Skill Stats
var skill_id: String = ""
var skill_params: Dictionary = {}
var skill_timer: float = 0.0
var is_stealth: bool = false
var formation_speed_limit: float = -1.0
var formation_limit_duration: float = 0.0
var disrupted_towers: Dictionary = {}
var split_triggered_once: bool = false

@onready var body: ColorRect = get_node_or_null("Body")
@onready var visual_root: Node2D = _resolve_visual_root()

func _resolve_visual_root() -> Node2D:
	var n := get_node_or_null("Body")
	if n is Node2D:
		return n
	if n != null:
		# Legacy enemy scenes keep Body as a hidden ColorRect while procedural
		# visuals draw on this PathFollow2D. That is valid and should not warn
		# once per spawned enemy.
		return self

	n = get_node_or_null("VisualRoot")
	if n is Node2D:
		return n

	n = get_node_or_null("Model")
	if n is Node2D:
		return n

	n = get_node_or_null("Sprite")
	if n is Node2D:
		return n

	DebugLog.warn_once("enemy_no_visual_root", "[Enemy] No Body/VisualRoot/Model/Sprite found, using self fallback.")
	return self
@onready var damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
@onready var death_pop_scene: PackedScene = preload("res://scenes/effects/DeathPopEffect.tscn")
@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
const ENEMY_VFX_CONTROLLER_SCRIPT := preload("res://scripts/effects/enemy_vfx_controller.gd")
const ENEMY_VISUAL_ROUTER := preload("res://scripts/enemies/enemy_visual_router.gd")

var vfx_controller: Node = null


func setup(config: Dictionary) -> void:
	EnemySetupService.apply_setup(self, config)

func normalize_enemy_category(raw_category) -> String:
	var normalized = str(raw_category).strip_edges().to_lower()
	if VALID_ENEMY_CATEGORIES.has(normalized):
		return normalized
	return ENEMY_CATEGORY_LAND

func get_enemy_category() -> String:
	return enemy_category

func is_cloaked() -> bool:
	return enemy_type == "cloaked" or skill_id == "stealth" or tags.has("stealth")

func get_hit_origin() -> Vector2:
	# canonical point for projectiles and effects
	return global_position

func get_hit_anchor_global_position() -> Vector2:
	return get_hit_origin()

func apply_visuals() -> void:
	if not is_inside_tree(): return
	if body: body.visible = false
	queue_redraw()

func _ensure_vfx_controller() -> void:
	if vfx_controller and is_instance_valid(vfx_controller):
		vfx_controller.setup(self )
		return
	vfx_controller = get_node_or_null("EnemyVFXController")
	if vfx_controller == null:
		vfx_controller = ENEMY_VFX_CONTROLLER_SCRIPT.new()
		add_child(vfx_controller)
	vfx_controller.setup(self )

func get_vfx_controller() -> Node:
	_ensure_vfx_controller()
	return vfx_controller

func _draw() -> void:
	EnemyVisualRenderer.draw_enemy(self)

func _scale_polygon(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		var dir := point.normalized()
		out.append(point + dir * amount)
	return out

func _apply_health_tint(base_color: Color) -> Color:
	match health_visual_state:
		HealthVisualState.HEALTH_DAMAGED:
			return base_color.lerp(Color(1.0, 0.45, 0.10, base_color.a), 0.34)
		HealthVisualState.HEALTH_CRITICAL:
			return base_color.lerp(Color(1.0, 0.08, 0.04, base_color.a), 0.55)
		_:
			return base_color

func _update_health_visual_state(force_redraw: bool = false) -> void:
	var hp_ratio: float = 1.0
	if max_hp > 0.0:
		hp_ratio = clampf(hp / max_hp, 0.0, 1.0)
	var next_state: int = HealthVisualState.HEALTH_OK
	if hp_ratio <= 0.20:
		next_state = HealthVisualState.HEALTH_CRITICAL
	elif hp_ratio <= 0.60:
		next_state = HealthVisualState.HEALTH_DAMAGED
	if force_redraw or next_state != health_visual_state:
		health_visual_state = next_state
		queue_redraw()
		if _body_baked and next_state != _baked_health_state:
			_request_baked_enemy_texture()
		# Escalate to HIGH LOD when hurt — full animation + glow from now on.
		if next_state >= HealthVisualState.HEALTH_DAMAGED:
			_set_anim_lod_high()
		if next_state == HealthVisualState.HEALTH_CRITICAL:
			_start_near_death_glow()

# ── Baker-style body sprite ──────────────────────────────────────────────────

func _request_baked_enemy_texture() -> void:
	if is_gallery_preview:
		return
	# Defer until we're in the scene tree so add_child / callbacks work safely.
	if not is_inside_tree():
		call_deferred("_request_baked_enemy_texture")
		return
	var vt: String = str(visual_type)
	var hs: int    = health_visual_state
	var captured   := self
	EnemyTextureBaker.request_texture(vt, hs, func(tex: ImageTexture) -> void:
		if not is_instance_valid(captured):
			return
		captured._apply_baked_enemy_texture(tex)
	)

func _apply_baked_enemy_texture(tex: ImageTexture) -> void:
	if tex == null:
		return
	if _body_sprite == null or not is_instance_valid(_body_sprite):
		_body_sprite = Sprite2D.new()
		_body_sprite.name = "BakedBodySprite"
		_body_sprite.centered = true
		_body_sprite.z_index = 0
		_body_sprite.z_as_relative = true
		add_child(_body_sprite)
		move_child(_body_sprite, 0)

	if _uses_directional_visual(visual_type) and (_shadow_node == null or not is_instance_valid(_shadow_node)):
		_shadow_node = Node2D.new()
		_shadow_node.name = "DirectionalShadow"
		_shadow_node.z_index = -1
		_shadow_node.z_as_relative = true
		var is_fast = visual_type in ["fast", "runner", "hunter"]
		var rx = 14.2 if is_fast else 12.4
		var ry = 3.8 if is_fast else 3.3
		var alpha = 0.22 if is_fast else 0.15
		_shadow_node.draw.connect(func():
			var pts := PackedVector2Array()
			for i in 22:
				var a := float(i)/22.0*TAU
				pts.append(Vector2(cos(a)*rx, sin(a)*ry))
			_shadow_node.draw_colored_polygon(pts, Color(0,0,0,alpha))
			var core := PackedVector2Array()
			for i in 18:
				var a := float(i)/18.0*TAU
				core.append(Vector2(cos(a)*rx*0.58, sin(a)*ry*0.62))
			_shadow_node.draw_colored_polygon(core, Color(0,0,0,alpha*0.72))
		)
		add_child(_shadow_node)
		move_child(_shadow_node, 0)
		_shadow_node.queue_redraw()

	_bake_scale = Vector2.ONE / float(EnemyTextureBaker.BAKE_ZOOM)
	_body_sprite.texture = tex
	_body_sprite.scale   = _bake_scale
	_body_sprite.visible = true
	_baked_health_state  = health_visual_state
	if not _body_baked:
		# First time baked: pop-in spawn animation
		_body_sprite.scale = Vector2.ZERO
		var spawn_tw := create_tween()
		spawn_tw.tween_property(_body_sprite, "scale", _bake_scale, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_baked = true
	queue_redraw()

## Per-type lateral drift amplitude (px). Fast/small types drift more; tanks barely move.
func _get_type_drift_amp(vtype: String) -> float:
	match vtype:
		"swarm":       return 9.0
		"fast", "runner", "fast_flyer": return 7.5
		"cloaked":     return 7.0
		"basic", "healer", "splitter", "disruptor": return 6.0
		"hunter", "flyer", "armored_flyer": return 5.5
		"tank", "bulwark", "shieldbearer": return 3.0
		_:             return 6.0

## Spawn spread is visual-only and decays during the first few road tiles.
## It keeps dense starts from reading as one stacked train without moving gameplay hitboxes.
func _get_type_spawn_spread(vtype: String) -> float:
	match vtype:
		"swarm":                           return 10.0
		"fast", "runner", "fast_flyer":    return 8.5
		"tank", "bulwark", "shieldbearer": return 4.5
		"flyer", "armored_flyer":          return 6.0
		_:                                 return 7.0

## Lazy separation — pushes _sep_target away from nearby overlapping enemies.
## Called ~every 0.4 s per enemy (staggered), NOT every frame.
func _update_separation() -> void:
	var push := 0.0
	var pb := get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = (pb.get_enemies() if pb != null and pb.has_method("get_enemies")
						 else get_tree().get_nodes_in_group("enemies"))
	var my_pos   := global_position
	var my_prog  := get_path_progress()
	for other in enemies:
		if other == self or not is_instance_valid(other): continue
		var op: Vector2 = other.global_position
		var dx := op.x - my_pos.x
		var dy := op.y - my_pos.y
		if dx * dx + dy * dy > SEP_SCAN_RADIUS_SQ: continue   # world-distance guard
		if not other.has_method("get_path_progress"): continue
		if absf(my_prog - other.get_path_progress()) > 32.0: continue  # far on path
		# Determine push direction — must differ between the two enemies in a pair
		var other_lat: float = float(other.get("_sep_lateral"))
		var gap := _sep_lateral - other_lat
		var push_dir: float
		if absf(gap) > 2.0:
			push_dir = signf(gap)           # already separated: reinforce it
		else:
			# Tie-break via relative instance IDs — guarantees opposite dirs per pair
			push_dir = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
		var dist_sq := dx * dx + dy * dy
		push += push_dir * SEP_PUSH_MAX * (1.0 - dist_sq / SEP_SCAN_RADIUS_SQ)
	# Decay toward 0 when alone; clamp to road half-width
	if absf(push) < 0.1:
		push = _sep_target * -0.25   # gentle return to center when isolated
	_sep_target = clampf(push, -SEP_ROAD_HALF, SEP_ROAD_HALF)

func _uses_glide_motion(vtype: String) -> bool:
	return vtype == "fast" or vtype == "runner" or vtype == "fast_flyer" or vtype == "hunter"

func _uses_directional_visual(vtype: String) -> bool:
	return vtype == "fast" or vtype == "runner" or vtype == "fast_flyer" or vtype == "hunter"

func _record_visual_movement_delta(delta_pos: Vector2) -> void:
	if delta_pos.length_squared() <= 0.01:
		return
	_visual_heading_angle = delta_pos.angle()

func _get_body_visual_rotation() -> float:
	if _uses_directional_visual(visual_type):
		return _visual_heading_angle
	return 0.0

## Per-type bob intensity — pointed fast units glide; compact bodies can bounce.
func _get_type_bob_intensity(vtype: String) -> float:
	match vtype:
		"tank", "bulwark", "shieldbearer": return 0.55
		"swarm":                           return 0.85
		"fast", "runner", "fast_flyer":    return 0.34
		"hunter":                          return 0.48
		_:                                 return 1.0

## Walking squash/stretch — called every frame when baked. No queue_redraw.
func _update_sprite_movement_anim() -> void:
	if not _body_baked or _body_sprite == null or _hit_impact_active:
		return
	var speed_ratio := clampf(speed / maxf(base_speed, 1.0), 0.0, 2.2)
	if speed_ratio < 0.02:
		_body_sprite.scale    = _bake_scale
		_body_sprite.position = Vector2(0.0, -3.6 if _uses_directional_visual(visual_type) else 0.0)
		_body_sprite.rotation = _get_body_visual_rotation()
		if _uses_directional_visual(visual_type):
			_body_sprite.flip_v = absf(wrapf(_body_sprite.rotation, -PI, PI)) > (PI / 2.0)
		if _shadow_node != null and is_instance_valid(_shadow_node):
			_shadow_node.position = Vector2(0.0, 9.8)
		return
	# get_path_progress() works for BOTH PathFollow2D (progress) and dynamic-path
	# enemies (dynamic_travel_distance). Using progress directly would freeze dynamic-path
	# enemies at phase = 0, giving no animation.
	var path_px := get_path_progress()
	if _uses_glide_motion(visual_type):
		_update_sprite_glide_motion(path_px, speed_ratio)
		return

	var bob_intensity := _get_type_bob_intensity(visual_type)
	# Staggered bob: unique phase per enemy; ~1 cycle every 70 px of travel
	var bob := sin(path_px * 0.090 + _anim_phase) * speed_ratio * bob_intensity
	# Squash-stretch: exaggerated so it reads at small sprite sizes
	_body_sprite.scale = Vector2(
		_bake_scale.x * (1.0 - bob * 0.20),   # narrow on upstroke
		_bake_scale.y * (1.0 + bob * 0.30)    # tall on upstroke, short on downstroke
	)
	# Primary screen-local weave + secondary overtone = organic swarm feel
	# path_px drives drift so it's always in sync with actual travel distance
	var drift := sin(path_px * _perp_drift_freq + _anim_phase) * _perp_drift_amp \
			   + sin(path_px * _perp_drift_freq * 2.1 + _anim_phase + 1.4) * _perp_drift_amp * 0.30
	# Combined lateral: drift + separation, clamped to road half-width
	var spawn_spread := _spawn_spread_lateral * (1.0 - clampf(path_px / SPAWN_SPREAD_FADE_DISTANCE, 0.0, 1.0))
	var lateral := clampf(drift + _sep_lateral + spawn_spread, -SEP_ROAD_HALF, SEP_ROAD_HALF)
	# Float: sprite rises at upstroke peak. Visual angle is locked, so Y stays screen-local.
	_body_sprite.position = Vector2(0.0, lateral - absf(bob) * 6.5 * speed_ratio)
	# Lean: tilt sprite into each step — intensity scales with bob type
	_body_sprite.rotation = bob * 0.22

	if _shadow_node != null and is_instance_valid(_shadow_node):
		_shadow_node.position = Vector2(0.0, lateral + 9.8)


func _update_sprite_glide_motion(path_px: float, speed_ratio: float) -> void:
	var glide := sin(path_px * 0.135 + _anim_phase) * speed_ratio
	var micro := sin(path_px * 0.265 + _anim_phase * 0.73) * speed_ratio
	var compression := absf(glide)
	var scale_x := 1.0 + compression * (0.070 if visual_type == "runner" else 0.055)
	var scale_y := 1.0 - compression * (0.040 if visual_type == "runner" else 0.032)
	_body_sprite.scale = Vector2(_bake_scale.x * scale_x, _bake_scale.y * scale_y)

	var drift := (
		sin(path_px * _perp_drift_freq + _anim_phase) * _perp_drift_amp * 0.42
		+ sin(path_px * _perp_drift_freq * 2.1 + _anim_phase + 1.4) * _perp_drift_amp * 0.12
	)
	var spawn_spread := _spawn_spread_lateral * (1.0 - clampf(path_px / SPAWN_SPREAD_FADE_DISTANCE, 0.0, 1.0))
	var lateral := clampf(drift + _sep_lateral + spawn_spread, -SEP_ROAD_HALF, SEP_ROAD_HALF)
	var slide_x := micro * (1.85 if visual_type == "runner" else 1.35)
	var lift := absf(micro) * (0.34 if visual_type == "runner" else 0.26)
	if _uses_directional_visual(visual_type):
		lift += 3.6 # Replace baked body_offset so sprite floats correctly

	_body_sprite.position = Vector2(slide_x, lateral - lift)
	var bank := glide * (0.105 if visual_type == "runner" else 0.078)
	_body_sprite.rotation = _get_body_visual_rotation() + bank
	if _uses_directional_visual(visual_type):
		_body_sprite.flip_v = absf(wrapf(_body_sprite.rotation, -PI, PI)) > (PI / 2.0)


	if _shadow_node != null and is_instance_valid(_shadow_node):
		_shadow_node.position = Vector2(slide_x, lateral + 9.8)


## Hit impact squish + colour flash — no queue_redraw, all Tween/modulate.
## Heavy squash is intentionally throttled so rapid-fire hits do not freeze gait animation.
func _play_sprite_hit_impact(color: Color) -> void:
	if not _body_baked or _body_sprite == null or not is_instance_valid(_body_sprite):
		return
	var now_msec := Time.get_ticks_msec()
	if _hit_impact_active or now_msec - _last_sprite_hit_impact_msec < SPRITE_HIT_IMPACT_COOLDOWN_MSEC:
		return
	_last_sprite_hit_impact_msec = now_msec
	if _hit_impact_tween != null and _hit_impact_tween.is_valid():
		_hit_impact_tween.kill()
	if _death_glow_tween != null and _death_glow_tween.is_valid():
		_death_glow_tween.pause()
	_hit_impact_active = true

	# Bright white flash first frame, then element colour, then return — very snappy
	var flash_white := Color(2.0, 2.0, 2.0, 1.0)
	var flash_col   := Color(
		minf(color.r * 2.5, 1.0),
		minf(color.g * 2.0, 1.0),
		minf(color.b * 2.0, 1.0), 1.0)

	# Per-type squish — tanks thud with rigid shudder; light units flex dramatically.
	var squish_wide: float
	var squish_flat: float
	match visual_type:
		"tank", "bulwark", "shieldbearer":
			squish_wide = 1.30; squish_flat = 0.72
		"swarm":
			squish_wide = 1.50; squish_flat = 0.55
		"fast", "runner", "fast_flyer", "hunter":
			squish_wide = 1.26; squish_flat = 0.78
		_:
			squish_wide = 1.65; squish_flat = 0.45

	var t := create_tween().set_parallel(true)
	_hit_impact_tween = t

	# Squish [WAVE 1: 45ms] + instant white flash
	_body_sprite.modulate = flash_white
	t.tween_property(_body_sprite, "modulate", flash_col, 0.03)
	t.tween_property(_body_sprite, "scale",
		Vector2(_bake_scale.x * squish_wide, _bake_scale.y * squish_flat), 0.045)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Spring back [WAVE 2: 120ms]
	t.chain().tween_property(_body_sprite, "scale", _bake_scale, 0.12)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	# Release freeze right after spring-back (~165ms); colour fade continues
	# independently — walking animation resumes without fighting the scale tween.
	t.chain().tween_callback(func() -> void:
		_hit_impact_active = false
		if _body_sprite != null and is_instance_valid(_body_sprite):
			_body_sprite.rotation = _get_body_visual_rotation()
		if _death_glow_tween != null and _death_glow_tween.is_valid():
			_death_glow_tween.play()
	)
	# Colour fade [WAVE 3: +110ms, parallel with callback]
	t.tween_property(_body_sprite, "modulate", Color.WHITE, 0.11)\
		.set_trans(Tween.TRANS_EXPO)
	t.chain().tween_callback(func() -> void:
		if _body_sprite != null and is_instance_valid(_body_sprite):
			if health_visual_state < HealthVisualState.HEALTH_CRITICAL:
				_body_sprite.modulate = Color.WHITE
	)

	# Separate quick shake anchored at the current visual offset. Do not reset
	# position to Vector2.ZERO here; dense groups use different lateral offsets,
	# and collapsing all hit creeps back to one center line reads like a bug.
	if _hit_shake_tween != null and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	if _hit_jitter_tween != null and _hit_jitter_tween.is_valid():
		_hit_jitter_tween.kill()
	var hit_anchor := _body_sprite.position
	var impact_seed := fmod(float(get_instance_id()) * 0.61803398875, 1.0)
	var shake_sign := 1.0 if impact_seed >= 0.5 else -1.0
	var shake_amp := (5.0 if (enemy_type == "swarm" or tags.has("swarm")) else 8.0) * (0.78 + impact_seed * 0.34)
	var jitter_y := shake_amp * (0.15 + impact_seed * 0.12)
	_hit_shake_tween = create_tween()
	_hit_shake_tween.tween_property(_body_sprite, "position",
		hit_anchor + Vector2(shake_amp * shake_sign, -jitter_y), 0.026 + impact_seed * 0.010)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hit_shake_tween.chain().tween_property(_body_sprite, "position",
		hit_anchor + Vector2(-shake_amp * 0.55 * shake_sign, jitter_y * 0.35), 0.034 + impact_seed * 0.010)\
		.set_trans(Tween.TRANS_SPRING)
	_hit_shake_tween.chain().tween_property(_body_sprite, "position",
		hit_anchor + Vector2(shake_amp * 0.22 * shake_sign, -jitter_y * 0.18), 0.026 + impact_seed * 0.008)\
		.set_trans(Tween.TRANS_SPRING)
	_hit_shake_tween.chain().tween_property(_body_sprite, "position", hit_anchor, 0.026)\
		.set_trans(Tween.TRANS_SPRING)

## Hit spark at the world-space impact point — bypasses screen shake entirely.
## Uses the enemy_impact pool for a tiny 3-ray burst + core dot.
func _spawn_hit_spark(hit_pos: Vector2, color: Color) -> void:
	if PerformanceFirebreak.disable_death_effects:
		return
	var now_msec := Time.get_ticks_msec()
	var crowded := _get_nearby_enemy_count(CROWDED_ENEMY_RADIUS) >= CROWDED_ENEMY_THRESHOLD
	var cooldown := CROWDED_HIT_SPARK_COOLDOWN_MSEC if crowded else HIT_SPARK_COOLDOWN_MSEC
	if now_msec - _last_hit_spark_msec < cooldown:
		return
	_last_hit_spark_msec = now_msec
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_scene"):
		return
	var spark: Node = pool.acquire_scene("death_pop",
		get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer") \
		if get_tree().current_scene.has_node("WorldRoot/MapRoot/EffectsContainer") \
		else get_tree().current_scene,
		"death_pop")
	if spark == null:
		return
	spark.global_position = hit_pos
	spark.scale = Vector2.ONE * (0.32 if crowded else 0.45)   # tiny spark — not an explosion
	if spark.has_method("setup"):
		spark.setup("default", Color(color.r, color.g, color.b, 0.9), 0.10 if crowded else 0.12, 2 if crowded else 3)

func _get_nearby_enemy_count(radius: float) -> int:
	var count := 0
	var radius_sq := radius * radius
	var pb: Node = get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = pb.get_enemies() if pb != null and pb.has_method("get_enemies") else get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if global_position.distance_squared_to(enemy.global_position) <= radius_sq:
			count += 1
			if count >= CROWDED_ENEMY_THRESHOLD:
				return count
	return count

## Death pop — instant scale burst + fade before queue_free fires.
func _play_sprite_death() -> void:
	if not _body_baked or _body_sprite == null or not is_instance_valid(_body_sprite):
		return
	if _hit_impact_tween != null and _hit_impact_tween.is_valid():
		_hit_impact_tween.kill()
	if _death_glow_tween != null and _death_glow_tween.is_valid():
		_death_glow_tween.kill()
	# Pop: burst scale + instant white flash → transparent before queue_free
	var imp := _get_death_importance()
	_body_sprite.scale   = _bake_scale * clampf(1.15 + imp * 0.12, 1.15, 1.6)
	_body_sprite.modulate = Color(2.2, 2.2, 2.2, 0.0)

## Escalate LOD: full-rate animation + hit emphasis from now on.
func _set_anim_lod_high() -> void:
	_anim_lod = ANIM_LOD_HIGH

## Pulsing red glow on sprite when enemy is near death — draws attention to threats.
func _start_near_death_glow() -> void:
	if not _body_baked or _body_sprite == null or not is_instance_valid(_body_sprite):
		return
	if _death_glow_tween != null and _death_glow_tween.is_valid():
		return  # already pulsing
	_death_glow_tween = create_tween().set_loops()
	_death_glow_tween.tween_property(_body_sprite, "modulate",
		Color(1.6, 0.55, 0.55, 1.0), 0.28).set_trans(Tween.TRANS_SINE)
	_death_glow_tween.tween_property(_body_sprite, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.28).set_trans(Tween.TRANS_SINE)

# --- High-Fidelity Procedural Visuals ---

func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, count: int = 28, p_rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		var a: float = float(i) / float(count) * TAU
		var p := Vector2(cos(a) * radius_x, sin(a) * radius_y).rotated(p_rotation)
		pts.append(center + p)
	return pts

func _draw_runner_role_telegraph(size: float) -> void:
	var danger_color := Color(1.0, 0.35, 0.05, 1.0)
	var pulse: float = 0.5 + sin(pulse_time * 12.0) * 0.5
	var dash_charge: float = 1.0 - clampf(runner_dash_timer / maxf(runner_dash_cooldown, 0.01), 0.0, 1.0)
	var ring_alpha: float = 0.05 + dash_charge * 0.16

	# Small charge ring: tells the player Runner has a timed burst, without creating a huge range UI.
	draw_arc(Vector2.ZERO, size * (1.35 + dash_charge * 0.28), -PI * 0.85, PI * 0.85, 36, Color(danger_color.r, danger_color.g, danger_color.b, ring_alpha), 1.1, true)

	if runner_dash_remaining > 0.0:
		var dash_alpha: float = 0.22 + pulse * 0.18
		draw_circle(Vector2.ZERO, size * 1.55, Color(danger_color.r, danger_color.g, danger_color.b, 0.08 + pulse * 0.04))
		draw_line(Vector2(-size * 0.9, 0), Vector2(-size * 3.2, 0), Color(danger_color.r, danger_color.g, danger_color.b, dash_alpha), 4.0, true)
		draw_line(Vector2(-size * 0.5, -size * 0.45), Vector2(-size * 2.5, -size * 0.85), Color(1.0, 0.75, 0.2, dash_alpha * 0.7), 1.4, true)
		draw_line(Vector2(-size * 0.5, size * 0.45), Vector2(-size * 2.5, size * 0.85), Color(1.0, 0.75, 0.2, dash_alpha * 0.7), 1.4, true)

	if runner_panic_active:
		# Panic mode should read as dangerous and unstable: orange/red breathing halo.
		draw_arc(Vector2.ZERO, size * (1.75 + pulse * 0.22), 0.0, TAU, 40, Color(1.0, 0.12, 0.04, 0.22 + pulse * 0.08), 1.6, true)
		draw_circle(Vector2(size * 0.58, 0), size * (0.18 + pulse * 0.06), Color(1.0, 0.9, 0.45, 0.75))

func _draw_cyber_swarm(_color: Color, size: float) -> void:
	var phase := float(get_instance_id() % 97) * 0.071
	var pulse := 0.5 + sin(pulse_time * 7.4 + phase) * 0.5
	var bob := sin(pulse_time * 7.0 + phase) * size * 0.08
	var flicker := clampf(0.92 + sin(pulse_time * 18.5 + phase * 2.3) * 0.16 + swarm_core_flicker_time * 0.8, 0.72, 1.45)
	var core_color := swarm_core_glow_color.lerp(SWARM_CORE_HIGHLIGHT, 0.46 + pulse * 0.36)
	var origin := Vector2(0.0, bob)

	_draw_swarm_hover_fx(origin, size, pulse)
	_draw_swarm_thruster_fx(origin, size, pulse, flicker)
	_draw_swarm_forward_motion_fx(origin, size, pulse, flicker)

	_draw_swarm_body_layers(origin, size * 0.98, flicker)
	_draw_swarm_core_layers(origin + Vector2(size * 0.04, 0.0), size * 0.82, core_color, pulse, flicker)

	var orbit_count: int = 4 + int(get_instance_id() % 2)

	for i in range(orbit_count):
		var denominator: float = maxf(1.0, float(orbit_count - 1))
		var t: float = float(i) / denominator

		var ring_phase: float = phase + float(i) * TAU / float(orbit_count)
		var orbit_a: float = pulse_time * (2.45 + float(i) * 0.18) + ring_phase
		var orbit_r: float = size * lerpf(1.10, 1.58, t) + sin(pulse_time * 5.8 + ring_phase * 1.7) * size * 0.06

		var orbit_squash := Vector2(1.0, lerpf(0.62, 0.82, t))

		var local_offset := Vector2(
			sin(pulse_time * 1.7 + float(i) * 1.13) * size * 0.08,
			cos(pulse_time * 2.1 + float(i) * 0.91) * size * 0.06
		)

		var orbit_pos: Vector2 = origin + Vector2(cos(orbit_a), sin(orbit_a)) * orbit_r * orbit_squash + local_offset

		var orb_scale: float = lerpf(0.34, 0.48, 1.0 - t)
		var orb_alpha_mul: float = lerpf(0.58, 1.0, 1.0 - t)
		var orb_flicker: float = clampf(flicker * (0.78 + pulse * 0.18 + float(i) * 0.03), 0.60, 1.35) * orb_alpha_mul

		_draw_swarm_orbiter(orbit_pos, size * orb_scale, orb_flicker)

		draw_line(
			origin,
			orbit_pos,
			Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.10 * orb_alpha_mul),
			1.0
		)
		
func _draw_swarm_orbiter(origin: Vector2, size: float, flicker: float) -> void:
	_draw_swarm_body_layers(origin, size, flicker)
	var orb_core := swarm_core_glow_color.lerp(SWARM_GLOW_LIGHT, 0.42)
	_draw_swarm_core_layers(origin + Vector2(size * 0.08, -size * 0.02), size * 0.52, orb_core, 0.55, flicker)

func _draw_swarm_hover_fx(origin: Vector2, size: float, pulse: float) -> void:
	var shadow_pos := origin + Vector2(-size * 0.16, size * 0.90)
	draw_circle(
		shadow_pos,
		size * (0.72 + pulse * 0.03),
		Color(0.0, 0.0, 0.0, 0.10 + pulse * 0.03)
	)
	var under_glow_pos := origin + Vector2(-size * 0.04, size * 0.36)
	draw_arc(
		under_glow_pos,
		size * (0.68 + pulse * 0.03),
		PI * 0.16,
		PI * 0.84,
		18,
		Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.10 + pulse * 0.03),
		1.0
	)
	
func _draw_swarm_body_layers(origin: Vector2, size: float, flicker: float) -> void:
	# Symmetric 3/4 top-down swarm body. Keep wings mirrored to avoid visual skew.
	var skew_y := size * 0.05

	var outer := PackedVector2Array([
		origin + Vector2(size * 1.42, 0.0),
		origin + Vector2(size * 0.76, -size * 0.34),
		origin + Vector2(-size * 0.18, -size * 0.76 + skew_y),
		origin + Vector2(-size * 0.94, -size * 0.54 + skew_y),
		origin + Vector2(-size * 0.58, 0.0 + skew_y * 0.75),
		origin + Vector2(-size * 0.94, size * 0.54 + skew_y),
		origin + Vector2(-size * 0.18, size * 0.76 + skew_y),
		origin + Vector2(size * 0.76, size * 0.34)
	])

	var inner := PackedVector2Array([
		origin + Vector2(size * 0.86, 0.0),
		origin + Vector2(size * 0.24, -size * 0.22),
		origin + Vector2(-size * 0.20, -size * 0.48 + skew_y * 0.85),
		origin + Vector2(-size * 0.42, 0.0 + skew_y * 0.6),
		origin + Vector2(-size * 0.20, size * 0.48 + skew_y * 0.85),
		origin + Vector2(size * 0.24, size * 0.22)
	])

	var under_plate := PackedVector2Array([
		origin + Vector2(size * 0.38, size * 0.14 + skew_y * 0.55),
		origin + Vector2(-size * 0.16, size * 0.08 + skew_y * 0.72),
		origin + Vector2(-size * 0.02, size * 0.42 + skew_y * 0.9),
		origin + Vector2(size * 0.28, size * 0.34 + skew_y * 0.78)
	])

	var top_fin := PackedVector2Array([
		origin + Vector2(-size * 0.34, -size * 0.34 + skew_y * 0.55),
		origin + Vector2(-size * 1.18, -size * 0.98 + skew_y),
		origin + Vector2(-size * 0.92, -size * 0.14 + skew_y * 0.8),
		origin + Vector2(-size * 0.48, -size * 0.06 + skew_y * 0.65)
	])

	var bottom_fin := PackedVector2Array([
		origin + Vector2(-size * 0.34, size * 0.34 + skew_y * 0.55),
		origin + Vector2(-size * 1.18, size * 0.98 + skew_y),
		origin + Vector2(-size * 0.92, size * 0.14 + skew_y * 0.8),
		origin + Vector2(-size * 0.48, size * 0.06 + skew_y * 0.65)
	])

	var sensor := PackedVector2Array([
		origin + Vector2(size * 1.04, 0.0),
		origin + Vector2(size * 0.82, -size * 0.15),
		origin + Vector2(size * 0.82, size * 0.15)
	])

	draw_colored_polygon(top_fin, SWARM_PANEL_COLOR)
	draw_colored_polygon(bottom_fin, SWARM_PANEL_COLOR)
	draw_colored_polygon(outer, swarm_body_color)
	draw_colored_polygon(inner, SWARM_PANEL_COLOR)
	draw_colored_polygon(under_plate, Color(SWARM_PANEL_COLOR.r, SWARM_PANEL_COLOR.g, SWARM_PANEL_COLOR.b, 0.8))
	draw_colored_polygon(sensor, Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.86 * flicker))

	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(SWARM_TRAIL_COLOR.r, SWARM_TRAIL_COLOR.g, SWARM_TRAIL_COLOR.b, 0.9), 1.35)
	draw_polyline(top_fin + PackedVector2Array([top_fin[0]]), Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.52 * flicker), 1.0)
	draw_polyline(bottom_fin + PackedVector2Array([bottom_fin[0]]), Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.52 * flicker), 1.0)

	# Mirrored wing circuit accents. Do not use an undeclared variable named angle here.
	draw_line(
		origin + Vector2(-size * 0.98, -size * 0.72 + skew_y),
		origin + Vector2(-size * 0.74, -size * 0.30 + skew_y),
		Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.98 * flicker),
		1.25
	)
	draw_line(
		origin + Vector2(-size * 0.98, size * 0.72 + skew_y),
		origin + Vector2(-size * 0.74, size * 0.30 + skew_y),
		Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.98 * flicker),
		1.25
	)

	draw_line(
		origin + Vector2(size * 0.60, -size * 0.04),
		origin + Vector2(-size * 0.04, -size * 0.24 + skew_y * 0.72),
		Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.88 * flicker),
		1.15
	)
	draw_line(
		origin + Vector2(size * 0.60, size * 0.04),
		origin + Vector2(-size * 0.04, size * 0.24 + skew_y * 0.72),
		Color(SWARM_TRAIL_COLOR.r, SWARM_TRAIL_COLOR.g, SWARM_TRAIL_COLOR.b, 0.78 * flicker),
		1.15
	)
	draw_circle(
		origin + Vector2(-size * 0.60, -size * 0.20),
		size * 0.055,
		Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.86 * flicker)
	)
	draw_circle(
		origin + Vector2(-size * 0.68, 0.0),
		size * 0.065,
		Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.92 * flicker)
	)
	draw_circle(
		origin + Vector2(-size * 0.60, size * 0.20),
		size * 0.055,
		Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.86 * flicker)
	)

func _draw_swarm_core_layers(origin: Vector2, size: float, core_color: Color, pulse: float, flicker: float) -> void:
	var glow_core := PackedVector2Array()
	var core := PackedVector2Array()
	var hot_core := PackedVector2Array()
	var radius_glow := size * (0.68 + pulse * 0.12)
	for i in range(6):
		var a := PI / 6.0 + float(i) * TAU / 6.0
		var dir := Vector2(cos(a), sin(a))
		glow_core.append(origin + dir * radius_glow)
		core.append(origin + dir * size * 0.34)
		hot_core.append(origin + dir * size * (0.17 + pulse * 0.03))
	draw_colored_polygon(glow_core, Color(core_color.r, core_color.g, core_color.b, 0.34 * flicker))
	draw_colored_polygon(core, Color(core_color.r, core_color.g, core_color.b, 0.98 * flicker))
	draw_polyline(core + PackedVector2Array([core[0]]), Color(SWARM_GLOW_LIGHT.r, SWARM_GLOW_LIGHT.g, SWARM_GLOW_LIGHT.b, 1.0 * flicker), 1.45)
	draw_colored_polygon(hot_core, Color(SWARM_GLOW_LIGHT.r, SWARM_GLOW_LIGHT.g, SWARM_GLOW_LIGHT.b, 1.0 * flicker))

@export var is_gallery_preview := false

func _ready() -> void:
	_lock_visual_orientation()
	body = get_node_or_null("Body") as ColorRect
	visual_root = _resolve_visual_root()

	apply_visuals()

	loop = false

	if is_gallery_preview:
		set_process(true)
		set_physics_process(false)
		queue_redraw()
		return


	add_to_group("enemies")
	_sync_spatial_target_cache(true)

	_ensure_vfx_controller()

func _lock_visual_orientation() -> void:
	# Creep textures are baked in one faux 3/4 top-down angle. Keeping the
	# PathFollow2D from rotating prevents the baked shadow from flipping on turns.
	rotates = false
	rotation = 0.0

func _exit_tree() -> void:
	_sync_spatial_target_cache(false)

func _process(delta: float) -> void:
	FrameSpikeLogger.begin("enemy_tick")
	_process_inner(delta)
	FrameSpikeLogger.end("enemy_tick")

func _process_inner(delta: float) -> void:
	if game_manager != null and (game_manager.is_paused or game_manager.is_game_over):
		return

	if is_gallery_preview or CatalogPreviewMode.is_preview_node(self):
		if not CatalogPreviewMode.is_selected_demo(self):
			set_process(false)
			queue_redraw()
			return
		pulse_time += delta
		queue_redraw()
		return

	if not is_active or is_dead_flag or reached_base_flag:
		return

	_anim_frame_counter += 1
	if _body_baked:
		# Smart LOD: LOW priority updates every 3rd frame; HIGH every frame.
		var skip := (_anim_lod == ANIM_LOD_LOW) and (_anim_frame_counter % 3 != 0)
		if not skip:
			_update_sprite_movement_anim()
			# Redraw overlay arcs only when something is active (shield/slow)
			if shield_remaining > 0 or active_slow_percent > 0:
				queue_redraw()
		# Separation: lazy scan + per-frame lerp. Lerp cost = ~3 floats, free.
		_sep_check_timer -= delta
		if _sep_check_timer <= 0.0:
			_sep_check_timer = SEP_SCAN_INTERVAL + fmod(float(get_instance_id()) * 0.0370, 0.14)
			_update_separation()
		_sep_lateral = lerpf(_sep_lateral, _sep_target, minf(delta * 5.5, 1.0))
	else:
		pulse_time += delta
		_draw_timer += delta
		if _draw_timer >= ENEMY_VISUAL_REDRAW_INTERVAL:
			_draw_timer -= ENEMY_VISUAL_REDRAW_INTERVAL
			queue_redraw()

	if not is_active or is_dead_flag or reached_base_flag:
		return

	if swarm_core_flicker_time > 0.0:
		swarm_core_flicker_time = maxf(0.0, swarm_core_flicker_time - delta)
	if enemy_type == "swarm" or tags.has("swarm"):
		swarm_pack_check_timer -= delta
		if swarm_pack_check_timer <= 0.0:
			swarm_pack_check_timer = 0.2
			_update_swarm_pack_density()
	
	# Update timers
	if slow_remaining > 0:
		slow_remaining -= delta
		if slow_remaining <= 0: clear_slow()
		
		# VISUAL: Slow particles (blue sparks)
		if not PERFORMANCE_VISUAL_MODE and Engine.get_process_frames() % 10 == 0:
			_spawn_impact_particle(Color(0.4, 0.8, 1.0, 0.6))
	
	_process_formation_speed(delta)
	
	if shield_remaining > 0:
		shield_remaining -= delta
		if shield_remaining <= 0:
			active_shield_reduction = 0.0
			active_shield_source = null
			enemy_modifier_changed.emit(self , "shield_reduction", 0.0)
			if vfx_controller:
				vfx_controller.set_protected_icon(false)
			queue_redraw()
	
	if vulnerability_remaining > 0:
		vulnerability_remaining -= delta
		if vulnerability_remaining <= 0:
			vulnerability_multiplier = 1.0
		
		# Bleed effect (blood particles)
		bleed_particle_timer -= delta
		if bleed_particle_timer <= 0:
			_spawn_bleed_particle()
			bleed_particle_timer = 0.15 # Every 150ms

	if armor_reduction_remaining > 0:
		armor_reduction_remaining -= delta
		if armor_reduction_remaining <= 0:
			armor_reduction_bonus_percent = 0.0
			enemy_modifier_changed.emit(self, "armor_reduction", 0.0)

	if root_remaining > 0:
		root_remaining -= delta
		if root_remaining <= 0:
			root_slow_percent = 0.0
			update_effective_speed()
			enemy_modifier_changed.emit(self, "root", 0.0)

	_dot_tick_timer -= delta
	_dot_tick_accum += delta
	if _dot_tick_timer <= 0.0:
		_dot_tick_timer = DOT_TICK_INTERVAL
		_process_tower_status_effects(_dot_tick_accum)
		_dot_tick_accum = 0.0

	# Skill Logic
	if skill_id != "":
		skill_timer -= delta
		match skill_id:
			"shield_aura":
				# Interval-gated: was scanning ALL enemies every frame (O(n) per bulwark).
				_shield_aura_timer -= delta
				if _shield_aura_timer <= 0.0:
					_shield_aura_timer = SHIELD_AURA_INTERVAL
					_process_shield_aura()
			"healer":
				if skill_timer <= 0:
					_process_healer_aura()
					skill_timer = skill_params.get("interval", 1.0)
			"disrupt_aura":
				# Interval-gated: was scanning ALL towers every frame (O(m) per disruptor).
				_disrupt_aura_timer -= delta
				if _disrupt_aura_timer <= 0.0:
					_disrupt_aura_timer = DISRUPT_AURA_INTERVAL
					_process_disrupt_aura()

	# Archetype Logic (Legacy)
	if is_bulwark and skill_id == "":
		_shield_aura_timer -= delta
		if _shield_aura_timer <= 0.0:
			_shield_aura_timer = SHIELD_AURA_INTERVAL
			_process_shield_aura()
		
	if is_runner:
		_process_runner_role(delta)

	if is_hunter:
		_process_hunter_ai(delta)
	else:
		_process_pathing(delta)

func _configure_runner_role(config: Dictionary) -> void:
	EnemyRoleRunner._configure_runner_role(self, config)

func _process_runner_role(delta: float) -> void:
	EnemyRoleRunner._process_runner_role(self, delta)

func _trigger_runner_dash(reason: String = "burst") -> void:
	EnemyRoleRunner._trigger_runner_dash(self, reason)

func _try_runner_hit_dash() -> void:
	EnemyRoleRunner._try_runner_hit_dash(self)

func _process_shield_aura() -> void:
	EnemySkillService._process_shield_aura(self)

func _get_skill_reduction() -> float:
	return EnemySkillService._get_skill_reduction(self)

func _process_healer_aura() -> void:
	EnemySkillService._process_healer_aura(self)


func _process_disrupt_aura() -> void:
	EnemySkillService._process_disrupt_aura(self)

func heal(amount: float, _source: Variant = null) -> float:
	if is_dead_flag or reached_base_flag or hp >= max_hp:
		return 0.0
	var before := hp
	hp = min(hp + amount, max_hp)
	var applied := hp - before
	if applied > 0.0:
		_update_health_visual_state()
		enemy_modifier_changed.emit(self , "hp", hp)
	return applied

func apply_shield(duration: float, reduction: float = shield_reduction, source: Variant = null) -> void:
	EnemyStatusService.apply_shield(self, duration, reduction, source)

func apply_vulnerability(multiplier: float, duration: float) -> void:
	EnemyStatusService.apply_vulnerability(self, multiplier, duration)

func apply_damage_amp(multiplier: float, duration: float) -> void:
	EnemyStatusService.apply_damage_amp(self, multiplier, duration)

func apply_armor_reduction(percent: float, duration: float) -> void:
	EnemyStatusService.apply_armor_reduction(self, percent, duration)

func apply_damage_over_time(damage_per_second: float, duration: float, source_id: String = "", attack_type: String = "dot") -> void:
	EnemyStatusService.apply_damage_over_time(self, damage_per_second, duration, source_id, attack_type)

func apply_root(duration: float, snare_percent: float = 1.0) -> void:
	EnemyStatusService.apply_root(self, duration, snare_percent)

func apply_delayed_damage(amount: float, delay: float, source_id: String = "", attack_type: String = "delayed") -> void:
	EnemyStatusService.apply_delayed_damage(self, amount, delay, source_id, attack_type)

func _process_hunter_ai(delta: float) -> void:
	EnemyRoleHunter._process_hunter_ai(self, delta)

func _update_hunter_target() -> void:
	EnemyRoleHunter._update_hunter_target(self)

func _is_hero_huntable(hero: Node) -> bool:
	return EnemyRoleHunter._is_hero_huntable(self, hero)

func _clear_hunter_target() -> void:
	EnemyRoleHunter._clear_hunter_target(self)

func _move_toward_hero(target_pos: Vector2, delta: float) -> void:
	EnemyRoleHunter._move_toward_hero(self, target_pos, delta)

func _face_hunter_target(_target_pos: Vector2, _delta: float) -> void:
	EnemyRoleHunter._face_hunter_target(self, _target_pos, _delta)

func _attack_hero(hero: Node) -> void:
	EnemyRoleHunter._attack_hero(self, hero)

func _process_pathing(delta: float) -> void:
	EnemyMovementService._process_pathing(self, delta)

func set_dynamic_pathing(manager: Node, spawn_cell: Vector2i) -> void:
	EnemyMovementService.set_dynamic_pathing(self, manager, spawn_cell)

func set_pathfinding_manager(manager: Node) -> void:
	EnemyMovementService.set_pathfinding_manager(self, manager)

func request_path_to_core() -> void:
	EnemyMovementService.request_path_to_core(self)

func on_navigation_grid_changed(version: int) -> void:
	EnemyMovementService.on_navigation_grid_changed(self, version)

func _process_dynamic_pathing(delta: float) -> void:
	EnemyMovementService._process_dynamic_pathing(self, delta)

func _recalculate_dynamic_path() -> void:
	EnemyMovementService._recalculate_dynamic_path(self)

func _sync_spatial_target_cache(register_if_missing: bool) -> void:
	EnemyMovementService._sync_spatial_target_cache(self, register_if_missing)

func get_last_damage_source() -> String:
	return last_damage_source

func take_damage(amount: float, hit_global: Vector2 = Vector2.ZERO, source_id: String = "", p_attack_type: String = "single") -> void:
	if CatalogPreviewMode.is_preview_node(self):
		return
	if is_dead_flag or reached_base_flag: return
	
	if source_id != "":
		last_damage_source = source_id
	
	var final_damage = amount
	if is_runner and runner_dash_remaining > 0.0:
		final_damage *= (1.0 - runner_dash_damage_reduction)
		_spawn_impact_particle(Color(1.0, 0.48, 0.08, 0.35))
	if shield_remaining > 0 and not is_bulwark:
		var shielded_damage: float = final_damage * (1.0 - active_shield_reduction)
		shield_applied.emit(self , final_damage, shielded_damage, active_shield_source)
		final_damage = shielded_damage
		if OS.is_debug_build() and _verbose_combat:
			print("[EnemyFeature][Shield] target=%s source=%s original=%.1f final=%.1f reduction=%.2f" % [
				enemy_type,
				active_shield_source.get_enemy_type() if active_shield_source and active_shield_source.has_method("get_enemy_type") else "unknown",
				amount,
				final_damage,
				active_shield_reduction
			])
			
	var capture_pos = hit_global if hit_global != Vector2.ZERO else global_position
	
	# Apply vulnerability
	if vulnerability_remaining > 0:
		final_damage *= vulnerability_multiplier
	if armor_reduction_remaining > 0:
		final_damage *= 1.0 + armor_reduction_bonus_percent
		
	hp -= final_damage
	_update_health_visual_state()
	
	var gm = get_tree().current_scene.get_node_or_null("GameManager")
	if gm and gm.battle_telemetry:
		gm.battle_telemetry.log_damage(source_id, final_damage, p_attack_type, enemy_type)
	var damage_stats := get_tree().current_scene.get_node_or_null("DamageStatsTracker")
	if damage_stats and damage_stats.has_method("record_damage"):
		damage_stats.record_damage(source_id, final_damage)
		
	flash_body(source_id if source_id != "" else p_attack_type)
	var dn_color = Color.WHITE
	if shield_remaining > 0 and not is_bulwark:
		dn_color = Color(0.4, 0.8, 1.0)
	elif source_id.begins_with("disease_"):
		dn_color = Color(0.58, 1.0, 0.28)

	spawn_damage_number(int(final_damage), capture_pos, dn_color, source_id)
	_play_hit_pulse()
	if _body_baked:
		# One heavy impact path only. flash_body() resolves comfort colour/LOD;
		# this call owns the baked-sprite tween so rapid hits cannot double-trigger it.
		var impact_color: Color = hit_flash_color if hit_flash_color.a > 0.0 else dn_color
		if dn_color != Color.WHITE:
			impact_color = dn_color
		_play_sprite_hit_impact(impact_color)
		# Hit spark: tiny burst at impact point — replaces screen shake as impact cue.
		_spawn_hit_spark(capture_pos, dn_color)
	_try_runner_hit_dash()
	if enemy_type == "swarm" or tags.has("swarm"):
		_trigger_swarm_hit_reaction()
		_spawn_swarm_hit_effect(capture_pos)
	
	if hp <= 0:
		die(capture_pos)

func apply_slow(percent: float, duration: float) -> void:
	EnemyStatusService.apply_slow(self, percent, duration)

func clear_slow() -> void:
	EnemyStatusService.clear_slow(self)

func _configure_formation_speed() -> void:
	if formation_speed_limit > 0.0 and formation_limit_duration > 0.0 and base_speed > 0.0:
		formation_target_multiplier = clampf(formation_speed_limit / base_speed, 0.25, 1.0)
		formation_speed_multiplier = formation_target_multiplier
	elif formation_limit_duration > 0.0 and formation_config_multiplier < 1.0:
		formation_target_multiplier = clampf(formation_config_multiplier, 0.25, 1.0)
		formation_speed_multiplier = formation_target_multiplier
	else:
		formation_target_multiplier = 1.0
		formation_speed_multiplier = 1.0
	if formation_speed_multiplier < 1.0:
		enemy_modifier_changed.emit(self , "formation_speed_multiplier", formation_speed_multiplier)

func _process_formation_speed(delta: float) -> void:
	if formation_limit_duration > 0.0:
		formation_limit_duration -= delta
		if formation_limit_duration <= 0.0:
			formation_limit_duration = 0.0
			formation_target_multiplier = 1.0
			enemy_modifier_changed.emit(self , "formation_speed_multiplier", formation_target_multiplier)
			if vfx_controller and (tags.has("fast") or tags.has("runner") or enemy_type in ["fast", "runner", "hunter", "fast_flyer"]):
				vfx_controller.play_runner_burst()
			if OS.is_debug_build() and _verbose_combat:
				print("[SpawnFormation] release throttle enemy=%s base_speed=%.1f effective_speed=%.1f" % [enemy_type, base_speed, speed])
	if formation_speed_multiplier != formation_target_multiplier:
		if formation_speed_multiplier > formation_target_multiplier:
			formation_speed_multiplier = formation_target_multiplier
		else:
			formation_speed_multiplier = move_toward(formation_speed_multiplier, formation_target_multiplier, formation_release_rate * delta)
		update_effective_speed()

func update_effective_speed() -> void:
	EnemyStatusService.update_effective_speed(self)

func _process_tower_status_effects(delta: float) -> void:
	EnemyStatusService._process_tower_status_effects(self, delta)

func flash_body(damage_context: String = "") -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	# Baked sprites resolve colour/LOD here, then take_damage() plays the single
	# heavy impact path. Keeping tween ownership in one place avoids double hits.
	if _body_baked:
		var fc: Color = Color(1.0, 0.62, 0.26, 0.20)
		if comfort != null and comfort.has_method("get_hit_flash_color"):
			fc = comfort.get_hit_flash_color(damage_context)
		hit_flash_color = fc
		hit_flash_alpha = 0.0
		is_flashing = false
		_set_anim_lod_high()
		return
	if comfort != null and comfort.has_method("should_skip_hit_flash") and comfort.should_skip_hit_flash():
		return
	if comfort != null and comfort.has_method("allow_flash"):
		if not comfort.allow_flash("hit_%s" % get_instance_id()):
			return
	if not is_visible_in_tree():
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid() and _hit_flash_tween.is_running():
		return

	if comfort != null and comfort.has_method("get_hit_flash_color"):
		hit_flash_color = comfort.get_hit_flash_color(damage_context)
	else:
		hit_flash_color = Color(1.0, 0.62, 0.26, 0.20)
	hit_flash_alpha = minf(hit_flash_color.a, 0.22)
	is_flashing = hit_flash_alpha > 0.01
	_set_anim_lod_high()   # hit = always full animation
	queue_redraw()

	var duration := 0.08
	if comfort != null and comfort.has_method("get_hit_flash_duration"):
		duration = float(comfort.get_hit_flash_duration())
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "hit_flash_alpha", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hit_flash_tween.tween_callback(func():
		is_flashing = false
		queue_redraw()
	)

func spawn_damage_number(amount: int, hit_global: Vector2, color: Color = Color.WHITE, source_id: String = "") -> void:
	if PerformanceFirebreak.disable_damage_numbers: return
	if _get_nearby_enemy_count(CROWDED_ENEMY_RADIUS) >= CROWDED_ENEMY_THRESHOLD and amount < int(max_hp * 0.18):
		return
	var perf_service := get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("allow_floating_damage_number"):
		if not perf_service.allow_floating_damage_number():
			return
	elif not SHOW_FLOATING_DAMAGE_NUMBERS:
		return
	# Budget cap — skip new labels when too many are already alive.
	if DamageNumber._active_count >= DamageNumber.MAX_ACTIVE:
		return
	if damage_number_scene:
		var pool := get_node_or_null("/root/VisualEffectPoolService")
		var parent_node: Node = get_tree().current_scene
		var dn: Node = null
		if pool != null and pool.has_method("acquire_scene"):
			dn = pool.acquire_scene("damage_number", parent_node, "damage_number")
		if dn == null:
			return
		var offset := Vector2(randf_range(-5, 5), -20 + randf_range(-5, 5))
		if source_id.begins_with("disease_"):
			offset = Vector2(randf_range(-12, 12), -12 + randf_range(-3, 3))
		dn.global_position = hit_global + offset
		dn.setup(amount, color)

func die(death_global: Vector2 = Vector2.ZERO) -> void:
	EnemyDeathService.die(self, death_global)

func _handle_split_on_death(_death_pos: Vector2) -> void:
	EnemySkillService._handle_split_on_death(self, _death_pos)

func notify_stealth_deferred(preferred_target: Node) -> void:
	EnemySkillService.notify_stealth_deferred(self, preferred_target)

func notify_stealth_targetable() -> void:
	EnemySkillService.notify_stealth_targetable(self)

func _clear_disrupted_towers() -> void:
	EnemySkillService._clear_disrupted_towers(self)

func _get_death_burst_color() -> Color:
	return EnemyDeathService._get_death_burst_color(self)

func _get_death_importance() -> float:
	return EnemyDeathService._get_death_importance(self)

func _trigger_death_shake() -> void:
	EnemyDeathService._trigger_death_shake(self)

func spawn_death_effect(death_global: Vector2) -> void:
	EnemyDeathService.spawn_death_effect(self, death_global)

func reach_base() -> void:
	EnemyDeathService.reach_base(self)

func is_alive() -> bool:
	return hp > 0 and not reached_base_flag and not is_dead_flag

func _play_hit_pulse() -> void:
	if PerformanceFirebreak.disable_cosmetic_tweens:
		return
	if not is_visible_in_tree():
		return
	if _hit_pulse_tween != null and _hit_pulse_tween.is_valid() and _hit_pulse_tween.is_running():
		return
	_hit_pulse_tween = create_tween()
	var tween := _hit_pulse_tween
	var is_swarm := enemy_type == "swarm" or tags.has("swarm")
	var s = randf_range(1.08, 1.14) if is_swarm else randf_range(1.15, 1.25)
	# Scale-squeeze on the PathFollow2D root is safe: PathFollow2D._update_transform()
	# recalculates position/rotation from progress but never resets scale.
	tween.tween_property(self, "scale", Vector2(s, 1.0 / s), 0.025 if is_swarm else 0.04).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2.ONE, 0.055 if is_swarm else 0.08).set_trans(Tween.TRANS_BACK)

	# Hit shake: MUST target the child visual node, not the PathFollow2D root.
	# Tweening self.position on a PathFollow2D fights _update_transform() which
	# recomputes position from progress every frame — causing the creep to snap/warp
	# off the path after each hit (especially visible on control-family area hits).
	var shake_target: Node2D = visual_root if (visual_root != null and visual_root != self) else null
	if shake_target != null:
		if _hit_shake_tween != null and _hit_shake_tween.is_valid() and _hit_shake_tween.is_running():
			return
		var original_pos := shake_target.position
		_hit_shake_tween = create_tween()
		var shake_tween := _hit_shake_tween
		var shake_strength := 1.4 if is_swarm else 3.0
		var shake_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * shake_strength
		shake_tween.tween_property(shake_target, "position", original_pos + shake_dir, 0.018 if is_swarm else 0.03)
		shake_tween.tween_property(shake_target, "position", original_pos, 0.018 if is_swarm else 0.03)

func _trigger_swarm_hit_reaction() -> void:
	swarm_core_flicker_time = 0.08

func _spawn_swarm_hit_effect(hit_global: Vector2) -> void:
	if death_pop_scene == null:
		return
	if PerformanceFirebreak.disable_death_effects: return
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	var effect: Node = null
	if pool != null and pool.has_method("acquire_scene"):
		effect = pool.acquire_scene("death_pop", container, "death_pop")
	if effect == null:
		return
	effect.global_position = hit_global
	if effect.has_method("setup"):
		effect.setup("swarm_hit", swarm_core_glow_color, 0.18, 6)

func _update_swarm_pack_density() -> void:
	var nearby := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var node_tags: Array = node.get("tags")
		if str(node.get("enemy_type")) != "swarm" and not node_tags.has("swarm"):
			continue
		var other := node as Node2D
		if global_position.distance_to(other.global_position) <= 42.0:
			nearby += 1
			if nearby >= 6:
				break
	swarm_pack_density = clampf(float(nearby) / 6.0, 0.0, 1.0)

func get_priority_score() -> float:
	var score = 1.0
	if tags.has("fast"): score = 1.2
	if is_hunter: score = 1.4
	if is_bulwark: score = 1.6
	return score

func get_path_progress() -> float:
	if use_dynamic_pathing:
		return dynamic_travel_distance
	return progress

func get_current_hp() -> float:
	return hp

func get_enemy_type() -> String:
	return enemy_type

func get_movement_speed() -> float:
	return base_speed

func _spawn_bleed_particle() -> void:
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_script"):
		return
	var p := pool.acquire_script(load("res://scripts/effects/bleed_particle.gd"), container, "bleed_particle", "enemy_impact") as Node2D
	if p == null:
		return
	# Spawn randomly around center
	var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	p.global_position = global_position + offset
	if p.has_method("reset_particle"):
		p.reset_particle()

func _spawn_impact_particle(color: Color) -> void:
	var perf_service := get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("get_budget") and not bool(perf_service.get_budget("allow_minor_impacts")):
		return
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	
	var imp_pool := get_node_or_null("/root/ImpactVFXPool")
	if imp_pool != null:
		var effect: Node = imp_pool.acquire(container)
		if effect == null:
			return
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		effect.global_position = global_position + offset
		if effect.has_method("setup"):
			effect.setup(color, 0.4)

func _transform_points(points: PackedVector2Array, angle: float, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var t := Transform2D(angle, offset)
	for p in points:
		out.append(t * p)
	return out


func _mirror_points_y(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x, -p.y))
	return out

func _draw_swarm_forward_motion_fx(origin: Vector2, size: float, pulse: float, flicker: float) -> void:
	var nose := origin + Vector2(size * 1.20, 0.0)

	draw_arc(
		nose + Vector2(size * (0.30 + pulse * 0.05), 0.0),
		size * (0.36 + pulse * 0.06),
		-0.58,
		0.58,
		18,
		Color(SWARM_GLOW_LIGHT.r, SWARM_GLOW_LIGHT.g, SWARM_GLOW_LIGHT.b, 0.28 * flicker),
		1.25
	)

	draw_arc(
		nose + Vector2(size * (0.48 + pulse * 0.06), 0.0),
		size * (0.58 + pulse * 0.04),
		-0.42,
		0.42,
		16,
		Color(swarm_core_glow_color.r, swarm_core_glow_color.g, swarm_core_glow_color.b, 0.13 * flicker),
		1.0
	)

	var slash_color := Color(SWARM_GLOW_LIGHT.r, SWARM_GLOW_LIGHT.g, SWARM_GLOW_LIGHT.b, 0.46 * flicker)

	draw_polyline(
		PackedVector2Array([
			nose + Vector2(size * 0.04, -size * 0.30),
			nose + Vector2(size * 0.42, -size * 0.10),
			nose + Vector2(size * 0.14, -size * 0.01)
		]),
		slash_color,
		1.1
	)

	draw_polyline(
		PackedVector2Array([
			nose + Vector2(size * 0.04, size * 0.30),
			nose + Vector2(size * 0.42, size * 0.10),
			nose + Vector2(size * 0.14, size * 0.01)
		]),
		slash_color,
		1.1
	)
	
func _draw_swarm_thruster_fx(origin: Vector2, size: float, pulse: float, flicker: float) -> void:
	var plume_len := size * (1.18 + pulse * 0.24)
	var plume_w := size * (0.20 + pulse * 0.04)

	var rear_ports := [
		origin + Vector2(-size * 0.62, -size * 0.22),
		origin + Vector2(-size * 0.72, 0.0),
		origin + Vector2(-size * 0.62, size * 0.22)
	]

	for i in range(rear_ports.size()):
		var port: Vector2 = rear_ports[i]
		var center_boost := 1.18 if i == 1 else 1.0
		var spread := plume_w * (0.86 if i == 1 else 0.72)
		var length := plume_len * center_boost

		var outer_plume := PackedVector2Array([
			port + Vector2(0.0, -spread),
			port + Vector2(-length, -spread * 0.36),
			port + Vector2(-length * 1.12, 0.0),
			port + Vector2(-length, spread * 0.36),
			port + Vector2(0.0, spread)
		])

		var inner_plume := PackedVector2Array([
			port + Vector2(-size * 0.03, -spread * 0.44),
			port + Vector2(-length * 0.68, -spread * 0.18),
			port + Vector2(-length * 0.82, 0.0),
			port + Vector2(-length * 0.68, spread * 0.18),
			port + Vector2(-size * 0.03, spread * 0.44)
		])

		var hot_core := PackedVector2Array([
			port + Vector2(-size * 0.22, -spread * 0.18),
			port + Vector2(-length * 1.42, 0.18),
			port + Vector2(-size * 0.22, spread * 0.18)
		])

		draw_colored_polygon(
			outer_plume,
			Color(SWARM_TRAIL_COLOR.r, SWARM_TRAIL_COLOR.g, SWARM_TRAIL_COLOR.b, 0.16 + pulse * 0.05)
		)

		draw_colored_polygon(
			inner_plume,
			Color(SWARM_ACCENT_AMBER.r, SWARM_ACCENT_AMBER.g, SWARM_ACCENT_AMBER.b, 0.18 + pulse * 0.08)
		)

		draw_colored_polygon(
			hot_core,
			Color(SWARM_ACCENT_HOT.r, SWARM_ACCENT_HOT.g, SWARM_ACCENT_HOT.b, 0.34 + pulse * 0.14)
		)

		draw_circle(
			port,
			size * 0.095,
			Color(SWARM_GLOW_LIGHT.r, SWARM_GLOW_LIGHT.g, SWARM_GLOW_LIGHT.b, 0.9 * flicker)
		)

		draw_circle(
			port + Vector2(-size * 0.04, 0.0),
			size * 0.17,
			Color(SWARM_ACCENT_AMBER.r, SWARM_ACCENT_AMBER.g, SWARM_ACCENT_AMBER.b, 0.20 * flicker)
		)
