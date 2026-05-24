extends Node
class_name LevelManager

var level_id: String
var level_name: String
var grid_size: int = 64
var grid_cols: int = 20
var grid_rows: int = 12
var grid_origin: Vector2 = Vector2.ZERO
 
const LANE_WIDTH: float = 64.0
const PLACEMENT_PADDING: float = 4.0
const DEFAULT_TOWER_FOOTPRINT: float = 20.0

var path_cells: Array[Vector2i] = []
var multi_paths: Dictionary = {} # path_id -> Array[Vector2i]
var spawn_cell: Vector2i
var base_cell: Vector2i
var spawn_cells: Array[Vector2i] = []
var base_cells: Array[Vector2i] = []
var blocked_cells: Array[Vector2i] = []
var decorative_blocked_cells: Array[Vector2i] = []
var buildable_cells: Array[Vector2i] = []

var starting_gold: int = 100
var starting_lives: int = 20
var waves_path: String = "res://data/waves/waves_01.json"
var buildable_mode: String = "full_non_path"
var hero_config: Dictionary = {
	"enabled": false,
	"unlock_message": "",
	"deploy_cost": 100,
	"duration": 28,
	"cooldown": 35
}
var level_data: Dictionary = {}

var current_theme: Resource = null
var theme_manager: Node = null
 
func reset_state() -> void:
	level_id = ""
	level_name = "Unknown Level"
	starting_gold = 100
	starting_lives = 20
	buildable_mode = "full_non_path"
	path_cells.clear()
	multi_paths.clear()
	spawn_cells.clear()
	base_cells.clear()
	blocked_cells.clear()
	decorative_blocked_cells.clear()
	buildable_cells.clear()
	grid_cols = 20
	grid_rows = 12
	hero_config = {
		"enabled": false,
		"unlock_message": "",
		"deploy_cost": 100,
		"duration": 28,
		"cooldown": 35
	}
	current_theme = null
	level_data.clear()

func load_level(path: String) -> bool:
	reset_state()
	
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
	
	level_data = data
	level_id = data.get("id", "unknown")
	level_name = data.get("name", "Unknown Level")
	grid_size = data.get("grid_size", 64)
	grid_cols = data.get("grid_cols", 20)
	grid_rows = data.get("grid_rows", 12)
	
	var origin_data = data.get("grid_origin", {"x": 0, "y": 0})
	grid_origin = Vector2(origin_data.get("x", 0), origin_data.get("y", 0))
	
	var area_id = data.get("area_id", 1)
	_load_theme_for_area(area_id)
	
	starting_gold = data.get("starting_gold", 100)
	starting_lives = data.get("starting_lives", 20)
	waves_path = data.get("waves_path", "res://data/waves/waves_01.json")
	buildable_mode = data.get("buildable_mode", "full_non_path")
	
	hero_config = {
		"enabled": data.get("hero_enabled", false),
		"unlock_message": data.get("hero_unlock_message", ""),
		"deploy_cost": data.get("hero_deploy_cost", 100),
		"duration": data.get("hero_duration_seconds", 28),
		"cooldown": data.get("hero_cooldown_seconds", 35),
		"hp": data.get("hero_hp", 450.0),
		"damage": data.get("hero_damage", 36.0),
		"attack_speed": data.get("hero_attack_speed", 1.4),
		"attack_range": data.get("hero_attack_range", 125.0),
		"move_speed": data.get("hero_move_speed", 220.0)
	}
	
	# Handle paths
	path_cells.clear()
	multi_paths.clear()
	
	# Try loading "paths" dictionary first (New Multi-Path support)
	var paths_dict = data.get("paths", {})
	if paths_dict is Dictionary and not paths_dict.is_empty():
		for p_id in paths_dict:
			var cells: Array[Vector2i] = []
			for p in paths_dict[p_id]:
				if p is Array and p.size() >= 2:
					cells.append(Vector2i(p[0], p[1]))
			if cells.is_empty():
				push_error("[PathSystem] ERROR: Path '%s' in level '%s' has no points!" % [p_id, level_id])
			else:
				multi_paths[p_id] = cells
				if OS.is_debug_build():
					var start = cells[0]
					var end = cells[cells.size() - 1]
					print("[PathSystem] lane=%s points=%d start=%s end=%s" % [p_id, cells.size(), start, end])
		
		# Set primary path_cells for compatibility
		if multi_paths.has("default"):
			path_cells = multi_paths["default"] as Array[Vector2i]
		elif not multi_paths.is_empty():
			path_cells = multi_paths.values()[0] as Array[Vector2i]
	else:
		# Fallback to legacy path_cells
		for p in data.get("path_cells", []):
			if p is Array and p.size() >= 2:
				path_cells.append(Vector2i(p[0], p[1]))
		multi_paths["default"] = path_cells
		if OS.is_debug_build(): print("[PathSystem] default_path=default points=%d" % path_cells.size())
		
	var s = data.get("spawn_cell", [0, 0])
	spawn_cell = Vector2i(s[0], s[1])
	spawn_cells = _cells_from_arrays(data.get("spawn_cells", []))
	if spawn_cells.is_empty():
		spawn_cells.append(spawn_cell)
	
	var b = data.get("base_cell", [0, 0])
	base_cell = Vector2i(b[0], b[1])
	base_cells = _cells_from_arrays(data.get("base_cells", []))
	if base_cells.is_empty():
		base_cells.append(base_cell)
	
	blocked_cells.clear()
	for p in data.get("blocked_cells", []):
		if p is Array and p.size() >= 2:
			blocked_cells.append(Vector2i(p[0], p[1]))
		
	decorative_blocked_cells.clear()
	for p in data.get("decorative_blocked_cells", []):
		if p is Array and p.size() >= 2:
			decorative_blocked_cells.append(Vector2i(p[0], p[1]))
			
	buildable_cells.clear()
	for p in data.get("buildable_cells", []):
		if p is Array and p.size() >= 2:
			buildable_cells.append(Vector2i(p[0], p[1]))
		
	if OS.is_debug_build(): print("[PathSystem] level=%s paths=%d" % [level_id, multi_paths.size()])
	return true

