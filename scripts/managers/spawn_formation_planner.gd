extends RefCounted
class_name SpawnFormationPlanner

const ENEMY_CATEGORY_AIR := "air"

const ROLE_FRONTLINER := "frontliner"
const ROLE_ESCORT := "escort"
const ROLE_PRESSURE := "pressure"
const ROLE_SWARM := "swarm"
const ROLE_SUPPORT := "support"
const ROLE_DISRUPTOR := "disruptor"
const ROLE_AIR := "air"
const ROLE_SPLITTER := "splitter"
const ROLE_PRIORITY := "priority_target"

const ROLE_POSITION := {
	ROLE_FRONTLINER: "lead",
	ROLE_ESCORT: "middle",
	ROLE_SUPPORT: "rear-middle",
	ROLE_PRESSURE: "delayed burst",
	ROLE_SWARM: "clustered burst",
	ROLE_DISRUPTOR: "protected middle",
	ROLE_AIR: "parallel pressure",
	ROLE_SPLITTER: "middle payload",
	ROLE_PRIORITY: "protected visible"
}

const TACTICAL_NOTES := {
	"escort_staggered": "Tank-led convoy",
	"tank_support_column": "Support protected by frontliners",
	"armored_cloak_mask": "Cloaked units masked by visible enemies",
	"swarm_screen": "Swarm screen",
	"swarm_runner_flank": "Swarm and runner flank",
	"swarm_runner_pressure": "Swarm and runner flank",
	"delayed_runner_pressure": "Runner burst after frontline",
	"shield_wall": "Break the shield wall",
	"repair_convoy": "Healer protected by heavy units",
	"splitter_payload": "Splitter payload",
	"air_escort": "Air disruptor escort",
	"frontliner_anchor": "Frontliner anchor",
	"support_guard": "Support guard",
	"stealth_mask": "Stealth mask",
	"stealth_probe": "Stealth probe",
	"delayed_pressure": "Delayed pressure burst",
	"swarm_burst": "Swarm burst",
	"air_wing": "Air wing",
	"payload": "Payload formation",
	"baseline_column": "Baseline column",
	"runner_raid": "Runner raid",
	"swarm_rush": "Swarm rush",
	"heavy_column": "Heavy column",
	"repair_train": "Repair train",
	"air_scout_wing": "Air scout wing",
	"multi_lane_pincer": "Coordinated multi-lane pincer",
	"multi_lane_sync": "Synchronized multi-lane attack"
}

var enemies_config: Dictionary = {}
var last_plan: Dictionary = {}

func _init(config: Dictionary = {}) -> void:
	enemies_config = config

func set_enemies_config(config: Dictionary) -> void:
	enemies_config = config

