extends Node
## Level Access Service
##
## Single point-of-truth for all level/wave/feature access checks.
## UI and gameplay code call ONLY this service.
##
## When RemoteAccessConfigService is bound (via bind_remote_config), every
## query delegates there.  Without it the service reads the bundled local
## config file as a standalone offline fallback.

const LOCAL_CONFIG_PATH = "res://data/level_access_config.json"

var _remote: Node = null   # RemoteAccessConfigService, or null

func bind_remote_config(service: Node) -> void:
	_remote = service

# ── Local fallback state ───────────────────────────────────────────────────────
var _local_demo_enabled: bool    = true
var _local_full_unlocked: bool   = false
var _local_max_demo_level: int   = 1
var _local_max_demo_wave: int    = 60
var _local_allow_lb: bool        = false
var _local_enabled_levels: Array = [1]

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
	_local_max_demo_wave  = int(parsed.get("max_demo_wave", 60))
	_local_allow_lb       = bool(parsed.get("allow_leaderboard_submit", false))
	var raw_levels = parsed.get("enabled_levels", null)
	if raw_levels is String and raw_levels == "all":
		pass  # handled in can_play_level
	elif raw_levels is Array:
		_local_enabled_levels = raw_levels
	else:
		_local_enabled_levels = [1]

# ── Access queries ────────────────────────────────────────────────────────────

func can_play_level(level_id: int) -> bool:
	if _remote:
		return _remote.can_play_level(level_id)
	if _local_full_unlocked or not _local_demo_enabled:
		return true
	for v in _local_enabled_levels:
		if int(v) == int(level_id):
			return true
	return false

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

func is_maintenance_enabled() -> bool:
	if _remote:
		return _remote.is_maintenance_enabled()
	return false

func is_force_update() -> bool:
	if _remote:
		return _remote.is_force_update()
	return false

func can_save_resume() -> bool:
	if _remote:
		return _remote.can_save_resume()
	return true

func get_locked_reason(level_id: int, wave_number: int = -1) -> String:
	if _remote:
		return _remote.get_locked_reason(level_id, wave_number)
	if _local_full_unlocked or not _local_demo_enabled:
		return ""
	if not can_play_level(level_id):
		return "This level is not included in your current access profile."
	if wave_number > 0 and wave_number > _local_max_demo_wave:
		return "Wave %d is beyond the demo limit (Wave %d)." % [wave_number, _local_max_demo_wave]
	return ""

func is_demo_wave_cap_reached(wave_number: int) -> bool:
	if _remote:
		return _remote.is_demo_wave_cap_reached(wave_number)
	if _local_full_unlocked or not _local_demo_enabled:
		return false
	return wave_number >= _local_max_demo_wave

func get_max_demo_level() -> int:
	if _remote:
		return _remote.get_max_demo_level()
	var best := 1
	for v in _local_enabled_levels:
		if int(v) > best:
			best = int(v)
	return best

# ── Identity / access metadata (for UI display) ───────────────────────────────

## Current access mode: "demo", "full", or a custom profile key.
func get_access_mode() -> String:
	if _remote:
		if _remote.is_full_mode_global():
			return "full"
		return str(_remote._config.get("mode", "demo"))
	if _local_full_unlocked or not _local_demo_enabled:
		return "full"
	return "demo"

## Source of the active config: "remote", "cache", or "default".
func get_access_source() -> String:
	if _remote:
		return _remote.get_config_source()
	return "local"

## Backend tags assigned to this runtime (e.g. ["tester", "qa"]).
func get_tags() -> Array:
	if _remote:
		return _remote.get_tags()
	return []

## Which override rule produced this config (e.g. "install_id_override").
func get_resolved_from() -> String:
	if _remote:
		return _remote.get_resolved_from()
	return ""

## Config version integer, for display in the identity panel.
func get_config_version() -> int:
	if _remote:
		return _remote.get_config_version()
	return 1

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
