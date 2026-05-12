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
const SPAWN_EFFECT_SCRIPT: GDScript = preload("res://scripts/effects/spawn_effect.gd")

const PERFORMANCE_MODE := true  # Disables spawn VFX for stable 60 FPS

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
var pathfinding_manager: Node = null
var use_dynamic_pathing_for_ground: bool = true
var leak_respawn_enabled: bool = false
var leak_respawn_health_mode: String = "preserve" # preserve | full
var spawn_generation: int = 0
var spawn_lane_cursor: int = 0

# Track active wave specifically to avoid index confusion during running wave
var active_wave_number: int = 0
var active_wave_name: String = ""
var active_wave_reward: int = 0
# Element TD economy gate: after the first leak of a wave, interest stops
# until the next wave. This prevents interest farming on respawned creeps.
var current_wave_has_leak: bool = false

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

func set_pathfinding_manager(p_pathfinding_manager: Node) -> void:
	pathfinding_manager = p_pathfinding_manager

func configure_from_level(level_manager: Node) -> void:
	use_dynamic_pathing_for_ground = true
	if level_manager == null:
		return
	var data: Dictionary = {}
	var raw_data = level_manager.get("level_data")
	if raw_data is Dictionary:
		data = raw_data
	var mode := _normalize_pathing_mode(data.get("enemy_pathing_mode", data.get("pathing_mode", "dynamic_maze")))
	use_dynamic_pathing_for_ground = not _is_fixed_path_mode(mode)
	leak_respawn_enabled = bool(data.get("leak_respawn_enabled", false))
	leak_respawn_health_mode = str(data.get("leak_respawn_health_mode", "preserve")).strip_edges().to_lower()
	if OS.is_debug_build():
		print("[WaveManager] pathing_mode=", mode, " dynamic_ground=", use_dynamic_pathing_for_ground, " leak_respawn=", leak_respawn_enabled, " hp_mode=", leak_respawn_health_mode)

func force_fixed_pathing() -> void:
	use_dynamic_pathing_for_ground = false

func _normalize_pathing_mode(raw_mode) -> String:
	return str(raw_mode).strip_edges().to_lower().replace("-", "_")

func _is_fixed_path_mode(mode: String) -> bool:
	return mode in ["fixed", "fixed_path", "element_td", "elemental_td", "path2d"]

func _should_use_dynamic_pathing_for_enemy(config: Dictionary) -> bool:
	return use_dynamic_pathing_for_ground and normalize_enemy_category(config.get("category", ENEMY_CATEGORY_LAND)) == ENEMY_CATEGORY_LAND and pathfinding_manager != null

func _stamp_enemy_pathing_config(config: Dictionary) -> void:
	# Let Enemy.gd know which movement model the WaveManager selected.
	# This prevents older enemy-side dynamic-path defaults from overriding fixed Path2D levels.
	config["pathing_mode"] = "dynamic_maze" if use_dynamic_pathing_for_ground else "fixed_path"
	config["enemy_pathing_mode"] = config["pathing_mode"]
	config["use_dynamic_pathing"] = use_dynamic_pathing_for_ground
	config["dynamic_pathing_enabled"] = use_dynamic_pathing_for_ground

func _attach_enemy_to_path(enemy: Node, path_node: Node, progress: float = 0.0) -> void:
	path_node.add_child(enemy)
	if enemy.has_method("clear_dynamic_pathing"):
		enemy.clear_dynamic_pathing()
	if enemy is PathFollow2D:
		enemy.progress = maxf(0.0, progress)
	elif enemy is Node2D:
		var local_pos := Vector2.ZERO
		if path_node is Path2D and path_node.curve and path_node.curve.point_count > 0:
			if progress > 0.0:
				local_pos = path_node.curve.sample_baked(clampf(progress, 0.0, path_node.curve.get_baked_length()))
			else:
				local_pos = path_node.curve.get_point_position(0)
		enemy.position = local_pos

func reset_waves() -> void:
	spawn_generation += 1
	spawn_lane_cursor = 0
	is_wave_running = false
	is_spawning = false
	current_wave_index = 0
	active_enemy_count = 0
	active_wave_number = 0
	active_wave_name = ""
	active_wave_reward = 0
	current_wave_has_leak = false
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
	current_wave_has_leak = false
	
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
	var requested_path_id: String = str(group_data.get("path", "default"))
	var path_id: String = _resolve_spawn_path_id(requested_path_id)
	var path_node = path_nodes.get(path_id, path_nodes.get("default"))
	if not path_node: return
		
	var enemy_type = group_data.get("enemy_type", group_data.get("type", "basic"))
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = resolve_enemy_category(group_data)
	
	# Merge group overrides into base config
	for key in group_data.keys():
		if key != "count" and key != "spawn_delay":
			base_config[key] = group_data[key]
	
	_stamp_enemy_pathing_config(base_config)
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	_apply_respawn_health_override(enemy, group_data)
	
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	
	if OS.is_debug_build():
		var spawn_pos = path_node.curve.get_point_position(0)
		var f_id = group_data.get("formation_id", "none")
		var pos_type = group_data.get("tactical_position", "middle")
		print("[FORMATION] spawn enemy=%s lane=%s t=%.2f position=%s formation=%s" % [
			enemy_type, path_id, (Time.get_ticks_msec() - wave_start_time_msec) / 1000.0, pos_type, f_id
		])
		
	var spawn_pos: Vector2 = path_node.curve.get_point_position(0) if path_node.curve and path_node.curve.point_count > 0 else Vector2.ZERO
	var spawn_world: Vector2 = path_node.to_global(spawn_pos)
	if _should_use_dynamic_pathing_for_enemy(base_config) and enemy.has_method("set_dynamic_pathing"):
		var enemy_parent := _get_enemy_container()
		enemy_parent.add_child(enemy)
		enemy.global_position = spawn_world
		var spawn_cell: Vector2i = pathfinding_manager.world_to_cell(spawn_world)
		enemy.set_dynamic_pathing(pathfinding_manager, spawn_cell)
	else:
		_attach_enemy_to_path(enemy, path_node, 0.0)
	active_enemy_count += 1
	
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_enemy_spawn(enemy_type)
	
	# VISUAL: Spawn effect at portal
	if not PERFORMANCE_MODE:
		var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if not container: container = get_tree().current_scene
		var spawn_pos_vec = path_node.curve.get_point_position(0)
		var effect = Node2D.new()
		effect.set_script(SPAWN_EFFECT_SCRIPT)
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

func _apply_respawn_health_override(enemy: Node, group_data: Dictionary) -> void:
	if not group_data.has("_respawn_current_hp"):
		return
	var hp_value := float(group_data.get("_respawn_current_hp", -1.0))
	if hp_value <= 0.0:
		return
	var max_hp_value := hp_value
	var raw_max_hp = enemy.get("max_hp")
	if raw_max_hp != null:
		max_hp_value = float(raw_max_hp)
	enemy.set("hp", clampf(hp_value, 1.0, max_hp_value))
	var hp_bar = enemy.get("hp_bar")
	if hp_bar != null:
		hp_bar.value = float(enemy.get("hp"))

func spawn_enemy_at_progress(enemy_type: String, prog: float, path_node: Node2D) -> void:
	if not path_node: return
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = normalize_enemy_category(base_config.get("category", ENEMY_CATEGORY_LAND))
	_stamp_enemy_pathing_config(base_config)
	
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	
	if _should_use_dynamic_pathing_for_enemy(base_config) and enemy.has_method("set_dynamic_pathing"):
		var enemy_parent := _get_enemy_container()
		enemy_parent.add_child(enemy)
		var source_cell := Vector2i.ZERO
		var source_world := Vector2.ZERO
		if path_node is Path2D and path_node.curve and path_node.curve.point_count > 0:
			var offset := clampf(prog, 0.0, path_node.curve.get_baked_length())
			source_world = path_node.to_global(path_node.curve.sample_baked(offset))
			source_cell = pathfinding_manager.world_to_cell(source_world)
		enemy.global_position = source_world
		enemy.set_dynamic_pathing(pathfinding_manager, source_cell)
	else:
		_attach_enemy_to_path(enemy, path_node, prog)
	active_enemy_count += 1
	
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_enemy_spawn(enemy_type)

