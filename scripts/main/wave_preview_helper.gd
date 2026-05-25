extends RefCounted

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]

static func level_id_to_int(level_id_value) -> int:
	var text = str(level_id_value)
	if text == "": return 0
	if text.is_valid_int(): return int(text)
	var parts = text.split("_")
	if parts.is_empty(): return 0
	var suffix = parts[parts.size() - 1]
	return int(suffix) if suffix.is_valid_int() else 0

static func format_level_id(level_id: int) -> String:
	return "level_%02d" % level_id

static func sanitize_wave_name(raw_name: String) -> String:
	var name := raw_name.strip_edges()
	name = name.replace("Elemental Guardian", "Elemental Sentinel")
	name = name.replace("Guardian", "Sentinel")
	return name

static func normalize_enemy_type(raw: String) -> String:
	var value = raw.to_lower()
	match value:
		"basic", "normal", "grunt": return "Normal"
		"fast", "runner", "scout": return "Fast"
		"tank", "heavy", "brute": return "Heavy"
		"swarm", "small": return "Swarm"
		"air", "flyer": return "Air"
		"air_fast", "fast_air", "flyer_fast": return "Fast"
		"air_basic", "basic_air", "flyer_basic": return "Normal"
		_: return raw.capitalize()

static func classify_enemy_group(raw_type: String, group: Dictionary, enemy_config: Dictionary = {}) -> Dictionary:
	var enemy_type := raw_type.to_lower()
	var visual_type := str(enemy_config.get("visual_type", enemy_type)).to_lower()
	var skill := str(enemy_config.get("skill", "")).to_lower()
	var secondary_skill := str(enemy_config.get("secondary_skill", "")).to_lower()
	var tags := _string_array(enemy_config.get("tags", []))
	var affixes := _merged_affixes(group, enemy_config)
	var traits: Array[String] = []
	var base_label := _base_role_label(enemy_type, visual_type, tags, skill)

	if group.has("category"):
		var group_category := normalize_enemy_category(group.get("category", ENEMY_CATEGORY_LAND))
		if group_category == ENEMY_CATEGORY_AIR and not traits.has("Air"):
			traits.append("Air")
	elif normalize_enemy_category(enemy_config.get("category", ENEMY_CATEGORY_LAND)) == ENEMY_CATEGORY_AIR:
		traits.append("Air")

	if tags.has("boss") or enemy_type.begins_with("boss"):
		traits.append("Boss")
	if tags.has("fast") or tags.has("runner") or enemy_type in ["fast", "runner", "fast_flyer"] or affixes.has("fast"):
		traits.append("Fast")
	if tags.has("heavy") or tags.has("armored") or enemy_type in ["tank", "bulwark", "shieldbearer", "armored_flyer"] or affixes.has("mechanical"):
		traits.append("Heavy")
	if tags.has("swarm") or enemy_type == "swarm":
		traits.append("Swarm")
	if tags.has("shield") or skill == "shield_aura":
		traits.append("Shield")
	if tags.has("anti_hero") or enemy_type == "hunter":
		traits.append("Anti-Hero")
	if tags.has("healing") or skill == "healer" or affixes.has("healing"):
		traits.append("Healing")
	if tags.has("stealth") or skill == "stealth" or affixes.has("image"):
		traits.append("Stealth")
	if tags.has("disruptor") or skill == "disrupt_aura":
		traits.append("Disruption")
	if tags.has("splitter") or skill == "split_on_death":
		traits.append("Splitting")
	if affixes.has("undead"):
		traits.append("Undead")
	if affixes.has("image"):
		traits.append("Illusion")
	if affixes.has("mechanical"):
		traits.append("Mechanical")
	if secondary_skill == "regenerate":
		traits.append("Regeneration")
	if secondary_skill == "spawn_minions":
		traits.append("Minions")

	var prefix := _role_prefix(base_label, traits)
	var label := base_label if prefix == "" else "%s %s" % [prefix, base_label]
	if traits.has("Air") and not label.begins_with("Air "):
		label = "Air " + label

	return {
		"label": label,
		"traits": _dedupe_strings(traits),
		"category": ENEMY_CATEGORY_AIR if traits.has("Air") else ENEMY_CATEGORY_LAND,
	}

