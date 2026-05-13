extends RefCounted

static func is_plan_valid_for_autoplay(plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	if not plan.has("level_id"):
		return false
	if not plan.has("initial_actions"):
		return false
	if not plan.has("wave_actions"):
		return false
	if not bool(plan.get("validated", false)):
		return false
	if int(plan.get("expected_lives_lost", 999)) != 0:
		return false
	if bool(plan.get("covers_all_waves", false)) != true:
		return false
	var total_waves: int = get_plan_total_waves(plan)
	if total_waves <= 0:
		return false
	for wave_num in range(1, total_waves + 1):
		if not plan.get("wave_actions", {}).has(str(wave_num)):
			return false
		var before_actions: Array = get_wave_action_list(plan, wave_num, "before_wave")
		var after_actions: Array = get_wave_action_list(plan, wave_num, "after_wave")
		for action in before_actions + after_actions:
			if not (action is Dictionary):
				return false
			var action_type: String = str(action.get("type", ""))
			if not ["place_tower", "upgrade_tower", "start_wave", "wait_seconds"].has(action_type):
				return false
	if total_waves > 1 and not plan_has_between_wave_non_start_action(plan):
		print("[AUTO_CLEAR] Planner selected upgrades/builds during search, but final plan contains no between-wave actions.")
		return false
	return true

static func normalize_auto_clear_plan(plan: Dictionary) -> void:
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
				if action is Dictionary and str(action.get("timing", "before_wave")) == "after_wave":
					after.append(action)
				elif action is Dictionary:
					before.append(action)
			normalized[str(wave_key)] = {"before_wave": before, "after_wave": after}
	plan["wave_actions"] = normalized

static func get_wave_action_list(plan: Dictionary, wave_number: int, timing: String) -> Array:
	var wave_key := str(wave_number)
	var wave_actions: Dictionary = plan.get("wave_actions", {})
	if not wave_actions.has(wave_key):
		return []
	var entry = wave_actions[wave_key]
	if entry is Dictionary:
		return entry.get(timing, [])
	var result: Array = []
	if entry is Array:
		for action in entry:
			if action is Dictionary and str(action.get("timing", "before_wave")) == timing:
				result.append(action)
	return result

static func get_plan_total_waves(plan: Dictionary) -> int:
	var total_waves: int = 0
	for wave_key in plan.get("wave_actions", {}).keys():
		total_waves = max(total_waves, int(str(wave_key)))
	return total_waves

static func plan_has_between_wave_non_start_action(plan: Dictionary) -> bool:
	var total_waves: int = get_plan_total_waves(plan)
	for wave_num in range(1, total_waves + 1):
		for action in get_wave_action_list(plan, wave_num, "after_wave"):
			if action is Dictionary and str(action.get("type", "")) != "start_wave":
				return true
		if wave_num > 1:
			for action in get_wave_action_list(plan, wave_num, "before_wave"):
				if action is Dictionary and str(action.get("type", "")) != "start_wave":
					return true
	return false

static func format_auto_clear_final_plan(plan: Dictionary) -> String:
	var lines: Array[String] = ["[AUTO_CLEAR] FINAL PLAN:"]
	lines.append("Initial actions:")
	for action in plan.get("initial_actions", []):
		if action is Dictionary:
			lines.append(" - %s" % auto_clear_action_text(action))
	var total_waves: int = get_plan_total_waves(plan)
	for wave_num in range(1, total_waves + 1):
		lines.append("Wave %d before:" % wave_num)
		for action in get_wave_action_list(plan, wave_num, "before_wave"):
			if action is Dictionary:
				lines.append(" - %s" % auto_clear_action_text(action))
		lines.append("Wave %d after:" % wave_num)
		for action in get_wave_action_list(plan, wave_num, "after_wave"):
			if action is Dictionary:
				lines.append(" - %s" % auto_clear_action_text(action))
	return "\n".join(lines)

static func auto_clear_action_text(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"place_tower":
			return "place %s %s" % [str(action.get("tower_type", "")), str(action.get("cell", []))]
		"upgrade_tower":
			return "upgrade %s" % str(action.get("tower_ref", action.get("cell", [])))
		"start_wave":
			return "start_wave"
		_:
			return str(action)
