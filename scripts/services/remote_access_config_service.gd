extends Node
## Remote Access Config Service
##
## Fetches access/demo-gate config from the backend at startup and caches it
## locally so the game works fully offline.
##
## Priority order (highest to lowest):
##   1. Remote  — fresh fetch from backend
##   2. Cache   — user://remote_access_config.json (last successful fetch)
##   3. Default — res://data/default_access_config.json  (bundled fallback)
##
## Callers should use LevelAccessService, which delegates here.
## Never put per-frame logic in this service.

# ── Signals ───────────────────────────────────────────────────────────────────
## Emitted after config is loaded from any source, or re-loaded after a
## successful remote fetch.  source = "remote" | "cache" | "default"
signal config_updated(source: String)
## Emitted when the remote fetch attempt fails (cache/default still active).
signal fetch_failed(reason: String)

# ── Constants ─────────────────────────────────────────────────────────────────
const BUNDLED_API_URL: String = "http://aovu1d8v7xwbm2ox287iskkc.165.22.240.130.sslip.io"
const DEV_CONFIG_PATH: String = "user://remote_access_config_dev.json"
const CACHE_PATH: String      = "user://remote_access_config.json"
const DEFAULT_PATH: String    = "res://data/default_access_config.json"
const REQUEST_TIMEOUT: float  = 8.0
const BUILD_NUMBER: int       = 1

# ── State ─────────────────────────────────────────────────────────────────────
enum _State { IDLE, FETCHING }

var _state: _State = _State.IDLE
var _http: HTTPRequest = null
var _api_base_url: String = ""
var _config: Dictionary = {}
var _entitlement: Dictionary = {}
var _config_source: String = "default"  # "remote" | "cache" | "default"
var _ready_flag: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_api_url()
	_load_initial_config()

func _load_api_url() -> void:
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
					if OS.is_debug_build():
						print("[RemoteAccessConfig] API URL from dev config: ", _api_base_url)

func _load_initial_config() -> void:
	# Try cache first so the game is immediately usable.
	if _try_load_file(CACHE_PATH, "cache"):
		_ready_flag = true
		return
	# Fall back to bundled default.
	if _try_load_file(DEFAULT_PATH, "default"):
		_ready_flag = true
		return
	# Absolute last resort: hard-coded safe defaults.
	_apply_safe_defaults()
	_ready_flag = true

