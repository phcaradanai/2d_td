extends Node2D

const PERFORMANCE_MODE := true  # Disables projectile trail and impact effects for 60 FPS
const ELEMENTAL_DEBUG_FLOATING_TEXT := true

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

@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
@onready var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")
@onready var splash_effect_scene: PackedScene = preload("res://scenes/effects/SplashEffect.tscn")
@onready var impact_effect_scene: PackedScene = preload("res://scenes/effects/ImpactEffect.tscn")
@onready var damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
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
	
	# Density Control: Shorten trail for fast/rapid projectiles to avoid clutter
	if p_speed > 600:
		max_trail_points = 4
	elif p_speed > 400:
		max_trail_points = 6
	else:
		max_trail_points = 8

func setup_chain(jumps: int, p_range: float, falloff: float, excluded: Array = []) -> void:
	chain_jumps = jumps
	chain_range = p_range
	chain_falloff = falloff
	chained_enemies = excluded
	if is_instance_valid(target) and not chained_enemies.has(target):
		chained_enemies.append(target)

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return
		
	if target == null or not is_instance_valid(target):
		queue_free()
		return
		
	var target_pos := target.global_position
	if target.has_method("get_hit_origin"):
		target_pos = target.get_hit_origin()
		
	var to_target := target_pos - global_position
	var distance := to_target.length()
	
	# STANDARD: Use global distance for hit detection
	if distance < 10.0:
		hit_target()
		return
		
	global_position += to_target.normalized() * speed * delta

	if not PERFORMANCE_MODE:
		_update_trail()

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _update_trail() -> void:
	# Avoid adding points if we're already at the target or dead
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) < 5.0:
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
	if attack_type == "chain":
		_draw_lightning_projectile()
		return

	if PERFORMANCE_MODE:
		var perf_color := Color(0.3, 1.0, 0.6, 1.0) if speed > 550 else Color(0.3, 0.7, 1.0, 1.0)
		if attack_type == "splash": perf_color = Color(1.0, 0.5, 0.2, 1.0)
		elif attack_type == "slow": perf_color = Color(0.7, 0.5, 1.0, 1.0)
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
	var rot = 0.0
	if is_instance_valid(target):
		rot = (target.global_position - global_position).angle()
	
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	
	var color = Color(0.3, 0.8, 1.0, 1.0) # Default cyan
	
	if attack_type == "splash": # Cannon
		color = Color(1.0, 0.5, 0.2, 1.0)
		_draw_shell(color)
	elif attack_type == "slow": # Slow
		color = Color(0.7, 0.5, 1.0, 1.0)
		_draw_bolt(color, 12.0)
	else: # Basic / Rapid
		color = Color(0.3, 1.0, 0.6, 1.0) if speed > 550 else Color(0.3, 0.7, 1.0, 1.0)
		_draw_bolt(color, 10.0)

func _draw_bolt(color: Color, length: float) -> void:
	var pts = [Vector2(length, 0), Vector2(-length/2, -3), Vector2(-length/2, 3)]
	draw_colored_polygon(pts, color)
	draw_polyline(pts + [pts[0]], Color.WHITE, 1.0)
	# Glow
	draw_line(Vector2(-length, 0), Vector2(length, 0), Color(color.r, color.g, color.b, 0.4), 4.0)

func _draw_shell(color: Color) -> void:
	draw_circle(Vector2.ZERO, 5, color)
	draw_arc(Vector2.ZERO, 5, 0, TAU, 16, Color.WHITE, 1.5)
	# Trail tail
	draw_line(Vector2(-8, 0), Vector2(-2, 0), color, 3.0)

func hit_target() -> void:
	var hit_global = global_position
	if is_instance_valid(target):
		if target.has_method("get_hit_origin"):
			hit_global = target.get_hit_origin()
		else:
			hit_global = target.global_position
		
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
			# STANDARD: Use captured hit point and current pos for angle
			var impact_angle = (hit_global - global_position).angle()
			_spawn_impact_effect(hit_global, Color.WHITE, impact_angle)
			
			if attack_type == "chain" and chain_jumps > 0:
				_handle_chain_jump(hit_global)
			
			if audio_manager:
				audio_manager.play_sfx("projectile_hit")
	
	queue_free()

