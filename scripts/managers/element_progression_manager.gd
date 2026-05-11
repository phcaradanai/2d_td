extends Node

signal element_levels_changed(levels: Dictionary)
signal element_pick_available(pending_picks: int)

const ELEMENT_ORDER: Array[String] = ["light", "darkness", "water", "fire", "nature", "earth"]
const ELEMENT_LABELS := {
	"light": "Light",
	"darkness": "Darkness",
	"water": "Water",
	"fire": "Fire",
	"nature": "Nature",
	"earth": "Earth"
}
const MAX_ELEMENT_LEVEL: int = 3

var element_levels: Dictionary = {}
var pending_picks: int = 0

func _ready() -> void:
	if element_levels.is_empty():
		reset(false)

func reset(emit_update: bool = true) -> void:
	element_levels.clear()
	for element_id in ELEMENT_ORDER:
		element_levels[element_id] = 0
	pending_picks = 0
	if emit_update:
		element_levels_changed.emit(get_element_levels())

func grant_pick(amount: int = 1) -> void:
	pending_picks += max(0, amount)
	element_pick_available.emit(pending_picks)

func has_pending_pick() -> bool:
	return pending_picks > 0

func choose_element(element_id: String) -> bool:
	if pending_picks <= 0:
		return false
	if not element_levels.has(element_id):
		return false
	var current_level: int = int(element_levels[element_id])
	if current_level >= MAX_ELEMENT_LEVEL:
		return false
	element_levels[element_id] = current_level + 1
	pending_picks -= 1
	element_levels_changed.emit(get_element_levels())
	if pending_picks > 0:
		element_pick_available.emit(pending_picks)
	return true

func get_element_levels() -> Dictionary:
	return element_levels.duplicate(true)

func get_element_label(element_id: String) -> String:
	return str(ELEMENT_LABELS.get(element_id, element_id.capitalize()))

func get_element_summary() -> String:
	var parts: Array[String] = []
	for element_id in ELEMENT_ORDER:
		var level: int = int(element_levels.get(element_id, 0))
		if level > 0:
			parts.append("%s %d" % [get_element_label(element_id), level])
	if parts.is_empty():
		return "No elements unlocked"
	return " | ".join(parts)

func can_build_tower(tower_config: Dictionary) -> bool:
	if tower_config.is_empty():
		return false
	var combo_type: String = str(tower_config.get("combo_type", "neutral"))
	if combo_type == "neutral":
		return true
	var tower_elements: Array = tower_config.get("elements", [])
	if tower_elements.is_empty():
		return true
	var required_level: int = int(tower_config.get("required_element_level", 1))
	for raw_element in tower_elements:
		var element_id: String = str(raw_element)
		if int(element_levels.get(element_id, 0)) < required_level:
			return false
	return true

func get_locked_reason(tower_config: Dictionary) -> String:
	if tower_config.is_empty():
		return "Tower config missing"
	if can_build_tower(tower_config):
		return ""
	var required_level: int = int(tower_config.get("required_element_level", 1))
	var missing: Array[String] = []
	for raw_element in tower_config.get("elements", []):
		var element_id: String = str(raw_element)
		var owned_level: int = int(element_levels.get(element_id, 0))
		if owned_level < required_level:
			missing.append("%s %d" % [get_element_label(element_id), required_level])
	return "Requires " + ", ".join(missing)

func get_buildable_tower_ids(towers_config: Dictionary) -> Array[String]:
	var entries: Array[Dictionary] = []
	for tower_id in towers_config.keys():
		var cfg: Dictionary = towers_config.get(tower_id, {})
		if not bool(cfg.get("build_entry", false)):
			continue
		if not can_build_tower(cfg):
			continue
		var cfg_elements: Array = cfg.get("elements", [])
		entries.append({
			"id": str(tower_id),
			"order": int(cfg.get("shop_order", 9999)),
			"combo_count": cfg_elements.size()
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["order"]) == int(b["order"]):
			return str(a["id"]) < str(b["id"])
		return int(a["order"]) < int(b["order"])
	)
	var ids: Array[String] = []
	for entry in entries:
		ids.append(str(entry["id"]))
	return ids
