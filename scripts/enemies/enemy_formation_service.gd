class_name EnemyFormationService
extends RefCounted

static func _configure_formation_speed(enemy: Node2D) -> void:
	if enemy.formation_speed_limit > 0.0 and enemy.formation_limit_duration > 0.0 and enemy.base_speed > 0.0:
		enemy.formation_target_multiplier = clampf(enemy.formation_speed_limit / enemy.base_speed, 0.25, 1.0)
		enemy.formation_speed_multiplier = enemy.formation_target_multiplier
	elif enemy.formation_limit_duration > 0.0 and enemy.formation_config_multiplier < 1.0:
		enemy.formation_target_multiplier = clampf(enemy.formation_config_multiplier, 0.25, 1.0)
		enemy.formation_speed_multiplier = enemy.formation_target_multiplier
	else:
		enemy.formation_target_multiplier = 1.0
		enemy.formation_speed_multiplier = 1.0
	if enemy.formation_speed_multiplier < 1.0:
		enemy.enemy_modifier_changed.emit(enemy , "formation_speed_multiplier", enemy.formation_speed_multiplier)


static func _process_formation_speed(enemy: Node2D, delta: float) -> void:
	if enemy.formation_limit_duration > 0.0:
		enemy.formation_limit_duration -= delta
		if enemy.formation_limit_duration <= 0.0:
			enemy.formation_limit_duration = 0.0
			enemy.formation_target_multiplier = 1.0
			enemy.enemy_modifier_changed.emit(enemy , "formation_speed_multiplier", enemy.formation_target_multiplier)
			if enemy.vfx_controller and (enemy.tags.has("fast") or enemy.tags.has("runner") or enemy.enemy_type in ["fast", "runner", "hunter", "fast_flyer"]):
				enemy.vfx_controller.play_runner_burst()
			if OS.is_debug_build() and enemy._verbose_combat:
				print("[SpawnFormation] release throttle enemy=%s enemy.base_speed=%.1f effective_speed=%.1f" % [enemy.enemy_type, enemy.base_speed, enemy.speed])
	if enemy.formation_speed_multiplier != enemy.formation_target_multiplier:
		if enemy.formation_speed_multiplier > enemy.formation_target_multiplier:
			enemy.formation_speed_multiplier = enemy.formation_target_multiplier
		else:
			enemy.formation_speed_multiplier = move_toward(enemy.formation_speed_multiplier, enemy.formation_target_multiplier, enemy.formation_release_rate * delta)
		enemy.update_effective_speed()


