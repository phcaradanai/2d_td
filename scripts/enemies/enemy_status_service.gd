class_name EnemyStatusService
extends RefCounted

static func apply_shield(enemy: Node2D, duration: float, reduction: float, source: Variant = null) -> void:
	if enemy.shield_remaining <= 0:
		enemy.queue_redraw()
	enemy.shield_remaining = max(enemy.shield_remaining, duration)
	enemy.active_shield_reduction = clampf(reduction, 0.0, 0.9)
	enemy.active_shield_source = source
	enemy.enemy_modifier_changed.emit(enemy, "shield_reduction", enemy.active_shield_reduction)
	if enemy.vfx_controller:
		enemy.vfx_controller.set_protected_icon(enemy.active_shield_reduction > 0.0)

static func apply_vulnerability(enemy: Node2D, multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	if multiplier >= enemy.vulnerability_multiplier:
		enemy.vulnerability_multiplier = multiplier
		enemy.vulnerability_remaining = duration
	elif duration > enemy.vulnerability_remaining and multiplier == enemy.vulnerability_multiplier:
		enemy.vulnerability_remaining = duration

static func apply_damage_amp(enemy: Node2D, multiplier: float, duration: float) -> void:
	EnemyStatusService.apply_vulnerability(enemy, multiplier, duration)

static func apply_armor_reduction(enemy: Node2D, percent: float, duration: float) -> void:
	if duration <= 0.0 or percent <= 0.0:
		return
	if percent >= enemy.armor_reduction_bonus_percent:
		enemy.armor_reduction_bonus_percent = percent
		enemy.armor_reduction_remaining = duration
		enemy.enemy_modifier_changed.emit(enemy, "armor_reduction", percent)
	elif duration > enemy.armor_reduction_remaining and is_equal_approx(percent, enemy.armor_reduction_bonus_percent):
		enemy.armor_reduction_remaining = duration

static func apply_damage_over_time(enemy: Node2D, damage_per_second: float, duration: float, source_id: String = "", attack_type: String = "dot") -> void:
	if damage_per_second <= 0.0 or duration <= 0.0:
		return
	enemy.active_dot_effects.append({
		"damage_per_second": damage_per_second,
		"remaining": duration,
		"source_id": source_id,
		"attack_type": attack_type
	})

static func apply_root(enemy: Node2D, duration: float, snare_percent: float = 1.0) -> void:
	if duration <= 0.0:
		return
	var clamped_percent := clampf(snare_percent, 0.0, 1.0)
	if clamped_percent >= enemy.root_slow_percent:
		enemy.root_slow_percent = clamped_percent
		enemy.root_remaining = duration
		EnemyStatusService.update_effective_speed(enemy)
		enemy.enemy_modifier_changed.emit(enemy, "root", clamped_percent)
	elif duration > enemy.root_remaining and is_equal_approx(clamped_percent, enemy.root_slow_percent):
		enemy.root_remaining = duration

static func apply_delayed_damage(enemy: Node2D, amount: float, delay: float, source_id: String = "", attack_type: String = "delayed") -> void:
	if amount <= 0.0:
		return
	enemy.delayed_damage_effects.append({
		"amount": amount,
		"remaining": maxf(0.0, delay),
		"source_id": source_id,
		"attack_type": attack_type
	})

static func apply_slow(enemy: Node2D, percent: float, duration: float) -> void:
	if percent >= enemy.active_slow_percent:
		enemy.active_slow_percent = percent
		enemy.status_speed_multiplier = max(1.0 - enemy.active_slow_percent, 0.25)
		enemy.slow_remaining = duration
		EnemyStatusService.update_effective_speed(enemy)
	elif duration > enemy.slow_remaining and percent == enemy.active_slow_percent:
		enemy.slow_remaining = duration

static func clear_slow(enemy: Node2D) -> void:
	enemy.active_slow_percent = 0.0
	enemy.slow_remaining = 0.0
	EnemyStatusService.update_effective_speed(enemy)

static func update_effective_speed(enemy: Node2D) -> void:
	var slow_multiplier: float = max(1.0 - enemy.active_slow_percent, 0.25)
	var root_multiplier: float = max(1.0 - enemy.root_slow_percent, 0.25)
	enemy.status_speed_multiplier = min(slow_multiplier, root_multiplier)
	var runner_multiplier := 1.0
	if enemy.is_runner:
		if enemy.runner_panic_active:
			runner_multiplier *= enemy.runner_panic_speed_multiplier
		if enemy.runner_dash_remaining > 0.0:
			runner_multiplier *= enemy.runner_dash_speed_multiplier
	enemy.speed = enemy.base_speed * enemy.formation_speed_multiplier * enemy.status_speed_multiplier * runner_multiplier

static func _process_tower_status_effects(enemy: Node2D, delta: float) -> void:
	if enemy.CatalogPreviewMode.is_preview_node(enemy):
		return
	if not enemy.active_dot_effects.is_empty():
		var expired_dot_indexes: Array[int] = []
		for i in range(enemy.active_dot_effects.size()):
			var effect: Dictionary = enemy.active_dot_effects[i]
			var remaining := float(effect.get("remaining", 0.0))
			var tick_delta := minf(delta, remaining)
			if tick_delta > 0.0:
				var damage_per_second := float(effect.get("damage_per_second", 0.0))
				var source := str(effect.get("source_id", ""))
				var attack_type := str(effect.get("attack_type", "dot"))
				enemy.take_damage(damage_per_second * tick_delta, enemy.global_position, source, attack_type)
			remaining -= delta
			if remaining <= 0.0:
				expired_dot_indexes.append(i)
			else:
				effect["remaining"] = remaining
				enemy.active_dot_effects[i] = effect
		for j in range(expired_dot_indexes.size() - 1, -1, -1):
			enemy.active_dot_effects.remove_at(expired_dot_indexes[j])

	if not enemy.delayed_damage_effects.is_empty():
		var triggered_indexes: Array[int] = []
		for i in range(enemy.delayed_damage_effects.size()):
			var effect: Dictionary = enemy.delayed_damage_effects[i]
			var remaining := float(effect.get("remaining", 0.0)) - delta
			if remaining <= 0.0:
				enemy.take_damage(float(effect.get("amount", 0.0)), enemy.global_position, str(effect.get("source_id", "")), str(effect.get("attack_type", "delayed")))
				triggered_indexes.append(i)
			else:
				effect["remaining"] = remaining
				enemy.delayed_damage_effects[i] = effect
		for j in range(triggered_indexes.size() - 1, -1, -1):
			enemy.delayed_damage_effects.remove_at(triggered_indexes[j])
