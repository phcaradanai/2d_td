extends Node2D

signal health_changed(current, max_hp)
signal skill_cooldown_updated(current, max_cooldown)
signal skill_ready()
signal hero_retreated()

enum HeroState { IDLE, CHASING, ATTACKING, RETURNING, RETREATING }

@export var hero_name: String = "Guardian"
@export var hero_tooltip: String = "Ground-only emergency defender. Cannot attack air enemies."
@export var max_hp: float = 450.0
@export var damage: float = 36.0
@export var attack_range: float = 125.0
@export var attack_speed: float = 1.4
@export var move_speed: float = 220.0

var current_hp: float = 450.0
var attack_cooldown: float = 0.0
var current_target: Node2D = null
var current_state: HeroState = HeroState.IDLE

var is_active: bool = true
var active_duration_max: float = 28.0
var active_duration_current: float = 0.0
var rally_point: Vector2
var battlefield_bounds: Rect2 = Rect2(0, 0, 1280, 768)

# Skill Stats: Rally Strike
var skill_name: String = "Rally Strike"
var skill_cooldown_max: float = 20.0
var skill_cooldown_current: float = 0.0
var skill_damage: float = 80.0
var skill_radius: float = 100.0

@onready var visual: Node2D = $Visual
@onready var range_ring: Line2D = %RangeRing
@onready var base_ring: Line2D = %BaseRing
@onready var attack_effect: Node2D = %AttackEffect
@onready var game_manager = get_tree().current_scene.get_node_or_null("GameManager")

var _pulse_time: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	rally_point = global_position
	add_to_group("heroes")
	_update_range_collision()
	_update_range_visual()
	_generate_base_ring()
	active_duration_current = active_duration_max
	
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_hero_deployed()
	
	if OS.is_debug_build(): 
		print("[HeroConfig] %s ready at %s" % [hero_name, global_position])

func initialize_hero(pos: Vector2, rally: Vector2, bounds: Rect2) -> void:
	global_position = pos
	rally_point = rally
	battlefield_bounds = bounds

func trigger_shockwave() -> void:
	var shockwave_radius = 150.0
	var shockwave_damage = 60.0
	var enemies_hit = 0
	
	_play_shockwave_visual(shockwave_radius)
	
	var main = get_tree().current_scene
	if main and main.has_method("shake_camera"):
		main.shake_camera(12.0, 0.3)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			# Guardian land-only: skip air enemies
			if enemy.has_method("get_enemy_category") and enemy.get_enemy_category() != "land":
				continue
			if global_position.distance_to(enemy.global_position) <= shockwave_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(int(shockwave_damage), enemy.global_position, "hero")
					enemies_hit += 1
					
	if OS.is_debug_build():
		print("[HeroDeploy] shockwave enemies_hit=%d" % enemies_hit)

func _process(delta: float) -> void:
	if game_manager and (game_manager.is_paused or game_manager.is_game_over):
		return
		
	if not is_active: return
	
	# Handle Duration
	if active_duration_current > 0:
		active_duration_current -= delta
		if active_duration_current <= 0:
			retreat()
			return
			
	_update_visuals(delta)
	_update_ai(delta)
	_update_skill(delta)

func _update_visuals(delta: float) -> void:
	_pulse_time += delta
	
	# Handle Hit Flash
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0:
			if visual: visual.modulate = Color(1, 1, 1, 1)
			
	# Faster pulse if expiring
	var pulse_speed = 4.0
	if active_duration_current < 5.0:
		pulse_speed = 12.0
		visual.modulate = Color(1.2, 0.6, 0.6) # Red warning tint
	elif _hit_flash_timer <= 0:
		visual.modulate = Color(1, 1, 1)
		
	var alpha = 0.3 + 0.3 * sin(_pulse_time * pulse_speed)
	if range_ring: range_ring.modulate.a = alpha
	if base_ring: base_ring.modulate.a = alpha + 0.2

func take_damage(amount: float) -> void:
	if current_state == HeroState.RETREATING: return
	
	current_hp -= amount
	health_changed.emit(current_hp, max_hp)
	
	_trigger_hit_flash()
	
	if current_hp <= 0:
		current_hp = 0
		if OS.is_debug_build(): print("[HeroLifecycle] defeated by enemy")
		retreat()

var _hit_flash_timer: float = 0.0
func _trigger_hit_flash() -> void:
	_hit_flash_timer = 0.1
	if visual: visual.modulate = Color(10, 10, 10, 1) # Bright white flash

func _update_ai(delta: float) -> void:
	if is_instance_valid(current_target):
		if not current_target.has_method("is_alive") or not current_target.is_alive():
			current_target = null
	
	if not is_instance_valid(current_target):
		current_target = find_best_target()
	
	if not is_instance_valid(current_target):
		var dist_to_rally = global_position.distance_to(rally_point)
		if dist_to_rally > 20.0:
			_change_state(HeroState.RETURNING)
		else:
			_change_state(HeroState.IDLE)
	else:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			_change_state(HeroState.ATTACKING)
		else:
			_change_state(HeroState.CHASING)
			
	match current_state:
		HeroState.RETURNING:
			_move_toward(rally_point, delta)
			if global_position.distance_to(rally_point) < 10.0:
				_change_state(HeroState.IDLE)
		HeroState.CHASING:
			if is_instance_valid(current_target):
				_move_toward(current_target.global_position, delta)
		HeroState.ATTACKING:
			if is_instance_valid(current_target):
				_face_target(current_target.global_position, delta)
				_process_attack(delta)

func _change_state(new_state: HeroState) -> void:
	if current_state == new_state: return
	current_state = new_state
	
	if current_state == HeroState.RETREATING:
		is_active = false

func _move_toward(target_pos: Vector2, delta: float) -> void:
	var diff = target_pos - global_position
	if diff.length() < 1.0: return
	
	var dir = diff.normalized()
	var dist = diff.length()
	var stop_dist = attack_range * 0.85 if current_state == HeroState.CHASING else 0.0
		
	if dist > stop_dist:
		var move_amt = move_speed * delta
		if dist - move_amt < stop_dist: move_amt = dist - stop_dist
		global_position += dir * move_amt
		global_position.x = clamp(global_position.x, battlefield_bounds.position.x, battlefield_bounds.end.x)
		global_position.y = clamp(global_position.y, battlefield_bounds.position.y, battlefield_bounds.end.y)
		_face_target(target_pos, delta)

func _face_target(target_pos: Vector2, delta: float) -> void:
	if visual:
		var dir = target_pos - global_position
		if dir.length() > 2.0:
			visual.rotation = lerp_angle(visual.rotation, dir.angle(), 12.0 * delta)

func _process_attack(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if attack_cooldown <= 0:
		attack()
		attack_cooldown = 1.0 / attack_speed

func find_best_target() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var max_progress = -1.0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			# Guardian land-only: skip air enemies
			if enemy.has_method("get_enemy_category") and enemy.get_enemy_category() != "land":
				continue
			if enemy.has_method("get_path_progress"):
				var prog = enemy.get_path_progress()
				if prog > max_progress:
					max_progress = prog
					best_target = enemy
			elif best_target == null:
				best_target = enemy
	return best_target

func attack() -> void:
	if not is_instance_valid(current_target): return
	# Guardian land-only: abort if target is an air enemy
	if current_target.has_method("get_enemy_category") and current_target.get_enemy_category() != "land":
		current_target = null
		return
	var dist = global_position.distance_to(current_target.global_position)
	if dist > attack_range: return
	
	if current_target.has_method("take_damage"):
		current_target.take_damage(int(damage), current_target.global_position, "hero")
		_play_attack_visual(current_target.global_position)

func _play_attack_visual(target_pos: Vector2) -> void:
	# Punch/Scale visual
	var tween = create_tween()
	tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Directional Slash
	if attack_effect:
		attack_effect.visible = true
		attack_effect.rotation = (target_pos - global_position).angle()
		var slash = attack_effect.get_node("Slash")
		slash.modulate.a = 1.0
		var s_tween = create_tween()
		s_tween.tween_property(slash, "modulate:a", 0.0, 0.2)
		s_tween.tween_callback(func(): attack_effect.visible = false)

func retreat() -> void:
	if current_state == HeroState.RETREATING: return
	_change_state(HeroState.RETREATING)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func():
		hero_retreated.emit()
		queue_free()
	)

func _update_skill(delta: float) -> void:
	if skill_cooldown_current > 0:
		skill_cooldown_current -= delta
		skill_cooldown_updated.emit(skill_cooldown_current, skill_cooldown_max)
		if skill_cooldown_current <= 0:
			skill_ready.emit()

func cast_skill() -> void:
	if skill_cooldown_current > 0: return
	var hit_count = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			# Guardian land-only: Rally Strike does not hit air enemies
			if enemy.has_method("get_enemy_category") and enemy.get_enemy_category() != "land":
				continue
			if global_position.distance_to(enemy.global_position) <= skill_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(int(skill_damage), enemy.global_position, "hero")
					hit_count += 1
	_play_skill_visual()
	skill_cooldown_current = skill_cooldown_max
	skill_cooldown_updated.emit(skill_cooldown_current, skill_cooldown_max)

func _play_skill_visual() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	var circle = Line2D.new()
	effect.add_child(circle)
	circle.width = 4.0
	circle.default_color = Color(1.0, 0.8, 0.2, 0.8)
	var points = []
	for i in range(33):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * skill_radius)
	circle.points = points
	circle.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(circle, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(effect.queue_free)

func _play_shockwave_visual(radius: float) -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	var circle = Line2D.new()
	effect.add_child(circle)
	circle.width = 6.0
	circle.default_color = Color(0.4, 0.8, 1.0, 1.0)
	var points = []
	for i in range(33):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.points = points
	circle.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(circle, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.6)
	tween.tween_callback(effect.queue_free)


func _update_range_collision() -> void:
	var shape = get_node_or_null("RangeArea/CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = attack_range

func _update_range_visual() -> void:
	if range_ring:
		var points = PackedVector2Array()
		for i in range(33):
			var angle = i * TAU / 32.0
			points.append(Vector2(cos(angle), sin(angle)) * attack_range)
		range_ring.points = points

func _generate_base_ring() -> void:
	if base_ring:
		var points = PackedVector2Array()
		var radius = 24.0
		for i in range(33):
			var angle = i * TAU / 32.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		base_ring.points = points
