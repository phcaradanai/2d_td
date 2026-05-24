class_name EnemyRoleRunner
extends RefCounted

static func _configure_runner_role(enemy: Node2D, config: Dictionary) -> void:
	var params: Dictionary = config.get("skill_params", {})
	enemy.runner_dash_cooldown = float(config.get("runner_dash_cooldown", params.get("dash_cooldown", enemy.runner_dash_cooldown)))
	enemy.runner_dash_timer = float(config.get("runner_initial_dash_delay", params.get("initial_dash_delay", minf(enemy.runner_dash_timer, enemy.runner_dash_cooldown))))
	enemy.runner_dash_duration = float(config.get("runner_dash_duration", params.get("dash_duration", enemy.runner_dash_duration)))
	enemy.runner_dash_speed_multiplier = float(config.get("runner_dash_speed_multiplier", params.get("dash_speed_multiplier", enemy.runner_dash_speed_multiplier)))
	enemy.runner_dash_damage_reduction = clampf(float(config.get("runner_dash_damage_reduction", params.get("dash_damage_reduction", enemy.runner_dash_damage_reduction))), 0.0, 0.85)
	enemy.runner_panic_threshold = clampf(float(config.get("runner_panic_threshold", params.get("panic_threshold", enemy.runner_panic_threshold))), 0.05, 0.95)
	enemy.runner_panic_speed_multiplier = float(config.get("runner_panic_speed_multiplier", params.get("panic_speed_multiplier", enemy.runner_panic_speed_multiplier)))
	enemy.runner_base_speed_scale = clampf(float(config.get("runner_base_speed_scale", params.get("base_speed_scale", enemy.runner_base_speed_scale))), 0.55, 1.15)
	if not enemy.tags.has("runner"):
		enemy.tags.append("runner")

static func _process_runner_role(enemy: Node2D, delta: float) -> void:
	if not enemy.is_runner:
		return

	var hp_ratio: float = enemy.hp / maxf(enemy.max_hp, 1.0)
	if not enemy.runner_panic_active and hp_ratio <= enemy.runner_panic_threshold:
		enemy.runner_panic_active = true
		if enemy.vfx_controller:
			enemy.vfx_controller.play_runner_burst()
		enemy._spawn_impact_particle(Color(1.0, 0.24, 0.06, 0.72))
		enemy.enemy_modifier_changed.emit(enemy, "runner_panic", enemy.runner_panic_speed_multiplier)
		enemy.update_effective_speed()

	if enemy.runner_dash_remaining > 0.0:
		enemy.runner_dash_remaining = maxf(0.0, enemy.runner_dash_remaining - delta)
		if enemy.runner_dash_remaining <= 0.0:
			enemy.enemy_modifier_changed.emit(enemy, "runner_dash", 1.0)
			enemy.update_effective_speed()
	else:
		enemy.runner_dash_timer -= delta
		if enemy.runner_dash_timer <= 0.0:
			EnemyRoleRunner._trigger_runner_dash(enemy, "cooldown")

static func _trigger_runner_dash(enemy: Node2D, reason: String = "burst") -> void:
	if not enemy.is_runner or enemy.is_dead_flag or enemy.reached_base_flag:
		return
	enemy.runner_dash_remaining = enemy.runner_dash_duration
	enemy.runner_dash_timer = enemy.runner_dash_cooldown
	enemy.update_effective_speed()
	EnemyAudioService.play_dash(enemy)
	if enemy.vfx_controller:
		enemy.vfx_controller.play_runner_burst()
	enemy._spawn_impact_particle(Color(1.0, 0.46, 0.08, 0.56))
	enemy.enemy_modifier_changed.emit(enemy, "runner_dash", enemy.runner_dash_speed_multiplier)
	if OS.is_debug_build() and enemy._verbose_combat:
		print("[RunnerRole] dash reason=%s speed=%.1f reduction=%.2f" % [reason, enemy.speed, enemy.runner_dash_damage_reduction])

static func _try_runner_hit_dash(enemy: Node2D) -> void:
	if not enemy.is_runner or enemy.runner_dash_remaining > 0.0:
		return
	if enemy.runner_dash_timer <= enemy.runner_dash_cooldown * 0.25:
		EnemyRoleRunner._trigger_runner_dash(enemy, "hit")