static func _base_role_label(enemy_type: String, visual_type: String, tags: Array, skill: String) -> String:
	if tags.has("boss") or enemy_type.begins_with("boss"):
		if skill == "healer": return "Boss Healer"
		if skill == "disrupt_aura": return "Boss Disruptor"
		if skill == "shield_aura": return "Boss Shield"
		if tags.has("runner") or tags.has("fast"): return "Boss Runner"
		if tags.has("stealth"): return "Boss Cloaked"
		if tags.has("swarm"): return "Boss Swarm"
		if tags.has("splitter"): return "Boss Splitter"
		return "Boss"
	if skill == "healer" or enemy_type == "healer" or visual_type == "healer": return "Healer"
	if skill == "disrupt_aura" or enemy_type == "disruptor" or visual_type == "disruptor": return "Disruptor"
	if skill == "shield_aura" or enemy_type in ["bulwark", "shieldbearer"] or visual_type in ["bulwark", "shieldbearer"]: return "Shieldbearer"
	if skill == "stealth" or enemy_type == "cloaked" or visual_type == "cloaked": return "Cloaked"
	if skill == "split_on_death" or enemy_type == "splitter" or visual_type == "splitter": return "Splitter"
	if enemy_type == "hunter" or visual_type == "hunter": return "Hunter"
	if enemy_type == "runner" or visual_type == "runner": return "Runner"
	if enemy_type in ["tank", "heavy"] or visual_type == "tank": return "Heavy"
	if enemy_type == "swarm" or visual_type == "swarm": return "Swarm"
	if enemy_type in ["flyer", "air", "air_basic"] or visual_type == "flyer": return "Flyer"
	if enemy_type in ["fast_flyer", "air_fast"] or visual_type == "fast_flyer": return "Fast Flyer"
	if enemy_type in ["armored_flyer", "air_heavy"] or visual_type == "armored_flyer": return "Armored Flyer"
	if enemy_type in ["fast", "scout"] or visual_type == "fast": return "Fast"
	return normalize_enemy_type(enemy_type)

static func _role_prefix(base_label: String, traits: Array[String]) -> String:
	if base_label in ["Healer", "Disruptor", "Shieldbearer", "Cloaked", "Splitter", "Hunter", "Runner"]:
		return ""
	if base_label.begins_with("Boss"):
		return ""
	if traits.has("Healing"): return "Healing"
	if traits.has("Disruption"): return "Disrupting"
	if traits.has("Shield"): return "Shielding"
	if traits.has("Mechanical"): return "Mechanical"
	if traits.has("Undead"): return "Undead"
	if traits.has("Illusion"): return "Illusion"
	if traits.has("Fast") and not base_label.contains("Fast"): return "Fast"
	return ""

static func _merged_affixes(group: Dictionary, enemy_config: Dictionary) -> Array:
	var result: Array = []
	for source in [enemy_config.get("affixes", []), group.get("affixes", [])]:
		for value in _string_array(source):
			if not result.has(value):
				result.append(value)
	return result

static func _string_array(value) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item).to_lower())
	return result

static func normalize_enemy_category(raw_category) -> String:
	var normalized = str(raw_category).strip_edges().to_lower()
	if VALID_ENEMY_CATEGORIES.has(normalized):
		return normalized
	return ENEMY_CATEGORY_LAND

static func format_preview_enemy_label(normalized_type: String, enemy_category: String) -> String:
	if enemy_category == ENEMY_CATEGORY_AIR and normalized_type != "Air":
		return "Air " + normalized_type
	return normalized_type

static func derive_wave_traits(enemy_counts: Dictionary, total_count: int, categories: Dictionary = {}) -> Array[String]:
	var traits: Array[String] = []
	if total_count == 0: return ["Standard"]
	
	if categories.has(ENEMY_CATEGORY_AIR): traits.append("Air")
	
	# Majority/Significance checks
	var has_fast = false
	var has_heavy = false
	var has_swarm = false
	var has_shield = false
	var has_anti_hero = false
	
	for type_name in enemy_counts.keys():
		var count = enemy_counts[type_name]
		var ratio = float(count) / total_count
		
		if type_name.contains("Fast") and ratio > 0.2: has_fast = true
		if type_name.contains("Heavy") and ratio > 0.2: has_heavy = true
		if type_name.contains("Swarm") and ratio > 0.4: has_swarm = true
		if type_name.contains("Bulwark") or type_name.contains("Shield"): has_shield = true
		if type_name.contains("Hunter") or type_name.contains("Anti-Hero"): has_anti_hero = true
		if type_name.contains("Healer"): traits.append("Healing")
		if type_name.contains("Cloaked") or type_name.contains("Ghost"): traits.append("Stealth")
		if type_name.contains("Disruptor") or type_name.contains("EMP"): traits.append("Disruption")
		if type_name.contains("Splitter"): traits.append("Splitting")
		
	if has_fast: traits.append("Fast")
	if has_heavy: traits.append("Heavy")
	if has_swarm or total_count >= 15: traits.append("Swarm")
	if has_shield: traits.append("Shield")
	if has_anti_hero: traits.append("Anti-Hero")
	
	if enemy_counts.keys().size() >= 3:
		traits.append("Mixed")
	
	if traits.is_empty():
		traits.append("Standard")
		
	return traits