func build_plan(wave_data: Dictionary, wave_index: int = 0) -> Dictionary:
	var groups: Array = _get_wave_groups(wave_data)
	var legacy_duration := _estimate_legacy_duration(groups)
	var path_groups := _groups_by_path(groups)
	var plan := {
		"wave_id": int(wave_data.get("wave", wave_index + 1)),
		"original_groups": groups.duplicate(true),
		"paths": path_groups.keys(),
		"path_plans": {},
		"formations": [],
		"events": [],
		"generated_spawn_events": [],
		"total_enemy_count": _count_groups(groups),
		"legacy_duration": legacy_duration,
		"total_duration": 0.0,
		"density_score": 0.0,
		"role_diversity_score": 0.0,
		"synergy_score": 0.0,
		"support_protection_score": 0.0,
		"cloaked_masking_score": 0.0,
		"runner_timing_score": 0.0,
		"air_pressure_score": 0.0,
		"warnings": [],
		"wrapper_formation": "multi_lane_pincer" if path_groups.keys().size() > 1 else "",
		"formation_preview": [],
		"validation_result": {}
	}

	# Handle explicit formations array if present
	if wave_data.has("formations") and wave_data["formations"] is Array:
		var start_offset := 0.0
		for f_data in wave_data["formations"]:
			var f_res := _build_explicit_formation(f_data, start_offset)
			plan["formations"].append(f_res)
			plan["events"].append_array(f_res.get("generated_events", []))
			plan["formation_preview"].append({
				"path": f_data.get("path_id", "default"),
				"formation": f_data.get("type", "unknown"),
				"note": f_res.get("tactical_note", ""),
				"role_sequence": f_res.get("role_sequence", [])
			})
			# Formations in the list are sequential by default
			start_offset += f_res.get("duration", 0.0) + f_data.get("burst_delay", 1.0)
		
		# If we have explicit formations, we might still have loose groups?
		# For now assume formations is the full source if present, 
		# or merge with remaining path groups.
	
	if groups.is_empty() and plan["events"].is_empty():
		last_plan = plan
		return plan
	
	var path_ids: Array = path_groups.keys()
	path_ids.sort()
	var path_offset_index := 0
	for path_id in path_ids:
		# Skip paths already handled by explicit formations
		for f in plan["formations"]:
			if f.get("path") == path_id:
				# This is a bit complex if one path has multiple formations.
				# For now, if we have explicit formations, we assume they define the path behavior.
				# But let's allow mixing if needed.
				pass
		
		var path_list: Array = path_groups[path_id]
		var explicit := _explicit_formation(wave_data, path_list)
		var formation := explicit if explicit != "" else _detect_formation(path_list)
		var offset := _path_offset(path_id, path_offset_index, path_ids.size(), formation)
		var formation_result := _build_path_formation(path_id, path_list, formation, offset)
		plan["formations"].append(formation_result)
		plan["path_plans"][path_id] = formation_result
		plan["events"].append_array(formation_result.get("generated_events", []))
		plan["formation_preview"].append({
			"path": path_id,
			"formation": formation_result.get("pattern", formation),
			"note": formation_result.get("tactical_note", TACTICAL_NOTES.get(formation, "")),
			"role_sequence": formation_result.get("role_sequence", [])
		})
		path_offset_index += 1
	
	plan["events"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	plan["generated_spawn_events"] = plan["events"]
	plan["total_duration"] = _duration_for_events(plan["events"])
	plan["warnings"].append_array(_validate_plan(plan))
	_repair_invalid_plan(plan)
	_apply_metrics(plan)
	last_plan = plan
	return plan

func schedule_from_plan(plan: Dictionary) -> Array:
	var events: Array = plan.get("events", [])
	var out := []
	for event in events:
		out.append((event as Dictionary).duplicate(true))
	return out

func infer_enemy_roles(enemy_type: String, group_data: Dictionary = {}) -> Array[String]:
	var cfg: Dictionary = enemies_config.get(enemy_type, {})
	var roles: Array[String] = []
	var tags: Array = cfg.get("tags", [])
	var skill := str(cfg.get("skill", group_data.get("skill", "")))
	var category := str(group_data.get("category", cfg.get("category", ""))).to_lower()
	var movement_type := str(group_data.get("movement_type", cfg.get("movement_type", ""))).to_lower()
	var hp := float(group_data.get("max_hp", cfg.get("max_hp", 0.0)))
	var speed := float(group_data.get("speed", cfg.get("speed", 0.0)))
	var counters: Array = cfg.get("counter_towers", [])
	
	if enemy_type in ["tank", "bulwark", "shieldbearer", "armored_flyer"] or _has_any(tags, ["heavy", "armored", "frontline"]) or hp >= 180.0:
		_add_role(roles, ROLE_FRONTLINER)
	if enemy_type in ["basic", "flyer"] or _has_any(tags, ["core", "baseline", "scout"]):
		_add_role(roles, ROLE_ESCORT)
	if enemy_type in ["fast", "runner", "hunter", "fast_flyer"] or _has_any(tags, ["fast", "runner", "danger", "anti_hero"]) or speed >= 135.0:
		_add_role(roles, ROLE_PRESSURE)
	if enemy_type == "swarm" or _has_any(tags, ["swarm", "small"]):
		_add_role(roles, ROLE_SWARM)
	if enemy_type in ["healer", "shieldbearer", "disruptor"] or _has_any(tags, ["support", "healing", "shield", "disruptor"]) or skill in ["healer", "shield_aura", "disrupt_aura"]:
		_add_role(roles, ROLE_SUPPORT)
	if enemy_type in ["cloaked", "disruptor", "hunter"] or _has_any(tags, ["stealth", "disruptor", "anti_hero"]):
		_add_role(roles, ROLE_DISRUPTOR)
	if enemy_type in ["flyer", "fast_flyer", "armored_flyer", "disruptor"] or category == ENEMY_CATEGORY_AIR or movement_type == ENEMY_CATEGORY_AIR or tags.has("air"):
		_add_role(roles, ROLE_AIR)
	if enemy_type == "splitter" or skill == "split_on_death" or tags.has("splitter"):
		_add_role(roles, ROLE_SPLITTER)
	if enemy_type in ["healer", "shieldbearer", "disruptor", "hunter", "splitter"]:
		_add_role(roles, ROLE_PRIORITY)
	if counters.has("sniper") and (roles.has(ROLE_SUPPORT) or roles.has(ROLE_DISRUPTOR)):
		_add_role(roles, ROLE_PRIORITY)
	if roles.is_empty():
		roles.append(ROLE_ESCORT)
	return roles

func _build_path_formation(path_id: String, raw_groups: Array, formation: String, offset: float) -> Dictionary:
	var groups := _normalize_groups(raw_groups)
	var events: Array = []
	match formation:
		"escort_staggered":
			events = _gen_escort_staggered(path_id, groups, offset)
		"tank_support_column":
			events = _gen_tank_support_column(path_id, groups, offset)
		"armored_cloak_mask":
			events = _gen_armored_cloak_mask(path_id, groups, offset)
		"swarm_screen":
			events = _gen_swarm_screen(path_id, groups, offset)
		"delayed_runner_pressure":
			events = _gen_delayed_runner_pressure(path_id, groups, offset)
		"swarm_runner_pressure":
			events = _gen_swarm_runner_pressure(path_id, groups, offset)
		"swarm_runner_flank":
			events = _gen_swarm_runner_pressure(path_id, groups, offset)
		"shield_wall":
			events = _gen_shield_wall(path_id, groups, offset)
		"repair_convoy":
			events = _gen_repair_convoy(path_id, groups, offset)
		"splitter_payload":
			events = _gen_splitter_payload(path_id, groups, offset)
		"air_escort":
			events = _gen_air_escort(path_id, groups, offset)
		"frontliner_anchor":
			events = _gen_frontliner_anchor(path_id, groups, offset)
		"support_guard":
			events = _gen_support_guard(path_id, groups, offset)
		"stealth_mask":
			events = _gen_armored_cloak_mask(path_id, groups, offset)
		"stealth_probe":
			events = _gen_stealth_probe(path_id, groups, offset)
		"delayed_pressure":
			events = _gen_delayed_runner_pressure(path_id, groups, offset)
		"swarm_burst":
			events = _gen_swarm_burst(path_id, groups, offset)
		"air_wing", "air_scout_wing":
			events = _gen_air_wing(path_id, groups, offset)
		"payload":
			events = _gen_splitter_payload(path_id, groups, offset)
		"baseline_column":
			events = _gen_baseline_column(path_id, groups, offset)
		"runner_raid":
			events = _gen_runner_raid(path_id, groups, offset)
		"swarm_rush":
			events = _gen_swarm_burst(path_id, groups, offset)
		"heavy_column":
			events = _gen_heavy_column(path_id, groups, offset)
		"repair_train":
			events = _gen_repair_train(path_id, groups, offset)
		"single_file", "line":
			events = _gen_baseline_column(path_id, groups, offset)
		"cluster", "swarm_pack":
			events = _gen_swarm_burst(path_id, groups, offset)
		"staggered":
			events = _gen_escort_staggered(path_id, groups, offset)
		"escort":
			events = _gen_tank_support_column(path_id, groups, offset)
		"mixed_squad":
			events = _gen_mixed_squad(path_id, groups, offset)
		"boss_guard":
			events = _gen_boss_guard(path_id, groups, offset)
		"wedge":
			events = _gen_wedge(path_id, groups, offset)
		_:
			formation = _fallback_formation_for_groups(groups)
			return _build_path_formation(path_id, raw_groups, formation, offset)
	_apply_formation_preserve_throttles(events, groups, formation)
	
	# Assign formation indices
	for i in range(events.size()):
		events[i]["formation_index"] = i + 1
		events[i]["formation_total"] = events.size()
	
	var roles := []
	for event in events:
		for role in event.get("role_tags", []):
			if not roles.has(role):
				roles.append(role)
	
	return {
		"id": "%s:%s" % [path_id, formation],
		"pattern": formation,
		"path": path_id,
		"groups": groups,
		"generated_events": events,
		"role_sequence": roles,
		"rules": _rules_for_formation(formation),
		"validation_result": {},
		"tactical_note": TACTICAL_NOTES.get(formation, "Legacy spawn stream")
	}

func _detect_formation(raw_groups: Array) -> String:
	var groups := _normalize_groups(raw_groups)
	if groups.is_empty():
		return "baseline_column"
	var roles := _roles_in_groups(groups)
	if _unique_types(groups).size() <= 1:
		return _single_role_formation(groups[0])
	if roles.has(ROLE_SWARM) and roles.has(ROLE_PRESSURE):
		return "swarm_runner_flank"
	if roles.has(ROLE_FRONTLINER) and roles.has(ROLE_SUPPORT):
		if _has_type(groups, "shieldbearer"):
			return "shield_wall"
		if _has_type(groups, "healer"):
			return "repair_convoy"
		return "tank_support_column"
	if roles.has(ROLE_FRONTLINER) and roles.has(ROLE_DISRUPTOR) and _has_type(groups, "cloaked"):
		return "armored_cloak_mask"
	if roles.has(ROLE_FRONTLINER) and roles.has(ROLE_SWARM):
		return "swarm_screen"
	if roles.has(ROLE_FRONTLINER) and roles.has(ROLE_PRESSURE):
		return "delayed_runner_pressure"
	if roles.has(ROLE_AIR):
		return "air_escort"
	if roles.has(ROLE_SPLITTER):
		return "splitter_payload"
	if roles.has(ROLE_FRONTLINER) and roles.has(ROLE_ESCORT):
		return "escort_staggered"
	if roles.has(ROLE_PRESSURE) and (roles.has(ROLE_ESCORT) or roles.has(ROLE_SWARM)):
		return "delayed_runner_pressure"
	if roles.has(ROLE_DISRUPTOR) and roles.has(ROLE_ESCORT):
		return "armored_cloak_mask"
	return _fallback_formation_for_groups(groups)

func _single_role_formation(group: Dictionary) -> String:
	var roles: Array = group.get("role_tags", [])
	if roles.has(ROLE_SWARM):
		return "swarm_pack"
	if roles.has(ROLE_PRESSURE):
		return "runner_raid"
	if roles.has(ROLE_AIR):
		return "air_wing"
	if roles.has(ROLE_SUPPORT) and str(group.get("type", "")) == "healer":
		return "repair_train"
	if roles.has(ROLE_DISRUPTOR) and str(group.get("type", "")) == "cloaked":
		return "stealth_probe"
	if roles.has(ROLE_FRONTLINER) or roles.has(ROLE_SPLITTER):
		return "heavy_column"
	return "baseline_column"

func _fallback_formation_for_groups(groups: Array) -> String:
	var roles := _roles_in_groups(groups)
	if roles.has(ROLE_FRONTLINER):
		return "frontliner_anchor"
	if roles.has(ROLE_SUPPORT):
		return "support_guard"
	if roles.has(ROLE_DISRUPTOR) and _has_type(groups, "cloaked"):
		return "stealth_mask" if _unique_types(groups).size() > 1 else "stealth_probe"
	if roles.has(ROLE_PRESSURE):
		return "delayed_pressure"
	if roles.has(ROLE_SWARM):
		return "swarm_burst"
	if roles.has(ROLE_AIR):
		return "air_wing"
	if roles.has(ROLE_SPLITTER):
		return "payload"
	return "baseline_column"

func _gen_escort_staggered(path_id: String, groups: Array, offset: float) -> Array:
	var frontliners := _units_with_role(groups, ROLE_FRONTLINER)
	var escorts := _units_without_roles(groups, [ROLE_FRONTLINER])
	if frontliners.is_empty():
		return _gen_baseline_column(path_id, groups, offset)
	var events := []
	var time := offset
	events.append(_event(time, frontliners.pop_front(), path_id, "escort_staggered"))
	time += 0.20
	var escort_run := 0
	while not frontliners.is_empty() or not escorts.is_empty():
		if not escorts.is_empty():
			var escort = escorts.pop_front()
			events.append(_event(time, escort, path_id, "escort_staggered", true))
			time += 0.18 if escort_run == 0 else 0.16
			escort_run += 1
		if (escort_run >= 2 or escorts.is_empty()) and not frontliners.is_empty():
			events.append(_event(time, frontliners.pop_front(), path_id, "escort_staggered"))
			time += 0.18
			escort_run = 0
	return events

func _gen_tank_support_column(path_id: String, groups: Array, offset: float) -> Array:
	var frontliners := _units_with_role(groups, ROLE_FRONTLINER)
	var supports := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_SUPPORT) and not unit.role_tags.has(ROLE_FRONTLINER))
	var fillers := _units_without_roles(groups, [ROLE_FRONTLINER, ROLE_SUPPORT])
	if frontliners.is_empty():
		return _gen_support_guard(path_id, groups, offset)
	var events := []
	var time := offset
	for i in range(min(2, frontliners.size())):
		events.append(_event(time, frontliners.pop_front(), path_id, "tank_support_column"))
		time += 0.24
	while not frontliners.is_empty() or not supports.is_empty() or not fillers.is_empty():
		if not supports.is_empty():
			events.append(_event(time, supports.pop_front(), path_id, "tank_support_column", true))
			time += 0.22
		if not fillers.is_empty():
			events.append(_event(time, fillers.pop_front(), path_id, "tank_support_column"))
			time += 0.18
		if not frontliners.is_empty():
			events.append(_event(time, frontliners.pop_front(), path_id, "tank_support_column"))
			time += 0.24
	return events

