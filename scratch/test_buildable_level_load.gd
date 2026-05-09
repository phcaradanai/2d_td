extends SceneTree

const LEVEL_MANAGER_SCRIPT := preload("res://scripts/managers/level_manager.gd")
const BUILDABLE_RING_GENERATOR_SCRIPT := preload("res://scripts/debug/buildable_ring_generator.gd")

var failed := false

func _init() -> void:
	var root := Node.new()
	get_root().add_child(root)
	current_scene = root
	var generator = BUILDABLE_RING_GENERATOR_SCRIPT.new()
	for i in range(1, 21):
		var level_path := "res://data/levels/level_%02d.json" % i
		var level_manager = LEVEL_MANAGER_SCRIPT.new()
		root.add_child(level_manager)
		var loaded: bool = level_manager.load_level(level_path)
		_assert_true("%s loads" % level_path, loaded)
		if loaded:
			var config: Dictionary = _load_json(level_path)
			var report: Dictionary = generator.analyze_level(config)
			_assert_true("%s buildable coverage passes" % level_manager.level_id, bool(report.get("pass", false)))
			_assert_true("%s path cells are unbuildable" % level_manager.level_id, _no_overlap(level_manager.buildable_cells, _all_path_cells(level_manager)))
			_assert_true("%s spawn cells are unbuildable" % level_manager.level_id, _no_overlap(level_manager.buildable_cells, _spawn_cells(config)))
			_assert_true("%s base cells are unbuildable" % level_manager.level_id, _no_overlap(level_manager.buildable_cells, _base_cells(config)))
			_assert_true("%s blocked cells are unbuildable" % level_manager.level_id, _no_overlap(level_manager.buildable_cells, level_manager.blocked_cells + level_manager.decorative_blocked_cells))
		level_manager.queue_free()
	if failed:
		print("[TEST][FAIL] Buildable level load checks failed.")
		quit(1)
	else:
		print("[TEST][PASS] Buildable level load checks passed.")
		quit(0)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}

func _all_path_cells(level_manager: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for path_name in level_manager.multi_paths.keys():
		for cell in level_manager.multi_paths[path_name]:
			if not cells.has(cell):
				cells.append(cell)
	return cells

func _spawn_cells(config: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if config.has("spawn_cell"):
		var s: Array = config.get("spawn_cell", [])
		if s.size() >= 2:
			cells.append(Vector2i(int(s[0]), int(s[1])))
	for raw in config.get("spawn_cells", []):
		if raw is Array and raw.size() >= 2:
			var cell := Vector2i(int(raw[0]), int(raw[1]))
			if not cells.has(cell):
				cells.append(cell)
	return cells

func _base_cells(config: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if config.has("base_cell"):
		var b: Array = config.get("base_cell", [])
		if b.size() >= 2:
			cells.append(Vector2i(int(b[0]), int(b[1])))
	return cells

func _no_overlap(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	for cell in a:
		if b.has(cell):
			return false
	return true

func _assert_true(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		failed = true
		push_error("[FAIL] %s" % label)
