extends CanvasLayer

signal level_selected(level_path: String)
signal back_pressed()

@onready var back_button: Button = $Root/BackButton

var level_container_map: Dictionary = {} # level_id: Control node
var area_panels: Dictionary = {} # area_id: Control node
var selected_level_path: String = ""
var play_button: Button = null

var dynamic_list_container: Control = null

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
	
	for level_num in range(1, 11):
		var level_id = "level_%02d" % level_num
		if level_container_map.has(level_id):
			_update_dynamic_level_card(level_id, level_container_map[level_id], save_manager)
	
	# Update area headers
	for area_id in range(1, 3):
		if area_panels.has(area_id):
			var unlocked = save_manager.is_area_unlocked(area_id)
			var panel = area_panels[area_id]
			var header = panel.get_node("Header")
			if not unlocked:
				header.modulate = Color(0.6, 0.6, 0.6)
				header.text = "AREA %d: [ LOCKED ]" % area_id
			else:
				header.modulate = Color(1, 1, 1)
				header.text = "AREA %d: %s" % [area_id, "TRAINING SECTOR" if area_id == 1 else "IRON SECTOR"]

func _generate_dynamic_ui(save_manager: Node) -> void:
	if dynamic_list_container == null: return
	
	# Clear old nodes if any
	for child in dynamic_list_container.get_children():
		child.queue_free()
	
	# Create Area Containers
	for area_id in range(1, 3):
		var area_box = VBoxContainer.new()
		area_box.name = "Area%d" % area_id
		dynamic_list_container.add_child(area_box)
		area_panels[area_id] = area_box
		
		var header = Label.new()
		header.name = "Header"
		header.add_theme_font_size_override("font_size", 20)
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		area_box.add_child(header)
		
		var grid = GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 15)
		grid.add_theme_constant_override("v_separation", 15)
		area_box.add_child(grid)
		
		var start_l = (area_id - 1) * 5 + 1
		for l_num in range(start_l, start_l + 5):
			var level_id = "level_%02d" % l_num
			var card = _create_level_card(level_id)
			grid.add_child(card)
			level_container_map[level_id] = card

func _create_level_card(level_id: String) -> Control:
	var btn = Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(100, 80)
	btn.text = level_id.replace("level_", "L")
	btn.pressed.connect(func(): _select_level("res://data/levels/%s.json" % level_id))
	
	var label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var container = VBoxContainer.new()
	container.add_child(btn)
	container.add_child(label)
	return container

func _update_dynamic_level_card(level_id: String, container: Control, save_manager: Node) -> void:
	var btn = container.get_node("Button")
	var label = container.get_node("Label")
	
	var record = save_manager.get_level_record(level_id)
	var unlocked = save_manager.is_level_unlocked(level_id)
	
	btn.disabled = not unlocked
	
	if not unlocked:
		btn.text = "L%s" % level_id.replace("level_", "")
		btn.modulate = Color(0.3, 0.3, 0.3, 0.8)
		label.text = "Locked"
		label.modulate = Color(0.5, 0.5, 0.5)
	else:
		btn.modulate = Color(1, 1, 1)
		label.modulate = Color(1, 1, 1)
		if record.get("completed", false):
			btn.text = "✓ L%s" % level_id.replace("level_", "")
			btn.modulate = Color(0.6, 1.0, 0.6)
			label.text = "CLEARED"
			label.modulate = Color(0.7, 1.0, 0.7)
		else:
			btn.text = "L%s" % level_id.replace("level_", "")
			label.text = "MISSION"
			btn.modulate = Color(1.0, 1.0, 1.5) # Distinct blue highlight for current
			label.modulate = Color(0.8, 0.9, 1.0)

func _update_selection_visuals() -> void:
	for level_id in level_container_map:
		var card = level_container_map[level_id]
		var btn = card.get_node("Button")
		var path = "res://data/levels/%s.json" % level_id
		
		if path == selected_level_path:
			btn.modulate = Color(2.0, 2.0, 1.5) # Very bright when selected
		else:
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

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 650) # Increased size
	center.add_child(panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.3, 0.6, 1.0)
	panel_style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24) # Increased separation
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "WORLD EXPEDITION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(title)
	
	# Container for dynamic content
	dynamic_list_container = VBoxContainer.new()
	dynamic_list_container.name = "DynamicList"
	dynamic_list_container.add_theme_constant_override("separation", 32) # Space between Area 1 and Area 2
	dynamic_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(dynamic_list_container)
	
	play_button = Button.new()
	play_button.text = "SELECT MISSION"
	play_button.custom_minimum_size.y = 72 # Larger button
	play_button.disabled = true
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.5, 0.25)
	btn_style.set_corner_radius_all(15)
	play_button.add_theme_stylebox_override("normal", btn_style)
	play_button.add_theme_font_size_override("font_size", 28)
	
	vbox.add_child(play_button)
	play_button.pressed.connect(_on_play_pressed)
	
	if back_button:
		back_button.get_parent().remove_child(back_button)
		$Root.add_child(back_button)
		back_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		back_button.position = Vector2(30, 30)

func _select_level(path: String) -> void:
	selected_level_path = path
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
		if not unlocked:
			play_button.text = "MISSION LOCKED"
			play_button.modulate = Color(1, 0.4, 0.4)
		elif completed:
			play_button.text = "RE-DEPLOY MISSION"
			play_button.modulate = Color(0.6, 1.2, 0.6)
		else:
			play_button.text = "START MISSION"
			play_button.modulate = Color(1, 1, 1)

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

func hide_select() -> void:
	hide()
