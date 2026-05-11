extends Node

signal tower_selected(tower_id: String)
signal tower_selection_cleared()
signal tower_placed(tower: Node2D, tower_id: String, cost: int)
signal placement_failed(reason: String)
signal hover_cell_changed(cell: Vector2i, is_valid: bool, reason: String)

@export var grid_size: int = 64
@export var grid_cols: int = 20
@export var grid_rows: int = 12
@export var grid_origin: Vector2 = Vector2.ZERO

@export var tower_scene: PackedScene = preload("res://scenes/towers/Tower.tscn")
@export var towers_data_path: String = "res://data/towers.json"
@export var towers_tree_data_path: String = "res://data/towers_tree.json"

var towers_config: Dictionary = {}
var towers_tree_config: Dictionary = {}
var selected_tower_id: String = ""
var occupied_cells: Dictionary = {} # cell: bool
var tower_by_cell: Dictionary = {} # cell_key: tower
var blocked_cells: Array[Vector2i] = [] # path cells + blocked level cells
var active_loadout: Array[String] = []
var unlocked_tower_ids: Array[String] = ["basic_tower_t1"]

var game_manager: Node
var level_manager: Node
var pathfinding_manager: Node
var use_path_blocking_validation: bool = true
var tower_container: Node2D
var projectile_container: Node2D

const LANE_WIDTH: float = 64.0
const PLACEMENT_PADDING: float = 4.0
const DEFAULT_FOOTPRINT_RADIUS: float = 20.0

func setup(p_game_manager: Node, p_tower_container: Node2D, p_projectile_container: Node2D) -> void:
	game_manager = p_game_manager
	tower_container = p_tower_container
	projectile_container = p_projectile_container
	load_towers_config()

func configure_from_level(p_level_manager: Node) -> void:
	level_manager = p_level_manager
	grid_size = level_manager.grid_size
	grid_cols = level_manager.grid_cols
	grid_rows = level_manager.grid_rows
	grid_origin = level_manager.grid_origin
	blocked_cells = level_manager.get_all_blocked_cells()
	use_path_blocking_validation = true
	var raw_data = level_manager.get("level_data")
	if raw_data is Dictionary:
		var mode := str(raw_data.get("enemy_pathing_mode", raw_data.get("pathing_mode", "dynamic_maze"))).strip_edges().to_lower()
		if mode in ["fixed", "fixed_path", "fixed-path", "element_td", "elemental_td"]:
			use_path_blocking_validation = false

func set_pathfinding_manager(p_pathfinding_manager: Node) -> void:
	pathfinding_manager = p_pathfinding_manager

func load_towers_config() -> void:
	# Load legacy towers config
	# if FileAccess.file_exists(towers_data_path):
	# 	var file = FileAccess.open(towers_data_path, FileAccess.READ)
	# 	var json_text = file.get_as_text()
	# 	file.close()
		
	# 	var json = JSON.new()
	# 	var error = json.parse(json_text)
	# 	if error == OK:
	# 		towers_config = json.data
	# 		if OS.is_debug_build(): print("Loaded ", towers_config.size(), " tower types (legacy).")

	# Load tower tree config (new progression system)
	if FileAccess.file_exists(towers_tree_data_path):
		var file2 = FileAccess.open(towers_tree_data_path, FileAccess.READ)
		var json_text2 = file2.get_as_text()
		file2.close()
		
		var json2 = JSON.new()
		var error2 = json2.parse(json_text2)
		if error2 == OK:
			towers_tree_config = json2.data
			# Merge into towers_config so place_tower can find all configs
			for key in towers_tree_config:
				towers_config[key] = towers_tree_config[key]
			if OS.is_debug_build(): print("Loaded tower tree: ", towers_tree_config.size(), " entries.")

func reset_build_state() -> void:
	selected_tower_id = ""
	occupied_cells.clear()
	tower_by_cell.clear()
	tower_selection_cleared.emit()

func mark_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells = cells

func set_selected_tower(tower_id: String) -> void:
	selected_tower_id = tower_id
	if selected_tower_id != "":
		tower_selected.emit(selected_tower_id)
	else:
		tower_selection_cleared.emit()

