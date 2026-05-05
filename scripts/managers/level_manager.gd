extends Node

var level_id: String
var level_name: String
var grid_size: int = 64
var grid_cols: int = 20
var grid_rows: int = 12
var grid_origin: Vector2 = Vector2.ZERO

var path_cells: Array[Vector2i] = []
var spawn_cell: Vector2i
var base_cell: Vector2i
var blocked_cells: Array[Vector2i] = []
var decorative_blocked_cells: Array[Vector2i] = []

var starting_gold: int = 100
var starting_lives: int = 20
var waves_path: String = "res://data/waves.json"

func load_level(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Level file not found: " + path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open level file: " + path)
		return false
		
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON Parse Error in " + path + ": " + json.get_error_message())
		return false
	
	var data = json.data
	if data == null:
		push_error("JSON data is null in " + path)
		return false
		
	level_id = data.get("id", "unknown")
	level_name = data.get("name", "Unknown Level")
	grid_size = data.get("grid_size", 64)
	grid_cols = data.get("grid_cols", 20)
	grid_rows = data.get("grid_rows", 12)
	
	var origin_data = data.get("grid_origin", {"x": 0, "y": 0})
	grid_origin = Vector2(origin_data.get("x", 0), origin_data.get("y", 0))
	
	starting_gold = data.get("starting_gold", 100)
	starting_lives = data.get("starting_lives", 20)
	waves_path = data.get("waves_path", "res://data/waves.json")
	
	path_cells.clear()
	for p in data.get("path_cells", []):
		if p is Array and p.size() >= 2:
			path_cells.append(Vector2i(p[0], p[1]))
		
	var s = data.get("spawn_cell", [0, 0])
	spawn_cell = Vector2i(s[0], s[1])
	
	var b = data.get("base_cell", [0, 0])
	base_cell = Vector2i(b[0], b[1])
	
	blocked_cells.clear()
	for p in data.get("blocked_cells", []):
		if p is Array and p.size() >= 2:
			blocked_cells.append(Vector2i(p[0], p[1]))
		
	decorative_blocked_cells.clear()
	for p in data.get("decorative_blocked_cells", []):
		if p is Array and p.size() >= 2:
			decorative_blocked_cells.append(Vector2i(p[0], p[1]))
		
	if OS.is_debug_build(): print("Level loaded: ", level_name, " (", level_id, ")")
	return true

func get_all_blocked_cells() -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	all.append_array(path_cells)
	all.append_array(blocked_cells)
	all.append_array(decorative_blocked_cells)
	return all

func is_path_cell(cell: Vector2i) -> bool:
	return cell in path_cells

func is_blocked_cell(cell: Vector2i) -> bool:
	return cell in blocked_cells or cell in decorative_blocked_cells or cell in path_cells

func cell_to_world_center(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x * grid_size + grid_size / 2, cell.y * grid_size + grid_size / 2)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_origin
	return Vector2i(floor(local_pos.x / grid_size), floor(local_pos.y / grid_size))

func get_path_points() -> PackedVector2Array:
	var points = PackedVector2Array()
	for cell in path_cells:
		points.append(cell_to_world_center(cell))
	return points