func _try_load_file(path: String, source: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false
	_apply_config(parsed, source)
	return true

func _apply_safe_defaults() -> void:
	_config = {
		"config_version": 1,
		"mode": "demo",
		"demo_enabled": true,
		"max_demo_level": 1,
		"max_demo_wave": 20,
		"enabled_levels": [1],
		"enabled_modes": ["normal"],
		"allow_save_resume": true,
		"allow_leaderboard_submit": false,
		"allow_sandbox": false,
		"maintenance_enabled": false,
		"force_update": false,
		"min_supported_build": 1,
		"announcement": ""
	}
	_entitlement = {"full_version_unlocked": false, "owned_products": []}
	_config_source = "default"

# ── Public API ────────────────────────────────────────────────────────────────

## True once the initial config (cache or default) is loaded.
func is_ready() -> bool:
	return _ready_flag

## Integer version stamp from the backend, or 1 for bundled default.
func get_config_version() -> int:
	return int(_config.get("config_version", 1))

## Source of the active config: "remote", "cache", or "default".
func get_config_source() -> String:
	return _config_source

## True when demo restrictions are in effect.
func is_demo_enabled() -> bool:
	if _is_full_unlocked():
		return false
	var mode = str(_config.get("mode", "demo"))
	if mode == "full":
		return false
	return bool(_config.get("demo_enabled", true))

## True when the backend or entitlement grants unrestricted access.
func is_full_mode_global() -> bool:
	if _is_full_unlocked():
		return true
	var mode = str(_config.get("mode", "demo"))
	return mode == "full" or not bool(_config.get("demo_enabled", true))

## True when maintenance mode blocks all play.
func is_maintenance_enabled() -> bool:
	return bool(_config.get("maintenance_enabled", false))

## True when the client build is too old and an update is required.
func is_force_update() -> bool:
	if bool(_config.get("force_update", false)):
		return true
	return BUILD_NUMBER < int(_config.get("min_supported_build", 1))

## Announcement text to display in the UI (may be empty).
func get_announcement() -> String:
	return str(_config.get("announcement", ""))

## True when the player may start or load this level.
func can_play_level(level_id: int) -> bool:
	if is_maintenance_enabled() or is_force_update():
		return false
	if not is_demo_enabled():
		return true
	var enabled: Array = _config.get("enabled_levels", [1])
	return level_id in enabled

## True when the player may play this wave on this level.
func can_play_wave(level_id: int, wave_number: int) -> bool:
	if not can_play_level(level_id):
		return false
	if not is_demo_enabled():
		return true
	return wave_number <= int(_config.get("max_demo_wave", 20))

## True when a demo run may submit to the leaderboard.
func can_submit_leaderboard() -> bool:
	if is_maintenance_enabled() or is_force_update():
		return false
	if _is_full_unlocked():
		return true
	return bool(_config.get("allow_leaderboard_submit", false))

## True when the game may allow save/resume in the current config.
func can_save_resume() -> bool:
	return bool(_config.get("allow_save_resume", true))

## True when the given feature key is enabled (reserved for future flags).
func is_feature_enabled(feature_key: String) -> bool:
	var features = _config.get("features", {})
	if features is Dictionary:
		return bool(features.get(feature_key, false))
	return false

## True when the demo wave cap has been reached after clearing wave_number.
func is_demo_wave_cap_reached(wave_number: int) -> bool:
	if not is_demo_enabled():
		return false
	return wave_number >= int(_config.get("max_demo_wave", 20))

## Human-readable reason a level/wave is blocked.
func get_locked_reason(level_id: int, wave_number: int = -1) -> String:
	if is_maintenance_enabled():
		return "Server maintenance in progress. Please try again later."
	if is_force_update():
		return "A game update is required before playing."
	if not is_demo_enabled():
		return ""
	if not can_play_level(level_id):
		return "This level requires the Full Version."
	if wave_number > 0 and not can_play_wave(level_id, wave_number):
		return "Wave %d is beyond the demo limit (Wave %d)." % [
			wave_number, int(_config.get("max_demo_wave", 20))
		]
	return ""

## Trigger a manual refresh from the backend (e.g. when the player opens the menu).
func fetch_remote_config(player_id: String = "") -> void:
	if _state == _State.FETCHING:
		return
	if _api_base_url.strip_edges().is_empty():
		fetch_failed.emit("No API URL configured.")
		return

	var pid = player_id.strip_edges()
	if pid.is_empty():
		pid = OS.get_unique_id().substr(0, 32)

	var platform = OS.get_name().to_lower()
	var url = "%s/api/v1/game/access?player_id=%s&build=%d&platform=%s" % [
		_api_base_url.rstrip("/"),
		pid.uri_encode(),
		BUILD_NUMBER,
		platform.uri_encode()
	]

	var err = _http.request(url)
	if err != OK:
		push_warning("[RemoteAccessConfig] HTTP request error: %d" % err)
		fetch_failed.emit("HTTP error %d" % err)
		return
	_state = _State.FETCHING
	if OS.is_debug_build():
		print("[RemoteAccessConfig] Fetching: ", url)

# ── HTTP callback ─────────────────────────────────────────────────────────────
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_state = _State.IDLE
	var success = (result == HTTPRequest.RESULT_SUCCESS) and (response_code >= 200) and (response_code < 300)
	if not success:
		var reason = "HTTP %d (result=%d)" % [response_code, result]
		push_warning("[RemoteAccessConfig] Fetch failed: %s" % reason)
		fetch_failed.emit(reason)
		return

	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("[RemoteAccessConfig] Response parse failed.")
		fetch_failed.emit("JSON parse error")
		return

	# Extract nested access block + entitlement.
	var access_block = parsed.get("access", parsed)
	if not access_block is Dictionary:
		access_block = parsed

	var version_from_root = int(parsed.get("config_version", int(access_block.get("config_version", 1))))
	access_block["config_version"] = version_from_root

	var entitlement_block = parsed.get("entitlement", {})
	if not entitlement_block is Dictionary:
		entitlement_block = {}

	_entitlement = entitlement_block
	_apply_config(access_block, "remote")
	_save_cache(parsed)

	if OS.is_debug_build():
		print("[RemoteAccessConfig] Loaded remote config v%d (mode=%s full=%s)" % [
			get_config_version(),
			str(_config.get("mode", "demo")),
			str(_is_full_unlocked())
		])

# ── Internals ─────────────────────────────────────────────────────────────────
func _apply_config(data: Dictionary, source: String) -> void:
	_config = data
	_config_source = source
	config_updated.emit(source)

func _save_cache(full_response: Dictionary) -> void:
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[RemoteAccessConfig] Could not write cache.")
		return
	file.store_string(JSON.stringify(full_response))
	file.close()

func _is_full_unlocked() -> bool:
	return bool(_entitlement.get("full_version_unlocked", false))

# ── Debug helpers (debug builds only) ────────────────────────────────────────
func force_full_version_for_debug() -> void:
	if not OS.is_debug_build():
		return
	_entitlement["full_version_unlocked"] = true
	config_updated.emit("debug")
	print("[RemoteAccessConfig] DEBUG: full_version_unlocked forced.")

func force_demo_for_debug() -> void:
	if not OS.is_debug_build():
		return
	_entitlement["full_version_unlocked"] = false
	config_updated.emit("debug")
	print("[RemoteAccessConfig] DEBUG: reset to demo mode.")
