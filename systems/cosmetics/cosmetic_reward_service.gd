extends Node

func process_victory(level_id: String, summary: Dictionary) -> Array[Dictionary]:
	if str(summary.get("result", "")) != "Victory":
		return []
	return _process_rules(level_id)

func process_current_progress() -> Array[Dictionary]:
	return _process_rules("")

func _process_rules(level_id: String = "") -> Array[Dictionary]:
	var inventory := get_node_or_null("/root/CosmeticInventory")
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if inventory == null or registry == null:
		return []
	var newly_unlocked: Array[Dictionary] = []
	for raw_id in registry.cosmetics_by_id.keys():
		var id := str(raw_id)
		if inventory.is_unlocked(id):
			continue
		var cfg: Dictionary = registry.get_cosmetic(id)
		var condition: Dictionary = cfg.get("unlock_condition", {}) as Dictionary
		if condition.is_empty():
			continue
		if _condition_passes(condition, level_id):
			if inventory.unlock(id):
				newly_unlocked.append(cfg)
	return newly_unlocked

func _condition_passes(condition: Dictionary, level_id: String) -> bool:
	if str(condition.get("type", "")) == "always_unlocked":
		return true
	var sm := _save_manager()
	if sm == null:
		return false
	match str(condition.get("type", "")):
		"total_stars":
			return _total_stars(sm) >= int(condition.get("count", 0))
		"perfect_level":
			var target_level := str(condition.get("level_id", ""))
			if target_level == "":
				return false
			return (level_id == "" or level_id == target_level) and _is_perfect(sm, target_level)
		"perfect_count":
			return _perfect_count(sm) >= int(condition.get("count", 0))
		"perfect_any":
			return _perfect_count(sm) >= int(condition.get("count", 1))
	return false

func _total_stars(sm: Node) -> int:
	var total := 0
	for rec in _level_records(sm):
		total += int(rec.get("best_stars", 0))
	return total

func _perfect_count(sm: Node) -> int:
	var total := 0
	for rec in _level_records(sm):
		if bool(rec.get("perfect_clear", false)):
			total += 1
	return total

func _is_perfect(sm: Node, level_id: String) -> bool:
	if sm.has_method("get_level_record"):
		return bool(sm.get_level_record(level_id).get("perfect_clear", false))
	return false

func _level_records(sm: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Variant = sm.get("save_data")
	if not (data is Dictionary):
		return out
	var levels: Dictionary = data.get("levels", {})
	for level_id in levels.keys():
		var rec: Dictionary = levels[level_id]
		out.append(rec)
	return out

func _save_manager() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("SaveManager") if scene != null else null
