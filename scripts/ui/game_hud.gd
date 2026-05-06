extends CanvasLayer

signal start_wave_requested()
signal tower_build_selected(tower_id: String)
signal cancel_build_requested()
signal pause_requested()
signal restart_requested()
signal upgrade_tower_requested()
signal deselect_tower_requested()
signal target_mode_changed(mode: String)
signal main_menu_requested()
signal audio_settings_changed(settings: Dictionary)
signal test_audio_requested(type: String)
signal reset_audio_requested()
signal next_level_requested()
signal back_to_map_requested()

# Top Bar
@onready var gold_label: Label = $Root/TopBar/MarginContainer/HBoxContainer/GoldLabel
@onready var lives_label: Label = $Root/TopBar/MarginContainer/HBoxContainer/LivesLabel
@onready var wave_label: Label = $Root/TopBar/MarginContainer/HBoxContainer/WaveLabel
@onready var status_label: Label = $Root/TopBar/MarginContainer/HBoxContainer/StatusLabel
@onready var next_wave_label: Label = $Root/TopBar/MarginContainer/HBoxContainer/NextWaveLabel
@onready var start_wave_button: Button = $Root/TopBar/MarginContainer/HBoxContainer/StartWaveButton
@onready var settings_button: Button = $Root/TopBar/MarginContainer/HBoxContainer/SettingsButton
@onready var pause_button: Button = $Root/TopBar/MarginContainer/HBoxContainer/PauseButton
@onready var restart_button: Button = $Root/TopBar/MarginContainer/HBoxContainer/RestartButton

# Sidebar Panels
@onready var left_sidebar: PanelContainer = $Root/LeftSidebar
@onready var basic_tower_button: Button = $Root/LeftSidebar/MarginContainer/VBoxContainer/BasicTowerButton
@onready var rapid_tower_button: Button = $Root/LeftSidebar/MarginContainer/VBoxContainer/RapidTowerButton
@onready var cannon_tower_button: Button = $Root/LeftSidebar/MarginContainer/VBoxContainer/CannonTowerButton
@onready var slow_tower_button: Button = $Root/LeftSidebar/MarginContainer/VBoxContainer/SlowTowerButton
@onready var build_status_label: Label = $Root/LeftSidebar/MarginContainer/VBoxContainer/BuildStatusLabel
@onready var cancel_build_button: Button = $Root/LeftSidebar/MarginContainer/VBoxContainer/CancelBuildButton

# Right Sidebar (Tower Info)
@onready var right_sidebar: PanelContainer = $Root/RightSidebar
@onready var tower_name_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerNameLabel
@onready var tower_level_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerLevelLabel
@onready var tower_damage_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerDamageLabel
@onready var tower_range_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerRangeLabel
@onready var tower_fire_rate_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerFireRateLabel
@onready var tower_splash_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerSplashLabel
@onready var tower_slow_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerSlowLabel
@onready var target_mode_option_button: OptionButton = $Root/RightSidebar/MarginContainer/VBoxContainer/TargetModeOptionButton
@onready var tower_upgrade_cost_label: Label = $Root/RightSidebar/MarginContainer/VBoxContainer/TowerUpgradeCostLabel
@onready var upgrade_tower_button: Button = $Root/RightSidebar/MarginContainer/VBoxContainer/UpgradeTowerButton
@onready var deselect_tower_button: Button = $Root/RightSidebar/MarginContainer/VBoxContainer/DeselectTowerButton

# Center Message Panel
@onready var center_message_panel: PanelContainer = $Root/CenterMessagePanel
@onready var center_message_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterMessageLabel
@onready var center_restart_button: Button = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterRestartButton
@onready var center_next_level_button: Button = get_node_or_null("Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterNextLevelButton")
@onready var center_menu_button: Button = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterMenuButton

# Summary Stats
@onready var stats_container: VBoxContainer = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer
@onready var stars_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/StarsLabel
@onready var score_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/ScoreLabel
@onready var lives_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/LivesLabel
@onready var kills_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/KillsLabel
@onready var leaks_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/LeaksLabel
@onready var gold_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/GoldLabel

# Feedback
@onready var temp_message_label: Label = $Root/TemporaryMessageLabel
@onready var dim_overlay: ColorRect = $Root/DimOverlay

