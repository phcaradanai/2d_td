extends Node2D

const PERFORMANCE_MODE := true  # Keeps trails/splash heavy FX off; compact impacts are quality-gated.
const RENDER_GENERIC_PROJECTILE_PIXEL := false
const SHOW_PROJECTILE_BODY_VFX := RENDER_GENERIC_PROJECTILE_PIXEL
const ELEMENTAL_DEBUG_FLOATING_TEXT := false
const ELEMENTAL_DEBUG_FLOATING_TEXT_META := "elemental_debug_floating_text_enabled"
const ELEMENTAL_DEBUG_FLOATING_TEXT_LAST_MSEC_META := "elemental_debug_floating_text_last_msec"
const ELEMENTAL_DEBUG_FLOATING_TEXT_MIN_INTERVAL_MSEC := 90

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const DEFAULT_TARGET_CATEGORIES: Array[String] = [ENEMY_CATEGORY_LAND]
const ENEMIES_DATA_PATH := "res://data/enemies.json"
const TOWERS_TREE_DATA_PATH := "res://data/towers_tree.json"

# Element TD WC3-style elemental damage relation.
# Cycle used by classic Element TD logic:
# Light > Darkness > Water > Fire > Nature > Earth > Light.
const ELEMENT_ORDER: Array[String] = ["light", "darkness", "water", "fire", "nature", "earth"]
const ELEMENT_STRONG_AGAINST := {
	"light": "darkness",
	"darkness": "water",
	"water": "fire",
	"fire": "nature",
	"nature": "earth",
	"earth": "light",
}
const ELEMENT_DAMAGE_STRONG_MULTIPLIER: float = 1.50
const ELEMENT_DAMAGE_WEAK_MULTIPLIER: float = 0.75
const ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER: float = 1.0

# Backward-compatible safety net only. Stage 5C reads enemy armor from
# data/enemies.json first, then falls back here only if older/custom enemy data
# has not been migrated yet.
const ENEMY_TYPE_ARMOR_FALLBACK := {
	"basic": "earth",
	"fast": "nature",
	"tank": "earth",
	"bulwark": "light",
	"hunter": "darkness",
	"swarm": "water",
	"runner": "nature",
	"shieldbearer": "light",
	"healer": "water",
	"splitter": "fire",
	"cloaked": "darkness",
	"flyer": "light",
	"fast_flyer": "nature",
	"armored_flyer": "earth",
	"disruptor": "darkness",
}

var enemy_armor_data_cache: Dictionary = {}
var enemy_armor_data_loaded: bool = false
var tower_elements_data_cache: Dictionary = {}
var tower_elements_data_loaded: bool = false

var target: Node2D = null
var damage: float = 0.0
var speed: float = 500.0
var attack_type: String = "single"
var effect_radius: float = 0.0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var target_categories: Array[String] = DEFAULT_TARGET_CATEGORIES.duplicate()
var lifetime: float = 5.0
var chain_jumps: int = 0
var chain_range: float = 0.0
var chain_falloff: float = 1.0
var chained_enemies: Array = []
var source_id: String = ""
var attack_elements_override: Array[String] = []
var vulnerability_percent: float = 0.0
var vulnerability_duration: float = 0.0
var status_effects: Array[Dictionary] = []
var last_known_target_pos: Vector2 = Vector2.ZERO
var vfx_core_color: Color = Color(0.75, 0.9, 1.0, 1.0)
var vfx_glow_color: Color = Color(0.25, 0.85, 1.0, 0.75)
var vfx_accent_color: Color = Color.WHITE

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
@onready var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")
@onready var combat_audio_service := get_tree().current_scene.get_node_or_null("CombatAudioService")
@onready var splash_effect_scene: PackedScene = preload("res://scenes/effects/SplashEffect.tscn")
@onready var impact_effect_scene: PackedScene = preload("res://scenes/effects/ImpactEffect.tscn")
@onready var damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
@onready var generic_visual: CanvasItem = get_node_or_null("Visual")
var trail_points: Array[Vector2] = []
@export var max_trail_points: int = 8
@export var min_point_distance: float = 4.0

func setup(p_target: Variant, p_damage: float, p_speed: float = 500.0, p_attack_type: String = "single", p_effect_radius: float = 0.0, p_slow_percent: float = 0.0, p_slow_duration: float = 0.0, p_target_categories: Array = [], p_source_id: String = "", p_vulnerability_percent: float = 0.0, p_vulnerability_duration: float = 0.0, p_attack_elements: Array = []) -> void:
	target = p_target
	damage = p_damage
	speed = p_speed
	attack_type = p_attack_type
	effect_radius = p_effect_radius
	slow_percent = p_slow_percent
	slow_duration = p_slow_duration
	target_categories = _normalize_target_categories(p_target_categories)
	source_id = p_source_id
	attack_elements_override = _normalize_element_array(p_attack_elements)
	vulnerability_percent = maxf(0.0, p_vulnerability_percent)
	vulnerability_duration = maxf(0.0, p_vulnerability_duration)
	_refresh_vfx_palette()
	if target != null and is_instance_valid(target):
		last_known_target_pos = _get_hit_anchor_global_position(target)
	
	# Density Control: Shorten trail for fast/rapid projectiles to avoid clutter
	if p_speed > 600:
		max_trail_points = 4
	elif p_speed > 400:
		max_trail_points = 6
	else:
		max_trail_points = 8

	_apply_generic_projectile_visual_mode()

func _ready() -> void:
	add_to_group("projectiles")
	_apply_generic_projectile_visual_mode()

func _apply_generic_projectile_visual_mode() -> void:
	if RENDER_GENERIC_PROJECTILE_PIXEL:
		return
	if generic_visual:
		generic_visual.visible = false
		generic_visual.set_process(false)
		generic_visual.set_physics_process(false)
		if generic_visual is Control:
			generic_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail_points.clear()

func setup_chain(jumps: int, p_range: float, falloff: float, excluded: Array = []) -> void:
	chain_jumps = jumps
	chain_range = p_range
	chain_falloff = falloff
	chained_enemies = excluded
	if is_instance_valid(target) and not chained_enemies.has(target):
		chained_enemies.append(target)

func setup_status_effects(effects: Array) -> void:
	status_effects.clear()
	for raw_effect in effects:
		if raw_effect is Dictionary:
			status_effects.append(raw_effect.duplicate(true))

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return
		
	var has_live_target := target != null and is_instance_valid(target)
	if has_live_target:
		last_known_target_pos = _get_hit_anchor_global_position(target)
	elif last_known_target_pos == Vector2.ZERO:
		queue_free()
		return
		
	var target_pos := last_known_target_pos
		
	var to_target := target_pos - global_position
	var distance := to_target.length()
	
	# STANDARD: Use global distance for hit detection
	if distance < 10.0:
		global_position = target_pos
		if has_live_target:
			hit_target()
		else:
			_spawn_dissipate_effect()
			queue_free()
		return

	var direction := to_target.normalized()
	rotation = direction.angle()
	global_position += direction * speed * delta

	if not PERFORMANCE_MODE:
		_update_trail()

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _update_trail() -> void:
	# Avoid adding points if we're already at the target or dead
	if not is_instance_valid(target) or global_position.distance_to(_get_hit_anchor_global_position(target)) < 5.0:
		return
		
	if trail_points.is_empty():
		trail_points.append(global_position)
		return
		
	var last_p = trail_points.back()
	if last_p.distance_to(global_position) >= min_point_distance:
		trail_points.append(global_position)
	
	if trail_points.size() > max_trail_points:
		trail_points.pop_front()
	
	queue_redraw()

func _draw() -> void:
	if not SHOW_PROJECTILE_BODY_VFX:
		return

	if attack_type == "chain":
		_draw_lightning_projectile()
		return

	if PERFORMANCE_MODE:
		# Use tower element color (set via modulate in tower.shoot()) when available;
		# fall back to attack_type defaults for neutral / legacy towers.
		var mod := modulate
		var is_default_white := mod.r >= 0.95 and mod.g >= 0.95 and mod.b >= 0.95
		var perf_color: Color
		if is_default_white:
			if attack_type == "splash":   perf_color = Color(1.0, 0.5, 0.2, 1.0)
			elif attack_type == "slow":   perf_color = Color(0.7, 0.5, 1.0, 1.0)
			else: perf_color = Color(0.3, 1.0, 0.6, 1.0) if speed > 550 else Color(0.3, 0.7, 1.0, 1.0)
		else:
			perf_color = Color(mod.r, mod.g, mod.b, 1.0)
		draw_circle(Vector2.ZERO, 4.0, perf_color)
		return

	# 1. Draw Trail (Global points converted to local space)
	if trail_points.size() >= 2:
		var base_color = modulate
		for i in range(trail_points.size() - 1):
			var p1 = to_local(trail_points[i])
			var p2 = to_local(trail_points[i+1])
			
			# Avoid drawing very tiny or degenerate segments
			if p1.distance_to(p2) < 0.5: continue
			
			var alpha = float(i + 1) / trail_points.size()
			var seg_color = base_color
			seg_color.a = 0.4 * alpha
			draw_line(p1, p2, seg_color, 2.0 * alpha, true)

	# 2. Face movement direction
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	var color = vfx_core_color
	
	if attack_type == "splash": # Cannon
		_draw_shell(color)
	elif attack_type == "slow": # Slow
		_draw_bolt(color, 12.0)
	else: # Basic / Rapid
		_draw_bolt(color, 10.0)

