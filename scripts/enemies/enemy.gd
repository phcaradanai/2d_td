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
const PERFORMANCE_VISUAL_MODE := true # Simplified silhouette rendering for 60 FPS
const ENEMY_VISUAL_REDRAW_INTERVAL := 0.125 # 8 FPS visual update (was 1/30 = 30 FPS)
const ENEMY_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.74)
const ENEMY_OUTLINE_THICKNESS := 2.0
const SHOW_FLOATING_DAMAGE_NUMBERS := false
enum HealthVisualState {HEALTH_OK, HEALTH_DAMAGED, HEALTH_CRITICAL}
var health_visual_state: int = HealthVisualState.HEALTH_OK

# Baker-style body sprite — replaces procedural _draw() body (15→1 draw call).
var _body_sprite: Sprite2D = null
var _body_baked: bool = false
var _baked_health_state: int = -1
var _bake_scale: Vector2 = Vector2(0.5, 0.5) # set in _apply_baked_enemy_texture

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
var _anim_phase: float = 0.0 # unique bob phase per enemy (0..TAU)
var _perp_drift_amp: float = 0.0 # lateral drift amplitude in local-Y px
var _perp_drift_freq: float = 0.0 # drift cycles per px of path progress
var _visual_heading_angle: float = 0.0

# Lazy separation — scan nearby enemies every ~0.4 s, smoothly push apart visually.
# Visual angle is locked, so this is a screen-local Y offset and never moves gameplay hitboxes.
var _sep_lateral: float = 0.0 # current smoothed lateral offset (px)
var _sep_target: float = 0.0 # target lateral from last avoidance scan
var _sep_check_timer: float = 0.0 # countdown to next scan
var _spawn_spread_lateral: float = 0.0 # early visual-only lane offset; fades with progress

const SEP_SCAN_INTERVAL := 0.38 # base seconds between scans per enemy
const SEP_SCAN_RADIUS_SQ := 784.0 # 28 px² — world-space proximity filter
const SEP_PUSH_MAX := 7.0 # max px pushed per overlapping neighbour
const SEP_ROAD_HALF := 14.0 # max combined lateral offset from path center
const SPAWN_SPREAD_FADE_DISTANCE := 220.0

# Smart Visual LOD — prioritises CPU for hero moments, saves it for background creeps.
# LOW (0): healthy, not in combat  → animate every 3rd frame, no glow
# HIGH (2): low HP, hit recently   → animate every frame, red pulse glow
const ANIM_LOD_LOW := 0
const ANIM_LOD_HIGH := 2
var _anim_lod: int = ANIM_LOD_LOW
var _anim_frame_counter: int = 0 # incremented in _process, used to skip frames
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
	return EnemyBakedSpriteService._resolve_visual_root(self)
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
	EnemySetupService.apply_setup(self , config)

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
	EnemyVisualRenderer.draw_enemy(self )

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
	EnemyBakedSpriteService._request_baked_enemy_texture(self)
	if is_gallery_preview:
		return
	# Defer until we're in the scene tree so add_child / callbacks work safely.
	if not is_inside_tree():
		call_deferred("_request_baked_enemy_texture")
		return
	var vt: String = str(visual_type)
	var hs: int = health_visual_state
	var captured := self
	EnemyTextureBaker.request_texture(vt, hs, func(tex: ImageTexture) -> void:
		if not is_instance_valid(captured):
			return
		captured._apply_baked_enemy_texture(tex)
	)

func _apply_baked_enemy_texture(tex: ImageTexture) -> void:
	EnemyBakedSpriteService._apply_baked_enemy_texture(self, tex)
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
				var a := float(i) / 22.0 * TAU
				pts.append(Vector2(cos(a) * rx, sin(a) * ry))
			_shadow_node.draw_colored_polygon(pts, Color(0, 0, 0, alpha))
			var core := PackedVector2Array()
			for i in 18:
				var a := float(i) / 18.0 * TAU
				core.append(Vector2(cos(a) * rx * 0.58, sin(a) * ry * 0.62))
			_shadow_node.draw_colored_polygon(core, Color(0, 0, 0, alpha * 0.72))
		)
		add_child(_shadow_node)
		move_child(_shadow_node, 0)
		_shadow_node.queue_redraw()

	_bake_scale = Vector2.ONE / float(EnemyTextureBaker.BAKE_ZOOM)
	_body_sprite.texture = tex
	_body_sprite.scale = _bake_scale
	_body_sprite.visible = true
	_baked_health_state = health_visual_state
	if not _body_baked:
		# First time baked: pop-in spawn animation
		_body_sprite.scale = Vector2.ZERO
		var spawn_tw := create_tween()
		spawn_tw.tween_property(_body_sprite, "scale", _bake_scale, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_baked = true
	queue_redraw()

## Per-type lateral drift amplitude (px). Fast/small types drift more; tanks barely move.
func _get_type_drift_amp(vtype: String) -> float:
	return EnemyBakedSpriteService._get_type_drift_amp(self, vtype)
	match vtype:
		"swarm": return 9.0
		"fast", "runner", "fast_flyer": return 7.5
		"cloaked": return 7.0
		"basic", "healer", "splitter", "disruptor": return 6.0
		"hunter", "flyer", "armored_flyer": return 5.5
		"tank", "bulwark", "shieldbearer": return 3.0
		_: return 6.0

## Spawn spread is visual-only and decays during the first few road tiles.
## It keeps dense starts from reading as one stacked train without moving gameplay hitboxes.
func _get_type_spawn_spread(vtype: String) -> float:
	return EnemyBakedSpriteService._get_type_spawn_spread(self, vtype)
	match vtype:
		"swarm": return 10.0
		"fast", "runner", "fast_flyer": return 8.5
		"tank", "bulwark", "shieldbearer": return 4.5
		"flyer", "armored_flyer": return 6.0
		_: return 7.0

## Lazy separation — pushes _sep_target away from nearby overlapping enemies.
## Called ~every 0.4 s per enemy (staggered), NOT every frame.
func _update_separation() -> void:
	EnemyVisualCrowdService._update_separation(self)
	var push := 0.0
	var pb := get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = (pb.get_enemies() if pb != null and pb.has_method("get_enemies")
						 else get_tree().get_nodes_in_group("enemies"))
	var my_pos := global_position
	var my_prog := get_path_progress()
	for other in enemies:
		if other == self or not is_instance_valid(other): continue
		var op: Vector2 = other.global_position
		var dx := op.x - my_pos.x
		var dy := op.y - my_pos.y
		if dx * dx + dy * dy > SEP_SCAN_RADIUS_SQ: continue # world-distance guard
		if not other.has_method("get_path_progress"): continue
		if absf(my_prog - other.get_path_progress()) > 32.0: continue # far on path
		# Determine push direction — must differ between the two enemies in a pair
		var other_lat: float = float(other.get("_sep_lateral"))
		var gap := _sep_lateral - other_lat
		var push_dir: float
		if absf(gap) > 2.0:
			push_dir = signf(gap) # already separated: reinforce it
		else:
			# Tie-break via relative instance IDs — guarantees opposite dirs per pair
			push_dir = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
		var dist_sq := dx * dx + dy * dy
		push += push_dir * SEP_PUSH_MAX * (1.0 - dist_sq / SEP_SCAN_RADIUS_SQ)
	# Decay toward 0 when alone; clamp to road half-width
	if absf(push) < 0.1:
		push = _sep_target * -0.25 # gentle return to center when isolated
	_sep_target = clampf(push, -SEP_ROAD_HALF, SEP_ROAD_HALF)

func _uses_glide_motion(vtype: String) -> bool:
	return EnemyBakedSpriteService._uses_glide_motion(self, vtype)
	return vtype == "fast" or vtype == "runner" or vtype == "fast_flyer" or vtype == "hunter"

func _uses_directional_visual(vtype: String) -> bool:
	return EnemyBakedSpriteService._uses_directional_visual(self, vtype)
	return vtype == "fast" or vtype == "runner" or vtype == "fast_flyer" or vtype == "hunter"

func _record_visual_movement_delta(delta_pos: Vector2) -> void:
	EnemyBakedSpriteService._record_visual_movement_delta(self, delta_pos)
	if delta_pos.length_squared() <= 0.01:
		return
	_visual_heading_angle = delta_pos.angle()

func _get_body_visual_rotation() -> float:
	return EnemyBakedSpriteService._get_body_visual_rotation(self)
	if _uses_directional_visual(visual_type):
		return _visual_heading_angle
	return 0.0

## Per-type bob intensity — pointed fast units glide; compact bodies can bounce.
func _get_type_bob_intensity(vtype: String) -> float:
	return EnemyBakedSpriteService._get_type_bob_intensity(self, vtype)
	match vtype:
		"tank", "bulwark", "shieldbearer": return 0.55
		"swarm": return 0.85
		"fast", "runner", "fast_flyer": return 0.34
		"hunter": return 0.48
		_: return 1.0

## Walking squash/stretch — called every frame when baked. No queue_redraw.
func _update_sprite_movement_anim() -> void:
	EnemyBakedSpriteService._update_sprite_movement_anim(self)
	if not _body_baked or _body_sprite == null or _hit_impact_active:
		return
	var speed_ratio := clampf(speed / maxf(base_speed, 1.0), 0.0, 2.2)
	if speed_ratio < 0.02:
		_body_sprite.scale = _bake_scale
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
		_bake_scale.x * (1.0 - bob * 0.20), # narrow on upstroke
		_bake_scale.y * (1.0 + bob * 0.30) # tall on upstroke, short on downstroke
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
	EnemyBakedSpriteService._update_sprite_glide_motion(self, path_px, speed_ratio)
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
func _get_nearby_enemy_count(radius: float) -> int:
	return EnemyVisualCrowdService._get_nearby_enemy_count(self, radius)
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
	_body_sprite.scale = _bake_scale * clampf(1.15 + imp * 0.12, 1.15, 1.6)
	_body_sprite.modulate = Color(2.2, 2.2, 2.2, 0.0)

## Escalate LOD: full-rate animation + hit emphasis from now on.
func _set_anim_lod_high() -> void:
	_anim_lod = ANIM_LOD_HIGH

## Pulsing red glow on sprite when enemy is near death — draws attention to threats.
func _start_near_death_glow() -> void:
	if not _body_baked or _body_sprite == null or not is_instance_valid(_body_sprite):
		return
	if _death_glow_tween != null and _death_glow_tween.is_valid():
		return # already pulsing
	_death_glow_tween = create_tween().set_loops()
	_death_glow_tween.tween_property(_body_sprite, "modulate",
		Color(1.6, 0.55, 0.55, 1.0), 0.28).set_trans(Tween.TRANS_SINE)
	_death_glow_tween.tween_property(_body_sprite, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.28).set_trans(Tween.TRANS_SINE)

# --- High-Fidelity Procedural Visuals ---

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

	if is_gallery_preview or CatalogPreviewMode.is_preview_node(self ):
		if not CatalogPreviewMode.is_selected_demo(self ):
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
			enemy_modifier_changed.emit(self , "armor_reduction", 0.0)

	if root_remaining > 0:
		root_remaining -= delta
		if root_remaining <= 0:
			root_slow_percent = 0.0
			update_effective_speed()
			enemy_modifier_changed.emit(self , "root", 0.0)

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
	EnemyRoleRunner._configure_runner_role(self , config)

func _process_runner_role(delta: float) -> void:
	EnemyRoleRunner._process_runner_role(self , delta)

func _trigger_runner_dash(reason: String = "burst") -> void:
	EnemyRoleRunner._trigger_runner_dash(self , reason)

func _try_runner_hit_dash() -> void:
	EnemyRoleRunner._try_runner_hit_dash(self )

func _process_shield_aura() -> void:
	EnemySkillService._process_shield_aura(self )

func _get_skill_reduction() -> float:
	return EnemySkillService._get_skill_reduction(self )

func _process_healer_aura() -> void:
	EnemySkillService._process_healer_aura(self )


func _process_disrupt_aura() -> void:
	EnemySkillService._process_disrupt_aura(self )

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
	EnemyStatusService.apply_shield(self , duration, reduction, source)

func apply_vulnerability(multiplier: float, duration: float) -> void:
	EnemyStatusService.apply_vulnerability(self , multiplier, duration)

func apply_damage_amp(multiplier: float, duration: float) -> void:
	EnemyStatusService.apply_damage_amp(self , multiplier, duration)

func apply_armor_reduction(percent: float, duration: float) -> void:
	EnemyStatusService.apply_armor_reduction(self , percent, duration)

func apply_damage_over_time(damage_per_second: float, duration: float, source_id: String = "", attack_type: String = "dot") -> void:
	EnemyStatusService.apply_damage_over_time(self , damage_per_second, duration, source_id, attack_type)

func apply_root(duration: float, snare_percent: float = 1.0) -> void:
	EnemyStatusService.apply_root(self , duration, snare_percent)

func apply_delayed_damage(amount: float, delay: float, source_id: String = "", attack_type: String = "delayed") -> void:
	EnemyStatusService.apply_delayed_damage(self , amount, delay, source_id, attack_type)

func _process_hunter_ai(delta: float) -> void:
	EnemyRoleHunter._process_hunter_ai(self , delta)

func _update_hunter_target() -> void:
	EnemyRoleHunter._update_hunter_target(self )

func _is_hero_huntable(hero: Node) -> bool:
	return EnemyRoleHunter._is_hero_huntable(self , hero)

func _clear_hunter_target() -> void:
	EnemyRoleHunter._clear_hunter_target(self )

func _move_toward_hero(target_pos: Vector2, delta: float) -> void:
	EnemyRoleHunter._move_toward_hero(self , target_pos, delta)

func _face_hunter_target(_target_pos: Vector2, _delta: float) -> void:
	EnemyRoleHunter._face_hunter_target(self , _target_pos, _delta)

func _attack_hero(hero: Node) -> void:
	EnemyRoleHunter._attack_hero(self , hero)

func _process_pathing(delta: float) -> void:
	EnemyMovementService._process_pathing(self , delta)

func set_dynamic_pathing(manager: Node, spawn_cell: Vector2i) -> void:
	EnemyMovementService.set_dynamic_pathing(self , manager, spawn_cell)

func set_pathfinding_manager(manager: Node) -> void:
	EnemyMovementService.set_pathfinding_manager(self , manager)

func request_path_to_core() -> void:
	EnemyMovementService.request_path_to_core(self )

func on_navigation_grid_changed(version: int) -> void:
	EnemyMovementService.on_navigation_grid_changed(self , version)

func _process_dynamic_pathing(delta: float) -> void:
	EnemyMovementService._process_dynamic_pathing(self , delta)

func _recalculate_dynamic_path() -> void:
	EnemyMovementService._recalculate_dynamic_path(self )

func _sync_spatial_target_cache(register_if_missing: bool) -> void:
	EnemyMovementService._sync_spatial_target_cache(self , register_if_missing)

func get_last_damage_source() -> String:
	return last_damage_source

func take_damage(amount: float, hit_global: Vector2 = Vector2.ZERO, source_id: String = "", p_attack_type: String = "single") -> void:
	EnemyDamagePipeline.take_damage(self, amount, hit_global, source_id, p_attack_type)

func apply_slow(percent: float, duration: float) -> void:
	EnemyStatusService.apply_slow(self , percent, duration)

func clear_slow() -> void:
	EnemyStatusService.clear_slow(self )

func _configure_formation_speed() -> void:
	EnemyFormationService._configure_formation_speed(self)
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
	EnemyFormationService._process_formation_speed(self, delta)
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
	EnemyStatusService.update_effective_speed(self )

func _process_tower_status_effects(delta: float) -> void:
	EnemyStatusService._process_tower_status_effects(self , delta)

func flash_body(damage_context: String = "") -> void:
	EnemyHitFeedbackService.flash_body(self , damage_context)

func spawn_damage_number(amount: int, hit_global: Vector2, color: Color = Color.WHITE, source_id: String = "") -> void:
	EnemyHitFeedbackService.spawn_damage_number(self , amount, hit_global, color, source_id)

func die(death_global: Vector2 = Vector2.ZERO) -> void:
	EnemyDeathService.die(self , death_global)

func _handle_split_on_death(_death_pos: Vector2) -> void:
	EnemySkillService._handle_split_on_death(self , _death_pos)

func notify_stealth_deferred(preferred_target: Node) -> void:
	EnemySkillService.notify_stealth_deferred(self , preferred_target)

func notify_stealth_targetable() -> void:
	EnemySkillService.notify_stealth_targetable(self )

func _clear_disrupted_towers() -> void:
	EnemySkillService._clear_disrupted_towers(self )

func _get_death_burst_color() -> Color:
	return EnemyDeathService._get_death_burst_color(self )

func _get_death_importance() -> float:
	return EnemyDeathService._get_death_importance(self )

func _trigger_death_shake() -> void:
	EnemyDeathService._trigger_death_shake(self )

func spawn_death_effect(death_global: Vector2) -> void:
	EnemyDeathService.spawn_death_effect(self , death_global)

func reach_base() -> void:
	EnemyDeathService.reach_base(self )

func is_alive() -> bool:
	return hp > 0 and not reached_base_flag and not is_dead_flag

func _update_swarm_pack_density() -> void:
	EnemyVisualCrowdService._update_swarm_pack_density(self)
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
