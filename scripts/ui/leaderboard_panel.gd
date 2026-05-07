extends PanelContainer

signal close_pressed()

@onready var level_option: OptionButton = %LevelOption
@onready var entry_list: VBoxContainer = %EntryList
@onready var close_button: Button = %CloseButton

var leaderboard_service: Node = null

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	level_option.item_selected.connect(_on_level_selected)
	
	# Populate level options
	level_option.clear()
	for i in range(1, 16):
		level_option.add_item("Level %02d" % i)

func show_leaderboard(service: Node, initial_level_id: String = "level_01") -> void:
	leaderboard_service = service
	visible = true
	
	if OS.is_debug_build(): print("[LeaderboardPanel] open level_id=%s" % initial_level_id)
	
	# Select the level in option button
	var level_num = int(initial_level_id.replace("level_", ""))
	var target_idx = level_num - 1
	if target_idx >= 0 and target_idx < level_option.item_count:
		level_option.select(target_idx)
	
	_refresh_list(initial_level_id)

func _on_level_selected(index: int) -> void:
	var level_id = "level_%02d" % (index + 1)
	_refresh_list(level_id)

func _refresh_list(level_id: String) -> void:
	if not leaderboard_service: return
	
	# Clear old entries
	for child in entry_list.get_children():
		child.queue_free()
		
	var entries = leaderboard_service.get_top_scores(level_id)
	
	if entries.is_empty():
		var label = Label.new()
		label.text = "No leaderboard entries yet.\nClear this level to submit your score!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate.a = 0.6
		label.add_theme_font_size_override("font_size", 20)
		entry_list.add_child(label)
		if OS.is_debug_build(): print("[LeaderboardPanel] Displaying empty state for %s" % level_id)
		return
		
	if OS.is_debug_build(): print("[LeaderboardPanel] Displaying %d entries for %s" % [entries.size(), level_id])
		
	# Header
	var header = _create_entry_row("RANK", "PLAYER", "SCORE", "STARS", "TIME", true)
	entry_list.add_child(header)
	
	for i in range(entries.size()):
		var e = entries[i]
		var row = _create_entry_row(
			"#%d" % (i + 1),
			e.player_name,
			str(e.score),
			int(e.stars),
			_format_time(int(e.clear_time))
		)
		
		# Highlight if it's the current player (simple check for now)
		var main = get_tree().current_scene
		if main and main.save_manager:
			if e.player_name == main.save_manager.get_player_name():
				row.modulate = Color(1.0, 1.0, 0.6)
				
		entry_list.add_child(row)

func _create_entry_row(rank: String, p_name: String, score: String, stars_val: Variant, time: String, is_header: bool = false) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var font_size = 18 if is_header else 16
	var color = Color(0.4, 0.8, 1.0) if is_header else Color.WHITE
	
	var l_rank = _create_cell(rank, 60, font_size, color)
	var l_name = _create_cell(p_name, 150, font_size, color)
	var l_score = _create_cell(score, 100, font_size, color)
	
	var l_stars
	if stars_val is String:
		l_stars = _create_cell(stars_val, 100, font_size, color)
	else:
		l_stars = _create_stars_cell(int(stars_val), 100)
		
	var l_time = _create_cell(time, 80, font_size, color)
	
	hbox.add_child(l_rank)
	hbox.add_child(l_name)
	hbox.add_child(l_score)
	hbox.add_child(l_stars)
	hbox.add_child(l_time)
	
	return hbox

func _create_cell(txt: String, width: float, f_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.custom_minimum_size.x = width
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", color)
	return l

func _create_stars_cell(count: int, width: float) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.x = width
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	
	var StarIconScript = load("res://scripts/ui/star_icon.gd")
	for i in range(3):
		var star = Control.new()
		star.set_script(StarIconScript)
		star.custom_minimum_size = Vector2(20, 20)
		if star.has_method("set"):
			star.filled = (i < count)
		hbox.add_child(star)
		
	return hbox

func _on_close_button_pressed() -> void:
	if OS.is_debug_build(): print("[LeaderboardPanel] close")
	visible = false
	close_pressed.emit()

func _format_time(seconds: int) -> String:
	var mins = int(seconds / 60)
	var secs = int(seconds % 60)
	return "%02d:%02d" % [mins, secs]