func _draw_bolt(color: Color, length: float) -> void:
	var pts := PackedVector2Array([Vector2(length, 0), Vector2(-length/2.0, -3), Vector2(-length/2.0, 3)])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.0)
	# Glow
	draw_line(Vector2(-length, 0), Vector2(length, 0), Color(vfx_glow_color.r, vfx_glow_color.g, vfx_glow_color.b, 0.4), 4.0)

func _draw_shell(color: Color) -> void:
	draw_circle(Vector2.ZERO, 5, color)
	draw_arc(Vector2.ZERO, 5, 0, TAU, 16, vfx_glow_color, 1.5)
	# Trail tail
	draw_line(Vector2(-10, 0), Vector2(-2, 0), vfx_accent_color, 3.0)

func _draw_performance_projectile() -> void:
	if _is_flamethrower_projectile():
		_draw_flame_stream()
	elif _is_beam_projectile():
		_draw_beam_sliver()
	elif attack_type == "splash":
		_draw_shell(vfx_core_color)
	elif attack_type == "slow":
		_draw_elemental_droplet()
	else:
		var length := 12.0 if speed > 550 else 10.0
		_draw_bolt(vfx_core_color, length)

func _draw_elemental_droplet() -> void:
	var pts := PackedVector2Array([Vector2(8, 0), Vector2(-5, -4), Vector2(-8, 0), Vector2(-5, 4)])
	draw_colored_polygon(pts, vfx_core_color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), vfx_glow_color, 1.0)
	draw_circle(Vector2(-2, 0), 2.5, Color.WHITE)

func _draw_flame_stream() -> void:
	var flame_len := 20.0
	var outer := PackedVector2Array([Vector2(-5, -5), Vector2(flame_len, -2), Vector2(flame_len + 8, 0), Vector2(flame_len, 2), Vector2(-5, 5)])
	draw_colored_polygon(outer, Color(vfx_glow_color.r, vfx_glow_color.g, vfx_glow_color.b, 0.55))
	var inner := PackedVector2Array([Vector2(-3, -3), Vector2(flame_len * 0.75, -1), Vector2(flame_len + 3, 0), Vector2(flame_len * 0.75, 1), Vector2(-3, 3)])
	draw_colored_polygon(inner, vfx_core_color)
	draw_circle(Vector2(flame_len * 0.55, 0), 2.5, vfx_accent_color)

func _draw_beam_sliver() -> void:
	draw_line(Vector2(-12, 0), Vector2(16, 0), vfx_glow_color, 4.0, true)
	draw_line(Vector2(-10, 0), Vector2(18, 0), Color.WHITE, 1.5, true)
	draw_circle(Vector2(18, 0), 2.0, vfx_core_color)

func _get_hit_anchor_global_position(node: Variant) -> Vector2:
	if node != null and is_instance_valid(node):
		if node.has_method("get_hit_anchor_global_position"):
			return node.get_hit_anchor_global_position()
		if node.has_method("get_hit_origin"):
			return node.get_hit_origin()
		if node.has_method("get_aim_point"):
			return node.get_aim_point()
		if node is Node2D:
			return node.global_position
	return global_position

func _refresh_vfx_palette() -> void:
	var attack_elements := _get_attack_elements_from_source()
	if _is_flamethrower_projectile():
		vfx_core_color = _get_element_vfx_color("fire")
		vfx_glow_color = _get_element_vfx_color("darkness")
		vfx_accent_color = _get_element_vfx_color("earth").lightened(0.25)
		return
	if attack_elements.is_empty():
		vfx_core_color = Color(0.78, 0.9, 1.0, 1.0)
		vfx_glow_color = Color(0.28, 0.8, 1.0, 0.85)
		vfx_accent_color = Color(0.9, 0.96, 1.0, 1.0)
		if attack_type == "splash":
			vfx_core_color = Color(1.0, 0.55, 0.24, 1.0)
			vfx_glow_color = Color(1.0, 0.28, 0.08, 0.85)
			vfx_accent_color = Color(1.0, 0.85, 0.45, 1.0)
		return

	vfx_core_color = _get_element_vfx_color(attack_elements[0])
	vfx_glow_color = vfx_core_color.lightened(0.25)
	vfx_accent_color = Color.WHITE
	if attack_elements.size() >= 2:
		vfx_glow_color = _get_element_vfx_color(attack_elements[1])
	if attack_elements.size() >= 3:
		vfx_accent_color = _get_element_vfx_color(attack_elements[2]).lightened(0.2)

