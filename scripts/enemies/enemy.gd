extends PathFollow2D

signal died(enemy, reward_gold)
signal reached_base(enemy, damage, global_pos)

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]

var hp: float = 30.0
var max_hp: float = 30.0
var base_speed: float = 100.0
var speed: float = 100.0
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
var is_flashing: bool = false
var vulnerability_multiplier: float = 1.0
var vulnerability_remaining: float = 0.0
var bleed_particle_timer: float = 0.0

# Special Archetypes
var is_bulwark: bool = false
var is_hunter: bool = false
var tags: Array = []

# Visual State
var pulse_time: float = 0.0
const COLOR_BODY = Color(0.08, 0.08, 0.12) # Dark Gunmetal
const COLOR_NEON_BASIC = Color(0.2, 0.8, 1.0) # Electric Cyan
const COLOR_NEON_FAST = Color(0.0, 1.0, 0.7) # Teal/Green
const COLOR_NEON_TANK = Color(1.0, 0.45, 0.1) # Amber/Orange
const COLOR_NEON_BULWARK = Color(0.1, 0.6, 1.0) # Blue
const COLOR_NEON_HUNTER = Color(1.0, 0.1, 0.4) # Magenta/Red

# Bulwark Stats
var shield_radius: float = 90.0
var shield_reduction: float = 0.30

# Hunter Stats
enum HunterState { PATHING, AGGRO_CHASING, AGGRO_ATTACKING }
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

@onready var body: ColorRect = $Body
@onready var hp_bar: ProgressBar = $HpBar
@onready var damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
@onready var death_pop_scene: PackedScene = preload("res://scenes/effects/DeathPopEffect.tscn")
@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")

func setup(config: Dictionary) -> void:
	enemy_type = config.get("id", config.get("enemy_type", "basic"))
	enemy_category = normalize_enemy_category(config.get("category", ENEMY_CATEGORY_LAND))
	display_name = config.get("name", "Enemy")
	visual_type = config.get("visual_type", "basic")
	tags = config.get("tags", [])
	skill_id = config.get("skill", "")
	skill_params = config.get("skill_params", {})
	
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
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	apply_visuals()
	is_active = true

func normalize_enemy_category(raw_category) -> String:
	var normalized = str(raw_category).strip_edges().to_lower()
	if VALID_ENEMY_CATEGORIES.has(normalized):
		return normalized
	return ENEMY_CATEGORY_LAND

func get_enemy_category() -> String:
	return enemy_category

func apply_visuals() -> void:
	if not is_inside_tree(): return
	if body: body.visible = false
	queue_redraw()

func _draw() -> void:
	var size = 16.0
	
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
			_draw_cyber_swarm(COLOR_NEON_FAST, size * 0.5)
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
		draw_circle(Vector2.ZERO, size * 2.0, Color(1, 1, 1, 0.7))

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
		var a : float = i * PI/3
		pts.append(Vector2(cos(a), sin(a)) * size)
	
	# Layer 1: Base
	draw_colored_polygon(pts, COLOR_BODY)
	
	# Layer 2: Circuit Seams
	for i in range(6):
		_draw_circuit_line(Vector2.ZERO, pts[i], color)
	
	# Layer 3: Neon Border
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
	
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
	
	# Layer 2: Speed Trails
	var trail_alpha = 0.3 + (sin(pulse_time * 20.0) * 0.2)
	draw_line(Vector2(-size * 0.8, -size * 0.4), Vector2(-size * 2.5, -size * 0.4), Color(color.r, color.g, color.b, trail_alpha), 2.0)
	draw_line(Vector2(-size * 0.8, size * 0.4), Vector2(-size * 2.5, size * 0.4), Color(color.r, color.g, color.b, trail_alpha), 2.0)
	
	# Layer 3: Neon Edges
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.5)
	
	# Layer 4: Agile Core
	_draw_glow_core(Vector2(size * 0.4, 0), size * 0.25, color)

func _draw_cyber_tank(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a : float = i * PI/4
		pts.append(Vector2(cos(a), sin(a)) * size)
	
	# Layer 1: Base Heavy Body
	draw_colored_polygon(pts, COLOR_BODY)
	
	# Layer 2: Heavy Armor Plates (Beveled)
	for i in range(8):
		var mid = (pts[i] + pts[(i+1)%8]) * 0.5
		var inner_mid = mid * 0.7
		draw_line(mid, inner_mid, Color.WHITE, 1.0)
		
	# Layer 3: Thick Neon Border
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 4.0)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0) # Separation line
	
	# Layer 4: Heavy Energy Core
	_draw_glow_core(Vector2.ZERO, size * 0.45, color)
	# Secondary lights
	for i in range(4):
		var a = i * PI/2 + PI/4
		draw_circle(Vector2(cos(a), sin(a)) * size * 0.8, 3, color)