func clear_selected_tower() -> void:
	set_selected_tower("")

func set_unlocked_tower_ids(ids: Array[String]) -> void:
	unlocked_tower_ids = ids.duplicate()
	active_loadout = ids.duplicate()

func is_tower_unlocked(tower_id: String) -> bool:
	if unlocked_tower_ids.is_empty():
		return tower_id == "basic_tower_t1"
	return unlocked_tower_ids.has(tower_id)

func has_selected_tower() -> bool:
	return selected_tower_id != ""

func is_build_mode_active() -> bool:
	return has_selected_tower()

func get_selected_tower_config() -> Dictionary:
	return towers_config.get(selected_tower_id, {})

func get_selected_tower_range() -> float:
	var config = get_selected_tower_config()
	if config.has("levels") and config["levels"].size() > 0:
		return config["levels"][0].get("range", 0.0)
	return 0.0

func get_selected_tower_footprint() -> float:
	var config = get_selected_tower_config()
	return config.get("footprint_radius", DEFAULT_FOOTPRINT_RADIUS)

func update_hover(local_pos: Vector2) -> void:
	if not has_selected_tower(): return
	
	var cell = local_to_cell(local_pos)
	var validation = validate_placement(cell)
	hover_cell_changed.emit(cell, validation["is_valid"], validation["reason"])

func try_place_tower(local_pos: Vector2) -> bool:
	if not has_selected_tower(): return false
	
	var cell = local_to_cell(local_pos)
	var validation = validate_placement(cell)
	
	if not validation["is_valid"]:
		if OS.is_debug_build(): print("[BuildFlow] place failed reason=%s" % validation["reason"])
		placement_failed.emit(validation["reason"])
		return false
	
	if game_manager.spend_gold(validation["cost"]):
		if OS.is_debug_build(): print("[BuildFlow] placed tower=%s pos=%s cost=%d" % [selected_tower_id, cell, validation["cost"]])
		place_tower(cell, validation["config"])
		return true
	
	if OS.is_debug_build(): print("[BuildFlow] place failed: Not enough gold! (needed %d)" % validation["cost"])
	placement_failed.emit("Not enough gold!")
	return false

func validate_placement(cell: Vector2i) -> Dictionary:
	var config = get_selected_tower_config()
	if config.is_empty():
		return {"is_valid": false, "reason": "Tower config missing", "cost": 0}
	var cost = config.get("cost", 0)

	# Elemental TD mode: direct build options are filtered by unlocked element
	# combinations. Upgrades are handled separately by Main/Tower.
	if not is_tower_unlocked(selected_tower_id):
		return {"is_valid": false, "reason": "Tower is not unlocked by current elements", "cost": cost}

	if not is_in_bounds(cell):
		return {"is_valid": false, "reason": "Cannot build outside map", "cost": cost}
	
	# Occupancy Check
	if occupied_cells.has(cell):
		return {"is_valid": false, "reason": "Cannot build on existing tower", "cost": cost}
		
	if use_path_blocking_validation and pathfinding_manager and pathfinding_manager.has_method("get_blocker_validation_reason"):
		var path_reason := str(pathfinding_manager.get_blocker_validation_reason(cell, _get_tower_footprint_cells(cell, config), true))
		if path_reason != "":
			return {"is_valid": false, "reason": path_reason, "cost": cost}

	var build_reason := get_build_block_reason(cell)
	if build_reason != "":
		return {"is_valid": false, "reason": _format_build_reason(build_reason), "cost": cost}
	
	return {"is_valid": true, "reason": "Valid", "cost": cost, "config": config}


