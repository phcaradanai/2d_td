class_name EnemyHitFeedbackService
extends RefCounted

const EnemyAffixVisuals = preload("res://scripts/config/enemy_affix_visuals.gd")

static func _play_sprite_hit_impact(enemy: Node2D, color: Color) -> void:
	if not enemy._body_baked or enemy._body_sprite == null or not is_instance_valid(enemy._body_sprite):
		return
	var now_msec := Time.get_ticks_msec()
	if enemy._hit_impact_active or now_msec - enemy._last_sprite_hit_impact_msec < enemy.SPRITE_HIT_IMPACT_COOLDOWN_MSEC:
		return
	enemy._last_sprite_hit_impact_msec = now_msec
	if enemy._hit_impact_tween != null and enemy._hit_impact_tween.is_valid():
		enemy._hit_impact_tween.kill()
	if enemy._death_glow_tween != null and enemy._death_glow_tween.is_valid():
		enemy._death_glow_tween.pause()
	enemy._hit_impact_active = true

	# Bright white flash first frame, then element colour, then return — very snappy
	var flash_white := Color(2.0, 2.0, 2.0, 1.0)
	var flash_col   := Color(
		minf(color.r * 2.5, 1.0),
		minf(color.g * 2.0, 1.0),
		minf(color.b * 2.0, 1.0), 1.0)

	# Per-type squish — tanks thud with rigid shudder; light units flex dramatically.
	var squish_wide: float
	var squish_flat: float
	match enemy.visual_type:
		"tank", "bulwark", "shieldbearer":
			squish_wide = 1.30; squish_flat = 0.72
		"swarm":
			squish_wide = 1.50; squish_flat = 0.55
		"fast", "runner", "fast_flyer", "hunter":
			squish_wide = 1.26; squish_flat = 0.78
		_:
			squish_wide = 1.65; squish_flat = 0.45

	var t := enemy.create_tween().set_parallel(true)
	enemy._hit_impact_tween = t

	# Squish [WAVE 1: 45ms] + instant white flash
	enemy._body_sprite.modulate = flash_white
	t.tween_property(enemy._body_sprite, "modulate", flash_col, 0.03)
	t.tween_property(enemy._body_sprite, "scale",
		Vector2(enemy._bake_scale.x * squish_wide, enemy._bake_scale.y * squish_flat), 0.045)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Spring back [WAVE 2: 120ms]
	t.chain().tween_property(enemy._body_sprite, "scale", enemy._bake_scale, 0.12)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	# Release freeze right after spring-back (~165ms); colour fade continues
	# independently — walking animation resumes without fighting the scale tween.
	t.chain().tween_callback(func() -> void:
		enemy._hit_impact_active = false
		if enemy._body_sprite != null and is_instance_valid(enemy._body_sprite):
			enemy._body_sprite.rotation = enemy._get_body_visual_rotation()
		if enemy._death_glow_tween != null and enemy._death_glow_tween.is_valid():
			enemy._death_glow_tween.play()
	)
	# Colour fade [WAVE 3: +110ms, parallel with callback]
	t.tween_property(enemy._body_sprite, "modulate", EnemyAffixVisuals.get_sprite_modulate(enemy.affix_tint), 0.11)\
		.set_trans(Tween.TRANS_EXPO)
	t.chain().tween_callback(func() -> void:
		if enemy._body_sprite != null and is_instance_valid(enemy._body_sprite):
			if enemy.health_visual_state < enemy.HealthVisualState.HEALTH_CRITICAL:
				enemy._body_sprite.modulate = EnemyAffixVisuals.get_sprite_modulate(enemy.affix_tint)
	)

	# Separate quick shake anchored at the current visual offset. Do not reset
	# position to Vector2.ZERO here; dense groups use different lateral offsets,
	# and collapsing all hit creeps back to one center line reads like a bug.
	if enemy._hit_shake_tween != null and enemy._hit_shake_tween.is_valid():
		enemy._hit_shake_tween.kill()
	if enemy._hit_jitter_tween != null and enemy._hit_jitter_tween.is_valid():
		enemy._hit_jitter_tween.kill()
	var hit_anchor = enemy._body_sprite.position
	var impact_seed := fmod(float(enemy.get_instance_id()) * 0.61803398875, 1.0)
	var shake_sign := 1.0 if impact_seed >= 0.5 else -1.0
	var shake_amp := (5.0 if (enemy.enemy_type == "swarm" or enemy.tags.has("swarm")) else 8.0) * (0.78 + impact_seed * 0.34)
	var jitter_y := shake_amp * (0.15 + impact_seed * 0.12)
	enemy._hit_shake_tween = enemy.create_tween()
	enemy._hit_shake_tween.tween_property(enemy._body_sprite, "position",
		hit_anchor + Vector2(shake_amp * shake_sign, -jitter_y), 0.026 + impact_seed * 0.010)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enemy._hit_shake_tween.chain().tween_property(enemy._body_sprite, "position",
		hit_anchor + Vector2(-shake_amp * 0.55 * shake_sign, jitter_y * 0.35), 0.034 + impact_seed * 0.010)\
		.set_trans(Tween.TRANS_SPRING)
	enemy._hit_shake_tween.chain().tween_property(enemy._body_sprite, "position",
		hit_anchor + Vector2(shake_amp * 0.22 * shake_sign, -jitter_y * 0.18), 0.026 + impact_seed * 0.008)\
		.set_trans(Tween.TRANS_SPRING)
	enemy._hit_shake_tween.chain().tween_property(enemy._body_sprite, "position", hit_anchor, 0.026)\
		.set_trans(Tween.TRANS_SPRING)