func _get_enemy_container() -> Node:
	if not is_inside_tree():
		return self
	var scene := get_tree().current_scene
	if scene == null:
		return self
	var container := scene.get_node_or_null("WorldRoot/MapRoot/EnemyContainer")
	if container:
		return container
	return scene

func spawn_enemy_at_world_position(enemy_type: String, world_pos: Vector2) -> void:
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = normalize_enemy_category(base_config.get("category", ENEMY_CATEGORY_LAND))
	_stamp_enemy_pathing_config(base_config)
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)

	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)

	var parent := _get_enemy_container()
	parent.add_child(enemy)
	enemy.global_position = world_pos
	if _should_use_dynamic_pathing_for_enemy(base_config) and enemy.has_method("set_dynamic_pathing"):
		enemy.set_dynamic_pathing(pathfinding_manager, pathfinding_manager.world_to_cell(world_pos))
	active_enemy_count += 1

	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_enemy_spawn(enemy_type)

func _resolve_spawn_path_id(requested_path_id: String) -> String:
	# Level files can expose visual lane paths named road_lane_left/default/road_lane_right.
	# Waves may still target "default" for compatibility; in that case spread spawns
	# across available road lanes so enemies do not visually stack on one center line.
	if requested_path_id != "default":
		return requested_path_id

	var lane_ids: Array[String] = []
	if path_nodes.has("road_lane_left"):
		lane_ids.append("road_lane_left")
	if path_nodes.has("default"):
		lane_ids.append("default")
	if path_nodes.has("road_lane_right"):
		lane_ids.append("road_lane_right")

	if lane_ids.size() <= 1:
		return requested_path_id

	var selected: String = lane_ids[spawn_lane_cursor % lane_ids.size()]
	spawn_lane_cursor += 1
	return selected

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
	current_wave_has_leak = true
	var hp_rem := _enemy.get_current_hp() if _enemy.has_method("get_current_hp") else 0.0
	if game_manager and game_manager.battle_telemetry:
		var prog = _enemy.get_path_progress() if _enemy.has_method("get_path_progress") else 0.0
		var lives_after = game_manager.lives - damage
		game_manager.battle_telemetry.log_enemy_leak(_enemy.enemy_type, hp_rem, global_pos, prog, lives_after)
		
	base_damaged.emit(damage, global_pos)
	# base_damaged is handled synchronously by Main, so game_manager.lives is already updated here.
	# Respawn only if the leak did not end the run.
	if leak_respawn_enabled and (game_manager == null or game_manager.lives > 0):
		_respawn_leaked_enemy(_enemy, hp_rem)
	_on_enemy_removed()

func _respawn_leaked_enemy(enemy: Node, hp_remaining: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var path_id := _get_path_id_for_enemy(enemy)
	var respawn_data := {
		"type": str(enemy.get("enemy_type")),
		"enemy_type": str(enemy.get("enemy_type")),
		"path": path_id,
		"category": str(enemy.get("enemy_category"))
	}
	if leak_respawn_health_mode != "full" and hp_remaining > 0.0:
		respawn_data["_respawn_current_hp"] = hp_remaining
	spawn_enemy(respawn_data)
	if OS.is_debug_build():
		print("[ElementTDLeak] respawn enemy=", respawn_data["enemy_type"], " path=", path_id, " hp=", hp_remaining)

func _get_path_id_for_enemy(enemy: Node) -> String:
	var parent := enemy.get_parent()
	for key in path_nodes.keys():
		if path_nodes[key] == parent:
			return str(key)
	return "default"

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

func has_active_enemies() -> bool:
	return active_enemy_count > 0

func has_current_wave_leak() -> bool:
	return current_wave_has_leak

func is_interest_eligible() -> bool:
	return is_wave_running and active_enemy_count > 0 and not current_wave_has_leak

func get_current_wave_data() -> Dictionary:
	if current_wave_index < waves.size():
		return waves[current_wave_index]
	return {}
