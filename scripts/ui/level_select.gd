extends CanvasLayer

signal level_selected(level_path: String)
signal back_pressed()
signal leaderboard_requested(level_id: String)

@onready var back_button: Button = $Root/BackButton

var level_container_map: Dictionary = {} # level_id: Control node
var area_panels: Dictionary = {} # area_id: Control node
var selected_level_path: String = ""
var play_button: Button = null

var dynamic_list_container: Control = null
var intel_panel: Control = null
var loadout_container: Control = null
var mission_info_labels: Dictionary = {}
var notification_label: Label = null
var leaderboard_button: Button = null

func _ready() -> void:
	# Create a clean panel layout for Level Select
	_setup_clean_layout()
	
	back_button.visible = true # Restore Back button to return to Main Menu
	back_button.pressed.connect(func(): back_pressed.emit())

func update_ui(save_manager: Node) -> void:
	# Always ensure nodes are setup
	if dynamic_list_container == null:
		_setup_clean_layout()
	
	# Generate cards if they haven't been created yet
	if level_container_map.is_empty():
		_generate_dynamic_ui(save_manager)
	
	for l_num in range(1, 21):
		var level_id = "level_%02d" % l_num
		if level_container_map.has(level_id):
			_update_dynamic_level_card(level_id, level_container_map[level_id], save_manager)
	
	# Update area headers
	for area_id in range(1, 5):
		if area_panels.has(area_id):
			var unlocked = save_manager.is_area_unlocked(area_id)
			var panel = area_panels[area_id]
			var header = panel.get_node("Header")
			if not unlocked:
				header.modulate = Color(0.6, 0.6, 0.6)
				header.text = "AREA %d: [ LOCKED ]" % area_id
			else:
				header.modulate = Color(1, 1, 1)
				var area_name = "TRAINING SECTOR"
				if area_id == 2: area_name = "IRON SECTOR"
				elif area_id == 3: area_name = "COMMAND SECTOR"
				elif area_id == 4: area_name = "WARFRONT SECTOR"
				header.text = "AREA %d: %s" % [area_id, area_name]

func _generate_dynamic_ui(save_manager: Node) -> void:
	if dynamic_list_container == null: return
	
	# Clear old nodes if any
	for child in dynamic_list_container.get_children():
		child.queue_free()
	
	# Create Area Containers
	for area_id in range(1, 5):
		var area_box = VBoxContainer.new()
		area_box.name = "Area%d" % area_id
		dynamic_list_container.add_child(area_box)
		area_panels[area_id] = area_box
		
		var header = Label.new()
		header.name = "Header"
		header.add_theme_font_size_override("font_size", 32) # Increased for Full HD
		header.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		header.add_theme_constant_override("margin_bottom", 16)
		area_box.add_child(header)
		
		var grid = GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 20)
		area_box.add_child(grid)
		
		var start_l = (area_id - 1) * 5 + 1
		for l_num in range(start_l, start_l + 5):
			var level_id = "level_%02d" % l_num
			var card = _create_level_card(level_id)
			grid.add_child(card)
			level_container_map[level_id] = card

func _create_level_card(level_id: String) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(140, 130) # Increased to fit stars/badge
	
	var btn = Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(140, 96)
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.text = level_id.replace("level_", "L")
	btn.pressed.connect(func(): _select_level("res://data/levels/%s.json" % level_id))
	root.add_child(btn)
	
	# Stars Container
	var stars = Label.new()
	stars.name = "Stars"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", 18)
	stars.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	stars.text = "☆☆☆"
	stars.position = Vector2(0, 100)
	stars.size = Vector2(140, 20)
	root.add_child(stars)
	
	# Lock Icon
	var lock = Label.new()
	lock.name = "LockIcon"
	lock.text = "🔒"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.add_theme_font_size_override("font_size", 32)
	lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lock)
	
	# Perfect Badge
	var badge = Label.new()
	badge.name = "PerfectBadge"
	badge.text = "✨"
	badge.add_theme_font_size_override("font_size", 24)
	badge.position = Vector2(110, -5)
	badge.tooltip_text = "PERFECT CLEAR!"
	btn.add_child(badge)
	
	var label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(0, 120)
	label.size = Vector2(140, 20)
	root.add_child(label)
	
	return root