func _draw_cyber_bulwark(color: Color, size: float) -> void:
	var rect = Rect2(-size, -size * 0.8, size * 2, size * 1.6)
	
	# Layer 1: Base Silhouette
	draw_rect(rect, COLOR_BODY)
	
	# Layer 2: Plate Segments
	draw_line(Vector2(0, -size * 0.8), Vector2(0, size * 0.8), color * 0.5)
	
	# Layer 3: Shield Rails
	draw_polyline(PackedVector2Array([
		Vector2(size, -size * 0.8), Vector2(size, size * 0.8)
	]), color, 3.0)
	draw_polyline(PackedVector2Array([
		Vector2(-size, -size * 0.8), Vector2(-size, size * 0.8)
	]), color, 3.0)
	
	# Layer 4: Emitter Nodes
	for i in range(3):
		var y = -size * 0.4 + i * (size * 0.4)
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
	
	# Layer 3: High-contrast Neon
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
	
	# Layer 4: Predatory Eyes
	_draw_glow_core(Vector2(size * 0.7, -size * 0.3), 4, Color.RED)
	_draw_glow_core(Vector2(size * 0.7, size * 0.3), 4, Color.RED)
	_draw_glow_core(Vector2(size * 1.2, 0), 3, color)

func _draw_cyber_swarm(color: Color, size: float) -> void:
	var count = 3
	for i in range(count):
		var a = (pulse_time * 10.0) + (i * TAU / count)
		var offset = Vector2(cos(a), sin(a)) * size * 1.2
		_draw_glow_core(offset, size * 0.8, color)

func _draw_cyber_healer(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var a = i * PI/6
		var r = size if i % 3 != 0 else size * 0.6
		pts.append(Vector2(cos(a), sin(a)) * r)
	
	draw_colored_polygon(pts, COLOR_BODY)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
	# Rotating healing ring
	draw_arc(Vector2.ZERO, size * 0.8, pulse_time * 5.0, pulse_time * 5.0 + PI, 24, color, 2.0)
	_draw_glow_core(Vector2.ZERO, size * 0.5, color)

func _draw_cyber_splitter(color: Color, size: float) -> void:
	_draw_cyber_node(color, size)
	# Unstable Cracks
	var noise = sin(pulse_time * 25.0) * 2.0
	draw_line(Vector2.ZERO, Vector2(size + noise, size), Color.WHITE, 1.5)
	draw_line(Vector2.ZERO, Vector2(-size - noise, size), Color.WHITE, 1.5)
	draw_line(Vector2.ZERO, Vector2(0, -size - noise), Color.WHITE, 1.5)

func _draw_cyber_cloaked(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(4):
		var a = i * PI/2 + PI/4
		pts.append(Vector2(cos(a), sin(a)) * size)
	# Distortion effect
	var d = (sin(pulse_time * 15.0) * 0.5 + 0.5) * 0.2
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.2 + d), 1.5)
	draw_circle(Vector2.ZERO, size * (0.2 + d), Color(color.r, color.g, color.b, 0.15))

func _draw_cyber_drone(color: Color, size: float, is_fast: bool) -> void:
	# Base
	draw_circle(Vector2.ZERO, size * 0.6, COLOR_BODY)
	draw_arc(Vector2.ZERO, size * 0.6, 0, TAU, 24, color, 2.0)
	
	# Rotor arms
	for i in range(4):
		var a = i * PI/2 + (pulse_time * 15.0)
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * size, color, 2.0)
		draw_circle(Vector2(cos(a), sin(a)) * size, 3, Color.WHITE)
	
	if is_fast:
		var trail = (sin(pulse_time * 30.0) * 0.5 + 0.5) * 10.0
		draw_line(Vector2(-size, 0), Vector2(-size - trail, 0), color, 3.0)
	
	_draw_glow_core(Vector2.ZERO, size * 0.3, color)

func _draw_cyber_disruptor(color: Color, size: float) -> void:
	_draw_cyber_drone(color, size, false)
	# EMP interference rings
	var r_pulse = (sin(pulse_time * 10.0) * 0.5 + 0.5)
	draw_arc(Vector2.ZERO, size * (1.2 + r_pulse * 0.3), 0, TAU, 32, Color(color.r, color.g, color.b, 0.4 - r_pulse * 0.3), 2.0)
	draw_arc(Vector2.ZERO, size * (1.5 + r_pulse * 0.5), 0, TAU, 32, Color(color.r, color.g, color.b, 0.2 - r_pulse * 0.2), 1.5)


func _ready() -> void:
	add_to_group("enemies")
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	apply_visuals()

