class_name EnemyBakedSpriteService
extends RefCounted

static func _resolve_visual_root(enemy: Node2D) -> Node2D:
	var n = enemy.get_node_or_null("Body")
	if n is Node2D:
		return n
	if n != null:
		# Legacy enemy scenes keep Body as a hidden ColorRect while procedural
		# visuals draw on this PathFollow2D. That is valid and should not warn
		# once per spawned enemy.
		return enemy

	n = enemy.get_node_or_null("VisualRoot")
	if n is Node2D:
		return n

	n = enemy.get_node_or_null("Model")
	if n is Node2D:
		return n

	n = enemy.get_node_or_null("Sprite")
	if n is Node2D:
		return n

	DebugLog.warn_once("enemy_no_visual_root", "[Enemy] No Body/VisualRoot/Model/Sprite found, using enemy fallback.")
	return enemy

static func _request_baked_enemy_texture(enemy: Node2D) -> void:
	if enemy.is_gallery_preview:
		return
	# Defer until we're in the scene tree so enemy.add_child / callbacks work safely.
	if not enemy.is_inside_tree():
		enemy.call_deferred("_request_baked_enemy_texture")
		return
	var vt: String = str(enemy.visual_type)
	var hs: int = enemy.health_visual_state
	var captured := enemy
	EnemyTextureBaker.request_texture(vt, hs, func(tex: ImageTexture) -> void:
		if not is_instance_valid(captured):
			return
		captured.EnemyBakedSpriteService._apply_baked_enemy_texture(enemy, tex)
	)


static func _apply_baked_enemy_texture(enemy: Node2D, tex: ImageTexture) -> void:
	if tex == null:
		return
	if enemy._body_sprite == null or not is_instance_valid(enemy._body_sprite):
		enemy._body_sprite = Sprite2D.new()
		enemy._body_sprite.name = "BakedBodySprite"
		enemy._body_sprite.centered = true
		enemy._body_sprite.z_index = 0
		enemy._body_sprite.z_as_relative = true
		enemy.add_child(enemy._body_sprite)
		enemy.move_child(enemy._body_sprite, 0)

	if EnemyBakedSpriteService._uses_directional_visual(enemy, enemy.visual_type) and (enemy._shadow_node == null or not is_instance_valid(enemy._shadow_node)):
		enemy._shadow_node = Node2D.new()
		enemy._shadow_node.name = "DirectionalShadow"
		enemy._shadow_node.z_index = -1
		enemy._shadow_node.z_as_relative = true
		var is_fast = enemy.visual_type in ["fast", "runner", "hunter"]
		var rx = 14.2 if is_fast else 12.4
		var ry = 3.8 if is_fast else 3.3
		var alpha = 0.22 if is_fast else 0.15
		enemy._shadow_node.draw.connect(func():
			var pts := PackedVector2Array()
			for i in 22:
				var a := float(i) / 22.0 * TAU
				pts.append(Vector2(cos(a) * rx, sin(a) * ry))
			enemy._shadow_node.draw_colored_polygon(pts, Color(0, 0, 0, alpha))
			var core := PackedVector2Array()
			for i in 18:
				var a := float(i) / 18.0 * TAU
				core.append(Vector2(cos(a) * rx * 0.58, sin(a) * ry * 0.62))
			enemy._shadow_node.draw_colored_polygon(core, Color(0, 0, 0, alpha * 0.72))
		)
		enemy.add_child(enemy._shadow_node)
		enemy.move_child(enemy._shadow_node, 0)
		enemy._shadow_node.queue_redraw()

	enemy._bake_scale = Vector2.ONE / float(EnemyTextureBaker.BAKE_ZOOM)
	enemy._body_sprite.texture = tex
	enemy._body_sprite.scale = enemy._bake_scale
	enemy._body_sprite.visible = true
	enemy._baked_health_state = enemy.health_visual_state
	if not enemy._body_baked:
		# First time baked: pop-in spawn animation
		enemy._body_sprite.scale = Vector2.ZERO
		var spawn_tw = enemy.create_tween()
		spawn_tw.tween_property(enemy._body_sprite, "enemy.scale", enemy._bake_scale, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enemy._body_baked = true
	enemy.queue_redraw()

## Per-type lateral drift amplitude (px). Fast/small types drift more; tanks barely move.

static func _get_type_drift_amp(enemy: Node2D, vtype: String) -> float:
	match vtype:
		"swarm": return 9.0
		"fast", "runner", "fast_flyer": return 7.5
		"cloaked": return 7.0
		"basic", "healer", "splitter", "disruptor": return 6.0
		"hunter", "flyer", "armored_flyer": return 5.5
		"tank", "bulwark", "shieldbearer": return 3.0
		_: return 6.0

## Spawn spread is visual-only and decays during the first few road tiles.
## It keeps dense starts from reading as one stacked train without moving gameplay hitboxes.

static func _get_type_spawn_spread(enemy: Node2D, vtype: String) -> float:
	match vtype:
		"swarm": return 10.0
		"fast", "runner", "fast_flyer": return 8.5
		"tank", "bulwark", "shieldbearer": return 4.5
		"flyer", "armored_flyer": return 6.0
		_: return 7.0

## Lazy separation — pushes _sep_target away from nearby overlapping enemies.
## Called ~every 0.4 s per enemy (staggered), NOT every frame.

static func _uses_glide_motion(enemy: Node2D, vtype: String) -> bool:
	return vtype == "fast" or vtype == "runner" or vtype == "fast_flyer" or vtype == "hunter"


static func _uses_directional_visual(enemy: Node2D, vtype: String) -> bool:
	return vtype == "fast" or vtype == "runner" or vtype == "fast_flyer" or vtype == "hunter"


static func _record_visual_movement_delta(enemy: Node2D, delta_pos: Vector2) -> void:
	if delta_pos.length_squared() <= 0.01:
		return
	enemy._visual_heading_angle = delta_pos.angle()


static func _get_body_visual_rotation(enemy: Node2D) -> float:
	if EnemyBakedSpriteService._uses_directional_visual(enemy, enemy.visual_type):
		return enemy._visual_heading_angle
	return 0.0

## Per-type bob intensity — pointed fast units glide; compact bodies can bounce.

static func _get_type_bob_intensity(enemy: Node2D, vtype: String) -> float:
	match vtype:
		"tank", "bulwark", "shieldbearer": return 0.55
		"swarm": return 0.85
		"fast", "runner", "fast_flyer": return 0.34
		"hunter": return 0.48
		_: return 1.0

## Walking squash/stretch — called every frame when baked. No enemy.queue_redraw.

static func _update_sprite_movement_anim(enemy: Node2D) -> void:
	if not enemy._body_baked or enemy._body_sprite == null or enemy._hit_impact_active:
		return
	var speed_ratio := clampf(enemy.speed / maxf(enemy.base_speed, 1.0), 0.0, 2.2)
	if speed_ratio < 0.02:
		enemy._body_sprite.scale = enemy._bake_scale
		enemy._body_sprite.position = Vector2(0.0, -3.6 if EnemyBakedSpriteService._uses_directional_visual(enemy, enemy.visual_type) else 0.0)
		enemy._body_sprite.rotation = EnemyBakedSpriteService._get_body_visual_rotation(enemy)
		if EnemyBakedSpriteService._uses_directional_visual(enemy, enemy.visual_type):
			enemy._body_sprite.flip_v = absf(wrapf(enemy._body_sprite.rotation, -PI, PI)) > (PI / 2.0)
		if enemy._shadow_node != null and is_instance_valid(enemy._shadow_node):
			enemy._shadow_node.position = Vector2(0.0, 9.8)
		return
	# enemy.get_path_progress() works for BOTH PathFollow2D (progress) and dynamic-path
	# enemies (dynamic_travel_distance). Using progress directly would freeze dynamic-path
	# enemies at phase = 0, giving no animation.
	var path_px = enemy.get_path_progress()
	if EnemyBakedSpriteService._uses_glide_motion(enemy, enemy.visual_type):
		EnemyBakedSpriteService._update_sprite_glide_motion(enemy, path_px, speed_ratio)
		return

	var bob_intensity := EnemyBakedSpriteService._get_type_bob_intensity(enemy, enemy.visual_type)
	# Staggered bob: unique phase per enemy; ~1 cycle every 70 px of travel
	var bob := sin(path_px * 0.090 + enemy._anim_phase) * speed_ratio * bob_intensity
	# Squash-stretch: exaggerated so it reads at small sprite sizes
	enemy._body_sprite.scale = Vector2(
		enemy._bake_scale.x * (1.0 - bob * 0.20), # narrow on upstroke
		enemy._bake_scale.y * (1.0 + bob * 0.30) # tall on upstroke, short on downstroke
	)
	# Primary screen-local weave + secondary overtone = organic swarm feel
	# path_px drives drift so it's always in sync with actual travel distance
	var drift = sin(path_px * enemy._perp_drift_freq + enemy._anim_phase) * enemy._perp_drift_amp \
			   + sin(path_px * enemy._perp_drift_freq * 2.1 + enemy._anim_phase + 1.4) * enemy._perp_drift_amp * 0.30
	# Combined lateral: drift + separation, clamped to road half-width
	var spawn_spread = enemy._spawn_spread_lateral * (1.0 - clampf(path_px / enemy.SPAWN_SPREAD_FADE_DISTANCE, 0.0, 1.0))
	var lateral := clampf(drift + enemy._sep_lateral + spawn_spread, -enemy.SEP_ROAD_HALF, enemy.SEP_ROAD_HALF)
	# Float: sprite rises at upstroke peak. Visual angle is locked, so Y stays screen-local.
	enemy._body_sprite.position = Vector2(0.0, lateral - absf(bob) * 6.5 * speed_ratio)
	# Lean: tilt sprite into each step — intensity scales with bob type
	enemy._body_sprite.rotation = bob * 0.22

	if enemy._shadow_node != null and is_instance_valid(enemy._shadow_node):
		enemy._shadow_node.position = Vector2(0.0, lateral + 9.8)



static func _update_sprite_glide_motion(enemy: Node2D, path_px: float, speed_ratio: float) -> void:
	var glide := sin(path_px * 0.135 + enemy._anim_phase) * speed_ratio
	var micro := sin(path_px * 0.265 + enemy._anim_phase * 0.73) * speed_ratio
	var compression := absf(glide)
	var scale_x := 1.0 + compression * (0.070 if enemy.visual_type == "runner" else 0.055)
	var scale_y := 1.0 - compression * (0.040 if enemy.visual_type == "runner" else 0.032)
	enemy._body_sprite.scale = Vector2(enemy._bake_scale.x * scale_x, enemy._bake_scale.y * scale_y)

	var drift = (
		sin(path_px * enemy._perp_drift_freq + enemy._anim_phase) * enemy._perp_drift_amp * 0.42
		+ sin(path_px * enemy._perp_drift_freq * 2.1 + enemy._anim_phase + 1.4) * enemy._perp_drift_amp * 0.12
	)
	var spawn_spread = enemy._spawn_spread_lateral * (1.0 - clampf(path_px / enemy.SPAWN_SPREAD_FADE_DISTANCE, 0.0, 1.0))
	var lateral := clampf(drift + enemy._sep_lateral + spawn_spread, -enemy.SEP_ROAD_HALF, enemy.SEP_ROAD_HALF)
	var slide_x := micro * (1.85 if enemy.visual_type == "runner" else 1.35)
	var lift := absf(micro) * (0.34 if enemy.visual_type == "runner" else 0.26)
	if EnemyBakedSpriteService._uses_directional_visual(enemy, enemy.visual_type):
		lift += 3.6 # Replace baked body_offset so sprite floats correctly

	enemy._body_sprite.position = Vector2(slide_x, lateral - lift)
	var bank := glide * (0.105 if enemy.visual_type == "runner" else 0.078)
	enemy._body_sprite.rotation = EnemyBakedSpriteService._get_body_visual_rotation(enemy) + bank
	if EnemyBakedSpriteService._uses_directional_visual(enemy, enemy.visual_type):
		enemy._body_sprite.flip_v = absf(wrapf(enemy._body_sprite.rotation, -PI, PI)) > (PI / 2.0)


	if enemy._shadow_node != null and is_instance_valid(enemy._shadow_node):
		enemy._shadow_node.position = Vector2(slide_x, lateral + 9.8)


## Hit impact squish + colour flash — no enemy.queue_redraw, all Tween/modulate.
## Heavy squash is intentionally throttled so rapid-fire hits do not freeze gait animation.