func _update_dynamic_level_card(level_id: String, container: Control, save_manager: Node) -> void:
	var btn = container.get_node("Button")
	var label = container.get_node("Label")
	var stars_label = container.get_node("Stars")
	var lock_icon = btn.get_node("LockIcon")
	var perfect_badge = btn.get_node("PerfectBadge")
	
	var record = save_manager.get_level_record(level_id)
	var unlocked = save_manager.is_level_unlocked(level_id)
	
	btn.disabled = not unlocked
	lock_icon.visible = not unlocked
	
	if not unlocked:
		btn.text = ""
		btn.modulate = Color(0.3, 0.3, 0.3, 0.8)
		label.text = "LOCKED"
		label.modulate = Color(0.5, 0.5, 0.5)
		stars_label.hide()
		perfect_badge.hide()
	else:
		btn.text = level_id.replace("level_", "L")
		btn.modulate = Color(1, 1, 1)
		label.modulate = Color(1, 1, 1)
		stars_label.show()
		
		var stars_count = record.get("best_stars", 0)
		var stars_text = ""
		for i in range(3):
			stars_text += "★" if i < stars_count else "☆"
		stars_label.text = stars_text
		
		var is_perfect = record.get("perfect_clear", false)
		perfect_badge.visible = is_perfect
		
		if record.get("completed", false):
			btn.modulate = Color(0.8, 1.0, 0.8)
			if is_perfect:
				btn.modulate = Color(1.0, 0.9, 0.6) # Golden hue for perfect
			label.text = "Best: " + str(record.get("best_score", 0))
		else:
			label.text = "NEW MISSION"
			btn.modulate = Color(0.8, 0.9, 1.2)

func _update_selection_visuals() -> void:
	for level_id in level_container_map:
		var card = level_container_map[level_id]
		var btn = card.get_node("Button")
		var path = "res://data/levels/%s.json" % level_id
		
		if path == selected_level_path:
			btn.modulate = Color(1.5, 1.5, 2.0) # Bright neon blue highlight
			btn.scale = Vector2(1.05, 1.05)
		else:
			btn.scale = Vector2(1.0, 1.0)
			# Reset to normal based on status
			var save_manager = get_tree().current_scene.get_node_or_null("SaveManager")
			if save_manager:
				_update_dynamic_level_card(level_id, card, save_manager)

func _load_config(id: String) -> Dictionary:
	var path = "res://data/levels/%s.json" % id
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(json_text)
	return json if json else {}

