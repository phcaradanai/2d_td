class_name EnemySetupService
extends RefCounted

const EnemyAffixVisuals = preload("res://scripts/config/enemy_affix_visuals.gd")

static func apply_setup(enemy: Node2D, config: Dictionary) -> void:
	enemy.enemy_type = config.get("id", config.get("enemy_type", "basic"))
	enemy.enemy_category = enemy.normalize_enemy_category(config.get("category", enemy.ENEMY_CATEGORY_LAND))
	enemy.display_name = config.get("name", "Enemy")
	enemy.visual_type = config.get("visual_type", "basic")
	enemy.tags = Array(config.get("tags", []))
	enemy.is_boss_unit = enemy.enemy_type == "boss" or enemy.enemy_type.begins_with("boss_") or enemy.tags.has("boss")
	enemy.skill_id = config.get("skill", "")
	enemy.skill_params = config.get("skill_params", {})
	enemy.secondary_skill_id = config.get("secondary_skill", "")
	enemy.secondary_skill_params = config.get("secondary_skill_params", {})

	if enemy.skill_id == "healer":
		enemy.skill_timer = float(enemy.skill_params.get("initial_delay", enemy.skill_params.get("interval", 1.0)))
	else:
		enemy.skill_timer = float(enemy.skill_params.get("initial_delay", 0.0))

	if enemy.secondary_skill_id == "regenerate":
		enemy._regen_timer = float(enemy.secondary_skill_params.get("initial_delay", enemy.secondary_skill_params.get("interval", 2.0)))
	elif enemy.secondary_skill_id == "spawn_minions":
		enemy._minion_timer = float(enemy.secondary_skill_params.get("initial_delay", enemy.secondary_skill_params.get("interval", 5.0)))
	
	enemy.is_stealth = (enemy.skill_id == "stealth" or enemy.tags.has("stealth"))
	if enemy.is_stealth:
		enemy.modulate.a = 0.4 # Visual feedback for stealth

	if enemy.enemy_category == enemy.ENEMY_CATEGORY_LAND:
		enemy.add_to_group("ground_enemies")
	else:
		enemy.remove_from_group("ground_enemies")
	
	enemy.is_bulwark = (enemy.enemy_type == "bulwark" or enemy.tags.has("shield"))
	enemy.is_hunter = (enemy.enemy_type == "hunter" or enemy.tags.has("hunter"))
	enemy.is_runner = (enemy.enemy_type == "runner" or enemy.tags.has("runner"))
	if enemy.is_runner:
		if enemy.has_method("_configure_runner_role"):
			enemy._configure_runner_role(config)
	if enemy.is_hunter:
		enemy.aggro_range = float(config.get("aggro_range", enemy.skill_params.get("aggro_range", enemy.aggro_range)))
		# Keep Hunter readable without covering too much map area. Existing configs can still tune it,
		# but clamp the gameplay/visual radius to a tighter anti-hero zone.
		enemy.aggro_range = clampf(enemy.aggro_range, 75.0, 110.0)
		enemy.hunter_attack_range = float(config.get("hunter_attack_range", enemy.skill_params.get("attack_range", enemy.hunter_attack_range)))
		enemy.hunter_attack_damage = float(config.get("hunter_attack_damage", enemy.skill_params.get("attack_damage", enemy.hunter_attack_damage)))
		enemy.hunter_attack_cooldown = float(config.get("hunter_attack_cooldown", enemy.skill_params.get("attack_cooldown", enemy.hunter_attack_cooldown)))
		enemy.hunter_chase_speed_multiplier = float(config.get("hunter_chase_speed_multiplier", enemy.skill_params.get("chase_speed_multiplier", enemy.hunter_chase_speed_multiplier)))
	
	enemy.max_hp = config.get("max_hp", config.get("hp", 30.0))
	enemy.hp = enemy.max_hp
	enemy.base_speed = config.get("speed", 100.0)
	if enemy.is_runner:
		# Keep Fast as the constant-speed enemy. Runner should be slightly calmer by default,
		# then become threatening through dash/panic windows.
		enemy.base_speed *= enemy.runner_base_speed_scale
	enemy.speed = enemy.base_speed
	enemy.reward_gold = config.get("reward_gold", 5)
	enemy.base_damage = config.get("base_damage", 1)
	
	enemy.formation_speed_limit = config.get("formation_speed_limit", -1.0)
	enemy.formation_limit_duration = config.get("formation_limit_duration", 0.0)
	enemy.formation_config_multiplier = float(config.get("formation_speed_multiplier", 1.0))
	enemy.formation_release_rate = float(config.get("formation_release_rate", enemy.formation_release_rate))
	enemy._configure_formation_speed()
	enemy.update_effective_speed()
	
	enemy._update_health_visual_state(true)
	enemy.apply_visuals()
	enemy._ensure_vfx_controller()
	
	if enemy.is_gallery_preview:
		enemy.CatalogPreviewMode.mark_preview_tree(enemy, true, false)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.queue_redraw()
		
	var l_offset = config.get("local_offset", Vector2.ZERO)
	if l_offset is Vector2:
		enemy.h_offset = l_offset.x
		enemy.v_offset = l_offset.y

	# Per-enemy organic motion seed.
	# Use golden-ratio hash so consecutive spawns get well-separated phases,
	# not adjacent values from a modulo strip.
	var iid_f := float(enemy.get_instance_id())
	enemy._anim_phase      = fmod(iid_f * 2.39996, TAU)
	enemy._perp_drift_amp  = enemy._get_type_drift_amp(enemy.visual_type) * (0.7 + fmod(iid_f * 0.61803, 1.0) * 0.6)
	enemy._perp_drift_freq = 0.045 + fmod(iid_f * 0.38196, 0.025)
	var spread_dir := 1.0 if fmod(iid_f * 0.754877, 1.0) >= 0.5 else -1.0
	var spread_mag := 0.55 + fmod(iid_f * 0.31831, 1.0) * 0.45
	enemy._spawn_spread_lateral = enemy._get_type_spawn_spread(enemy.visual_type) * spread_dir * spread_mag
	enemy._sep_check_timer = 0.04 + fmod(iid_f * 0.15700, 0.14)  # quick first scan, still staggered

	enemy.affix_service = Engine.get_main_loop().root.get_node_or_null("EnemyAffixService")
	if enemy.affix_service and enemy.affix_service.has_method("setup_enemy_affixes"):
		enemy.affix_service.setup_enemy_affixes(enemy, config)
	else:
		enemy.armor_element = config.get("armor_element", "composite")
		enemy.affixes = Array(config.get("affixes", []))
		enemy.gives_gold = bool(config.get("gives_gold", true))
		enemy.can_leak = bool(config.get("can_leak", true))
		enemy.is_illusion = bool(config.get("is_illusion", false))
		enemy.is_invulnerable = false
		enemy.affix_speed_multiplier = 1.0
		enemy.affix_state = {}

	# Apply affix/boss tint AFTER affixes are set
	enemy.affix_tint = _compute_affix_tint(enemy)
	enemy._request_baked_enemy_texture()

	enemy.is_active = true

	if enemy.is_gallery_preview:
		enemy.CatalogPreviewMode.mark_preview_tree(enemy, true, false)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.queue_redraw()

static func _compute_affix_tint(enemy: Node2D) -> Color:
	var etype: String = str(enemy.get("enemy_type"))
	var affixes: Array = enemy.get("affixes") if enemy.get("affixes") is Array else []
	return EnemyAffixVisuals.get_enemy_tint(etype, affixes)

static func _affix_color(affix: String) -> Color:
	return EnemyAffixVisuals.get_affix_color(affix)
