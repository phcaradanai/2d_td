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

var waves: Array = []
var enemies_config: Dictionary = {}
var current_wave_index: int = 0
var is_wave_running: bool = false
var active_enemy_count: int = 0

var is_spawning: bool = false
var target_path: Path2D
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

func setup(path: Path2D) -> void:
	target_path = path

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
		var delay = group.get("spawn_delay", 1.0)
		
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
	if not target_path: return
		
	var enemy_type = group_data.get("enemy_type", "basic")
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	
	# Merge group overrides into base config
	for key in group_data.keys():
		if key != "count" and key != "spawn_delay":
			base_config[key] = group_data[key]
	
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	
	target_path.add_child(enemy)
	active_enemy_count += 1

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
