extends Node

# Battle Telemetry System
# Decoupled metrics tracker for post-game analysis and balancing.

const TELEMETRY_DIR = "user://telemetry/"

var metrics: Dictionary = {}

var start_time: int = 0
var is_active: bool = false

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(TELEMETRY_DIR):
		DirAccess.make_dir_recursive_absolute(TELEMETRY_DIR)

func start_level(level_id: String, starting_lives: int, starting_gold: int) -> void:
	start_time = Time.get_ticks_msec()
	is_active = true
	
	metrics = {
		"level_id": level_id,
		"result": "incomplete",
		"lives_start": starting_lives,
		"lives_end": starting_lives,
		"gold_start": starting_gold,
		"gold_earned": starting_gold,
		"gold_spent": 0,
		"gold_remaining": starting_gold,
		"towers_built": {},
		"upgrades_purchased": {},
		"total_damage_by_tower_id": {},
		"total_kills_by_tower_id": {},
		"total_damage_by_attack_type": {},
		"enemy_spawned_by_type": {},
		"enemy_killed_by_type": {},
		"enemy_leaked_by_type": {},
		"leak_positions": [],
		"hero_damage": 0.0,
		"hero_kills": 0,
		"hero_deploy_count": 0,
		"wave_clear_times": {},
		"most_dangerous_wave": -1,
		"most_dangerous_enemy_type": "",
		"duration_sec": 0.0,
		"timestamp": Time.get_datetime_string_from_system()
	}

func log_gold_earned(amount: int) -> void:
	if not is_active: return
	metrics["gold_earned"] += amount
	metrics["gold_remaining"] += amount

func log_gold_spent(amount: int) -> void:
	if not is_active: return
	metrics["gold_spent"] += amount
	metrics["gold_remaining"] -= amount

func log_tower_built(tower_id: String, cost: int) -> void:
	if not is_active: return
	if not metrics["towers_built"].has(tower_id):
		metrics["towers_built"][tower_id] = 0
	metrics["towers_built"][tower_id] += 1
	log_gold_spent(cost)

func log_tower_upgraded(tower_id: String, level: int, cost: int) -> void:
	if not is_active: return
	var key = tower_id + "_lvl_" + str(level)
	if not metrics["upgrades_purchased"].has(key):
		metrics["upgrades_purchased"][key] = 0
	metrics["upgrades_purchased"][key] += 1
	log_gold_spent(cost)

func log_damage(source_id: String, amount: float, attack_type: String = "single") -> void:
	if not is_active: return
	
	if source_id == "hero":
		metrics["hero_damage"] += amount
	else:
		if not metrics["total_damage_by_tower_id"].has(source_id):
			metrics["total_damage_by_tower_id"][source_id] = 0.0
		metrics["total_damage_by_tower_id"][source_id] += amount
		
	if not metrics["total_damage_by_attack_type"].has(attack_type):
		metrics["total_damage_by_attack_type"][attack_type] = 0.0
	metrics["total_damage_by_attack_type"][attack_type] += amount

func log_kill(source_id: String, enemy_type: String) -> void:
	if not is_active: return
	
	if source_id == "hero":
		metrics["hero_kills"] += 1
	else:
		if not metrics["total_kills_by_tower_id"].has(source_id):
			metrics["total_kills_by_tower_id"][source_id] = 0
		metrics["total_kills_by_tower_id"][source_id] += 1
		
	if not metrics["enemy_killed_by_type"].has(enemy_type):
		metrics["enemy_killed_by_type"][enemy_type] = 0
	metrics["enemy_killed_by_type"][enemy_type] += 1

func log_enemy_spawn(enemy_type: String) -> void:
	if not is_active: return
	if not metrics["enemy_spawned_by_type"].has(enemy_type):
		metrics["enemy_spawned_by_type"][enemy_type] = 0
	metrics["enemy_spawned_by_type"][enemy_type] += 1

func log_enemy_leak(enemy_type: String, pos: Vector2) -> void:
	if not is_active: return
	if not metrics["enemy_leaked_by_type"].has(enemy_type):
		metrics["enemy_leaked_by_type"][enemy_type] = 0
	metrics["enemy_leaked_by_type"][enemy_type] += 1
	metrics["leak_positions"].append({"x": pos.x, "y": pos.y, "type": enemy_type})

func log_hero_deployed() -> void:
	if not is_active: return
	metrics["hero_deploy_count"] += 1

func log_wave_cleared(wave_index: int, duration_sec: float) -> void:
	if not is_active: return
	metrics["wave_clear_times"][str(wave_index)] = duration_sec

func end_level(result: String, final_lives: int) -> Dictionary:
	if not is_active: return {}
	
	is_active = false
	metrics["result"] = result
	metrics["lives_end"] = final_lives
	
	var end_time = Time.get_ticks_msec()
	metrics["duration_sec"] = (end_time - start_time) / 1000.0
	
	# Compute most dangerous enemy (most leaks)
	var max_leaks = 0
	var danger_enemy = ""
	for etype in metrics["enemy_leaked_by_type"]:
		if metrics["enemy_leaked_by_type"][etype] > max_leaks:
			max_leaks = metrics["enemy_leaked_by_type"][etype]
			danger_enemy = etype
	metrics["most_dangerous_enemy_type"] = danger_enemy
	
	_save_report(metrics)
	print_summary()
	return metrics

func print_summary() -> void:
	if metrics.is_empty(): return
	print("=== BATTLE TELEMETRY SUMMARY ===")
	print("Level: ", metrics["level_id"], " | Result: ", metrics["result"])
	print("Gold Efficiency: ", metrics["gold_spent"], "/", metrics["gold_earned"])
	
	var best_tower = ""
	var max_dmg = 0.0
	for t_id in metrics["total_damage_by_tower_id"]:
		var d = metrics["total_damage_by_tower_id"][t_id]
		if d > max_dmg:
			max_dmg = d
			best_tower = t_id
	print("MVP Tower: ", best_tower, " (", int(max_dmg), " dmg)")
	
	var total_leaks = 0
	for count in metrics["enemy_leaked_by_type"].values():
		total_leaks += count
	print("Total Leaks: ", total_leaks, " (Most dangerous: ", metrics["most_dangerous_enemy_type"], ")")
	print("Hero Deploys: ", metrics["hero_deploy_count"], " (", metrics["hero_kills"], " kills)")
	print("================================")
	
	# Full JSON Dump
	var json = JSON.new()
	print(json.stringify(metrics, "  "))

func _save_report(report: Dictionary) -> void:
	var filename = TELEMETRY_DIR + report["level_id"] + "_" + str(Time.get_unix_time_from_system()) + ".json"
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var json = JSON.new()
		file.store_string(json.stringify(report, "\t"))
		file.close()
		if OS.is_debug_build():
			print("[BattleTelemetry] Saved report to %s" % filename)
	else:
		push_error("[BattleTelemetry] Failed to save report to %s" % filename)
