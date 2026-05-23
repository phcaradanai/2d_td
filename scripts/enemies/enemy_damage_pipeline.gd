class_name EnemyDamagePipeline
extends RefCounted

static func take_damage(enemy: Node2D, amount: float, hit_global: Vector2 = Vector2.ZERO, source_id: String = "", p_attack_type: String = "single") -> void:
	if CatalogPreviewMode.is_preview_node(enemy ):
		return
	if enemy.is_dead_flag or enemy.reached_base_flag: return
	
	if source_id != "":
		enemy.last_damage_source = source_id
	
	var final_damage = amount
	if enemy.is_runner and enemy.runner_dash_remaining > 0.0:
		final_damage *= (1.0 - enemy.runner_dash_damage_reduction)
		enemy._spawn_impact_particle(Color(1.0, 0.48, 0.08, 0.35))
	if enemy.shield_remaining > 0 and not enemy.is_bulwark:
		var shielded_damage: float = final_damage * (1.0 - enemy.active_shield_reduction)
		enemy.shield_applied.emit(enemy , final_damage, shielded_damage, enemy.active_shield_source)
		final_damage = shielded_damage
		if OS.is_debug_build() and enemy._verbose_combat:
			print("[EnemyFeature][Shield] target=%s source=%s original=%.1f final=%.1f reduction=%.2f" % [
				enemy.enemy_type,
				enemy.active_shield_source.get_enemy_type() if enemy.active_shield_source and enemy.active_shield_source.has_method("get_enemy_type") else "unknown",
				amount,
				final_damage,
				enemy.active_shield_reduction
			])
			
	var capture_pos = hit_global if hit_global != Vector2.ZERO else enemy.global_position
	
	# Apply vulnerability
	if enemy.vulnerability_remaining > 0:
		final_damage *= enemy.vulnerability_multiplier
	if enemy.armor_reduction_remaining > 0:
		final_damage *= 1.0 + enemy.armor_reduction_bonus_percent
		
	enemy.hp -= final_damage
	enemy._update_health_visual_state()
	
	var gm = enemy.get_tree().current_scene.get_node_or_null("GameManager")
	if gm and gm.battle_telemetry:
		gm.battle_telemetry.log_damage(source_id, final_damage, p_attack_type, enemy.enemy_type)
	var damage_stats := enemy.get_tree().current_scene.get_node_or_null("DamageStatsTracker")
	if damage_stats and damage_stats.has_method("record_damage"):
		damage_stats.record_damage(source_id, final_damage)
		
	enemy.flash_body(source_id if source_id != "" else p_attack_type)
	var dn_color = Color.WHITE
	if enemy.shield_remaining > 0 and not enemy.is_bulwark:
		dn_color = Color(0.4, 0.8, 1.0)
	elif source_id.begins_with("disease_"):
		dn_color = Color(0.58, 1.0, 0.28)

	enemy.spawn_damage_number(int(final_damage), capture_pos, dn_color, source_id)
	EnemyHitFeedbackService._play_hit_pulse(enemy )
	if enemy._body_baked:
		# One heavy impact path only. enemy.flash_body() resolves comfort colour/LOD;
		# this call owns the baked-sprite tween so rapid hits cannot double-trigger it.
		var impact_color: Color = enemy.hit_flash_color if enemy.hit_flash_color.a > 0.0 else dn_color
		if dn_color != Color.WHITE:
			impact_color = dn_color
		EnemyHitFeedbackService._play_sprite_hit_impact(enemy , impact_color)
		# Hit spark: tiny burst at impact point — replaces screen shake as impact cue.
		EnemyHitFeedbackService._spawn_hit_spark(enemy , capture_pos, dn_color)
	enemy._try_runner_hit_dash()
	if enemy.enemy_type == "swarm" or enemy.tags.has("swarm"):
		EnemyHitFeedbackService._trigger_swarm_hit_reaction(enemy )
		EnemyHitFeedbackService._spawn_swarm_hit_effect(enemy , capture_pos)
	
	if enemy.hp <= 0:
		enemy.die(capture_pos)

