class_name EnemySkillService
extends RefCounted

static func _process_shield_aura(enemy: Node2D) -> void:
	if enemy.CatalogPreviewMode.is_preview_node(enemy):
		return
	var radius = float(enemy.skill_params.get("radius", enemy.shield_radius))
	var reduction = EnemySkillService._get_skill_reduction(enemy)
	var pb: Node = enemy.get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = pb.get_enemies() if pb else enemy.get_tree().get_nodes_in_group("enemies")
	for other in enemies:
		if other != enemy and is_instance_valid(other) and other.has_method("apply_shield"):
			if other.has_method("is_alive") and not other.is_alive():
				continue
			if enemy.global_position.distance_to(other.global_position) <= radius:
				other.apply_shield(0.25, reduction, enemy) # Short duration, refreshed by aura

static func _get_skill_reduction(enemy: Node2D) -> float:
	var raw = enemy.skill_params.get("reduction", enemy.skill_params.get("shield_reduction", enemy.shield_reduction))
	return clampf(float(raw), 0.0, 0.9)

static func _process_healer_aura(enemy: Node2D) -> void:
	if enemy.CatalogPreviewMode.is_preview_node(enemy):
		return
	var radius = float(enemy.skill_params.get("radius", 100.0))
	var amount = float(enemy.skill_params.get("heal_amount", 5.0))
	var pb: Node = enemy.get_node_or_null("/root/PerformanceBudget")
	var enemies: Array = pb.get_enemies() if pb else enemy.get_tree().get_nodes_in_group("enemies")
	var healed_targets: Array = []
	for other in enemies:
		if other != enemy and is_instance_valid(other) and other.has_method("heal"):
			if other.has_method("is_alive") and not other.is_alive():
				continue
			if enemy.global_position.distance_to(other.global_position) <= radius:
				var hp_before := float(other.get_current_hp()) if other.has_method("get_current_hp") else 0.0
				var applied := float(other.heal(amount, enemy))
				if applied > 0.0:
					var hp_after := float(other.get_current_hp()) if other.has_method("get_current_hp") else hp_before + applied
					healed_targets.append(other)
					enemy.healed.emit(other, applied, enemy)
					enemy.enemy_healed.emit(other, enemy, applied, hp_before, hp_after)
					enemy.enemy_modifier_changed.emit(other, "healed", applied)
					if OS.is_debug_build() and enemy._verbose_combat:
						print("[EnemyFeature][Healer] source=%s target=%s amount=%.1f hp=%.1f/%.1f" % [
							enemy.enemy_type,
							other.get_enemy_type() if other.has_method("get_enemy_type") else str(other.name),
							applied,
							float(other.get_current_hp()) if other.has_method("get_current_hp") else 0.0,
							float(other.max_hp) if "max_hp" in other else 0.0
						])
	if not healed_targets.is_empty():
		enemy.healer_heal_tick.emit(enemy, healed_targets, amount)

static func _process_disrupt_aura(enemy: Node2D) -> void:
	if enemy.CatalogPreviewMode.is_preview_node(enemy):
		return
	var radius = float(enemy.skill_params.get("radius", 150.0))
	var penalty = clampf(float(enemy.skill_params.get("fire_rate_penalty", 0.5)), 0.05, 1.0)
	var _ts_dis := enemy.get_node_or_null("/root/TargetingService")
	var towers: Array = _ts_dis.get_towers() if _ts_dis else enemy.get_tree().get_nodes_in_group("towers")
	var currently_affected: Array[Node] = []
	for tower in towers:
		if not is_instance_valid(tower) or not tower.has_method("apply_fire_rate_modifier"):
			continue
		if enemy.global_position.distance_to(tower.global_position) <= radius:
			tower.apply_fire_rate_modifier(enemy, penalty)
			currently_affected.append(tower)
			enemy.disrupted_towers[tower.get_instance_id()] = tower
			enemy.disrupted_tower.emit(tower, penalty, enemy)
			if OS.is_debug_build() and enemy._verbose_combat:
				var effective = tower.get_effective_fire_rate() if tower.has_method("get_effective_fire_rate") else 0.0
				print("[EnemyFeature][Disruptor] source=%s tower=%s penalty=%.2f effective_interval=%.2f" % [enemy.enemy_type, str(tower.name), penalty, effective])
	for key in enemy.disrupted_towers.keys():
		var tower = enemy.disrupted_towers[key]
		if not is_instance_valid(tower) or not currently_affected.has(tower):
			if is_instance_valid(tower) and tower.has_method("remove_fire_rate_modifier"):
				tower.remove_fire_rate_modifier(enemy)
				enemy.disruption_removed.emit(tower, enemy)
			enemy.disrupted_towers.erase(key)
	if enemy.vfx_controller:
		enemy.vfx_controller.update_disrupted_towers(currently_affected)

static func _handle_split_on_death(enemy: Node2D, _death_pos: Vector2) -> void:
	if enemy.split_triggered_once:
		return
	enemy.split_triggered_once = true
	var count = enemy.skill_params.get("count", 2)
	var type = enemy.skill_params.get("type", "basic")
	enemy.split_triggered.emit(enemy, type, count)
	if enemy.vfx_controller:
		enemy.vfx_controller.play_split_burst(str(type), int(count))

	var wave_manager = enemy.get_tree().current_scene.get_node_or_null("WaveManager")
	if wave_manager and wave_manager.has_method("spawn_enemy_at_progress"):
		for i in range(count):
			var offset := Vector2((i - (count - 1) / 2.0) * 12.0, 0.0)
			if enemy.use_dynamic_pathing and wave_manager.has_method("spawn_enemy_at_world_position"):
				wave_manager.spawn_enemy_at_world_position(type, enemy.global_position + offset)
			else:
				var offset_prog = (i - (count - 1) / 2.0) * 20.0
				wave_manager.spawn_enemy_at_progress(type, enemy.progress + offset_prog, enemy.get_parent())

static func notify_stealth_deferred(enemy: Node2D, preferred_target: Node) -> void:
	enemy.stealth_targeting_deferred.emit(enemy, preferred_target)
	if enemy.vfx_controller:
		enemy.vfx_controller.mark_cloaked_deferred(preferred_target)
	if OS.is_debug_build() and enemy._verbose_combat:
		print("[EnemyFeature][Cloaked] deferred=%s preferred=%s" % [enemy.enemy_type, preferred_target.get_enemy_type() if preferred_target and preferred_target.has_method("get_enemy_type") else str(preferred_target)])

static func notify_stealth_targetable(enemy: Node2D) -> void:
	if enemy.vfx_controller:
		enemy.vfx_controller.mark_cloaked_targetable()

static func _clear_disrupted_towers(enemy: Node2D) -> void:
	for key in enemy.disrupted_towers.keys():
		var tower = enemy.disrupted_towers[key]
		if is_instance_valid(tower) and tower.has_method("remove_fire_rate_modifier"):
			tower.remove_fire_rate_modifier(enemy)
			enemy.disruption_removed.emit(tower, enemy)
	enemy.disrupted_towers.clear()
	if enemy.vfx_controller:
		enemy.vfx_controller.clear_all_disrupted_towers()