func _get_element_vfx_color(element_id: String) -> Color:
	match _normalize_element_id(element_id):
		"light": return Color(1.0, 0.88, 0.18, 1.0)
		"darkness": return Color(0.52, 0.16, 0.9, 1.0)
		"water": return Color(0.16, 0.78, 1.0, 1.0)
		"fire": return Color(1.0, 0.26, 0.06, 1.0)
		"nature": return Color(0.22, 0.95, 0.34, 1.0)
		"earth": return Color(0.86, 0.53, 0.2, 1.0)
		_: return Color(0.78, 0.9, 1.0, 1.0)

func _is_flamethrower_projectile() -> bool:
	return source_id.to_lower().begins_with("flamethrower")

func _is_beam_projectile() -> bool:
	var normalized_source := source_id.to_lower()
	return normalized_source.find("laser") >= 0 or normalized_source.find("rail") >= 0

func _spawn_dissipate_effect() -> void:
	if _allow_impact_fx():
		_spawn_impact_effect(global_position, Color(vfx_core_color.r, vfx_core_color.g, vfx_core_color.b, 0.55), rotation)

func hit_target() -> void:
	var hit_global = global_position
	if is_instance_valid(target):
		hit_global = _get_hit_anchor_global_position(target)
		
	pass # hit captured

	if attack_type == "splash" or attack_type == "slow":
		apply_area_effect(hit_global)
	else:
		if target and target.has_method("take_damage"):
			var elemental_info := _get_elemental_damage_info(damage, target)
			var final_damage := float(elemental_info.get("final_damage", damage))
			target.take_damage(final_damage, hit_global, source_id, attack_type)
			_spawn_elemental_debug_text(hit_global, elemental_info)
			_apply_damage_amp_to_enemy(target)
			_apply_status_effects_to_enemy(target)
			# STANDARD: Use captured hit point and current pos for angle
			var impact_angle = (hit_global - global_position).angle()
			# Use tower element color (modulate) for the impact spark color.
			var impact_col := Color(modulate.r, modulate.g, modulate.b, 1.0)
			_spawn_impact_effect(hit_global, impact_col, impact_angle)
			
			if attack_type == "chain" and chain_jumps > 0:
				_handle_chain_jump(hit_global)

			if _is_beam_projectile():
				_apply_laser_pierce(hit_global, final_damage)

			if combat_audio_service:
				combat_audio_service.play_combat_event_sfx("projectile_hit")

	queue_free()

func _apply_laser_pierce(origin: Vector2, base_damage: float) -> void:
	var pierce_dir := Vector2.RIGHT.rotated(rotation)
	var pierce_range := 200.0
	var pierce_damage := base_damage * 0.65
	var max_pierce := 2
	var enemies_sorted: Array = []
	for en in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(en) or en == target: continue
		if not en.has_method("is_alive") or not en.is_alive(): continue
		if not can_affect_enemy(en): continue
		var en_pos := _get_hit_anchor_global_position(en)
		var to_en := en_pos - origin
		var dist := to_en.length()
		if dist > pierce_range or dist < 1.0: continue
		if to_en.normalized().dot(pierce_dir) < 0.55: continue
		enemies_sorted.append([dist, en, en_pos])
	enemies_sorted.sort_custom(func(a, b): return a[0] < b[0])
	var pierced := 0
	for entry in enemies_sorted:
		if pierced >= max_pierce: break
		var en: Node2D = entry[1]
		var en_pos: Vector2 = entry[2]
		var pierce_info := _get_elemental_damage_info(pierce_damage, en)
		var final_pierce := float(pierce_info.get("final_damage", pierce_damage))
		en.take_damage(final_pierce, en_pos, source_id, attack_type)
		_apply_damage_amp_to_enemy(en)
		_apply_status_effects_to_enemy(en)
		_spawn_impact_effect(en_pos, Color(modulate.r, modulate.g, modulate.b, 0.7), rotation)
		pierced += 1

func _handle_chain_jump(hit_pos: Vector2) -> void:
	var next_target = _find_next_chain_target(hit_pos)
	if next_target:
		# VISUAL: Spawn arc from previous target to next
		var arc = Node2D.new()
		arc.set_script(load("res://scripts/effects/lightning_arc.gd"))
		get_parent().add_child(arc)
		arc.global_position = hit_pos
		arc.setup(hit_pos, _get_hit_anchor_global_position(next_target), vfx_core_color)
		
		var next_proj = duplicate()
		get_parent().add_child(next_proj)
		next_proj.global_position = hit_pos
		next_proj.setup(next_target, damage * chain_falloff, speed, "chain", effect_radius, slow_percent, slow_duration, target_categories, source_id, vulnerability_percent, vulnerability_duration, attack_elements_override)
		next_proj.setup_chain(chain_jumps - 1, chain_range, chain_falloff, chained_enemies)
		# Propagate status effects (slow, hex, etc.) to every chain bounce.
		if not status_effects.is_empty() and next_proj.has_method("setup_status_effects"):
			next_proj.setup_status_effects(status_effects)
		next_proj.modulate = modulate # Keep lightning color

