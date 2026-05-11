extends Node2D
class_name EnemyRouteOverlay

## Lightweight route indicator — draws one path per spawn to the core
## plus a limited active-enemy reroute hint.
## Updates only when the pathfinding grid version changes.
## No per-frame processing, no per-enemy drawing, no animations.

# ------------------------------------------------------------------ visual
const SPAWN_ROUTE_COLOR    := Color(0.2,  0.9,  1.0,  0.35)  # cyan — spawn→core
const SPAWN_ARROW_COLOR    := Color(0.2,  0.9,  1.0,  0.45)
const ACTIVE_ROUTE_COLOR   := Color(1.0,  0.62, 0.12, 0.38)  # amber — active enemy→core
const ACTIVE_ARROW_COLOR   := Color(1.0,  0.62, 0.12, 0.50)
const LINE_WIDTH           := 2.0
const ARROW_EVERY          := 8       # one direction arrow every N cells
const ARROW_SIZE           := 10.0
const Z_INDEX_LAYER        := 1       # above bg/grid, below towers/enemies

const MAX_ACTIVE_REROUTE_PATHS := 3    # never draw more than this

# ------------------------------------------------------------------ state
var _pathfinding_manager: Node = null
var _spawn_cells: Array[Vector2i] = []
var _target_cells: Array[Vector2i] = []

var _cached_spawn_routes: Array[PackedVector2Array] = []
var _cached_active_routes: Array[PackedVector2Array] = []
var _last_grid_version: int = -1

var _visible_for_wave: bool = true


# ================================================================== setup

func _ready() -> void:
	set_process(false)
	z_index = Z_INDEX_LAYER
	z_as_relative = false


## Call once per level load.
func setup(p_pathfinding_manager: Node, p_spawn_cells: Array[Vector2i], p_target_cells: Array[Vector2i]) -> void:
	_pathfinding_manager = p_pathfinding_manager
	_spawn_cells = p_spawn_cells
	_target_cells = p_target_cells

	_last_grid_version = -1  # force refresh

	if _pathfinding_manager and _pathfinding_manager.has_signal("grid_changed"):
		if not _pathfinding_manager.grid_changed.is_connected(_on_grid_changed):
			_pathfinding_manager.grid_changed.connect(_on_grid_changed)

	refresh_routes()


## Recompute cached routes — spawn→core + active-enemy→core.
func refresh_routes() -> void:
	if _pathfinding_manager == null or not is_instance_valid(_pathfinding_manager):
		_cached_spawn_routes.clear()
		_cached_active_routes.clear()
		return

	# ----- spawn → core routes ---------------------------------------
	_cached_spawn_routes.clear()

	for spawn in _spawn_cells:
		if not _pathfinding_manager.is_cell_walkable(spawn):
			var nearest: Vector2i = _pathfinding_manager.nearest_walkable_cell(spawn)
			if not _pathfinding_manager.is_cell_walkable(nearest):
				continue

		var route: PackedVector2Array = _pathfinding_manager.get_world_path(spawn)
		if route.size() >= 2:
			_cached_spawn_routes.append(route)

	# ----- active enemy → core reroute hints -------------------------
	_cached_active_routes.clear()

	var frontmost_enemies: Array[Node2D] = _pick_frontmost_ground_enemies(MAX_ACTIVE_REROUTE_PATHS)
	for enemy in frontmost_enemies:
		var start_cell: Vector2i = _pathfinding_manager.world_to_cell(enemy.global_position)
		if not _pathfinding_manager.is_cell_walkable(start_cell):
			start_cell = _pathfinding_manager.nearest_walkable_cell(start_cell)

		var route: PackedVector2Array = _pathfinding_manager.get_world_path(start_cell)
		if route.size() >= 2:
			_cached_active_routes.append(route)

	_last_grid_version = int(_pathfinding_manager.grid_version)
	queue_redraw()


func set_visible_for_wave(active: bool) -> void:
	_visible_for_wave = active
	queue_redraw()


# ================================================================ signals

func _on_grid_changed(_version: int) -> void:
	if not _visible_for_wave:
		return
	refresh_routes()


# ================================================= active enemy selection

## Returns up to [limit] active ground enemies closest to the core.
func _pick_frontmost_ground_enemies(limit: int) -> Array[Node2D]:
	var out: Array[Node2D] = []

	var tree := get_tree()
	if tree == null:
		return out

	# Collect active ground enemies with their distance-to-core
	var candidates: Array[Dictionary] = []
	for enemy in tree.get_nodes_in_group("ground_enemies"):
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue

		var dist: float = _min_distance_to_target(enemy.global_position)
		candidates.append({"enemy": enemy, "dist": dist})

	if candidates.is_empty():
		return out

	# Sort by distance — closest first (front-most)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist"] < b["dist"])

	for i in range(min(limit, candidates.size())):
		out.append(candidates[i]["enemy"] as Node2D)

	return out


func _min_distance_to_target(world_pos: Vector2) -> float:
	var best: float = INF
	for target in _target_cells:
		var target_world: Vector2 = _pathfinding_manager.cell_to_world(target)
		var d: float = world_pos.distance_squared_to(target_world)
		if d < best:
			best = d
	return best


# =================================================================== draw

func _draw() -> void:
	if not _visible_for_wave:
		return

	# ----- spawn → core routes (cyan, always shown) -----------------
	for route in _cached_spawn_routes:
		if route.size() < 2:
			continue
		_draw_route_line(route, SPAWN_ROUTE_COLOR, SPAWN_ARROW_COLOR)

	# ----- active enemy → core reroute hints (amber) -----------------
	for route in _cached_active_routes:
		if route.size() < 2:
			continue
		_draw_route_line(route, ACTIVE_ROUTE_COLOR, ACTIVE_ARROW_COLOR)


func _draw_route_line(route: PackedVector2Array, line_color: Color, arrow_color: Color) -> void:
	draw_polyline(route, line_color, LINE_WIDTH, false)

	# direction arrows every ARROW_EVERY cells
	if route.size() > 2:
		for i in range(ARROW_EVERY, route.size() - 1, ARROW_EVERY):
			var from_pos := route[i]
			var to_pos   := route[i + 1]
			var dir := from_pos.direction_to(to_pos)
			if dir.length_squared() < 0.0001:
				continue
			_draw_arrow_head(from_pos, dir, arrow_color)

		# one arrow near the core (readable final direction)
		var last_idx := route.size() - 1
		var prev_idx := last_idx - 1
		var last_dir := route[prev_idx].direction_to(route[last_idx])
		if last_dir.length_squared() > 0.0001:
			var arrow_pos := route[prev_idx].lerp(route[last_idx], 0.35)
			_draw_arrow_head(arrow_pos, last_dir, arrow_color)


func _draw_arrow_head(at: Vector2, dir: Vector2, color: Color) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var size := ARROW_SIZE
	var wing := size * 0.5

	var tip   := at + dir * size * 0.4
	var left  := tip - dir * wing + perp * wing * 0.55
	var right := tip - dir * wing - perp * wing * 0.55

	draw_line(tip, left,  color, 1.2)
	draw_line(tip, right, color, 1.2)