## Hit spark at the world-space impact point — bypasses screen shake entirely.
## Uses the enemy_impact pool for a tiny 3-ray burst + core dot.

static func _spawn_hit_spark(enemy: Node2D, hit_pos: Vector2, color: Color) -> void:
	if PerformanceFirebreak.disable_death_effects:
		return
	var now_msec := Time.get_ticks_msec()
	var crowded = enemy._get_nearby_enemy_count(enemy.CROWDED_ENEMY_RADIUS) >= enemy.CROWDED_ENEMY_THRESHOLD
	var cooldown = enemy.CROWDED_HIT_SPARK_COOLDOWN_MSEC if crowded else enemy.HIT_SPARK_COOLDOWN_MSEC
	if now_msec - enemy._last_hit_spark_msec < cooldown:
		return
	enemy._last_hit_spark_msec = now_msec
	var pool := enemy.get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_scene"):
		return
	var spark: Node = pool.acquire_scene("death_pop",
		enemy.get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer") \
		if enemy.get_tree().current_scene.has_node("WorldRoot/MapRoot/EffectsContainer") \
		else enemy.get_tree().current_scene,
		"death_pop")
	if spark == null:
		return
	spark.enemy.global_position = hit_pos
	spark.scale = Vector2.ONE * (0.32 if crowded else 0.45)   # tiny spark — not an explosion
	if spark.has_method("setup"):
		spark.setup("default", Color(color.r, color.g, color.b, 0.9), 0.10 if crowded else 0.12, 2 if crowded else 3)