func _find_next_chain_target(hit_pos: Vector2) -> Node2D:
	var best_target = null
	var min_dist = chain_range
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			if chained_enemies.has(enemy): continue
			if not can_affect_enemy(enemy): continue
			
			var dist = hit_pos.distance_to(_get_hit_anchor_global_position(enemy))
			if dist < min_dist:
				min_dist = dist
				best_target = enemy
				
	return best_target

func _spawn_impact_effect(hit_pos: Vector2, color: Color = Color.WHITE, hit_angle: float = 0.0) -> void:
	if not _allow_impact_fx():
		return
	if impact_effect_scene and ImpactEffect._active_count < ImpactEffect.MAX_ACTIVE:
		var effect = impact_effect_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
			# MUST set global_position AFTER add_child
			effect.global_position = hit_pos
		else:
			get_tree().current_scene.add_child(effect)
			effect.global_position = hit_pos

		var scale_val = 0.8
		if attack_type == "slow": scale_val = 1.2

		# Set rotation for directional sparks
		effect.rotation = hit_angle

		if effect.has_method("setup"):
			effect.setup(color, scale_val, attack_type, vfx_glow_color, vfx_accent_color)

func _allow_impact_fx() -> bool:
	var perf_service := get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("get_budget"):
		return bool(perf_service.get_budget("allow_minor_impacts"))
	var pb := get_node_or_null("/root/PerformanceBudget")
	if pb != null and pb.has_method("get_quality_name"):
		return str(pb.get_quality_name()) != "LOW"
	return not PERFORMANCE_MODE

func apply_area_effect(hit_pos: Vector2) -> void:
	if attack_type == "splash":
		if combat_audio_service:
			combat_audio_service.play_combat_event_sfx("splash_hit")
	elif attack_type == "slow":
		if combat_audio_service:
			combat_audio_service.play_combat_event_sfx("projectile_hit")

	_spawn_impact_effect(hit_pos, vfx_core_color, rotation)

	# Spawn visual effect at hit position
	if not PERFORMANCE_MODE and splash_effect_scene and SplashEffect._active_count < SplashEffect.MAX_ACTIVE:
		var effect = splash_effect_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
			effect.global_position = hit_pos
		else:
			get_tree().current_scene.add_child(effect)
			effect.global_position = hit_pos
		
		# Element-tinted splash ring: prefer modulate color, fall back to attack-type defaults.
		var mod := modulate
		var is_default_white := mod.r >= 0.95 and mod.g >= 0.95 and mod.b >= 0.95
		var effect_color: Color
		if is_default_white:
			effect_color = Color(1.0, 0.5, 0.2) if attack_type == "splash" else Color(0.4, 0.8, 1.0)
		else:
			effect_color = Color(mod.r, mod.g, mod.b, 0.85)
		if effect.has_method("setup"):
			effect.setup(effect_radius, effect_color)
		
	# Find enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			if not can_affect_enemy(enemy):
				continue
			
			# Precision: Use hit center or aim point if available
			var enemy_pos = _get_hit_anchor_global_position(enemy)
			
			# STANDARD: Use global distance check for area damage/slow
			var dist = hit_pos.distance_to(enemy_pos)
			if dist <= effect_radius:
				if attack_type == "splash":
					# Linear Falloff: 100% at center, 50% at edge
					var falloff = 1.0 - (dist / effect_radius) * 0.5
					var splash_info := _get_elemental_damage_info(damage * falloff, enemy)
					var splash_damage := float(splash_info.get("final_damage", damage * falloff))
					enemy.take_damage(splash_damage, enemy_pos, source_id, attack_type)
					_spawn_elemental_debug_text(enemy_pos, splash_info)
					if slow_percent > 0.0 and slow_duration > 0.0 and enemy.has_method("apply_slow"):
						enemy.apply_slow(slow_percent, slow_duration)
					_apply_damage_amp_to_enemy(enemy)
					_apply_status_effects_to_enemy(enemy)
				elif attack_type == "slow":
					# Area slow deals its low base damage + applies debuffs.
					var slow_info := _get_elemental_damage_info(damage, enemy)
					var slow_damage := float(slow_info.get("final_damage", damage))
					enemy.take_damage(slow_damage, enemy_pos, source_id, attack_type)
					_spawn_elemental_debug_text(enemy_pos, slow_info)
					if enemy.has_method("apply_slow"):
						enemy.apply_slow(slow_percent, slow_duration)
					_apply_damage_amp_to_enemy(enemy)
					_apply_status_effects_to_enemy(enemy)

