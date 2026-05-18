extends Node
## Remote Access Config Service
##
## Fetches per-runtime access rules from the backend and caches them locally
## so the game works fully offline.
##
## Config priority (highest first):
##   1. Remote  — fresh GET /api/v1/game/access with full identity payload
##   2. Cache   — user://remote_access_config.json  (last successful fetch)
##   3. Default — res://data/default_access_config.json  (bundled fallback)
##
## All callers must use LevelAccessService — never this service directly.

signal config_updated(source: String)
signal fetch_failed(reason: String)

const BUNDLED_API_URL = "http://aovu1d8v7xwbm2ox287iskkc.165.22.240.130.sslip.io"
const DEV_CONFIG_PATH = "user://remote_access_config_dev.json"
const CACHE_PATH      = "user://remote_access_config.json"
const DEFAULT_PATH    = "res://data/default_access_config.json"
const REQUEST_TIMEOUT = 8.0
const BUILD_NUMBER    = 1

enum _State { IDLE, FETCHING }

var _state: _State       = _State.IDLE
var _http: HTTPRequest   = null
var _api_base_url: String = ""
var _identity: Node      = null   # RuntimeIdentityService, optional

# Resolved config fields
var _config: Dictionary      = {}
var _entitlement: Dictionary = {}
var _resolved_from: String   = ""
var _tags: Array             = []
var _config_source: String   = "default"
var _ready_flag: bool        = false

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

func _load_initial_config() -> void:
	if _try_load_file(CACHE_PATH, "cache"):
		_ready_flag = true
		return
	if _try_load_file(DEFAULT_PATH, "default"):
		_ready_flag = true
		return
	_apply_safe_defaults()
	_ready_flag = true

## Bind a RuntimeIdentityService so identity fields are included in requests.
func bind_identity_service(service: Node) -> void:
	_identity = service

# ── Public API ────────────────────────────────────────────────────────────────

func is_ready() -> bool:
	return _ready_flag

func get_config_version() -> int:
	return int(_config.get("config_version", 1))

func get_config_source() -> String:
	return _config_source

func get_resolved_from() -> String:
	return _resolved_from

func get_tags() -> Array:
	return _tags.duplicate()

func get_announcement() -> String:
	return str(_config.get("announcement", ""))

func get_max_demo_level() -> int:
	var enabled: Array = _config.get("enabled_levels", [1])
	if enabled is Array and not enabled.is_empty():
		var best = 1
		for v in enabled:
			if int(v) > best:
				best = int(v)
		return best
	return int(_config.get("max_demo_level", 1))

func is_demo_enabled() -> bool:
	if _is_full_unlocked():
		return false
	var mode = str(_config.get("mode", "demo"))
	if mode == "full":
		return false
	return bool(_config.get("demo_enabled", true))

func is_full_mode_global() -> bool:
	return _is_full_unlocked() or str(_config.get("mode", "demo")) == "full" or not bool(_config.get("demo_enabled", true))

func is_maintenance_enabled() -> bool:
	return bool(_config.get("maintenance_enabled", false))

func is_force_update() -> bool:
	if bool(_config.get("force_update", false)):
		return true
	return BUILD_NUMBER < int(_config.get("min_supported_build", 1))

func can_play_level(level_id: int) -> bool:
	if is_maintenance_enabled() or is_force_update():
		return false
	if not is_demo_enabled():
		return true
	var enabled: Array = _config.get("enabled_levels", [1])
	return level_id in enabled

func can_play_wave(level_id: int, wave_number: int) -> bool:
	if not can_play_level(level_id):
		return false
	if not is_demo_enabled():
		return true
	return wave_number <= _get_max_wave()

func can_submit_leaderboard() -> bool:
	if is_maintenance_enabled() or is_force_update():
		return false
	if _is_full_unlocked():
		return true
	return bool(_config.get("allow_leaderboard_submit", false))

func can_save_resume() -> bool:
	return bool(_config.get("allow_save_resume", true))

func is_feature_enabled(feature_key: String) -> bool:
	var features = _config.get("features", {})
	if features is Dictionary:
		return bool(features.get(feature_key, false))
	return false

func is_demo_wave_cap_reached(wave_number: int) -> bool:
	if not is_demo_enabled():
		return false
	return wave_number >= _get_max_wave()

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
		return "Wave %d is beyond the demo limit (Wave %d)." % [wave_number, _get_max_wave()]
	return ""

