extends CanvasLayer

signal add_gold_requested(amount: int)
signal start_next_wave_requested()
signal kill_all_enemies_requested()
signal clear_projectiles_requested()
signal trigger_victory_requested()
signal trigger_game_over_requested()
signal restart_requested()
signal god_mode_toggled(enabled: bool)
signal hard_audio_test_requested()
signal test_sfx_requested()
signal test_music_requested()
signal test_sfx_master_requested()
signal auto_verify_current_requested()
signal solve_current_level_requested()
signal auto_verify_level_7_requested()
signal auto_verify_all_requested()
signal verify_current_board_requested()
signal auto_play_current_board_requested()
signal auto_solve_current_requested()
signal auto_solve_level_7_requested()
signal auto_play_last_plan_requested()
signal solve_all_levels_requested()
signal auto_clear_current_requested()
signal auto_clear_level_7_requested()
signal generate_balance_report_requested()
signal apply_verified_starting_gold_requested()

@onready var panel: PanelContainer = $Root/Panel
@onready var info_label: Label = $Root/Panel/MarginContainer/Scroll/Content/InfoLabel
@onready var god_mode_check: CheckBox = $Root/Panel/MarginContainer/Scroll/Content/GodModeCheck
@onready var status_label: Label = Label.new()

var game_manager: Node = null
var wave_manager: Node = null
var tower_container: Node2D = null
var projectile_container: Node2D = null
var advanced_content: VBoxContainer = null
var advanced_toggle: Button = null

signal level_load_requested(path: String)

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")
	tower_container = get_tree().current_scene.get_node_or_null("WorldRoot/TowerContainer")
	projectile_container = get_tree().current_scene.get_node_or_null("WorldRoot/ProjectileContainer")
	
	_setup_clean_auto_clear_layout()
	_connect_buttons()
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_F9:
				verify_current_board_requested.emit()
			KEY_F8:
				if event.shift_pressed:
					auto_solve_level_7_requested.emit()
				else:
					auto_solve_current_requested.emit()
			KEY_F10:
				solve_all_levels_requested.emit()