func _gen_armored_cloak_mask(path_id: String, groups: Array, offset: float) -> Array:
	var cloaked := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_DISRUPTOR) and unit.type == "cloaked")
	var visible := _units_matching(groups, func(unit): return unit.type != "cloaked")
	if visible.is_empty():
		return _gen_stealth_probe(path_id, groups, offset)
	var events := []
	var time := offset
	events.append(_event(time, visible.pop_front(), path_id, "armored_cloak_mask"))
	time += 0.18
	while not visible.is_empty() or not cloaked.is_empty():
		if not visible.is_empty():
			events.append(_event(time, visible.pop_front(), path_id, "armored_cloak_mask"))
			time += 0.16
		if not cloaked.is_empty():
			events.append(_event(time, cloaked.pop_front(), path_id, "armored_cloak_mask"))
			time += 0.18
	return events

func _gen_swarm_screen(path_id: String, groups: Array, offset: float) -> Array:
	var anchors := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_FRONTLINER) and not unit.role_tags.has(ROLE_SPLITTER) and not unit.role_tags.has(ROLE_SWARM))
	var swarms := _units_with_role(groups, ROLE_SWARM)
	var payloads := _units_with_role(groups, ROLE_SPLITTER)
	if anchors.is_empty():
		anchors = payloads
	var events := []
	var time := offset
	while not anchors.is_empty() or not swarms.is_empty() or not payloads.is_empty():
		if not anchors.is_empty():
			events.append(_event(time, anchors.pop_front(), path_id, "swarm_screen"))
			time += 0.18
		var burst: int = min(3, swarms.size())
		for i in range(burst):
			events.append(_event(time, swarms.pop_front(), path_id, "swarm_screen"))
			time += 0.10
		if anchors.is_empty() and not payloads.is_empty():
			events.append(_event(time, payloads.pop_front(), path_id, "swarm_screen"))
			time += 0.16
	return events

func _gen_delayed_runner_pressure(path_id: String, groups: Array, offset: float) -> Array:
	var runners := _units_with_role(groups, ROLE_PRESSURE)
	var anchors := _units_without_roles(groups, [ROLE_PRESSURE])
	if anchors.is_empty():
		return _gen_runner_raid(path_id, groups, offset)
	var events := []
	var time := offset
	for i in range(min(3, anchors.size())):
		events.append(_event(time, anchors.pop_front(), path_id, "delayed_runner_pressure"))
		time += 0.18
	time = max(time, offset + 0.55)
	while not runners.is_empty() or not anchors.is_empty():
		var burst: int = min(3, runners.size())
		for i in range(burst):
			events.append(_event(time, runners.pop_front(), path_id, "delayed_runner_pressure"))
			time += 0.12
		if not anchors.is_empty():
			events.append(_event(time, anchors.pop_front(), path_id, "delayed_runner_pressure"))
			time += 0.20
		else:
			time += 0.10
	return events

