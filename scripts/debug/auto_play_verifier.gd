extends Node

# Auto-Play Perfect Clear Verifier
# Executes structured plans from the Solver in real gameplay.

enum AutoPlayState {
	IDLE,
	STARTING_LEVEL,
	APPLYING_INITIAL_ACTIONS,
	BEFORE_WAVE_ACTIONS,
	STARTING_WAVE,
	WAVE_RUNNING,
	AFTER_WAVE_ACTIONS,
	PREPARING_NEXT_WAVE,
	COMPLETED,
	FAILED
}

signal state_changed(new_state: AutoPlayState, message: String)

const REPORT_DIR = "user://balance_reports/"

var is_active: bool = false
var state: AutoPlayState = AutoPlayState.IDLE
var current_plan: Dictionary = {}
var current_wave: int = 1
var starting_lives: int = 0
var log_messages: Array[String] = []
var fail_reason: String = ""
var last_action: String = ""
var tower_refs: Dictionary = {}
var before_wave_started: bool = false
var completed_wave_pending: int = 0
var after_wave_defer_frames: int = 0
var auto_clear_decision_timer: float = 0.0
var auto_clear_decision_interval: float = 0.25
var auto_clear_last_action_time: float = -999.0
var auto_clear_min_action_gap: float = 0.75
var auto_clear_actions_taken: Array[Dictionary] = []
var auto_clear_handled_wave_complete: bool = false
var auto_clear_initial_setup_actions: Array[Dictionary] = []
var auto_clear_initial_setup_cost: int = 0
var auto_clear_verified_initial_setup_gold: int = 0
var auto_clear_current_test_gold: int = 0

@onready var main := get_parent()
@onready var game_manager := main.get_node_or_null("GameManager") if main else null
@onready var wave_manager := main.get_node_or_null("WaveManager") if main else null
@onready var build_manager := main.get_node_or_null("BuildManager") if main else null

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(REPORT_DIR):
		DirAccess.make_dir_recursive_absolute(REPORT_DIR)

func start_verification(plan: Dictionary) -> void:
	_refresh_refs()
	if not plan or plan.is_empty():
		_fail("Empty plan received")
		return
	if not _is_plan_valid_for_autoplay(plan):
		_fail("Invalid or unvalidated plan rejected")
		return
		
	if main.has_method("is_debug_auto_play_allowed"):
		if not main.is_debug_auto_play_allowed(): return
	elif not OS.is_debug_build(): return
	
	is_active = true
	current_plan = plan
	current_wave = 1
	log_messages.clear()
	fail_reason = ""
	last_action = ""
	tower_refs.clear()
	before_wave_started = false
	completed_wave_pending = 0
	after_wave_defer_frames = 0
	auto_clear_actions_taken.clear()
	auto_clear_decision_timer = 0.0
	auto_clear_handled_wave_complete = false
	auto_clear_initial_setup_actions.clear()
	auto_clear_initial_setup_cost = 0
	auto_clear_verified_initial_setup_gold = 0
	auto_clear_current_test_gold = int(plan.get("starting_gold_used", -1))
	
	_log("Starting Verification: " + plan.get("name", "Unnamed"))
	state = AutoPlayState.STARTING_LEVEL
	state_changed.emit(state, "Loading Level %s" % str(plan.get("level_id")))
	
	var level_id = plan.get("level_id", "level_01")
	var level_path = ""
	if level_id is String:
		if level_id.ends_with(".json"): level_path = level_id
		elif level_id.begins_with("res://"): level_path = level_id
		elif level_id.begins_with("level_"): level_path = "res://data/levels/%s.json" % level_id
		else: level_path = "res://data/levels/level_%s.json" % level_id
	else:
		level_path = "res://data/levels/level_%02d.json" % int(level_id)
		
	_log("Loading level: " + level_path)
	if main.has_method("set_debug_starting_gold_override") and plan.has("starting_gold_used"):
		main.set_debug_starting_gold_override(int(plan.get("starting_gold_used", -1)))
	main.start_level(level_path)
	
	# Wait for level to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	_refresh_refs()
	_connect_wave_signals()
	
	starting_lives = game_manager.lives
	_log("Level loaded. Lives: %d" % starting_lives)
	
	state = AutoPlayState.APPLYING_INITIAL_ACTIONS