static func flash_body(enemy: Node2D, damage_context: String = "") -> void:
	var comfort := enemy.get_node_or_null("/root/VisualComfort")
	# Baked sprites resolve colour/LOD here, then take_damage() plays the single
	# heavy impact path. Keeping tween ownership in one place avoids double hits.
	if enemy._body_baked:
		var fc: Color = Color(1.0, 0.62, 0.26, 0.20)
		if comfort != null and comfort.has_method("get_hit_flash_color"):
			fc = comfort.get_hit_flash_color(damage_context)
		enemy.hit_flash_color = fc
		enemy.hit_flash_alpha = 0.0
		enemy.is_flashing = false
		enemy._set_anim_lod_high()
		return
	if comfort != null and comfort.has_method("should_skip_hit_flash") and comfort.should_skip_hit_flash():
		return
	if comfort != null and comfort.has_method("allow_flash"):
		if not comfort.allow_flash("hit_%s" % enemy.get_instance_id()):
			return
	if not enemy.is_visible_in_tree():
		return
	if enemy._hit_flash_tween != null and enemy._hit_flash_tween.is_valid() and enemy._hit_flash_tween.is_running():
		return

	if comfort != null and comfort.has_method("get_hit_flash_color"):
		enemy.hit_flash_color = comfort.get_hit_flash_color(damage_context)
	else:
		enemy.hit_flash_color = Color(1.0, 0.62, 0.26, 0.20)
	enemy.hit_flash_alpha = minf(enemy.hit_flash_color.a, 0.22)
	enemy.is_flashing = enemy.hit_flash_alpha > 0.01
	enemy._set_anim_lod_high()   # hit = always full animation
	enemy.queue_redraw()

	var duration := 0.08
	if comfort != null and comfort.has_method("get_hit_flash_duration"):
		duration = float(comfort.get_hit_flash_duration())
	enemy._hit_flash_tween = enemy.create_tween()
	enemy._hit_flash_tween.tween_property(enemy, "hit_flash_alpha", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	enemy._hit_flash_tween.tween_callback(func():
		enemy.is_flashing = false
		enemy.queue_redraw()
	)


static func spawn_damage_number(enemy: Node2D, amount: int, hit_global: Vector2, color: Color = Color.WHITE, source_id: String = "") -> void:
	if PerformanceFirebreak.disable_damage_numbers: return
	if enemy._get_nearby_enemy_count(enemy.CROWDED_ENEMY_RADIUS) >= enemy.CROWDED_ENEMY_THRESHOLD and amount < int(enemy.max_hp * 0.18):
		return
	var perf_service := enemy.get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("allow_floating_damage_number"):
		if not perf_service.allow_floating_damage_number():
			return
	elif not enemy.SHOW_FLOATING_DAMAGE_NUMBERS:
		return
	# Budget cap — skip new labels when too many are already alive.
	if DamageNumber._active_count >= DamageNumber.MAX_ACTIVE:
		return
	if enemy.damage_number_scene:
		var pool := enemy.get_node_or_null("/root/VisualEffectPoolService")
		var parent_node: Node = enemy.get_tree().current_scene
		var dn: Node = null
		if pool != null and pool.has_method("acquire_scene"):
			dn = pool.acquire_scene("damage_number", parent_node, "damage_number")
		if dn == null:
			return
		var offset := Vector2(randf_range(-5, 5), -20 + randf_range(-5, 5))
		if source_id.begins_with("disease_"):
			offset = Vector2(randf_range(-12, 12), -12 + randf_range(-3, 3))
		dn.enemy.global_position = hit_global + offset
		dn.setup(amount, color)


static func _play_hit_pulse(enemy: Node2D) -> void:
	if PerformanceFirebreak.disable_cosmetic_tweens:
		return
	if not enemy.is_visible_in_tree():
		return
	if enemy._hit_pulse_tween != null and enemy._hit_pulse_tween.is_valid() and enemy._hit_pulse_tween.is_running():
		return
	enemy._hit_pulse_tween = enemy.create_tween()
	var tween = enemy._hit_pulse_tween
	var is_swarm = enemy.enemy_type == "swarm" or enemy.tags.has("swarm")
	var s = randf_range(1.08, 1.14) if is_swarm else randf_range(1.15, 1.25)
	# Scale-squeeze on the PathFollow2D root is safe: PathFollow2D._update_transform()
	# recalculates position/rotation from progress but never resets scale.
	tween.tween_property(enemy, "scale", Vector2(s, 1.0 / s), 0.025 if is_swarm else 0.04).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(enemy, "scale", Vector2.ONE, 0.055 if is_swarm else 0.08).set_trans(Tween.TRANS_BACK)

	# Hit shake: MUST target the child visual node, not the PathFollow2D root.
	# Tweening enemy.position on a PathFollow2D fights _update_transform() which
	# recomputes position from progress every frame — causing the creep to snap/warp
	# off the path after each hit (especially visible on control-family area hits).
	var shake_target: Node2D = enemy.visual_root if (enemy.visual_root != null and enemy.visual_root != enemy) else null
	if shake_target != null:
		if enemy._hit_shake_tween != null and enemy._hit_shake_tween.is_valid() and enemy._hit_shake_tween.is_running():
			return
		var original_pos := shake_target.position
		enemy._hit_shake_tween = enemy.create_tween()
		var shake_tween = enemy._hit_shake_tween
		var shake_strength := 1.4 if is_swarm else 3.0
		var shake_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * shake_strength
		shake_tween.tween_property(shake_target, "position", original_pos + shake_dir, 0.018 if is_swarm else 0.03)
		shake_tween.tween_property(shake_target, "position", original_pos, 0.018 if is_swarm else 0.03)


static func _trigger_swarm_hit_reaction(enemy: Node2D) -> void:
	enemy.swarm_core_flicker_time = 0.08


static func _spawn_swarm_hit_effect(enemy: Node2D, hit_global: Vector2) -> void:
	if enemy.death_pop_scene == null:
		return
	if PerformanceFirebreak.disable_death_effects: return
	var container = enemy.get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = enemy.get_tree().current_scene
	var pool := enemy.get_node_or_null("/root/VisualEffectPoolService")
	var effect: Node = null
	if pool != null and pool.has_method("acquire_scene"):
		effect = pool.acquire_scene("death_pop", container, "death_pop")
	if effect == null:
		return
	effect.enemy.global_position = hit_global
	if effect.has_method("setup"):
		effect.setup("swarm_hit", enemy.swarm_core_glow_color, 0.18, 6)
