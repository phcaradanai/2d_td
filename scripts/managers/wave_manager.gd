extends Node

## Signals for wave lifecycle
signal wave_started(wave_number: int, wave_name: String)
signal wave_completed(wave_number: int, wave_name: String, reward: int)
signal all_waves_completed()
signal boss_wave_started(wave_number: int)
## Signals for gameplay events
signal enemy_killed(reward_gold: int)
signal base_damaged(base_damage: int, global_pos: Vector2)

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
@export var waves_data_path: String = "res://data/waves/waves_01.json"
@export var enemies_data_path: String = "res://data/enemies.json"
@export var formation_planner_script: GDScript = preload("res://scripts/managers/spawn_formation_planner.gd")
const SPAWN_EFFECT_SCRIPT: GDScript = preload("res://scripts/effects/spawn_effect.gd")

const PERFORMANCE_MODE := true  # Disables spawn VFX for stable 60 FPS

# Element TD-style economy damage towers.
# Gold towers grant bonus bounty on their own kills.
# Life towers grant +1 life after a small number of their own kills.
const ECONOMY_KILL_GOLD_BONUS_PERCENT := {
	"gold_t1": 0.20,
	"gold_t2": 0.30,
	"gold_t3": 0.40,
}
const ECONOMY_KILL_LIFE_COUNTER_REQUIRED := {
	"life_t1": 6,
	"life_t2": 4,
	"life_t3": 2,
}
var economy_life_kill_counters: Dictionary = {}

func get_economy_life_kill_progress(source_id: String) -> int:
	return int(economy_life_kill_counters.get(source_id, 0))

func get_economy_life_kill_required(source_id: String) -> int:
	return int(ECONOMY_KILL_LIFE_COUNTER_REQUIRED.get(source_id, 0))

func get_economy_gold_bonus_percent(source_id: String) -> float:
	return float(ECONOMY_KILL_GOLD_BONUS_PERCENT.get(source_id, 0.0))

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]
const ELEMENT_TD_PATHING_MODE := "fixed_path"

var waves: Array = []
var enemies_config: Dictionary = {}

var wave_start_time_msec: int = 0
var current_wave_index: int = 0
var is_wave_running: bool = false
var formation_planner = null

var is_spawning: bool = false
var path_nodes: Dictionary = {} # id -> Path2D
var path_portals: Dictionary = {} # id -> Array[Dictionary]
var spawn_generation: int = 0
var spawn_lane_cursor: int = 0
var enemy_pathing_mode: String = ELEMENT_TD_PATHING_MODE
var leak_respawn_enabled: bool = false

# ── Enemy tracking (instance-based) ─────────────────────────────────────────
# Track the Set of live enemy instances instead of a bare counter.
# Rules:
#   • _track_enemy(node)   — called once per spawn; no-op on duplicate.
#   • _untrack_enemy(node) — called once per removal; no-op on unknown node.
#   • active_enemy_count   — always equals _live_enemies.size(); read-only alias.
# This makes double-add and double-remove structurally impossible.
var _live_enemies: Dictionary = {}  # instance_id (int) -> WeakRef

var active_enemy_count: int:
	get: return _live_enemies.size()

# Safety: periodic resync evicts freed nodes that somehow slipped past signals.
const _WAVE_STUCK_CHECK_INTERVAL := 3.0
var _wave_stuck_elapsed: float = 0.0

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
	if file == null:
		push_error("[WaveManager] Cannot open enemies config: " + enemies_data_path)
		return
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
	if file == null:
		push_error("[WaveManager] Cannot open waves data: " + waves_data_path)
		return
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

func setup(paths: Dictionary, portals: Dictionary = {}) -> void:
	path_nodes = paths
	path_portals = portals

func configure_from_level(level_manager: Node) -> void:
	if level_manager == null:
		return
	var data = level_manager.get("level_data")
	enemy_pathing_mode = ELEMENT_TD_PATHING_MODE
	if data is Dictionary:
		# Element TD WC3 clone rule: levels are fixed-path only. Ignore any older
		# dynamic-maze/pathing flags that may remain in legacy level data.
		leak_respawn_enabled = bool(data.get("leak_respawn_enabled", true))

func set_pathfinding_manager(_p_pathfinding_manager: Node) -> void:
	# Compatibility shim for old scene wiring. Dynamic maze pathfinding is no
	# longer used by WaveManager in Element TD WC3 mode.
	pass

func reset_waves() -> void:
	spawn_generation += 1
	spawn_lane_cursor = 0
	is_wave_running = false
	is_spawning = false
	current_wave_index = 0
	_live_enemies.clear()
	_wave_stuck_elapsed = 0.0
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

	var groups: Array = wave_data.get("groups", [])
	var has_boss := groups.any(func(g): return _is_boss_group(g))
	if has_boss:
		boss_wave_started.emit(active_wave_number)
	
	if OS.is_debug_build(): print("Starting Wave ", active_wave_number, ": ", active_wave_name, ". Next index=", current_wave_index)
	
	var current_gen = spawn_generation
	
	# BUILD FORMATION PLAN
	if formation_planner == null:
		formation_planner = formation_planner_script.new(enemies_config)
	var plan = formation_planner.build_plan(wave_data, current_wave_index - 1)
	
	DebugLog.trace("formation", "[FORMATION] wave=%d groups=%d events=%d duration=%.2fs" % [
		active_wave_number, wave_data.get("groups", []).size(),
		plan.get("events", []).size(), plan.get("total_duration", 0.0)
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

func _is_boss_group(group: Dictionary) -> bool:
	var enemy_type := str(group.get("type", group.get("enemy_type", "")))
	if enemy_type == "boss" or enemy_type.begins_with("boss_"):
		return true
	var cfg: Dictionary = enemies_config.get(enemy_type, {})
	var tags: Array = cfg.get("tags", [])
	return tags.has("boss")

func spawn_wave_groups(_groups: Array, _gen: int) -> void:
	# Deprecated in favor of spawn_wave_events but kept for reference/safety
	DebugLog.warn_once("spawn_wave_groups_deprecated", "[WaveManager] spawn_wave_groups() is deprecated — use spawn_wave_events()")

func _wait_unpaused(seconds: float, gen: int) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if gen != spawn_generation: return
		
		await get_tree().process_frame
		
		if game_manager != null and game_manager.is_paused:
			continue
			
		elapsed += get_process_delta_time()

func spawn_enemy(group_data: Dictionary) -> Node:
	FrameSpikeLogger.begin("enemy_spawn")
	var result := _spawn_enemy_impl(group_data)
	FrameSpikeLogger.end("enemy_spawn")
	return result

func _spawn_enemy_impl(group_data: Dictionary) -> Node:  # extracted for FSL timing
	var requested_path_id: String = str(group_data.get("path", "default"))
	var path_id: String = _resolve_spawn_path_id(requested_path_id)
	var path_node = path_nodes.get(path_id, path_nodes.get("default"))
	if not path_node: return null

	var enemy_type = group_data.get("enemy_type", group_data.get("type", "basic"))
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = resolve_enemy_category(group_data)
	base_config["pathing_mode"] = ELEMENT_TD_PATHING_MODE

	# Merge group overrides into base config
	for key in group_data.keys():
		if key != "count" and key != "spawn_delay":
			base_config[key] = group_data[key]

	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	if enemy.has_method("set_path_portals"):
		enemy.set_path_portals(path_portals.get(path_id, []))

	var is_debug_probe := bool(group_data.get("debug_probe", false))
	if is_debug_probe:
		enemy.died.connect(_on_sandbox_enemy_died)
		enemy.reached_base.connect(_on_sandbox_enemy_reached_base)
	else:
		enemy.died.connect(_on_enemy_died)
		enemy.reached_base.connect(_on_enemy_reached_base)
	
	DebugLog.trace("formation", "[FORMATION] spawn enemy=%s lane=%s t=%.2f position=%s formation=%s" % [
		enemy_type, path_id, (Time.get_ticks_msec() - wave_start_time_msec) / 1000.0,
		group_data.get("tactical_position", "middle"), group_data.get("formation_id", "none")
	])
		
	path_node.add_child(enemy)
	if not is_debug_probe:
		_track_enemy(enemy)
	
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

	return enemy

func _uses_dynamic_pathing(_base_config: Dictionary) -> bool:
	return false

func _on_sandbox_enemy_died(_enemy: Node, _reward: int) -> void:
	# Sandbox probes should not award gold or affect wave completion.
	pass

func _on_sandbox_enemy_reached_base(_enemy: Node, _damage: int, _global_pos: Vector2) -> void:
	# Sandbox probes should not damage the core or affect wave completion.
	pass

func spawn_sandbox_enemy(enemy_type: String = "basic", category: String = "land") -> void:
	var normalized_category := normalize_enemy_category(category)
	var chosen_type := enemy_type
	if normalized_category == ENEMY_CATEGORY_AIR and chosen_type == "basic":
		chosen_type = "flyer"
	spawn_enemy({
		"type": chosen_type,
		"enemy_type": chosen_type,
		"category": normalized_category,
		"path": "default",
		"debug_probe": true
	})

func spawn_enemy_at_progress(enemy_type: String, prog: float, path_node: Node2D) -> void:
	if not path_node: return
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = normalize_enemy_category(base_config.get("category", ENEMY_CATEGORY_LAND))
	base_config["pathing_mode"] = ELEMENT_TD_PATHING_MODE
	
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)
	
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	
	path_node.add_child(enemy)
	enemy.progress = prog
	for p_id in path_nodes:
		if path_nodes[p_id] == path_node:
			if enemy.has_method("set_path_portals"):
				enemy.set_path_portals(path_portals.get(str(p_id), []))
			break
	_track_enemy(enemy)
	
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
	# Debug-only helper kept for tooling. Fixed-path gameplay should use
	# spawn_enemy/spawn_enemy_at_progress so creeps stay attached to Path2D lanes.
	var base_config = enemies_config.get(enemy_type, {}).duplicate()
	base_config["category"] = normalize_enemy_category(base_config.get("category", ENEMY_CATEGORY_LAND))
	base_config["pathing_mode"] = ELEMENT_TD_PATHING_MODE
	var enemy = enemy_scene.instantiate()
	if enemy.has_method("setup"):
		enemy.setup(base_config)

	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)

	var parent := _get_enemy_container()
	parent.add_child(enemy)
	enemy.global_position = world_pos
	_track_enemy(enemy)

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
	var source_id := _get_enemy_last_damage_source(_enemy)
	_apply_economy_tower_kill_effects(source_id, reward)
	enemy_killed.emit(reward)
	_untrack_enemy(_enemy)
	_on_enemy_removed()