func _refresh_refs() -> void:
	if main == null:
		main = get_parent()
	if main:
		game_manager = main.get_node_or_null("GameManager")
		wave_manager = main.get_node_or_null("WaveManager")
		build_manager = main.get_node_or_null("BuildManager")

func _connect_wave_signals() -> void:
	if wave_manager and not wave_manager.wave_completed.is_connected(_on_wave_completed):
		wave_manager.wave_completed.connect(_on_wave_completed)

func _on_wave_completed(wave_number: int, _wave_name: String, _reward: int) -> void:
	completed_wave_pending = wave_number

func _process(_delta: float) -> void:
	if not is_active: return
	
	# Global monitoring
	if game_manager and game_manager.lives < starting_lives:
		_fail("HP lost. started=%d current=%d wave=%d" % [
			starting_lives,
			game_manager.lives,
			current_wave
		])
		return

	match state:
		AutoPlayState.APPLYING_INITIAL_ACTIONS:
			_emit_status("Placing initial towers")
			if _execute_list(current_plan.get("initial_actions", [])):
				state = AutoPlayState.BEFORE_WAVE_ACTIONS
		
		AutoPlayState.BEFORE_WAVE_ACTIONS:
			_emit_status("Before Wave %d Actions" % current_wave)
			var actions = _get_actions(current_wave, "before_wave")
			before_wave_started = _actions_include_start_wave(actions)
			if _execute_list(actions):
				state = AutoPlayState.STARTING_WAVE
		
		AutoPlayState.STARTING_WAVE:
			if not before_wave_started:
				_log("[AUTO_CLEAR] No explicit start_wave action found for Wave %d. Auto-starting." % current_wave)
			_auto_clear_start_wave()
			state = AutoPlayState.WAVE_RUNNING
			
		AutoPlayState.WAVE_RUNNING:
			_emit_status("Wave %d: In Progress" % current_wave)
			
			# Real-time in-wave decision loop
			auto_clear_update_wave_running(_delta)
			
			if not auto_clear_handled_wave_complete and auto_clear_is_wave_fully_complete():
				auto_clear_handled_wave_complete = true
				auto_clear_on_wave_complete()

		AutoPlayState.AFTER_WAVE_ACTIONS:
			_emit_status("After Wave %d Actions" % current_wave)
			if after_wave_defer_frames > 0:
				after_wave_defer_frames -= 1
				return
			var after_actions = _get_actions(current_wave, "after_wave")
			if _execute_list(after_actions):
				completed_wave_pending = 0
				state = AutoPlayState.PREPARING_NEXT_WAVE
			else:
				_fail("After-wave actions failed on Wave %d" % current_wave)

		AutoPlayState.PREPARING_NEXT_WAVE:
			auto_clear_start_next_wave_if_available()

func _get_actions(wave_num: int, timing: String) -> Array:
	return get_wave_action_list(current_plan, wave_num, timing)

func get_wave_action_list(plan: Dictionary, wave_number: int, timing: String) -> Array:
	var wave_key := str(wave_number)
	var wave_actions: Dictionary = plan.get("wave_actions", {})
	if not wave_actions.has(wave_key):
		return []
	var wave_data = wave_actions[wave_key]
	if wave_data is Dictionary:
		return wave_data.get(timing, [])
	var filtered: Array = []
	if wave_data is Array:
		for a in wave_data:
			if a is Dictionary and str(a.get("timing", "before_wave")) == timing:
				filtered.append(a)
	return filtered

func _get_actions_legacy(wave_num: int, timing: String) -> Array:
	var wave_data = current_plan.get("wave_actions", {}).get(str(wave_num), [])
	if wave_data is Dictionary:
		return wave_data.get(timing, [])

	var filtered: Array = []
	if wave_data is Array:
		for a in wave_data:
			if a.get("timing", "before_wave") == timing:
				filtered.append(a)
	return filtered

func _actions_include_start_wave(actions: Array) -> bool:
	for action in actions:
		if str(action.get("type", "")) == "start_wave":
			return true
	return false

