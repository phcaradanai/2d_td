extends RefCounted
class_name ElementalShopService

const DEFAULT_STARTER_TOWERS: Array[String] = ["basic_tower_t1", "neutral_cannon_tower"]

static func get_buildable_tower_ids(
	element_progression_manager: Variant,
	towers_config: Dictionary,
	starter_tower_ids: Array = DEFAULT_STARTER_TOWERS
) -> Array[String]:
	var ids: Array[String] = []

	if element_progression_manager != null and element_progression_manager.has_method("get_buildable_tower_ids"):
		var raw_ids: Variant = element_progression_manager.get_buildable_tower_ids(towers_config)
		ids = normalize_tower_ids(raw_ids)

	return ensure_starter_towers_in_shop(ids, starter_tower_ids, towers_config)

static func ensure_starter_towers_in_shop(
	ids: Array[String],
	starter_tower_ids: Array = DEFAULT_STARTER_TOWERS,
	towers_config: Dictionary = {}
) -> Array[String]:
	var result: Array[String] = ids.duplicate()

	for raw_id in starter_tower_ids:
		var tower_id := str(raw_id)
		if tower_id == "":
			continue
		if not towers_config.is_empty() and not towers_config.has(tower_id):
			continue
		if not result.has(tower_id):
			result.insert(min(result.size(), 1), tower_id)

	if result.is_empty():
		for raw_id in starter_tower_ids:
			var fallback_id := str(raw_id)
			if fallback_id == "":
				continue
			if towers_config.is_empty() or towers_config.has(fallback_id):
				result.append(fallback_id)
				break

	return result

static func normalize_tower_ids(raw_ids: Variant) -> Array[String]:
	var ids: Array[String] = []
	if not (raw_ids is Array):
		return ids

	for raw_id in raw_ids:
		var tower_id := str(raw_id)
		if tower_id != "" and not ids.has(tower_id):
			ids.append(tower_id)

	return ids