func _get_enemy_last_damage_source(enemy: Variant) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return ""
	if enemy.has_method("get_last_damage_source"):
		return str(enemy.get_last_damage_source())
	# Defensive fallback for older enemy scripts.
	var raw_source = enemy.get("last_damage_source") if enemy.has_method("get") else null
	return str(raw_source) if raw_source != null else ""

func _apply_economy_tower_kill_effects(source_id: String, reward: int) -> void:
	if source_id == "" or game_manager == null:
		return

	if ECONOMY_KILL_GOLD_BONUS_PERCENT.has(source_id):
		var bonus := int(round(float(reward) * float(ECONOMY_KILL_GOLD_BONUS_PERCENT[source_id])))
		if bonus > 0:
			game_manager.add_gold(bonus)
			DebugLog.trace("economy", "[Economy][GoldTower] source=%s base=%d bonus=%d" % [source_id, reward, bonus])

	if ECONOMY_KILL_LIFE_COUNTER_REQUIRED.has(source_id):
		var required : int = max(1, int(ECONOMY_KILL_LIFE_COUNTER_REQUIRED[source_id]))
		var count := int(economy_life_kill_counters.get(source_id, 0)) + 1
		if count >= required:
			count = 0
			if game_manager.has_method("add_lives"):
				game_manager.add_lives(1, source_id)
		economy_life_kill_counters[source_id] = count

func _on_enemy_reached_base(_enemy: Node, damage: int, global_pos: Vector2) -> void:
	# Instance-set guard: if this enemy isn't in _live_enemies it was already
	# counted out (e.g. via _on_enemy_died in the same frame). Skip entirely.
	var enemy_id := -1
	if _enemy != null and is_instance_valid(_enemy):
		enemy_id = _enemy.get_instance_id()
	if not _live_enemies.has(enemy_id):
		return

	var hp_rem := 0.0
	var prog := 0.0
	if _enemy != null and is_instance_valid(_enemy):
		hp_rem = _enemy.get_current_hp() if _enemy.has_method("get_current_hp") else 0.0
		prog = _enemy.get_path_progress() if _enemy.has_method("get_path_progress") else 0.0

	if game_manager and game_manager.battle_telemetry and _enemy != null and is_instance_valid(_enemy):
		var lives_after = game_manager.lives - damage
		game_manager.battle_telemetry.log_enemy_leak(_enemy.enemy_type, hp_rem, global_pos, prog, lives_after)

	base_damaged.emit(damage, global_pos)

	# Element TD WC3-style leak loop: respawn the enemy once at the path start.
	# Mark it so it cannot trigger a second respawn and create an infinite loop.
	if leak_respawn_enabled and _should_respawn_leaked_enemy(_enemy):
		_respawn_leaked_enemy(_enemy, hp_rem)

	_untrack_enemy(_enemy)
	_on_enemy_removed()

