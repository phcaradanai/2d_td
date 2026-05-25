extends Node

const COSMETICS_PATH := "res://data/cosmetics/cosmetics.json"
const TOWER_SKINS_PATH := "res://data/cosmetics/tower_skins.json"
const PROJECTILE_SKINS_PATH := "res://data/cosmetics/projectile_skins.json"
const IMPACT_SKINS_PATH := "res://data/cosmetics/impact_skins.json"

const SLOT_TOWER_SKIN := "tower_skin"
const SLOT_PROJECTILE_SKIN := "projectile_skin"
const SLOT_IMPACT_SKIN := "impact_skin"

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
	_load_entries(TOWER_SKINS_PATH)
	_load_entries(PROJECTILE_SKINS_PATH)
	_load_entries(IMPACT_SKINS_PATH)

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

func _load_entries(path: String) -> void:
	var data := _load_json(path)
	for cosmetic_id in data.keys():
		var cfg: Dictionary = data[cosmetic_id]
		cfg["id"] = str(cfg.get("id", cosmetic_id))
		var slot := str(cfg.get("slot", ""))
		var tower_id := str(cfg.get("tower_id", ""))
		if cfg["id"] == "" or slot == "" or tower_id == "":
			continue
		cosmetics_by_id[cfg["id"]] = cfg
		if not cosmetics_by_slot.has(slot):
			cosmetics_by_slot[slot] = []
		cosmetics_by_slot[slot].append(cfg["id"])
		var key := _tower_slot_key(tower_id, slot)
		if not cosmetics_by_tower_slot.has(key):
			cosmetics_by_tower_slot[key] = []
		cosmetics_by_tower_slot[key].append(cfg["id"])

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
