extends Node

const DEFAULT_BUCKET_SIZE := 64.0

var _bucket_size: float = DEFAULT_BUCKET_SIZE
var _inv_bucket_size: float = 1.0 / DEFAULT_BUCKET_SIZE

var _enemies: Array[Node2D] = []
var _enemy_ids: Dictionary = {}
var _enemy_bucket_keys: Dictionary = {}
var _buckets: Dictionary = {}

func set_bucket_size(size: float) -> void:
	var next_size := maxf(1.0, size)
	if is_equal_approx(next_size, _bucket_size):
		return
	_bucket_size = next_size
	_inv_bucket_size = 1.0 / _bucket_size
	_rebuild_buckets()

func register_enemy(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _enemy_ids.has(id):
		update_enemy_bucket(enemy)
		return
	_enemy_ids[id] = true
	_enemies.append(enemy)
	var key := _bucket_key_for_world(enemy.global_position)
	_enemy_bucket_keys[id] = key
	_bucket_add_enemy(key, enemy)

func unregister_enemy(enemy: Node2D) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if not _enemy_ids.has(id):
		return
	_enemy_ids.erase(id)
	_enemies.erase(enemy)
	var old_key: String = _enemy_bucket_keys.get(id, "")
	if old_key != "":
		_bucket_remove_enemy(old_key, enemy)
	_enemy_bucket_keys.erase(id)

func update_enemy_bucket(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if not _enemy_ids.has(id):
		register_enemy(enemy)
		return
	var old_key: String = _enemy_bucket_keys.get(id, "")
	var next_key := _bucket_key_for_world(enemy.global_position)
	if old_key == next_key:
		return
	if old_key != "":
		_bucket_remove_enemy(old_key, enemy)
	_enemy_bucket_keys[id] = next_key
	_bucket_add_enemy(next_key, enemy)

func get_candidates_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	if _enemies.is_empty():
		return []
	var out: Array[Node2D] = []
	var r := maxf(0.0, radius)
	var min_x := int(floor((center.x - r) * _inv_bucket_size))
	var max_x := int(floor((center.x + r) * _inv_bucket_size))
	var min_y := int(floor((center.y - r) * _inv_bucket_size))
	var max_y := int(floor((center.y + r) * _inv_bucket_size))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var key := _cell_key(x, y)
			if not _buckets.has(key):
				continue
			var bucket: Array = _buckets[key]
			for enemy in bucket:
				if enemy is Node2D and is_instance_valid(enemy):
					out.append(enemy)
	return out

func get_registered_enemy_count() -> int:
	return _enemies.size()

func _bucket_key_for_world(world_pos: Vector2) -> String:
	var x := int(floor(world_pos.x * _inv_bucket_size))
	var y := int(floor(world_pos.y * _inv_bucket_size))
	return _cell_key(x, y)

func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _bucket_add_enemy(key: String, enemy: Node2D) -> void:
	var bucket: Array = _buckets.get(key, [])
	bucket.append(enemy)
	_buckets[key] = bucket

func _bucket_remove_enemy(key: String, enemy: Node2D) -> void:
	if not _buckets.has(key):
		return
	var bucket: Array = _buckets[key]
	bucket.erase(enemy)
	if bucket.is_empty():
		_buckets.erase(key)
	else:
		_buckets[key] = bucket

func _rebuild_buckets() -> void:
	_buckets.clear()
	_enemy_bucket_keys.clear()
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var id := enemy.get_instance_id()
		var key := _bucket_key_for_world(enemy.global_position)
		_enemy_bucket_keys[id] = key
		_bucket_add_enemy(key, enemy)
