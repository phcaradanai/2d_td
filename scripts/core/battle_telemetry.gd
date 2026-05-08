extends Node

# Battle Telemetry System
# Decoupled metrics tracker for post-game analysis and balancing.

const TELEMETRY_DIR = "user://telemetry/"

var metrics: Dictionary = {}
var current_wave_stats: Dictionary = {}
var is_active: bool = false

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(TELEMETRY_DIR):
		DirAccess.make_dir_recursive_absolute(TELEMETRY_DIR)

func start_level(level_id: String, level_name: String, starting_lives: int, starting_gold: int) -> void:
	is_active = true
	
	metrics = {
		"level_id": level_id,
		"level_name": level_name,
		"started_at_msec": Time.get_ticks_msec(),
		"ended_at_msec": 0,
		"clear_time_sec": 0.0,
		"result": "abandoned", # Default until finalized
		
		"lives_start": starting_lives,
		"lives_end": starting_lives,
		"lives_lost": 0,
		
		"gold_start": starting_gold,
		"gold_earned_from_kills": 0,
		"gold_earned_from_waves": 0,
		"gold_earned_total": 0,
		"gold_spent_on_towers": 0,
		"gold_spent_on_upgrades": 0,
		"gold_spent_on_hero": 0,
		"gold_spent_total": 0,
		"gold_remaining": starting_gold,
		
		"score": 0,
		"star_count": 0,
		"perfect_clear": true,
		
		"waves_total": 0,
		"waves_completed": 0,
		
		"enemies_spawned_total": 0,
		"enemies_killed_total": 0,
		"enemies_leaked_total": 0,
		
		"enemies_spawned_by_type": {},
		"enemies_killed_by_type": {},
		"enemies_leaked_by_type": {},
		
		"damage_by_tower_type": {},
		"kills_by_tower_type": {},
		"damage_by_attack_type": {},
		
		"tower_build_count_by_type": {},
		"tower_upgrade_count_by_type": {},
		"tower_sell_count_by_type": {},
		"tower_total_spent_by_type": {},
		
		"hero_deploy_count": 0,
		"hero_damage": 0.0,
		"hero_kills": 0,
		"hero_active_time_sec": 0.0,
		
		"wave_stats": {},
		"leak_events": [],
		"notable_events": [],
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	if OS.is_debug_build():
		print("[BattleTelemetry] Level started: ", level_id)

func start_wave(wave_index: int, wave_name: String) -> void:
	if not is_active: return
	
	current_wave_stats = {
		"wave_index": wave_index,
		"wave_name": wave_name,
		"started_at_sec": (Time.get_ticks_msec() - metrics["started_at_msec"]) / 1000.0,
		"ended_at_sec": 0,
		"duration_sec": 0.0,
		"enemies_spawned_by_type": {},
		"enemies_killed_by_type": {},
		"enemies_leaked_by_type": {},
		"damage_by_tower_type": {},
		"hero_damage": 0.0,
		"lives_lost": 0,
		"gold_earned": 0,
		"status": "in_progress"
	}
	
	if OS.is_debug_build():
		print("[BattleTelemetry] Wave started: ", wave_index)

func log_wave_completed(wave_index: int, status: String, gold_reward: int) -> void:
	if not is_active: return
	
	var now_sec = (Time.get_ticks_msec() - metrics["started_at_msec"]) / 1000.0
	current_wave_stats["ended_at_sec"] = now_sec
	current_wave_stats["duration_sec"] = now_sec - current_wave_stats["started_at_sec"]
	current_wave_stats["status"] = status
	current_wave_stats["gold_earned"] = gold_reward
	
	metrics["wave_stats"][str(wave_index)] = current_wave_stats.duplicate()
	metrics["waves_completed"] = wave_index
	
	if OS.is_debug_build():
		print("[BattleTelemetry] Wave completed: ", wave_index, " status=", status)

func log_enemy_spawn(enemy_type: String) -> void:
	if not is_active: return
	
	metrics["enemies_spawned_total"] += 1
	_increment_dict(metrics["enemies_spawned_by_type"], enemy_type)
	
	if not current_wave_stats.is_empty():
		_increment_dict(current_wave_stats["enemies_spawned_by_type"], enemy_type)

func log_enemy_kill(source_type: String, enemy_type: String) -> void:
	if not is_active: return
	
	metrics["enemies_killed_total"] += 1
	_increment_dict(metrics["enemies_killed_by_type"], enemy_type)
	
	if not current_wave_stats.is_empty():
		_increment_dict(current_wave_stats["enemies_killed_by_type"], enemy_type)
	
	if source_type == "hero":
		metrics["hero_kills"] += 1
	else:
		_increment_dict(metrics["kills_by_tower_type"], source_type)

func log_enemy_leak(enemy_type: String, hp_remaining: float, pos: Vector2, progress: float, lives_after: int) -> void:
	if not is_active: return
	
	metrics["enemies_leaked_total"] += 1
	_increment_dict(metrics["enemies_leaked_by_type"], enemy_type)
	
	if not current_wave_stats.is_empty():
		_increment_dict(current_wave_stats["enemies_leaked_by_type"], enemy_type)
		current_wave_stats["lives_lost"] += 1
	
	metrics["lives_lost"] += 1
	metrics["perfect_clear"] = false
	
	var leak_event = {
		"time_sec": (Time.get_ticks_msec() - metrics["started_at_msec"]) / 1000.0,
		"wave_index": metrics["waves_completed"] + 1,
		"enemy_type": enemy_type,
		"enemy_remaining_hp": hp_remaining,
		"path_progress": progress,
		"leak_position": {"x": pos.x, "y": pos.y},
		"lives_after_leak": lives_after
	}
	metrics["leak_events"].append(leak_event)

func log_damage(source_type: String, amount: float, attack_type: String, enemy_type: String) -> void:
	if not is_active: return
	
	if source_type == "hero":
		metrics["hero_damage"] += amount
		if not current_wave_stats.is_empty():
			current_wave_stats["hero_damage"] += amount
	else:
		_increment_dict(metrics["damage_by_tower_type"], source_type, amount)
		if not current_wave_stats.is_empty():
			_increment_dict(current_wave_stats["damage_by_tower_type"], source_type, amount)
			
	_increment_dict(metrics["damage_by_attack_type"], attack_type, amount)

func log_tower_built(tower_type: String, cell: Vector2i, world_pos: Vector2, cost: int) -> void:
	if not is_active: return
	
	_increment_dict(metrics["tower_build_count_by_type"], tower_type)
	_increment_dict(metrics["tower_total_spent_by_type"], tower_type, cost)
	
	log_notable_event("tower_built", {
		"type": tower_type,
		"cell": {"x": cell.x, "y": cell.y},
		"pos": {"x": world_pos.x, "y": world_pos.y},
		"cost": cost
	})
	
	metrics["gold_spent_on_towers"] += cost

func log_tower_upgraded(tower_type: String, from_level: int, to_level: int, cost: int) -> void:
	if not is_active: return
	
	_increment_dict(metrics["tower_upgrade_count_by_type"], tower_type)
	_increment_dict(metrics["tower_total_spent_by_type"], tower_type, cost)
	
	log_notable_event("tower_upgraded", {
		"type": tower_type,
		"from": from_level,
		"to": to_level,
		"cost": cost
	})
	
	metrics["gold_spent_on_upgrades"] += cost

func log_tower_sold(tower_type: String, refund: int) -> void:
	if not is_active: return
	
	_increment_dict(metrics["tower_sell_count_by_type"], tower_type)
	log_gold_earned(refund, "sell")
	
	log_notable_event("tower_sold", {
		"type": tower_type,
		"refund": refund
	})

func log_hero_deployed(pos: Vector2, cost: int) -> void:
	if not is_active: return
	
	metrics["hero_deploy_count"] += 1
	
	log_notable_event("hero_deployed", {
		"pos": {"x": pos.x, "y": pos.y},
		"cost": cost
	})
	
	metrics["gold_spent_on_hero"] += cost

func log_hero_active_time(delta: float) -> void:
	if not is_active: return
	metrics["hero_active_time_sec"] += delta

func log_gold_earned(amount: int, source: String = "other") -> void:
	if not is_active: return
	
	metrics["gold_earned_total"] += amount
	metrics["gold_remaining"] += amount
	
	match source:
		"kill": metrics["gold_earned_from_kills"] += amount
		"wave": metrics["gold_earned_from_waves"] += amount
		"sell": pass # Handled by generic earned_total

func log_gold_spent(amount: int) -> void:
	if not is_active: return
	metrics["gold_spent_total"] += amount
	metrics["gold_remaining"] -= amount

func log_notable_event(event_type: String, data: Dictionary) -> void:
	if not is_active: return
	
	var event = {
		"time_sec": (Time.get_ticks_msec() - metrics["started_at_msec"]) / 1000.0,
		"wave_index": metrics["waves_completed"] + 1,
		"event_type": event_type,
		"data": data
	}
	metrics["notable_events"].append(event)

func end_level(result: String, final_lives: int, final_gold: int, score: int, stars: int, total_waves: int) -> Dictionary:
	if not is_active: return {}
	
	is_active = false
	metrics["ended_at_msec"] = Time.get_ticks_msec()
	metrics["clear_time_sec"] = (metrics["ended_at_msec"] - metrics["started_at_msec"]) / 1000.0
	metrics["result"] = result
	metrics["lives_end"] = final_lives
	metrics["gold_remaining"] = final_gold
	metrics["score"] = score
	metrics["star_count"] = stars
	metrics["waves_total"] = total_waves
	
	if final_lives < metrics["lives_start"]:
		metrics["perfect_clear"] = false
	
	# Bake balance analysis into metrics before saving
	metrics["balance_analysis"] = get_balance_analysis()
	
	_save_report()
	
	if OS.is_debug_build():
		print_summary()
		print_balance_analysis()
	
	return metrics

func get_summary() -> Dictionary:
	return metrics

func to_json_string() -> String:
	return JSON.stringify(metrics, "\t")

func print_summary() -> void:
	if metrics.is_empty(): return
	
	print("\n[BATTLE_REPORT]")
	print("level=%s" % metrics.get("level_id", "unknown"))
	print("result=%s" % metrics.get("result", "abandoned"))
	print("perfect=%s" % str(metrics.get("perfect_clear", false)))
	print("time=%.1f" % metrics.get("clear_time_sec", 0.0))
	print("waves=%d/%d" % [metrics.get("waves_completed", 0), metrics.get("waves_total", 0)])
	print("lives=%d/%d" % [metrics.get("lives_end", 0), metrics.get("lives_start", 20)])
	print("gold_start=%d" % metrics.get("gold_start", 0))
	print("gold_earned_total=%d (kills:%d, waves:%d)" % [
		metrics.get("gold_earned_total", 0),
		metrics.get("gold_earned_from_kills", 0),
		metrics.get("gold_earned_from_waves", 0)
	])
	print("gold_spent_total=%d (towers:%d, upgrades:%d, hero:%d)" % [
		metrics.get("gold_spent_total", 0),
		metrics.get("gold_spent_on_towers", 0),
		metrics.get("gold_spent_on_upgrades", 0),
		metrics.get("gold_spent_on_hero", 0)
	])
	print("gold_remaining=%d" % metrics.get("gold_remaining", 0))
	
	# Validate Invariant
	var expected = metrics.get("gold_start", 0) + metrics.get("gold_earned_total", 0) - metrics.get("gold_spent_total", 0)
	if expected != metrics.get("gold_remaining", 0):
		print("[TELEMETRY_MONEY_MISMATCH] expected=%d actual=%d diff=%d" % [
			expected, metrics.get("gold_remaining", 0), metrics.get("gold_remaining", 0) - expected
		])
		
	print("enemies_killed=%d" % metrics.get("enemies_killed_total", 0))
	print("enemies_leaked=%d" % metrics.get("enemies_leaked_total", 0))
	
	# Find top damage tower
	var top_tower = "None"
	var max_dmg = 0.0
	for t_type in metrics["damage_by_tower_type"]:
		if metrics["damage_by_tower_type"][t_type] > max_dmg:
			max_dmg = metrics["damage_by_tower_type"][t_type]
			top_tower = t_type
	print("top_damage_tower=%s" % top_tower)
	
	# Find top leaked enemy
	var top_leak = "None"
	var max_leaks = 0
	for e_type in metrics["enemies_leaked_by_type"]:
		if metrics["enemies_leaked_by_type"][e_type] > max_leaks:
			max_leaks = metrics["enemies_leaked_by_type"][e_type]
			top_leak = e_type
	print("top_leaked_enemy=%s" % top_leak)
	
	# Find danger wave (most leaks)
	var danger_wave = 0
	var max_wave_leaks = 0
	for w_idx in metrics["wave_stats"]:
		var w = metrics["wave_stats"][w_idx]
		var w_leaks = 0
		for count in w["enemies_leaked_by_type"].values():
			w_leaks += count
		if w_leaks > max_wave_leaks:
			max_wave_leaks = w_leaks
			danger_wave = int(w_idx)
	if danger_wave > 0:
		print("danger_wave=%d" % danger_wave)
	else:
		print("danger_wave=None")
	print("================\n")

func print_balance_analysis() -> void:
	var analysis = get_balance_analysis()
	if analysis.is_empty(): return
	
	print("[BALANCE_ANALYSIS]")
	print("level=%s" % analysis.get("level_id", "unknown"))
	print("difficulty_rating=%s" % analysis.get("difficulty_rating", "Unknown"))
	print("reason=%s" % analysis.get("reason", "N/A"))
	print("gold_remaining_ratio=%.1f%%" % (analysis.get("gold_remaining_ratio", 0.0) * 100.0))
	print("gold_spent_ratio=%.1f%%" % (analysis.get("gold_spent_ratio", 0.0) * 100.0))
	print("tower_dominance=%s" % analysis.get("tower_dominance", "None"))
	print("hero_relevance=%s" % analysis.get("hero_relevance", "N/A"))
	print("recommended_actions:")
	for action in analysis.get("recommended_actions", []):
		print("- %s" % action)
	print("================\n")

func get_balance_analysis() -> Dictionary:
	if metrics.is_empty(): return {}
	
	var level_id = metrics.get("level_id", "unknown")
	var is_final_level = level_id == "level_20"
	
	var total_available_gold = metrics.get("gold_start", 0) + metrics.get("gold_earned_total", 0)
	var gold_remaining = metrics.get("gold_remaining", 0)
	var gold_spent = metrics.get("gold_spent_total", 0)
	
	var gold_remaining_ratio = 0.0
	if total_available_gold > 0:
		gold_remaining_ratio = float(gold_remaining) / float(total_available_gold)
	
	var gold_spent_ratio = 0.0
	if total_available_gold > 0:
		gold_spent_ratio = float(gold_spent) / float(total_available_gold)
		
	# Tower Dominance
	var top_tower = "None"
	var max_dmg = 0.0
	var total_dmg = 0.0
	for t_type in metrics.get("damage_by_tower_type", {}):
		var dmg = metrics["damage_by_tower_type"][t_type]
		total_dmg += dmg
		if dmg > max_dmg:
			max_dmg = dmg
			top_tower = t_type
	
	var top_tower_ratio = 0.0
	if total_dmg > 0:
		top_tower_ratio = max_dmg / total_dmg
		
	# Hero Usage
	var hero_used = metrics.get("hero_deploy_count", 0) > 0
	
	# Pressure (Leaks/Lives)
	var lives_lost = metrics.get("lives_lost", 0)
	var perfect_clear = metrics.get("perfect_clear", true)
	
	# Danger Wave
	var danger_wave = 0
	var max_wave_leaks = 0
	for w_idx in metrics.get("wave_stats", {}):
		var w = metrics["wave_stats"][w_idx]
		var w_leaks = 0
		for count in w.get("enemies_leaked_by_type", {}).values():
			w_leaks += count
		if w_leaks > max_wave_leaks:
			max_wave_leaks = w_leaks
			danger_wave = int(w_idx)

	# Determine Difficulty Rating
	var rating = "Good"
	var reasons = []
	var actions = []
	
	if metrics.get("result", "") == "defeat":
		rating = "Too Hard"
		reasons.append("Player defeated")
		actions.append("Increase starting gold")
		actions.append("Reduce early wave density")
	else:
		if gold_remaining_ratio > 0.40:
			rating = "Too Easy"
			reasons.append("High remaining gold (%.1f%%)" % (gold_remaining_ratio * 100.0))
			actions.append("Reduce gold rewards from waves/kills")
			actions.append("Increase enemy HP or count")
		elif gold_remaining_ratio > 0.25:
			rating = "Slightly Easy"
			reasons.append("Moderate remaining gold (%.1f%%)" % (gold_remaining_ratio * 100.0))
			
		if perfect_clear and danger_wave == 0:
			reasons.append("No pressure detected (Perfect Clear + No Leaks)")
			actions.append("Add high-speed or tanky units to mid-game waves")
			
	if top_tower_ratio > 0.55:
		reasons.append("Tower dominance: %s (%.1f%% dmg)" % [top_tower.replace("_tower", ""), top_tower_ratio * 100.0])
		actions.append("Add enemies resistant to %s" % top_tower.replace("_tower", ""))
		
	if not hero_used:
		reasons.append("Hero not utilized")
		actions.append("Create situations where Hero utility is needed (e.g. mobile threats)")

	# Specific Final Level Logic
	if is_final_level:
		if rating == "Too Easy" or rating == "Slightly Easy":
			actions.append("CRITICAL: Final level should be more taxing on resources")
	
	return {
		"level_id": level_id,
		"difficulty_rating": rating,
		"reason": ", ".join(reasons) if not reasons.is_empty() else "Balanced performance",
		"gold_remaining_ratio": gold_remaining_ratio,
		"gold_spent_ratio": gold_spent_ratio,
		"tower_dominance": top_tower.replace("_tower", "") if top_tower != "None" else "None",
		"tower_dominance_ratio": top_tower_ratio,
		"hero_relevance": "Used" if hero_used else "Not Used",
		"recommended_actions": actions
	}

func _save_report() -> void:
	var timestamp = Time.get_unix_time_from_system()
	var filename = TELEMETRY_DIR + metrics["level_id"] + "_" + str(timestamp) + ".json"
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(to_json_string())
		file.close()
		if OS.is_debug_build():
			print("[BattleTelemetry] Saved report to %s" % filename)

func _increment_dict(dict: Dictionary, key: String, amount: float = 1.0) -> void:
	if not dict.has(key):
		dict[key] = 0.0
	dict[key] += amount
