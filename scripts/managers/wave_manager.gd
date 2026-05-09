extends Node

## Signals for wave lifecycle
signal wave_started(wave_number: int, wave_name: String)
signal wave_completed(wave_number: int, wave_name: String, reward: int)
signal all_waves_completed()
## Signals for gameplay events
signal enemy_killed(reward_gold: int)
signal base_damaged(base_damage: int, global_pos: Vector2)

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
@export var waves_data_path: String = "res://data/waves.json"
@export var enemies_data_path: String = "res://data/enemies.json"
@export var formation_planner_script: GDScript = preload("res://scripts/managers/spawn_formation_planner.gd")

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]

var waves: Array = []
var enemies_config: Dictionary = {}

var wave_start_time_msec: int = 0
var current_wave_index: int = 0
var is_wave_running: bool = false
var active_enemy_count: int = 0
var formation_planner = null

var is_spawning: bool = false
var path_nodes: Dictionary = {} # id -> Path2D
var spawn_generation: int = 0

# Track active wave specifically to avoid index confusion during running wave
var active_wave_number: int = 0
var active_wave_name: String = ""
var active_wave_reward: int = 0

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")

func _ready() -> void:
	load_enemies_config()
	load_waves()

func load_enemies_config() -> void:
	if not FileAccess.file_exists(enemies_data_path):
		push_error("Enemies config file not found: " + enemies_data_path)
		return
	
	var file = FileAccess.open(enemies_data_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		enemies_config = json.data
		if formation_planner == null:
			formation_planner = formation_planner_script.new(enemies_config)
		else:
			formation_planner.set_enemies_config(enemies_config)
		if OS.is_debug_build(): print("Loaded ", enemies_config.size(), " enemy types.")

func load_waves() -> void:
	if not FileAccess.file_exists(waves_data_path):
		push_error("Waves data file not found: " + waves_data_path)
		return
	
	var file = FileAccess.open(waves_data_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON Parse Error: " + json.get_error_message())
		return
	
	waves = json.data
	if OS.is_debug_build(): print("Loaded ", waves.size(), " waves.")

func load_waves_from_file(path: String) -> void:
	waves_data_path = path
	load_waves()

func load_waves_from_data(data: Array) -> void:
	waves = data
	if OS.is_debug_build(): print("[WaveManager] Loaded ", waves.size(), " waves from data.")

func setup(paths: Dictionary) -> void:
	path_nodes = paths

func reset_waves() -> void:
	spawn_generation += 1
	is_wave_running = false
	is_spawning = false
	current_wave_index = 0
	active_enemy_count = 0
	active_wave_number = 0
	active_wave_name = ""
	active_wave_reward = 0
	if OS.is_debug_build(): print("[WaveManager] reset_waves: current_wave_index=0")

func start_next_wave() -> void:
	if is_wave_running: return
	
	if current_wave_index >= waves.size():
		if OS.is_debug_build(): print("All waves already completed.")
		all_waves_completed.emit()
		return
	
	var wave_data = waves[current_wave_index]
	is_wave_running = true
	is_spawning = true
	
	active_wave_number = int(wave_data.get("wave", current_wave_index + 1))
	active_wave_name = str(wave_data.get("name", "Unknown Wave"))
	active_wave_reward = int(wave_data.get("reward", wave_data.get("completion_reward", 0)))
	
	wave_start_time_msec = Time.get_ticks_msec()
	
	current_wave_index += 1
	
	wave_started.emit(active_wave_number, active_wave_name)
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.start_wave(active_wave_number, active_wave_name)
	
	if OS.is_debug_build(): print("Starting Wave ", active_wave_number, ": ", active_wave_name, ". Next index=", current_wave_index)
	
	var current_gen = spawn_generation
	
	# BUILD FORMATION PLAN
	if formation_planner == null:
		formation_planner = formation_planner_script.new(enemies_config)
	var plan = formation_planner.build_plan(wave_data, current_wave_index - 1)
	
	if OS.is_debug_build():
		print("[FORMATION] wave=%d groups=%d events=%d duration=%.2fs" % [
			active_wave_number, 
			wave_data.get("groups", []).size(),
			plan.get("events", []).size(),
			plan.get("total_duration", 0.0)
		])
	
	await spawn_wave_events(plan.get("events", []), current_gen)
	
	if current_gen != spawn_generation:
		return
		
	is_spawning = false
	_check_wave_completion()

func spawn_wave_events(events: Array, gen: int) -> void:
	if events.is_empty():
		return
		
	var start_time_sec = Time.get_ticks_msec() / 1000.0
	var event_index = 0
	
	while event_index < events.size():
		if gen != spawn_generation: return
		
		var current_time_sec = Time.get_ticks_msec() / 1000.0
		var elapsed = current_time_sec - start_time_sec
		
		# Handle pause if game_manager exists
		if game_manager != null and game_manager.is_paused:
			await get_tree().process_frame
			start_time_sec += get_process_delta_time()
			continue
			
		var event = events[event_index]
		var target_time = float(event.get("time", 0.0))
		
		if elapsed >= target_time:
			spawn_enemy_from_event(event)
			event_index += 1
		else:
			# Wait a bit before checking again
			await get_tree().process_frame

func spawn_enemy_from_event(event: Dictionary) -> void:
	var group_data = event.get("group_data", {}).duplicate()
	# Ensure event specific data is passed to spawn_enemy
	group_data["type"] = event.get("type", "basic")
	group_data["path"] = event.get("path", "default")
	# Pass formation metadata for potential visual/behavior use
	group_data["formation_id"] = event.get("formation_id", "")
	group_data["tactical_position"] = event.get("tactical_position", "")
	group_data["formation_speed_multiplier"] = event.get("formation_speed_multiplier", 1.0)
	
	spawn_enemy(group_data)

func spawn_wave_groups(_groups: Array, _gen: int) -> void:
	# Deprecated in favor of spawn_wave_events but kept for reference/safety
	push_warning("spawn_wave_groups called but replaced by spawn_wave_events")

func _wait_unpaused(seconds: float, gen: int) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if gen != spawn_generation: return
		
		await get_tree().process_frame
		
		if game_manager != null and game_manager.is_paused:
			continue
			
		elapsed += get_process_delta_time()

func spawn_enemy(group_data: Dictionary) -> void:
	var path_id = group_data.get("path", "default")
	var path_node = path_nodes.get(path_id, path_nodes.get("default"))
	if not path_node: return
		
	var enemy_type = group_data.get("enemy_type", group_data.get("type", "basic"))
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = resolve_enemy_category(group_data)
	
	# Merge group overrides into base config
	for key in group_data.keys():
		if key != "count" and key != "spawn_delay":
			base_config[key] = group_data[key]
	
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	
	if OS.is_debug_build():
		var spawn_pos = path_node.curve.get_point_position(0)
		var f_id = group_data.get("formation_id", "none")
		var pos_type = group_data.get("tactical_position", "middle")
		print("[FORMATION] spawn enemy=%s lane=%s t=%.2f position=%s formation=%s" % [
			enemy_type, path_id, (Time.get_ticks_msec() - wave_start_time_msec) / 1000.0, pos_type, f_id
		])
		
	path_node.add_child(enemy)
	active_enemy_count += 1
	
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_enemy_spawn(enemy_type)
	
	# VISUAL: Spawn effect at portal
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	
	var spawn_pos_vec = path_node.curve.get_point_position(0)
	var effect = Node2D.new()
	effect.set_script(load("res://scripts/effects/spawn_effect.gd"))
	container.add_child(effect)
	effect.global_position = path_node.to_global(spawn_pos_vec)
	if effect.has_method("setup"):
		var spawn_color = Color(0.4, 0.7, 1.0, 0.6)
		var spawn_mode = "portal"
		var enemy_tags: Array = base_config.get("tags", [])
		if base_config.get("category") == ENEMY_CATEGORY_AIR:
			spawn_color = Color(1.0, 0.8, 0.4, 0.6) # Yellow for air
		if enemy_type == "swarm" or enemy_tags.has("swarm"):
			spawn_color = Color(0.0, 0.941, 1.0, 0.66)
			spawn_mode = "swarm"
		effect.setup(spawn_color, 20.0, spawn_mode)

func spawn_enemy_at_progress(enemy_type: String, prog: float, path_node: Node2D) -> void:
	if not path_node: return
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	
	path_node.add_child(enemy)
	enemy.progress = prog
	active_enemy_count += 1
	
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_enemy_spawn(enemy_type)

func resolve_enemy_category(spawn_data: Dictionary) -> String:
	if spawn_data.has("category"):
		return normalize_enemy_category(spawn_data["category"])
	
	var enemy_type = str(spawn_data.get("enemy_type", spawn_data.get("type", "basic")))
	var enemy_config = enemies_config.get(enemy_type, {})
	if enemy_config is Dictionary and enemy_config.has("category"):
		return normalize_enemy_category(enemy_config["category"])
	
	return ENEMY_CATEGORY_LAND

func normalize_enemy_category(raw_category) -> String:
	var normalized = str(raw_category).strip_edges().to_lower()
	if VALID_ENEMY_CATEGORIES.has(normalized):
		return normalized
	return ENEMY_CATEGORY_LAND

func _on_enemy_died(_enemy: Node, reward: int) -> void:
	enemy_killed.emit(reward)
	_on_enemy_removed()

func _on_enemy_reached_base(_enemy: Node, damage: int, global_pos: Vector2) -> void:
	if game_manager and game_manager.battle_telemetry:
		var hp_rem = _enemy.get_current_hp() if _enemy.has_method("get_current_hp") else 0.0
		var prog = _enemy.get_path_progress() if _enemy.has_method("get_path_progress") else 0.0
		var lives_after = game_manager.lives - damage
		game_manager.battle_telemetry.log_enemy_leak(_enemy.enemy_type, hp_rem, global_pos, prog, lives_after)
		
	base_damaged.emit(damage, global_pos)
	_on_enemy_removed()

func _on_enemy_removed() -> void:
	active_enemy_count -= 1
	_check_wave_completion()

func _check_wave_completion() -> void:
	if is_wave_running and not is_spawning and active_enemy_count <= 0:
		is_wave_running = false
		
		var duration_sec = (Time.get_ticks_msec() - wave_start_time_msec) / 1000.0
		if game_manager and game_manager.battle_telemetry:
			game_manager.battle_telemetry.log_wave_completed(active_wave_number, "cleared", active_wave_reward)
			
		if OS.is_debug_build(): print("Wave ", active_wave_number, " completed!")
		wave_completed.emit(active_wave_number, active_wave_name, active_wave_reward)
		
		if current_wave_index >= waves.size():
			if OS.is_debug_build(): print("All waves completed!")
			all_waves_completed.emit()

func get_next_wave_number() -> int:
	if current_wave_index < waves.size():
		return int(waves[current_wave_index].get("wave", current_wave_index + 1))
	return 0

func get_total_waves() -> int:
	return waves.size()

func get_next_wave_name() -> String:
	if current_wave_index < waves.size():
		return str(waves[current_wave_index].get("name", ""))
	return ""

func has_next_wave() -> bool:
	return current_wave_index < waves.size()

func get_current_wave_data() -> Dictionary:
	if current_wave_index < waves.size():
		return waves[current_wave_index]
	return {}