static func merge_wave_traits(base_traits: Array[String], extra_traits: Array[String]) -> Array[String]:
	var traits := base_traits.duplicate()
	for raw_trait in extra_traits:
		var trait_name := str(raw_trait)
		if trait_name != "" and not traits.has(trait_name):
			traits.append(trait_name)
	if traits.has("Standard") and traits.size() > 1:
		traits.erase("Standard")
	if traits.has("Boss") and not traits.has("Heavy"):
		traits.append("Heavy")
	return traits

static func recommend_roles_for_wave(traits: Array[String]) -> Array[String]:
	var roles: Array[String] = []

	# Element TD-style guidance: recommend element roles and combo directions,
	# not old tower classes such as Basic/Rapid/Cannon/Slow or removed hero systems.
	if traits.has("Air"):
		roles.append("Light/Nature anti-air")
		roles.append("Dual universal tower")

	if traits.has("Fast"):
		roles.append("Water slow")
		roles.append("Light rapid")

	if traits.has("Heavy"):
		roles.append("Fire splash")
		roles.append("Earth high damage")

	if traits.has("Shield"):
		roles.append("Fire + Earth splash")
		roles.append("Darkness vulnerability")

	if traits.has("Anti-Hero"):
		roles.append("Light burst")
		roles.append("Water control")

	if traits.has("Swarm"):
		roles.append("Fire splash")
		roles.append("Water + Nature slow field")

	if traits.has("Mixed"):
		roles.append("Dual element coverage")
		roles.append("Triple combo tower")

	if traits.has("Stealth"):
		roles.append("Light reveal damage")
		roles.append("Darkness chain pressure")

	if traits.has("Healing") or traits.has("Splitting"):
		roles.append("Light + Darkness chain")
		roles.append("Earth single-target focus")

	if traits.has("Disruption"):
		roles.append("Long range element combo")
		roles.append("Split tower placement")

	if roles.is_empty():
		roles.append("Starter tower")
		roles.append("Choose first element")

	var unique: Array[String] = []
	for r in roles:
		if not unique.has(r):
			unique.append(r)
	return unique

static func get_preview_wave_groups(wave_data: Dictionary) -> Array:
	if wave_data.has("groups") and wave_data["groups"] is Array:
		return wave_data["groups"]
	if wave_data.has("spawns") and wave_data["spawns"] is Array:
		return wave_data["spawns"]
	if wave_data.has("enemies") and wave_data["enemies"] is Array:
		return wave_data["enemies"]
	if wave_data.has("enemy_type") or wave_data.has("type"):
		return [wave_data]
	return []

static func derive_wave_warnings(traits: Array[String]) -> Array[String]:
	var warnings: Array[String] = []
	if traits.has("Boss"):
		warnings.append("Boss unit present. Keep damage focused while clearing escorts.")
	if traits.has("Shield"):
		warnings.append("Protected units take reduced damage inside the dome.")
	if traits.has("Anti-Hero"):
		warnings.append("Hunter pressure punishes exposed support and weak backline coverage.")
	if traits.has("Healing"):
		warnings.append("Healing support is active. Kill repair units before frontliners reset.")
	if traits.has("Disruption"):
		warnings.append("Disruptors slow tower reloads. Spread tower placement and prioritize them.")
	if traits.has("Stealth"):
		warnings.append("Cloaked enemies are deprioritized while visible enemies remain.")
	if traits.has("Splitting"):
		warnings.append("Splitters create extra bodies on death. Reserve splash or chain coverage.")
	if traits.has("Mechanical"):
		warnings.append("Mechanical units can create temporary invulnerability windows.")
	if traits.has("Undead"):
		warnings.append("Undead units may return once after lethal damage.")
	if traits.has("Illusion"):
		warnings.append("Illusion pressure adds decoys or copies; avoid overfocusing one target.")
	if traits.has("Shield") and traits.has("Anti-Hero"):
		warnings.append("Danger: Shielded high-threat units detected.")
	return warnings

static func extract_progression_note(raw_intel: String) -> String:
	var text := raw_intel.strip_edges()
	if text == "":
		return ""
	if text.contains("Element pick") or text.contains("element pick"):
		return text
	if text.contains("Final normal wave"):
		return text
	return ""

static func format_wave_enemy_summary(summary: Dictionary) -> String:
	var counts = summary.get("enemy_counts", {})
	if counts.is_empty(): return "Malformed Wave"
	var parts = []
	var type_order = ["Normal", "Fast", "Heavy", "Swarm", "Air", "Air Normal", "Air Fast", "Air Heavy", "Air Swarm"]
	for type_name in type_order:
		if counts.has(type_name):
			parts.append("%s x%d" % [type_name, int(counts[type_name])])
	for type_name in counts.keys():
		if not type_order.has(str(type_name)):
			parts.append("%s x%d" % [str(type_name), int(counts[type_name])])
	return ", ".join(parts)

static func _dedupe_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique
