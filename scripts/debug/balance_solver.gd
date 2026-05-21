extends Node

# Perfect Play Balance Solver
# This script searches for optimal plans and suggests balance adjustments.

const TOWERS_CONFIG_PATH = "res://data/towers_tree.json"
const ENEMIES_CONFIG_PATH = "res://data/enemies.json"
const OUTPUT_DIR = "user://balance_reports/"

var towers_config = {}
var enemies_config = {}
var current_level_data = {}
var current_level_id = ""
var current_waves_data = []
var current_level_curves = {}
var formation_planner = null

const FORMATION_PLANNER_SCRIPT = preload("res://scripts/managers/spawn_formation_planner.gd")
const ENEMY_CATEGORY_AIR := "air"
var last_candidate_count: int = 0
var auto_clear_verbose_solver_logs: bool = false

class GameState:
	var gold: int = 0
	var lives: int = 0
	var wave_index: int = 0
	var towers: Array = [] # { type, cell, level, cooldown }
	var action_log: Array = []
	var plan: Dictionary = {
		"initial_actions": [],
		"wave_actions": {} # "1": [actions]
	}

	func duplicate():
		var new_state = GameState.new()
		new_state.gold = gold
		new_state.lives = lives
		new_state.wave_index = wave_index
		new_state.towers = towers.duplicate(true)
		new_state.action_log = action_log.duplicate()
		new_state.plan = plan.duplicate(true)
		return new_state

func _ready():
	_ensure_output_dir()
	load_configs()

func _ensure_output_dir():
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

func load_configs():
	towers_config = _load_json(TOWERS_CONFIG_PATH)
	enemies_config = _load_json(ENEMIES_CONFIG_PATH)
	formation_planner = FORMATION_PLANNER_SCRIPT.new(enemies_config)

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK: return {}
	return json.data if json.data is Dictionary or json.data is Array else {}

# --- Solver Core ---

func solve_level_with_gold_testing(level_id: String, minimum_gold: int = -1) -> Dictionary:
	current_level_id = level_id
	var level_path = "res://data/levels/%s.json" % level_id
	current_level_data = _load_json(level_path)
	if current_level_data.is_empty():
		return {"status": "ERROR", "reason": "Level not found"}

	var waves_path = current_level_data.get("waves_path", "")
	var wave_json = _load_json(waves_path)
	if wave_json is Array:
		current_waves_data = wave_json
	elif wave_json is Dictionary:
		current_waves_data = wave_json.get("waves", [])
	else:
		current_waves_data = []
		
	_build_level_curves()

	var base_gold = current_level_data.get("starting_gold", 0)
	var gold_candidates = [
		base_gold,
		base_gold + 10,
		base_gold + 20,
		base_gold + 30,
		base_gold + 40,
		base_gold + 50,
		base_gold + 75,
		base_gold + 100
	]

	var best_result = null

	for gold in gold_candidates:
		if minimum_gold >= 0 and gold < minimum_gold:
			continue
		print("[AUTO_CLEAR] Testing starting_gold=%d" % gold)
		var result = _solve_with_gold(gold)
		result["tested_gold"] = gold
		result["gold_candidates"] = gold_candidates
		if result.get("status", "") == "PASS":
			result["starting_gold"] = gold
			result["original_gold"] = base_gold
			result["result_state"] = "FOUND_AT_CURRENT_GOLD" if gold == base_gold else "FOUND_WITH_DEBUG_GOLD"
			if not result.has("plan") or not (result["plan"] is Dictionary):
				result["status"] = "FAIL"
				result["reason"] = "Solver PASS had no plan"
				if best_result == null or int(result.get("wave", 0)) > int(best_result.get("wave", 0)):
					best_result = result
				continue
			result["plan"]["starting_gold_used"] = gold
			result["plan"]["original_starting_gold"] = base_gold
			result["plan"]["result_state"] = result["result_state"]
			_normalize_plan_wave_actions(result["plan"])
			var validation: Dictionary = validate_plan_for_level(result["plan"], gold)
			if not validation.get("valid", false):
				print("[AUTO_CLEAR] Rejected simulated pass: %s" % str(validation.get("reason", "invalid plan")))
				result["status"] = "FAIL"
				result["reason"] = str(validation.get("reason", "Plan failed validation"))
				result["wave"] = int(validation.get("wave", result.get("wave", 1)))
				if best_result == null or int(result.get("wave", 0)) > int(best_result.get("wave", 0)):
					best_result = result
				continue
			result["plan"]["validated"] = true
			result["plan"]["expected_lives_lost"] = 0
			result["plan"]["covers_all_waves"] = true
			result["plan"]["total_waves"] = current_waves_data.size()
			result["plan"]["plan_quality"] = validation.get("quality", "validated")
			result["validation"] = validation
			print("[AUTO_CLEAR] Found validated plan, expected lives lost=0")
			return result
		if best_result == null or int(result.get("wave", 0)) > int(best_result.get("wave", 0)):
			best_result = result

	if best_result == null:
		best_result = {"status": "FAIL", "wave": 1, "reason": "No gold candidates available", "total_candidates_tested": 0}
	best_result["starting_gold"] = base_gold
	best_result["original_gold"] = base_gold
	best_result["gold_candidates"] = gold_candidates
	best_result["result_state"] = "NOT_FOUND"
	return best_result

func _solve_with_gold(gold_amount: int) -> Dictionary:
	var initial_candidates = generate_initial_build_candidates(gold_amount)
	if initial_candidates.is_empty():
		return {"status": "FAIL", "wave": 1, "reason": "No valid opening candidates generated", "total_candidates_tested": 0}

	last_candidate_count = initial_candidates.size()
	print("[AUTO_CLEAR] Generated %d candidate openings" % last_candidate_count)

	return _solve_from_state_with_beam(initial_candidates)

func solve_from_state(state, level_id: String) -> Dictionary:
	current_level_id = level_id
	var level_path = "res://data/levels/%s.json" % level_id
	current_level_data = _load_json(level_path)
	var waves_path = current_level_data.get("waves_path", "")
	var wave_json = _load_json(waves_path)
	if wave_json is Array:
		current_waves_data = wave_json
	elif wave_json is Dictionary:
		current_waves_data = wave_json.get("waves", [])
	else:
		current_waves_data = []
		
	_build_level_curves()

	# Clear plan and logs of the starting state if we want a fresh verification
	state.action_log.clear()
	state.plan.wave_actions.clear()

	return _solve_from_state_with_beam([state])

func simulate_remaining_level(initial_state) -> Dictionary:
	return _solve_from_state_with_beam([initial_state])

func get_wave_data_for_solver(wave_index: int) -> Dictionary:
	if wave_index < 0 or wave_index >= current_waves_data.size():
		push_warning("[AUTO_SOLVER] Invalid wave index %d (total waves: %d)" % [wave_index, current_waves_data.size()])
		return {}
	return current_waves_data[wave_index]

func _build_level_curves():
	current_level_curves.clear()
	var paths = {}
	if current_level_data.has("paths"):
		paths = current_level_data["paths"]
	else:
		paths["default"] = current_level_data.get("path_cells", [])
		
	for p_id in paths:
		var cells = paths[p_id]
		var curve = Curve2D.new()
		for c in cells:
			curve.add_point(Vector2(c[0], c[1]) * 64.0 + Vector2(32, 32))
		current_level_curves[p_id] = curve

func create_state_manual(gold: int, lives: int, wave_idx: int, tower_data: Array) -> GameState:
	var state = GameState.new()
	state.gold = gold
	state.lives = lives
	state.wave_index = wave_idx
	state.towers = tower_data # Already formatted as {type, cell, level}
	return state

