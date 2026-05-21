extends Node

const SAVE_PATH          = "user://tower_defense_save.json"
const IDENTITY_CACHE_PATH = "user://runtime_identity.json"
const DEV_CONFIG_PATH     = "user://remote_access_config_dev.json"
const BUNDLED_API_URL     = "http://ecn8h5mus6i7ommtg7hjpfl4.157.85.103.69.sslip.io"
const BACKEND_TIMEOUT     = 10.0

var _api_base_url: String   = ""
var _install_id: String     = ""
var _http_fetch: HTTPRequest = null
var _http_push: HTTPRequest  = null
var _push_in_flight: bool    = false
var _push_pending: bool      = false

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
		},
		"performance": {
			"visual_quality": "auto",
			"attack_vfx": "normal",
			"floating_damage_numbers": "off",
			"status_effects": "icons_only",
			"screen_shake": "off"
		}
	}
}

func _ready() -> void:
	load_save()
	call_deferred("_setup_backend")

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		if OS.is_debug_build(): print("[SaveManager] No save file found, using defaults.")
		return save_data

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Cannot open save file for reading: " + SAVE_PATH)
		return save_data
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
	if file == null:
		push_error("[SaveManager] Cannot open save file for writing: " + SAVE_PATH)
		return
	var json_text = JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()
	if OS.is_debug_build(): print("[SaveManager] Save written to disk.")
	_push_backend_save()

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
	return int(float(num - 1) / float(LEVELS_PER_AREA)) + 1

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

func get_performance_settings() -> Dictionary:
	if not save_data["settings"].has("performance"):
		save_data["settings"]["performance"] = {
			"visual_quality": "auto",
			"attack_vfx": "normal",
			"floating_damage_numbers": "off",
			"status_effects": "icons_only",
			"screen_shake": "off"
		}
	return save_data["settings"]["performance"]

func update_performance_settings(settings: Dictionary) -> void:
	save_data["settings"]["performance"] = settings
	save_to_disk()

# ── Backend Cloud Save ────────────────────────────────────────────────────────

func _setup_backend() -> void:
	_api_base_url = BUNDLED_API_URL
	if FileAccess.file_exists(DEV_CONFIG_PATH):
		var file = FileAccess.open(DEV_CONFIG_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				var url = str(parsed.get("api_base_url", "")).strip_edges()
				if not url.is_empty():
					_api_base_url = url

	if FileAccess.file_exists(IDENTITY_CACHE_PATH):
		var file = FileAccess.open(IDENTITY_CACHE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				_install_id = str(parsed.get("install_id", "")).strip_edges()

	if _install_id.is_empty():
		if OS.is_debug_build(): print("[SaveManager] No install_id yet, skipping cloud sync.")
		return

	_http_fetch = HTTPRequest.new()
	_http_fetch.timeout = BACKEND_TIMEOUT
	add_child(_http_fetch)
	_http_fetch.request_completed.connect(_on_fetch_completed)

	_http_push = HTTPRequest.new()
	_http_push.timeout = BACKEND_TIMEOUT
	add_child(_http_push)
	_http_push.request_completed.connect(_on_push_completed)

	_fetch_backend_save()

func _fetch_backend_save() -> void:
	if _http_fetch == null or _install_id.is_empty():
		return
	var url = _api_base_url.rstrip("/") + "/api/v1/game/save?install_id=" + _install_id.uri_encode()
	var err = _http_fetch.request(url)
	if err != OK:
		if OS.is_debug_build(): push_warning("[SaveManager] Cloud fetch request error: %d" % err)

func _on_fetch_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if OS.is_debug_build():
			push_warning("[SaveManager] Cloud fetch failed: HTTP %d (result=%d)" % [response_code, result])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("ok", false):
		return

	if not parsed.get("found", false):
		if OS.is_debug_build(): print("[SaveManager] No cloud save found; pushing local.")
		_push_backend_save()
		return

	var remote_save = JSON.parse_string(str(parsed.get("save_json", "")))
	if not remote_save is Dictionary:
		return

	var changed = false

	var remote_name = str(remote_save.get("player_name", "")).strip_edges()
	if remote_name != "" and remote_name != "Player" and remote_name != save_data.get("player_name", ""):
		save_data["player_name"] = remote_name
		changed = true

	if remote_save.has("levels") and remote_save["levels"] is Dictionary:
		for level_id in remote_save["levels"]:
			var remote_rec: Dictionary = remote_save["levels"][level_id]
			if save_data["levels"].has(level_id):
				var merged = _merge_level_record(save_data["levels"][level_id], remote_rec)
				if merged != save_data["levels"][level_id]:
					save_data["levels"][level_id] = merged
					changed = true
			else:
				save_data["levels"][level_id] = remote_rec
				changed = true

	if changed:
		var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(save_data, "\t"))
			file.close()
		if OS.is_debug_build(): print("[SaveManager] Cloud save merged and written to disk.")
		_push_backend_save()
	else:
		if OS.is_debug_build(): print("[SaveManager] Cloud save loaded; no new data.")

func _merge_level_record(local_rec: Dictionary, remote_rec: Dictionary) -> Dictionary:
	var merged = local_rec.duplicate()
	merged["best_score"]    = max(local_rec.get("best_score", 0),    remote_rec.get("best_score", 0))
	merged["best_stars"]    = max(local_rec.get("best_stars", 0),    remote_rec.get("best_stars", 0))
	merged["times_cleared"] = max(local_rec.get("times_cleared", 0), remote_rec.get("times_cleared", 0))
	merged["perfect_clear"] = local_rec.get("perfect_clear", false) or remote_rec.get("perfect_clear", false)
	merged["completed"]     = local_rec.get("completed", false)      or remote_rec.get("completed", false)
	merged["unlocked"]      = local_rec.get("unlocked", false)       or remote_rec.get("unlocked", false)
	return merged

func _push_backend_save() -> void:
	if _http_push == null or _install_id.is_empty():
		return
	if _push_in_flight:
		_push_pending = true
		return

	var cloud_payload = {
		"player_name": save_data.get("player_name", "Player"),
		"levels": save_data.get("levels", {})
	}
	var body = JSON.stringify({
		"install_id": _install_id,
		"save_json":  JSON.stringify(cloud_payload)
	})
	var headers = PackedStringArray(["Content-Type: application/json"])
	var url = _api_base_url.rstrip("/") + "/api/v1/game/save"
	var err = _http_push.request(url, headers, HTTPClient.METHOD_PUT, body)
	if err == OK:
		_push_in_flight = true
	else:
		if OS.is_debug_build(): push_warning("[SaveManager] Cloud push request error: %d" % err)

func _on_push_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_push_in_flight = false
	if OS.is_debug_build():
		if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
			print("[SaveManager] Cloud save pushed OK.")
		else:
			push_warning("[SaveManager] Cloud push failed: HTTP %d (result=%d)" % [response_code, result])
	if _push_pending:
		_push_pending = false
		_push_backend_save()

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
			},
			"performance": {
				"visual_quality": "auto",
				"attack_vfx": "normal",
				"floating_damage_numbers": "off",
				"status_effects": "icons_only",
				"screen_shake": "off"
			}
		}
	}
	save_to_disk()