# Settings Panel
@onready var settings_panel: PanelContainer = $Root/SettingsPanel
@onready var version_label: Label = $Root/SettingsPanel/MarginContainer/VBoxContainer/VersionLabel
@onready var master_slider: HSlider = $Root/SettingsPanel/MarginContainer/VBoxContainer/GridContainer/MasterSlider
@onready var music_slider: HSlider = $Root/SettingsPanel/MarginContainer/VBoxContainer/GridContainer/MusicSlider
@onready var sfx_slider: HSlider = $Root/SettingsPanel/MarginContainer/VBoxContainer/GridContainer/SfxSlider
@onready var master_mute_check: CheckBox = $Root/SettingsPanel/MarginContainer/VBoxContainer/GridContainer/MasterMuteCheck
@onready var music_mute_check: CheckBox = $Root/SettingsPanel/MarginContainer/VBoxContainer/GridContainer/MusicMuteCheck
@onready var sfx_mute_check: CheckBox = $Root/SettingsPanel/MarginContainer/VBoxContainer/GridContainer/SfxMuteCheck
@onready var test_sfx_button: Button = $Root/SettingsPanel/MarginContainer/VBoxContainer/HBoxContainer/TestSfxButton
@onready var test_music_button: Button = $Root/SettingsPanel/MarginContainer/VBoxContainer/HBoxContainer/TestMusicButton
@onready var reset_audio_button: Button = $Root/SettingsPanel/MarginContainer/VBoxContainer/ResetAudioButton
@onready var close_settings_button: Button = $Root/SettingsPanel/MarginContainer/VBoxContainer/CloseSettingsButton

# Wave Intel Panel
var right_info_column: PanelContainer = null
var right_info_vbox: VBoxContainer = null
var right_info_spacer: Control = null
var wave_intel_panel: PanelContainer = null
var wave_intel_current_label: Label = null
var wave_intel_status_label: Label = null
var wave_intel_section_label: Label = null
var wave_intel_main_summary_label: Label = null
var wave_intel_next_title_label: Label = null
var wave_intel_next_summary_label: Label = null
var wave_intel_threats_title_label: Label = null
var wave_intel_threats_label: Label = null
var wave_intel_suggested_title_label: Label = null
var wave_intel_suggested_label: Label = null

var updating_target_mode_ui := false
var updating_audio_ui := false
var target_modes = ["first", "last", "nearest", "strongest", "weakest"]
var tower_prices := {} # id: cost

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	start_wave_button.pressed.connect(func(): start_wave_requested.emit())
	settings_button.pressed.connect(func(): set_panel_active(settings_panel, true, true))
	pause_button.pressed.connect(func(): pause_requested.emit())
	
	restart_button.pressed.connect(_on_restart_pressed)
	center_restart_button.pressed.connect(_on_restart_pressed)
	
	_setup_wave_intel_panel()
	_setup_tower_detail_in_right_info_column()
	
	# Handle dynamic Next Level button if not in scene
	if center_next_level_button == null:
		center_next_level_button = Button.new()
		center_next_level_button.name = "CenterNextLevelButton"
		center_next_level_button.text = "Next Level"
		# Style it similar to restart button if possible
		var ref_btn = center_restart_button
		if ref_btn:
			for style_type in ["normal", "hover", "pressed", "disabled", "focus"]:
				var sb = ref_btn.get_theme_stylebox(style_type)
				if sb: center_next_level_button.add_theme_stylebox_override(style_type, sb)
		
		# Insert between Restart and Menu
		var container = center_restart_button.get_parent()
		if container:
			container.add_child(center_next_level_button)
			container.move_child(center_next_level_button, center_restart_button.get_index() + 1)
			
	if center_next_level_button:
		center_next_level_button.pressed.connect(func(): next_level_requested.emit())
	
	center_menu_button.pressed.connect(func(): 
		if center_menu_button.text == "Main Menu":
			main_menu_requested.emit()
		else:
			back_to_map_requested.emit()
	)
	
	basic_tower_button.pressed.connect(func(): _on_tower_btn_pressed("basic_tower", basic_tower_button))
	rapid_tower_button.pressed.connect(func(): _on_tower_btn_pressed("rapid_tower", rapid_tower_button))
	cannon_tower_button.pressed.connect(func(): _on_tower_btn_pressed("cannon_tower", cannon_tower_button))
	slow_tower_button.pressed.connect(func(): _on_tower_btn_pressed("slow_tower", slow_tower_button))
	cancel_build_button.pressed.connect(func(): cancel_build_requested.emit())
	upgrade_tower_button.pressed.connect(func(): upgrade_tower_requested.emit())
	deselect_tower_button.pressed.connect(func(): deselect_tower_requested.emit())
	
	target_mode_option_button.clear()
	for mode in target_modes:
		target_mode_option_button.add_item(mode.capitalize())
	target_mode_option_button.item_selected.connect(_on_target_mode_selected)
	
	# Responsive
	get_viewport().size_changed.connect(update_layout_for_viewport)
	update_layout_for_viewport()
	
	# Initialize Audio Settings UI
	master_slider.value_changed.connect(func(_v): _on_audio_ui_changed())
	music_slider.value_changed.connect(func(_v): _on_audio_ui_changed())
	sfx_slider.value_changed.connect(func(_v): _on_audio_ui_changed())
	master_mute_check.toggled.connect(func(_v): _on_audio_ui_changed())
	music_mute_check.toggled.connect(func(_v): _on_audio_ui_changed())
	sfx_mute_check.toggled.connect(func(_v): _on_audio_ui_changed())
	
	test_sfx_button.pressed.connect(func(): test_audio_requested.emit("sfx"))
	test_music_button.pressed.connect(func(): test_audio_requested.emit("music"))
	reset_audio_button.pressed.connect(func(): reset_audio_requested.emit())
	close_settings_button.pressed.connect(func(): set_panel_active(settings_panel, false))
	
	hide_tower_info()
	hide_center_message()
	set_panel_active(settings_panel, false)
	if dim_overlay: dim_overlay.hide()
	
	# STANDARD: Full-screen Root should ignore mouse except for children
	# This prevents invisible containers from blocking map clicks.
	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	set_status("Ready")
	set_build_status("Build: None")

