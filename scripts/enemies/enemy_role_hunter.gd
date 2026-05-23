class_name EnemyRoleHunter
extends RefCounted

static func _process_hunter_ai(enemy: Node2D, delta: float) -> void:
	enemy.hunter_attack_timer = maxf(0.0, enemy.hunter_attack_timer - delta)
	enemy.hunter_scan_rotation += delta * 2.8
	if enemy.hunter_state != enemy.HunterState.PATHING:
		enemy.hunter_lock_fx_time += delta
	else:
		enemy.hunter_lock_fx_time = maxf(0.0, enemy.hunter_lock_fx_time - delta * 3.0)

	EnemyRoleHunter._update_hunter_target(enemy)

	if enemy.hunter_target != null and is_instance_valid(enemy.hunter_target):
		var dist := enemy.global_position.distance_to(enemy.hunter_target.global_position)
		if dist <= enemy.hunter_attack_range:
			enemy.hunter_state = enemy.HunterState.AGGRO_ATTACKING
			EnemyRoleHunter._face_hunter_target(enemy, enemy.hunter_target.global_position, delta)
			EnemyRoleHunter._attack_hero(enemy, enemy.hunter_target)
			return

		enemy.hunter_state = enemy.HunterState.AGGRO_CHASING
		EnemyRoleHunter._move_toward_hero(enemy, enemy.hunter_target.global_position, delta)
		return

	if enemy.hunter_state != enemy.HunterState.PATHING:
		if OS.is_debug_build(): print("[HunterAI] return_to_path reason=no_valid_hero")
	EnemyRoleHunter._clear_hunter_target(enemy)
	enemy._process_pathing(delta)

static func _update_hunter_target(enemy: Node2D) -> void:
	if enemy.hunter_target != null:
		if EnemyRoleHunter._is_hero_huntable(enemy, enemy.hunter_target) and enemy.global_position.distance_to(enemy.hunter_target.global_position) <= enemy.aggro_range:
			return
		EnemyRoleHunter._clear_hunter_target(enemy)

	var nearest_hero: Node2D = null
	var nearest_dist := INF
	var heroes = enemy.get_tree().get_nodes_in_group("heroes")
	for hero_node in heroes:
		if not (hero_node is Node2D):
			continue
		var hero := hero_node as Node2D
		if not EnemyRoleHunter._is_hero_huntable(enemy, hero):
			continue
		var dist := enemy.global_position.distance_to(hero.global_position)
		if dist <= enemy.aggro_range and dist < nearest_dist:
			nearest_dist = dist
			nearest_hero = hero

	if nearest_hero != null:
		if enemy.hunter_state == enemy.HunterState.PATHING and OS.is_debug_build() and enemy._verbose_combat:
			print("[HunterAI] aggro hero distance=%.1f" % nearest_dist)
		enemy.hunter_target = nearest_hero
	else:
		enemy.hunter_state = enemy.HunterState.PATHING

static func _is_hero_huntable(enemy: Node2D, hero: Node) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	if hero.has_method("is_alive"):
		return hero.is_alive()
	var active_value = hero.get("is_active")
	if active_value != null:
		return bool(active_value)
	return true

static func _clear_hunter_target(enemy: Node2D) -> void:
	enemy.hunter_target = null
	enemy.hunter_state = enemy.HunterState.PATHING

static func _move_toward_hero(enemy: Node2D, target_pos: Vector2, delta: float) -> void:
	var to_target: Vector2 = target_pos - Vector2(enemy.global_position)
	if to_target.length_squared() <= 1.0:
		return
	var dir: Vector2 = to_target.normalized()
	var move_delta: Vector2 = dir * float(enemy.speed) * float(enemy.hunter_chase_speed_multiplier) * delta
	enemy.global_position += move_delta
	enemy._record_visual_movement_delta(move_delta)
	EnemyRoleHunter._face_hunter_target(enemy, target_pos, delta)

static func _face_hunter_target(enemy: Node2D, _target_pos: Vector2, _delta: float) -> void:
	enemy._lock_visual_orientation()

static func _attack_hero(enemy: Node2D, hero: Node) -> void:
	if enemy.hunter_attack_timer > 0.0:
		return
	if not EnemyRoleHunter._is_hero_huntable(enemy, hero):
		EnemyRoleHunter._clear_hunter_target(enemy)
		return

	if hero.has_method("take_damage"):
		hero.take_damage(enemy.hunter_attack_damage)
		enemy.hunter_attack_timer = enemy.hunter_attack_cooldown
		enemy._spawn_impact_particle(Color(1.0, 0.25, 0.08, 0.75))
		if OS.is_debug_build(): print("[HunterAI] attack_hero damage=%.1f" % enemy.hunter_attack_damage)

	if not EnemyRoleHunter._is_hero_huntable(enemy, hero):
		EnemyRoleHunter._clear_hunter_target(enemy)