func _setup_clean_layout() -> void:
	# Hide existing UI nodes to prevent overlap/blocking
	if has_node("Root/VBoxContainer"):
		$Root/VBoxContainer.hide()
	if has_node("Root/Title"):
		$Root/Title.hide()
	if has_node("Root/Background"):
		$Root/Background.modulate = Color(0.4, 0.4, 0.4, 1.0) # Dim original bg a bit more for focus

	var outer_margin = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 32)
	outer_margin.add_theme_constant_override("margin_right", 32)
	outer_margin.add_theme_constant_override("margin_top", 32)
	outer_margin.add_theme_constant_override("margin_bottom", 32)
	$Root.add_child(outer_margin)
	
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.3, 0.6, 1.0)
	panel_style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)
	
	# Header Row: Back Button and Title
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	if back_button:
		back_button.get_parent().remove_child(back_button)
		header.add_child(back_button)
		back_button.text = " < BACK"
		back_button.custom_minimum_size = Vector2(120, 44)
		back_button.add_theme_font_size_override("font_size", 18)
	
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	
	var title = Label.new()
	title.text = "WORLD EXPEDITION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	header.add_child(title)
	
	# Notification Label
	notification_label = Label.new()
	notification_label.name = "UnlockNotification"
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 24)
	notification_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	notification_label.modulate.a = 0
	vbox.add_child(notification_label)
	vbox.move_child(notification_label, 1) # Below header
	
	var header_spacer_r = Control.new()
	header_spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer_r)
	
	# Dummy node to balance header if needed, or just let title be center-ish
	var dummy = Control.new()
	dummy.custom_minimum_size.x = 120
	header.add_child(dummy)
	
	# Main horizontal split
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 40)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(main_hbox)
	
	# Left Side: World Map
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)
	
	# Wrap dynamic list in a scroll container for safety
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)
	
	dynamic_list_container = VBoxContainer.new()
	dynamic_list_container.name = "DynamicList"
	dynamic_list_container.add_theme_constant_override("separation", 32)
	dynamic_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(dynamic_list_container)
	
	# Right Side: Mission Intel & Loadout
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size.x = 380
	right_vbox.add_theme_constant_override("separation", 16)
	main_hbox.add_child(right_vbox)
	
	# Intel Panel (Styled & Scrollable)
	var intel_bg = PanelContainer.new()
	intel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var intel_style = StyleBoxFlat.new()
	intel_style.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	intel_style.set_border_width_all(1)
	intel_style.border_color = Color(0.3, 0.4, 0.6, 0.8)
	intel_style.set_corner_radius_all(10)
	intel_bg.add_theme_stylebox_override("panel", intel_style)
	right_vbox.add_child(intel_bg)
	
	var intel_scroll = ScrollContainer.new()
	intel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	intel_bg.add_child(intel_scroll)
	
	var intel_margin = MarginContainer.new()
	intel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_margin.add_theme_constant_override("margin_left", 16)
	intel_margin.add_theme_constant_override("margin_right", 16)
	intel_margin.add_theme_constant_override("margin_top", 16)
	intel_margin.add_theme_constant_override("margin_bottom", 16)
	intel_scroll.add_child(intel_margin)
	
	_setup_intel_panel(intel_margin)
	
	# Play Button at the bottom of the right column
	play_button = Button.new()
	play_button.text = "SELECT MISSION"
	play_button.custom_minimum_size = Vector2(0, 72)
	play_button.disabled = true
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.5, 0.25)
	btn_style.set_corner_radius_all(15)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.15, 0.65, 0.35)
	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2)
	
	play_button.add_theme_stylebox_override("normal", btn_style)
	play_button.add_theme_stylebox_override("hover", btn_hover)
	play_button.add_theme_stylebox_override("disabled", btn_disabled)
	play_button.add_theme_font_size_override("font_size", 24)
	
	right_vbox.add_child(play_button)
	play_button.pressed.connect(_on_play_pressed)
	
	# Back button was moved to header, so we don't need this legacy logic
	# but we should ensure it's themed if we care.
	if back_button:
		var back_style = StyleBoxFlat.new()
		back_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		back_style.set_corner_radius_all(8)
		back_button.add_theme_stylebox_override("normal", back_style)