func place_tower(cell: Vector2i, config: Dictionary) -> void:
	var tower = tower_scene.instantiate()
	tower_container.add_child(tower)
	tower.add_to_group("towers")
	tower.add_to_group("placed_towers")
	# Set LOCAL position relative to TowerContainer
	tower.position = cell_to_local_center(cell)
	
	if OS.is_debug_build(): print("[Build] Placed tower at cell=", cell, " local=", tower.position, " global=", tower.global_position)
	
	tower.setup(config, cell)
	tower.set_projectile_container(projectile_container)
	
	for footprint_cell in _get_tower_footprint_cells(cell, config):
		occupied_cells[footprint_cell] = true
		tower_by_cell[_cell_key(footprint_cell)] = tower
	if use_path_blocking_validation and pathfinding_manager and pathfinding_manager.has_method("set_tower_blocked"):
		pathfinding_manager.set_tower_blocked(cell, true, _get_tower_footprint_cells(cell, config))
	tower_placed.emit(tower, selected_tower_id, config.get("cost", 0))
	
	if game_manager and "battle_telemetry" in game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_tower_built(selected_tower_id, cell, tower.position, config.get("cost", 0))
	
	# After placing, clear selection
	clear_selected_tower()

func local_to_cell(local_pos: Vector2) -> Vector2i:
	var p := local_pos - grid_origin
	return Vector2i(floor(p.x / grid_size), floor(p.y / grid_size))

func cell_to_local_center(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x * grid_size + grid_size/2, cell.y * grid_size + grid_size/2)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_cols and cell.y >= 0 and cell.y < grid_rows

func can_build_at_cell(cell: Vector2i) -> bool:
	return validate_placement(cell)["is_valid"]

func get_build_block_reason(cell: Vector2i) -> String:
	if not is_in_bounds(cell):
		return "out_of_bounds"
	if level_manager and level_manager.has_method("get_build_block_reason"):
		var reason := str(level_manager.get_build_block_reason(cell))
		if reason != "":
			return reason
	elif cell in blocked_cells:
		return "blocked"
	return ""

func _format_build_reason(reason: String) -> String:
	match reason:
		"out_of_bounds":
			return "Cannot build outside map"
		"path":
			return "Cannot block enemy path"
		"spawn":
			return "Cannot build on spawn point"
		"base":
			return "Cannot build on base point"
		"non_buildable":
			return "Tile is not buildable"
		"occupied":
			return "Cannot build on existing tower"
		_:
			return reason

func can_place_at(cell: Vector2i) -> bool:
	return validate_placement(cell)["is_valid"]

func _get_tower_footprint_cells(cell: Vector2i, config: Dictionary) -> Array[Vector2i]:
	var footprint_cells: Array[Vector2i] = []
	var raw = config.get("footprint_cells", [])
	if raw is Array and not raw.is_empty():
		for item in raw:
			if item is Vector2i:
				footprint_cells.append(item)
			elif item is Array and item.size() >= 2:
				footprint_cells.append(cell + Vector2i(int(item[0]), int(item[1])))
	if footprint_cells.is_empty():
		footprint_cells.append(cell)
	return footprint_cells


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func get_tower_at_cell(cell: Vector2i) -> Node:
	return tower_by_cell.get(_cell_key(cell), null)


func remove_tower_at_cell(cell: Vector2i) -> bool:
	var footprint_cells: Array[Vector2i] = []
	
	# Find the tower at this cell and determine its full footprint
	var key := _cell_key(cell)
	var tower: Node = tower_by_cell.get(key, null)
	if tower == null:
		return false
	
	if tower.has_method("get_grid_cell"):
		var tower_cell: Vector2i = tower.get_grid_cell()
		# Gather all footprint cells from tower_by_cell that point to this tower
		for k in tower_by_cell.keys():
			if tower_by_cell[k] == tower:
				footprint_cells.append(_parse_cell_key(k))
	
	if footprint_cells.is_empty():
		footprint_cells.append(cell)
	
	# Remove from occupancy and tower map
	for fc in footprint_cells:
		occupied_cells.erase(fc)
		tower_by_cell.erase(_cell_key(fc))
	
	# Clear pathfinding blocker
	if use_path_blocking_validation and pathfinding_manager and pathfinding_manager.has_method("set_tower_blocked"):
		pathfinding_manager.set_tower_blocked(tower.get_grid_cell() if tower.has_method("get_grid_cell") else cell, false, footprint_cells)
	
	# Remove the tower node
	if tower is Node and is_instance_valid(tower):
		tower.queue_free()
	
	return true


func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)


func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",", false, 1)
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO
