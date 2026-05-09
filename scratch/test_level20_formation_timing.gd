extends SceneTree

const PLANNER_SCRIPT = preload("res://scripts/managers/spawn_formation_planner.gd")

func _init() -> void:
	var enemies = _load_json("res://data/enemies.json")
	var waves = _load_json("res://data/waves/waves_20.json")
	var planner = PLANNER_SCRIPT.new(enemies)
	var wave: Dictionary = waves[0]
	var plan: Dictionary = planner.build_plan(wave, 0)
	var events: Array = plan.get("events", [])
	var ok := true
	
	ok = _expect(events.size() == 26, "level_20 wave_1 enemy count remains 26") and ok
	ok = _expect(_first_on_path(events, "default").get("type", "") == "tank", "default path starts with tank") and ok
	ok = _expect(float(_first_on_path(events, "lane_b").get("time", 0.0)) >= 0.30, "lane_b uses readable flank offset") and ok
	ok = _expect(_first_time(events, "lane_b", "runner") > _first_time(events, "lane_b", "swarm"), "runners arrive after flank pressure starts") and ok
	var legacy := float(plan.get("legacy_duration", 0.0))
	var duration := float(plan.get("total_duration", 0.0))
	ok = _expect(duration <= legacy * 1.15 + 0.001, "formation duration stays within 15 percent of legacy")
	ok = _expect(_has_formation(plan, "escort_staggered", "default"), "default path uses escort_staggered") and ok
	ok = _expect(_has_formation(plan, "swarm_runner_flank", "lane_b"), "lane_b combines swarm screen and runner pressure") and ok
	ok = _expect(_all_events_have_formation_coverage(events), "all spawn events have formation coverage metadata") and ok
	ok = _expect(not bool(plan.get("validation_result", {}).get("independent_group_spawn_detected", true)), "no independent group spawn detected") and ok
	
	print("[FORMATION_TEST] wave=%s events=%d legacy=%.2f duration=%.2f density=%.2f ok=%s" % [
		str(plan.get("wave_id", "")),
		events.size(),
		legacy,
		duration,
		float(plan.get("density_score", 0.0)),
		str(ok)
	])
	for event in events:
		print("t=%.2f path=%s type=%s formation=%s note=%s" % [
			float(event.get("time", 0.0)),
			str(event.get("path", "")),
			str(event.get("type", "")),
			str(event.get("formation_id", "")),
			str(event.get("tactical_note", ""))
		])
	quit(0 if ok else 1)

func _load_json(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func _expect(condition: bool, label: String) -> bool:
	if condition:
		print("[PASS] " + label)
	else:
		push_error("[FAIL] " + label)
	return condition

func _first_on_path(events: Array, path_id: String) -> Dictionary:
	for event in events:
		if str(event.get("path", "")) == path_id:
			return event
	return {}

func _first_time(events: Array, path_id: String, enemy_type: String) -> float:
	for event in events:
		if str(event.get("path", "")) == path_id and str(event.get("type", "")) == enemy_type:
			return float(event.get("time", 999.0))
	return 999.0

func _has_formation(plan: Dictionary, formation: String, path_id: String) -> bool:
	for item in plan.get("formations", []):
		if str(item.get("path", "")) == path_id and str(item.get("pattern", "")) == formation:
			return true
	return false

func _all_events_have_formation_coverage(events: Array) -> bool:
	for event in events:
		if str(event.get("formation_id", "")) == "":
			return false
		if str(event.get("formation_id", "")).contains("independent"):
			return false
		if str(event.get("tactical_position", "")) == "":
			return false
		if str(event.get("intended_relationship", "")) == "":
			return false
	return true
