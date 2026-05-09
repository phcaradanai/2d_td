extends SceneTree

const PLANNER_SCRIPT = preload("res://scripts/managers/spawn_formation_planner.gd")

func _init() -> void:
	var enemies: Dictionary = _load_json("res://data/enemies.json")
	var planner = PLANNER_SCRIPT.new(enemies)
	var ok := true
	for level_num in range(1, 21):
		var path := "res://data/waves/waves_%02d.json" % level_num
		if not FileAccess.file_exists(path):
			continue
		var waves: Array = _load_json(path)
		for i in range(waves.size()):
			var wave: Dictionary = waves[i]
			var plan: Dictionary = planner.build_plan(wave, i)
			var expected := _wave_count(wave)
			var events: Array = plan.get("events", [])
			var validation: Dictionary = plan.get("validation_result", {})
			ok = _expect(events.size() == expected, "%s wave %d count expected=%d actual=%d" % [path, i + 1, expected, events.size()]) and ok
			ok = _expect(bool(validation.get("all_spawn_events_have_formation", false)), "%s wave %d all events have formation" % [path, i + 1]) and ok
			ok = _expect(not bool(validation.get("independent_group_spawn_detected", true)), "%s wave %d no independent spawn" % [path, i + 1]) and ok
			ok = _expect(_all_events_positioned(events), "%s wave %d all events positioned" % [path, i + 1]) and ok
			ok = _expect(not plan.get("formations", []).is_empty(), "%s wave %d has path formation" % [path, i + 1]) and ok
	print("[FORMATION_COVERAGE_TEST] ok=%s" % str(ok))
	quit(0 if ok else 1)

func _load_json(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func _wave_count(wave: Dictionary) -> int:
	var total := 0
	for group in wave.get("groups", []):
		if group is Dictionary:
			total += int(group.get("count", 0))
	return total

func _all_events_positioned(events: Array) -> bool:
	for event in events:
		if str(event.get("tactical_position", "")) == "":
			return false
		if str(event.get("intended_relationship", "")) == "":
			return false
	return true

func _expect(condition: bool, label: String) -> bool:
	if condition:
		print("[PASS] " + label)
	else:
		push_error("[FAIL] " + label)
	return condition