func _auto_clear_start_wave() -> void:
	if not wave_manager:
		_fail("Wave manager missing")
		return
	if wave_manager.is_wave_running:
		_log("[AUTO_CLEAR] Cannot start wave: already running")
		return
	if not wave_manager.has_next_wave():
		_log("[AUTO_CLEAR] Cannot start wave: no next wave")
		return
	
	var btn_text = "unknown"
	if main and main.get_node_or_null("GameHUD"):
		var hud = main.get_node("GameHUD")
		if "start_wave_button" in hud and hud.start_wave_button:
			btn_text = hud.start_wave_button.text
			
	_log("[AUTO_CLEAR] Before start Wave %d:" % current_wave)
	_log(" - game current_wave_index=%d" % wave_manager.current_wave_index)
	_log(" - auto_clear_current_wave_number=%d" % current_wave)
	_log(" - wave_running=%s" % str(wave_manager.is_wave_running))
	_log(" - can_start_wave=%s" % str(not wave_manager.is_wave_running))
	_log(" - gold=%d" % (game_manager.gold if game_manager else 0))
	_log(" - lives=%d/%d" % [game_manager.lives if game_manager else 0, starting_lives])
	
	_log("[AUTO_CLEAR] Starting Wave %d" % current_wave)
	
	auto_clear_handled_wave_complete = false
	
	if main and main.has_method("_on_start_wave_requested"):
		main._on_start_wave_requested()
	else:
		wave_manager.start_next_wave()

func _execute_list(actions: Array) -> bool:
	for i in range(actions.size()):
		var a: Dictionary = actions[i]
		_log("Action %d/%d: %s" % [i + 1, actions.size(), _action_to_text(a)])
		
		var result = _execute_action_structured(a)
		match result.get("status"):
			"success":
				continue
			"skipped":
				_log("[AUTO_CLEAR] SKIPPED optional action: " + result.get("reason", "unknown"))
				# Try fallback if it was a tower placement
				if a.get("type") == "place_tower":
					_try_fallback_for_unaffordable_action(a)
				continue
			"failed":
				_fail(result.get("reason", "Action failed"))
				return false
	return true

func _execute_action_structured(action: Dictionary) -> Dictionary:
	var type = action.get("type", "")
	# Initial actions are required. Between-wave actions are optional unless marked.
	var required = action.get("required", state == AutoPlayState.APPLYING_INITIAL_ACTIONS)
	
	match type:
		"place_tower":
			return _place_structured(action, required)
		"upgrade_tower":
			return _upgrade_structured(action, required)
		"start_wave":
			return {"status": "success"}
		"wait_seconds":
			return {"status": "success"}
	
	return {"status": "failed", "reason": "Unknown action type: %s" % str(type)}

func _place_structured(a: Dictionary, required: bool) -> Dictionary:
	var type = a.get("tower_type", "")
	var cell = Vector2i(a.cell[0], a.cell[1])
	build_manager.set_selected_tower(type)
	var val = build_manager.validate_placement(cell)
	
	if not val.is_valid:
		return {"status": "failed", "reason": "Placement invalid at %s: %s" % [str(cell), val.reason]}
		
	if game_manager.gold < val.cost:
		var msg = "No gold for %s at %s. Need %d, have %d" % [type, str(cell), val.cost, game_manager.gold]
		return {"status": "failed" if required else "skipped", "reason": msg}
		
	if game_manager.spend_gold(val.cost):
		build_manager.place_tower(cell, val.config)
		var tower = _find_tower(cell)
		if tower:
			register_auto_clear_tower(a, tower)
		last_action = "Place %s at %s" % [type, str(cell)]
		_log("[AUTO_CLEAR] %s. Gold left=%d" % [last_action, game_manager.gold])
		
		# TRACK INITIAL SETUP
		if state == AutoPlayState.APPLYING_INITIAL_ACTIONS:
			auto_clear_initial_setup_cost += val.cost
			var recorded = a.duplicate(true)
			recorded["cost"] = val.cost
			auto_clear_initial_setup_actions.append(recorded)
			_log("[AUTO_CLEAR] Initial setup tower: %s cost=%d total_setup_cost=%d" % [type, val.cost, auto_clear_initial_setup_cost])
			
		return {"status": "success"}
		
	return {"status": "failed", "reason": "Spend gold failed unexpectedly for %s" % type}

