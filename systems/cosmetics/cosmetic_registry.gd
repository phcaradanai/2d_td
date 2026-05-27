extends Node

const COSMETICS_PATH := "res://data/cosmetics/cosmetics.json"
const TOWERS_DIR     := "res://data/cosmetics/towers/"

const SLOT_TOWER_SKIN    := "tower_skin"
const SLOT_PROJECTILE_SKIN := "projectile_skin"
const SLOT_IMPACT_SKIN   := "impact_skin"

var slots: Array[String] = []
var rarities: Dictionary = {}
var cosmetics_by_id: Dictionary = {}
var cosmetics_by_slot: Dictionary = {}
var cosmetics_by_tower_slot: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	slots.clear()
	rarities.clear()
	cosmetics_by_id.clear()
	cosmetics_by_slot.clear()
	cosmetics_by_tower_slot.clear()

	var base := _load_json(COSMETICS_PATH)
	for slot in base.get("slots", []):
		slots.append(str(slot))
	rarities = base.get("rarities", {}).duplicate(true)

	var dir := DirAccess.open(TOWERS_DIR)
	if dir == null:
		push_warning("[CosmeticRegistry] towers/ directory not found: " + TOWERS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var tower_id := file_name.get_basename()
			_load_tower_file(TOWERS_DIR + file_name, tower_id)
		file_name = dir.get_next()
	dir.list_dir_end()

func get_cosmetic(cosmetic_id: String) -> Dictionary:
	return cosmetics_by_id.get(cosmetic_id, {}).duplicate(true)

func get_for_tower_slot(tower_id: String, slot: String) -> Array[Dictionary]:
	var key := _tower_slot_key(tower_id, slot)
	var out: Array[Dictionary] = []
	for id in cosmetics_by_tower_slot.get(key, []):
		out.append(get_cosmetic(str(id)))
	return out

func get_rarity_color(rarity: String) -> Color:
	var cfg: Dictionary = rarities.get(rarity, {})
	return Color.from_string(str(cfg.get("color", "#66d9ff")), Color(0.4, 0.85, 1.0))

func get_rarity_label(rarity: String) -> String:
	var cfg: Dictionary = rarities.get(rarity, {})
	return str(cfg.get("label", rarity.capitalize()))

## Load one per-tower file. tower_id and slot are injected automatically.
func _load_tower_file(path: String, tower_id: String) -> void:
	var data := _load_json(path)
	for slot in data.keys():
		var entries = data[slot]
		if not entries is Array:
			continue
		for raw in entries:
			if not raw is Dictionary:
				continue
			var cfg: Dictionary = raw.duplicate(true)
			cfg["tower_id"] = tower_id
			cfg["slot"]     = slot
			var id := str(cfg.get("id", "")).strip_edges()
			if id == "":
				continue
			cosmetics_by_id[id] = cfg
			if not cosmetics_by_slot.has(slot):
				cosmetics_by_slot[slot] = []
			cosmetics_by_slot[slot].append(id)
			var key := _tower_slot_key(tower_id, slot)
			if not cosmetics_by_tower_slot.has(key):
				cosmetics_by_tower_slot[key] = []
			cosmetics_by_tower_slot[key].append(id)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[CosmeticRegistry] Missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("[CosmeticRegistry] Invalid JSON: %s" % path)
		return {}
	return json.data

func _tower_slot_key(tower_id: String, slot: String) -> String:
	return "%s::%s" % [tower_id, slot]