func _handle_chain_jump(hit_pos: Vector2) -> void:
	var next_target = _find_next_chain_target(hit_pos)
	if next_target:
		# VISUAL: Spawn arc from previous target to next
		var arc = Node2D.new()
		arc.set_script(load("res://scripts/effects/lightning_arc.gd"))
		get_parent().add_child(arc)
		arc.global_position = hit_pos
		arc.setup(hit_pos, next_target.global_position, Color(0.5, 0.8, 1.0))
		
		var next_proj = duplicate()
		get_parent().add_child(next_proj)
		next_proj.global_position = hit_pos
		next_proj.setup(next_target, damage * chain_falloff, speed, "chain", effect_radius, slow_percent, slow_duration, target_categories, source_id, vulnerability_percent, vulnerability_duration, attack_elements_override)
		next_proj.setup_chain(chain_jumps - 1, chain_range, chain_falloff, chained_enemies)
		next_proj.modulate = modulate # Keep lightning color

func _find_next_chain_target(hit_pos: Vector2) -> Node2D:
	var best_target = null
	var min_dist = chain_range
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			if chained_enemies.has(enemy): continue
			if not can_affect_enemy(enemy): continue
			
			var dist = hit_pos.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				best_target = enemy
				
	return best_target

func _spawn_impact_effect(hit_pos: Vector2, color: Color = Color.WHITE, hit_angle: float = 0.0) -> void:
	if PERFORMANCE_MODE: return
	if impact_effect_scene:
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
			effect.setup(color, scale_val)

func apply_area_effect(hit_pos: Vector2) -> void:
	if attack_type == "splash":
		if audio_manager:
			audio_manager.play_sfx("splash_hit")
		# Screen shake for cannon
		var main = get_tree().current_scene
		if main and main.has_method("shake_camera"):
			main.shake_camera(8.0, 0.2)
	elif attack_type == "slow":
		if audio_manager:
			audio_manager.play_sfx("projectile_hit")

	# Spawn visual effect at hit position
	if not PERFORMANCE_MODE and splash_effect_scene:
		var effect = splash_effect_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
			effect.global_position = hit_pos
		else:
			get_tree().current_scene.add_child(effect)
			effect.global_position = hit_pos
		
		var effect_color = Color(1, 0.5, 0.2) if attack_type == "splash" else Color(0.4, 0.8, 1.0)
		if effect.has_method("setup"):
			effect.setup(effect_radius, effect_color)
		
	# Find enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			if not can_affect_enemy(enemy):
				continue
			
			# Precision: Use hit center or aim point if available
			var enemy_pos = enemy.global_position
			if enemy.has_method("get_hit_origin"):
				enemy_pos = enemy.get_hit_origin()
			elif enemy.has_method("get_aim_point"):
				enemy_pos = enemy.get_aim_point()
			
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
				elif attack_type == "slow":
					# Area slow deals its low base damage + applies debuffs.
					var slow_info := _get_elemental_damage_info(damage, enemy)
					var slow_damage := float(slow_info.get("final_damage", damage))
					enemy.take_damage(slow_damage, enemy_pos, source_id, attack_type)
					_spawn_elemental_debug_text(enemy_pos, slow_info)
					if enemy.has_method("apply_slow"):
						enemy.apply_slow(slow_percent, slow_duration)
					_apply_damage_amp_to_enemy(enemy)

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
	if not ELEMENTAL_DEBUG_FLOATING_TEXT:
		return
	var multiplier := float(info.get("multiplier", ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER))
	if is_equal_approx(multiplier, ELEMENT_DAMAGE_NEUTRAL_MULTIPLIER):
		return
	var text := str(info.get("text", ""))
	if text == "":
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
		var target_pos = target.global_position
		if target.has_method("get_hit_origin"):
			target_pos = target.get_hit_origin()
		back_dir = (global_position - target_pos).normalized()
	
	for i in range(1, 4):
		var base = back_dir * i * 8.0
		var perp = Vector2(-back_dir.y, back_dir.x)
		var offset = perp * randf_range(-6.0, 6.0)
		pts.append(base + offset)
	
	draw_polyline(pts, Color(0.5, 0.8, 1.0, 0.8), 3.0, true)
	draw_polyline(pts, Color.WHITE, 1.0, true)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
