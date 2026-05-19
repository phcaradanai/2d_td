extends Node

const SAVE_PATH = "user://tower_defense_save.json"

var save_data: Dictionary = {
	"player_name": "Player",
	"levels": {},
	"settings": {
		"audio": {
			"master_volume": 0.8,
			"music_volume": 0.6,
			"sfx_volume": 0.8,
			"master_muted": false,
			"music_muted": false,
			"sfx_muted": false,
			"audio_combat_mode": "balanced"
		},
		"display": {
			"window_mode": "borderless"
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
		"perfect_clear": false,
		"completed": false,
		"times_cleared": 0,
		"last_score": 0,
		"last_stars": 0,
		"unlocked": level_id == "level_01"
	}

const LEVELS_PER_AREA: int = 5
const TOTAL_AREAS: int = 4
const TOTAL_LEVELS: int = 20

func get_area_id_for_level(level_id_str: String) -> int:
	var parts = level_id_str.split("_")
	if parts.size() < 2: return 1
	var num = int(parts[1])
	return int((num - 1) / LEVELS_PER_AREA) + 1

func is_area_unlocked(area_id: int) -> bool:
	if area_id <= 1: return true
	# Check if the last level of the previous area is completed
	var last_level_of_prev = (area_id - 1) * LEVELS_PER_AREA
	var prev_id = "level_%02d" % last_level_of_prev
	return get_level_record(prev_id).get("completed", false)

func is_level_unlocked(level_id: String) -> bool:
	if level_id == "level_01": return true
	
	# Extract level number from ID like "level_02" -> 2
	var parts = level_id.split("_")
	if parts.size() < 2: return false
	
	var level_num = int(parts[1])
	if level_num <= 1: return true
	
	var area_id = get_area_id_for_level(level_id)
	if not is_area_unlocked(area_id):
		return false
	
	# Check if previous level (e.g. level_01) is completed
	var prev_level_num = level_num - 1
	var prev_level_id = "level_%02d" % prev_level_num
	
	return get_level_record(prev_level_id).get("completed", false)

func get_next_level_id(current_id: String) -> String:
	var parts = current_id.split("_")
	if parts.size() < 2: return ""
	
	var level_num = int(parts[1])
	if level_num >= TOTAL_LEVELS: return ""
	
	var next_num = level_num + 1
	var next_id = "level_%02d" % next_num
	
	# Only return next level if it's actually unlocked
	if is_level_unlocked(next_id):
		return next_id
	return ""

func update_level_record(level_id: String, summary: Dictionary) -> Dictionary:
	var current = get_level_record(level_id)
	var improvements = {
		"new_best_score": false,
		"new_best_stars": false,
		"new_perfect_clear": false,
		"first_time_clear": false
	}
	
	var is_victory = summary.get("result", "") == "Victory"
	var new_score = summary.get("score", 0)
	var new_stars = summary.get("stars", 0)
	var is_perfect = summary.get("is_perfect", false)
	
	if not save_data["levels"].has(level_id):
		save_data["levels"][level_id] = get_level_record(level_id)
		current = save_data["levels"][level_id]
	
	# Always save last results
	save_data["levels"][level_id]["last_score"] = new_score
	save_data["levels"][level_id]["last_stars"] = new_stars
	
	if new_score > current.get("best_score", 0):
		save_data["levels"][level_id]["best_score"] = new_score
		improvements["new_best_score"] = true
	
	if new_stars > current.get("best_stars", 0):
		save_data["levels"][level_id]["best_stars"] = new_stars
		improvements["new_best_stars"] = true
	
	if is_perfect and not current.get("perfect_clear", false):
		save_data["levels"][level_id]["perfect_clear"] = true
		improvements["new_perfect_clear"] = true
	
	if is_victory:
		if not current.get("completed", false):
			improvements["first_time_clear"] = true
			save_data["levels"][level_id]["completed"] = true
		
		save_data["levels"][level_id]["times_cleared"] = current.get("times_cleared", 0) + 1
		
		# Auto-unlock next level
		var next_id = get_next_level_id(level_id)
		if next_id != "" and not save_data["levels"].has(next_id):
			save_data["levels"][next_id] = get_level_record(next_id)
			save_data["levels"][next_id]["unlocked"] = true
	
	save_to_disk()
	return improvements

func print_progress() -> void:
	print("=== SAVED PROGRESS ===")
	for level_id in save_data["levels"]:
		var rec = save_data["levels"][level_id]
		print("[%s] Best Score: %d, Stars: %d, Perfect: %s, Clears: %d" % [
			level_id, 
			rec.get("best_score", 0), 
			rec.get("best_stars", 0), 
			str(rec.get("perfect_clear", false)),
			rec.get("times_cleared", 0)
		])
	print("======================")

func get_player_name() -> String:
	return save_data.get("player_name", "Player")

func set_player_name(new_name: String) -> void:
	save_data["player_name"] = new_name
	save_to_disk()

func get_audio_settings() -> Dictionary:
	return save_data["settings"]["audio"]

func update_audio_settings(settings: Dictionary) -> void:
	save_data["settings"]["audio"] = settings
	save_to_disk()

func get_display_settings() -> Dictionary:
	if not save_data["settings"].has("display"):
		save_data["settings"]["display"] = {"window_mode": "borderless"}
	return save_data["settings"]["display"]

func update_display_settings(settings: Dictionary) -> void:
	save_data["settings"]["display"] = settings
	save_to_disk()

func clear_save() -> void:
	save_data = {
		"player_name": "Player",
		"levels": {},
		"settings": {
			"audio": {
				"master_volume": 0.8,
				"music_volume": 0.6,
				"sfx_volume": 0.8,
				"master_muted": false,
				"music_muted": false,
				"sfx_muted": false,
				"audio_combat_mode": "balanced"
			},
			"display": {
				"window_mode": "borderless"
			}
		}
	}
	save_to_disk()
