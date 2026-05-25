extends RefCounted
class_name WaveIntelService

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"

static func build_wave_intel(wave_data: Dictionary) -> Dictionary:
	var groups: Array = get_preview_wave_groups(wave_data)
	var enemy_counts: Dictionary = {}
	var categories: Dictionary = {
		ENEMY_CATEGORY_LAND: 0,
		ENEMY_CATEGORY_AIR: 0,
	}
	var total_count: int = 0

	for group in groups:
		if not (group is Dictionary):
			continue
		var enemy_type := str(group.get("enemy_type", group.get("type", "basic")))
		var count := int(group.get("count", 1))
		count = max(0, count)
		if count <= 0:
			continue
		enemy_counts[enemy_type] = int(enemy_counts.get(enemy_type, 0)) + count
		total_count += count

		var category := str(group.get("category", ""))
		if category == "":
			category = infer_enemy_category(enemy_type)
		if not categories.has(category):
			categories[category] = 0
		categories[category] = int(categories.get(category, 0)) + count

	var traits: Array[String] = derive_wave_traits(enemy_counts, total_count, categories)
	return {
		"total_count": total_count,
		"enemy_counts": enemy_counts,
		"categories": categories,
		"traits": traits,
		"recommended_roles": recommend_roles_for_wave(traits),
	}

static func get_preview_wave_groups(wave_data: Dictionary) -> Array:
	if wave_data.has("groups") and wave_data["groups"] is Array:
		return wave_data["groups"]
	if wave_data.has("enemies") and wave_data["enemies"] is Array:
		return wave_data["enemies"]
	return []

static func infer_enemy_category(enemy_type: String) -> String:
	var normalized := enemy_type.to_lower()
	if normalized.contains("air") or normalized.contains("fly") or normalized.contains("drone"):
		return ENEMY_CATEGORY_AIR
	return ENEMY_CATEGORY_LAND

static func sanitize_wave_name(raw_name: String) -> String:
	var name := raw_name.strip_edges()
	name = name.replace("Elemental Guardian", "Elemental Sentinel")
	name = name.replace("Guardian", "Sentinel")
	return name

static func derive_wave_traits(enemy_counts: Dictionary, total_count: int, categories: Dictionary) -> Array[String]:
	var traits: Array[String] = []

	var air_count := int(categories.get(ENEMY_CATEGORY_AIR, 0))
	if air_count > 0:
		traits.append("Air")
	if air_count > 0 and air_count < total_count:
		traits.append("Mixed")

	var unique_enemy_types := enemy_counts.keys().size()
	if unique_enemy_types >= 3:
		traits.append("Mixed")

	for enemy_type in enemy_counts.keys():
		var t := str(enemy_type).to_lower()
		if t.contains("fast") or t.contains("runner") or t.contains("skitter"):
			traits.append("Fast")
		if t.contains("heavy") or t.contains("tank") or t.contains("boss") or t.contains("armored"):
			traits.append("Heavy")
		if t.contains("shield"):
			traits.append("Shield")
		if t.contains("swarm") or t.contains("split"):
			traits.append("Swarm")
		if t.contains("stealth") or t.contains("cloak"):
			traits.append("Stealth")
		if t.contains("heal") or t.contains("support"):
			traits.append("Healing")
		if t.contains("split"):
			traits.append("Splitting")
		if t.contains("disrupt") or t.contains("jammer"):
			traits.append("Disruption")
		if t.contains("anti_hero") or t.contains("anti-hero"):
			traits.append("Anti-Hero")

	return dedupe_strings(traits)

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

	return dedupe_strings(roles)

static func dedupe_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique
