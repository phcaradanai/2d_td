class_name EnemyMovementService
extends RefCounted

static func _process_pathing(enemy: Node2D, delta: float) -> void:
	if enemy.is_dead_flag or enemy.reached_base_flag:
		return
	enemy._lock_visual_orientation()
	if enemy.use_dynamic_pathing:
		EnemyMovementService._process_dynamic_pathing(enemy, delta)
		return
	var before_pos := enemy.global_position
	enemy.progress += enemy.speed * delta
	enemy._record_visual_movement_delta(enemy.global_position - before_pos)
	enemy._lock_visual_orientation()
	EnemyMovementService._sync_spatial_target_cache(enemy, true)
	if enemy.progress_ratio >= 1.0:
		if enemy.has_method("reach_base"):
			enemy.reach_base()

static func set_dynamic_pathing(enemy: Node2D, manager: Node, spawn_cell: Vector2i) -> void:
	enemy.pathfinding_manager = manager
	enemy.use_dynamic_pathing = enemy.pathfinding_manager != null and enemy.enemy_category == enemy.ENEMY_CATEGORY_LAND
	if not enemy.use_dynamic_pathing:
		return

	var start_cell: Vector2i = enemy.pathfinding_manager.nearest_walkable_cell(spawn_cell)
	enemy.global_position = enemy.pathfinding_manager.cell_to_world(start_cell)
	EnemyMovementService._sync_spatial_target_cache(enemy, true)
	enemy.last_path_grid_version = -1
	EnemyMovementService._recalculate_dynamic_path(enemy)

static func set_pathfinding_manager(enemy: Node2D, manager: Node) -> void:
	enemy.pathfinding_manager = manager
	enemy.use_dynamic_pathing = enemy.pathfinding_manager != null and enemy.enemy_category == enemy.ENEMY_CATEGORY_LAND
	if enemy.use_dynamic_pathing:
		enemy.add_to_group("ground_enemies")

static func request_path_to_core(enemy: Node2D) -> void:
	EnemyMovementService._recalculate_dynamic_path(enemy)

static func on_navigation_grid_changed(enemy: Node2D, version: int) -> void:
	if enemy.enemy_category == enemy.ENEMY_CATEGORY_AIR or not enemy.use_dynamic_pathing:
		return
	if version == enemy.last_path_grid_version:
		return
	EnemyMovementService._recalculate_dynamic_path(enemy)

static func _process_dynamic_pathing(enemy: Node2D, delta: float) -> void:
	if enemy.is_dead_flag or enemy.reached_base_flag:
		return
	if enemy.pathfinding_manager == null or not is_instance_valid(enemy.pathfinding_manager):
		return

	if enemy.last_path_grid_version != int(enemy.pathfinding_manager.grid_version):
		EnemyMovementService._recalculate_dynamic_path(enemy)

	if enemy.dynamic_path.is_empty():
		EnemyMovementService._recalculate_dynamic_path(enemy)
		if enemy.dynamic_path.is_empty():
			return

	if enemy.dynamic_path_index >= enemy.dynamic_path.size():
		if enemy.has_method("reach_base"):
			enemy.reach_base()
		return

	var target: Vector2 = enemy.dynamic_path[enemy.dynamic_path_index]
	var to_target: Vector2 = target - Vector2(enemy.global_position)
	var step: float = float(enemy.speed) * delta
	if to_target.length() <= maxf(step, float(enemy.dynamic_target_reached_distance)):
		var snap_delta: Vector2 = target - Vector2(enemy.global_position)
		enemy.global_position = target
		enemy._record_visual_movement_delta(snap_delta)
		enemy.dynamic_path_index += 1
		if enemy.dynamic_path_index >= enemy.dynamic_path.size():
			if enemy.has_method("reach_base"):
				enemy.reach_base()
		return

	var dir: Vector2 = to_target.normalized()
	var move_delta: Vector2 = dir * step
	enemy.global_position += move_delta
	enemy._record_visual_movement_delta(move_delta)
	enemy._lock_visual_orientation()
	enemy.dynamic_travel_distance += step
	EnemyMovementService._sync_spatial_target_cache(enemy, true)

static func _recalculate_dynamic_path(enemy: Node2D) -> void:
	if enemy.pathfinding_manager == null or not is_instance_valid(enemy.pathfinding_manager):
		enemy.dynamic_path = PackedVector2Array()
		return

	var current_cell: Vector2i = enemy.pathfinding_manager.world_to_cell(enemy.global_position)
	if not enemy.pathfinding_manager.is_cell_walkable(current_cell):
		current_cell = enemy.pathfinding_manager.nearest_walkable_cell(current_cell)
		enemy.global_position = enemy.pathfinding_manager.cell_to_world(current_cell)

	enemy.dynamic_path = enemy.pathfinding_manager.get_path_world_points(enemy.global_position)
	enemy.last_path_grid_version = int(enemy.pathfinding_manager.grid_version)
	enemy.dynamic_path_index = 0
	if enemy.dynamic_path.size() > 1 and enemy.global_position.distance_to(enemy.dynamic_path[0]) <= enemy.dynamic_target_reached_distance:
		enemy.dynamic_path_index = 1
	EnemyMovementService._sync_spatial_target_cache(enemy, true)

static func _sync_spatial_target_cache(enemy: Node2D, register_if_missing: bool) -> void:
	var cache := enemy.get_node_or_null("/root/SpatialTargetCache")
	if cache == null:
		return
	if register_if_missing:
		cache.update_enemy_bucket(enemy)
	else:
		cache.unregister_enemy(enemy)
