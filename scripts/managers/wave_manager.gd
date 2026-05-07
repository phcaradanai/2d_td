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

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]

var waves: Array = []
var enemies_config: Dictionary = {}
var current_wave_index: int = 0
var is_wave_running: bool = false
var active_enemy_count: int = 0

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
	active_wave_reward = int(wave_data.get("completion_reward", 0))
	
	current_wave_index += 1
	
	wave_started.emit(active_wave_number, active_wave_name)
	if OS.is_debug_build(): print("Starting Wave ", active_wave_number, ": ", active_wave_name, ". Next index=", current_wave_index)
	
	var current_gen = spawn_generation
	await spawn_wave_groups(wave_data["groups"], current_gen)
	
	if current_gen != spawn_generation:
		return
		
	is_spawning = false
	_check_wave_completion()

func spawn_wave_groups(groups: Array, gen: int) -> void:
	for group in groups:
		if gen != spawn_generation: return
		
		var count = group.get("count", 0)
		var delay = group.get("spawn_delay", group.get("interval", 1.0))
		
		for i in range(count):
			if gen != spawn_generation: return
			spawn_enemy(group)
			await _wait_unpaused(delay, gen)

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
		print("[EnemySpawn] enemy=%s lane=%s spawn_pos=%s" % [enemy_type, path_id, spawn_pos])
		
	path_node.add_child(enemy)
	active_enemy_count += 1
	
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
		if base_config.get("category") == ENEMY_CATEGORY_AIR:
			spawn_color = Color(1.0, 0.8, 0.4, 0.6) # Yellow for air
		effect.setup(spawn_color, 20.0)

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
	base_damaged.emit(damage, global_pos)
	_on_enemy_removed()

func _on_enemy_removed() -> void:
	active_enemy_count -= 1
	_check_wave_completion()

func _check_wave_completion() -> void:
	if is_wave_running and not is_spawning and active_enemy_count <= 0:
		is_wave_running = false
		
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