func _solve_from_state_with_beam(initial_beam: Array) -> Dictionary:
	var beam = initial_beam
	var max_waves = current_waves_data.size()
	var total_candidates_tested = 0
	var start_wave_index = beam[0].wave_index

	var best_fail = {"wave": start_wave_index, "state": beam[0], "reason": "No defense found"}

	for w in range(start_wave_index, max_waves):
		var next_beam = []
		var wave_data = get_wave_data_for_solver(w)
		if wave_data.is_empty():
			return {"status": "ERROR", "reason": "Invalid wave data at index %d" % w, "wave": w + 1}

		for state in beam:
			var candidates = _generate_candidates_for_wave(state, w + 1)
			for candidate in candidates:
				total_candidates_tested += 1
				var result = simulate_wave(candidate, wave_data)
				if result.perfect:
					next_beam.append(result.state)
				else:
					if result.state.wave_index > best_fail.wave or (result.state.wave_index == best_fail.wave and result.enemies_killed > best_fail.get("enemies_killed", -1)):
						best_fail.wave = result.state.wave_index
						best_fail.state = result.state
						best_fail.reason = result.get("reason", "Leak")
						best_fail.enemies_killed = result.get("enemies_killed", 0)
						best_fail.leak_time = result.get("leak_time", 0.0)
						best_fail.leak_enemy = result.get("leak_enemy", "")

		# Log simulation progress for large searches
		if total_candidates_tested % 500 == 0:
			print("[AUTO_SOLVER] Progress: Wave %d, candidates tested: %d" % [w + 1, total_candidates_tested])

		if next_beam.is_empty():
			return {
				"status": "FAIL",
				"wave": best_fail.wave + 1,
				"reason": best_fail.reason,
				"best_fail": best_fail,
				"total_candidates_tested": total_candidates_tested
			}

		next_beam.sort_custom(func(a, b): return _score_state_for_level(a) > _score_state_for_level(b))
		beam = next_beam.slice(0, 50) # Beam width

	var final_state = beam[0]
	var plan_dict = final_state.plan
	# Use the actual level_id string (e.g. "level_07")
	var l_id = current_level_data.get("id", current_level_data.get("level_id", ""))
	if l_id == "": l_id = current_level_id # Fallback to the property set at start
	
	if l_id is int or l_id is float:
		l_id = "level_%02d" % int(l_id)
		
	plan_dict["level_id"] = l_id
	plan_dict["name"] = current_level_data.get("name", "Verified Plan")
	return {"status": "PASS", "plan": plan_dict, "wave": max_waves, "total_candidates_tested": total_candidates_tested}

func _generate_candidates_for_wave(state, wave_num: int) -> Array:
	var candidates = []
	# Option 1: Do nothing new
	candidates.append(state.duplicate())

	var legal_cells = _get_legal_cells()
	var tower_types = _get_tower_priority_order()
	var planned_actions: Array = []
	if wave_num > 1:
		planned_actions = plan_between_wave_actions(_state_to_dictionary(state), wave_num - 1)
	if wave_num > 1 and not planned_actions.is_empty():
		var planned_state = state.duplicate()
		var ok: bool = true
		var occupied: Dictionary = _occupied_cells_from_state(planned_state)
		for action in planned_actions:
			var applied: Dictionary = _apply_plan_action_to_state(planned_state, action, occupied)
			if not applied.get("ok", false):
				ok = false
				break
			var wave_key: String = str(wave_num)
			if not planned_state.plan.wave_actions.has(wave_key): planned_state.plan.wave_actions[wave_key] = []
			action["timing"] = "before_wave"
			planned_state.plan.wave_actions[wave_key].append(action)
		if ok:
			_solver_log_verbose("[AUTO_CLEAR] Planning before Wave %d. Gold=%d Upcoming=%s" % [
				wave_num,
				state.gold,
				_wave_summary(wave_num - 1)
			])
			candidates.append(planned_state)

	# Try upgrading first (often high value)
	for i in range(state.towers.size()):
		var t = state.towers[i]
		var cfg = towers_config[t["type"]]
		var next_lvl = t["level"]
		if next_lvl < cfg.get("levels", []).size():
			var cost = cfg["levels"][next_lvl - 1].get("upgrade_cost", 0)
			if state.gold >= cost:
				var s = state.duplicate()
				s.gold -= cost
				s.towers[i]["level"] += 1

				var wave_key = str(wave_num)
				if not s.plan.wave_actions.has(wave_key): s.plan.wave_actions[wave_key] = []
				s.plan.wave_actions[wave_key].append({
					"id": "upgrade_%s_%d_%d_w%d" % [str(t["type"]), t["cell"].x, t["cell"].y, wave_num],
					"type": "upgrade_tower",
					"tower_ref": "%s@%d,%d" % [str(t["type"]), t["cell"].x, t["cell"].y],
					"cell": [t["cell"].x, t["cell"].y],
					"timing": "before_wave"
				})
				_solver_log_verbose("[AUTO_CLEAR] Selected upgrade %s@%d,%d because upcoming wave is %s." % [
					str(t["type"]),
					t["cell"].x,
					t["cell"].y,
					_wave_summary(wave_num - 1)
				])
				candidates.append(s)

	# Try placing 1 tower
	var best_cells = _rank_cells_by_coverage(legal_cells).slice(0, 12)
	for cell in best_cells:
		for type in tower_types:
			var cost = towers_config[type].get("cost", 0)
			if state.gold >= cost:
				var s = _create_placement_candidate(state, type, cell, wave_num)
				candidates.append(s)

				# Try placing a SECOND tower if gold allows (only if small set)
				if state.gold >= cost * 2 and best_cells.size() < 5:
					for cell2 in best_cells:
						if cell2 == cell: continue
						var s2 = _create_placement_candidate(s, type, cell2, wave_num)
						candidates.append(s2)

	candidates.sort_custom(func(a, b): return _score_state_for_level(a) > _score_state_for_level(b))
	if candidates.size() > 80:
		candidates = candidates.slice(0, 80)

	return candidates

func generate_initial_build_candidates(gold: int) -> Array:
	var candidates = []
	var legal_cells = _get_legal_cells()
	var tower_types = _get_tower_priority_order()
	var best_cells = _rank_cells_by_coverage(legal_cells).slice(0, 14)
	if best_cells.is_empty():
		return candidates

	# Map legacy names to current tower IDs and filter to only existing entries.
	var _id_map: Dictionary = {
		"basic_tower":    "basic_tower_t1",
		"cannon_tower":   "neutral_cannon_tower",
		"rapid_tower":    "nature_t1",
		"slow_tower":     "water_t1",
		"sniper_tower":   "light_t1",
		"lightning_tower":"electricity_t1",
		"sawblade_tower": "earth_t1",
	}
	var _remap := func(raw_id: String) -> String:
		var mapped: String = str(_id_map.get(raw_id, raw_id))
		return mapped if towers_config.has(mapped) else ""

	var raw_recipes: Array = [
		["rapid_tower", "rapid_tower"],
		["rapid_tower", "basic_tower"],
		["rapid_tower", "slow_tower"],
		["basic_tower", "slow_tower"],
		["cannon_tower", "basic_tower"],
		["rapid_tower", "rapid_tower", "slow_tower"],
		["rapid_tower", "rapid_tower", "basic_tower", "basic_tower"],
		["rapid_tower", "slow_tower", "basic_tower"],
		["rapid_tower", "rapid_tower", "rapid_tower"],
		["cannon_tower", "rapid_tower", "slow_tower"],
		["cannon_tower", "basic_tower", "basic_tower"],
		["slow_tower", "rapid_tower", "basic_tower", "basic_tower"],
		["sniper_tower", "basic_tower"],
		["lightning_tower", "slow_tower"],
		["sawblade_tower", "rapid_tower"],
		["sniper_tower", "lightning_tower", "basic_tower"],
	]
	var recipes: Array = []
	for raw in raw_recipes:
		var mapped_recipe: Array = []
		var valid := true
		for raw_id in raw:
			var mid: String = _remap.call(str(raw_id))
			if mid.is_empty():
				valid = false
				break
			mapped_recipe.append(mid)
		if valid:
			recipes.append(mapped_recipe)

	for recipe in recipes:
		var recipe_cost: int = _recipe_cost(recipe)
		if recipe_cost > gold:
			continue
		var placement_limit: int = min(best_cells.size(), 8)
		for offset in range(placement_limit):
			var state = GameState.new()
			state.gold = gold
			state.wave_index = 0
			var used_cells: Dictionary = {}
			var valid := true
			for i in range(recipe.size()):
				var cell: Vector2i = best_cells[(offset + i * 2) % best_cells.size()]
				if used_cells.has(cell):
					valid = false
					break
				used_cells[cell] = true
				state = _create_placement_candidate(state, str(recipe[i]), cell, 0)
			if valid:
				candidates.append(state)

	for type in tower_types:
		var cost = towers_config.get(type, {}).get("cost", 0)
		if gold >= cost:
			for cell in best_cells.slice(0, 4):
				var s = GameState.new()
				s.gold = gold
				s.wave_index = 0
				s = _create_placement_candidate(s, type, cell, 0)
				candidates.append(s)

	candidates.sort_custom(func(a, b): return _score_state_for_level(a) > _score_state_for_level(b))
	if candidates.size() > 120:
		candidates = candidates.slice(0, 120)
	return candidates

