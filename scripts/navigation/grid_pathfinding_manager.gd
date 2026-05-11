extends Node
class_name GridPathfindingManager

signal grid_changed(version: int)

const DEFAULT_TOWER_CLEARANCE_RADIUS := 28.0

var grid_size: int = 64
var grid_cols: int = 20
var grid_rows: int = 12
var grid_origin: Vector2 = Vector2.ZERO

var spawn_cells: Array[Vector2i] = []
var target_cells: Array[Vector2i] = []
var reserved_cells: Dictionary = {}
var static_blocked_cells: Dictionary = {}
var tower_blocked_cells: Dictionary = {}
var grid_version: int = 0

var _astar := AStarGrid2D.new()
var _cached_spawn_paths: Dictionary = {}

func setup_grid(level_manager: Node) -> void:
	if level_manager == null:
		return

	grid_size = int(level_manager.grid_size)
	grid_cols = int(level_manager.grid_cols)
	grid_rows = int(level_manager.grid_rows)
	grid_origin = level_manager.grid_origin

	spawn_cells = _extract_cells(level_manager.level_data.get("spawn_cells", []))
	if spawn_cells.is_empty() and "spawn_cell" in level_manager:
		spawn_cells.append(level_manager.spawn_cell)

	target_cells = _extract_cells(level_manager.level_data.get("base_cells", []))
	if target_cells.is_empty() and "base_cell" in level_manager:
		target_cells.append(level_manager.base_cell)

	reserved_cells.clear()
	for cell in spawn_cells:
		reserved_cells[_cell_key(cell)] = true
	for cell in target_cells:
		reserved_cells[_cell_key(cell)] = true

	static_blocked_cells.clear()
	for cell in level_manager.blocked_cells:
		if cell is Vector2i:
			static_blocked_cells[_cell_key(cell)] = true

	tower_blocked_cells.clear()
	_configure_astar()
	_apply_all_solid_cells()
	_bump_grid_version()

func setup_from_level(level_manager: Node) -> void:
	setup_grid(level_manager)

func can_place_blocker(cell: Vector2i, footprint_cells: Array[Vector2i] = [], check_enemies: bool = true) -> bool:
	return get_blocker_validation_reason(cell, footprint_cells, check_enemies) == ""

func can_block_cell_without_breaking_paths(cell: Vector2i) -> bool:
	var footprint: Array[Vector2i] = []
	return can_place_blocker(cell, footprint, true)

func get_blocker_validation_reason(cell: Vector2i, footprint_cells: Array[Vector2i] = [], check_enemies: bool = true) -> String:
	var cells := _normalize_footprint(cell, footprint_cells)
	for c in cells:
		if not is_in_bounds(c):
			return "Cannot build outside map"
		if is_reserved_cell(c):
			if spawn_cells.has(c):
				return "Cannot build on spawn point"
			return "Cannot build on base point"
		if static_blocked_cells.has(_cell_key(c)):
			return "Tile is blocked"
		if tower_blocked_cells.has(_cell_key(c)):
			return "Cannot build on existing tower"
		if check_enemies and _is_enemy_on_cell(c):
			return "Cannot build on active enemy"

	for c in cells:
		_set_cell_solid(c, true)

	var valid := validate_all_spawns_have_path() and validate_active_ground_enemies_have_path()

	for c in cells:
		_set_cell_solid(c, _is_permanently_solid(c))

	if not valid:
		return "Cannot block enemy path"
	return ""

func set_tower_blocked(cell: Vector2i, blocked: bool, footprint_cells: Array[Vector2i] = []) -> void:
	var changed := false
	for c in _normalize_footprint(cell, footprint_cells):
		var key := _cell_key(c)
		if blocked:
			if not tower_blocked_cells.has(key):
				tower_blocked_cells[key] = true
				changed = true
		elif tower_blocked_cells.has(key):
			tower_blocked_cells.erase(key)
			changed = true
		_set_cell_solid(c, _is_permanently_solid(c))

	if changed:
		_bump_grid_version()

func is_cell_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	return not _astar.is_point_solid(cell)

func is_reserved_cell(cell: Vector2i) -> bool:
	return reserved_cells.has(_cell_key(cell))

func validate_all_spawns_have_path() -> bool:
	if spawn_cells.is_empty() or target_cells.is_empty():
		return false
	for spawn in spawn_cells:
		if get_cell_path(spawn).is_empty():
			return false
	return true

func validate_active_ground_enemies_have_path() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	for enemy in tree.get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if enemy.has_method("get_enemy_category") and enemy.get_enemy_category() != "land":
			continue
		if get_cell_path(world_to_cell(enemy.global_position)).is_empty():
			return false
	return true

