extends PathFollow2D

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

# Effects status
var active_slow_percent: float = 0.0
var slow_remaining: float = 0.0
var shield_remaining: float = 0.0
var active_shield_reduction: float = 0.0
var active_shield_source: Node = null
var is_flashing: bool = false
var vulnerability_multiplier: float = 1.0
var vulnerability_remaining: float = 0.0
var bleed_particle_timer: float = 0.0

# Special Archetypes
var is_bulwark: bool = false
var is_hunter: bool = false

var last_damage_source: String = ""
var tags: Array = []

# Visual State
var pulse_time: float = 0.0
var swarm_core_flicker_time: float = 0.0
var swarm_pack_density: float = 0.0
var swarm_pack_check_timer: float = 0.0
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
@export var swarm_death_particle_count: int = 18

# Bulwark Stats
var shield_radius: float = 90.0
var shield_reduction: float = 0.30

# Hunter Stats
enum HunterState {PATHING, AGGRO_CHASING, AGGRO_ATTACKING}
var hunter_state: HunterState = HunterState.PATHING
var aggro_range: float = 160.0
var hunter_attack_range: float = 90.0
var hunter_attack_damage: float = 28.0
var hunter_attack_cooldown: float = 0.0

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

	n = get_node_or_null("VisualRoot")
	if n is Node2D:
		return n

	n = get_node_or_null("Model")
	if n is Node2D:
		return n

	n = get_node_or_null("Sprite")
	if n is Node2D:
		return n

	push_warning("[Enemy] No Body/VisualRoot/Model/Sprite found. Using self as visual root: %s" % name)
	return self
@onready var hp_bar: ProgressBar = get_node_or_null("HpBar") as ProgressBar
@onready var damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
@onready var death_pop_scene: PackedScene = preload("res://scenes/effects/DeathPopEffect.tscn")
@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
const ENEMY_VFX_CONTROLLER_SCRIPT := preload("res://scripts/effects/enemy_vfx_controller.gd")

var vfx_controller: Node = null


func setup(config: Dictionary) -> void:
	enemy_type = config.get("id", config.get("enemy_type", "basic"))
	enemy_category = normalize_enemy_category(config.get("category", ENEMY_CATEGORY_LAND))
	display_name = config.get("name", "Enemy")
	visual_type = config.get("visual_type", "basic")
	tags = config.get("tags", [])
	skill_id = config.get("skill", "")
	skill_params = config.get("skill_params", {})
	
	if skill_id == "healer":
		skill_timer = float(skill_params.get("initial_delay", skill_params.get("interval", 1.0)))
	else:
		skill_timer = float(skill_params.get("initial_delay", 0.0))
	
	is_stealth = (skill_id == "stealth" or tags.has("stealth"))
	if is_stealth:
		modulate.a = 0.4 # Visual feedback for stealth
	
	is_bulwark = (enemy_type == "bulwark" or tags.has("shield"))
	is_hunter = (enemy_type == "hunter" or tags.has("anti_hero"))
	
	max_hp = config.get("max_hp", config.get("hp", 30.0))
	hp = max_hp
	base_speed = config.get("speed", 100.0)
	speed = base_speed
	reward_gold = config.get("reward_gold", 5)
	base_damage = config.get("base_damage", 1)
	
	formation_speed_limit = config.get("formation_speed_limit", -1.0)
	formation_limit_duration = config.get("formation_limit_duration", 0.0)
	formation_config_multiplier = float(config.get("formation_speed_multiplier", 1.0))
	formation_release_rate = float(config.get("formation_release_rate", formation_release_rate))
	_configure_formation_speed()
	update_effective_speed()
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	apply_visuals()
	_ensure_vfx_controller()
	
	if is_gallery_preview:
		set_process(true)
		set_physics_process(false)
		queue_redraw()
		
	var l_offset = config.get("local_offset", Vector2.ZERO)
	if l_offset is Vector2:
		h_offset = l_offset.x
		v_offset = l_offset.y
	
	is_active = true
	
	if is_gallery_preview:
		set_process(true)
		set_physics_process(false)
		queue_redraw()

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
	var size = 16.0
	if enemy_category == ENEMY_CATEGORY_AIR and not (enemy_type == "swarm" or tags.has("swarm")):
		var hover_offset := sin(pulse_time * 4.0) * 2.0
		draw_circle(Vector2(0, 12), size * 0.75, Color(0.0, 0.0, 0.0, 0.16))
		draw_arc(Vector2(0, hover_offset), size * 1.15, 0, TAU, 28, Color(0.45, 0.9, 1.0, 0.18), 1.2)
	
	if shield_remaining > 0:
		# Subtle hex-style or thin ring indicator for protected units
		var p_pulse = sin(pulse_time * 5.0) * 0.1 + 0.9
		draw_arc(Vector2.ZERO, size * 1.4 * p_pulse, 0, TAU, 16, Color(0.4, 0.8, 1.0, 0.4), 1.5)
		draw_circle(Vector2.ZERO, size * 1.4, Color(0.4, 0.8, 1.0, 0.08))
	
	if active_slow_percent > 0:
		# Frost/Slow glow
		draw_circle(Vector2.ZERO, size * 1.2, Color(0.6, 0.9, 1.0, 0.25))
		draw_arc(Vector2.ZERO, size * 1.1, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.4), 2.0)
	
	match visual_type:
		"basic":
			_draw_cyber_node(COLOR_NEON_BASIC, size)
		"fast":
			_draw_cyber_runner(COLOR_NEON_FAST, size)
		"tank":
			_draw_cyber_tank(COLOR_NEON_TANK, size * 1.4)
		"bulwark":
			_draw_cyber_bulwark(COLOR_NEON_BULWARK, size * 1.6)
		"hunter":
			_draw_cyber_hunter(COLOR_NEON_HUNTER, size * 1.3)
		"swarm":
			_draw_cyber_swarm(COLOR_NEON_FAST, size * 0.86)
		"runner":
			_draw_cyber_runner(COLOR_NEON_BASIC, size)
		"shieldbearer":
			_draw_cyber_bulwark(Color(0.3, 0.8, 1.0), size * 1.3)
		"healer":
			_draw_cyber_healer(Color(0.4, 1.0, 0.4), size * 1.1)
		"splitter":
			_draw_cyber_splitter(Color(0.8, 0.4, 1.0), size * 1.3)
		"cloaked":
			_draw_cyber_cloaked(Color(0.7, 0.7, 1.0), size)
		"flyer":
			_draw_cyber_drone(COLOR_NEON_BULWARK, size, false)
		"fast_flyer":
			_draw_cyber_drone(COLOR_NEON_FAST, size * 0.8, true)
		"armored_flyer":
			_draw_cyber_drone(COLOR_NEON_TANK, size * 1.5, false)
		"disruptor":
			_draw_cyber_disruptor(Color(0.6, 0.3, 1.0), size * 1.2)
			
	if is_flashing:
		draw_circle(Vector2.ZERO, size * 1.5, Color(1, 1, 1, 0.4))
		draw_arc(Vector2.ZERO, size * 1.6, 0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)