func _create_placement_candidate(state, type: String, cell: Vector2i, wave_num: int):
	var s = state.duplicate()
	var cost = towers_config[type].get("cost", 0)
	s.gold -= cost
	s.towers.append({"type": type, "cell": cell, "level": 1})

	var action = {
		"id": _make_tower_action_id(type, cell),
		"type": "place_tower",
		"tower_type": type,
		"cell": [cell.x, cell.y]
	}
	if wave_num <= 1 and state.wave_index == 0:
		s.plan.initial_actions.append(action)
	else:
		var wave_key = str(wave_num)
		if not s.plan.wave_actions.has(wave_key): s.plan.wave_actions[wave_key] = []
		action["timing"] = "before_wave"
		s.plan.wave_actions[wave_key].append(action)
	return s

func _get_legal_cells() -> Array:
	var cells = []
	var cols = current_level_data.get("grid_cols", 20)
	var rows = current_level_data.get("grid_rows", 12)
	
	for x in range(cols):
		for y in range(rows):
			var cell = Vector2i(x, y)
			
			var is_blocked := false
			if formation_planner and formation_planner.has_method("get_build_block_reason"):
				is_blocked = formation_planner.get_build_block_reason(cell) != ""
			elif BuildableGridGenerator.get_static_block_reason(cell, current_level_data) != "":
				is_blocked = true
			else:
				# Fallback manual check
				var path_cells = []
				if current_level_data.has("paths"):
					for p_id in current_level_data["paths"]:
						path_cells.append_array(current_level_data["paths"][p_id])
				else:
					path_cells = current_level_data.get("path_cells", [])
				
				for p in path_cells:
					if p[0] == x and p[1] == y:
						is_blocked = true
						break
				
				if not is_blocked:
					var blocked = current_level_data.get("blocked_cells", [])
					for b in blocked:
						if b[0] == x and b[1] == y:
							is_blocked = true
							break
			
			if not is_blocked:
				cells.append(cell)
	return cells

func _rank_cells_by_coverage(cells: Array) -> Array:
	var path = []
	if current_level_data.has("paths"):
		for p_id in current_level_data["paths"]:
			path.append_array(current_level_data["paths"][p_id])
	else:
		path = current_level_data.get("path_cells", [])
	
	var ranked = []
	for cell in cells:
		var score = 0.0
		for p_idx in range(path.size()):
			var p = path[p_idx]
			var dist = Vector2(cell).distance_to(Vector2(p[0], p[1]))
			if dist <= 3.5:
				# Weight early path slightly higher for openers
				var weight = 1.0 + (1.0 - float(p_idx) / path.size()) * 0.5
				score += weight
		ranked.append({"cell": cell, "score": score})
	ranked.sort_custom(func(a,b): return a.score > b.score)
	var res = []
	for r in ranked: res.append(r.cell)
	return res

func _get_tower_priority_order() -> Array[String]:
	# Build priority list from actual config keys so we never reference missing IDs.
	# Neutral towers first (cheapest, always buildable), then single-element, then combos.
	var combo_priority := ["neutral", "single", "dual", "triple", "pure", "periodic"]
	var buckets: Dictionary = {}
	for tid in towers_config.keys():
		var cfg: Dictionary = towers_config.get(tid, {})
		if not bool(cfg.get("build_entry", false)):
			continue
		var combo: String = str(cfg.get("combo_type", "neutral"))
		if not buckets.has(combo):
			buckets[combo] = []
		buckets[combo].append(tid)
	# Sort within each bucket by cost ascending
	for combo in buckets:
		buckets[combo].sort_custom(func(a: String, b: String) -> bool:
			return int(towers_config.get(a, {}).get("cost", 9999)) < int(towers_config.get(b, {}).get("cost", 9999))
		)
	var order: Array[String] = []
	for combo in combo_priority:
		if buckets.has(combo):
			order.append_array(buckets[combo])
	# Fallback: include any remaining keys not covered by combo_priority
	for tid in towers_config.keys():
		if not order.has(tid) and bool(towers_config.get(tid, {}).get("build_entry", false)):
			order.append(tid)
	return order

func _level_has_fast_pressure() -> bool:
	for wave in current_waves_data:
		for group in wave.get("groups", []):
			var e_type = group.get("enemy_type", group.get("type", ""))
			if str(e_type).to_lower().contains("fast"):
				return true
	for role in current_level_data.get("recommended_roles", []):
		if str(role).to_lower().contains("rapid") or str(role).to_lower().contains("slow"):
			return true
	return false

func _recipe_cost(recipe: Array) -> int:
	var total: int = 0
	for tower_type in recipe:
		total += int(towers_config.get(str(tower_type), {}).get("cost", 99999))
	return total

func _score_state_for_level(state) -> float:
	var score: float = float(state.gold) * 0.05
	var fast_pressure: bool = _level_has_fast_pressure()
	var cells_seen: Dictionary = {}
	for tower in state.towers:
		var tower_type: String = str(tower.get("type", ""))
		var cell: Vector2i = tower.get("cell", Vector2i.ZERO)
		var level: int = int(tower.get("level", 1))
		cells_seen[cell] = true
		var coverage: float = _cell_coverage_score(cell)
		score += coverage
		if level > 1:
			score += float(level - 1) * coverage * 1.25
		var cfg: Dictionary = towers_config.get(tower_type, {})
		var visual: String = str(cfg.get("visual_type", ""))
		var elements: Array = cfg.get("elements", [])
		var is_slow:   bool = elements.has("water") or visual == "crystal_emitter"
		var is_rapid:  bool = elements.has("nature") or visual == "bio_vine"
		var is_cannon: bool = visual == "cannon" or visual == "heavy_mortar"
		var is_single: bool = str(cfg.get("combo_type", "")) == "neutral" and not is_cannon
		if fast_pressure:
			if is_rapid:
				score += 36.0
				score += float(level - 1) * 34.0
			elif is_slow:
				score += 28.0
				score += float(level - 1) * 24.0
			elif is_single:
				score += 12.0
				score += float(level - 1) * 14.0
			elif is_cannon:
				score -= 14.0
				score += float(level - 1) * 4.0
		else:
			if is_cannon:
				score += 18.0
				score += float(level - 1) * 18.0
			elif is_single:
				score += 14.0
				score += float(level - 1) * 20.0
			elif is_rapid:
				score += 12.0
				score += float(level - 1) * 12.0
			elif is_slow:
				score += 8.0
				score += float(level - 1) * 8.0
	score += float(cells_seen.size()) * 8.0
	return score

func _cell_coverage_score(cell: Vector2i) -> float:
	var path = []
	if current_level_data.has("paths"):
		for p_id in current_level_data["paths"]:
			path.append_array(current_level_data["paths"][p_id])
	else:
		path = current_level_data.get("path_cells", [])
		
	var score: float = 0.0
	for p_idx in range(path.size()):
		var p = path[p_idx]
		var dist: float = Vector2(cell).distance_to(Vector2(p[0], p[1]))
		if dist <= 3.5:
			var path_t: float = float(p_idx) / max(1.0, float(path.size() - 1))
			var middle_bonus: float = 1.0 - abs(path_t - 0.58)
			score += 1.0 + middle_bonus
	return score