## Fetch fresh config from backend.  Includes full identity payload if
## RuntimeIdentityService is bound.  Safe to call while offline.
func fetch_remote_config() -> void:
	if _state == _State.FETCHING:
		return
	if _api_base_url.strip_edges().is_empty():
		fetch_failed.emit("No API URL configured.")
		return

	var url = _build_access_url()
	var err = _http.request(url)
	if err != OK:
		push_warning("[RemoteAccessConfig] HTTP request error: %d" % err)
		fetch_failed.emit("HTTP error %d" % err)
		return
	_state = _State.FETCHING
	if OS.is_debug_build():
		print("[RemoteAccessConfig] GET ", url)

# ── HTTP callback ─────────────────────────────────────────────────────────────

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_state = _State.IDLE
	var ok = (result == HTTPRequest.RESULT_SUCCESS) and (response_code >= 200) and (response_code < 300)
	if not ok:
		var reason = "HTTP %d (result=%d)" % [response_code, result]
		push_warning("[RemoteAccessConfig] Fetch failed: %s" % reason)
		fetch_failed.emit(reason)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		push_warning("[RemoteAccessConfig] Response parse failed.")
		fetch_failed.emit("JSON parse error")
		return

	_ingest_response(parsed)
	_save_cache(parsed)

	if OS.is_debug_build():
		print("[RemoteAccessConfig] v%d mode=%s full=%s resolved_from=%s tags=%s" % [
			get_config_version(), _config.get("mode", "demo"),
			str(_is_full_unlocked()), _resolved_from, str(_tags)
		])

# ── Internals ─────────────────────────────────────────────────────────────────

func _build_access_url() -> String:
	var base = _api_base_url.rstrip("/")
	var params: Array = []

	if _identity:
		var payload = _identity.get_identity_payload()
		for key in payload:
			var val = str(payload[key])
			if not val.is_empty():
				params.append("%s=%s" % [key, val.uri_encode()])
	else:
		# Fallback: include minimal OS info
		params.append("build=%d" % BUILD_NUMBER)
		params.append("platform=%s" % OS.get_name().to_lower().uri_encode())

	var query = "&".join(params)
	return "%s/api/v1/game/access%s" % [base, ("?" + query) if not query.is_empty() else ""]

func _ingest_response(parsed: Dictionary) -> void:
	# Support both flat and enveloped {access:{}, entitlement:{}} formats.
	var access_data: Dictionary = {}
	if parsed.has("access") and parsed["access"] is Dictionary:
		access_data = parsed["access"].duplicate()
		# Pull top-level meta fields into access_data for unified storage.
		for key in ["config_version", "resolved_from", "tags"]:
			if parsed.has(key):
				access_data[key] = parsed[key]
		var ent = parsed.get("entitlement", {})
		_entitlement = ent if ent is Dictionary else {}
	else:
		# Flat format — treat whole parsed dict as config.
		access_data = parsed.duplicate()
		_entitlement = parsed.get("entitlement", {})
		if not _entitlement is Dictionary:
			_entitlement = {}

	# Normalize max_wave / max_demo_wave
	if access_data.has("max_wave") and not access_data.has("max_demo_wave"):
		access_data["max_demo_wave"] = access_data["max_wave"]

	_resolved_from = str(access_data.get("resolved_from", ""))
	var raw_tags   = access_data.get("tags", [])
	_tags = raw_tags if raw_tags is Array else []
	_apply_config(access_data, "remote")

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
	_ingest_response(parsed)
	# Override the source tag set by _ingest_response (which would say "remote").
	_config_source = source
	return true

func _apply_config(data: Dictionary, source: String) -> void:
	_config = data
	_config_source = source
	config_updated.emit(source)

func _apply_safe_defaults() -> void:
	_config = {
		"config_version": 1, "mode": "demo", "demo_enabled": true,
		"max_demo_level": 1, "max_demo_wave": 60,
		"enabled_levels": [1], "enabled_modes": ["normal"],
		"allow_save_resume": true, "allow_leaderboard_submit": false,
		"allow_sandbox": false, "maintenance_enabled": false,
		"force_update": false, "min_supported_build": 1, "announcement": ""
	}
	_entitlement   = {"full_version_unlocked": false, "owned_products": []}
	_resolved_from = ""
	_tags          = []
	_config_source = "default"

func _save_cache(full_response: Dictionary) -> void:
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[RemoteAccessConfig] Could not write cache.")
		return
	file.store_string(JSON.stringify(full_response))
	file.close()

func _get_max_wave() -> int:
	return int(_config.get("max_wave", _config.get("max_demo_wave", 60)))

func _is_full_unlocked() -> bool:
	return bool(_entitlement.get("full_version_unlocked", false))

# ── Debug helpers ─────────────────────────────────────────────────────────────

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
