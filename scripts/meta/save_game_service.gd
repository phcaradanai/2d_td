extends Node

# Handles run-state saves separate from the profile/level-record save (save_manager.gd).
# Save file: user://savegame.json
# This file is created/updated after each wave clear and deleted when a run ends.

const SAVE_PATH = "user://savegame.json"
const SAVE_VERSION = 1

# Returns true if a valid, uncorrupted run save exists.
func has_valid_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = _load_raw()
	if data.is_empty():
		return false
	return int(data.get("version", 0)) == SAVE_VERSION \
		and data.has("level_id") \
		and data.has("current_wave")

# Persist run state to disk. Returns true on success.
func save_run_state(state: Dictionary) -> bool:
	var to_write = state.duplicate(true)
	to_write["version"] = SAVE_VERSION
	var now = int(Time.get_unix_time_from_system())
	to_write["updated_at"] = now
	if not to_write.has("created_at"):
		to_write["created_at"] = now

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveGameService] Cannot open save for writing: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(to_write, "\t"))
	file.close()
	if OS.is_debug_build():
		print("[SaveGameService] Run saved — wave=%d gold=%d towers=%d" % [
			to_write.get("current_wave", 0),
			to_write.get("gold", 0),
			(to_write["towers"] as Array).size() if to_write.has("towers") and to_write["towers"] is Array else 0
		])
	return true

# Load and return save data. Returns empty dict on missing/corrupt file.
func load_run_state() -> Dictionary:
	return _load_raw()

# Delete the run save (called on new game start or run end).
func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var abs_path = ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.remove_absolute(abs_path)
	if OS.is_debug_build():
		print("[SaveGameService] Save deleted.")

func _load_raw() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {}
	var json = JSON.new()
	if json.parse(text) != OK:
		push_warning("[SaveGameService] Save file corrupt — ignoring.")
		return {}
	var data = json.data
	if not (data is Dictionary):
		return {}
	return data
