extends Node
## Runtime Identity Service
##
## Gives every game install and every session a stable, unique identity so the
## backend/admin panel can target a specific runtime with custom access rules.
##
## install_id   — stable across launches (persisted in user://runtime_identity.json)
## runtime_session_id — fresh every launch (never persisted)
## runtime_id   — assigned by backend after registration (persisted once received)
##
## Signals:
##   registered(runtime_id)       — backend accepted registration
##   registration_failed(reason)  — backend unreachable; local IDs still usable

const BackendApiConfig = preload("res://scripts/config/backend_api_config.gd")

signal registered(runtime_id: String)
signal registration_failed(reason: String)

const CACHE_PATH = "user://runtime_identity.json"
const BUILD_ID = "v1.0.0-RC1" # must match VERSION in main.gd
const DEV_CONFIG_PATH = "user://remote_access_config_dev.json"
const REQUEST_TIMEOUT = 8.0

var _install_id: String = ""
var _runtime_session_id: String = ""
var _runtime_id: String = "" # from backend
var _api_base_url: String = ""
var _http: HTTPRequest = null
var _registering: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_register_completed)
	_load_api_url()
	load_identity_cache()

# ── Public API ────────────────────────────────────────────────────────────────

func get_install_id() -> String:
	return _install_id

func get_runtime_session_id() -> String:
	return _runtime_session_id

func get_runtime_id() -> String:
	return _runtime_id

func get_build_id() -> String:
	return BUILD_ID

func get_platform() -> String:
	return OS.get_name().to_lower()

func get_game_version() -> String:
	return BUILD_ID

## Full identity dict to include in every backend request.
func get_identity_payload() -> Dictionary:
	return {
		"install_id": _install_id,
		"runtime_session_id": _runtime_session_id,
		"runtime_id": _runtime_id,
		"build_id": BUILD_ID,
		"platform": get_platform(),
		"game_version": BUILD_ID,
	}

## POST /api/v1/game/runtime/register with identity payload.
## Emits registered(runtime_id) or registration_failed(reason) when done.
## Safe to call multiple times per session; subsequent calls are ignored while
## one is in flight.
func register_runtime() -> void:
	if _registering:
		return
	if _api_base_url.strip_edges().is_empty():
		registration_failed.emit("No API URL configured.")
		return

	_registering = true
	var url = _api_base_url.rstrip("/") + "/api/v1/game/runtime/register"
	var body = JSON.stringify(get_identity_payload())
	var headers = PackedStringArray(["Content-Type: application/json"])
	var err = _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_registering = false
		var reason = "HTTP request error %d" % err
		push_warning("[RuntimeIdentity] Register failed: %s" % reason)
		registration_failed.emit(reason)

## Load install_id and cached runtime_id from disk.  Generates install_id if
## missing.  Always generates a fresh runtime_session_id.
func load_identity_cache() -> void:
	_runtime_session_id = _make_id("sess")

	if FileAccess.file_exists(CACHE_PATH):
		var file = FileAccess.open(CACHE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				_install_id = str(parsed.get("install_id", ""))
				_runtime_id = str(parsed.get("runtime_id", ""))

	if _install_id.is_empty():
		_install_id = _make_install_id()
		save_identity_cache()

	if OS.is_debug_build():
		print("[RuntimeIdentity] install_id=%s  session=%s  runtime_id=%s" % [
			_install_id, _runtime_session_id, _runtime_id
		])

## Persist install_id and runtime_id to disk.
func save_identity_cache() -> void:
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[RuntimeIdentity] Could not write cache.")
		return
	file.store_string(JSON.stringify({
		"install_id": _install_id,
		"runtime_id": _runtime_id,
	}))
	file.close()

# ── HTTP callback ─────────────────────────────────────────────────────────────

func _on_register_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_registering = false
	var ok = (result == HTTPRequest.RESULT_SUCCESS) and (response_code >= 200) and (response_code < 300)
	if not ok:
		var reason = "HTTP %d (result=%d)" % [response_code, result]
		push_warning("[RuntimeIdentity] Registration response failed: %s" % reason)
		registration_failed.emit(reason)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		push_warning("[RuntimeIdentity] Registration response parse failed.")
		registration_failed.emit("JSON parse error")
		return

	var rid = str(parsed.get("runtime_id", "")).strip_edges()
	if rid.is_empty():
		push_warning("[RuntimeIdentity] Registration response missing runtime_id.")
		registration_failed.emit("Missing runtime_id in response")
		return

	_runtime_id = rid
	save_identity_cache()
	if OS.is_debug_build():
		print("[RuntimeIdentity] Registered. runtime_id=%s tags=%s" % [
			_runtime_id, str(parsed.get("tags", []))
		])
	registered.emit(_runtime_id)

# ── Internals ─────────────────────────────────────────────────────────────────

func _load_api_url() -> void:
	_api_base_url = BackendApiConfig.BUNDLED_API_URL
	if FileAccess.file_exists(DEV_CONFIG_PATH):
		var file = FileAccess.open(DEV_CONFIG_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				var url = str(parsed.get("api_base_url", "")).strip_edges()
				if not url.is_empty():
					_api_base_url = url

func _make_install_id() -> String:
	var device = OS.get_unique_id()
	if not device.is_empty():
		return "inst_" + device.substr(0, 20).to_lower().replace("-", "")
	return _make_id("inst")

func _make_id(prefix: String) -> String:
	var t = int(Time.get_unix_time_from_system())
	var r1 = randi()
	var r2 = randi()
	return "%s_%08x%08x%08x" % [prefix, t, r1, r2]
