class_name EnemyProcessService
extends RefCounted

static func process(enemy: Node2D, delta: float) -> void:
	if enemy.game_manager != null and (enemy.game_manager.is_paused or enemy.game_manager.is_game_over):
		return

	if enemy.is_gallery_preview or CatalogPreviewMode.is_preview_node(enemy ):
		if not CatalogPreviewMode.is_selected_demo(enemy ):
			enemy.set_process(false)
			enemy.queue_redraw()
			return
		enemy.pulse_time += delta
		enemy.queue_redraw()
		return

	if not enemy.is_active or enemy.is_dead_flag or enemy.reached_base_flag:
		return

	enemy._anim_frame_counter += 1
	if enemy._body_baked:
		# Smart LOD: LOW priority updates every 3rd frame; HIGH every frame.
		var skip = (enemy._anim_lod == enemy.ANIM_LOD_LOW) and (enemy._anim_frame_counter % 3 != 0)
		if not skip:
			enemy._update_sprite_movement_anim()
			# Redraw overlay arcs only when something is active (shield/slow)
			if enemy.shield_remaining > 0 or enemy.active_slow_percent > 0:
				enemy.queue_redraw()
		# Separation: lazy scan + per-frame lerp. Lerp cost = ~3 floats, free.
		enemy._sep_check_timer -= delta
		if enemy._sep_check_timer <= 0.0:
			enemy._sep_check_timer = enemy.SEP_SCAN_INTERVAL + fmod(float(enemy.get_instance_id()) * 0.0370, 0.14)
			enemy._update_separation()
		enemy._sep_lateral = lerpf(enemy._sep_lateral, enemy._sep_target, minf(delta * 5.5, 1.0))
	else:
		# Non-baked gameplay enemy: gallery/preview paths already returned above.
		# draw_enemy returns immediately for these — no queue_redraw needed.
		enemy.pulse_time += delta

	if not enemy.is_active or enemy.is_dead_flag or enemy.reached_base_flag:
		return

	if enemy.swarm_core_flicker_time > 0.0:
		enemy.swarm_core_flicker_time = maxf(0.0, enemy.swarm_core_flicker_time - delta)
	if enemy.enemy_type == "swarm" or enemy.tags.has("swarm"):
		enemy.swarm_pack_check_timer -= delta
		if enemy.swarm_pack_check_timer <= 0.0:
			enemy.swarm_pack_check_timer = 0.2
			enemy._update_swarm_pack_density()
	
	# Update timers
	if enemy.slow_remaining > 0:
		enemy.slow_remaining -= delta
		if enemy.slow_remaining <= 0: enemy.clear_slow()
		
		# VISUAL: Slow particles (blue sparks)
		if not enemy.PERFORMANCE_VISUAL_MODE and Engine.get_process_frames() % 10 == 0:
			enemy._spawn_impact_particle(Color(0.4, 0.8, 1.0, 0.6))
	
	enemy._process_formation_speed(delta)
	
	if enemy.shield_remaining > 0:
		enemy.shield_remaining -= delta
		if enemy.shield_remaining <= 0:
			enemy.active_shield_reduction = 0.0
			enemy.active_shield_source = null
			enemy.enemy_modifier_changed.emit(enemy , "shield_reduction", 0.0)
			if enemy.vfx_controller:
				enemy.vfx_controller.set_protected_icon(false)
			enemy.queue_redraw()
	
	if enemy.vulnerability_remaining > 0:
		enemy.vulnerability_remaining -= delta
		if enemy.vulnerability_remaining <= 0:
			enemy.vulnerability_multiplier = 1.0
		
		# Bleed effect (blood particles)
		enemy.bleed_particle_timer -= delta
		if enemy.bleed_particle_timer <= 0:
			enemy._spawn_bleed_particle()
			enemy.bleed_particle_timer = 0.15 # Every 150ms

	if enemy.armor_reduction_remaining > 0:
		enemy.armor_reduction_remaining -= delta
		if enemy.armor_reduction_remaining <= 0:
			enemy.armor_reduction_bonus_percent = 0.0
			enemy.enemy_modifier_changed.emit(enemy , "armor_reduction", 0.0)

	if enemy.root_remaining > 0:
		enemy.root_remaining -= delta
		if enemy.root_remaining <= 0:
			enemy.root_slow_percent = 0.0
			enemy.update_effective_speed()
			enemy.enemy_modifier_changed.emit(enemy , "root", 0.0)

	enemy._dot_tick_timer -= delta
	enemy._dot_tick_accum += delta
	if enemy._dot_tick_timer <= 0.0:
		enemy._dot_tick_timer = enemy.DOT_TICK_INTERVAL
		enemy._process_tower_status_effects(enemy._dot_tick_accum)
		enemy._dot_tick_accum = 0.0

	# Skill Logic
	if enemy.skill_id != "":
		enemy.skill_timer -= delta
		match enemy.skill_id:
			"shield_aura":
				# Interval-gated: was scanning ALL enemies every frame (O(n) per bulwark).
				enemy._shield_aura_timer -= delta
				if enemy._shield_aura_timer <= 0.0:
					enemy._shield_aura_timer = enemy.SHIELD_AURA_INTERVAL
					enemy._process_shield_aura()
			"healer":
				if enemy.skill_timer <= 0:
					enemy._process_healer_aura()
					enemy.skill_timer = enemy.skill_params.get("interval", 1.0)
			"disrupt_aura":
				# Interval-gated: was scanning ALL towers every frame (O(m) per disruptor).
				enemy._disrupt_aura_timer -= delta
				if enemy._disrupt_aura_timer <= 0.0:
					enemy._disrupt_aura_timer = enemy.DISRUPT_AURA_INTERVAL
					enemy._process_disrupt_aura()

	# Archetype Logic (Legacy)
	if enemy.is_bulwark and enemy.skill_id == "":
		enemy._shield_aura_timer -= delta
		if enemy._shield_aura_timer <= 0.0:
			enemy._shield_aura_timer = enemy.SHIELD_AURA_INTERVAL
			enemy._process_shield_aura()
		
	if enemy.is_runner:
		enemy._process_runner_role(delta)

	if enemy.is_hunter:
		enemy._process_hunter_ai(delta)
	else:
		enemy._process_pathing(delta)