func _calculate_elemental_damage(raw_damage: float, enemy: Variant) -> float:
	return float(_get_elemental_damage_info(raw_damage, enemy).get("final_damage", raw_damage))

func _get_elemental_damage_info(raw_damage: float, enemy: Variant) -> Dictionary:
	var info := {
		"raw_damage": raw_damage,
		"final_damage": raw_damage,
		"multiplier": ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER,
		"attack_elements": PackedStringArray(),
		"armor_element": "",
		"text": "",
		"relation": "neutral",
	}
	if raw_damage <= 0.0:
		return info
	var attack_elements := _get_attack_elements_from_source()
	if attack_elements.is_empty():
		return info
	var armor_element := _get_target_armor_element(enemy)
	if armor_element == "":
		return info
	var multiplier := _calculate_elemental_multiplier(attack_elements, armor_element)
	var final_damage := raw_damage * multiplier
	info["final_damage"] = final_damage
	info["multiplier"] = multiplier
	info["attack_elements"] = PackedStringArray(attack_elements)
	info["armor_element"] = armor_element
	info["text"] = _build_elemental_debug_text(attack_elements, armor_element, multiplier)
	if multiplier > ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER + 0.01:
		info["relation"] = "strong"
	elif multiplier < ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER - 0.01:
		info["relation"] = "weak"
	return info

func _calculate_elemental_multiplier(attack_elements: Array[String], armor_element: String) -> float:
	if attack_elements.is_empty() or armor_element == "":
		return ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER
	var total := 0.0
	for element_id in attack_elements:
		total += _single_element_multiplier(element_id, armor_element)
	var average := total / float(attack_elements.size())
	return clampf(average, ELEMENT_DAMAGE_WEAK_MULTIPLIER, ELEMENT_DAMAGE_STRONG_MULTIPLIER)

func _single_element_multiplier(attack_element: String, armor_element: String) -> float:
	attack_element = _normalize_element_id(attack_element)
	armor_element = _normalize_element_id(armor_element)
	if attack_element == "" or armor_element == "":
		return ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER
	if attack_element == armor_element:
		return ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER
	if str(ELEMENT_STRONG_AGAINST.get(attack_element, "")) == armor_element:
		return ELEMENT_DAMAGE_STRONG_MULTIPLIER
	if str(ELEMENT_STRONG_AGAINST.get(armor_element, "")) == attack_element:
		return ELEMENT_DAMAGE_WEAK_MULTIPLIER
	return ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER

func _spawn_elemental_debug_text(hit_pos: Vector2, info: Dictionary) -> void:
	if not _is_elemental_debug_text_enabled():
		return
	var multiplier := float(info.get("multiplier", ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER))
	if is_equal_approx(multiplier, ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER):
		return
	if not _claim_elemental_debug_text_slot():
		return
	var perf_service := get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("allow_floating_damage_number"):
		if not perf_service.allow_floating_damage_number():
			return
	var text := str(info.get("text", ""))
	if text == "":
		return
	if DamageNumber._active_count >= DamageNumber.MAX_ACTIVE:
		return
	var effect = damage_number_scene.instantiate()
	var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if effects_container:
		effects_container.add_child(effect)
	else:
		get_tree().current_scene.add_child(effect)
	effect.global_position = hit_pos + Vector2(0, -22)
	if effect.has_method("setup_text"):
		effect.setup_text(text, _get_elemental_debug_color(multiplier), 12)
	elif effect.has_method("setup"):
		effect.setup(int(round(abs(multiplier * 100.0))), _get_elemental_debug_color(multiplier))

func _is_elemental_debug_text_enabled() -> bool:
	var scene := get_tree().current_scene
	if scene != null and scene.has_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_META):
		return bool(scene.get_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_META))
	if game_manager != null and game_manager.has_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_META):
		return bool(game_manager.get_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_META))
	return ELEMENTAL_DEBUG_FLOATING_TEXT

func _claim_elemental_debug_text_slot() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return true
	var now_msec := Time.get_ticks_msec()
	var last_msec := 0
	if scene.has_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_LAST_MSEC_META):
		last_msec = int(scene.get_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_LAST_MSEC_META))
	if now_msec - last_msec < ELEMENTAL_DEBUG_FLOATING_TEXT_MIN_INTERVAL_MSEC:
		return false
	scene.set_meta(ELEMENTAL_DEBUG_FLOATING_TEXT_LAST_MSEC_META, now_msec)
	return true

func _get_elemental_debug_color(multiplier: float) -> Color:
	if multiplier > ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER + 0.01:
		return Color(0.35, 1.0, 0.55, 1.0)
	if multiplier < ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER - 0.01:
		return Color(1.0, 0.35, 0.35, 1.0)
	return Color.WHITE

func _build_elemental_debug_text(attack_elements: Array[String], armor_element: String, multiplier: float) -> String:
	if attack_elements.is_empty() or armor_element == "":
		return ""
	var attack_label := "+".join(_format_element_labels(attack_elements))
	var armor_label := _format_element_label(armor_element)
	var arrow := "="
	if multiplier > ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER + 0.01:
		arrow = ">"
	elif multiplier < ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER - 0.01:
		arrow = "<"
	return "%s %s %s x%.2f" % [attack_label, arrow, armor_label, multiplier]

func _format_element_labels(elements: Array[String]) -> PackedStringArray:
	var labels := PackedStringArray()
	for element_id in elements:
		labels.append(_format_element_label(element_id))
	return labels

func _format_element_label(element_id: String) -> String:
	var value := _normalize_element_id(element_id)
	if value == "":
		return "?"
	return value.substr(0, 1).to_upper() + value.substr(1)

func _get_attack_elements_from_source() -> Array[String]:
	if not attack_elements_override.is_empty():
		return attack_elements_override.duplicate()

	var out: Array[String] = []
	var normalized_source := source_id.to_lower().strip_edges()
	if normalized_source == "":
		return out

	var data_elements := _get_attack_elements_from_tower_data(normalized_source)
	if not data_elements.is_empty():
		return data_elements

	# Legacy fallback for older/custom tower ids that are not in towers_tree.json.
	for element_id in ELEMENT_ORDER:
		if _source_id_contains_element(normalized_source, element_id):
			out.append(element_id)
	return out

func _get_attack_elements_from_tower_data(source: String) -> Array[String]:
	var normalized_source := source.to_lower().strip_edges()
	var out: Array[String] = []
	if normalized_source == "":
		return out
	_ensure_tower_elements_data_loaded()
	if not tower_elements_data_cache.has(normalized_source):
		return out
	var cached = tower_elements_data_cache.get(normalized_source, [])
	if cached is Array:
		return _normalize_element_array(cached)
	return out

