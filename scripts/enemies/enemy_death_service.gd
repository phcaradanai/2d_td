class_name EnemyDeathService
extends RefCounted

static func _get_death_burst_color(enemy: Node2D) -> Color:
	if enemy.enemy_type == "boss" or enemy.tags.has("boss"):
		return Color(1.00, 0.85, 0.10, 1.0)  # gold
	match enemy.visual_type:
		"basic":        return Color(0.20, 0.80, 1.00, 1.0)
		"fast":         return Color(0.00, 1.00, 0.70, 1.0)
		"tank":         return Color(1.00, 0.45, 0.10, 1.0)
		"bulwark":      return Color(0.10, 0.60, 1.00, 1.0)
		"hunter":       return Color(1.00, 0.10, 0.40, 1.0)
		"healer":       return Color(0.40, 1.00, 0.60, 1.0)
		"disruptor":    return Color(1.00, 0.55, 0.15, 1.0)
		"splitter":     return Color(0.90, 0.45, 1.00, 1.0)
		"shieldbearer": return Color(0.35, 0.90, 1.00, 1.0)
		"runner":       return Color(0.15, 1.00, 0.50, 1.0)
		"cloaked":      return Color(0.75, 0.75, 1.00, 1.0)
		"flyer":        return Color(0.45, 0.90, 1.00, 1.0)
		"fast_flyer":   return Color(0.00, 0.90, 0.60, 1.0)
		"armored_flyer":return Color(1.00, 0.60, 0.20, 1.0)
	return Color(0.70, 0.85, 1.00, 1.0)

static func _get_death_importance(enemy: Node2D) -> float:
	if enemy.enemy_type == "boss" or enemy.tags.has("boss"):
		return 4.0  # max importance — largest burst, strongest shake
	var hp_tier := clampf(enemy.max_hp / 80.0, 1.0, 4.0)
	match enemy.visual_type:
		"tank","bulwark","armored_flyer": return clampf(hp_tier * 1.4, 1.8, 4.0)
		"splitter","healer","disruptor":  return clampf(hp_tier * 1.1, 1.2, 3.0)
	return clampf(hp_tier, 1.0, 2.5)

static func _trigger_death_shake(enemy: Node2D) -> void:
	var main := enemy.get_tree().current_scene
	if not main.has_method("shake_camera"):
		return
	var imp := EnemyDeathService._get_death_importance(enemy)
	var strength := clampf(imp * 1.8, 1.0, 6.0)
	main.shake_camera(strength, 0.8)

static func spawn_death_effect(enemy: Node2D, death_global: Vector2) -> void:
	EnemyDeathService._trigger_death_shake(enemy)
	if not PerformanceFirebreak.disable_death_effects:
		if enemy.death_pop_scene:
			var pool := enemy.get_node_or_null("/root/VisualEffectPoolService")
			var effect: Node = null
			if pool != null and pool.has_method("acquire_scene"):
				effect = pool.acquire_scene("death_pop", enemy.get_tree().current_scene, "death_pop")
			if effect == null:
				return
			var imp := EnemyDeathService._get_death_importance(enemy)
			effect.global_position = death_global
			effect.scale = Vector2.ONE * clampf(imp * 0.72, 0.72, 2.2)
			if effect.has_method("setup"):
				if enemy.enemy_type == "swarm" or enemy.tags.has("swarm"):
					effect.setup("swarm_death", enemy.swarm_core_glow_color, 0.32, enemy.swarm_death_particle_count)
				else:
					var burst_color := EnemyDeathService._get_death_burst_color(enemy)
					var particles  := clampi(int(imp * 4.0), 4, 10)
					var dur        := clampf(0.25 + imp * 0.06, 0.25, 0.42)
					effect.setup("default", burst_color, dur, particles)

static func reach_base(enemy: Node2D) -> void:
	if enemy.reached_base_flag: return
	enemy.reached_base_flag = true
	enemy.is_active = false

	var leak_damage: int = enemy.base_damage if enemy.can_leak else 0
	enemy.reached_base.emit(enemy, leak_damage, enemy.global_position)
	enemy.queue_free()

static func die(enemy: Node2D, death_global: Vector2 = Vector2.ZERO) -> void:
	if enemy.is_dead_flag: return
	enemy.is_dead_flag = true
	enemy.is_active = false
	if enemy.has_method("_play_sprite_death"):
		enemy._play_sprite_death()
	enemy._clear_disrupted_towers()
	if enemy.vfx_controller:
		enemy.vfx_controller.fade_out()
	
	var gm = enemy.get_tree().current_scene.get_node_or_null("GameManager")
	if gm and gm.battle_telemetry and not enemy.is_illusion:
		gm.battle_telemetry.log_enemy_kill(enemy.last_damage_source, enemy.enemy_type)
		
	var capture_pos = death_global if death_global != Vector2.ZERO else enemy.global_position
	EnemyDeathService.spawn_death_effect(enemy, capture_pos)
	
	if enemy.skill_id == "split_on_death":
		enemy._handle_split_on_death(capture_pos)

	if enemy.affix_service and enemy.affix_service.has_method("on_enemy_death"):
		enemy.affix_service.on_enemy_death(enemy, capture_pos)

	var gold_reward: int = enemy.reward_gold if enemy.gives_gold else 0
	enemy.died.emit(enemy, gold_reward)
	enemy.queue_free()