func _upgrade_structured(a: Dictionary, required: bool) -> Dictionary:
	var tower = _resolve_tower_for_upgrade(a)
	if not tower:
		return {"status": "failed", "reason": "No tower found for upgrade: %s" % str(a)}
		
	if tower.has_method("can_upgrade") and not tower.can_upgrade():
		return {"status": "skipped" if not required else "failed", "reason": "Tower at max level or cannot upgrade"}
		
	var cost = tower.get_upgrade_cost()
	if game_manager.gold < cost:
		var msg = "No gold for upgrade at %s. Need %d, have %d" % [str(_get_tower_cell(tower)), cost, game_manager.gold]
		return {"status": "failed" if required else "skipped", "reason": msg}
		
	if game_manager.spend_gold(cost):
		tower.upgrade()
		last_action = "Upgrade %s to Lv%d" % [_tower_label(tower), tower.get_tower_level() if tower.has_method("get_tower_level") else 0]
		_log("[AUTO_CLEAR] %s. Gold left=%d" % [last_action, game_manager.gold])
		return {"status": "success"}
		
	return {"status": "failed", "reason": "Spend gold failed unexpectedly for upgrade"}

func _try_fallback_for_unaffordable_action(failed_action: Dictionary) -> void:
	_log("[AUTO_CLEAR] Searching for affordable fallback...")
	var cell = Vector2i(failed_action.cell[0], failed_action.cell[1])
	
	# Try cheaper towers in order
	var fallbacks = ["rapid_tower", "basic_tower"]
	for fb_type in fallbacks:
		build_manager.set_selected_tower(fb_type)
		var val = build_manager.validate_placement(cell)
		if val.is_valid and game_manager.gold >= val.cost:
			_log("[AUTO_CLEAR] Found fallback: %s cost %d" % [fb_type, val.cost])
			var fb_action = failed_action.duplicate()
			fb_action["tower_type"] = fb_type
			fb_action["reason"] = "Fallback for unaffordable %s" % failed_action.get("tower_type")
			_place_structured(fb_action, false)
			return
			
	_log("[AUTO_CLEAR] No affordable fallback found for spot %s" % str(cell))

func _execute_action(action: Dictionary) -> bool:
	# Keep for legacy support if needed, but redirects to structured
	var res = _execute_action_structured(action)
	if res.status == "failed":
		_fail(res.reason)
		return false
	return true

func _resolve_tower_for_upgrade(a: Dictionary) -> Node2D:
	if a.has("tower_ref"):
		var ref: String = str(a.get("tower_ref"))
		if tower_refs.has(ref) and is_instance_valid(tower_refs[ref]):
			return tower_refs[ref]
		if ref.contains("@"):
			var parts: PackedStringArray = ref.split("@")
			var coords: PackedStringArray = parts[1].split(",")
			if coords.size() >= 2:
				return _find_tower_by_type_and_cell(str(parts[0]), Vector2i(int(coords[0]), int(coords[1])))
		for t in _get_tower_container_children():
			if t.has_meta("auto_clear_id") and str(t.get_meta("auto_clear_id")) == ref:
				return t
	if a.has("cell"):
		var cell_data: Array = a.get("cell")
		if cell_data.size() >= 2:
				return _find_tower(Vector2i(int(cell_data[0]), int(cell_data[1])))
	return null

func register_auto_clear_tower(action: Dictionary, tower: Node) -> void:
	if action.has("id"):
		var explicit_id := str(action.get("id"))
		tower_refs[explicit_id] = tower
		tower.set_meta("auto_clear_id", explicit_id)
	var cell: Vector2i = _get_tower_cell(tower)
	var tower_type: String = _get_tower_type(tower)
	if tower_type != "":
		tower_refs["%s@%d,%d" % [tower_type, cell.x, cell.y]] = tower

func _get_tower_type(tower: Node) -> String:
	if tower.has_method("get_tower_id"):
		return str(tower.get_tower_id())
	if "tower_id" in tower:
		return str(tower.tower_id)
	if tower.has_meta("tower_type"):
		return str(tower.get_meta("tower_type"))
	return ""

func _get_tower_cell(tower: Node) -> Vector2i:
	if tower.has_method("get_grid_cell"):
		return tower.get_grid_cell()
	if "grid_cell" in tower:
		return tower.grid_cell
	if tower.has_meta("grid_cell"):
		return tower.get_meta("grid_cell")
	return Vector2i.ZERO

func _get_tower_container_children() -> Array:
	var container = main.get_node_or_null("WorldRoot/MapRoot/TowerContainer") if main else null
	return container.get_children() if container else []