func set_panel_active(panel: Control, active: bool, block_mouse: bool = true) -> void:
	if panel == null: return
	
	panel.visible = active
	if active:
		panel.process_mode = Node.PROCESS_MODE_INHERIT
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if block_mouse else Control.MOUSE_FILTER_IGNORE
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_layout_for_viewport() -> void:
	if not is_inside_tree(): return
	var size = get_viewport().get_visible_rect().size
	var right_width = 240.0 if size.x < 1000 else 260.0
	if size.x < 1000:
		left_sidebar.custom_minimum_size.x = 180
	else:
		left_sidebar.custom_minimum_size.x = 200
	if right_sidebar.get_parent() == right_info_vbox:
		right_sidebar.custom_minimum_size = Vector2(0, 0)
	else:
		right_sidebar.custom_minimum_size.x = right_width
		right_sidebar.custom_minimum_size.y = 0
	if right_info_column:
		_layout_right_info_column(right_width)

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_target_mode_selected(index: int) -> void:
	if updating_target_mode_ui: return
	var mode = target_modes[index]
	target_mode_changed.emit(mode)

func _on_audio_ui_changed() -> void:
	if updating_audio_ui: return
	var settings = {
		"master_volume": master_slider.value,
		"music_volume": music_slider.value,
		"sfx_volume": sfx_slider.value,
		"master_muted": master_mute_check.button_pressed,
		"music_muted": music_mute_check.button_pressed,
		"sfx_muted": sfx_mute_check.button_pressed
	}
	audio_settings_changed.emit(settings)

func set_audio_settings_ui(settings: Dictionary) -> void:
	updating_audio_ui = true
	master_slider.value = settings.get("master_volume", 0.8)
	music_slider.value = settings.get("music_volume", 0.6)
	sfx_slider.value = settings.get("sfx_volume", 0.8)
	master_mute_check.button_pressed = settings.get("master_muted", false)
	music_mute_check.button_pressed = settings.get("music_muted", false)
	sfx_mute_check.button_pressed = settings.get("sfx_muted", false)
	updating_audio_ui = false

func set_gold(value: int) -> void:
	var old_text = gold_label.text
	gold_label.text = "Gold: " + str(value)
	if old_text != gold_label.text:
		pulse_label(gold_label)
	_update_tower_affordability(value)

func _update_tower_affordability(current_gold: int) -> void:
	# Update button appearance based on gold
	for btn_info in [
		{"btn": basic_tower_button, "id": "basic_tower"},
		{"btn": rapid_tower_button, "id": "rapid_tower"},
		{"btn": cannon_tower_button, "id": "cannon_tower"},
		{"btn": slow_tower_button, "id": "slow_tower"}
	]:
		var cost = tower_prices.get(btn_info["id"], 999)
		if current_gold < cost:
			btn_info["btn"].modulate = Color(1, 0.4, 0.4, 0.8)
		else:
			btn_info["btn"].modulate = Color(1, 1, 1, 1)
		
		# Update label with price if possible
		var base_name = btn_info["id"].replace("_tower", "").capitalize()
		btn_info["btn"].text = "%s ($%d)" % [base_name, cost]

