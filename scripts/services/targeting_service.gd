## TargetingService — shared tower registry for hot-path scans.
##
## Replaces per-call get_nodes_in_group("placed_towers") / ("towers").
## Towers self-register in setup() and self-unregister in _exit_tree().
## This turns O(group-scan) into O(1) list access for every scan.
extends Node

var _towers: Array[Node] = []
# Instance-id set for O(1) membership checks and safe unregister.
var _tower_ids: Dictionary = {}
# Safety-prune interval — in normal play towers always unregister cleanly.
var _prune_timer: float = 0.0
const PRUNE_INTERVAL := 5.0

func register_tower(tower: Node) -> void:
	var id := tower.get_instance_id()
	if not _tower_ids.has(id):
		_tower_ids[id] = true
		_towers.append(tower)

func unregister_tower(tower: Node) -> void:
	var id := tower.get_instance_id()
	if _tower_ids.has(id):
		_tower_ids.erase(id)
		_towers.erase(tower)

## Return the live tower list. Callers must not store the reference across frames.
func get_towers() -> Array[Node]:
	return _towers

## Return all towers whose global_position is within `radius` of `center`.
func get_towers_in_radius(center: Vector2, radius: float) -> Array[Node]:
	var out: Array[Node] = []
	var r2 := radius * radius
	for tower in _towers:
		if is_instance_valid(tower) and center.distance_squared_to((tower as Node2D).global_position) <= r2:
			out.append(tower)
	return out

func _process(delta: float) -> void:
	_prune_timer += delta
	if _prune_timer < PRUNE_INTERVAL:
		return
	_prune_timer = 0.0
	# Remove any stale references (safety net; should be empty in normal flow).
	for i in range(_towers.size() - 1, -1, -1):
		if not is_instance_valid(_towers[i]):
			_tower_ids.erase(_towers[i].get_instance_id() if is_instance_valid(_towers[i]) else 0)
			_towers.remove_at(i)