func _gen_swarm_runner_pressure(path_id: String, groups: Array, offset: float) -> Array:
	var swarms := _units_with_role(groups, ROLE_SWARM)
	var runners := _units_with_role(groups, ROLE_PRESSURE)
	var anchors := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_FRONTLINER) and not unit.role_tags.has(ROLE_SPLITTER))
	var fillers := _units_without_roles(groups, [ROLE_SWARM, ROLE_PRESSURE, ROLE_FRONTLINER])
	var events := []
	var time := offset
	if not anchors.is_empty():
		events.append(_event(time, anchors.pop_front(), path_id, "swarm_screen"))
		time += 0.12
	var runner_started := false
	while not swarms.is_empty() or not runners.is_empty() or not anchors.is_empty() or not fillers.is_empty():
		var swarm_burst := 2 if runner_started else 2
		for i in range(min(swarm_burst, swarms.size())):
			events.append(_event(time, swarms.pop_front(), path_id, "swarm_screen"))
			time += 0.10
		if not runners.is_empty():
			if not runner_started:
				time = max(time, offset + 0.24)
				runner_started = true
			events.append(_event(time, runners.pop_front(), path_id, "delayed_runner_pressure"))
			time += 0.11
		if not anchors.is_empty():
			events.append(_event(time, anchors.pop_front(), path_id, "swarm_screen"))
			time += 0.10
		elif not fillers.is_empty():
			events.append(_event(time, fillers.pop_front(), path_id, "swarm_screen"))
			time += 0.10
	return events

func _gen_shield_wall(path_id: String, groups: Array, offset: float) -> Array:
	return _gen_tank_support_column(path_id, groups, offset)

func _gen_repair_convoy(path_id: String, groups: Array, offset: float) -> Array:
	return _gen_tank_support_column(path_id, groups, offset)

func _gen_frontliner_anchor(path_id: String, groups: Array, offset: float) -> Array:
	return _gen_escort_staggered(path_id, groups, offset)

func _gen_support_guard(path_id: String, groups: Array, offset: float) -> Array:
	var guards := _units_without_roles(groups, [ROLE_SUPPORT])
	var supports := _units_with_role(groups, ROLE_SUPPORT)
	var events := []
	var time := offset
	if guards.is_empty():
		for unit in supports:
			events.append(_event(time, unit, path_id, "support_guard"))
			time += 0.22
		return events
	for i in range(min(2, guards.size())):
		events.append(_event(time, guards.pop_front(), path_id, "support_guard"))
		time += 0.18
	while not supports.is_empty() or not guards.is_empty():
		if not supports.is_empty():
			events.append(_event(time, supports.pop_front(), path_id, "support_guard", true))
			time += 0.20
		if not guards.is_empty():
			events.append(_event(time, guards.pop_front(), path_id, "support_guard"))
			time += 0.18
	return events

func _gen_stealth_probe(path_id: String, groups: Array, offset: float) -> Array:
	var units := _all_units(groups)
	var events := []
	var time := offset
	for unit in units:
		events.append(_event(time, unit, path_id, "stealth_probe"))
		time += 0.24
	return events

func _gen_swarm_burst(path_id: String, groups: Array, offset: float) -> Array:
	var units := _all_units(groups)
	var events := []
	var time := offset
	var emitted := 0
	for unit in units:
		events.append(_event(time, unit, path_id, "swarm_burst"))
		emitted += 1
		time += 0.08
		if emitted % 4 == 0:
			time += 0.20
	return events

func _gen_runner_raid(path_id: String, groups: Array, offset: float) -> Array:
	var units := _all_units(groups)
	var events := []
	var time := offset
	var emitted := 0
	for unit in units:
		events.append(_event(time, unit, path_id, "runner_raid"))
		emitted += 1
		time += 0.11
		if emitted % 3 == 0:
			time += 0.22
	return events

func _gen_heavy_column(path_id: String, groups: Array, offset: float) -> Array:
	var units := _all_units(groups)
	var events := []
	var time := offset
	for unit in units:
		events.append(_event(time, unit, path_id, "heavy_column"))
		time += 0.35
	return events

func _gen_repair_train(path_id: String, groups: Array, offset: float) -> Array:
	var units := _all_units(groups)
	var events := []
	var time := offset
	for unit in units:
		events.append(_event(time, unit, path_id, "repair_train"))
		time += 0.28
	return events

func _gen_air_wing(path_id: String, groups: Array, offset: float) -> Array:
	var air_tanks := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_FRONTLINER))
	var pressure := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_PRESSURE) and not air_tanks.has(unit))
	var supports := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_SUPPORT) and not air_tanks.has(unit) and not pressure.has(unit))
	var escorts := _units_matching(groups, func(unit): return not air_tanks.has(unit) and not pressure.has(unit) and not supports.has(unit))
	var events := []
	var time := offset
	while not air_tanks.is_empty() or not escorts.is_empty() or not pressure.is_empty() or not supports.is_empty():
		if not air_tanks.is_empty():
			events.append(_event(time, air_tanks.pop_front(), path_id, "air_wing"))
			time += 0.16
		if not escorts.is_empty():
			events.append(_event(time, escorts.pop_front(), path_id, "air_wing"))
			time += 0.12
		if not pressure.is_empty():
			events.append(_event(time, pressure.pop_front(), path_id, "air_wing"))
			time += 0.11
		if not supports.is_empty():
			events.append(_event(time, supports.pop_front(), path_id, "air_wing"))
			time += 0.16
	return events

func _gen_baseline_column(path_id: String, groups: Array, offset: float) -> Array:
	var units := _all_units(groups)
	var events := []
	var time := offset
	var emitted := 0
	for unit in units:
		events.append(_event(time, unit, path_id, "baseline_column"))
		emitted += 1
		time += 0.16
		if emitted % 3 == 0:
			time += 0.12
	return events

func _gen_splitter_payload(path_id: String, groups: Array, offset: float) -> Array:
	var splitters := _units_with_role(groups, ROLE_SPLITTER)
	var anchors := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_FRONTLINER) and not unit.role_tags.has(ROLE_SPLITTER))
	var fillers := _units_without_roles(groups, [ROLE_SPLITTER, ROLE_FRONTLINER])
	if anchors.is_empty():
		anchors = fillers
		fillers = []
	var events := []
	var time := offset
	if not anchors.is_empty():
		events.append(_event(time, anchors.pop_front(), path_id, "splitter_payload"))
		time += 0.18
	while not splitters.is_empty() or not anchors.is_empty() or not fillers.is_empty():
		if not fillers.is_empty():
			events.append(_event(time, fillers.pop_front(), path_id, "splitter_payload"))
			time += 0.14
		if not splitters.is_empty():
			events.append(_event(time, splitters.pop_front(), path_id, "splitter_payload"))
			time += 0.22
		if not anchors.is_empty():
			events.append(_event(time, anchors.pop_front(), path_id, "splitter_payload"))
			time += 0.18
	return events