func _tower_label(tower: Node) -> String:
	if tower.has_meta("auto_clear_id"):
		return str(tower.get_meta("auto_clear_id"))
	if tower.has_method("get_tower_id"):
		return tower.get_tower_id()
	return str(tower.name)

func _find_tower(cell: Vector2i) -> Node2D:
	var container = main.get_node_or_null("WorldRoot/MapRoot/TowerContainer")
	if not container: return null
	for t in container.get_children():
		if t.get("grid_cell") == cell: return t
	return null

func _find_tower_by_type_and_cell(tower_type: String, cell: Vector2i) -> Node2D:
	for tower in _get_tower_container_children():
		if _get_tower_cell(tower) == cell and _get_tower_type(tower) == tower_type:
			return tower
	return null

func _log(msg: String):
	log_messages.append("[%s] %s" % [Time.get_time_string_from_system(), msg])
	print("[AutoVerify] ", msg)

func _fail(reason: String):
	fail_reason = reason
	is_active = false
	state = AutoPlayState.FAILED
	_safe_reset_waves("AutoPlay failure: " + reason)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	_log("FAILED: " + reason)
	state_changed.emit(state, "FAILED: " + reason)

func _safe_reset_waves(reason: String) -> void:
	if is_active and state in [
		AutoPlayState.AFTER_WAVE_ACTIONS,
		AutoPlayState.PREPARING_NEXT_WAVE,
		AutoPlayState.BEFORE_WAVE_ACTIONS,
		AutoPlayState.WAVE_RUNNING
	]:
		_log("[AUTO_CLEAR] BLOCKED reset_waves during active continuation. reason=" + reason)
		return

	if wave_manager:
		_log("[AUTO_CLEAR] reset_waves called. reason=" + reason)
		wave_manager.reset_waves()

func _complete_success():
	is_active = false
	state = AutoPlayState.COMPLETED
	
	auto_clear_verified_initial_setup_gold = auto_clear_initial_setup_cost
	_log("[AUTO_CLEAR] SUCCESS: Level cleared with no HP lost.")
	_log("[AUTO_CLEAR] VERIFIED PERFECT RUN")
	_log("[AUTO_CLEAR] Debug starting_gold tested: %d" % auto_clear_current_test_gold)
	_log("[AUTO_CLEAR] Initial setup cost before Wave 1: %d" % auto_clear_verified_initial_setup_gold)
	_log("[AUTO_CLEAR] Recommended starting_gold: %d" % auto_clear_verified_initial_setup_gold)
	
	state_changed.emit(state, "SUCCESS: Perfect Clear | Recommended Gold: %d" % auto_clear_verified_initial_setup_gold)

func auto_clear_is_wave_fully_complete() -> bool:
	if wave_manager == null:
		return false
	if wave_manager.is_wave_running:
		return false
	if wave_manager.is_spawning:
		return false
	if wave_manager.active_enemy_count > 0:
		return false
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		return false
	return true

func auto_clear_on_wave_complete() -> void:
	_log("[AUTO_CLEAR] Wave %d completed" % current_wave)
	
	# Wait for reward to be applied
	await get_tree().process_frame
	
	_log("[AUTO_CLEAR] After wave %d: gold=%d lives=%d/%d" % [
		current_wave,
		game_manager.gold if game_manager else 0,
		game_manager.lives if game_manager else 0,
		starting_lives
	])
	
	if game_manager and game_manager.lives < starting_lives:
		_fail("HP lost after wave %d" % current_wave)
		return
		
	# Check for actions after wave
	var after_actions = _get_actions(current_wave, "after_wave")
	if not after_actions.is_empty():
		after_wave_defer_frames = 0 # Already waited 1 frame above
		state = AutoPlayState.AFTER_WAVE_ACTIONS
	else:
		state = AutoPlayState.PREPARING_NEXT_WAVE

func auto_clear_start_next_wave_if_available() -> void:
	if wave_manager == null:
		_fail("Wave manager missing")
		return
		
	var total_waves = wave_manager.get_total_waves()
	
	if current_wave >= total_waves:
		_complete_success()
		return
		
	if wave_manager.has_next_wave():
		current_wave += 1
		_log("[AUTO_CLEAR] Preparing Wave %d / %d" % [current_wave, total_waves])
		state = AutoPlayState.BEFORE_WAVE_ACTIONS
	else:
		_fail("No next wave but level not cleared")

func auto_clear_prepare_next_wave() -> void:
	# Deprecated by auto_clear_start_next_wave_if_available but kept for safety
	auto_clear_start_next_wave_if_available()

func _get_upcoming_wave_summary() -> String:
	if wave_manager == null:
		return "unknown"
	var data: Dictionary = wave_manager.get_current_wave_data()
	var parts: Array[String] = []
	for group in data.get("groups", []):
		parts.append("%s x%d" % [str(group.get("enemy_type", "unknown")).capitalize(), int(group.get("count", 0))])
	return ", ".join(parts) if not parts.is_empty() else "unknown"

func _emit_status(label: String) -> void:
	var total_waves: int = wave_manager.get_total_waves() if wave_manager else 0
	var lives_text: String = "%d / %d" % [game_manager.lives, starting_lives] if game_manager else "-"
	var gold_text: String = str(game_manager.gold) if game_manager else "-"
	state_changed.emit(state, "%s | Wave %d/%d | Lives %s | Gold %s | %s" % [label, current_wave, total_waves, lives_text, gold_text, last_action])

func _is_plan_valid_for_autoplay(plan: Dictionary) -> bool:
	if plan.is_empty(): return false
	if not plan.has("level_id"): return false
	if not plan.has("initial_actions"): return false
	if not plan.has("wave_actions"): return false
	if not bool(plan.get("validated", false)): return false
	if int(plan.get("expected_lives_lost", 999)) != 0: return false
	if bool(plan.get("covers_all_waves", false)) != true: return false
	return true

func _action_to_text(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"place_tower":
			return "place %s at %s" % [str(action.get("tower_type", "")), str(action.get("cell", []))]
		"upgrade_tower":
			return "upgrade tower at %s" % str(action.get("cell", []))
		"start_wave":
			return "start wave"
		_:
			return str(action)

func auto_clear_update_wave_running(delta: float) -> void:
	auto_clear_decision_timer -= delta
	if auto_clear_decision_timer <= 0.0:
		auto_clear_decision_timer = auto_clear_decision_interval
		auto_clear_make_in_wave_decision()

func auto_clear_make_in_wave_decision() -> void:
	if not wave_manager or not wave_manager.is_wave_running:
		return
	
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - auto_clear_last_action_time < auto_clear_min_action_gap:
		return

	var gold = game_manager.gold if game_manager else 0
	if gold <= 0:
		return

	var risk = auto_clear_calculate_leak_risk()
	if risk["risk_level"] == "low" and gold < 50: # Only save gold if risk is low and gold is scarce
		return

	var action = auto_clear_choose_best_in_wave_action(risk)
	if not action.is_empty():
		auto_clear_execute_action(action, "in_wave")
		auto_clear_last_action_time = current_time

func auto_clear_calculate_leak_risk() -> Dictionary:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return {"risk_level": "low", "reason": "No enemies"}

	var high_risk_count = 0
	var critical_enemy = null
	var highest_progress = 0.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		
		# Assume enemy has PathFollow2D or progress property
		var progress = 0.0
		if "progress_ratio" in enemy:
			progress = enemy.progress_ratio
		elif enemy.get_parent() is PathFollow2D:
			progress = enemy.get_parent().progress_ratio
		
		if progress > highest_progress:
			highest_progress = progress
			critical_enemy = enemy
		
		if progress > 0.7:
			high_risk_count += 1
	
	var risk_level = "low"
	var reason = "All clear"
	
	if highest_progress > 0.9:
		risk_level = "critical"
		reason = "Enemy very near base (%.1f%%)" % (highest_progress * 100.0)
	elif highest_progress > 0.75 or high_risk_count >= 3:
		risk_level = "high"
		reason = "Multiple enemies deep in path or leading enemy at %.1f%%" % (highest_progress * 100.0)
	elif highest_progress > 0.5:
		risk_level = "medium"
		reason = "Enemy past mid-point"

	return {
		"risk_level": risk_level,
		"highest_progress": highest_progress,
		"critical_enemy": critical_enemy,
		"high_risk_count": high_risk_count,
		"reason": reason
	}

func auto_clear_choose_best_in_wave_action(risk: Dictionary) -> Dictionary:
	# 1. Try to find a best upgrade
	var upgrade = auto_clear_find_best_in_wave_upgrade(risk)
	if not upgrade.is_empty():
		return upgrade
	
	# 2. Try to find a best build
	var build = auto_clear_find_best_in_wave_build(risk)
	if not build.is_empty():
		return build
	
	return {}

func auto_clear_find_best_in_wave_upgrade(risk: Dictionary) -> Dictionary:
	var gold = game_manager.gold if game_manager else 0
	var towers = _get_tower_container_children()
	
	var best_tower = null
	var best_score = -1.0
	
	for tower in towers:
		if not tower.has_method("can_upgrade") or not tower.can_upgrade():
			continue
		
		var cost = tower.get_upgrade_cost()
		if gold < cost:
			continue
		
		var score = 10.0 # Base score
		
		# Bonus if tower is near the critical enemy
		if risk["critical_enemy"] != null:
			var dist = tower.global_position.distance_to(risk["critical_enemy"].global_position)
			if dist < 150.0: # Roughly tower range
				score += 50.0
		
		# Bonus for higher progress enemies in range
		var coverage = _get_tower_path_coverage(tower)
		score += coverage * 2.0
		
		if score > best_score:
			best_score = score
			best_tower = tower
	
	if best_tower:
		return {
			"type": "upgrade_tower",
			"tower_ref": _tower_label(best_tower),
			"cell": [_get_tower_cell(best_tower).x, _get_tower_cell(best_tower).y],
			"reason": "Risk %s: %s. Upgrading %s" % [risk["risk_level"], risk["reason"], _tower_label(best_tower)]
		}
	
	return {}

func auto_clear_find_best_in_wave_build(risk: Dictionary) -> Dictionary:
	var gold = game_manager.gold if game_manager else 0
	if gold < 60: # Minimum tower cost
		return {}

	if risk["risk_level"] == "low":
		return {}

	var critical_enemy = risk.get("critical_enemy")
	if not critical_enemy or not is_instance_valid(critical_enemy):
		return {}

	# Find a cell near the critical enemy that is legal
	var enemy_pos = critical_enemy.global_position
	# We need to map global position to grid cell
	# Usually main or build_manager has a method for this
	var target_cell = Vector2i.ZERO
	if main.has_method("global_to_grid"):
		target_cell = main.global_to_grid(enemy_pos)
	elif build_manager.has_method("get_cell_from_position"):
		target_cell = build_manager.get_cell_from_position(enemy_pos)
	else:
		# Fallback: search around the enemy
		return {}

	# Search in a small radius around target_cell for a legal spot
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var cell = target_cell + Vector2i(dx, dy)
			# Basic bounds check if possible
			if cell.x < 0 or cell.y < 0: continue
			
			build_manager.set_selected_tower("rapid_tower" if gold >= 100 else "basic_tower")
			var val = build_manager.validate_placement(cell)
			if val.is_valid:
				return {
					"type": "place_tower",
					"tower_type": build_manager.selected_tower_type,
					"cell": [cell.x, cell.y],
					"reason": "Risk %s: %s. Building %s at %s" % [risk["risk_level"], risk["reason"], build_manager.selected_tower_type, str(cell)]
				}

	return {}

func auto_clear_execute_action(action: Dictionary, source: String) -> void:
	_log("[AUTO_CLEAR] %s ACTION: %s" % [source.to_upper(), action.get("reason", _action_to_text(action))])
	
	var result = _execute_action_structured(action)
	
	if result.get("status") == "success":
		action["source"] = source
		action["timestamp"] = Time.get_ticks_msec() / 1000.0
		action["wave"] = current_wave
		auto_clear_actions_taken.append(action)
	elif result.get("status") == "failed":
		# If a required in-wave action fails (rare), we fail the run
		_fail(result.get("reason", "In-wave action failed"))
	elif result.get("status") == "skipped":
		_log("[AUTO_CLEAR] In-wave action skipped: " + result.get("reason", ""))

func _get_tower_path_coverage(tower: Node) -> float:
	# Simplified version of solver's coverage logic
	# Count path cells within range
	var cell = _get_tower_cell(tower)
	# We'd need level data path cells here. 
	# For now, return a dummy value or use main.level_data
	if main and "level_data" in main:
		var path = main.level_data.get("path_cells", [])
		var count = 0.0
		for p in path:
			var dist = Vector2(cell).distance_to(Vector2(p[0], p[1]))
			if dist <= 3.5:
				count += 1.0
		return count
	return 0.0