func _process(delta: float) -> void:
	if not is_wave_running or is_spawning:
		_wave_stuck_elapsed = 0.0
		return
	if _live_enemies.is_empty():
		_check_wave_completion()
		return
	# Periodic sweep: evict freed/done weak-refs that slipped past signals.
	_wave_stuck_elapsed += delta
	if _wave_stuck_elapsed >= _WAVE_STUCK_CHECK_INTERVAL:
		_wave_stuck_elapsed = 0.0
		var stale: Array = []
		for eid in _live_enemies:
			var ref: WeakRef = _live_enemies[eid]
			var node = ref.get_ref()
			if node == null or not is_instance_valid(node) \
					or bool(node.get("is_dead_flag")) \
					or bool(node.get("reached_base_flag")):
				stale.append(eid)
		if not stale.is_empty():
			if OS.is_debug_build():
				print("[WaveManager] Swept %d orphaned enemy refs (wave %d)." % [stale.size(), active_wave_number])
			for eid in stale:
				_live_enemies.erase(eid)
		_check_wave_completion()

func _should_respawn_leaked_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not is_wave_running:
		return false
	if game_manager != null and int(game_manager.get("lives")) <= 0:
		return false
	if enemy.has_method("get_current_hp") and float(enemy.get_current_hp()) <= 0.0:
		return false
	# An already-respawned enemy must not respawn again — prevents infinite leak loops.
	if enemy.has_meta("is_leak_respawn"):
		return false
	return true

func _respawn_leaked_enemy(enemy: Node, hp_remaining: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_type := str(enemy.get_enemy_type()) if enemy.has_method("get_enemy_type") else str(enemy.get("enemy_type"))
	if enemy_type == "" or not enemies_config.has(enemy_type):
		enemy_type = "basic"
	var category := ENEMY_CATEGORY_LAND
	if enemy.has_method("get_enemy_category"):
		category = normalize_enemy_category(enemy.get_enemy_category())
	else:
		category = normalize_enemy_category(enemy.get("enemy_category"))
	var path_id := _get_path_id_for_enemy(enemy)
	var respawned := spawn_enemy({
		"type": enemy_type,
		"enemy_type": enemy_type,
		"category": category,
		"path": path_id,
		"leak_respawn": true
	})
	if respawned != null and is_instance_valid(respawned):
		respawned.set_meta("is_leak_respawn", true)
	_apply_respawn_health(respawned, hp_remaining)
	DebugLog.trace("formation", "[LeakRespawn] enemy=%s path=%s hp=%.1f" % [enemy_type, path_id, hp_remaining])

func _get_path_id_for_enemy(enemy: Node) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return "default"
	var parent := enemy.get_parent()
	for key in path_nodes.keys():
		if path_nodes[key] == parent:
			return str(key)
	return "default"

func _apply_respawn_health(enemy: Node, hp_remaining: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var max_hp := float(enemy.get("max_hp"))
	if max_hp <= 0.0:
		return
	var preserved_hp := clampf(hp_remaining, 1.0, max_hp)
	enemy.set("hp", preserved_hp)
	if enemy.has_method("_update_health_visual_state"):
		enemy._update_health_visual_state(true)

## Add an enemy to the live set.  Duplicate spawns are silently ignored.
func _track_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _live_enemies.has(id):
		return  # already tracked — no double-count
	_live_enemies[id] = weakref(enemy)

## Remove an enemy from the live set.  Unknown nodes are silently ignored.
func _untrack_enemy(enemy: Node) -> void:
	var id := -1
	if enemy != null and is_instance_valid(enemy):
		id = enemy.get_instance_id()
	if id >= 0 and _live_enemies.has(id):
		_live_enemies.erase(id)
		return
	# Fallback: sweep for a freed/invalid weak-ref with this id or scan all.
	# This handles the rare case where the node was freed before _untrack.
	var stale: Array = []
	for eid in _live_enemies:
		var ref: WeakRef = _live_enemies[eid]
		if ref.get_ref() == null:
			stale.append(eid)
		elif id >= 0 and eid == id:
			stale.append(eid)
	for eid in stale:
		_live_enemies.erase(eid)

func _on_enemy_removed() -> void:
	_check_wave_completion()

func _check_wave_completion() -> void:
	if is_wave_running and not is_spawning and _live_enemies.is_empty():
		is_wave_running = false

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