func _process(delta: float) -> void:
	if game_manager != null and (game_manager.is_paused or game_manager.is_game_over):
		return
		
	if not is_active or is_dead_flag or reached_base_flag:
		return
		
	pulse_time += delta
	queue_redraw()
	
	# Update timers
	if slow_remaining > 0:
		slow_remaining -= delta
		if slow_remaining <= 0: clear_slow()
		
		# VISUAL: Slow particles (blue sparks)
		if Engine.get_process_frames() % 10 == 0:
			_spawn_impact_particle(Color(0.4, 0.8, 1.0, 0.6))
	
	if shield_remaining > 0:
		shield_remaining -= delta
		if shield_remaining <= 0: queue_redraw()
	
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
	var radius = skill_params.get("radius", shield_radius)
	var reduction = skill_params.get("reduction", shield_reduction)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy) and enemy.has_method("apply_shield"):
			if global_position.distance_to(enemy.global_position) <= radius:
				enemy.apply_shield(0.2) # Short duration, refreshed by aura

func _process_healer_aura() -> void:
	var radius = skill_params.get("radius", 100.0)
	var amount = skill_params.get("heal_amount", 5.0)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy) and enemy.has_method("heal"):
			if global_position.distance_to(enemy.global_position) <= radius:
				enemy.heal(amount)

func _process_disrupt_aura() -> void:
	var radius = skill_params.get("radius", 150.0)
	var penalty = skill_params.get("fire_rate_penalty", 0.5)
	var towers = get_tree().get_nodes_in_group("towers")
	# This requires tower support to apply a 'disrupted' state. 
	# For now, we'll just log or stub it.
	pass

func heal(amount: float) -> void:
	if hp < max_hp:
		hp = min(hp + amount, max_hp)
		if hp_bar: hp_bar.value = hp
		_spawn_impact_particle(Color(0.4, 1.0, 0.4, 0.6)) # Green pulse

func apply_shield(duration: float) -> void:
	if shield_remaining <= 0:
		queue_redraw()
	shield_remaining = max(shield_remaining, duration)

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

func take_damage(amount: float, hit_global: Vector2 = Vector2.ZERO) -> void:
	if is_dead_flag or reached_base_flag: return
	
	var final_damage = amount
	if shield_remaining > 0 and not is_bulwark:
		final_damage *= (1.0 - shield_reduction)
		if OS.is_debug_build(): 
			print("[Damage] shield_reduced original=%.1f final=%.1f" % [amount, final_damage])
			
	var capture_pos = hit_global if hit_global != Vector2.ZERO else global_position
	
	# Apply vulnerability
	if vulnerability_remaining > 0:
		final_damage *= vulnerability_multiplier
		
	hp -= final_damage
	if hp_bar: hp_bar.value = hp
		
	flash_body()
	var dn_color = Color.WHITE
	if shield_remaining > 0 and not is_bulwark:
		dn_color = Color(0.4, 0.8, 1.0) # Light blue for shielded hits
		
	spawn_damage_number(int(final_damage), capture_pos, dn_color)
	_play_hit_pulse()
	
	if hp <= 0:
		die(capture_pos)

func apply_slow(percent: float, duration: float) -> void:
	if percent >= active_slow_percent:
		active_slow_percent = percent
		slow_remaining = duration
		update_effective_speed()
	elif duration > slow_remaining and percent == active_slow_percent:
		slow_remaining = duration

func clear_slow() -> void:
	active_slow_percent = 0.0
	slow_remaining = 0.0
	update_effective_speed()

func update_effective_speed() -> void:
	speed = base_speed * max(1.0 - active_slow_percent, 0.25)

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
	var capture_pos = death_global if death_global != Vector2.ZERO else global_position
	spawn_death_effect(capture_pos)
	
	if skill_id == "split_on_death":
		_handle_split_on_death(capture_pos)
		
	died.emit(self, reward_gold)
	queue_free()

func _handle_split_on_death(death_pos: Vector2) -> void:
	var count = skill_params.get("count", 2)
	var type = skill_params.get("type", "basic")
	var wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")
	if wave_manager and wave_manager.has_method("spawn_enemy_at_progress"):
		for i in range(count):
			# Spawn slightly behind or ahead
			var offset_prog = (i - (count-1)/2.0) * 20.0
			wave_manager.spawn_enemy_at_progress(type, progress + offset_prog, get_parent())

func spawn_death_effect(death_global: Vector2) -> void:
	if death_pop_scene:
		var effect = death_pop_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = death_global

func reach_base() -> void:
	if reached_base_flag: return
	reached_base_flag = true
	is_active = false
	reached_base.emit(self, base_damage, global_position)
	queue_free()

func is_alive() -> bool:
	return hp > 0 and not reached_base_flag and not is_dead_flag

func _play_hit_pulse() -> void:
	var tween = create_tween()
	var s = randf_range(1.15, 1.25)
	tween.tween_property(self, "scale", Vector2(s, 1.0/s), 0.04).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK)
	
	# Small hit shake
	var original_pos = position
	var shake_tween = create_tween()
	var shake_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 3.0
	shake_tween.tween_property(self, "position", original_pos + shake_dir, 0.03)
	shake_tween.tween_property(self, "position", original_pos, 0.03)

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
