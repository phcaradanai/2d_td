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

func apply_visuals() -> void:
	if not is_inside_tree(): return
	if body: body.visible = false
	queue_redraw()

func _draw() -> void:
	var color = Color(0.8, 0.2, 0.2, 1.0)
	var size = 16.0
	
	if shield_remaining > 0:
		draw_circle(Vector2.ZERO, size * 1.3, Color(0.4, 0.8, 1.0, 0.3))
	
	if active_slow_percent > 0:
		# Frost/Slow glow
		draw_circle(Vector2.ZERO, size * 1.2, Color(0.6, 0.9, 1.0, 0.25))
		draw_arc(Vector2.ZERO, size * 1.1, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.4), 2.0)
	
	match visual_type:
		"basic":
			color = Color(1.0, 0.2, 0.2, 1.0) # Electric Red
			_draw_drone_hexagon(color, size)
		"fast":
			color = Color(1.0, 0.8, 0.2, 1.0)
			_draw_drone_triangle(color, size * 0.7)
		"tank":
			color = Color(0.6, 0.1, 0.1, 1.0) # Dark Industrial Red
			_draw_drone_tank(color, size * 1.4)
		"bulwark":
			color = Color(0.1, 0.6, 1.0, 1.0) # Secure Blue
			_draw_bulwark(color, size * 1.6)
			draw_arc(Vector2.ZERO, shield_radius, 0, TAU, 32, Color(0.2, 0.8, 1.0, 0.2), 2.0)
		"hunter":
			color = Color(1.0, 0.4, 0.2, 1.0)
			_draw_hunter(color, size * 1.1)
			
	if is_flashing:
		draw_circle(Vector2.ZERO, size * 1.5, Color(1, 1, 1, 0.6))

func _draw_drone_hexagon(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var a : float = i * PI/3
		pts.append(Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
	draw_circle(Vector2(size * 0.4, 0), 3, Color.WHITE)

func _draw_drone_triangle(color: Color, size: float) -> void:
	var pts := PackedVector2Array([Vector2(size * 1.2, 0), Vector2(-size, -size), Vector2(-size, size)])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
	draw_circle(Vector2(0, 0), 4, Color.WHITE)

func _draw_drone_tank(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a : float = i * PI/4
		pts.append(Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)

func _draw_bulwark(color: Color, size: float) -> void:
	var pts := PackedVector2Array([
		Vector2(size, -size), Vector2(size, size), 
		Vector2(-size, size), Vector2(-size, -size)
	])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 2.0)
	# Internal cross
	draw_line(Vector2(-size*0.7, 0), Vector2(size*0.7, 0), Color.WHITE, 1.5)
	draw_line(Vector2(0, -size*0.7), Vector2(0, size*0.7), Color.WHITE, 1.5)

func _draw_hunter(color: Color, size: float) -> void:
	var pts := PackedVector2Array([
		Vector2(size * 1.5, 0), Vector2(-size*0.5, -size), 
		Vector2(-size, 0), Vector2(-size*0.5, size)
	])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.YELLOW, 1.5)
	# Red eye
	draw_circle(Vector2(size * 0.6, 0), 3, Color.RED)

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
		
	# Archetype Logic
	if is_bulwark:
		_process_bulwark_aura()
		
	if is_hunter:
		_process_hunter_ai(delta)
	else:
		_process_pathing(delta)

func _process_bulwark_aura() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy) and enemy.has_method("apply_shield"):
			if global_position.distance_to(enemy.global_position) <= shield_radius:
				enemy.apply_shield(0.2)

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
	died.emit(self, reward_gold)
	queue_free()

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