# --- High-Fidelity Procedural Visuals ---

func _draw_glow_core(pos: Vector2, radius: float, color: Color) -> void:
	var p = (sin(pulse_time * 8.0) * 0.5 + 0.5) * 0.2
	var r = radius * (1.0 + p)
	# Outer glow
	draw_circle(pos, r * 1.5, Color(color.r, color.g, color.b, 0.15))
	# Mid glow
	draw_circle(pos, r, Color(color.r, color.g, color.b, 0.4))
	# Hot core
	draw_circle(pos, r * 0.4, Color.WHITE)

func _draw_circuit_line(p1: Vector2, p2: Vector2, color: Color, width: float = 1.0) -> void:
	var alpha = (sin(pulse_time * 12.0 + p1.x) * 0.5 + 0.5) * 0.4 + 0.1
	draw_line(p1, p2, Color(color.r, color.g, color.b, alpha), width)

func _draw_edge_nodes(points: PackedVector2Array, color: Color, radius: float = 1.8) -> void:
	for p in points:
		draw_circle(p, radius + 1.0, Color(0.0, 0.0, 0.0, 0.45))
		draw_circle(p, radius, Color(color.r, color.g, color.b, 0.78))

func _draw_orbiters(count: int, orbit_radius: float, node_radius: float, color: Color, speed: float = 1.0) -> void:
	for i in range(count):
		var a := float(i) / float(count) * TAU + pulse_time * speed
		var p := Vector2.RIGHT.rotated(a) * orbit_radius
		draw_circle(p, node_radius + 2.0, Color(color.r, color.g, color.b, 0.08))
		draw_circle(p, node_radius, Color(color.r, color.g, color.b, 0.75))
		draw_line(p * 0.82, p * 1.06, Color(color.r, color.g, color.b, 0.28), 1.0)

func _draw_inner_plate(points: PackedVector2Array, color: Color, scale_factor: float = 0.66) -> void:
	var inner := PackedVector2Array()
	for p in points:
		inner.append(p * scale_factor)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(color.r, color.g, color.b, 0.28), 1.0)

func _draw_shield_dome(radius: float, color: Color) -> void:
	var pulse = sin(pulse_time * 3.0) * 0.5 + 0.5
	var r_anim = radius * (0.98 + pulse * 0.04)
	
	# Layer 1: Faint Fill
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.04 + pulse * 0.02))
	
	# Layer 2: Main Ring
	draw_arc(Vector2.ZERO, r_anim, 0, TAU, 64, Color(color.r, color.g, color.b, 0.2 + pulse * 0.1), 1.5)
	
	# Layer 3: Shimmer Nodes
	var node_count = 6
	for i in range(node_count):
		var a = i * (TAU / node_count) + (pulse_time * 0.5)
		var node_pos = Vector2(cos(a), sin(a)) * r_anim
		draw_circle(node_pos, 2.0, Color(color.r, color.g, color.b, 0.4))

func _draw_cyber_node(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = i * PI / 3
		pts.append(Vector2(cos(a), sin(a)) * size)
	
	# Layer 1: Base
	draw_colored_polygon(pts, COLOR_BODY)
	_draw_inner_plate(pts, color, 0.62)
	
	# Layer 2: Circuit Seams
	for i in range(6):
		_draw_circuit_line(Vector2.ZERO, pts[i], color)
	
	# Layer 3: Neon Border
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.75), 3.5)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
	_draw_edge_nodes(pts, color, 1.4)
	
	# Layer 4: Pulsing Core
	_draw_glow_core(Vector2.ZERO, size * 0.35, color)

func _draw_cyber_runner(color: Color, size: float) -> void:
	var pts := PackedVector2Array([
		Vector2(size * 1.5, 0),
		Vector2(-size * 1.0, -size * 0.7),
		Vector2(-size * 0.5, 0),
		Vector2(-size * 1.0, size * 0.7)
	])
	
	# Layer 1: Base
	draw_colored_polygon(pts, COLOR_BODY)
	var fin_pts := PackedVector2Array([
		Vector2(-size * 0.35, -size * 0.95),
		Vector2(size * 0.2, -size * 0.42),
		Vector2(-size * 0.58, -size * 0.28)
	])
	draw_colored_polygon(fin_pts, Color(color.r, color.g, color.b, 0.18))
	for i in range(fin_pts.size()):
		fin_pts[i].y *= -1.0
	draw_colored_polygon(fin_pts, Color(color.r, color.g, color.b, 0.18))
	
	# Layer 2: Speed Trails
	var trail_alpha = 0.3 + (sin(pulse_time * 20.0) * 0.2)
	draw_line(Vector2(-size * 0.8, -size * 0.4), Vector2(-size * 2.5, -size * 0.4), Color(color.r, color.g, color.b, trail_alpha), 2.0)
	draw_line(Vector2(-size * 0.8, size * 0.4), Vector2(-size * 2.5, size * 0.4), Color(color.r, color.g, color.b, trail_alpha), 2.0)
	draw_polyline(PackedVector2Array([Vector2(-size * 0.2, 0), Vector2(-size * 1.4, -size * 0.9), Vector2(-size * 2.3, -size * 0.9)]), Color(color.r, color.g, color.b, trail_alpha * 0.45), 1.0)
	draw_polyline(PackedVector2Array([Vector2(-size * 0.2, 0), Vector2(-size * 1.4, size * 0.9), Vector2(-size * 2.3, size * 0.9)]), Color(color.r, color.g, color.b, trail_alpha * 0.45), 1.0)
	
	# Layer 3: Neon Edges
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 4.0)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.5)
	
	# Layer 4: Agile Core
	_draw_glow_core(Vector2(size * 0.4, 0), size * 0.25, color)

func _draw_cyber_tank(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a: float = i * PI / 4
		pts.append(Vector2(cos(a), sin(a)) * size)
	
	# Layer 1: Base Heavy Body
	draw_colored_polygon(pts, COLOR_BODY)
	
	# Layer 2: Heavy Armor Plates (Beveled)
	for i in range(8):
		var mid = (pts[i] + pts[(i + 1) % 8]) * 0.5
		var inner_mid = mid * 0.7
		draw_line(mid, inner_mid, Color(color.r, color.g, color.b, 0.32), 1.4)
		if i % 2 == 0:
			draw_circle(inner_mid, 2.2, Color(color.r, color.g, color.b, 0.45))
		
	# Layer 3: Thick Neon Border
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 4.0)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0) # Separation line
	
	# Layer 4: Heavy Energy Core
	_draw_glow_core(Vector2.ZERO, size * 0.45, color)
	# Secondary lights
	for i in range(4):
		var a = i * PI / 2 + PI / 4
		draw_circle(Vector2(cos(a), sin(a)) * size * 0.8, 3, color)

func _draw_cyber_bulwark(color: Color, size: float) -> void:
	var rect = Rect2(-size, -size * 0.8, size * 2, size * 1.6)
	
	# Layer 1: Base Silhouette
	draw_rect(rect, COLOR_BODY)
	
	# Layer 2: Plate Segments
	draw_line(Vector2(0, -size * 0.8), Vector2(0, size * 0.8), color * 0.5)
	draw_rect(Rect2(-size * 0.72, -size * 0.52, size * 0.46, size * 1.04), Color(color.r, color.g, color.b, 0.12))
	draw_rect(Rect2(size * 0.26, -size * 0.52, size * 0.46, size * 1.04), Color(color.r, color.g, color.b, 0.12))
	draw_line(Vector2(-size, -size * 0.8), Vector2(size, -size * 0.8), Color(0, 0, 0, 0.75), 2.5)
	draw_line(Vector2(-size, size * 0.8), Vector2(size, size * 0.8), Color(0, 0, 0, 0.75), 2.5)
	
	# Layer 3: Shield Rails
	draw_polyline(PackedVector2Array([
		Vector2(size, -size * 0.8), Vector2(size, size * 0.8)
	]), color, 3.0)
	draw_polyline(PackedVector2Array([
		Vector2(-size, -size * 0.8), Vector2(-size, size * 0.8)
	]), color, 3.0)
	
	# Layer 4: Emitter Nodes
	for i in range(3):
		var y = - size * 0.4 + i * (size * 0.4)
		_draw_glow_core(Vector2(size * 0.8, y), 4, color)
		_draw_glow_core(Vector2(-size * 0.8, y), 4, color)
	
	# Shield Field (Dome)
	_draw_shield_dome(shield_radius, color)