func _setup_intel_panel(container: Control) -> void:
	intel_panel = VBoxContainer.new()
	intel_panel.name = "IntelVBox"
	intel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_panel.add_theme_constant_override("separation", 15)
	container.add_child(intel_panel)
	
	var intel_title = Label.new()
	intel_title.text = "MISSION INTEL"
	intel_title.add_theme_font_size_override("font_size", 28) # Slightly larger
	intel_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	intel_panel.add_child(intel_title)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	intel_panel.add_child(grid)
	
	var fields = [
		["Name:", "mission_name"],
		["Area:", "area_name"],
		["Difficulty:", "difficulty"],
		["Gold:", "starting_gold"],
		["Lives:", "starting_lives"],
		["Intel:", "enemy_intel"]
	]
	
	for field in fields:
		var label_key = Label.new()
		label_key.text = field[0]
		label_key.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		label_key.add_theme_font_size_override("font_size", 16) # Increased
		grid.add_child(label_key)
		
		var label_val = Label.new()
		label_val.text = "---"
		label_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_val.add_theme_font_size_override("font_size", 16) # Increased
		grid.add_child(label_val)
		mission_info_labels[field[1]] = label_val
	
	var rec_val = Label.new()
	rec_val.text = "---"
	rec_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rec_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_val.add_theme_font_size_override("font_size", 16) # Increased
	intel_panel.add_child(rec_val)
	mission_info_labels["recommended"] = rec_val
	
	# Add Waves count display
	var waves_label_hbox = HBoxContainer.new()
	intel_panel.add_child(waves_label_hbox)
	
	var waves_key = Label.new()
	waves_key.text = "Total Waves:"
	waves_key.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	waves_key.add_theme_font_size_override("font_size", 14)
	waves_label_hbox.add_child(waves_key)
	
	var waves_val = Label.new()
	waves_val.text = "---"
	waves_val.add_theme_font_size_override("font_size", 14)
	waves_label_hbox.add_child(waves_val)
	mission_info_labels["total_waves"] = waves_val
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 12
	intel_panel.add_child(spacer2)
	
	leaderboard_button = Button.new()
	leaderboard_button.text = "VIEW LEADERBOARD"
	leaderboard_button.custom_minimum_size = Vector2(0, 40)
	leaderboard_button.pressed.connect(func(): 
		var level_id = selected_level_path.get_file().get_basename()
		if OS.is_debug_build(): print("[WorldMap] View leaderboard clicked level_id=%s" % level_id)
		leaderboard_requested.emit(level_id)
	)
	intel_panel.add_child(leaderboard_button)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size.y = 12
	intel_panel.add_child(spacer3)
	
	var loadout_title = Label.new()
	loadout_title.text = "TOWER LOADOUT (MAX 4)"
	loadout_title.add_theme_font_size_override("font_size", 18) # Increased
	loadout_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	intel_panel.add_child(loadout_title)
	
	loadout_container = VBoxContainer.new()
	loadout_container.add_theme_constant_override("separation", 5)
	intel_panel.add_child(loadout_container)
	
	var loadout_msg = Label.new()
	loadout_msg.name = "LoadoutMessage"
	loadout_msg.add_theme_font_size_override("font_size", 12)
	loadout_msg.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	loadout_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intel_panel.add_child(loadout_msg)
	mission_info_labels["loadout_message"] = loadout_msg
	
	_create_loadout_ui()

func _create_loadout_ui() -> void:
	if loadout_container == null: return
	for child in loadout_container.get_children(): child.queue_free()
	
	var main = get_tree().current_scene
	if not main: return
	
	var available = main.get("available_tower_types")
	var selected = main.get("selected_loadout")
	if available == null or selected == null: return
	
	for tower_id in available:
		var hbox = HBoxContainer.new()
		loadout_container.add_child(hbox)
		
		var check = CheckBox.new()
		check.text = tower_id.replace("_tower", "").capitalize()
		check.button_pressed = selected.has(tower_id)
		check.toggled.connect(func(v): _on_tower_toggled(tower_id, v))
		hbox.add_child(check)

func _on_tower_toggled(tower_id: String, active: bool) -> void:
	var main = get_tree().current_scene
	if not main: return
	
	var selected = main.selected_loadout
	if active:
		if not selected.has(tower_id):
			if selected.size() >= main.MAX_TOWER_LOADOUT_SIZE:
				_update_play_button_state() # Force refresh to show warning if I add one
				_create_loadout_ui() # Reset UI state
				return
			selected.append(tower_id)
	else:
		if selected.has(tower_id):
			if selected.size() <= main.MIN_TOWER_LOADOUT_SIZE:
				_create_loadout_ui() # Reset UI state
				return
			selected.erase(tower_id)
	
	_play_ui_click_sound()
	_update_play_button_state()

func _update_intel_panel(config: Dictionary) -> void:
	mission_info_labels["mission_name"].text = config.get("name", "---")
	mission_info_labels["area_name"].text = config.get("area_name", "---")
	mission_info_labels["difficulty"].text = config.get("difficulty", "---")
	mission_info_labels["starting_gold"].text = str(config.get("starting_gold", "---"))
	mission_info_labels["starting_lives"].text = str(config.get("starting_lives", "---"))
	
	var intel = config.get("enemy_intel", [])
	mission_info_labels["enemy_intel"].text = ", ".join(intel) if not intel.is_empty() else "Unknown"
	
	var rec = config.get("recommended_roles", [])
	mission_info_labels["recommended"].text = ", ".join(rec) if not rec.is_empty() else "None"
	
	# Compact Intel Logic
	var main = get_tree().current_scene
	if main:
		var level_id_number = 0
		if main.has_method("level_id_to_int"):
			level_id_number = main.level_id_to_int(config.get("id", ""))
		var wave_previews = main.get_wave_preview_data(level_id_number)
		
		mission_info_labels["total_waves"].text = str(wave_previews.size())
		
		var all_traits = {}
		var all_roles = {}
		for preview in wave_previews:
			for t in preview.get("traits", []): all_traits[t] = true
			for r in preview.get("recommended_roles", []): all_roles[r] = true
		
		var intel_list = all_traits.keys()
		mission_info_labels["enemy_intel"].text = ", ".join(intel_list) if not intel_list.is_empty() else "Unknown"
		
		var rec_list = all_roles.keys()
		mission_info_labels["recommended"].text = ", ".join(rec_list) if not rec_list.is_empty() else "None"
	
	_create_loadout_ui()

func select_level(path: String) -> void:
	_select_level(path)

func _select_level(path: String) -> void:
	selected_level_path = path
	var main = get_tree().current_scene
	var level_id = path.get_file().get_basename()
	var config = {}
	if main and main.has_method("get_level_config"):
		config = main.get_level_config(level_id)
	else:
		config = _load_config(level_id)
	
	if main and main.has_method("get_default_loadout_for_level"):
		main.selected_loadout = main.get_default_loadout_for_level(level_id)
	
	_update_intel_panel(config)
	
	_update_selection_visuals()
	_update_play_button_state()
	_play_ui_click_sound()

func _update_play_button_state() -> void:
	if play_button == null or selected_level_path == "": return
	
	var level_id = selected_level_path.get_file().get_basename()
	var save_manager = get_tree().current_scene.get_node_or_null("SaveManager")
	
	if save_manager:
		var unlocked = save_manager.is_level_unlocked(level_id)
		var record = save_manager.get_level_record(level_id)
		var completed = record.get("completed", false)
		
		play_button.disabled = not unlocked
		if leaderboard_button: leaderboard_button.disabled = false
		
		# Loadout validation
		var main = get_tree().current_scene
		var valid_loadout = true
		if main and main.has_method("is_valid_loadout"):
			valid_loadout = main.is_valid_loadout(main.selected_loadout)
		
		if not valid_loadout:
			play_button.disabled = true
			play_button.text = "INVALID LOADOUT"
			play_button.modulate = Color(1, 0.5, 0.5)
			if mission_info_labels.has("loadout_message"):
				mission_info_labels["loadout_message"].text = "Select 1-4 towers"
		else:
			if mission_info_labels.has("loadout_message"):
				mission_info_labels["loadout_message"].text = ""
				
			if not unlocked:
				play_button.text = "MISSION LOCKED"
				play_button.modulate = Color(1, 0.4, 0.4)
			elif completed:
				play_button.text = "RE-DEPLOY"
				play_button.modulate = Color(0.7, 1.0, 0.7)
			else:
				play_button.text = "START MISSION"
				play_button.modulate = Color(0.8, 1.0, 0.8)

func _unlock_audio() -> void:
	var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("unlock_audio"):
		audio_manager.unlock_audio()

func _on_play_pressed() -> void:
	if selected_level_path != "":
		_unlock_audio()
		level_selected.emit(selected_level_path)

func _play_ui_click_sound() -> void:
	var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("ui_click")

func show_select() -> void:
	show()
	var sm = get_tree().current_scene.get_node_or_null("SaveManager")
	if sm: update_ui(sm)

func show_unlocked_notification(level_id: String) -> void:
	if notification_label == null: return
	
	var level_name = level_id.replace("_", " ").capitalize()
	notification_label.text = "NEW MISSION UNLOCKED: " + level_name + "!"
	
	var tween = create_tween()
	tween.tween_property(notification_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.0)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)

func hide_select() -> void:
	hide()
func _load_waves_config(path: String) -> Array:
	var main = get_tree().current_scene
	if main and main.has_method("load_waves_config"):
		return main.load_waves_config(path)
	return []