func plan_between_wave_actions(state: Dictionary, next_wave_index: int) -> Array:
	var actions: Array = []
	var gold: int = int(state.get("gold", 0))
	var towers: Array = state.get("towers", [])
	var upcoming: Dictionary = get_wave_data_for_solver(next_wave_index)
	if upcoming.is_empty():
		return actions

	var best_upgrade: Dictionary = _best_upgrade_action(towers, gold, upcoming)
	var best_build: Dictionary = _best_build_action(towers, gold, upcoming)

	if not best_upgrade.is_empty() and float(best_upgrade.get("score", 0.0)) >= float(best_build.get("score", 0.0)) * 0.85:
		actions.append(best_upgrade.get("action", {}))
		gold -= int(best_upgrade.get("cost", 0))
		_solver_log_verbose("[AUTO_CLEAR] Selected upgrade %s because upcoming wave is %s and tower has high coverage." % [
			str(best_upgrade.get("label", "tower")),
			_wave_summary(next_wave_index)
		])
		var follow_build: Dictionary = _best_build_action(towers, gold, upcoming)
		if not follow_build.is_empty() and float(follow_build.get("score", 0.0)) > 20.0:
			actions.append(follow_build.get("action", {}))
			_solver_log_verbose("[AUTO_CLEAR] Selected %s because it covers %.1f path score." % [
				_action_to_text(follow_build.get("action", {})),
				float(follow_build.get("coverage", 0.0))
			])
	elif not best_build.is_empty() and float(best_build.get("score", 0.0)) > 20.0:
		actions.append(best_build.get("action", {}))
		_solver_log_verbose("[AUTO_CLEAR] Selected %s because it covers %.1f path score." % [
			_action_to_text(best_build.get("action", {})),
			float(best_build.get("coverage", 0.0))
		])

	return actions

func _solver_log_verbose(message: String) -> void:
	if auto_clear_verbose_solver_logs:
		print(message)

func _state_to_dictionary(state) -> Dictionary:
	return {
		"gold": state.gold,
		"towers": state.towers.duplicate(true),
		"wave_index": state.wave_index
	}

func _occupied_cells_from_state(state) -> Dictionary:
	var occupied: Dictionary = {}
	for tower in state.towers:
		occupied[tower.get("cell", Vector2i.ZERO)] = true
	return occupied