func _draw_cyber_hunter(color: Color, size: float) -> void:
	var pts := PackedVector2Array([
		Vector2(size * 1.8, 0),
		Vector2(size * 0.4, -size * 0.5),
		Vector2(-size * 1.2, -size * 1.2),
		Vector2(-size * 0.4, 0),
		Vector2(-size * 1.2, size * 1.2),
		Vector2(size * 0.4, size * 0.5)
	])
	
	# Layer 1: Base Sharp Body
	draw_colored_polygon(pts, COLOR_BODY)
	
	# Layer 2: Circuit Ribs
	_draw_circuit_line(Vector2.ZERO, Vector2(-size, -size), color)
	_draw_circuit_line(Vector2.ZERO, Vector2(-size, size), color)
	draw_line(Vector2(size * 0.2, -size * 0.45), Vector2(-size * 1.05, -size * 1.05), Color(1.0, 0.1, 0.18, 0.35), 1.2)
	draw_line(Vector2(size * 0.2, size * 0.45), Vector2(-size * 1.05, size * 1.05), Color(1.0, 0.1, 0.18, 0.35), 1.2)
	
	# Layer 3: High-contrast Neon
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
	
	# Layer 4: Predatory Eyes
	_draw_glow_core(Vector2(size * 0.7, -size * 0.3), 4, Color.RED)
	_draw_glow_core(Vector2(size * 0.7, size * 0.3), 4, Color.RED)
	_draw_glow_core(Vector2(size * 1.2, 0), 3, color)

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

func _draw_cyber_healer(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var a = i * PI / 6
		var r = size if i % 3 != 0 else size * 0.6
		pts.append(Vector2(cos(a), sin(a)) * r)
	
	var heal_color := Color(0.62, 1.0, 0.86, 1.0)
	var gold := Color(1.0, 0.88, 0.48, 1.0)
	draw_colored_polygon(pts, COLOR_BODY)
	_draw_inner_plate(pts, heal_color, 0.58)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.7), 3.0)
	draw_polyline(pts + PackedVector2Array([pts[0]]), heal_color, 2.0)
	# Rotating healing ring
	draw_arc(Vector2.ZERO, size * 0.8, pulse_time * 2.6, pulse_time * 2.6 + PI, 24, gold, 2.0)
	draw_arc(Vector2.ZERO, size * 1.2, -pulse_time * 1.4, -pulse_time * 1.4 + PI * 0.65, 20, Color(heal_color.r, heal_color.g, heal_color.b, 0.48), 1.4)
	_draw_orbiters(4, size * 1.14, 2.2, gold, 1.1)
	for i in range(4):
		var a := i * PI * 0.5 + PI * 0.25
		_draw_circuit_line(Vector2.RIGHT.rotated(a) * size * 0.25, Vector2.RIGHT.rotated(a) * size * 0.78, heal_color, 1.1)
	_draw_glow_core(Vector2.ZERO, size * 0.5, heal_color)

func _draw_cyber_splitter(color: Color, size: float) -> void:
	_draw_cyber_node(color, size)
	# Unstable Cracks
	var noise = sin(pulse_time * 25.0) * 2.0
	var crack_color := Color(1.0, 0.78, 1.0, 0.86)
	draw_line(Vector2.ZERO, Vector2(size + noise, size), crack_color, 1.5)
	draw_line(Vector2.ZERO, Vector2(-size - noise, size), crack_color, 1.5)
	draw_line(Vector2.ZERO, Vector2(0, -size - noise), crack_color, 1.5)
	if hp / max(max_hp, 1.0) < 0.35:
		var warn := 0.35 + sin(pulse_time * 18.0) * 0.22
		draw_arc(Vector2.ZERO, size * 1.35, 0, TAU, 32, Color(1.0, 0.35, 0.9, warn), 2.0)

func _draw_cyber_cloaked(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(4):
		var a = i * PI / 2 + PI / 4
		pts.append(Vector2(cos(a), sin(a)) * size)
	# Distortion effect
	var d = (sin(pulse_time * 15.0) * 0.5 + 0.5) * 0.2
	for i in range(pts.size()):
		var p1 := pts[i] + Vector2(sin(pulse_time * 18.0 + i) * 2.0, 0)
		var p2 := pts[(i + 1) % pts.size()] + Vector2(sin(pulse_time * 17.0 + i) * -2.0, 0)
		draw_line(p1, p2, Color(color.r, color.g, color.b, 0.22 + d), 1.5)
	for i in range(4):
		var y := -size * 0.65 + i * size * 0.42
		draw_line(Vector2(-size * 0.55, y), Vector2(size * 0.55, y + sin(pulse_time * 12.0 + i) * 1.5), Color(color.r, color.g, color.b, 0.11 + d * 0.45), 1.0)
	draw_circle(Vector2.ZERO, size * (0.2 + d), Color(color.r, color.g, color.b, 0.15))

func _draw_cyber_drone(color: Color, size: float, is_fast: bool) -> void:
	# Base
	draw_circle(Vector2(0, size * 0.7), size * 0.36, Color(0.0, 0.0, 0.0, 0.14))
	draw_circle(Vector2.ZERO, size * 0.6, COLOR_BODY)
	draw_arc(Vector2.ZERO, size * 0.6, 0, TAU, 24, color, 2.0)
	draw_arc(Vector2.ZERO, size * 0.88, pulse_time * 2.0, pulse_time * 2.0 + PI, 24, Color(color.r, color.g, color.b, 0.28), 1.0)
	
	# Rotor arms
	for i in range(4):
		var a = i * PI / 2 + (pulse_time * 15.0)
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * size, color, 2.0)
		draw_circle(Vector2(cos(a), sin(a)) * size, 3, Color.WHITE)
	
	if is_fast:
		var trail = (sin(pulse_time * 30.0) * 0.5 + 0.5) * 10.0
		draw_line(Vector2(-size, 0), Vector2(-size - trail, 0), color, 3.0)
		draw_line(Vector2(-size * 0.45, -size * 0.35), Vector2(-size - trail * 0.7, -size * 0.6), Color(color.r, color.g, color.b, 0.35), 1.4)
		draw_line(Vector2(-size * 0.45, size * 0.35), Vector2(-size - trail * 0.7, size * 0.6), Color(color.r, color.g, color.b, 0.35), 1.4)
	
	_draw_glow_core(Vector2.ZERO, size * 0.3, color)

func _draw_cyber_disruptor(color: Color, size: float) -> void:
	_draw_cyber_drone(color, size, false)
	var cyan := Color(0.35, 1.0, 1.0, 1.0)
	draw_line(Vector2(size * 0.25, -size * 0.55), Vector2(size * 1.2, -size * 1.0), cyan, 1.6)
	draw_line(Vector2(size * 0.25, size * 0.55), Vector2(size * 1.2, size * 1.0), cyan, 1.6)
	draw_line(Vector2(size * 1.0, -size * 0.82), Vector2(size * 1.28, -size * 1.08), Color(1.0, 0.2, 0.82, 0.8), 1.0)
	draw_line(Vector2(size * 1.0, size * 0.82), Vector2(size * 1.28, size * 1.08), Color(1.0, 0.2, 0.82, 0.8), 1.0)
	# EMP interference rings
	var r_pulse = (sin(pulse_time * 10.0) * 0.5 + 0.5)
	draw_arc(Vector2.ZERO, size * (1.2 + r_pulse * 0.3), 0, TAU, 32, Color(color.r, color.g, color.b, 0.4 - r_pulse * 0.3), 2.0)
	draw_arc(Vector2.ZERO, size * (1.5 + r_pulse * 0.5), 0, TAU, 32, Color(color.r, color.g, color.b, 0.2 - r_pulse * 0.2), 1.5)

@export var is_gallery_preview := false

func _ready() -> void:
	body = get_node_or_null("Body") as ColorRect
	hp_bar = get_node_or_null("HpBar") as ProgressBar
	visual_root = _resolve_visual_root()

	apply_visuals()

	if is_gallery_preview:
		set_process(true)
		set_physics_process(false)
		queue_redraw()
		return


	add_to_group("enemies")

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

	_ensure_vfx_controller()

func _process(delta: float) -> void:
	if game_manager != null and (game_manager.is_paused or game_manager.is_game_over):
		return

	if is_gallery_preview:
		pulse_time += delta
		queue_redraw()
		return

	if not is_active or is_dead_flag or reached_base_flag:
		return

	pulse_time += delta
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
	queue_redraw()
	
	# Update timers
	if slow_remaining > 0:
		slow_remaining -= delta
		if slow_remaining <= 0: clear_slow()
		
		# VISUAL: Slow particles (blue sparks)
		if Engine.get_process_frames() % 10 == 0:
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
		
	# Skill Logic
	if skill_id != "":
		skill_timer -= delta
		match skill_id:
			"shield_aura":
				_process_shield_aura()
			"healer":
				if skill_timer <= 0:
					_process_healer_aura()
					skill_timer = skill_params.get("interval", 1.0)
			"disrupt_aura":
				_process_disrupt_aura()
		
	# Archetype Logic (Legacy)
	if is_bulwark and skill_id == "":
		_process_shield_aura()
		
	if is_hunter:
		_process_hunter_ai(delta)
	else:
		_process_pathing(delta)

