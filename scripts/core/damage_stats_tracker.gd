extends Node
class_name DamageStatsTracker

signal stats_changed()

const TOWERS_TREE_DATA_PATH := "res://data/towers_tree.json"
const TOWERS_DATA_PATH := "res://data/towers.json"

var wave_damage: float = 0.0
var total_damage: float = 0.0
var entries: Dictionary = {}
var tower_names: Dictionary = {}

func _ready() -> void:
	name = "DamageStatsTracker"
	_load_tower_names(TOWERS_TREE_DATA_PATH)
	_load_tower_names(TOWERS_DATA_PATH)

func reset_wave() -> void:
	wave_damage = 0.0
	for key in entries.keys():
		var entry: Dictionary = entries[key]
		entry["wave_damage"] = 0.0
		entry["wave_hit_count"] = 0
		entries[key] = entry
	stats_changed.emit()

func record_damage(source_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var tower_id: String = source_id if source_id != "" else "unknown"
	var tower_name: String = str(tower_names.get(tower_id, _fallback_tower_name(tower_id)))
	var entry: Dictionary = entries.get(tower_id, {
		"tower_id": tower_id,
		"tower_name": tower_name,
		"total_damage": 0.0,
		"hit_count": 0,
		"wave_damage": 0.0,
		"wave_hit_count": 0,
	})
	entry["tower_name"] = tower_name
	entry["total_damage"] = float(entry.get("total_damage", 0.0)) + amount
	entry["hit_count"] = int(entry.get("hit_count", 0)) + 1
	entry["wave_damage"] = float(entry.get("wave_damage", 0.0)) + amount
	entry["wave_hit_count"] = int(entry.get("wave_hit_count", 0)) + 1
	entries[tower_id] = entry
	wave_damage += amount
	total_damage += amount

func get_summary() -> Dictionary:
	var compact: Dictionary = get_compact_summary()
	compact["entries"] = _sorted_entries()
	return compact

func get_compact_summary() -> Dictionary:
	var top_entry: Dictionary = {}
	var top_damage: float = -1.0
	for entry_value in entries.values():
		var entry: Dictionary = entry_value
		var damage_amount: float = float(entry.get("wave_damage", 0.0))
		if damage_amount > top_damage:
			top_damage = damage_amount
			top_entry = entry
	return {
		"wave_damage": wave_damage,
		"total_damage": total_damage,
		"top_entry": top_entry,
	}

func _sorted_entries() -> Array:
	var sorted_entries: Array = entries.values()
	sorted_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("wave_damage", 0.0)) > float(b.get("wave_damage", 0.0))
	)
	return sorted_entries

func _load_tower_names(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return
	var data: Variant = json.data
	if data is Dictionary:
		for key in (data as Dictionary).keys():
			var config: Variant = (data as Dictionary)[key]
			if config is Dictionary:
				var tower_id: String = str((config as Dictionary).get("id", key))
				tower_names[tower_id] = str((config as Dictionary).get("name", (config as Dictionary).get("display_name", _fallback_tower_name(tower_id))))

func _fallback_tower_name(tower_id: String) -> String:
	if tower_id == "unknown":
		return "Unknown"
	var clean_id: String = tower_id.replace("_", " ").strip_edges()
	return clean_id.capitalize()