func _ensure_tower_elements_data_loaded() -> void:
	if tower_elements_data_loaded:
		return
	tower_elements_data_loaded = true
	tower_elements_data_cache.clear()
	if not FileAccess.file_exists(TOWERS_TREE_DATA_PATH):
		return
	var file := FileAccess.open(TOWERS_TREE_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		return
	_collect_tower_elements_from_variant(json.data)

func _collect_tower_elements_from_variant(value: Variant) -> void:
	if value is Dictionary:
		if value.has("id") and value.has("elements"):
			var tower_key := str(value.get("id", "")).to_lower().strip_edges()
			var parsed_elements := _normalize_element_array(value.get("elements", []))
			if tower_key != "" and not parsed_elements.is_empty():
				tower_elements_data_cache[tower_key] = parsed_elements
		for child in value.values():
			if child is Dictionary or child is Array:
				_collect_tower_elements_from_variant(child)
	elif value is Array:
		for child in value:
			if child is Dictionary or child is Array:
				_collect_tower_elements_from_variant(child)

func _source_id_contains_element(normalized_source: String, element_id: String) -> bool:
	return (
		normalized_source == element_id
		or normalized_source.begins_with(element_id + "_")
		or normalized_source.begins_with("pure_" + element_id)
		or normalized_source.find("_" + element_id + "_") >= 0
		or normalized_source.ends_with("_" + element_id)
	)

func _get_target_armor_element(enemy: Variant) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return ""

	if enemy.has_method("get_armor_element"):
		var explicit_method_value := _normalize_element_id(str(enemy.get_armor_element()))
		if explicit_method_value != "":
			return explicit_method_value

	if enemy.has_meta("armor_element"):
		var meta_value := _normalize_element_id(str(enemy.get_meta("armor_element")))
		if meta_value != "":
			return meta_value

	var explicit_value := _normalize_element_id(str(enemy.get("armor_element")))
	if explicit_value != "":
		return explicit_value

	var type_id := ""
	if enemy.has_method("get_enemy_type"):
		type_id = str(enemy.get_enemy_type()).to_lower()
	else:
		type_id = str(enemy.get("enemy_type")).to_lower()

	var data_value := _get_armor_element_from_enemy_data(type_id)
	if data_value != "":
		return data_value

	return _normalize_element_id(str(ENEMY_TYPE_ARMOR_FALLBACK.get(type_id, "")))

func _get_armor_element_from_enemy_data(type_id: String) -> String:
	var normalized_type := type_id.to_lower().strip_edges()
	if normalized_type == "":
		return ""
	_ensure_enemy_armor_data_loaded()
	return _normalize_element_id(str(enemy_armor_data_cache.get(normalized_type, "")))

func _ensure_enemy_armor_data_loaded() -> void:
	if enemy_armor_data_loaded:
		return
	enemy_armor_data_loaded = true
	enemy_armor_data_cache.clear()
	if not FileAccess.file_exists(ENEMIES_DATA_PATH):
		return
	var file := FileAccess.open(ENEMIES_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		return
	if not (json.data is Dictionary):
		return
	for key in json.data.keys():
		var enemy_config = json.data[key]
		if not (enemy_config is Dictionary):
			continue
		var armor_value := _normalize_element_id(str(enemy_config.get("armor_element", "")))
		if armor_value != "":
			enemy_armor_data_cache[str(key).to_lower()] = armor_value
			var config_id := str(enemy_config.get("id", "")).to_lower().strip_edges()
			if config_id != "":
				enemy_armor_data_cache[config_id] = armor_value

func _normalize_element_array(raw_elements) -> Array[String]:
	var out: Array[String] = []
	if raw_elements is Array:
		for raw_element in raw_elements:
			var value := _normalize_element_id(str(raw_element))
			if value != "" and not out.has(value):
				out.append(value)
	elif raw_elements != null:
		var value := _normalize_element_id(str(raw_elements))
		if value != "":
			out.append(value)
	return out

func _normalize_element_id(raw_element: String) -> String:
	var value := raw_element.to_lower().strip_edges()
	if value == "null" or value == "<null>":
		return ""
	if ELEMENT_ORDER.has(value):
		return value
	return ""

func _apply_damage_amp_to_enemy(enemy: Variant) -> void:
	if vulnerability_percent <= 0.0 or vulnerability_duration <= 0.0:
		return
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(1.0 + vulnerability_percent, vulnerability_duration)

func _apply_status_effects_to_enemy(enemy: Variant) -> void:
	if status_effects.is_empty() or enemy == null or not is_instance_valid(enemy):
		return
	for effect in status_effects:
		var effect_type := str(effect.get("type", "")).to_lower()
		var duration := float(effect.get("duration", 0.0))
		match effect_type:
			"armor_reduction":
				if enemy.has_method("apply_armor_reduction"):
					enemy.apply_armor_reduction(float(effect.get("percent", 0.0)), duration)
			"damage_amp":
				if enemy.has_method("apply_damage_amp"):
					enemy.apply_damage_amp(1.0 + float(effect.get("percent", 0.0)), duration)
			"dot":
				if enemy.has_method("apply_damage_over_time"):
					enemy.apply_damage_over_time(float(effect.get("damage_per_second", 0.0)), duration, source_id, str(effect.get("attack_type", "dot")))
			"root":
				if enemy.has_method("apply_root"):
					enemy.apply_root(duration, float(effect.get("snare_percent", 1.0)))
			"delayed_damage":
				if enemy.has_method("apply_delayed_damage"):
					enemy.apply_delayed_damage(float(effect.get("amount", 0.0)), float(effect.get("delay", duration)), source_id, str(effect.get("attack_type", "delayed")))

func can_affect_enemy(enemy: Variant) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.has_method("get_enemy_category"):
		return true
	return target_categories.has(str(enemy.get_enemy_category()).to_lower())

func _normalize_target_categories(raw_categories) -> Array[String]:
	var normalized: Array[String] = []
	if raw_categories is Array:
		for category in raw_categories:
			var value = str(category).strip_edges().to_lower()
			if (value == ENEMY_CATEGORY_LAND or value == ENEMY_CATEGORY_AIR) and not normalized.has(value):
				normalized.append(value)
	elif raw_categories != null:
		var value = str(raw_categories).strip_edges().to_lower()
		if value == ENEMY_CATEGORY_LAND or value == ENEMY_CATEGORY_AIR:
			normalized.append(value)
	if normalized.is_empty():
		normalized.append(ENEMY_CATEGORY_LAND)
	return normalized

func _draw_lightning_projectile() -> void:
	# Jagged tail behind the projectile head
	var pts = PackedVector2Array()
	pts.append(Vector2.ZERO)
	
	# Create 3-4 jagged points backward
	var back_dir = Vector2.LEFT
	if is_instance_valid(target):
		var target_pos = _get_hit_anchor_global_position(target)
		back_dir = (global_position - target_pos).normalized()
	
	for i in range(1, 4):
		var base = back_dir * i * 8.0
		var perp = Vector2(-back_dir.y, back_dir.x)
		var offset = perp * randf_range(-6.0, 6.0)
		pts.append(base + offset)
	
	draw_polyline(pts, Color(vfx_glow_color.r, vfx_glow_color.g, vfx_glow_color.b, 0.8), 3.0, true)
	draw_polyline(pts, Color.WHITE, 1.0, true)
	draw_circle(Vector2.ZERO, 3.0, vfx_core_color)
