extends Node2D

var target: Node2D = null
var damage: float = 0.0
var speed: float = 500.0
var attack_type: String = "single"
var splash_radius: float = 0.0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var lifetime: float = 5.0

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
@onready var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")
@onready var splash_effect_scene: PackedScene = preload("res://scenes/effects/SplashEffect.tscn")
@onready var impact_effect_scene: PackedScene = preload("res://scenes/effects/ImpactEffect.tscn")

func setup(p_target: Node2D, p_damage: float, p_speed: float = 500.0, p_attack_type: String = "single", p_splash_radius: float = 0.0, p_slow_percent: float = 0.0, p_slow_duration: float = 0.0) -> void:
	target = p_target
	damage = p_damage
	speed = p_speed
	attack_type = p_attack_type
	splash_radius = p_splash_radius
	slow_percent = p_slow_percent
	slow_duration = p_slow_duration

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return
		
	if target == null or not is_instance_valid(target):
		queue_free()
		return
		
	var target_pos := target.global_position
	var to_target := target_pos - global_position
	var distance := to_target.length()
	
	if distance < 15:
		hit_target()
		return
		
	global_position += to_target.normalized() * speed * delta
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	
	if OS.is_debug_build():
		queue_redraw()

func _draw() -> void:
	# Face movement direction
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

	if attack_type == "splash":
		apply_splash_damage(hit_global)
	elif attack_type == "slow":
		if target and is_instance_valid(target):
			if target.has_method("take_damage"):
				target.take_damage(damage, hit_global)
			if target.has_method("apply_slow"):
				target.apply_slow(slow_percent, slow_duration)
			_spawn_impact_effect(hit_global, Color(0.2, 0.8, 1.0)) # Icy blue
			if audio_manager:
				audio_manager.play_sfx("projectile_hit")
	else:
		if target and target.has_method("take_damage"):
			target.take_damage(damage, hit_global)
			_spawn_impact_effect(hit_global)
			if audio_manager:
				audio_manager.play_sfx("projectile_hit")
	
	queue_free()

func _spawn_impact_effect(hit_pos: Vector2, color: Color = Color.WHITE) -> void:
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
		effect.setup(color, scale_val)

func apply_splash_damage(hit_pos: Vector2) -> void:
	if audio_manager:
		audio_manager.play_sfx("splash_hit")
		
	# Screen shake for cannon
	var main = get_tree().current_scene
	if main and main.has_method("shake_camera"):
		main.shake_camera(8.0, 0.2)
		
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
		effect.setup(splash_radius)
	
	# Find enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			var enemy_global = enemy.global_position
			var dist = to_local(enemy_global).length()
			if dist <= splash_radius:
				# Pass enemy's OWN global position to take_damage for per-enemy numbers
				enemy.take_damage(damage, enemy_global)
