extends Node

const SAVE_PATH = "user://tower_defense_save.json"

var save_data: Dictionary = {
	"levels": {},
	"settings": {
		"audio": {
			"master_volume": 0.8,
			"music_volume": 0.6,
			"sfx_volume": 0.8,
			"master_muted": false,
			"music_muted": false,
			"sfx_muted": false
		}
	}
}

func _ready() -> void:
	load_save()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		if OS.is_debug_build(): print("[SaveManager] No save file found, using defaults.")
		return save_data
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		# Merge loaded data with defaults to handle missing fields in old saves
		var loaded_data = json.data
		if loaded_data.has("levels"):
			save_data["levels"] = loaded_data["levels"]
		if loaded_data.has("settings"):
			# Deep merge settings
			var loaded_settings = loaded_data["settings"]
			for category in loaded_settings:
				if not save_data["settings"].has(category):
					save_data["settings"][category] = {}
				for key in loaded_settings[category]:
					save_data["settings"][category][key] = loaded_settings[category][key]
		
		if OS.is_debug_build(): print("[SaveManager] Save loaded and merged.")
	else:
		push_error("[SaveManager] JSON Parse Error: " + json.get_error_message())
	
	return save_data

func save_to_disk() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_text = JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()
	if OS.is_debug_build(): print("[SaveManager] Save written to disk.")

func get_level_record(level_id: String) -> Dictionary:
	if save_data["levels"].has(level_id):
		return save_data["levels"][level_id]
	return {
		"best_score": 0,
		"best_stars": 0,
		"completed": false
	}

func is_level_unlocked(level_id: String) -> bool:
	if level_id == "level_01": return true
	
	if level_id == "level_02":
		return get_level_record("level_01")["completed"]
		
	if level_id == "level_03":
		return get_level_record("level_02")["completed"]
		
	return false

func update_level_record(level_id: String, summary: Dictionary) -> bool:
	var current = get_level_record(level_id)
	var updated = false
	
	var new_score = summary.get("score", 0)
	var new_stars = summary.get("stars", 0)
	
	if not save_data["levels"].has(level_id):
		save_data["levels"][level_id] = {
			"best_score": 0,
			"best_stars": 0,
			"completed": false
		}
		current = save_data["levels"][level_id]
	
	if new_score > current["best_score"]:
		save_data["levels"][level_id]["best_score"] = new_score
		updated = true
	
	if new_stars > current["best_stars"]:
		save_data["levels"][level_id]["best_stars"] = new_stars
		updated = true
	
	if new_stars > 0:
		save_data["levels"][level_id]["completed"] = true
	
	if updated:
		save_to_disk()
	
	return updated

func get_audio_settings() -> Dictionary:
	return save_data["settings"]["audio"]

func update_audio_settings(settings: Dictionary) -> void:
	save_data["settings"]["audio"] = settings
	save_to_disk()

func clear_save() -> void:
	save_data = {
		"levels": {},
		"settings": {
			"audio": {
				"master_volume": 0.8,
				"music_volume": 0.6,
				"sfx_volume": 0.8,
				"master_muted": false,
				"music_muted": false,
				"sfx_muted": false
			}
		}
	}
	save_to_disk()
