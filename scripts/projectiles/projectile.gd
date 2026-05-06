extends Node2D

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const DEFAULT_TARGET_CATEGORIES: Array[String] = [ENEMY_CATEGORY_LAND]

var target: Node2D = null
var damage: float = 0.0
var speed: float = 500.0
var attack_type: String = "single"
var effect_radius: float = 0.0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var target_categories: Array[String] = DEFAULT_TARGET_CATEGORIES.duplicate()
var lifetime: float = 5.0

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
@onready var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")
@onready var splash_effect_scene: PackedScene = preload("res://scenes/effects/SplashEffect.tscn")
@onready var impact_effect_scene: PackedScene = preload("res://scenes/effects/ImpactEffect.tscn")
var trail_points: Array[Vector2] = []
@export var max_trail_points: int = 8
@export var min_point_distance: float = 4.0

func setup(p_target: Node2D, p_damage: float, p_speed: float = 500.0, p_attack_type: String = "single", p_effect_radius: float = 0.0, p_slow_percent: float = 0.0, p_slow_duration: float = 0.0, p_target_categories: Array = []) -> void:
	target = p_target
	damage = p_damage
	speed = p_speed
	attack_type = p_attack_type
	effect_radius = p_effect_radius
	slow_percent = p_slow_percent
	slow_duration = p_slow_duration
	target_categories = _normalize_target_categories(p_target_categories)

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return
		
	if target == null or not is_instance_valid(target):
		queue_free()
		return
		
	var target_pos := target.global_position
	if target.has_method("get_hit_origin"):
		target_pos = target.get_hit_origin()
		
	var to_target := target_pos - global_position
	var distance := to_target.length()
	
	# STANDARD: Use global distance for hit detection
	if distance < 10.0:
		hit_target()
		return
		
	global_position += to_target.normalized() * speed * delta
	_update_trail()
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	
	if OS.is_debug_build():
		queue_redraw()

func _update_trail() -> void:
	# Avoid adding points if we're already at the target or dead
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) < 5.0:
		return
		
	if trail_points.is_empty():
		trail_points.append(global_position)
		return
		
	var last_p = trail_points.back()
	if last_p.distance_to(global_position) >= min_point_distance:
		trail_points.append(global_position)
	
	if trail_points.size() > max_trail_points:
		trail_points.pop_front()
	
	queue_redraw()

func _draw() -> void:
	# 1. Draw Trail (Global points converted to local space)
	if trail_points.size() >= 2:
		var base_color = modulate
		for i in range(trail_points.size() - 1):
			var p1 = to_local(trail_points[i])
			var p2 = to_local(trail_points[i+1])
			
			# Avoid drawing very tiny or degenerate segments
			if p1.distance_to(p2) < 0.5: continue
			
			var alpha = float(i + 1) / trail_points.size()
			var seg_color = base_color
			seg_color.a = 0.4 * alpha
			draw_line(p1, p2, seg_color, 2.0 * alpha, true)

	# 2. Face movement direction
	var rot = 0.0
	if is_instance_valid(target):
		rot = (target.global_position - global_position).angle()
	
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	
	var color = Color(0.3, 0.8, 1.0, 1.0) # Default cyan
	
	if attack_type == "splash": # Cannon
		color = Color(1.0, 0.5, 0.2, 1.0)
		_draw_shell(color)
	elif attack_type == "slow": # Slow
		color = Color(0.7, 0.5, 1.0, 1.0)
		_draw_bolt(color, 12.0)
	else: # Basic / Rapid
		color = Color(0.3, 1.0, 0.6, 1.0) if speed > 550 else Color(0.3, 0.7, 1.0, 1.0)
		_draw_bolt(color, 10.0)

func _draw_bolt(color: Color, length: float) -> void:
	var pts = [Vector2(length, 0), Vector2(-length/2, -3), Vector2(-length/2, 3)]
	draw_colored_polygon(pts, color)
	draw_polyline(pts + [pts[0]], Color.WHITE, 1.0)
	# Glow
	draw_line(Vector2(-length, 0), Vector2(length, 0), Color(color.r, color.g, color.b, 0.4), 4.0)