func _gen_mixed_squad(path_id: String, groups: Array, offset: float) -> Array:
	# Evenly distribute different roles
	var units := _all_units(groups)
	var events := []
	var time := offset
	for unit in units:
		events.append(_event(time, unit, path_id, "mixed_squad"))
		time += 0.20
	return events

func _gen_boss_guard(path_id: String, groups: Array, offset: float) -> Array:
	var boss := _units_matching(groups, func(u): return "boss" in u.get("tags", []) or u.type == "boss")
	var guards := _units_matching(groups, func(u): return not boss.has(u))
	var events := []
	var time := offset
	# Guards first
	for i in range(min(4, guards.size())):
		events.append(_event(time, guards.pop_front(), path_id, "boss_guard"))
		time += 0.15
	# Boss in middle
	if not boss.is_empty():
		events.append(_event(time, boss.pop_front(), path_id, "boss_guard"))
		time += 0.40
	# Remaining guards
	for unit in guards:
		events.append(_event(time, unit, path_id, "boss_guard"))
		time += 0.20
	return events

func _gen_wedge(path_id: String, groups: Array, offset: float) -> Array:
	# Lead unit then widening pairs (simplified as staggered for path)
	return _gen_escort_staggered(path_id, groups, offset)

func _build_explicit_formation(f_data: Dictionary, start_offset: float) -> Dictionary:
	var type := str(f_data.get("type", "single_file"))
	var path_id := str(f_data.get("path_id", "default"))
	var groups := _normalize_groups(f_data.get("enemy_groups", []))
	var repeat := int(f_data.get("repeat_count", 1))
	var group_spacing := float(f_data.get("group_spacing", 1.0))
	
	var events := []
	var current_time := start_offset
	
	for r in range(repeat):
		var sub_events: Array = _build_path_formation(path_id, groups, type, current_time).get("generated_events", [])
		events.append_array(sub_events)
		if not sub_events.is_empty():
			var last_event_time = float(sub_events.back().get("time", current_time))
			current_time = last_event_time + group_spacing
		else:
			current_time += group_spacing
			
	# Assign formation indices for the entire explicit formation
	for i in range(events.size()):
		events[i]["formation_index"] = i + 1
		events[i]["formation_total"] = events.size()
		events[i]["formation_id"] = f_data.get("id", "explicit_" + type)
			
	return {
		"id": f_data.get("id", "explicit_" + type),
		"pattern": type,
		"path": path_id,
		"generated_events": events,
		"duration": current_time - start_offset,
		"tactical_note": TACTICAL_NOTES.get(type, "Explicit formation")
	}

func _gen_air_escort(path_id: String, groups: Array, offset: float) -> Array:
	var air_tanks := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_AIR) and unit.role_tags.has(ROLE_FRONTLINER))
	var disruptors := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_DISRUPTOR) or unit.role_tags.has(ROLE_SUPPORT))
	var pressure := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_AIR) and unit.role_tags.has(ROLE_PRESSURE) and not disruptors.has(unit))
	var escorts := _units_matching(groups, func(unit): return unit.role_tags.has(ROLE_AIR) and not air_tanks.has(unit) and not disruptors.has(unit) and not pressure.has(unit))
	var events := []
	var time := offset
	while not air_tanks.is_empty() or not escorts.is_empty() or not pressure.is_empty() or not disruptors.is_empty():
		if not air_tanks.is_empty():
			events.append(_event(time, air_tanks.pop_front(), path_id, "air_escort"))
			time += 0.18
		if not escorts.is_empty():
			events.append(_event(time, escorts.pop_front(), path_id, "air_escort"))
			time += 0.14
		if not pressure.is_empty():
			events.append(_event(time, pressure.pop_front(), path_id, "air_escort"))
			time += 0.13
		if not disruptors.is_empty():
			events.append(_event(time, disruptors.pop_front(), path_id, "air_escort"))
			time += 0.18
	return events

func _event(time: float, group: Dictionary, path_id: String, formation: String, maybe_throttle: bool = false) -> Dictionary:
	var roles: Array = group.get("role_tags", [])
	var tactical_position := _tactical_position_for_roles(roles, formation)
	var event := {
		"time": snappedf(time, 0.01),
		"type": group.get("type", "basic"),
		"path": path_id,
		"reward_gold": int(group.get("reward_gold", 0)),
		"source_group": int(group.get("_original_index", -1)),
		"formation_id": "%s:%s" % [path_id, formation],
		"role_tags": roles,
		"tactical_position": tactical_position,
		"intended_relationship": _intended_relationship(group, formation, tactical_position),
		"tactical_note": TACTICAL_NOTES.get(formation, ""),
		"local_offset": Vector2(randf_range(-12, 12), randf_range(-12, 12)) if formation in ["swarm_pack", "cluster"] else Vector2.ZERO,
		"group_data": group.get("source_group", group).duplicate(true),
		"formation_speed_limit": -1.0,
		"formation_limit_duration": 0.0,
		"formation_speed_multiplier": 1.0,
		"formation_anchor_speed": -1.0,
		"formation_release_rate": 2.5
	}
	event["group_data"]["path"] = path_id
	if maybe_throttle and _needs_early_spacing(group):
		event["formation_speed_limit"] = _formation_speed_limit_for(group)
		event["formation_limit_duration"] = 2.0
		event["formation_speed_multiplier"] = clampf(float(event["formation_speed_limit"]) / max(float(group.get("speed", 100.0)), 1.0), 0.25, 1.0)
	return event

func _apply_formation_preserve_throttles(events: Array, groups: Array, formation: String) -> void:
	if events.is_empty():
		return
	var anchor_speed := _formation_anchor_speed(groups, formation)
	if anchor_speed <= 0.0:
		return
	var preserve_window := _preserve_window_for_formation(formation)
	if preserve_window <= 0.0:
		return
	var first_time := float(events[0].get("time", 0.0))
	for event in events:
		var roles: Array = event.get("role_tags", [])
		if roles.has(ROLE_FRONTLINER):
			continue
		var event_time := float(event.get("time", 0.0))
		if event_time - first_time > preserve_window:
			continue
		var group: Dictionary = event.get("group_data", {})
		var event_speed := _event_base_speed(event, group)
		if event_speed <= anchor_speed:
			continue
		var should_follow_anchor := roles.has(ROLE_ESCORT) or roles.has(ROLE_SUPPORT) or roles.has(ROLE_PRESSURE) or roles.has(ROLE_SWARM)
		if not should_follow_anchor:
			continue
		var relationship := str(event.get("intended_relationship", ""))
		var limit := anchor_speed
		if roles.has(ROLE_PRESSURE) and relationship.contains("delayed pressure"):
			limit = min(event_speed, anchor_speed * 1.18)
		elif roles.has(ROLE_SWARM):
			limit = min(event_speed, anchor_speed * 1.08)
		else:
			limit = min(event_speed, anchor_speed * 1.02)
		event["formation_speed_limit"] = snappedf(limit, 0.01)
		event["formation_limit_duration"] = preserve_window
		event["formation_anchor_speed"] = snappedf(anchor_speed, 0.01)
		event["formation_speed_multiplier"] = snappedf(clampf(limit / max(event_speed, 1.0), 0.25, 1.0), 0.001)
		event["formation_release_rate"] = 2.5

