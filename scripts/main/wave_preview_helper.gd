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

static func recommend_roles_for_wave(traits: Array[String]) -> Array[String]:
	var roles: Array[String] = []

	# Element TD-style guidance: recommend element roles and combo directions,
	# not old tower classes such as Basic/Rapid/Cannon/Slow/Guardian.
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
	if traits.has("Shield"):
		warnings.append("Protected units take reduced damage inside the dome.")
	if traits.has("Anti-Hero"):
		warnings.append("Hunter targets Guardian directly. Priority target him.")
	if traits.has("Shield") and traits.has("Anti-Hero"):
		warnings.append("Danger: Shielded high-threat units detected.")
	return warnings

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