func _create_debug_button(text: String, callable: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(callable)
	return btn

func _add_level_debug_buttons(parent: Control) -> void:
	var label = Label.new()
	label.text = "LEVELS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	
	var grid = GridContainer.new()
	grid.columns = 3
	parent.add_child(grid)
	
	for i in range(1, 4):
		var btn = Button.new()
		btn.text = "L%d" % i
		btn.custom_minimum_size = Vector2(40, 30)
		btn.pressed.connect(func(): level_load_requested.emit("res://data/levels/level_0%d.json" % i))
		grid.add_child(btn)
	
	var sep = HSeparator.new()
	parent.add_child(sep)

func _connect_buttons() -> void:
	_find_button("Gold100").pressed.connect(func(): add_gold_requested.emit(100))
	_find_button("Gold500").pressed.connect(func(): add_gold_requested.emit(500))
	_find_button("StartWave").pressed.connect(func(): start_next_wave_requested.emit())
	_find_button("KillAll").pressed.connect(func(): kill_all_enemies_requested.emit())
	_find_button("ClearProj").pressed.connect(func(): clear_projectiles_requested.emit())
	_find_button("Victory").pressed.connect(func(): trigger_victory_requested.emit())
	_find_button("GameOver").pressed.connect(func(): trigger_game_over_requested.emit())
	_find_button("Restart").pressed.connect(func(): restart_requested.emit())
	god_mode_check.toggled.connect(func(v): god_mode_toggled.emit(v))
	_find_button("HardAudioTest").pressed.connect(func(): hard_audio_test_requested.emit())
	_find_button("TestSfx").pressed.connect(func(): test_sfx_requested.emit())
	_find_button("TestMusic").pressed.connect(func(): test_music_requested.emit())
	_find_button("TestSfxMaster").pressed.connect(func(): test_sfx_master_requested.emit())

func _find_button(node_name: String) -> Button:
	return $Root/Panel/MarginContainer/Scroll/Content.find_child(node_name, true, false) as Button

func _setup_clean_auto_clear_layout() -> void:
	var root = $Root/Panel/MarginContainer/Scroll/Content
	var old_controls: Array[Node] = []
	for child in root.get_children():
		if child.name not in ["Title", "HSeparator", "InfoLabel", "HSeparator2"]:
			old_controls.append(child)
			root.remove_child(child)

	var title := root.get_node_or_null("Title")
	if title:
		title.text = "AUTO CLEAR"

	status_label.text = "AUTO CLEAR STATUS\n- State: Idle\n- Level: -\n- Current Gold Test: -\n- Best Result So Far: -\n- Final Result: -"
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)
	root.add_child(HSeparator.new())

	var primary_vbox := VBoxContainer.new()
	primary_vbox.name = "AutoClearPrimaryActions"
	primary_vbox.add_theme_constant_override("separation", 6)
	root.add_child(primary_vbox)

	primary_vbox.add_child(_create_debug_button("AUTO CLEAR CURRENT LEVEL", func(): auto_clear_current_requested.emit()))
	primary_vbox.add_child(_create_debug_button("AUTO CLEAR LEVEL 7", func(): auto_clear_level_7_requested.emit()))
	primary_vbox.add_child(_create_debug_button("AUTO PLAY LAST FOUND PLAN", func(): auto_play_last_plan_requested.emit()))
	primary_vbox.add_child(_create_debug_button("GENERATE BALANCE REPORT", func(): generate_balance_report_requested.emit()))
	
	var apply_btn = _create_debug_button("APPLY INITIAL SETUP GOLD", func(): apply_verified_starting_gold_requested.emit())
	apply_btn.name = "ApplySetupGoldBtn"
	apply_btn.disabled = true
	primary_vbox.add_child(apply_btn)
	
	root.add_child(HSeparator.new())

	advanced_toggle = Button.new()
	advanced_toggle.text = "ADVANCED DEBUG ▸"
	advanced_toggle.toggle_mode = true
	advanced_toggle.custom_minimum_size = Vector2(0, 30)
	advanced_toggle.toggled.connect(_set_advanced_visible)
	root.add_child(advanced_toggle)

	advanced_content = VBoxContainer.new()
	advanced_content.name = "AdvancedDebug"
	advanced_content.visible = false
	advanced_content.add_theme_constant_override("separation", 6)
	root.add_child(advanced_content)

	for child in old_controls:
		advanced_content.add_child(child)

	_add_verifier_buttons(advanced_content)
	_add_level_debug_buttons(advanced_content)

func _set_advanced_visible(is_open: bool) -> void:
	if advanced_content:
		advanced_content.visible = is_open
	if advanced_toggle:
		advanced_toggle.text = "ADVANCED DEBUG ▾" if is_open else "ADVANCED DEBUG ▸"

func _add_verifier_buttons(parent: Control) -> void:
	var verifier_vbox = VBoxContainer.new()
	parent.add_child(verifier_vbox)
	
	var label = Label.new()
	label.text = "VERIFICATION"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	verifier_vbox.add_child(label)
	
	var btn_verify = _create_debug_button("VERIFY CURRENT BOARD (F9)", func(): verify_current_board_requested.emit())
	var btn_solve = _create_debug_button("AUTO SOLVE CURRENT LEVEL (F8)", func(): auto_solve_current_requested.emit())
	var btn_solve7 = _create_debug_button("AUTO SOLVE LEVEL 7 (Shift+F8)", func(): auto_solve_level_7_requested.emit())
	var btn_play_last = _create_debug_button("AUTO PLAY LAST PLAN", func(): auto_play_last_plan_requested.emit())
	var btn_solve_all = _create_debug_button("SOLVE ALL LEVELS (F10)", func(): solve_all_levels_requested.emit())
	
	verifier_vbox.add_child(btn_verify)
	verifier_vbox.add_child(btn_solve)
	verifier_vbox.add_child(btn_solve7)
	verifier_vbox.add_child(btn_play_last)
	verifier_vbox.add_child(btn_solve_all)
	
	var btn_current_solve = Button.new()
	btn_current_solve.text = "SOLVE FROM SCRATCH"
	btn_current_solve.pressed.connect(func(): solve_current_level_requested.emit())
	parent.add_child(btn_current_solve)
	
	var btn_l7 = Button.new()
	btn_l7.text = "SOLVE LEVEL 7"
	btn_l7.pressed.connect(func(): auto_verify_level_7_requested.emit())
	parent.add_child(btn_l7)
	
	var btn_all = Button.new()
	btn_all.text = "VERIFY ALL PLANS"
	btn_all.pressed.connect(func(): auto_verify_all_requested.emit())
	parent.add_child(btn_all)
	
	var sep = HSeparator.new()
	parent.add_child(sep)