func get_all_blocked_cells() -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	for x in range(grid_cols):
		for y in range(grid_rows):
			var cell = Vector2i(x, y)
			var reason = get_build_block_reason(cell)
			if reason != "":
				all.append(cell)
	return all

func is_path_cell(cell: Vector2i) -> bool:
	for p_id in multi_paths:
		if cell in multi_paths[p_id]:
			return true
	return false

func get_visual_road_width_cells() -> int:
	return max(1, int(level_data.get("road_visual_width_cells", 1)))

func is_visual_road_cell(cell: Vector2i) -> bool:
	if not bool(level_data.get("road_visual_blocks_building", false)):
		return false
	var cells: Dictionary = _collect_visual_road_cells()
	return cells.has(_road_cell_key(cell))

func _collect_visual_road_cells() -> Dictionary:
	var out: Dictionary = {}
	var width: int = min(3, get_visual_road_width_cells())
	for p_id in multi_paths:
		var cells: Array = multi_paths[p_id]
		for i in range(cells.size()):
			var center_cell = cells[i]
			if center_cell is Vector2i:
				_add_visual_road_cell_segment_footprint(out, center_cell, cells, i, width)
	var extra_cells = level_data.get("road_visual_extra_cells", [])
	if extra_cells is Array:
		for item in extra_cells:
			if item is Array and item.size() >= 2:
				var c := Vector2i(int(item[0]), int(item[1]))
				_add_road_cell_if_inside(out, c)
	return out

func _add_visual_road_cell_footprint(out: Dictionary, center_cell: Vector2i, half_width: int) -> void:
	# Backward-compatible helper. Width is clamped by callers; avoid accidental 5+ cell roads.
	var width: int = min(3, half_width * 2 + 1)
	_add_visual_road_cell_segment_footprint(out, center_cell, [center_cell], 0, width)

func _add_visual_road_cell_segment_footprint(out: Dictionary, center_cell: Vector2i, cells: Array, index: int, width: int) -> void:
	_add_road_cell_if_inside(out, center_cell)
	if width <= 1:
		return

	var dirs: Array[Vector2i] = []
	if index > 0 and cells[index - 1] is Vector2i:
		var prev_cell: Vector2i = cells[index - 1]
		var prev_dir: Vector2i = center_cell - prev_cell
		if prev_dir != Vector2i.ZERO:
			dirs.append(Vector2i(signi(prev_dir.x), signi(prev_dir.y)))
	if index < cells.size() - 1 and cells[index + 1] is Vector2i:
		var next_cell: Vector2i = cells[index + 1]
		var next_dir: Vector2i = next_cell - center_cell
		if next_dir != Vector2i.ZERO:
			dirs.append(Vector2i(signi(next_dir.x), signi(next_dir.y)))
	if dirs.is_empty():
		dirs.append(Vector2i.RIGHT)

	for dir in dirs:
		var perp := Vector2i(-dir.y, dir.x)
		if perp == Vector2i.ZERO:
			continue
		_add_road_cell_if_inside(out, center_cell + perp)
		_add_road_cell_if_inside(out, center_cell - perp)

func _add_road_cell_if_inside(out: Dictionary, road_cell: Vector2i) -> void:
	if road_cell.x < 0 or road_cell.x >= grid_cols or road_cell.y < 0 or road_cell.y >= grid_rows:
		return
	out[_road_cell_key(road_cell)] = road_cell

func signi(v: int) -> int:
	if v > 0:
		return 1
	if v < 0:
		return -1
	return 0


func _road_cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func is_blocked_cell(cell: Vector2i) -> bool:
	return get_build_block_reason(cell) != ""

func get_build_block_reason(cell: Vector2i) -> String:
	if cell.x < 0 or cell.x >= grid_cols or cell.y < 0 or cell.y >= grid_rows:
		return "out_of_bounds"

	if cell in spawn_cells:
		return "spawn"

	if cell in base_cells:
		return "base"

	if cell in blocked_cells:
		return "blocked"

	# Element TD fixed-path maps: build freely around the road, but never on the enemy path.
	if is_path_cell(cell) or is_visual_road_cell(cell):
		return "path"

	if buildable_mode == "manual" and not buildable_cells.is_empty() and not buildable_cells.has(cell):
		return "non_buildable"

	return ""

func _cells_from_arrays(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (raw is Array):
		return out
	for item in raw:
		if item is Array and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out

func is_position_on_enemy_path(pos: Vector2, footprint: float = DEFAULT_TOWER_FOOTPRINT) -> bool:
	var threshold = (LANE_WIDTH / 2.0) + footprint + PLACEMENT_PADDING
	
	for p_id in multi_paths:
		var points = get_path_points_for_id(p_id)
		if points.size() < 2: continue
		
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			var closest = Geometry2D.get_closest_point_to_segment(pos, p1, p2)
			var dist = pos.distance_to(closest)
			
			if dist < threshold:
				return true
	return false

func cell_to_world_center(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x * grid_size + grid_size / 2.0, cell.y * grid_size + grid_size / 2.0)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_origin
	return Vector2i(floor(local_pos.x / grid_size), floor(local_pos.y / grid_size))

func get_path_points() -> PackedVector2Array:
	return get_path_points_for_id("default")

func get_path_points_for_id(path_id: String) -> PackedVector2Array:
	var points = PackedVector2Array()
	var cells = multi_paths.get(path_id, path_cells)
	for cell in cells:
		points.append(cell_to_world_center(cell))
	return points

func get_config_as_dict() -> Dictionary:
	return {
		"id": level_id,
		"name": level_name,
		"grid_size": grid_size,
		"grid_cols": grid_cols,
		"grid_rows": grid_rows,
		"paths": multi_paths,
		"path_cells": path_cells,
		"spawn_cells": spawn_cells,
		"base_cells": base_cells,
		"buildable_cells": buildable_cells,
		"starting_gold": starting_gold,
		"starting_lives": starting_lives,
		"hero_config": hero_config
	}

func _load_theme_for_area(area_id: int) -> void:
	if theme_manager == null:
		var theme_script = load("res://scripts/map/theme_manager.gd")
		theme_manager = theme_script.new()
		theme_manager.name = "ThemeManager"
		add_child(theme_manager)
	
	var theme_id = "area_grasslands"
	match area_id:
		1: theme_id = "area_grasslands"
		2: theme_id = "area_forest"
		3: theme_id = "area_forest_river"
		4: theme_id = "area_mountain"
	
	current_theme = theme_manager.get_theme(theme_id)
