extends SceneTree

const LEVEL_MANAGER_SCRIPT := preload("res://scripts/managers/level_manager.gd")
const BUILD_MANAGER_SCRIPT := preload("res://scripts/managers/build_manager.gd")
const BUILDABLE_GRID_GENERATOR := preload("res://scripts/managers/buildable_grid_generator.gd")

func _init() -> void:
	var ok := true
	var towers := _load_json("res://data/towers.json")
	var enemies := _load_json("res://data/enemies.json")
	var sniper_range := _sniper_range(towers)
	var disruptor_radius := float(enemies.get("disruptor", {}).get("skill_params", {}).get("radius", 150.0))
	for i in range(1, 21):
		var path := "res://data/levels/level_%02d.json" % i
		var data := _load_json(path)
		var lm = LEVEL_MANAGER_SCRIPT.new()
		get_root().add_child(lm)
		var loaded := lm.load_level(path)
		ok = _expect(loaded, "%s loads" % path) and ok
		if not loaded:
			lm.free()
			continue
		ok = _expect(lm.buildable_mode == "full_non_path", "%s defaults to full_non_path" % lm.level_id) and ok
		var generated := BUILDABLE_GRID_GENERATOR.generate_full_non_path_buildable_grid(data)
		ok = _expect(generated.size() == lm.buildable_cells.size(), "%s runtime buildable count matches generator" % lm.level_id) and ok
		for cell in BUILDABLE_GRID_GENERATOR.unique_path_cells(data):
			ok = _expect(not lm.can_build_at_cell(cell), "%s path cell blocked %s" % [lm.level_id, str(cell)]) and ok
		for cell in BUILDABLE_GRID_GENERATOR.spawn_cells(data):
			ok = _expect(not lm.can_build_at_cell(cell), "%s spawn cell blocked %s" % [lm.level_id, str(cell)]) and ok
		for cell in BUILDABLE_GRID_GENERATOR.base_cells(data):
			ok = _expect(not lm.can_build_at_cell(cell), "%s base cell blocked %s" % [lm.level_id, str(cell)]) and ok
		var bm = BUILD_MANAGER_SCRIPT.new()
		get_root().add_child(bm)
		bm.configure_from_level(lm)
		var mismatch := 0
		for cell in generated:
			if not bm.can_build_at_cell(cell):
				mismatch += 1
		ok = _expect(mismatch == 0, "%s preview/runtime can_build mismatch=%d" % [lm.level_id, mismatch]) and ok
		var counterplay := BUILDABLE_GRID_GENERATOR.validate_disruptor_counterplay(data, sniper_range, disruptor_radius)
		ok = _expect(bool(counterplay.get("pass", false)), "%s disruptor safe sniper cells=%d" % [lm.level_id, int(counterplay.get("valid_safe_sniper_cells_count", 0))]) and ok
		bm.free()
		lm.free()
	if ok:
		print("[TEST][PASS] Full non-path buildable validation passed.")
		quit(0)
	else:
		push_error("[TEST][FAIL] Full non-path buildable validation failed.")
		quit(1)

func _expect(condition: bool, message: String) -> bool:
	print("[%s] %s" % ["PASS" if condition else "FAIL", message])
	return condition

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}

func _sniper_range(towers: Dictionary) -> float:
	var sniper: Dictionary = towers.get("sniper_tower", {})
	if sniper.has("levels") and sniper["levels"] is Array and not sniper["levels"].is_empty():
		return float(sniper["levels"][0].get("range", 0.0))
	return float(sniper.get("range", 0.0))
