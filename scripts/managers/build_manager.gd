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

var towers_config: Dictionary = {}
var selected_tower_id: String = ""
var occupied_cells: Dictionary = {} # cell: bool
var blocked_cells: Array[Vector2i] = [] # path cells + blocked level cells
var active_loadout: Array[String] = []

var game_manager: Node
var level_manager: Node
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

func load_towers_config() -> void:
	if not FileAccess.file_exists(towers_data_path):
		push_error("Towers config file not found: " + towers_data_path)
		return
	
	var file = FileAccess.open(towers_data_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		towers_config = json.data
		if OS.is_debug_build(): print("Loaded ", towers_config.size(), " tower types.")

func reset_build_state() -> void:
	selected_tower_id = ""
	occupied_cells.clear()
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
	var cost = config.get("cost", 0)
	var footprint = config.get("footprint_radius", DEFAULT_FOOTPRINT_RADIUS)
	var range_val = get_selected_tower_range()
	
	if not active_loadout.is_empty() and not active_loadout.has(selected_tower_id):
		return {"is_valid": false, "reason": "Not in loadout", "cost": cost}
	
	if not is_in_bounds(cell):
		return {"is_valid": false, "reason": "Out of bounds", "cost": cost}
	
	# 1. Tile-based blocked check (for restricted build zones/buildable_cells)
	if cell in blocked_cells:
		# If we have restricted build zones, this might be intentional blocking
		if level_manager and not level_manager.buildable_cells.is_empty():
			return {"is_valid": false, "reason": "Restricted zone", "cost": cost}
		# If no restricted zones, this is the old path blocking - we'll re-evaluate with distance
	
	# 2. Precision Path Overlap Check
	var center_pos = cell_to_local_center(cell)
	if _is_overlapping_any_path(center_pos, footprint):
		if OS.is_debug_build():
			print("[BuildCheck] tower=%s pos=%s footprint=%.1f range=%.1f reason=blocked_by_path" % [selected_tower_id, center_pos, footprint, range_val])
		return {"is_valid": false, "reason": "Blocked by path", "cost": cost}
		
	# 3. Occupancy Check
	if occupied_cells.has(cell):
		return {"is_valid": false, "reason": "Already occupied", "cost": cost}
	
	if OS.is_debug_build():
		print("[BuildCheck] tower=%s pos=%s footprint=%.1f range=%.1f reason=ok" % [selected_tower_id, center_pos, footprint, range_val])
	
	return {"is_valid": true, "reason": "Valid", "cost": cost, "config": config}

func _is_overlapping_any_path(pos: Vector2, footprint: float) -> bool:
	if not level_manager: return false
	
	var threshold = (LANE_WIDTH / 2.0) + footprint + PLACEMENT_PADDING
	
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2: continue
		
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			var closest = Geometry2D.get_closest_point_to_segment(pos, p1, p2)
			var dist = pos.distance_to(closest)
			
			if dist < threshold:
				return true
	return false

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
	
	occupied_cells[cell] = true
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

func can_place_at(cell: Vector2i) -> bool:
	return validate_placement(cell)["is_valid"]