func _process_shield_aura() -> void:
	var radius = float(skill_params.get("radius", shield_radius))
	var reduction = _get_skill_reduction()
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy) and enemy.has_method("apply_shield"):
			if enemy.has_method("is_alive") and not enemy.is_alive():
				continue
			if global_position.distance_to(enemy.global_position) <= radius:
				enemy.apply_shield(0.25, reduction, self ) # Short duration, refreshed by aura

func _get_skill_reduction() -> float:
	var raw = skill_params.get("reduction", skill_params.get("shield_reduction", shield_reduction))
	return clampf(float(raw), 0.0, 0.9)

func _process_healer_aura() -> void:
	var radius = float(skill_params.get("radius", 100.0))
	var amount = float(skill_params.get("heal_amount", 5.0))
	var enemies = get_tree().get_nodes_in_group("enemies")
	var healed_targets: Array = []
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy) and enemy.has_method("heal"):
			if enemy.has_method("is_alive") and not enemy.is_alive():
				continue
			if global_position.distance_to(enemy.global_position) <= radius:
				var hp_before := float(enemy.get_current_hp()) if enemy.has_method("get_current_hp") else 0.0
				var applied := float(enemy.heal(amount, self ))
				if applied > 0.0:
					var hp_after := float(enemy.get_current_hp()) if enemy.has_method("get_current_hp") else hp_before + applied
					healed_targets.append(enemy)
					healed.emit(enemy, applied, self )
					enemy_healed.emit(enemy, self , applied, hp_before, hp_after)
					enemy_modifier_changed.emit(enemy, "healed", applied)
					if OS.is_debug_build():
						print("[EnemyFeature][Healer] source=%s target=%s amount=%.1f hp=%.1f/%.1f" % [
							enemy_type,
							enemy.get_enemy_type() if enemy.has_method("get_enemy_type") else str(enemy.name),
							applied,
							float(enemy.get_current_hp()) if enemy.has_method("get_current_hp") else 0.0,
							float(enemy.max_hp) if "max_hp" in enemy else 0.0
						])
	if not healed_targets.is_empty():
		healer_heal_tick.emit(self , healed_targets, amount)


func _process_disrupt_aura() -> void:
	var radius = float(skill_params.get("radius", 150.0))
	var penalty = clampf(float(skill_params.get("fire_rate_penalty", 0.5)), 0.05, 1.0)
	var towers = get_tree().get_nodes_in_group("towers")
	var currently_affected: Array[Node] = []
	for tower in towers:
		if not is_instance_valid(tower) or not tower.has_method("apply_fire_rate_modifier"):
			continue
		if global_position.distance_to(tower.global_position) <= radius:
			tower.apply_fire_rate_modifier(self , penalty)
			currently_affected.append(tower)
			disrupted_towers[tower.get_instance_id()] = tower
			disrupted_tower.emit(tower, penalty, self )
			if OS.is_debug_build():
				var effective = tower.get_effective_fire_rate() if tower.has_method("get_effective_fire_rate") else 0.0
				print("[EnemyFeature][Disruptor] source=%s tower=%s penalty=%.2f effective_interval=%.2f" % [enemy_type, str(tower.name), penalty, effective])
	for key in disrupted_towers.keys():
		var tower: Node = disrupted_towers[key]
		if not is_instance_valid(tower) or not currently_affected.has(tower):
			if is_instance_valid(tower) and tower.has_method("remove_fire_rate_modifier"):
				tower.remove_fire_rate_modifier(self )
				disruption_removed.emit(tower, self )
			disrupted_towers.erase(key)
	if vfx_controller:
		vfx_controller.update_disrupted_towers(currently_affected)

func heal(amount: float, source: Variant = null) -> float:
	if is_dead_flag or reached_base_flag or hp >= max_hp:
		return 0.0
	var before := hp
	hp = min(hp + amount, max_hp)
	var applied := hp - before
	if hp_bar: hp_bar.value = hp
	if applied > 0.0:
		_spawn_impact_particle(Color(0.4, 1.0, 0.4, 0.6)) # Green pulse
		enemy_modifier_changed.emit(self , "hp", hp)
	return applied

func apply_shield(duration: float, reduction: float = shield_reduction, source: Variant = null) -> void:
	if shield_remaining <= 0:
		queue_redraw()
	shield_remaining = max(shield_remaining, duration)
	active_shield_reduction = clampf(reduction, 0.0, 0.9)
	active_shield_source = source
	enemy_modifier_changed.emit(self , "shield_reduction", active_shield_reduction)
	if vfx_controller:
		vfx_controller.set_protected_icon(active_shield_reduction > 0.0)

func apply_vulnerability(multiplier: float, duration: float) -> void:
	# Keep the highest multiplier
	if multiplier >= vulnerability_multiplier:
		vulnerability_multiplier = multiplier
		vulnerability_remaining = duration
	elif duration > vulnerability_remaining and multiplier == vulnerability_multiplier:
		vulnerability_remaining = duration

func _process_hunter_ai(delta: float) -> void:
	var hero = null
	var heroes = get_tree().get_nodes_in_group("heroes")
	if heroes.size() > 0:
		hero = heroes[0] # Focus first hero
		
	if is_instance_valid(hero) and hero.has_method("is_alive") and hero.is_alive():
		var dist = global_position.distance_to(hero.global_position)
		if dist <= aggro_range:
			if hunter_state == HunterState.PATHING:
				if OS.is_debug_build(): print("[HunterAI] aggro hero distance=%.1f" % dist)
			
			if dist <= hunter_attack_range:
				hunter_state = HunterState.AGGRO_ATTACKING
				_attack_hero(hero, delta)
			else:
				hunter_state = HunterState.AGGRO_CHASING
				_move_toward_hero(hero.global_position, delta)
			return
			
	# Fallback to pathing
	if hunter_state != HunterState.PATHING:
		hunter_state = HunterState.PATHING
		if OS.is_debug_build(): print("[HunterAI] return_to_path reason=no_hero_in_range")
	_process_pathing(delta)

func _move_toward_hero(target_pos: Vector2, delta: float) -> void:
	var dir = (target_pos - global_position).normalized()
	global_position += dir * speed * delta
	# Rotate visual manually when off-path
	rotation = lerp_angle(rotation, dir.angle(), 10.0 * delta)

func _attack_hero(hero: Node, delta: float) -> void:
	if hunter_attack_cooldown > 0:
		hunter_attack_cooldown -= delta
	
	if hunter_attack_cooldown <= 0:
		if hero.has_method("take_damage"):
			hero.take_damage(hunter_attack_damage)
			hunter_attack_cooldown = 1.0 # 1 attack per sec
			if OS.is_debug_build(): print("[HunterAI] attack_hero damage=%.1f" % hunter_attack_damage)

func _process_pathing(delta: float) -> void:
	progress += speed * delta
	if progress_ratio >= 1.0:
		reach_base()

func take_damage(amount: float, hit_global: Vector2 = Vector2.ZERO, source_id: String = "", p_attack_type: String = "single") -> void:
	if is_dead_flag or reached_base_flag: return
	
	if source_id != "":
		last_damage_source = source_id
	
	var final_damage = amount
	if shield_remaining > 0 and not is_bulwark:
		var shielded_damage: float = final_damage * (1.0 - active_shield_reduction)
		shield_applied.emit(self , final_damage, shielded_damage, active_shield_source)
		final_damage = shielded_damage
		if OS.is_debug_build():
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
		
	hp -= final_damage
	if hp_bar: hp_bar.value = hp
	
	var gm = get_tree().current_scene.get_node_or_null("GameManager")
	if gm and gm.battle_telemetry:
		gm.battle_telemetry.log_damage(source_id, final_damage, p_attack_type, enemy_type)
		
	flash_body()
	var dn_color = Color.WHITE
	if shield_remaining > 0 and not is_bulwark:
		dn_color = Color(0.4, 0.8, 1.0) # Light blue for shielded hits
		
	spawn_damage_number(int(final_damage), capture_pos, dn_color)
	_play_hit_pulse()
	if enemy_type == "swarm" or tags.has("swarm"):
		_trigger_swarm_hit_reaction()
		_spawn_swarm_hit_effect(capture_pos)
	
	if hp <= 0:
		die(capture_pos)

func apply_slow(percent: float, duration: float) -> void:
	if percent >= active_slow_percent:
		active_slow_percent = percent
		status_speed_multiplier = max(1.0 - active_slow_percent, 0.25)
		slow_remaining = duration
		update_effective_speed()
	elif duration > slow_remaining and percent == active_slow_percent:
		slow_remaining = duration

func clear_slow() -> void:
	active_slow_percent = 0.0
	slow_remaining = 0.0
	status_speed_multiplier = 1.0
	update_effective_speed()

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
			if OS.is_debug_build():
				print("[SpawnFormation] release throttle enemy=%s base_speed=%.1f effective_speed=%.1f" % [enemy_type, base_speed, speed])
	if formation_speed_multiplier != formation_target_multiplier:
		if formation_speed_multiplier > formation_target_multiplier:
			formation_speed_multiplier = formation_target_multiplier
		else:
			formation_speed_multiplier = move_toward(formation_speed_multiplier, formation_target_multiplier, formation_release_rate * delta)
		update_effective_speed()

func update_effective_speed() -> void:
	status_speed_multiplier = max(1.0 - active_slow_percent, 0.25)
	speed = base_speed * formation_speed_multiplier * status_speed_multiplier

func flash_body() -> void:
	is_flashing = true
	queue_redraw()
	# Strong white flash
	var tween = create_tween()
	tween.tween_interval(0.06)
	tween.tween_callback(func():
		is_flashing = false
		queue_redraw()
	)

func spawn_damage_number(amount: int, hit_global: Vector2, color: Color = Color.WHITE) -> void:
	if damage_number_scene:
		var dn = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(dn)
		dn.global_position = hit_global + Vector2(randf_range(-5, 5), -20 + randf_range(-5, 5))
		dn.setup(amount, color)

func die(death_global: Vector2 = Vector2.ZERO) -> void:
	if is_dead_flag: return
	is_dead_flag = true
	is_active = false
	_clear_disrupted_towers()
	if vfx_controller:
		vfx_controller.fade_out()
	
	var gm = get_tree().current_scene.get_node_or_null("GameManager")
	if gm and gm.battle_telemetry:
		gm.battle_telemetry.log_enemy_kill(last_damage_source, enemy_type)
		
	var capture_pos = death_global if death_global != Vector2.ZERO else global_position
	spawn_death_effect(capture_pos)
	
	if skill_id == "split_on_death":
		_handle_split_on_death(capture_pos)
		
	died.emit(self , reward_gold)
	queue_free()

func _handle_split_on_death(death_pos: Vector2) -> void:
	if split_triggered_once:
		return
	split_triggered_once = true
	var count = skill_params.get("count", 2)
	var type = skill_params.get("type", "basic")
	split_triggered.emit(self , type, count)
	if vfx_controller:
		vfx_controller.play_split_burst(str(type), int(count))
	if OS.is_debug_build():
		print("[EnemyFeature][Splitter] source=%s child_type=%s count=%d progress=%.1f" % [enemy_type, type, count, progress])
	var wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")
	if wave_manager and wave_manager.has_method("spawn_enemy_at_progress"):
		for i in range(count):
			# Spawn slightly behind or ahead
			var offset_prog = (i - (count - 1) / 2.0) * 20.0
			wave_manager.spawn_enemy_at_progress(type, progress + offset_prog, get_parent())

func notify_stealth_deferred(preferred_target: Node) -> void:
	stealth_targeting_deferred.emit(self , preferred_target)
	if vfx_controller:
		vfx_controller.mark_cloaked_deferred(preferred_target)
	if OS.is_debug_build():
		print("[EnemyFeature][Cloaked] deferred=%s preferred=%s" % [enemy_type, preferred_target.get_enemy_type() if preferred_target and preferred_target.has_method("get_enemy_type") else str(preferred_target)])

func notify_stealth_targetable() -> void:
	if vfx_controller:
		vfx_controller.mark_cloaked_targetable()

func _clear_disrupted_towers() -> void:
	for key in disrupted_towers.keys():
		var tower: Node = disrupted_towers[key]
		if is_instance_valid(tower) and tower.has_method("remove_fire_rate_modifier"):
			tower.remove_fire_rate_modifier(self )
			disruption_removed.emit(tower, self )
	disrupted_towers.clear()
	if vfx_controller:
		vfx_controller.clear_all_disrupted_towers()

func spawn_death_effect(death_global: Vector2) -> void:
	if death_pop_scene:
		var effect = death_pop_scene.instantiate()
		if effect.has_method("setup") and (enemy_type == "swarm" or tags.has("swarm")):
			effect.setup("swarm_death", swarm_core_glow_color, 0.52, swarm_death_particle_count)
		get_tree().current_scene.add_child(effect)
		effect.global_position = death_global

func reach_base() -> void:
	if reached_base_flag: return
	reached_base_flag = true
	is_active = false
	
	reached_base.emit(self , base_damage, global_position)
	queue_free()

func is_alive() -> bool:
	return hp > 0 and not reached_base_flag and not is_dead_flag

func _play_hit_pulse() -> void:
	var tween = create_tween()
	var is_swarm := enemy_type == "swarm" or tags.has("swarm")
	var s = randf_range(1.08, 1.14) if is_swarm else randf_range(1.15, 1.25)
	tween.tween_property(self , "scale", Vector2(s, 1.0 / s), 0.025 if is_swarm else 0.04).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self , "scale", Vector2.ONE, 0.055 if is_swarm else 0.08).set_trans(Tween.TRANS_BACK)
	
	# Small hit shake
	var original_pos = position
	var shake_tween = create_tween()
	var shake_strength := 1.4 if is_swarm else 3.0
	var shake_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * shake_strength
	shake_tween.tween_property(self , "position", original_pos + shake_dir, 0.018 if is_swarm else 0.03)
	shake_tween.tween_property(self , "position", original_pos, 0.018 if is_swarm else 0.03)

func _trigger_swarm_hit_reaction() -> void:
	swarm_core_flicker_time = 0.08

func _spawn_swarm_hit_effect(hit_global: Vector2) -> void:
	if death_pop_scene == null:
		return
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	var effect = death_pop_scene.instantiate()
	if effect.has_method("setup"):
		effect.setup("swarm_hit", swarm_core_glow_color, 0.18, 6)
	container.add_child(effect)
	effect.global_position = hit_global

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
	
	var p = Node2D.new()
	p.set_script(load("res://scripts/effects/bleed_particle.gd"))
	container.add_child(p)
	
	# Spawn randomly around center
	var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	p.global_position = global_position + offset

func _spawn_impact_particle(color: Color) -> void:
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	
	var impact_scene = preload("res://scenes/effects/ImpactEffect.tscn")
	if impact_scene:
		var effect = impact_scene.instantiate()
		container.add_child(effect)
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
