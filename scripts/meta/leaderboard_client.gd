extends Node

const BackendApiConfig = preload("res://scripts/config/backend_api_config.gd")

# Online leaderboard client with offline fallback.
#
# Configuration:
#   Set BUNDLED_API_URL to your deployed API before building for production.
#   During development, create user://leaderboard_config.json:
#     { "api_base_url": "http://localhost:8080" }
#
# Usage:
#   submit_score(payload)    → emits score_submitted(ok, score, rank)
#   fetch_top_scores(level_id, limit) → emits top_scores_loaded(ok, items)
#   retry_pending()          → retries any stored failed submissions

const CONFIG_PATH: String = "user://leaderboard_config.json"
const PENDING_PATH: String = "user://pending_leaderboard.json"
const REQUEST_TIMEOUT: float = 10.0

signal score_submitted(ok: bool, score: int, rank: int)
signal top_scores_loaded(ok: bool, items: Array)

enum _State { IDLE, SUBMITTING, FETCHING }

var api_base_url: String = ""
var _state: _State = _State.IDLE
var _queue: Array = []
var _current_job: Dictionary = {}
var _pending: Array = []
var _http: HTTPRequest = null

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_config()
	_load_pending()

# ---- public API ----

# Build and enqueue a score submission. Saves to pending if offline.
func submit_score(payload: Dictionary) -> void:
	if not payload.has("client_run_id") or str(payload.get("client_run_id", "")).is_empty():
		payload["client_run_id"] = _make_run_id(payload)
	if not payload.has("client_created_at"):
		payload["client_created_at"] = int(Time.get_unix_time_from_system())
	_enqueue({"type": "submit", "payload": payload})

# Fetch the top scores list for a level.
func fetch_top_scores(level_id: String, limit: int = 50) -> void:
	_enqueue({"type": "fetch", "level_id": level_id, "limit": limit})

# Retry all pending submissions (call on game start and when opening leaderboard).
func retry_pending() -> void:
	if _pending.is_empty():
		return
	var to_retry = _pending.duplicate()
	_pending.clear()
	_save_pending()
	for entry in to_retry:
		_enqueue({"type": "submit", "payload": entry})

func has_api_url() -> bool:
	return not api_base_url.strip_edges().is_empty()

# ---- queue processing ----

func _enqueue(job: Dictionary) -> void:
	_queue.push_back(job)
	_process_queue()

func _process_queue() -> void:
	if _state != _State.IDLE or _queue.is_empty():
		return
	var job: Dictionary = _queue.pop_front()
	_current_job = job
	match job["type"]:
		"submit": _do_submit(job["payload"])
		"fetch":  _do_fetch(str(job["level_id"]), int(job.get("limit", 50)))

func _do_submit(payload: Dictionary) -> void:
	if not has_api_url():
		_add_to_pending(payload)
		score_submitted.emit(false, 0, 0)
		_current_job = {}
		call_deferred("_process_queue")
		return
	var url = api_base_url.rstrip("/") + "/api/v1/leaderboard/submit"
	var body = JSON.stringify(payload)
	var err = _http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("[LeaderboardClient] HTTP request error: %d" % err)
		_add_to_pending(payload)
		score_submitted.emit(false, 0, 0)
		_current_job = {}
		call_deferred("_process_queue")
		return
	_state = _State.SUBMITTING

func _do_fetch(level_id: String, limit: int) -> void:
	if not has_api_url():
		top_scores_loaded.emit(false, [])
		_current_job = {}
		call_deferred("_process_queue")
		return
	var url = "%s/api/v1/leaderboard/top?level_id=%s&limit=%d" % [
		api_base_url.rstrip("/"), level_id.uri_encode(), limit
	]
	var err = _http.request(url)
	if err != OK:
		top_scores_loaded.emit(false, [])
		_current_job = {}
		call_deferred("_process_queue")
		return
	_state = _State.FETCHING

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var prev_state = _state
	_state = _State.IDLE

	var success = (result == HTTPRequest.RESULT_SUCCESS) and (response_code >= 200) and (response_code < 300)

	if not success:
		if prev_state == _State.SUBMITTING:
			var payload = _current_job.get("payload", {})
			if not payload.is_empty():
				_add_to_pending(payload)
			score_submitted.emit(false, 0, 0)
		elif prev_state == _State.FETCHING:
			top_scores_loaded.emit(false, [])
		_current_job = {}
		_process_queue()
		return

	var text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(text) != OK:
		if prev_state == _State.SUBMITTING:
			score_submitted.emit(false, 0, 0)
		elif prev_state == _State.FETCHING:
			top_scores_loaded.emit(false, [])
		_current_job = {}
		_process_queue()
		return

	var data = json.data
	if prev_state == _State.SUBMITTING:
		var ok = bool(data.get("ok", false))
		var score = int(data.get("score", 0))
		var rank = int(data.get("rank", 0))
		score_submitted.emit(ok, score, rank)
	elif prev_state == _State.FETCHING:
		var items = data.get("items", [])
		if not (items is Array):
			items = []
		top_scores_loaded.emit(true, items)

	_current_job = {}
	_process_queue()

# ---- pending storage ----

func _add_to_pending(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	# Deduplicate by client_run_id
	var run_id = str(payload.get("client_run_id", ""))
	if run_id != "":
		for existing in _pending:
			if str(existing.get("client_run_id", "")) == run_id:
				return
	_pending.append(payload)
	_save_pending()
	if OS.is_debug_build():
		print("[LeaderboardClient] Stored pending submission (total=%d)" % _pending.size())

func _save_pending() -> void:
	var file = FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_pending))
	file.close()

func _load_pending() -> void:
	if not FileAccess.file_exists(PENDING_PATH):
		return
	var file = FileAccess.open(PENDING_PATH, FileAccess.READ)
	if file == null:
		return
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Array:
		_pending = json.data
		if OS.is_debug_build() and not _pending.is_empty():
			print("[LeaderboardClient] Loaded %d pending submissions." % _pending.size())

# ---- config ----

func _load_config() -> void:
	# Start with bundled URL constant
	api_base_url = BackendApiConfig.BUNDLED_API_URL

	# Override from user config if present (useful for dev / per-server deploys)
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file == null:
			return
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			var url = str(json.data.get("api_base_url", "")).strip_edges()
			if not url.is_empty():
				api_base_url = url
				if OS.is_debug_build():
					print("[LeaderboardClient] API URL from config: %s" % api_base_url)

# ---- helpers ----

func _make_run_id(payload: Dictionary) -> String:
	var level = str(payload.get("level_id", "unknown"))
	var t = str(int(Time.get_unix_time_from_system()))
	var r = str(randi() % 99999)
	return "%s_%s_%s" % [level, t, r]
