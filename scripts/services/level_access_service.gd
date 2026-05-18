extends Node
## Level Access Service
##
## Single point-of-truth for all level/wave/feature access checks.
## UI and gameplay code call only this service — never RemoteAccessConfigService
## directly.
##
## When RemoteAccessConfigService is bound (via bind_remote_config), all queries
## delegate there.  Without it the service reads the bundled local config file
## as a standalone fallback (useful for unit tests and offline-only builds).

const LOCAL_CONFIG_PATH = "res://data/level_access_config.json"

# ── Remote delegate ───────────────────────────────────────────────────────────
var _remote: Node = null  # RemoteAccessConfigService instance, or null

## Wire RemoteAccessConfigService.  Call once from main.gd after both nodes exist.
func bind_remote_config(service: Node) -> void:
	_remote = service

# ── Local fallback state (used only when _remote is null) ────────────────────
var _local_demo_enabled: bool = true
var _local_full_unlocked: bool = false
var _local_max_demo_level: int = 1
var _local_max_demo_wave: int = 20
var _local_allow_lb: bool = false

func _ready() -> void:
	_load_local_config()

func _load_local_config() -> void:
	if not FileAccess.file_exists(LOCAL_CONFIG_PATH):
		return
	var file = FileAccess.open(LOCAL_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	_local_demo_enabled   = bool(parsed.get("demo_enabled", true))
	_local_max_demo_level = int(parsed.get("max_demo_level", 1))
	_local_max_demo_wave  = int(parsed.get("max_demo_wave", 20))
	_local_allow_lb       = bool(parsed.get("allow_leaderboard_submit", false))

# ── Public API — identical signatures as before ───────────────────────────────

func can_play_level(level_id: int) -> bool:
	if _remote:
		return _remote.can_play_level(level_id)
	if _local_full_unlocked or not _local_demo_enabled:
		return true
	return level_id <= _local_max_demo_level

func can_play_wave(level_id: int, wave_number: int) -> bool:
	if _remote:
		return _remote.can_play_wave(level_id, wave_number)
	if not can_play_level(level_id):
		return false
	if _local_full_unlocked or not _local_demo_enabled:
		return true
	return wave_number <= _local_max_demo_wave

func is_full_version_unlocked() -> bool:
	if _remote:
		return _remote.is_full_mode_global()
	return _local_full_unlocked

func set_full_version_unlocked(value: bool) -> void:
	_local_full_unlocked = value
	if OS.is_debug_build():
		print("[LevelAccessService] local full_version_unlocked = ", value)

func can_submit_leaderboard() -> bool:
	if _remote:
		return _remote.can_submit_leaderboard()
	if _local_full_unlocked:
		return true
	return _local_allow_lb

func is_demo_enabled() -> bool:
	if _remote:
		return _remote.is_demo_enabled()
	return _local_demo_enabled and not _local_full_unlocked

## True when the game is in maintenance mode and all play should be blocked.
func is_maintenance_enabled() -> bool:
	if _remote:
		return _remote.is_maintenance_enabled()
	return false

## True when the client build is too old and must update before playing.
func is_force_update() -> bool:
	if _remote:
		return _remote.is_force_update()
	return false

## True when save/resume is allowed by the current config.
func can_save_resume() -> bool:
	if _remote:
		return _remote.can_save_resume()
	return true

func get_locked_reason(level_id: int, wave_number: int = -1) -> String:
	if _remote:
		return _remote.get_locked_reason(level_id, wave_number)
	if _local_full_unlocked or not _local_demo_enabled:
		return ""
	if level_id > _local_max_demo_level:
		return "This level requires the Full Version."
	if wave_number > 0 and wave_number > _local_max_demo_wave:
		return "Wave %d is beyond the demo limit (Wave %d)." % [wave_number, _local_max_demo_wave]
	return ""

func is_demo_wave_cap_reached(wave_number: int) -> bool:
	if _remote:
		return _remote.is_demo_wave_cap_reached(wave_number)
	if _local_full_unlocked or not _local_demo_enabled:
		return false
	return wave_number >= _local_max_demo_wave

## max_demo_level exposed so level_select.gd can read it for card styling.
func get_max_demo_level() -> int:
	if _remote:
		return int(_remote._config.get("max_demo_level", 1))
	return _local_max_demo_level

# ── Debug helpers ─────────────────────────────────────────────────────────────
func unlock_full_version_for_debug() -> void:
	if not OS.is_debug_build():
		return
	if _remote:
		_remote.force_full_version_for_debug()
	else:
		set_full_version_unlocked(true)

func reset_to_demo_for_debug() -> void:
	if not OS.is_debug_build():
		return
	if _remote:
		_remote.force_demo_for_debug()
	else:
		set_full_version_unlocked(false)
	print("[LevelAccessService] Reset to demo mode.")
