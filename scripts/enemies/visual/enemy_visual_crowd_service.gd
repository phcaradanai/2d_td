class_name EnemyVisualCrowdService
extends RefCounted

static func _update_separation(enemy: Node2D) -> void:
	var push := 0.0
	var pb := enemy.get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = (pb.get_enemies() if pb != null and pb.has_method("get_enemies")
						 else enemy.get_tree().get_nodes_in_group("enemies"))
	var my_pos := enemy.global_position
	var my_prog = enemy.get_path_progress()
	for other in enemies:
		if other == enemy or not is_instance_valid(other): continue
		var op: Vector2 = other.global_position
		var dx := op.x - my_pos.x
		var dy := op.y - my_pos.y
		if dx * dx + dy * dy > enemy.SEP_SCAN_RADIUS_SQ: continue # world-distance guard
		if not other.has_method("get_path_progress"): continue
		if absf(my_prog - other.get_path_progress()) > 32.0: continue # far on path
		# Determine push direction — must differ between the two enemies in a pair
		var other_lat: float = float(other.get("_sep_lateral"))
		var gap = enemy._sep_lateral - other_lat
		var push_dir: float
		if absf(gap) > 2.0:
			push_dir = signf(gap) # already separated: reinforce it
		else:
			# Tie-break via relative instance IDs — guarantees opposite dirs per pair
			push_dir = 1.0 if enemy.get_instance_id() > other.get_instance_id() else -1.0
		var dist_sq := dx * dx + dy * dy
		push += push_dir * enemy.SEP_PUSH_MAX * (1.0 - dist_sq / enemy.SEP_SCAN_RADIUS_SQ)
	# Decay toward 0 when alone; clamp to road half-width
	if absf(push) < 0.1:
		push = enemy._sep_target * -0.25 # gentle return to center when isolated
	enemy._sep_target = clampf(push, -enemy.SEP_ROAD_HALF, enemy.SEP_ROAD_HALF)


static func _get_nearby_enemy_count(enemy: Node2D, radius: float) -> int:
	var frame := Engine.get_process_frames()
	if enemy._crowd_cache_frame == frame:
		return enemy._crowd_cache_count
	var count := 0
	var radius_sq := radius * radius
	var pb: Node = enemy.get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = pb.get_enemies() if pb != null and pb.has_method("get_enemies") else enemy.get_tree().get_nodes_in_group("enemies")
	var ep := enemy.global_position
	for e in enemies:
		if e == enemy or not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var op: Vector2 = e.global_position
		var dx := op.x - ep.x
		var dy := op.y - ep.y
		if dx * dx + dy * dy <= radius_sq:
			count += 1
			if count >= enemy.CROWDED_ENEMY_THRESHOLD:
				break
	enemy._crowd_cache_frame = frame
	enemy._crowd_cache_count = count
	return count

## Death pop — instant scale burst + fade before queue_free fires.

static func _update_swarm_pack_density(enemy: Node2D) -> void:
	var nearby := 0
	var pb: Node = enemy.get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = pb.get_enemies() if pb != null and pb.has_method("get_enemies") else enemy.get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		if node == enemy:
			continue
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var node_tags: Array = node.get("tags")
		if str(node.get("enemy_type")) != "swarm" and not node_tags.has("swarm"):
			continue
		var other := node as Node2D
		if enemy.global_position.distance_to(other.global_position) <= 42.0:
			nearby += 1
			if nearby >= 6:
				break
	enemy.swarm_pack_density = clampf(float(nearby) / 6.0, 0.0, 1.0)