func _formation_anchor_speed(groups: Array, formation: String) -> float:
	if not _formation_uses_anchor(formation):
		return -1.0
	var anchor_speed := INF
	var found := false
	for group in groups:
		var roles: Array = group.get("role_tags", [])
		if roles.has(ROLE_FRONTLINER):
			anchor_speed = min(anchor_speed, float(group.get("speed", 100.0)))
			found = true
	if not found:
		for group in groups:
			var roles: Array = group.get("role_tags", [])
			if roles.has(ROLE_ESCORT) or roles.has(ROLE_AIR):
				anchor_speed = min(anchor_speed, float(group.get("speed", 100.0)))
				found = true
	return anchor_speed if found else -1.0

func _formation_uses_anchor(formation: String) -> bool:
	return formation in [
		"escort_staggered",
		"tank_support_column",
		"repair_convoy",
		"shield_wall",
		"frontliner_anchor",
		"support_guard",
		"armored_cloak_mask",
		"stealth_mask",
		"swarm_screen",
		"splitter_payload",
		"air_escort",
		"air_wing",
		"air_scout_wing",
		"delayed_runner_pressure",
		"swarm_runner_pressure",
		"swarm_runner_flank"
	]

func _preserve_window_for_formation(formation: String) -> float:
	match formation:
		"tank_support_column", "repair_convoy", "shield_wall", "support_guard":
			return 2.4
		"delayed_runner_pressure", "swarm_runner_pressure", "swarm_runner_flank":
			return 1.6
		"air_escort", "air_wing", "air_scout_wing":
			return 1.8
		"swarm_screen":
			return 1.8
		_:
			return 2.0

func _event_base_speed(event: Dictionary, group: Dictionary) -> float:
	if group.has("speed"):
		return float(group.get("speed", 100.0))
	var enemy_type := str(event.get("type", group.get("type", "basic")))
	var cfg: Dictionary = enemies_config.get(enemy_type, {})
	return float(cfg.get("speed", 100.0))

func _tactical_position_for_roles(roles: Array, formation: String) -> String:
	if roles.has(ROLE_DISRUPTOR) and formation in ["armored_cloak_mask", "stealth_mask", "stealth_probe"]:
		return "masked"
	if roles.has(ROLE_SWARM) or roles.has(ROLE_PRESSURE):
		return "burst"
	if roles.has(ROLE_SUPPORT):
		return "rear_middle"
	if roles.has(ROLE_SPLITTER) or roles.has(ROLE_PRIORITY):
		return "priority_payload"
	if roles.has(ROLE_FRONTLINER):
		return "frontline"
	if roles.has(ROLE_ESCORT) or roles.has(ROLE_AIR):
		return "middle"
	return "middle"

func _intended_relationship(group: Dictionary, formation: String, tactical_position: String) -> String:
	var enemy_type := str(group.get("type", "basic"))
	if enemy_type == "basic":
		return "following tank" if formation in ["escort_staggered", "frontliner_anchor"] else "filling formation gaps"
	if enemy_type in ["healer"]:
		return "protected by frontliner"
	if enemy_type in ["shieldbearer"]:
		return "shielding nearby allies"
	if enemy_type in ["cloaked"]:
		return "masked by visible enemies" if formation != "stealth_probe" else "unmasked stealth probe"
	if enemy_type in ["runner", "fast", "fast_flyer"]:
		return "delayed pressure burst"
	if enemy_type == "swarm":
		return "screening burst"
	if enemy_type == "disruptor":
		return "air support protected by escort"
	if enemy_type == "splitter":
		return "middle payload"
	if enemy_type in ["tank", "bulwark", "armored_flyer"]:
		return "anchoring frontline"
	if enemy_type == "hunter":
		return "priority assassin pressure"
	if tactical_position == "middle":
		return "maintaining formation pressure"
	return tactical_position

func _needs_early_spacing(group: Dictionary) -> bool:
	var roles: Array = group.get("role_tags", [])
	return roles.has(ROLE_PRESSURE) or (roles.has(ROLE_ESCORT) and float(group.get("speed", 0.0)) > 90.0)

func _formation_speed_limit_for(group: Dictionary) -> float:
	var speed := float(group.get("speed", 100.0))
	return max(72.0, min(speed, 110.0))

func _normalize_groups(raw_groups: Array) -> Array:
	var out := []
	for i in range(raw_groups.size()):
		if not (raw_groups[i] is Dictionary):
			continue
		var source: Dictionary = raw_groups[i]
		var enemy_type := str(source.get("enemy_type", source.get("type", "basic")))
		var cfg: Dictionary = enemies_config.get(enemy_type, {})
		var roles := infer_enemy_roles(enemy_type, source)
		var normalized := source.duplicate(true)
		normalized["type"] = enemy_type
		normalized["count"] = int(source.get("count", 0))
		normalized["interval"] = float(source.get("interval", source.get("spawn_delay", 1.0)))
		normalized["path"] = str(source.get("path", "default"))
		normalized["reward_gold"] = int(source.get("reward_gold", cfg.get("reward_gold", 0)))
		normalized["speed"] = float(source.get("speed", cfg.get("speed", 100.0)))
		normalized["max_hp"] = float(source.get("max_hp", cfg.get("max_hp", 0.0)))
		normalized["role_tags"] = roles
		normalized["desired_position"] = _desired_position(roles)
		normalized["formation_weight"] = _formation_weight(roles)
		normalized["source_group"] = source.duplicate(true)
		normalized["_original_index"] = int(source.get("_original_index", i))
		out.append(normalized)
	return out

func _units_with_role(groups: Array, role: String) -> Array:
	return _units_matching(groups, func(unit): return unit.role_tags.has(role))

func _all_units(groups: Array) -> Array:
	return _units_matching(groups, func(_unit): return true)

func _units_without_roles(groups: Array, roles: Array) -> Array:
	return _units_matching(groups, func(unit):
		for role in roles:
			if unit.role_tags.has(role):
				return false
		return true
	)

func _units_matching(groups: Array, predicate: Callable) -> Array:
	var units := []
	for group in groups:
		for i in range(int(group.get("count", 0))):
			if predicate.call(group):
				units.append(group)
	return units

func _roles_in_groups(groups: Array) -> Dictionary:
	var roles := {}
	for group in groups:
		for role in group.get("role_tags", []):
			roles[role] = true
	return roles

func _has_type(groups: Array, enemy_type: String) -> bool:
	for group in groups:
		if str(group.get("type", "")) == enemy_type:
			return true
	return false

func _unique_types(groups: Array) -> Array:
	var types := []
	for group in groups:
		var enemy_type := str(group.get("type", ""))
		if enemy_type != "" and not types.has(enemy_type):
			types.append(enemy_type)
	return types

func _groups_by_path(groups: Array) -> Dictionary:
	var path_groups := {}
	for i in range(groups.size()):
		if not (groups[i] is Dictionary):
			continue
		var group: Dictionary = groups[i].duplicate(true)
		group["_original_index"] = i
		var path_id := str(group.get("path", "default"))
		if not path_groups.has(path_id):
			path_groups[path_id] = []
		path_groups[path_id].append(group)
	return path_groups

func _get_wave_groups(wave_data: Dictionary) -> Array:
	if wave_data.has("groups") and wave_data["groups"] is Array:
		return wave_data["groups"]
	if wave_data.has("spawns") and wave_data["spawns"] is Array:
		return wave_data["spawns"]
	if wave_data.has("enemy_type") or wave_data.has("type"):
		return [wave_data]
	return []

func _explicit_formation(wave_data: Dictionary, groups: Array) -> String:
	if str(wave_data.get("formation", "")) != "":
		return str(wave_data.get("formation", ""))
	for group in groups:
		if str(group.get("formation", "")) != "":
			return str(group.get("formation", ""))
	return ""

func _path_offset(path_id: String, index: int, path_count: int, formation: String) -> float:
	if path_count <= 1:
		return 0.0
	if path_id == "default":
		return 0.0
	if formation == "air_escort":
		return 0.50 + 0.20 * float(index)
	return 0.35 + 0.20 * float(max(0, index - 1))

func _count_groups(groups: Array) -> int:
	var total := 0
	for group in groups:
		if group is Dictionary:
			total += int(group.get("count", 0))
	return total

func _estimate_legacy_duration(groups: Array) -> float:
	var max_time := 0.0
	for group in groups:
		if not (group is Dictionary):
			continue
		var start := float(group.get("start_offset", group.get("start_delay", 0.0)))
		var count := int(group.get("count", 0))
		var interval := float(group.get("interval", group.get("spawn_delay", 1.0)))
		if count > 0:
			max_time = max(max_time, start + interval * float(max(0, count - 1)))
	return max_time

func _duration_for_events(events: Array) -> float:
	var duration := 0.0
	for event in events:
		duration = max(duration, float(event.get("time", 0.0)))
	return snappedf(duration, 0.01)

func _apply_metrics(plan: Dictionary) -> void:
	var total := int(plan.get("total_enemy_count", 0))
	var duration: float = max(float(plan.get("total_duration", 0.0)), 0.01)
	plan["density_score"] = snappedf(float(total) / duration, 0.01)
	var role_set := {}
	for formation in plan.get("formations", []):
		for role in formation.get("role_sequence", []):
			role_set[role] = true
	plan["role_diversity_score"] = float(role_set.size())
	plan["support_protection_score"] = _score_protection(plan, ROLE_SUPPORT, ROLE_FRONTLINER)
	plan["cloaked_masking_score"] = _score_cloak_masking(plan)
	plan["runner_timing_score"] = _score_runner_timing(plan)
	plan["air_pressure_score"] = _score_air_pressure(plan)
	plan["synergy_score"] = snappedf((float(role_set.size()) + float(plan.get("support_protection_score", 0.0)) + float(plan.get("runner_timing_score", 0.0))) / 3.0, 0.01)

func _score_protection(plan: Dictionary, protected_role: String, protector_role: String) -> float:
	var score := 1.0
	for event in plan.get("events", []):
		var roles: Array = event.get("role_tags", [])
		if roles.has(protected_role):
			var has_protector := false
			for other in plan.get("events", []):
				if other.get("path", "") == event.get("path", "") and other.get("role_tags", []).has(protector_role) and float(other.get("time", 0.0)) <= float(event.get("time", 0.0)):
					has_protector = true
					break
			if not has_protector:
				score = 0.0
	return score

func _score_cloak_masking(plan: Dictionary) -> float:
	var cloaked_count := 0
	var masked_count := 0
	for event in plan.get("events", []):
		if event.get("type", "") == "cloaked":
			cloaked_count += 1
			for other in plan.get("events", []):
				if other.get("path", "") == event.get("path", "") and other.get("type", "") != "cloaked" and abs(float(other.get("time", 0.0)) - float(event.get("time", 0.0))) <= 0.45 and float(other.get("time", 0.0)) <= float(event.get("time", 0.0)):
					masked_count += 1
					break
	if cloaked_count == 0:
		return 1.0
	return snappedf(float(masked_count) / float(cloaked_count), 0.01)

func _score_runner_timing(plan: Dictionary) -> float:
	var first_anchor := {}
	var first_runner := {}
	for event in plan.get("events", []):
		var path := str(event.get("path", "default"))
		var roles: Array = event.get("role_tags", [])
		if (roles.has(ROLE_FRONTLINER) or roles.has(ROLE_ESCORT) or roles.has(ROLE_SWARM)) and not first_anchor.has(path):
			first_anchor[path] = float(event.get("time", 0.0))
		if roles.has(ROLE_PRESSURE) and not first_runner.has(path):
			first_runner[path] = float(event.get("time", 0.0))
	var score := 1.0
	for path in first_runner.keys():
		if _path_uses_formation(plan, path, "runner_raid"):
			continue
		if not first_anchor.has(path) or float(first_runner[path]) - float(first_anchor[path]) < 0.20:
			score = 0.0
	return score

func _path_uses_formation(plan: Dictionary, path: String, formation_name: String) -> bool:
	for formation in plan.get("formations", []):
		if str(formation.get("path", "")) == path and str(formation.get("pattern", "")) == formation_name:
			return true
	return false

func _score_air_pressure(plan: Dictionary) -> float:
	for event in plan.get("events", []):
		if event.get("role_tags", []).has(ROLE_AIR):
			return 1.0
	return 0.0