func _best_upgrade_action(towers: Array, gold: int, upcoming_wave: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for tower in towers:
		var tower_type: String = str(tower.get("type", ""))
		var cfg: Dictionary = towers_config.get(tower_type, {})
		var levels: Array = cfg.get("levels", [])
		var level: int = int(tower.get("level", 1))
		if level >= levels.size():
			continue
		var cost: int = int(levels[level - 1].get("upgrade_cost", 0))
		if cost <= 0 or gold < cost:
			continue
		var current_stats: Dictionary = levels[level - 1]
		var next_stats: Dictionary = levels[level]
		var current_dps: float = float(current_stats.get("damage", 0.0)) / max(0.05, float(current_stats.get("fire_rate", 1.0)))
		var next_dps: float = float(next_stats.get("damage", 0.0)) / max(0.05, float(next_stats.get("fire_rate", 1.0)))
		var dps_gain_per_gold: float = (next_dps - current_dps) / max(1.0, float(cost))
		var cell: Vector2i = tower.get("cell", Vector2i.ZERO)
		var coverage: float = _cell_coverage_score(cell)
		var role_bonus: float = _tower_role_bonus(tower_type, upcoming_wave)
		var _up_cfg: Dictionary = towers_config.get(tower_type, {})
		if _up_cfg.get("elements", []).has("water"):
			role_bonus += float(next_stats.get("slow_radius", 0.0) - current_stats.get("slow_radius", 0.0)) * 0.08
			role_bonus += float(next_stats.get("slow_percent", 0.0) - current_stats.get("slow_percent", 0.0)) * 35.0
		var score: float = coverage * 1.5 + dps_gain_per_gold * 220.0 + role_bonus
		if best.is_empty() or score > float(best.get("score", 0.0)):
			best = {
				"score": score,
				"cost": cost,
				"coverage": coverage,
				"label": "%s@%d,%d" % [tower_type, cell.x, cell.y],
				"action": {
					"type": "upgrade_tower",
					"tower_ref": "%s@%d,%d" % [tower_type, cell.x, cell.y],
					"cell": [cell.x, cell.y],
					"reason": "Upgrade %s for high coverage and DPS gain" % tower_type
				}
			}
	return best

func _best_build_action(towers: Array, gold: int, upcoming_wave: Dictionary) -> Dictionary:
	var legal_cells: Array = _rank_cells_by_coverage(_get_legal_cells()).slice(0, 14)
	var occupied: Dictionary = {}
	var has_slow: bool = false
	for tower in towers:
		var cell: Vector2i = tower.get("cell", Vector2i.ZERO)
		occupied[cell] = true
		var _t_cfg: Dictionary = towers_config.get(str(tower.get("type", "")), {})
		if _t_cfg.get("elements", []).has("water"):
			has_slow = true
	var best: Dictionary = {}
	for cell in legal_cells:
		if occupied.has(cell):
			continue
		var coverage: float = _cell_coverage_score(cell)
		for tower_type in _get_tower_priority_order():
			var cost: int = int(towers_config.get(tower_type, {}).get("cost", 99999))
			if cost > gold:
				continue
			var role_bonus: float = _tower_role_bonus(tower_type, upcoming_wave)
			var _bt_cfg: Dictionary = towers_config.get(tower_type, {})
			var _is_water: bool = (_bt_cfg.get("elements", []) as Array).has("water")
			if _wave_has_enemy(upcoming_wave, "fast") and _is_water and not has_slow:
				role_bonus += 22.0
			var score: float = coverage * 1.4 + role_bonus - float(cost) * 0.03
			if best.is_empty() or score > float(best.get("score", 0.0)):
				best = {
					"score": score,
					"cost": cost,
					"coverage": coverage,
					"action": {
						"id": _make_tower_action_id(tower_type, cell),
						"type": "place_tower",
						"tower_type": tower_type,
						"cell": [cell.x, cell.y],
						"reason": "Place %s for coverage %.1f against %s" % [tower_type, coverage, upcoming_wave.get("name", "wave")]
					}
				}
	return best

func _tower_role_bonus(tower_type: String, wave_data: Dictionary) -> float:
	var cfg: Dictionary = towers_config.get(tower_type, {})
	var visual: String   = str(cfg.get("visual_type", ""))
	var elements: Array  = cfg.get("elements", [])
	var is_slow:   bool = elements.has("water") or visual == "crystal_emitter"
	var is_rapid:  bool = elements.has("nature") or visual == "bio_vine"
	var is_cannon: bool = visual == "cannon" or visual == "heavy_mortar"
	var is_sniper: bool = elements.has("light") and str(cfg.get("combo_type", "")) == "single"
	var is_chain:  bool = elements.has("light") and elements.has("fire")
	var is_aura:   bool = elements.has("fire") and elements.has("earth")
	if _wave_has_enemy(wave_data, "fast"):
		if is_rapid:  return 34.0
		if is_slow:   return 28.0
		if is_cannon: return -8.0
		return 10.0
	if _wave_has_enemy(wave_data, "tank") or _wave_has_enemy(wave_data, "heavy"):
		if is_sniper: return 60.0
		if is_chain:  return 30.0
		if is_aura:   return 25.0
		if is_cannon: return 16.0
		if is_rapid:  return 8.0
		if is_slow:   return 8.0
		return 24.0
	return 10.0

func _wave_has_enemy(wave_data: Dictionary, enemy_key: String) -> bool:
	for group in wave_data.get("groups", []):
		var e_type = group.get("enemy_type", group.get("type", ""))
		if str(e_type).to_lower().contains(enemy_key):
			return true
	return false

func _wave_summary(wave_index: int) -> String:
	var wave: Dictionary = get_wave_data_for_solver(wave_index)
	var parts: Array[String] = []
	for group in wave.get("groups", []):
		var e_type = group.get("enemy_type", group.get("type", "unknown"))
		parts.append("%s x%d" % [str(e_type).capitalize(), int(group.get("count", 0))])
	return _join_strings(parts, ", ") if not parts.is_empty() else "unknown"

func _make_tower_action_id(tower_type: String, cell: Vector2i) -> String:
	return "%s_%d_%d" % [tower_type.replace("_tower", ""), cell.x, cell.y]

func validate_plan_for_level(plan: Dictionary, starting_gold: int) -> Dictionary:
	_normalize_plan_wave_actions(plan)
	if plan.is_empty():
		return {"valid": false, "reason": "Empty plan", "wave": 1}
	if not plan.has("level_id") or not plan.has("initial_actions") or not plan.has("wave_actions"):
		return {"valid": false, "reason": "Plan missing required fields", "wave": 1}

	var quality: Dictionary = _validate_plan_quality(plan)
	if not quality.get("valid", false):
		return quality

	var sim = GameState.new()
	sim.gold = starting_gold
	sim.lives = int(current_level_data.get("starting_lives", 20))
	sim.wave_index = 0
	sim.plan = plan.duplicate(true)

	var occupied: Dictionary = {}
	for action in plan.get("initial_actions", []):
		var applied: Dictionary = _apply_plan_action_to_state(sim, action, occupied)
		if not applied.get("ok", false):
			return {"valid": false, "reason": applied.get("reason", "Initial action failed"), "wave": 1}

	var total_waves: int = current_waves_data.size()
	for wave_num in range(1, total_waves + 1):
		var before_actions: Array = _get_plan_actions(plan, wave_num, "before_wave")
		var has_start: bool = false
		for action in before_actions:
			if action.get("type", "") == "start_wave":
				has_start = true
			else:
				var before_applied: Dictionary = _apply_plan_action_to_state(sim, action, occupied)
				if not before_applied.get("ok", false):
					return {"valid": false, "reason": before_applied.get("reason", "Before-wave action failed"), "wave": wave_num}
		if not has_start:
			return {"valid": false, "reason": "Wave %d has no start_wave action" % wave_num, "wave": wave_num}

		var wave_result: Dictionary = simulate_wave(sim, current_waves_data[wave_num - 1])
		if not wave_result.get("perfect", false):
			return {
				"valid": false,
				"reason": str(wave_result.get("reason", "Wave simulation leaked")),
				"wave": wave_num,
				"expected_lives_lost": 1
			}
		sim = wave_result["state"]

		for action in _get_plan_actions(plan, wave_num, "after_wave"):
			var after_applied: Dictionary = _apply_plan_action_to_state(sim, action, occupied)
			if not after_applied.get("ok", false):
				return {"valid": false, "reason": after_applied.get("reason", "After-wave action failed"), "wave": wave_num}

	if sim.wave_index < total_waves:
		return {"valid": false, "reason": "Plan does not cover all waves", "wave": sim.wave_index + 1}

	return {
		"valid": true,
		"expected_lives_lost": 0,
		"covers_all_waves": true,
		"wave": total_waves,
		"quality": quality.get("quality", "full-level validated")
	}

func _validate_plan_quality(plan: Dictionary) -> Dictionary:
	var initial: Array = plan.get("initial_actions", [])
	var placements: Array = []
	for action in initial:
		if action.get("type", "") == "place_tower":
			placements.append(str(action.get("tower_type", "")))

	var fast_pressure: bool = _level_has_fast_pressure()
	if fast_pressure:
		if placements.size() < 2:
			return {"valid": false, "reason": "Fast-pressure plan has fewer than two opening towers", "wave": 1}
		if placements.size() == 1 and towers_config.get(placements[0], {}).get("visual_type", "") == "cannon":
			return {"valid": false, "reason": "Rejected cannon-only fallback opening", "wave": 1}
		var _has_answer := false
		for _p in placements:
			var _pe: Array = towers_config.get(_p, {}).get("elements", [])
			if _pe.has("nature") or _pe.has("water"):
				_has_answer = true
				break
		if not _has_answer:
			return {"valid": false, "reason": "Fast-pressure plan lacks Rapid/Slow answer", "wave": 1}

	var total_waves: int = current_waves_data.size()
	for wave_num in range(1, total_waves + 1):
		var actions: Array = _get_plan_actions(plan, wave_num, "before_wave")
		var has_start: bool = false
		for action in actions:
			if action.get("type", "") == "start_wave":
				has_start = true
				break
		if not has_start:
			return {"valid": false, "reason": "Plan missing start_wave for wave %d" % wave_num, "wave": wave_num}

	return {"valid": true, "quality": "role-aware full-wave plan"}

func _normalize_plan_wave_actions(plan: Dictionary) -> void:
	if not plan.has("wave_actions") or not (plan["wave_actions"] is Dictionary):
		plan["wave_actions"] = {}
		return
	var normalized: Dictionary = {}
	for wave_key in plan["wave_actions"].keys():
		var wave_data = plan["wave_actions"][wave_key]
		if wave_data is Dictionary:
			var wave_dict: Dictionary = wave_data
			normalized[str(wave_key)] = {
				"before_wave": wave_dict.get("before_wave", []),
				"after_wave": wave_dict.get("after_wave", [])
			}
		elif wave_data is Array:
			var before: Array = []
			var after: Array = []
			for action in wave_data:
				if action.get("timing", "before_wave") == "after_wave":
					after.append(action)
				else:
					before.append(action)
			normalized[str(wave_key)] = {"before_wave": before, "after_wave": after}
	plan["wave_actions"] = normalized

func _get_plan_actions(plan: Dictionary, wave_num: int, timing: String) -> Array:
	var wave_data = plan.get("wave_actions", {}).get(str(wave_num), [])
	if wave_data is Dictionary:
		return wave_data.get(timing, [])
	var filtered: Array = []
	if wave_data is Array:
		for action in wave_data:
			if action.get("timing", "before_wave") == timing:
				filtered.append(action)
	return filtered

func _apply_plan_action_to_state(state, action: Dictionary, occupied: Dictionary) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"place_tower":
			var tower_type: String = str(action.get("tower_type", ""))
			var cell_data: Array = action.get("cell", [])
			if cell_data.size() < 2:
				return {"ok": false, "reason": "place_tower missing cell"}
			var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
			if occupied.has(cell):
				return {"ok": false, "reason": "cell already occupied: %s" % str(cell)}
			var cost: int = int(towers_config.get(tower_type, {}).get("cost", 99999))
			if state.gold < cost:
				return {"ok": false, "reason": "not enough gold for %s" % tower_type}
			state.gold -= cost
			state.towers.append({"type": tower_type, "cell": cell, "level": 1})
			occupied[cell] = true
			return {"ok": true}
		"upgrade_tower":
			var upgrade_cell_data: Array = action.get("cell", [])
			if upgrade_cell_data.size() < 2:
				return {"ok": false, "reason": "upgrade_tower missing cell"}
			var upgrade_cell := Vector2i(int(upgrade_cell_data[0]), int(upgrade_cell_data[1]))
			for i in range(state.towers.size()):
				var tower: Dictionary = state.towers[i]
				if tower.get("cell", Vector2i.ZERO) != upgrade_cell:
					continue
				var cfg: Dictionary = towers_config.get(str(tower.get("type", "")), {})
				var level: int = int(tower.get("level", 1))
				var levels: Array = cfg.get("levels", [])
				if level >= levels.size():
					return {"ok": false, "reason": "tower already max level at %s" % str(upgrade_cell)}
				var cost: int = int(levels[level - 1].get("upgrade_cost", 0))
				if state.gold < cost:
					return {"ok": false, "reason": "not enough gold to upgrade at %s" % str(upgrade_cell)}
				state.gold -= cost
				state.towers[i]["level"] = level + 1
				return {"ok": true}
			return {"ok": false, "reason": "no tower to upgrade at %s" % str(upgrade_cell)}
		"start_wave":
			return {"ok": true}
		_:
			return {"ok": true}

# --- Simulation Logic (Synced with real stats) ---

func simulate_wave(state, wave_data: Dictionary) -> Dictionary:
	var sim = state.duplicate()
	var enemies = []
	var projectiles = []
	var time = 0.0
	var tick = 0.05
	var reward = wave_data.get("completion_reward", 0)

	# Use Formation Planner for deterministic event queue
	if formation_planner == null:
		formation_planner = FORMATION_PLANNER_SCRIPT.new(enemies_config)
	
	var plan = formation_planner.build_plan(wave_data, state.wave_index)
	var events = plan.get("events", [])
	var total_enemies = events.size()
	var event_index = 0
	var dynamic_spawns = []
	
	while time < 600.0:
		# Check for spawns from formation
		while event_index < events.size() and time >= float(events[event_index].get("time", 0.0)):
			var event = events[event_index]
			var e_type = event.get("type", "basic")
			var cfg = enemies_config.get(e_type, {})
			var p_id = event.get("path", "default")
			var curve = current_level_curves.get(p_id)
			if curve == null and current_level_curves.has("default"):
				curve = current_level_curves["default"]
				
			var path_len = curve.get_baked_length() if curve else 0.0
			
			enemies.append({
				"id": randi(),
				"hp": cfg.get("max_hp", 30),
				"max_hp": cfg.get("max_hp", 30),
				"speed": cfg.get("speed", 100),
				"progress": 0.0,
				"path_id": p_id,
				"curve": curve,
				"path_len": path_len,
				"reward": cfg.get("reward_gold", 5),
				"type": e_type,
				"slow": 1.0,
				"slow_rem": 0.0,
				"tags": cfg.get("tags", []),
				"is_cloaked": "stealth" in cfg.get("tags", []),
				"is_air": cfg.get("category", "land") == "air" or "air" in cfg.get("tags", []),
				"shield": 0,
				"shield_reduction": 0.0,
				"vulnerability": 1.0,
				"vulnerability_rem": 0.0,
				"skill": cfg.get("skill", ""),
				"skill_params": cfg.get("skill_params", {}),
				"heal_timer": 0.0,
				"formation_speed_multiplier": event.get("formation_speed_multiplier", 1.0)
			})
			event_index += 1

		for e in enemies:
			if e["slow_rem"] > 0:
				e["slow_rem"] -= tick
				if e["slow_rem"] <= 0: e["slow"] = 1.0
			if e["vulnerability_rem"] > 0:
				e["vulnerability_rem"] -= tick
				if e["vulnerability_rem"] <= 0: e["vulnerability"] = 1.0
			
			e["shield_reduction"] = 0.0 # reset every tick for aura
			e["shield"] = 0
				
			if e["skill"] == "healer":
				e["heal_timer"] -= tick
				if e["heal_timer"] <= 0:
					e["heal_timer"] = e["skill_params"].get("interval", 1.0)
					var rad = e["skill_params"].get("radius", 120.0)
					var amt = e["skill_params"].get("heal_amount", 5)
					for other in enemies:
						if other["hp"] > 0 and other["hp"] < other["max_hp"]:
							if _get_pos(e).distance_to(_get_pos(other)) <= rad:
								other["hp"] = min(other["max_hp"], other["hp"] + amt)
								
		# Second pass for shield auras
		for e in enemies:
			if e["skill"] == "shield_aura":
				var rad = e["skill_params"].get("radius", 120.0)
				var red = e["skill_params"].get("reduction", e["skill_params"].get("shield_reduction", 0.35))
				for other in enemies:
					if other != e and _get_pos(e).distance_to(_get_pos(other)) <= rad:
						other["shield"] = 1
						other["shield_reduction"] = max(other["shield_reduction"], red)

		for e in enemies:
			e["progress"] += e["speed"] * e["slow"] * tick
			if e["progress"] >= e["path_len"]:
				return {
					"perfect": false,
					"state": sim,
					"reason": "Leak: %s reached base" % e["type"],
					"leak_time": time,
					"leak_enemy": e["type"],
					"enemies_killed": total_enemies - (events.size() - event_index) - enemies.size()
				}

		for t in sim.towers:
			if not t.has("cooldown"): t["cooldown"] = 0.0
			t["cooldown"] -= tick
			
			var rate_penalty = 0.0
			var t_pos = Vector2(t["cell"].x, t["cell"].y) * 64.0 + Vector2(32,32)
			for e in enemies:
				if e["skill"] == "disrupt_aura":
					if _get_pos(e).distance_to(t_pos) <= e["skill_params"].get("radius", 150.0):
						rate_penalty = max(rate_penalty, e["skill_params"].get("fire_rate_penalty", 0.5))
			
			if t["cooldown"] <= 0:
				var cfg = towers_config[t["type"]]
				var stats = cfg["levels"][t["level"] - 1]
				var target = _find_target(t, cfg, stats, enemies)
				if target:
					t["cooldown"] = stats.get("fire_rate", 1.0) * (1.0 + rate_penalty)
					var p_speed = stats.get("projectile_speed", 0.0)
					if p_speed > 0:
						t_pos = Vector2(t["cell"].x, t["cell"].y) * 64.0 + Vector2(32,32)
						var dist = t_pos.distance_to(_get_pos(target))
						var impact_time = time + (dist / p_speed)
						projectiles.append({
							"t": t, "cfg": cfg, "stats": stats, "target_id": target["id"],
							"impact_time": impact_time, "target": target
						})
					else:
						_apply_dmg(t, cfg, stats, target, enemies)

		var i = projectiles.size() - 1
		while i >= 0:
			if time >= projectiles[i]["impact_time"]:
				var p = projectiles[i]
				_apply_dmg(p["t"], p["cfg"], p["stats"], p["target"], enemies)
				projectiles.remove_at(i)
			i -= 1

		i = enemies.size() - 1
		while i >= 0:
			if enemies[i]["hp"] <= 0:
				sim.gold += enemies[i]["reward"]
				if enemies[i]["skill"] == "split_on_death":
					var count = enemies[i]["skill_params"].get("count", 3)
					var s_type = enemies[i]["skill_params"].get("type", "basic")
					for j in range(count):
						dynamic_spawns.append({
							"time": time + 0.2 * (j + 1),
							"type": s_type,
							"path": enemies[i]["path_id"]
						})
						total_enemies += 1
				enemies.remove_at(i)
			i -= 1

		# Check for dynamic spawns
		var ds_idx = dynamic_spawns.size() - 1
		while ds_idx >= 0:
			if time >= dynamic_spawns[ds_idx]["time"]:
				var ds = dynamic_spawns[ds_idx]
				var e_type = ds["type"]
				var cfg = enemies_config.get(e_type, {})
				var p_id = ds["path"]
				var curve = current_level_curves.get(p_id, current_level_curves.get("default"))
				var path_len = curve.get_baked_length() if curve else 0.0
				
				enemies.append({
					"id": randi(),
					"hp": cfg.get("max_hp", 30),
					"max_hp": cfg.get("max_hp", 30),
					"speed": cfg.get("speed", 100),
					"progress": 0.0,
					"path_id": p_id,
					"curve": curve,
					"path_len": path_len,
					"reward": 0, # splits usually give no gold
					"type": e_type,
					"slow": 1.0,
					"slow_rem": 0.0,
					"tags": cfg.get("tags", []),
					"is_cloaked": "stealth" in cfg.get("tags", []),
					"is_air": cfg.get("category", "land") == "air" or "air" in cfg.get("tags", []),
					"shield": 0,
					"shield_reduction": 0.0,
					"vulnerability": 1.0,
					"vulnerability_rem": 0.0,
					"skill": cfg.get("skill", ""),
					"skill_params": cfg.get("skill_params", {}),
					"heal_timer": 0.0,
					"formation_speed_multiplier": 1.0
				})
				dynamic_spawns.remove_at(ds_idx)
			ds_idx -= 1

		if event_index >= events.size() and dynamic_spawns.is_empty() and enemies.is_empty() and projectiles.is_empty():
			sim.gold += reward
			sim.wave_index += 1
			var wave_key = str(sim.wave_index)
			if not sim.plan.wave_actions.has(wave_key): sim.plan.wave_actions[wave_key] = []
			
			var has_start = false
			var actions_list = sim.plan.wave_actions[wave_key]
			if actions_list is Dictionary:
				for a in actions_list.get("before_wave", []):
					if a.get("type", "") == "start_wave":
						has_start = true; break
			else:
				for a in actions_list:
					if a.get("type", "") == "start_wave":
						has_start = true; break
						
			if not has_start:
				if actions_list is Dictionary:
					actions_list["before_wave"].append({"type": "start_wave", "timing": "before_wave"})
				else:
					actions_list.append({"type": "start_wave", "timing": "before_wave"})

			return { "perfect": true, "state": sim, "enemies_killed": total_enemies }
			
		time += tick

	return {"perfect": false, "state": sim}

func _find_target(t, cfg, stats, enemies) -> Variant:
	var t_pos = Vector2(t["cell"].x, t["cell"].y) * 64.0 + Vector2(32, 32)
	var r = stats.get("range", 160.0)
	var target_cats = cfg.get("target_categories", ["land", "air"])
	var mode = t.get("target_mode", "first")

	# Collect all valid in-range enemies, split by cloaked / visible
	var visible: Array = []
	var cloaked: Array = []
	for e in enemies:
		if e["hp"] <= 0: continue
		if e["is_air"] and not "air" in target_cats: continue
		if not e["is_air"] and not "land" in target_cats: continue
		if t_pos.distance_to(_get_pos(e)) > r: continue
		if e["is_cloaked"]:
			cloaked.append(e)
		else:
			visible.append(e)

	var pool = visible if visible.size() > 0 else cloaked
	if pool.is_empty(): return null

	# For priority-type modes, narrow to priority types first, fall back to full pool
	var PRIORITY_TYPES = {
		"air_first": ["flyer", "fast_flyer", "armored_flyer"],
		"support_first": ["healer", "disruptor"],
		"shield_first": ["shieldbearer", "bulwark"]
	}
	if PRIORITY_TYPES.has(mode):
		var ptypes = PRIORITY_TYPES[mode]
		var ppool: Array = []
		for e in pool:
			if e.get("type", "") in ptypes:
				ppool.append(e)
		if ppool.size() > 0:
			pool = ppool

	match mode:
		"last":
			var best = null; var min_p = INF
			for e in pool:
				if e["progress"] < min_p: min_p = e["progress"]; best = e
			return best
		"nearest":
			var best = null; var min_d = INF
			for e in pool:
				var d = t_pos.distance_to(_get_pos(e))
				if d < min_d: min_d = d; best = e
			return best
		"strongest":
			var best = null; var max_hp = -1.0
			for e in pool:
				if e["hp"] > max_hp: max_hp = e["hp"]; best = e
			return best
		"weakest":
			var best = null; var min_hp = INF
			for e in pool:
				if e["hp"] < min_hp: min_hp = e["hp"]; best = e
			return best
		"fastest":
			var best = null; var max_spd = -1.0
			for e in pool:
				if e["speed"] > max_spd: max_spd = e["speed"]; best = e
			return best
		_: # first / air_first / support_first / shield_first -> furthest along path
			var best = null; var max_p = -1.0
			for e in pool:
				if e["progress"] > max_p: max_p = e["progress"]; best = e
			return best

func _get_pos(e: Dictionary) -> Vector2:
	if e.get("curve"):
		return e["curve"].sample_baked(e["progress"])
	return Vector2.ZERO

func _apply_dmg(t, cfg, stats, target, enemies):
	if target["hp"] <= 0: return
	
	var base_dmg = stats.get("damage", 10.0)
	var atk_type = cfg.get("attack_type", "single")
	var hit_enemies = [target]
	
	if atk_type == "splash" or atk_type == "slow":
		var rad = stats.get("splash_radius", stats.get("slow_radius", 100.0))
		var center = _get_pos(target)
		hit_enemies.clear()
		for e in enemies:
			if e["hp"] > 0 and center.distance_to(_get_pos(e)) <= rad:
				hit_enemies.append(e)
	elif atk_type == "chain":
		var count = stats.get("chain_count", 3)
		var bounce_range = stats.get("chain_bounce_range", 120.0)
		var current = target
		for i in range(count - 1):
			var next = null
			var closest = 99999.0
			for e in enemies:
				if e["hp"] > 0 and not e in hit_enemies:
					var dist = _get_pos(current).distance_to(_get_pos(e))
					if dist <= bounce_range and dist < closest:
						closest = dist
						next = e
			if next:
				hit_enemies.append(next)
				current = next
			else:
				break
				
	var _saw_cfg: Dictionary = towers_config.get(str(t.get("type", "")), {})
	var is_sawblade = _saw_cfg.get("visual_type", "") == "strike_blades" or _saw_cfg.get("visual_type", "") == "seismic_drill"
	var is_slow = atk_type == "slow"
	var slow_pct = stats.get("slow_percent", 0.4)
	var slow_dur = stats.get("slow_duration", 2.0)
	var vuln_pct = stats.get("vulnerability_percent", 0.0)
	var vuln_dur = stats.get("vulnerability_duration", 0.0)
	
	for e in hit_enemies:
		var final_dmg = base_dmg
		if e["shield"] > 0:
			final_dmg *= max(0.0, 1.0 - e["shield_reduction"])
		final_dmg *= e["vulnerability"]
		e["hp"] -= final_dmg
		
		if is_slow:
			if e["slow"] > 1.0 - slow_pct:
				e["slow"] = 1.0 - slow_pct
				e["slow_rem"] = slow_dur
			elif e["slow"] == 1.0 - slow_pct and e["slow_rem"] < slow_dur:
				e["slow_rem"] = slow_dur
				
		if is_sawblade and vuln_pct > 0:
			e["vulnerability"] = 1.0 + vuln_pct
			e["vulnerability_rem"] = vuln_dur

# --- Reporting ---

func generate_consolidated_report(results: Array) -> String:
	var r = "# PERFECT CLEAR BALANCE REPORT\n\n"
	r += "Generated: %s\n\n" % Time.get_datetime_string_from_system()

	for res in results:
		r += "## Level %s - %s\n" % [res.get("id", "??"), res.get("name", "Unnamed")]
		r += "- **Status**: %s\n" % res["status"]
		r += "- **Current starting_gold**: %d\n" % res["original_gold"]

		if res["status"] == "PASS":
			r += "- **Verification**: SIMULATED_CANDIDATE\n"
			if res["starting_gold"] > res["original_gold"]:
				r += "- **Minimum gold that works**: %d\n" % res["starting_gold"]
				r += "- **Suggestion**: Increase starting gold to %d\n" % res["starting_gold"]
			else:
				r += "- **Result**: Perfectly balanced at current gold.\n"
		else:
			r += "- **Bottleneck**: Wave %d\n" % res["wave"]
			r += "- **Failure Reason**: %s\n" % res["reason"]
			if res.has("best_fail"):
				var best = res["best_fail"]
				if best.has("leak_enemy"):
					r += "- **Leak Details**: %s at approx %.1fs\n" % [best["leak_enemy"], float(best.get("leak_time", 0.0))]
			r += "- **Suggestion**: Review difficulty or increase starting gold.\n"

		r += "\n### Per-Wave Analysis\n"
		var waves = current_waves_data
		for i in range(waves.size()):
			var w_data = waves[i]
			r += "#### Wave %d: %s\n" % [i + 1, w_data.get("name", "")]
			var enemies = ""
			for g in w_data.get("groups", []):
				var e_type = g.get("enemy_type", g.get("type", ""))
				enemies += "%s x%d, " % [e_type, g.get("count", 0)]
			r += "- **Composition**: %s\n" % enemies.trim_suffix(", ")

			if i + 1 < res["wave"]:
				r += "- **Solver Result**: Passed\n"
			elif i + 1 == res["wave"] and res["status"] == "FAIL":
				r += "- **Solver Result**: FAILED\n"
				r += "- **Cause**: %s\n" % res["reason"]
				r += "- **Suggested Fix**: "
				if res["reason"].contains("fast"):
					r += "Increase starting gold or slow down fast enemies.\n"
				else:
					r += "Add more gold or reduce enemy HP.\n"
			else:
				r += "- **Solver Result**: Not reached\n"
		r += "\n---\n"

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var file = FileAccess.open(OUTPUT_DIR + "perfect_clear_balance_report.md", FileAccess.WRITE)
	if file:
		file.store_string(r)
		file.close()

	return r

func generate_auto_clear_report(result: Dictionary, verification_type: String = "SIMULATED_ONLY") -> String:
	_ensure_output_dir()
	var level_id: String = str(result.get("level_id", current_level_id))
	if level_id == "" and result.has("plan"):
		level_id = str(result["plan"].get("level_id", current_level_id))
	var level_num: int = _level_id_to_int(level_id)
	var level_name: String = str(current_level_data.get("name", result.get("name", "Unknown Level")))
	var status: String = str(result.get("status", "NOT_FOUND"))
	var result_state: String = str(result.get("result_state", "NOT_FOUND"))
	var original_gold: int = int(result.get("original_gold", current_level_data.get("starting_gold", 0)))
	var working_gold: int = int(result.get("starting_gold", original_gold))
	var perfect_at_current: bool = status == "PASS" and working_gold == original_gold
	var plan: Dictionary = result.get("plan", {})
	if plan is Dictionary:
		_normalize_plan_wave_actions(plan)

	var r: String = "# Auto Clear Report: %s\n\n" % level_id
	r += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	r += "- Level id / name: %s / %s\n" % [level_id, level_name]
	r += "- Current starting_gold: %d\n" % original_gold
	r += "- Perfect clear possible at current gold: %s\n" % ("yes" if perfect_at_current else "no")
	
	var setup_gold: int = int(result.get("verified_setup_gold", 0))
	if setup_gold > 0:
		r += "- Initial setup cost before Wave 1: %d\n" % setup_gold
		r += "- Recommended starting_gold: %d\n" % setup_gold
	else:
		r += "- Minimum tested starting_gold that works: %s\n" % (str(working_gold) if status == "PASS" else "not found")
		
	r += "- Verification type: %s\n" % verification_type
	r += "- Result state: %s\n\n" % result_state

	r += "## Best Plan Found\n"
	if status == "PASS" and plan is Dictionary:
		r += _format_plan_summary(plan)
	else:
		r += "- No perfect-clear plan found within tested debug budget.\n"
		r += "- Best failure: Wave %d, %s\n" % [int(result.get("wave", 0)), str(result.get("reason", "Unknown"))]
	r += "\n"

	r += "## Wave-by-Wave Notes\n"
	for i in range(current_waves_data.size()):
		r += _format_wave_note(i, result, plan, perfect_at_current)
		r += "\n"

	r += "## Suggested Improvement\n"
	if status == "PASS":
		if setup_gold > 0 and setup_gold != original_gold:
			r += "- Initial setup cost (%d) differs from current starting_gold (%d). Apply verified gold to update level balance.\n" % [setup_gold, original_gold]
		elif not perfect_at_current:
			r += "- Opening economy is too strict at current gold. Test +%d starting gold as a debug-only finding before changing towers or waves.\n" % (working_gold - original_gold)
		else:
			r += "- Current balance can produce a perfect clear. Keep wave pressure as-is unless the solution feels too narrow for normal players.\n"
	else:
		r += "- No perfect clear was found through +100 debug gold. Review early pressure, tower access, and path coverage before permanent data changes.\n"

	var level_report_path: String = OUTPUT_DIR + "auto_clear_report_level_%02d.md" % level_num
	var file: FileAccess = FileAccess.open(level_report_path, FileAccess.WRITE)
	if file:
		file.store_string(r)
		file.close()

	var consolidated: FileAccess = FileAccess.open(OUTPUT_DIR + "perfect_clear_balance_report.md", FileAccess.WRITE)
	if consolidated:
		consolidated.store_string(r)
		consolidated.close()

	return r

func _format_plan_summary(plan: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("- Starting gold used: %s" % str(plan.get("starting_gold_used", plan.get("starting_gold", ""))))
	var setup_actions: Array = plan.get("verified_setup_actions", [])
	if not setup_actions.is_empty():
		lines.append("- Initial Setup (before Wave 1):")
		for action in setup_actions:
			var cost = int(action.get("cost", 0))
			lines.append("  - %s | cost: %d" % [_action_to_text(action), cost])
	else:
		var initial: Array = plan.get("initial_actions", [])
		if initial.is_empty():
			lines.append("- Initial actions: none")
		else:
			lines.append("- Initial actions:")
			for action in initial:
				lines.append("  - %s" % _action_to_text(action))
	var wave_actions: Dictionary = plan.get("wave_actions", {})
	for wave_key in wave_actions.keys():
		lines.append("- Wave %s plan:" % str(wave_key))
		var before_actions: Array = _get_plan_actions(plan, int(str(wave_key)), "before_wave")
		var after_actions: Array = _get_plan_actions(plan, int(str(wave_key)), "after_wave")
		for action in before_actions:
			if action is Dictionary:
				lines.append("  - before_wave: %s" % _action_to_text(action))
		for action in after_actions:
			if action is Dictionary:
				lines.append("  - after_wave: %s" % _action_to_text(action))
	return "\n".join(lines) + "\n"

func _format_wave_note(index: int, result: Dictionary, plan: Dictionary, perfect_at_current: bool) -> String:
	var wave: Dictionary = current_waves_data[index]
	var wave_num: int = index + 1
	var composition: Array[String] = []
	var pressure: String = "mixed pressure"
	for group in wave.get("groups", []):
		var enemy_type: String = str(group.get("enemy_type", group.get("type", "unknown")))
		composition.append("%s x%d" % [enemy_type.capitalize(), int(group.get("count", 0))])
		if enemy_type.contains("fast"):
			pressure = "fast rush"
		elif enemy_type.contains("heavy"):
			pressure = "heavy durability"
	var actions: Array[String] = []
	if plan is Dictionary:
		for action in _get_plan_actions(plan, wave_num, "before_wave") + _get_plan_actions(plan, wave_num, "after_wave"):
			if action is Dictionary and action.get("type", "") != "start_wave":
				actions.append(_action_to_text(action))
		if wave_num == 1:
			for action in plan.get("initial_actions", []):
				if action is Dictionary:
					actions.append(_action_to_text(action))
	var result_text: String = "pass" if result.get("status", "") == "PASS" or wave_num < int(result.get("wave", 0)) else "fail"
	var suggestion: String = "okay as challenge"
	if not perfect_at_current and wave_num <= int(result.get("wave", wave_num)):
		suggestion = "opening economy too tight; test +10 or +20 gold before changing permanent data"
	elif result.get("status", "") != "PASS" and wave_num == int(result.get("wave", 0)):
		suggestion = "pressure exceeds tested build budget; review enemy count, reward, or starting gold"

	var text: String = "Wave %d:\n" % wave_num
	text += "- Enemies: %s\n" % _join_strings(composition, ", ")
	text += "- Pressure: %s\n" % pressure
	text += "- Best answer: %s\n" % (_join_strings(actions, ", ") if not actions.is_empty() else "hold current defense")
	text += "- At current gold: %s\n" % result_text
	text += "- Suggestion: %s\n" % suggestion
	return text

func _action_to_text(action: Dictionary) -> String:
	var base_text = ""
	match str(action.get("type", "")):
		"place_tower":
			base_text = "place %s at %s" % [str(action.get("tower_type", "")), str(action.get("cell", []))]
		"upgrade_tower":
			base_text = "upgrade tower at %s" % str(action.get("cell", []))
		"start_wave":
			base_text = "start wave"
		_:
			base_text = str(action)
			
	var reason = action.get("reason", "")
	if reason != "":
		return base_text + " | Reason: " + reason
	return base_text

func _level_id_to_int(level_id: String) -> int:
	var digits: String = ""
	for c in level_id:
		if c >= "0" and c <= "9":
			digits += c
	return int(digits) if digits != "" else 0

func _join_strings(values: Array[String], separator: String) -> String:
	var result: String = ""
	for i in range(values.size()):
		if i > 0:
			result += separator
		result += values[i]
	return result