func refresh_tower_shop(active_loadout: Array[String]) -> void:
	# If empty, default to everything (safety)
	var final_loadout = active_loadout
	if final_loadout.is_empty():
		final_loadout = ["basic_tower", "rapid_tower", "cannon_tower", "slow_tower"]
	
	basic_tower_button.visible = final_loadout.has("basic_tower")
	rapid_tower_button.visible = final_loadout.has("rapid_tower")
	cannon_tower_button.visible = final_loadout.has("cannon_tower")
	slow_tower_button.visible = final_loadout.has("slow_tower")
	
	# Update layout to collapse gaps
	var container = basic_tower_button.get_parent()
	if container is BoxContainer:
		container.queue_sort()

func set_tower_prices(prices: Dictionary) -> void:
	tower_prices = prices

func set_lives(value: int) -> void:
	var old_text = lives_label.text
	lives_label.text = "Lives: " + str(value)
	if old_text != lives_label.text:
		pulse_label(lives_label, 1.2 if value < 5 else 1.1)
		
		# Feedback for damage: Flash red briefly
		var flash_tween = create_tween()
		lives_label.add_theme_color_override("font_color", Color(1, 0, 0))
		flash_tween.tween_interval(0.4)
		flash_tween.tween_callback(func():
			if value < 5:
				lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			else:
				lives_label.remove_theme_color_override("font_color")
		)

func set_wave(value: int) -> void:
	var old_text = wave_label.text
	wave_label.text = "Wave: " + str(value)
	if old_text != wave_label.text:
		pulse_label(wave_label)

func set_version(text: String) -> void:
	if version_label:
		version_label.text = text

func set_level_name(text: String) -> void:
	# If we had a dedicated LevelLabel, we'd use it. 
	# For now, let's prepend it to the status if it's not empty.
	if status_label:
		status_label.text = text

func set_status(text: String) -> void:
	status_label.text = text

func set_build_status(text: String) -> void:
	build_status_label.text = text
	cancel_build_button.visible = (text != "Build: None")

func set_start_wave_enabled(enabled: bool) -> void:
	if start_wave_button == null: return
	start_wave_button.disabled = not enabled

func update_start_wave_button(next_wave_number: int, total_waves: int, wave_name: String = "") -> void:
	if next_wave_number <= 0 or next_wave_number > total_waves:
		start_wave_button.text = "Cleared"
		start_wave_button.disabled = true
		if next_wave_label:
			next_wave_label.text = "All waves cleared"
		return

	if wave_name != "":
		start_wave_button.text = "Start %d" % next_wave_number
		if next_wave_label:
			next_wave_label.text = "Next: %d/%d - %s" % [next_wave_number, total_waves, wave_name]
	else:
		start_wave_button.text = "Start %d" % next_wave_number
		if next_wave_label:
			next_wave_label.text = "Next: %d/%d" % [next_wave_number, total_waves]

func refresh_start_wave_button(total_waves: int, next_wave_number: int, wave_name: String, wave_running: bool, can_start: bool, level_cleared: bool, locked_label: String = "") -> void:
	if start_wave_button == null:
		return
	
	if total_waves <= 0:
		start_wave_button.text = "No Waves"
		start_wave_button.disabled = true
		if next_wave_label:
			next_wave_label.text = "No waves loaded"
		return
	
	if locked_label != "":
		start_wave_button.text = locked_label
		start_wave_button.disabled = true
		if next_wave_label:
			next_wave_label.text = locked_label
		return
	
	if level_cleared or next_wave_number <= 0 or next_wave_number > total_waves:
		start_wave_button.text = "Cleared"
		start_wave_button.disabled = true
		if next_wave_label:
			next_wave_label.text = "All waves cleared"
		return
	
	if wave_running:
		start_wave_button.text = "In Progress"
		start_wave_button.disabled = true
		if next_wave_label:
			next_wave_label.text = "Wave %d/%d active" % [next_wave_number, total_waves]
		return
	
	start_wave_button.text = "Start %d" % next_wave_number
	start_wave_button.disabled = not can_start
	if next_wave_label:
		if wave_name != "":
			next_wave_label.text = "Next: %d/%d - %s" % [next_wave_number, total_waves, wave_name]
		else:
			next_wave_label.text = "Next: %d/%d" % [next_wave_number, total_waves]

