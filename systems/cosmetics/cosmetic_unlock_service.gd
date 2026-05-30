extends Node
## CosmeticUnlockService — single source-of-truth for cosmetic unlock state.
##
## Offline:  reads/writes user://cosmetic_unlocks.json.
## Online:   on startup, serves cached unlocks immediately, then fires a
##            background GET to the server and union-merges any new grants.
## Earned unlocks are queued and POSTed to the server.
## One-time migration: existing SaveManager cosmetics.unlocked is absorbed on
## first run, then the flag is set so it never runs again.
##
## CosmeticInventory delegates all unlock reads/writes here.
## Server API:
##   GET  /api/v1/cosmetics/unlocks?install_id=<id>
##        → { "unlocked_ids": [...] }
##   POST /api/v1/cosmetics/unlocks
##        ← { "install_id": "...", "unlocked_ids": [...] }

const BackendApiConfig := preload("res://scripts/config/backend_api_config.gd")

const CACHE_PATH := "user://cosmetic_unlocks.json"
const FETCH_TIMEOUT := 8.0
const POST_TIMEOUT  := 8.0

signal unlocks_changed()
signal sync_completed(source: String)  # "server" | "cache" | "local"

var _install_id: String = ""
var _unlocked_ids: Array[String] = []
var _migrated: bool = false
var _last_sync: int = 0
var _api_base_url: String = ""

var _http_fetch: HTTPRequest = null
var _http_push: HTTPRequest = null
var _push_queue: Array[String] = []
var _fetch_in_flight: bool = false
var _push_in_flight: bool = false

var _dev_grant_all: bool = false
var _dev_grant_ids: Array[String] = []

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	name = "CosmeticUnlockService"
	_api_base_url = BackendApiConfig.BUNDLED_API_URL
	_load_api_url_override()
	_setup_http()
	_load_cache()
	_load_dev_grants()
	# Migration runs lazily (SaveManager is a scene node, not yet available here).
	# _fetch runs deferred so HTTPRequest children are fully ready.
	call_deferred("_fetch_from_server_background")

# ── Public API ─────────────────────────────────────────────────────────────────

func get_unlocked_ids() -> Array[String]:
	_try_lazy_migration()
	return _unlocked_ids.duplicate()

func is_unlocked(cosmetic_id: String) -> bool:
	_try_lazy_migration()
	if _dev_grant_all or _dev_grant_ids.has(cosmetic_id):
		return true
	if _is_registry_always_unlocked(cosmetic_id):
		return true
	return _unlocked_ids.has(cosmetic_id)

func unlock(cosmetic_id: String) -> bool:
	if cosmetic_id == "" or _unlocked_ids.has(cosmetic_id):
		return false
	_unlocked_ids.append(cosmetic_id)
	_save_cache()
	_enqueue_push(cosmetic_id)
	unlocks_changed.emit()
	return true

## Force a server re-fetch (e.g. after login or when the player opens the shop).
func refresh_from_server() -> void:
	_fetch_from_server_background()

func _is_registry_always_unlocked(cosmetic_id: String) -> bool:
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if registry == null or not registry.has_method("get_cosmetic"):
		return false
	var cfg: Dictionary = registry.get_cosmetic(cosmetic_id)
	var condition: Dictionary = cfg.get("unlock_condition", {}) as Dictionary
	return str(condition.get("type", "")) == "always_unlocked"

# ── Local cache ────────────────────────────────────────────────────────────────

func _load_cache() -> void:
	_install_id = _read_install_id()
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	_migrated  = bool(parsed.get("migrated_from_save", false))
	_last_sync = int(parsed.get("last_sync", 0))
	_unlocked_ids.clear()
	for raw_id in parsed.get("unlocked_ids", []):
		var s := str(raw_id).strip_edges()
		if s != "" and not _unlocked_ids.has(s):
			_unlocked_ids.append(s)

func _load_dev_grants() -> void:
	const DEV_GRANTS_PATH := "user://dev_cosmetic_grants.json"
	if not FileAccess.file_exists(DEV_GRANTS_PATH):
		return
	var file := FileAccess.open(DEV_GRANTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	_dev_grant_all = bool(parsed.get("grant_all", false))
	_dev_grant_ids.clear()
	for raw_id in parsed.get("grant_ids", []):
		var s := str(raw_id).strip_edges()
		if s != "":
			_dev_grant_ids.append(s)

func _save_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[CosmeticUnlock] Could not write cache to " + CACHE_PATH)
		return
	file.store_string(JSON.stringify({
		"install_id":        _install_id,
		"unlocked_ids":      _unlocked_ids,
		"migrated_from_save": _migrated,
		"last_sync":         _last_sync,
	}, "\t"))
	file.close()

# ── Migration from SaveManager ────────────────────────────────────────────────

func _try_lazy_migration() -> void:
	if _migrated:
		return
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	var sm: Node = scene.get_node_or_null("SaveManager")
	if sm == null:
		return
	if sm.has_method("get_unlocked_cosmetic_ids"):
		for id: String in sm.get_unlocked_cosmetic_ids():
			if id != "" and not _unlocked_ids.has(id):
				_unlocked_ids.append(id)
	_migrated = true
	_save_cache()

# ── Server fetch ───────────────────────────────────────────────────────────────

func _fetch_from_server_background() -> void:
	if _fetch_in_flight or _install_id == "" or _api_base_url.strip_edges() == "":
		return
	_fetch_in_flight = true
	var url := _api_base_url.rstrip("/") + "/api/v1/cosmetics/unlocks?install_id=" \
			+ _install_id.uri_encode()
	var err := _http_fetch.request(url, PackedStringArray([]), HTTPClient.METHOD_GET)
	if err != OK:
		_fetch_in_flight = false

func _on_fetch_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetch_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var changed := false
	for raw_id in parsed.get("unlocked_ids", []):
		var s := str(raw_id).strip_edges()
		if s != "" and not _unlocked_ids.has(s):
			_unlocked_ids.append(s)
			changed = true
	_last_sync = int(Time.get_unix_time_from_system())
	_save_cache()
	if changed:
		unlocks_changed.emit()
	sync_completed.emit("server")

# ── Server push ────────────────────────────────────────────────────────────────

func _enqueue_push(cosmetic_id: String) -> void:
	if not _push_queue.has(cosmetic_id):
		_push_queue.append(cosmetic_id)
	_flush_push()

func _flush_push() -> void:
	if _push_in_flight or _push_queue.is_empty() \
			or _install_id == "" or _api_base_url.strip_edges() == "":
		return
	_push_in_flight = true
	var url := _api_base_url.rstrip("/") + "/api/v1/cosmetics/unlocks"
	var body := JSON.stringify({
		"install_id":   _install_id,
		"unlocked_ids": _push_queue.duplicate(),
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http_push.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_push_in_flight = false

func _on_push_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_push_in_flight = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_push_queue.clear()
	# On failure the queue is kept; it retries on the next unlock() call.

# ── Internals ──────────────────────────────────────────────────────────────────

func _setup_http() -> void:
	_http_fetch = HTTPRequest.new()
	_http_fetch.timeout = FETCH_TIMEOUT
	add_child(_http_fetch)
	_http_fetch.request_completed.connect(_on_fetch_completed)

	_http_push = HTTPRequest.new()
	_http_push.timeout = POST_TIMEOUT
	add_child(_http_push)
	_http_push.request_completed.connect(_on_push_completed)

func _read_install_id() -> String:
	# RuntimeIdentityService may not be an autoload in all builds; try both paths.
	var ris := get_node_or_null("/root/RuntimeIdentityService")
	if ris != null and ris.has_method("get_install_id"):
		var id := str(ris.get_install_id()).strip_edges()
		if id != "":
			return id
	const IDENTITY_CACHE := "user://runtime_identity.json"
	if FileAccess.file_exists(IDENTITY_CACHE):
		var file := FileAccess.open(IDENTITY_CACHE, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				var id := str(parsed.get("install_id", "")).strip_edges()
				if id != "":
					return id
	return ""

func _load_api_url_override() -> void:
	const DEV_CONFIG := "user://remote_access_config_dev.json"
	if FileAccess.file_exists(DEV_CONFIG):
		var file := FileAccess.open(DEV_CONFIG, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				var url := str(parsed.get("api_base_url", "")).strip_edges()
				if not url.is_empty():
					_api_base_url = url