func get_cell_path(start_cell: Vector2i, target_cell: Vector2i = Vector2i(-999999, -999999)) -> Array[Vector2i]:
	if target_cells.is_empty() and target_cell == Vector2i(-999999, -999999):
		return []

	var start := nearest_walkable_cell(start_cell)
	if not is_in_bounds(start) or not is_cell_walkable(start):
		return []

	var best_path: Array[Vector2i] = []
	var best_len := INF
	var targets: Array[Vector2i] = [target_cell] if target_cell != Vector2i(-999999, -999999) else target_cells
	for target in targets:
		if not is_in_bounds(target) or not is_cell_walkable(target):
			continue
		var ids: Array = _astar.get_id_path(start, target)
		if ids.is_empty():
			continue
		var points: Array[Vector2i] = []
		for id in ids:
			if id is Vector2i:
				points.append(id)
		var length := _path_length(points)
		if length < best_len:
			best_len = length
			best_path = points
	return best_path

func get_path_cells(start_cell: Vector2i, target_cell: Vector2i = Vector2i(-999999, -999999)) -> Array[Vector2i]:
	return get_cell_path(start_cell, target_cell)

func get_world_path(start_cell: Vector2i, target_cell: Vector2i = Vector2i(-999999, -999999)) -> PackedVector2Array:
	var cell_path := get_cell_path(start_cell, target_cell)
	var world_path := PackedVector2Array()
	for p in cell_path:
		world_path.append(cell_to_world(p))
	return world_path

func get_path_world_points(start_world: Vector2, target_cell: Vector2i = Vector2i(-999999, -999999)) -> PackedVector2Array:
	return get_world_path(world_to_cell(start_world), target_cell)

func get_spawn_path(spawn_cell: Vector2i) -> PackedVector2Array:
	var key := _cell_key(spawn_cell)
	if _cached_spawn_paths.has(key):
		return _cached_spawn_paths[key]
	var path := get_world_path(spawn_cell)
	_cached_spawn_paths[key] = path
	return path

func world_to_cell(pos: Vector2) -> Vector2i:
	var p := pos - grid_origin
	return Vector2i(floor(p.x / grid_size), floor(p.y / grid_size))

func cell_to_world(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x * grid_size + grid_size / 2.0, cell.y * grid_size + grid_size / 2.0)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_cols and cell.y >= 0 and cell.y < grid_rows

func nearest_walkable_cell(cell: Vector2i, max_radius: int = 4) -> Vector2i:
	if is_cell_walkable(cell):
		return cell
	for radius in range(1, max_radius + 1):
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				var c := Vector2i(x, y)
				if is_cell_walkable(c):
					return c
	return cell

func _configure_astar() -> void:
	_astar.region = Rect2i(0, 0, grid_cols, grid_rows)
	_astar.cell_size = Vector2(grid_size, grid_size)
	_astar.offset = Vector2(grid_size / 2.0, grid_size / 2.0) + grid_origin
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

func _apply_all_solid_cells() -> void:
	for y in range(grid_rows):
		for x in range(grid_cols):
			var cell := Vector2i(x, y)
			_set_cell_solid(cell, _is_permanently_solid(cell))

func _set_cell_solid(cell: Vector2i, solid: bool) -> void:
	if is_in_bounds(cell):
		_astar.set_point_solid(cell, solid)

func _is_permanently_solid(cell: Vector2i) -> bool:
	var key := _cell_key(cell)
	return static_blocked_cells.has(key) or tower_blocked_cells.has(key)

func _bump_grid_version() -> void:
	grid_version += 1
	_cached_spawn_paths.clear()
	grid_changed.emit(grid_version)
	if is_inside_tree():
		var tree := get_tree()
		tree.call_group("ground_enemies", "on_navigation_grid_changed", grid_version)

func _normalize_footprint(cell: Vector2i, footprint_cells: Array[Vector2i]) -> Array[Vector2i]:
	if footprint_cells.is_empty():
		return [cell]
	return footprint_cells

func _extract_cells(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (raw is Array):
		return out
	for item in raw:
		if item is Vector2i:
			out.append(item)
		elif item is Array and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out

func _is_enemy_on_cell(cell: Vector2i) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for enemy in tree.get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if world_to_cell(enemy.global_position) == cell:
			return true
		if enemy.global_position.distance_to(cell_to_world(cell)) <= DEFAULT_TOWER_CLEARANCE_RADIUS:
			return true
	return false

func _path_length(points: Array[Vector2i]) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += abs(points[i].x - points[i + 1].x) + abs(points[i].y - points[i + 1].y)
	return total

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