func set_paused(paused: bool) -> void:
	if paused:
		pause_button.text = "Resume"
		set_status("Paused")
		show_center_message("PAUSED", true)
	else:
		pause_button.text = "Pause"
		hide_center_message()

func show_run_summary(summary: Dictionary) -> void:
	enter_end_game_ui_state()
	if dim_overlay: dim_overlay.show()
	
	set_panel_active(center_message_panel, true, true)
	var result_text = summary.get("result", "Victory").to_upper()
	center_message_label.text = result_text
	
	if result_text == "VICTORY":
		center_message_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	else:
		center_message_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		
	stats_container.show()
	center_restart_button.show()
	if center_next_level_button:
		center_next_level_button.visible = (result_text == "VICTORY")
	
	center_menu_button.text = "Back to Map"
	center_menu_button.show()
	
	var stars = summary.get("stars", 0)
	var stars_text = ""
	for i in range(3):
		if i < stars:
			stars_text += "★"
		else:
			stars_text += "☆"
	stars_label.text = stars_text
	
	score_summary_label.text = "Score: " + str(summary.get("score", 0))
	lives_summary_label.text = "Lives: %d / %d" % [summary.get("lives", 0), summary.get("starting_lives", 20)]
	kills_summary_label.text = "Kills: " + str(summary.get("enemies_killed", 0))
	leaks_summary_label.text = "Leaks: " + str(summary.get("enemies_leaked", 0))
	gold_summary_label.text = "Gold: " + str(summary.get("gold_remaining", 0))

func show_tower_info(info: Dictionary) -> void:
	show_tower_info_panel()
	tower_name_label.text = info["name"]
	tower_level_label.text = "Level: " + str(info["level"]) + "/" + str(info["max_level"])
	tower_damage_label.text = "Damage: " + str(info["damage"])
	tower_range_label.text = "Range: " + str(info["range"])
	tower_fire_rate_label.text = "Fire Rate: " + str(info["fire_rate"]) + "s"
	
	if info.get("attack_type") == "splash":
		tower_splash_label.show()
		tower_splash_label.text = "Splash: " + str(info["splash_radius"])
	else:
		tower_splash_label.hide()
		
	if info.get("attack_type") == "slow":
		tower_slow_label.show()
		var slow_pct = int(info.get("slow_percent", 0) * 100)
		var slow_dur = info.get("slow_duration", 0)
		var slow_rad = info.get("slow_radius", 0)
		tower_slow_label.text = "Slow: %d%% (%0.1fs) R:%d" % [slow_pct, slow_dur, slow_rad]
	else:
		tower_slow_label.hide()
	
	updating_target_mode_ui = true
	var current_mode = info.get("target_mode", "first")
	var mode_index = target_modes.find(current_mode)
	if mode_index != -1:
		target_mode_option_button.select(mode_index)
	updating_target_mode_ui = false
	
	if info["can_upgrade"]:
		tower_upgrade_cost_label.text = "Upgrade - %d Gold" % info["upgrade_cost"]
		upgrade_tower_button.disabled = false
		upgrade_tower_button.text = "Upgrade"
	else:
		tower_upgrade_cost_label.text = "Max Level"
		upgrade_tower_button.disabled = true
		upgrade_tower_button.text = "Max Level"

func hide_tower_info() -> void:
	hide_tower_info_panel()

func show_center_message(title: String, show_buttons: bool = true) -> void:
	set_panel_active(center_message_panel, true, true)
	center_message_label.text = title
	stats_container.hide()
	center_restart_button.visible = show_buttons
	if center_next_level_button:
		center_next_level_button.hide()
	
	# If paused, this button should go to Menu, else it's "Back to Map" from summary
	center_menu_button.text = "Main Menu" if get_tree().paused else "Back to Map"
	center_menu_button.visible = show_buttons

func hide_center_message() -> void:
	set_panel_active(center_message_panel, false)

func show_game_over() -> void:
	set_status("Game Over")
	if start_wave_button:
		start_wave_button.text = "Game Over"
		start_wave_button.disabled = true

func show_victory() -> void:
	set_status("Victory!")
	if start_wave_button:
		start_wave_button.text = "Cleared"
		start_wave_button.disabled = true
	if next_wave_label:
		next_wave_label.text = "All waves cleared"

func show_build_panel() -> void:
	set_panel_active(left_sidebar, true, true)

func hide_build_panel() -> void:
	set_panel_active(left_sidebar, false)

func show_tower_info_panel() -> void:
	set_panel_active(right_sidebar, true, true)
	right_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh_right_info_column_visibility()