func _validate_plan(plan: Dictionary) -> Array:
	var warnings: Array = []
	var legacy := float(plan.get("legacy_duration", 0.0))
	var duration := float(plan.get("total_duration", 0.0))
	var roleless_event_count := 0
	var unpositioned_event_count := 0
	var independent_detected := false
	var formations_used := []
	var tactical_sequence := []
	if legacy > 0.0 and duration > legacy * 1.15:
		warnings.append("total duration increased too much: %.2fs -> %.2fs" % [legacy, duration])
	var path_firsts := {}
	var type_by_path := {}
	for event in plan.get("events", []):
		var path := str(event.get("path", "default"))
		var formation_id := str(event.get("formation_id", ""))
		if formation_id == "":
			roleless_event_count += 1
		if formation_id.contains("independent"):
			independent_detected = true
		if str(event.get("tactical_position", "")) == "":
			unpositioned_event_count += 1
		var formation_name := formation_id.get_slice(":", 1) if formation_id.contains(":") else formation_id
		if formation_name != "" and not formations_used.has(formation_name):
			formations_used.append(formation_name)
		tactical_sequence.append("%s@%.2f:%s/%s" % [
			str(event.get("type", "")),
			float(event.get("time", 0.0)),
			str(event.get("tactical_position", "")),
			str(event.get("intended_relationship", ""))
		])
		if not path_firsts.has(path):
			path_firsts[path] = event
		if not type_by_path.has(path):
			type_by_path[path] = {}
		type_by_path[path][event.get("type", "")] = true
	for path in path_firsts.keys():
		var roles: Array = path_firsts[path].get("role_tags", [])
		var first_formation := str(path_firsts[path].get("formation_id", ""))
		if roles.has(ROLE_SUPPORT) and not roles.has(ROLE_FRONTLINER) and not first_formation.contains("repair_train"):
			warnings.append("support spawned first on %s" % path)
		if path_firsts[path].get("type", "") == "cloaked":
			warnings.append("cloaked isolated as first unit on %s" % path)
		if roles.has(ROLE_PRESSURE) and plan.get("events", []).size() > 1 and not first_formation.contains("runner_raid"):
			warnings.append("runner starts too early on %s" % path)
		if type_by_path[path].keys().size() == 1 and int(plan.get("wave_id", 1)) > 2:
			warnings.append("wave is single-type after tutorial on %s" % path)
	if _score_cloak_masking(plan) < 1.0:
		warnings.append("cloaked isolated from visible masking window")
	if _score_protection(plan, ROLE_SUPPORT, ROLE_FRONTLINER) < 1.0:
		warnings.append("support spawned before protected frontliner")
	if _score_runner_timing(plan) < 1.0:
		warnings.append("runner starts too early")
	if roleless_event_count > 0:
		warnings.append("roleless event count: %d" % roleless_event_count)
	if unpositioned_event_count > 0:
		warnings.append("unpositioned event count: %d" % unpositioned_event_count)
	if independent_detected:
		warnings.append("Independent group spawn detected. This violates formation rules.")
	var original_count := int(plan.get("total_enemy_count", 0))
	var generated_count := int(plan.get("events", []).size())
	if original_count != generated_count:
		warnings.append("total enemy count changed unexpectedly: %d -> %d" % [original_count, generated_count])
	plan["validation_result"] = {
		"ok": roleless_event_count == 0 and unpositioned_event_count == 0 and not independent_detected and original_count == generated_count,
		"all_spawn_events_have_formation": roleless_event_count == 0,
		"roleless_event_count": roleless_event_count,
		"unpositioned_event_count": unpositioned_event_count,
		"independent_group_spawn_detected": independent_detected,
		"formations_used": formations_used,
		"path_formations": _path_formations(plan),
		"tactical_sequence": tactical_sequence,
		"warnings": warnings.duplicate()
	}
	return warnings

func _repair_invalid_plan(plan: Dictionary) -> void:
	var validation: Dictionary = plan.get("validation_result", {})
	var count_ok := int(plan.get("total_enemy_count", 0)) == int(plan.get("events", []).size())
	if bool(validation.get("ok", false)) and count_ok:
		plan["warnings"].append("All enemy groups converted into role-aware formations.")
		return
	_repair_missing_events(plan)
	for event in plan.get("events", []):
		if str(event.get("formation_id", "")) == "" or str(event.get("formation_id", "")).contains("independent"):
			var path := str(event.get("path", "default"))
			event["formation_id"] = "%s:baseline_column" % path
			event["tactical_note"] = TACTICAL_NOTES.get("baseline_column", "")
		if str(event.get("tactical_position", "")) == "":
			event["tactical_position"] = _tactical_position_for_roles(event.get("role_tags", []), str(event.get("formation_id", "")))
		if str(event.get("intended_relationship", "")) == "":
			event["intended_relationship"] = "maintaining formation pressure"
	plan["events"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	plan["total_duration"] = _duration_for_events(plan["events"])
	plan["generated_spawn_events"] = plan["events"]
	_validate_plan(plan)

func _repair_missing_events(plan: Dictionary) -> void:
	var actual_by_source := {}
	for event in plan.get("events", []):
		var key := "%s:%d" % [str(event.get("path", "default")), int(event.get("source_group", -1))]
		actual_by_source[key] = int(actual_by_source.get(key, 0)) + 1
	var last_time := _duration_for_events(plan.get("events", []))
	for formation in plan.get("formations", []):
		var path := str(formation.get("path", "default"))
		var pattern := str(formation.get("pattern", "baseline_column"))
		for group in formation.get("groups", []):
			var key := "%s:%d" % [path, int(group.get("_original_index", -1))]
			var expected := int(group.get("count", 0))
			var actual := int(actual_by_source.get(key, 0))
			while actual < expected:
				last_time += 0.08
				plan["events"].append(_event(last_time, group, path, pattern))
				actual += 1
				actual_by_source[key] = actual
				if not plan["warnings"].has("auto-repaired missing formation events"):
					plan["warnings"].append("auto-repaired missing formation events")

func _path_formations(plan: Dictionary) -> Dictionary:
	var out := {}
	for formation in plan.get("formations", []):
		out[str(formation.get("path", "default"))] = str(formation.get("pattern", "baseline_column"))
	return out

func _desired_position(roles: Array) -> String:
	for role in [ROLE_FRONTLINER, ROLE_SUPPORT, ROLE_PRESSURE, ROLE_SWARM, ROLE_DISRUPTOR, ROLE_AIR, ROLE_SPLITTER, ROLE_ESCORT]:
		if roles.has(role):
			return ROLE_POSITION.get(role, "middle")
	return "middle"

func _formation_weight(roles: Array) -> float:
	var weight := 1.0
	if roles.has(ROLE_FRONTLINER): weight += 1.5
	if roles.has(ROLE_SUPPORT): weight += 1.0
	if roles.has(ROLE_PRESSURE): weight += 0.8
	if roles.has(ROLE_PRIORITY): weight += 1.0
	return weight

func _rules_for_formation(formation: String) -> Array:
	match formation:
		"escort_staggered":
			return ["frontliner_first", "escort_spacing", "preserve_formation_window"]
		"tank_support_column", "repair_convoy", "shield_wall":
			return ["support_never_first", "frontliner_before_support", "aura_overlap"]
		"armored_cloak_mask":
			return ["visible_before_cloak", "nearby_visible_mask"]
		"swarm_screen":
			return ["short_bursts", "anchor_density"]
		"delayed_runner_pressure":
			return ["runner_delayed", "burst_pressure"]
		"splitter_payload":
			return ["splitter_middle", "anchor_before_payload"]
		"air_escort":
			return ["air_tank_leads", "disruptor_protected"]
		"frontliner_anchor":
			return ["frontliner_leads", "roles_arranged_behind_anchor"]
		"support_guard", "repair_train":
			return ["support_has_guard_when_available", "support_delay"]
		"stealth_mask", "stealth_probe":
			return ["stealth_has_mask_when_available", "explicit_stealth_probe_warning"]
		"delayed_pressure", "runner_raid":
			return ["burst_pressure", "recovery_gaps"]
		"swarm_burst", "swarm_pack":
			return ["clustered_bursts", "high_density"]
		"air_wing", "air_scout_wing":
			return ["air_role_ordering", "wing_timing"]
		"payload":
			return ["payload_middle", "delayed_child_threat"]
		"baseline_column":
			return ["readable_clusters", "steady_pressure"]
		_:
			return ["fallback_tactical_structure"]

func _add_role(roles: Array[String], role: String) -> void:
	if not roles.has(role):
		roles.append(role)

func _has_any(values: Array, candidates: Array) -> bool:
	for candidate in candidates:
		if values.has(candidate):
			return true
	return false