func update_verifier_status(msg: String, is_error: bool = false) -> void:
	if msg.begins_with("AUTO CLEAR STATUS"):
		status_label.text = msg
	else:
		status_label.text = "AUTO CLEAR STATUS\n- State: %s" % msg
	if is_error:
		status_label.add_theme_color_override("font_color", Color.RED)
	elif "SUCCESS" in msg or "FOUND" in msg or "Verified" in msg:
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.add_theme_color_override("font_color", Color.YELLOW)

func update_auto_clear_status(status: Dictionary) -> void:
	var lines: Array[String] = ["AUTO CLEAR STATUS"]
	lines.append("- State: %s" % str(status.get("state", "Idle")))
	lines.append("- Level: %s" % str(status.get("level", "-")))
	lines.append("- Current Gold Test: %s" % str(status.get("gold", "-")))
	lines.append("- Candidate: %s" % str(status.get("candidate", "-")))
	lines.append("- Best Result So Far: %s" % str(status.get("best", "-")))
	lines.append("- Final Result: %s" % str(status.get("result", "-")))
	if status.has("recommended_gold"):
		lines.append("- Recommended Gold: %s" % str(status.get("recommended_gold")))
		
		var apply_btn = _find_button("ApplySetupGoldBtn")
		if apply_btn:
			var gold = int(status.get("recommended_gold", 0))
			var is_perfect = "Perfect" in str(status.get("state", ""))
			apply_btn.disabled = not (gold > 0 and is_perfect)
			
	if status.has("wave"):
		lines.append("- Wave: %s" % str(status.get("wave")))
	if status.has("lives"):
		lines.append("- Lives: %s" % str(status.get("lives")))
	if status.has("game_gold"):
		lines.append("- Gold: %s" % str(status.get("game_gold")))
	if status.has("last_action"):
		lines.append("- Last Action: %s" % str(status.get("last_action")))
	update_verifier_status("\n".join(lines), bool(status.get("is_error", false)))

func _update_layout() -> void:
	if not panel: return
	var viewport_size : Vector2 = get_viewport().get_visible_rect().size
	var panel_width : float = 240.0
	var margin : float = 16.0
	var top : float = 72.0
	var max_h : float = max(240.0, viewport_size.y - top - margin)

	panel.custom_minimum_size = Vector2(panel_width, min(560.0, max_h))
	panel.size = panel.custom_minimum_size
	panel.position = Vector2(
		viewport_size.x - panel_width - margin,
		top
	)

func _process(_delta: float) -> void:
	if not visible: return
	_update_info()

func _update_info() -> void:
	var info = ""
	info += "FPS: %d\n" % Engine.get_frames_per_second()
	if game_manager:
		info += "Gold: %d\n" % game_manager.gold
		info += "Lives: %d\n" % game_manager.lives
		info += "Wave: %d\n" % game_manager.current_wave
	if wave_manager:
		info += "Active Enemies: %d\n" % get_tree().get_nodes_in_group("enemies").size()
	if tower_container:
		info += "Towers: %d\n" % tower_container.get_child_count()
	if projectile_container:
		info += "Projectiles: %d\n" % projectile_container.get_child_count()
	info_label.text = info

func show_panel() -> void:
	visible = true
	layer = 500
	
	var root := get_node_or_null("Root")
	if root:
		root.visible = true
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	var panel_node := get_node_or_null("Root/Panel")
	if panel_node:
		panel_node.visible = true
		panel_node.mouse_filter = Control.MOUSE_FILTER_STOP
		
	_update_layout()
	refresh()
	if OS.is_debug_build(): print("[DebugPanel] show_panel")

func hide_panel() -> void:
	visible = false
	if OS.is_debug_build(): print("[DebugPanel] hide_panel")

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func refresh() -> void:
	# Placeholder for future refresh logic
	pass

func is_active() -> bool:
	return visible