func hide_tower_info_panel() -> void:
	set_panel_active(right_sidebar, false)
	_refresh_right_info_column_visibility()

func enter_end_game_ui_state() -> void:
	hide_tower_info_panel()
	hide_build_panel()
	
	if start_wave_button:
		start_wave_button.disabled = true
	pause_button.disabled = true
	
	# Clear status to avoid clutter
	set_status("")
	if next_wave_label: next_wave_label.text = ""

func exit_end_game_ui_state() -> void:
	show_build_panel()
	
	pause_button.disabled = false
	if dim_overlay: dim_overlay.hide()
	hide_center_message()

func show_hud() -> void:
	show()

func hide_hud() -> void:
	hide()

func show_temporary_message(text: String, color: Color = Color.WHITE, duration: float = 1.2) -> void:
	if not temp_message_label: return
	
	temp_message_label.text = text
	temp_message_label.modulate = color
	temp_message_label.modulate.a = 0.0
	temp_message_label.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	# Fade in and float up slightly
	var start_pos = Vector2(temp_message_label.position.x, 100)
	temp_message_label.position = start_pos
	
	tween.parallel().tween_property(temp_message_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(temp_message_label, "position:y", 80.0, 0.2)
	
	tween.tween_interval(duration)
	
	tween.parallel().tween_property(temp_message_label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(temp_message_label, "position:y", 60.0, 0.3)
	
	tween.tween_callback(temp_message_label.hide)

func show_screen_flash(color: Color, duration: float = 0.2) -> void:
	if dim_overlay == null: return
	
	var original_color = dim_overlay.color
	var original_visible = dim_overlay.visible
	
	dim_overlay.color = color
	dim_overlay.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(dim_overlay, "modulate:a", 0.0, duration).from(1.0)
	tween.tween_callback(func():
		dim_overlay.visible = original_visible
		dim_overlay.color = original_color
		dim_overlay.modulate.a = 1.0
	)

func pulse_label(label: Control, pulse_scale: float = 1.1) -> void:
	if label == null: return
	
	# Kill existing pulse if any
	if label.has_meta("pulse_tween"):
		var existing = label.get_meta("pulse_tween")
		if is_instance_valid(existing) and existing is Tween and existing.is_running():
			existing.kill()
		label.scale = Vector2.ONE
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	label.pivot_offset = label.size / 2.0
	
	tween.tween_property(label, "scale", Vector2.ONE * pulse_scale, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	label.set_meta("pulse_tween", tween)

func _on_tower_btn_pressed(id: String, btn: Button) -> void:
	var cost = tower_prices.get(id, 999)
	# Check affordability here for feedback
	var gold = 0
	if get_tree().current_scene.game_manager:
		gold = get_tree().current_scene.game_manager.gold
	
	if gold < cost:
		shake_node(btn)
		set_build_status("Not enough gold ($%d)!" % cost)
		return
		
	tower_build_selected.emit(id)

func shake_node(node: Control, strength: float = 10.0) -> void:
	if node == null: return
	var original_pos = node.position
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for i in range(4):
		var offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(node, "position", original_pos + offset, 0.04)
	tween.tween_property(node, "position", original_pos, 0.04)

func _setup_wave_intel_panel() -> void:
	_setup_right_info_column()
	
	wave_intel_panel = PanelContainer.new()
	wave_intel_panel.name = "WaveIntelPanel"
	wave_intel_panel.custom_minimum_size = Vector2(0, 190)
	wave_intel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_intel_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wave_intel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_info_vbox.add_child(wave_intel_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.20, 0.42, 0.66, 0.80)
	style.set_corner_radius_all(8)
	wave_intel_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_intel_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	var title = _create_wave_intel_label("WAVE INTEL", 17, Color(0.72, 0.90, 1.0))
	vbox.add_child(title)
	
	wave_intel_current_label = _create_wave_intel_label("Wave 1 / 1", 15, Color(0.94, 0.98, 1.0))
	vbox.add_child(wave_intel_current_label)
	
	wave_intel_status_label = _create_wave_intel_label("Status: Ready", 13, Color(0.95, 0.78, 0.36))
	vbox.add_child(wave_intel_status_label)
	
	vbox.add_child(_create_wave_intel_separator())
	
	wave_intel_section_label = _create_wave_intel_label("Upcoming", 12, Color(0.55, 0.72, 0.88))
	vbox.add_child(wave_intel_section_label)
	
	wave_intel_main_summary_label = _create_wave_intel_label("---", 15, Color(0.98, 1.0, 1.0))
	vbox.add_child(wave_intel_main_summary_label)
	
	wave_intel_next_title_label = _create_wave_intel_label("Next", 12, Color(0.55, 0.72, 0.88))
	vbox.add_child(wave_intel_next_title_label)
	
	wave_intel_next_summary_label = _create_wave_intel_label("---", 13, Color(0.78, 0.84, 0.90))
	vbox.add_child(wave_intel_next_summary_label)
	
	vbox.add_child(_create_wave_intel_separator())
	
	wave_intel_threats_title_label = _create_wave_intel_label("Threats", 12, Color(0.55, 0.72, 0.88))
	vbox.add_child(wave_intel_threats_title_label)
	
	wave_intel_threats_label = _create_wave_intel_label("---", 13, Color(1.0, 0.62, 0.42))
	vbox.add_child(wave_intel_threats_label)
	
	wave_intel_suggested_title_label = _create_wave_intel_label("Suggested Towers", 12, Color(0.55, 0.72, 0.88))
	vbox.add_child(wave_intel_suggested_title_label)
	
	wave_intel_suggested_label = _create_wave_intel_label("---", 13, Color(0.48, 0.86, 1.0))
	vbox.add_child(wave_intel_suggested_label)
	
	_set_next_wave_intel_visible(false)
	wave_intel_panel.visible = false

	right_info_spacer = Control.new()
	right_info_spacer.name = "RightInfoSpacer"
	right_info_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_info_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_info_vbox.add_child(right_info_spacer)

func _setup_tower_detail_in_right_info_column() -> void:
	_setup_right_info_column()
	if right_sidebar == null or right_info_vbox == null:
		return
	
	if right_sidebar.get_parent() != right_info_vbox:
		var old_parent = right_sidebar.get_parent()
		if old_parent:
			old_parent.remove_child(right_sidebar)
		right_info_vbox.add_child(right_sidebar)
	
	right_sidebar.name = "TowerDetailPanel"
	right_sidebar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	right_sidebar.offset_left = 0.0
	right_sidebar.offset_top = 0.0
	right_sidebar.offset_right = 0.0
	right_sidebar.offset_bottom = 0.0
	right_sidebar.custom_minimum_size = Vector2(0, 420)
	right_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.22, 0.36, 0.58, 0.85)
	style.set_corner_radius_all(8)
	right_sidebar.add_theme_stylebox_override("panel", style)
	
	var detail_margin = right_sidebar.get_node_or_null("MarginContainer")
	if detail_margin is MarginContainer:
		detail_margin.add_theme_constant_override("margin_left", 14)
		detail_margin.add_theme_constant_override("margin_right", 14)
		detail_margin.add_theme_constant_override("margin_top", 14)
		detail_margin.add_theme_constant_override("margin_bottom", 14)
		detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		if detail_margin.get_parent() == right_sidebar:
			right_sidebar.remove_child(detail_margin)
			var scroll = ScrollContainer.new()
			scroll.name = "TowerDetailScroll"
			scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.mouse_filter = Control.MOUSE_FILTER_PASS
			right_sidebar.add_child(scroll)
			scroll.add_child(detail_margin)
	
	if right_info_spacer and right_info_spacer.get_parent() == right_info_vbox:
		right_info_vbox.move_child(right_sidebar, max(0, right_info_spacer.get_index()))
	
	set_panel_active(right_sidebar, false)
	_refresh_right_info_column_visibility()

func _setup_right_info_column() -> void:
	if right_info_column != null:
		return
	
	right_info_column = PanelContainer.new()
	right_info_column.name = "RightInfoColumn"
	right_info_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_info_column.size_flags_horizontal = Control.SIZE_FILL
	$Root.add_child(right_info_column)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 0.72)
	style.set_border_width(SIDE_LEFT, 1)
	style.border_color = Color(0.16, 0.25, 0.36, 0.80)
	right_info_column.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	right_info_column.add_child(margin)
	
	right_info_vbox = VBoxContainer.new()
	right_info_vbox.name = "VBoxContainer"
	right_info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_info_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(right_info_vbox)
	
	_layout_right_info_column()

func _layout_right_info_column(width: float = 260.0) -> void:
	if right_info_column == null:
		return
	
	right_info_column.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_info_column.offset_left = -width
	right_info_column.offset_top = 60.0
	right_info_column.offset_right = 0.0
	right_info_column.offset_bottom = 0.0
	right_info_column.custom_minimum_size.x = width

func _create_wave_intel_label(text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _create_wave_intel_separator() -> ColorRect:
	var separator = ColorRect.new()
	separator.custom_minimum_size.y = 1
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.color = Color(0.30, 0.48, 0.64, 0.35)
	return separator

func _set_next_wave_intel_visible(visible: bool) -> void:
	if wave_intel_next_title_label:
		wave_intel_next_title_label.visible = visible
	if wave_intel_next_summary_label:
		wave_intel_next_summary_label.visible = visible

func clear_wave_intel() -> void:
	if wave_intel_panel == null: return
	
	wave_intel_panel.visible = false
	_refresh_right_info_column_visibility()
	if wave_intel_current_label:
		wave_intel_current_label.text = ""
	if wave_intel_status_label:
		wave_intel_status_label.text = ""
	if wave_intel_section_label:
		wave_intel_section_label.text = ""
	if wave_intel_main_summary_label:
		wave_intel_main_summary_label.text = ""
	if wave_intel_threats_label:
		wave_intel_threats_label.text = ""
	if wave_intel_suggested_label:
		wave_intel_suggested_label.text = ""
	_set_next_wave_intel_visible(false)

func set_wave_intel_visible(visible: bool) -> void:
	if wave_intel_panel == null:
		return
	wave_intel_panel.visible = visible
	_refresh_right_info_column_visibility()

func refresh_wave_intel(level_id: int, previews: Array[Dictionary], current_idx: int, total_waves: int, is_running: bool) -> void:
	if wave_intel_panel == null: return
	
	if level_id <= 0 or previews.is_empty():
		clear_wave_intel()
		return
	
	var display_wave_idx = current_idx
	if is_running:
		display_wave_idx = current_idx - 1
	
	if display_wave_idx < 0 or display_wave_idx >= previews.size():
		clear_wave_intel()
		return
	
	var wave_total = max(total_waves, previews.size())
	var current_preview = previews[display_wave_idx]
	var status_text = "In Progress" if is_running else "Ready"
	
	wave_intel_current_label.text = "Wave %d / %d" % [display_wave_idx + 1, wave_total]
	wave_intel_status_label.text = "Status: " + status_text
	wave_intel_status_label.add_theme_color_override("font_color", Color(0.38, 0.92, 0.62) if is_running else Color(0.95, 0.78, 0.36))
	wave_intel_section_label.text = "Current" if is_running else "Upcoming"
	wave_intel_main_summary_label.text = _format_wave_preview_summary(current_preview)
	wave_intel_threats_label.text = _format_wave_intel_list(current_preview.get("traits", []), "None")
	wave_intel_suggested_label.text = _format_wave_intel_list(current_preview.get("recommended_roles", []), "None")
	
	if is_running:
		var next_idx = display_wave_idx + 1
		if next_idx < previews.size():
			wave_intel_next_summary_label.text = _format_wave_preview_summary(previews[next_idx])
			_set_next_wave_intel_visible(true)
		else:
			_set_next_wave_intel_visible(false)
	else:
		_set_next_wave_intel_visible(false)
	
	wave_intel_panel.visible = true
	_refresh_right_info_column_visibility()

func _refresh_right_info_column_visibility() -> void:
	if right_info_column == null:
		return
	
	var wave_visible = wave_intel_panel != null and wave_intel_panel.visible
	var tower_visible = right_sidebar != null and right_sidebar.visible
	right_info_column.visible = wave_visible or tower_visible
	right_info_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if right_info_spacer:
		right_info_spacer.visible = not tower_visible
	
	if wave_intel_panel:
		wave_intel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right_sidebar:
		right_sidebar.mouse_filter = Control.MOUSE_FILTER_STOP if tower_visible else Control.MOUSE_FILTER_IGNORE

func _format_wave_preview_summary(preview: Dictionary) -> String:
	var counts = preview.get("enemy_counts", {})
	if counts.is_empty():
		return "Malformed Wave"
	
	var parts = []
	var type_order = ["Normal", "Fast", "Heavy", "Swarm", "Air"]
	for type_name in type_order:
		if counts.has(type_name):
			parts.append("%s x%d" % [type_name, int(counts[type_name])])
	for type_name in counts.keys():
		if not type_order.has(str(type_name)):
			parts.append("%s x%d" % [str(type_name), int(counts[type_name])])
	return ", ".join(parts)

func _format_wave_intel_list(values: Array, fallback: String) -> String:
	if values.is_empty():
		return fallback
	var parts = []
	for value in values:
		parts.append(str(value))
	return ", ".join(parts)
