extends PanelContainer

signal close_pressed()

@onready var level_option: OptionButton = %LevelOption
@onready var entry_list: VBoxContainer = %EntryList
@onready var close_button: Button = %CloseButton

var leaderboard_service: Node = null   # local fallback
var online_client: Node = null         # LeaderboardClient (optional)

var _current_level_id: String = "level_01"

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	level_option.item_selected.connect(_on_level_selected)
	level_option.clear()
	for i in range(1, 16):
		level_option.add_item("Level %02d" % i)

# Called by main.gd. Pass online_client if the LeaderboardClient node is available.
func show_leaderboard(service: Node, initial_level_id: String = "level_01", p_online_client: Node = null) -> void:
	leaderboard_service = service
	online_client = p_online_client
	visible = true

	# Retry any pending submissions now that the leaderboard screen is open
	if online_client and online_client.has_method("retry_pending"):
		online_client.retry_pending()

	_current_level_id = initial_level_id
	var level_num = int(initial_level_id.replace("level_0", "").replace("level_", ""))
	var idx = clampi(level_num - 1, 0, level_option.item_count - 1)
	level_option.select(idx)

	_refresh_list(initial_level_id)

func _on_level_selected(index: int) -> void:
	_current_level_id = "level_%02d" % (index + 1)
	_refresh_list(_current_level_id)

func _refresh_list(level_id: String) -> void:
	if online_client and online_client.has_method("fetch_top_scores") and online_client.has_api_url():
		_show_loading()
		if not online_client.top_scores_loaded.is_connected(_on_online_scores_loaded):
			online_client.top_scores_loaded.connect(_on_online_scores_loaded)
		online_client.fetch_top_scores(level_id, 50)
	else:
		_show_local(level_id)

func _on_online_scores_loaded(ok: bool, items: Array) -> void:
	# Disconnect to avoid double-fire on next fetch
	if online_client and online_client.top_scores_loaded.is_connected(_on_online_scores_loaded):
		online_client.top_scores_loaded.disconnect(_on_online_scores_loaded)

	if ok and not items.is_empty():
		_render_online(items)
	else:
		# Fall back to local scores silently
		_show_local(_current_level_id)

func _show_loading() -> void:
	_clear_list()
	var lbl = Label.new()
	lbl.text = "Loading scores..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.6
	lbl.add_theme_font_size_override("font_size", 18)
	entry_list.add_child(lbl)

func _show_local(level_id: String) -> void:
	_clear_list()
	if not leaderboard_service:
		return
	var entries = leaderboard_service.get_top_scores(level_id)
	if entries.is_empty():
		_show_empty()
		return
	var header = _create_row("RANK", "PLAYER", "SCORE", "WAVES", "TIME", true)
	entry_list.add_child(header)
	for i in range(entries.size()):
		var e = entries[i]
		var row = _create_row(
			"#%d" % (i + 1),
			str(e.get("player_name", "?")),
			str(e.get("score", 0)),
			"---",
			_fmt_time(int(e.get("clear_time", 0)))
		)
		_highlight_own(row, str(e.get("player_name", "")))
		entry_list.add_child(row)

func _render_online(items: Array) -> void:
	_clear_list()
	if items.is_empty():
		_show_empty()
		return
	var header = _create_row("RANK", "PLAYER", "SCORE", "WAVES", "TIME", true)
	entry_list.add_child(header)
	for item in items:
		if not (item is Dictionary):
			continue
		var waves_str = "%d/60" % int(item.get("wave_reached", 0))
		if bool(item.get("cleared", false)):
			waves_str = "CLEAR"
		var row = _create_row(
			"#%d" % int(item.get("rank", 0)),
			str(item.get("player_name", "?")),
			str(item.get("score", 0)),
			waves_str,
			_fmt_time(int(item.get("run_time_seconds", 0)))
		)
		_highlight_own(row, str(item.get("player_name", "")))
		entry_list.add_child(row)

func _show_empty() -> void:
	var lbl = Label.new()
	lbl.text = "No leaderboard entries yet.\nClear this level to submit your score!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.6
	lbl.add_theme_font_size_override("font_size", 18)
	entry_list.add_child(lbl)

func _clear_list() -> void:
	for child in entry_list.get_children():
		child.queue_free()

func _highlight_own(row: HBoxContainer, player_name: String) -> void:
	var main = get_tree().current_scene
	if main and "save_manager" in main and main.save_manager:
		if player_name == main.save_manager.get_player_name():
			row.modulate = Color(1.0, 1.0, 0.6)

# ---- row builder ----

func _create_row(rank: String, p_name: String, score: String, waves: String, time_str: String, is_header: bool = false) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	var fs = 18 if is_header else 16
	var col = Color(0.4, 0.8, 1.0) if is_header else Color.WHITE
	hbox.add_child(_cell(rank,    60,  fs, col))
	hbox.add_child(_cell(p_name, 160,  fs, col))
	hbox.add_child(_cell(score,  110,  fs, col))
	hbox.add_child(_cell(waves,   80,  fs, col))
	hbox.add_child(_cell(time_str, 80, fs, col))
	return hbox

func _cell(txt: String, width: float, fs: int, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.custom_minimum_size.x = width
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	return l

func _on_close_button_pressed() -> void:
	visible = false
	close_pressed.emit()

func _fmt_time(seconds: int) -> String:
	return "%02d:%02d" % [int(float(seconds) / 60.0), int(seconds % 60)]