func _draw_shell(color: Color) -> void:
	draw_circle(Vector2.ZERO, 5, color)
	draw_arc(Vector2.ZERO, 5, 0, TAU, 16, Color.WHITE, 1.5)
	# Trail tail
	draw_line(Vector2(-8, 0), Vector2(-2, 0), color, 3.0)

func hit_target() -> void:
	# Capture target position BEFORE calling damage (in case it dies)
	var hit_global = global_position
	if is_instance_valid(target):
		hit_global = target.global_position
		
	if OS.is_debug_build():
		if OS.is_debug_build(): print("[Projectile] Hit global captured at ", hit_global)

	if attack_type == "splash" or attack_type == "slow":
		apply_area_effect(hit_global)
	else:
		if target and target.has_method("take_damage"):
			target.take_damage(damage, hit_global)
			# STANDARD: Use captured hit point and current pos for angle
			var impact_angle = (hit_global - global_position).angle()
			_spawn_impact_effect(hit_global, Color.WHITE, impact_angle)
			if audio_manager:
				audio_manager.play_sfx("projectile_hit")
	
	queue_free()

func _spawn_impact_effect(hit_pos: Vector2, color: Color = Color.WHITE, hit_angle: float = 0.0) -> void:
	if impact_effect_scene:
		var effect = impact_effect_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
			# MUST set global_position AFTER add_child
			effect.global_position = hit_pos
		else:
			get_tree().current_scene.add_child(effect)
			effect.global_position = hit_pos
		
		var scale_val = 0.8
		if attack_type == "slow": scale_val = 1.2
		
		# Set rotation for directional sparks
		effect.rotation = hit_angle
		
		if effect.has_method("setup"):
			effect.setup(color, scale_val)

func apply_area_effect(hit_pos: Vector2) -> void:
	if attack_type == "splash":
		if audio_manager:
			audio_manager.play_sfx("splash_hit")
		# Screen shake for cannon
		var main = get_tree().current_scene
		if main and main.has_method("shake_camera"):
			main.shake_camera(8.0, 0.2)
	elif attack_type == "slow":
		if audio_manager:
			audio_manager.play_sfx("projectile_hit")

	# Spawn visual effect at hit position
	if splash_effect_scene:
		var effect = splash_effect_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
			effect.global_position = hit_pos
		else:
			get_tree().current_scene.add_child(effect)
			effect.global_position = hit_pos
		
		var effect_color = Color(1, 0.5, 0.2) if attack_type == "splash" else Color(0.4, 0.8, 1.0)
		if effect.has_method("setup"):
			effect.setup(effect_radius, effect_color)
		
	# Find enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			if not can_affect_enemy(enemy):
				continue
			
			# Precision: Use hit center or aim point if available
			var enemy_pos = enemy.global_position
			if enemy.has_method("get_hit_origin"):
				enemy_pos = enemy.get_hit_origin()
			elif enemy.has_method("get_aim_point"):
				enemy_pos = enemy.get_aim_point()
			
			# STANDARD: Use global distance check for area damage/slow
			var dist = hit_pos.distance_to(enemy_pos)
			if dist <= effect_radius:
				if attack_type == "splash":
					# Linear Falloff: 100% at center, 50% at edge
					var falloff = 1.0 - (dist / effect_radius) * 0.5
					enemy.take_damage(damage * falloff, enemy_pos)
				elif attack_type == "slow":
					# Area slow deals its low base damage + applies debuff
					enemy.take_damage(damage, enemy_pos)
					if enemy.has_method("apply_slow"):
						enemy.apply_slow(slow_percent, slow_duration)

func can_affect_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.has_method("get_enemy_category"):
		return true
	return target_categories.has(str(enemy.get_enemy_category()).to_lower())

func _normalize_target_categories(raw_categories) -> Array[String]:
	var normalized: Array[String] = []
	if raw_categories is Array:
		for category in raw_categories:
			var value = str(category).strip_edges().to_lower()
			if (value == ENEMY_CATEGORY_LAND or value == ENEMY_CATEGORY_AIR) and not normalized.has(value):
				normalized.append(value)
	elif raw_categories != null:
		var value = str(raw_categories).strip_edges().to_lower()
		if value == ENEMY_CATEGORY_LAND or value == ENEMY_CATEGORY_AIR:
			normalized.append(value)
	if normalized.is_empty():
		normalized.append(ENEMY_CATEGORY_LAND)
	return normalized
