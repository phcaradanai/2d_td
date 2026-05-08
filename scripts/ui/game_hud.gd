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
@onready var gold_label: Label = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/GoldLabel
@onready var lives_label: Label = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/LivesLabel
@onready var wave_label: Label = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/WaveLabel
@onready var status_label: Label = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/StatusLabel
@onready var next_wave_label: Label = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/NextWaveLabel
@onready var start_wave_button: Button = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/StartWaveButton
@onready var settings_button: Button = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/SettingsButton
@onready var pause_button: Button = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/PauseButton
@onready var restart_button: Button = $Root/ScreenLayout/TopBar/MarginContainer/HBoxContainer/RestartButton

# Sidebar Panels
@onready var left_sidebar: PanelContainer = $Root/ScreenLayout/MainContent/LeftSidebar
@onready var basic_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/BasicTowerButton
@onready var rapid_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/RapidTowerButton
@onready var cannon_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/CannonTowerButton
@onready var slow_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/SlowTowerButton
@onready var sniper_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/SniperTowerButton
@onready var lightning_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/LightningTowerButton
@onready var sawblade_tower_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/SawbladeTowerButton
@onready var build_status_label: Label = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/BuildStatusLabel
@onready var cancel_build_button: Button = $Root/ScreenLayout/MainContent/LeftSidebar/MarginContainer/VBoxContainer/CancelBuildButton

# Right Sidebar (Tower Info)
@onready var right_sidebar_container: VBoxContainer = $Root/ScreenLayout/MainContent/RightSidebarContainer
@onready var right_sidebar: PanelContainer = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar
@onready var tower_name_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerNameLabel
@onready var tower_level_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerLevelLabel
@onready var tower_damage_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerDamageLabel
@onready var tower_range_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerRangeLabel
@onready var tower_fire_rate_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerFireRateLabel
@onready var tower_splash_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerSplashLabel
@onready var tower_slow_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerSlowLabel
@onready var target_mode_option_button: OptionButton = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TargetModeOptionButton
@onready var tower_upgrade_cost_label: Label = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/TowerUpgradeCostLabel
@onready var tower_target_label: Label = null # Will be added dynamically or linked
@onready var upgrade_tower_button: Button = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/UpgradeTowerButton
@onready var deselect_tower_button: Button = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/DeselectTowerButton

# Center Message Panel
@onready var center_message_panel: PanelContainer = $Root/CenterMessagePanel
@onready var center_message_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterMessageLabel
@onready var center_restart_button: Button = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterRestartButton
@onready var center_next_level_button: Button = get_node_or_null("Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterNextLevelButton")
@onready var center_menu_button: Button = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/CenterMenuButton

# Summary Stats
@onready var stats_container: VBoxContainer = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer
@onready var stars_container: HBoxContainer = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/StarsContainer
@onready var score_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/ScoreLabel
@onready var lives_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/LivesLabel
@onready var kills_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/KillsLabel
@onready var leaks_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/LeaksLabel
@onready var gold_summary_label: Label = $Root/CenterMessagePanel/MarginContainer/VBoxContainer/StatsContainer/GoldLabel

# Feedback
@onready var temp_message_label: Label = $Root/TemporaryMessageLabel
enum HUDState { GAMEPLAY, PAUSED, RESULT }
var current_ui_state: HUDState = HUDState.GAMEPLAY

@onready var root: Control = $Root
@onready var screen_layout: VBoxContainer = $Root/ScreenLayout
@onready var playfield_area: Control = $Root/ScreenLayout/MainContent/PlayfieldArea
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
var wave_intel_panel: PanelContainer = null
var wave_intel_current_label: Label = null
var wave_intel_status_label: Label = null
var wave_intel_section_label: Label = null
var wave_intel_name_label: Label = null
var wave_intel_reward_label: Label = null
var wave_intel_main_summary_label: RichTextLabel = null
var wave_intel_next_title_label: Label = null
var wave_intel_next_summary_label: RichTextLabel = null
var wave_intel_threats_title_label: Label = null
var wave_intel_threats_label: RichTextLabel = null
var wave_intel_suggested_title_label: Label = null
var wave_intel_suggested_label: RichTextLabel = null
var wave_intel_warnings_label: Label = null
var no_selection_panel: PanelContainer = null

var enemy_role_tooltips = {
	"Fast": "reaches base quickly",
	"Heavy": "high health",
	"Swarm": "many weak units",
	"Shieldbearer": "protects or absorbs damage",
	"Healer": "restores allies",
	"Cloaked": "lower targeting priority while other visible targets are present",
	"Air": "requires anti-air-capable towers",
	"Armored Flyer": "needs high damage anti-air",
	"Hunter": "pressures hero",
	"Disruptor": "late-game special threat",
	"Normal": "Standard enemy"
}

var updating_target_mode_ui := false
var updating_audio_ui := false
var target_modes = ["first", "last", "nearest", "strongest", "weakest", "fastest", "air_first", "support_first", "shield_first"]
var target_mode_labels = {
	"first": "First",
	"last": "Last",
	"nearest": "Closest",
	"strongest": "Strongest",
	"weakest": "Weakest",
	"fastest": "Fastest",
	"air_first": "Air First",
	"support_first": "Support First",
	"shield_first": "Shield First"
}

var tower_descriptions = {
	"basic_tower": "Reliable single-target kinetic damage.",
	"rapid_tower": "High fire rate, effective against swarms and flyers.",
	"cannon_tower": "Heavy explosive shells dealing splash damage.",
	"slow_tower": "Frost field that reduces enemy movement speed.",
	"sniper_tower": "Extreme range precision for high-priority targets.",
	"lightning_tower": "Energy arcs that jump between multiple hostiles.",
	"sawblade_tower": "Short-range aura that causes bleeding debuffs."
}

var tower_prices := {} # id: cost

const RESULT_PANEL_SCENE = preload("res://scenes/ui/ResultPanel.tscn")
var result_panel: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	start_wave_button.pressed.connect(func(): start_wave_requested.emit())
	settings_button.pressed.connect(func(): set_panel_active(settings_panel, true, true))
	pause_button.pressed.connect(func(): pause_requested.emit())
	
	restart_button.pressed.connect(_on_restart_pressed)
	center_restart_button.pressed.connect(_on_restart_pressed)
	
	_setup_right_sidebar_layout()
	
	# Instantiate Result Panel
	result_panel = RESULT_PANEL_SCENE.instantiate()
	$Root.add_child(result_panel)
	result_panel.visible = false
	result_panel.retry_pressed.connect(_on_restart_pressed)
	result_panel.next_level_pressed.connect(func(): next_level_requested.emit())
	result_panel.level_select_pressed.connect(func(): back_to_map_requested.emit())
	
	# Apply theme to result panel
	var theme_mgr = load("res://scripts/ui/ui_theme_manager.gd").new()
	theme_mgr.apply_theme(result_panel)

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
	sniper_tower_button.pressed.connect(func(): _on_tower_btn_pressed("sniper_tower", sniper_tower_button))
	lightning_tower_button.pressed.connect(func(): _on_tower_btn_pressed("lightning_tower", lightning_tower_button))
	sawblade_tower_button.pressed.connect(func(): _on_tower_btn_pressed("sawblade_tower", sawblade_tower_button))
	cancel_build_button.pressed.connect(func(): cancel_build_requested.emit())
	upgrade_tower_button.pressed.connect(func(): upgrade_tower_requested.emit())
	deselect_tower_button.pressed.connect(func(): deselect_tower_requested.emit())
	
	target_mode_option_button.clear()
	for mode in target_modes:
		target_mode_option_button.add_item(target_mode_labels.get(mode, mode.capitalize()))
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
	if dim_overlay: 
		dim_overlay.hide()
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# STANDARD: Full-screen Root should ignore mouse except for children
	# This prevents invisible containers from blocking map clicks.
	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	set_status("Ready")
	set_build_status("Build: None")
	
	# Top Bar Final Polish
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Gold
	lives_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0)) # Core integrity (Cyan)
	wave_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	next_wave_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# Align top bar spacing
	var top_hbox = gold_label.get_parent()
	if top_hbox is HBoxContainer:
		top_hbox.add_theme_constant_override("separation", 24)

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
	var view_size = get_viewport().get_visible_rect().size
	
	if left_sidebar:
		if view_size.x < 1200:
			left_sidebar.custom_minimum_size.x = 180
		else:
			left_sidebar.custom_minimum_size.x = 210
			
	if right_sidebar_container:
		if view_size.x < 1200:
			right_sidebar_container.custom_minimum_size.x = 220
		else:
			right_sidebar_container.custom_minimum_size.x = 240

	if OS.is_debug_build():
		print("[HUD_LAYOUT] screen_size=", view_size, " playfield=", get_playfield_rect())

func get_playfield_rect() -> Rect2:
	if playfield_area and playfield_area.is_inside_tree():
		var rect = playfield_area.get_global_rect()
		if rect.size.x > 100: # Sanity check that it's laid out
			return rect
	
	# Fallback if HUD not ready or zero-sized
	var view_size = get_viewport().get_visible_rect().size
	var left_w = 180
	if left_sidebar and left_sidebar.custom_minimum_size.x > 0:
		left_w = left_sidebar.custom_minimum_size.x
		
	var right_w = 240
	if right_sidebar_container and right_sidebar_container.custom_minimum_size.x > 0:
		right_w = right_sidebar_container.custom_minimum_size.x
		
	return Rect2(left_w, 60, view_size.x - left_w - right_w, view_size.y - 60)

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
	gold_label.text = "CREDITS: " + str(value)
	if old_text != gold_label.text:
		pulse_label(gold_label)
	_update_tower_affordability(value)

func _update_tower_affordability(current_gold: int) -> void:
	# Update button appearance based on gold
	for btn_info in [
		{"btn": basic_tower_button, "id": "basic_tower"},
		{"btn": rapid_tower_button, "id": "rapid_tower"},
		{"btn": cannon_tower_button, "id": "cannon_tower"},
		{"btn": slow_tower_button, "id": "slow_tower"},
		{"btn": sniper_tower_button, "id": "sniper_tower"},
		{"btn": lightning_tower_button, "id": "lightning_tower"},
		{"btn": sawblade_tower_button, "id": "sawblade_tower"}
	]:
		var cost = tower_prices.get(btn_info["id"], 999)
		if current_gold < cost:
			btn_info["btn"].modulate = Color(1, 0.4, 0.4, 0.8)
		else:
			btn_info["btn"].modulate = Color(1, 1, 1, 1)
		
		# Update label with price if possible
		var base_name = btn_info["id"].replace("_tower", "").capitalize()
		btn_info["btn"].text = "%s ($%d)" % [base_name, cost]
		
		# Enhanced Tooltip
		var desc = tower_descriptions.get(btn_info["id"], "Defensive structure.")
		var targets = "Land Only"
		var attack = "Single"
		
		match btn_info["id"]:
			"basic_tower": 
				attack = "Single"
			"rapid_tower": 
				targets = "Land & Air"
				attack = "Rapid Single"
			"cannon_tower": 
				attack = "Splash Area"
			"slow_tower": 
				attack = "Area Slow"
			"sniper_tower": 
				targets = "Land & Air"
				attack = "Heavy Single"
			"lightning_tower": 
				targets = "Land & Air"
				attack = "Chain Jump"
			"sawblade_tower": 
				attack = "Close Aura"
		
		btn_info["btn"].tooltip_text = "%s\n\nType: %s\nTargets: %s\nCost: %d Credits" % [desc, attack, targets, cost]

func refresh_tower_shop(active_loadout: Array[String]) -> void:
	# If empty, default to everything (safety)
	var final_loadout = active_loadout
	if final_loadout.is_empty():
		final_loadout = ["basic_tower", "rapid_tower", "cannon_tower", "slow_tower", "sniper_tower", "lightning_tower", "sawblade_tower"]
	
	basic_tower_button.visible = final_loadout.has("basic_tower")
	rapid_tower_button.visible = final_loadout.has("rapid_tower")
	cannon_tower_button.visible = final_loadout.has("cannon_tower")
	slow_tower_button.visible = final_loadout.has("slow_tower")
	sniper_tower_button.visible = final_loadout.has("sniper_tower")
	lightning_tower_button.visible = final_loadout.has("lightning_tower")
	sawblade_tower_button.visible = final_loadout.has("sawblade_tower")
	
	# Update layout to collapse gaps
	var container = basic_tower_button.get_parent()
	if container is BoxContainer:
		container.queue_sort()

func set_tower_prices(prices: Dictionary) -> void:
	tower_prices = prices

func set_lives(value: int) -> void:
	var old_text = lives_label.text
	lives_label.text = "CORE: " + str(value)
	lives_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0) if value >= 5 else Color(1, 0.3, 0.3))
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
	if status_label:
		status_label.text = text
		status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))

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
		current_ui_state = HUDState.PAUSED
		pause_button.text = "Resume"
		set_status("Paused")
		show_center_message("PAUSED", true)
		if dim_overlay:
			dim_overlay.show()
			dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		current_ui_state = HUDState.GAMEPLAY
		pause_button.text = "Pause"
		hide_center_message()
		if dim_overlay:
			dim_overlay.hide()
			dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_run_summary(summary: Dictionary, improvements: Dictionary = {}, rank: int = -1) -> void:
	enter_result_mode(summary, improvements, rank)

func enter_gameplay_mode() -> void:
	current_ui_state = HUDState.GAMEPLAY
	if OS.is_debug_build(): print("[UI_STATE] Enter GAMEPLAY")
	
	if screen_layout: screen_layout.show()
	if dim_overlay:
		dim_overlay.hide()
		dim_overlay.color = Color(0, 0, 0, 0.4) # Neutral dark translucent
		dim_overlay.modulate.a = 1.0
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	hide_center_message()
	if result_panel: result_panel.hide_result()
	
	pause_button.disabled = false
	if start_wave_button: start_wave_button.disabled = false

func enter_result_overlay() -> void:
	current_ui_state = HUDState.RESULT
	if OS.is_debug_build(): print("[UI_STATE] Enter RESULT")
	
	# Hide gameplay HUD
	if OS.is_debug_build(): print("[UI_STATE] Hide gameplay HUD")
	if screen_layout: screen_layout.hide()
	
	# Block input with dim overlay
	if dim_overlay:
		dim_overlay.show()
		dim_overlay.color = Color(0, 0, 0, 0.7) # Reset to dark translucent, in case it was red
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Hide any loose hero panel if it exists as a direct child
	for child in get_children():
		if child.name.contains("HeroPanel"):
			child.hide()

func enter_result_mode(summary: Dictionary, improvements: Dictionary = {}, rank: int = -1) -> void:
	enter_result_overlay()
	
	# Show result modal
	if result_panel:
		if OS.is_debug_build(): print("[UI_STATE] Show result modal")
		result_panel.show_result(summary, improvements, rank)
	else:
		# Fallback to old panel if dynamic creation failed (shouldn't happen)
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
		
		var stars_count = summary.get("stars", 0)
		for i in range(stars_container.get_child_count()):
			var star = stars_container.get_child(i)
			if star.has_method("set"):
				star.filled = (i < stars_count)
		
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
	
	if tower_target_label:
		var targets = info.get("target_categories", ["land"])
		var target_str = "Targets: "
		if targets.size() >= 2: target_str += "Land + Air"
		elif targets.has("air"): target_str += "Air Only"
		else: target_str += "Land Only"
		tower_target_label.text = target_str
		tower_target_label.modulate = Color(0.6, 0.9, 1.0) if targets.has("air") else Color(0.8, 0.8, 0.8)
	
	# Clear previous type specific labels
	tower_splash_label.hide()
	tower_slow_label.hide()
	
	var a_type = info.get("attack_type", "single")
	match a_type:
		"splash":
			tower_splash_label.show()
			tower_splash_label.text = "Type: SPLASH AREA (%d)" % info["splash_radius"]
			tower_splash_label.modulate = Color(1.0, 0.6, 0.3)
		"slow":
			tower_slow_label.show()
			var slow_pct = int(info.get("slow_percent", 0) * 100)
			var slow_dur = info.get("slow_duration", 0)
			tower_slow_label.text = "Type: AREA SLOW %d%% (%0.1fs)" % [slow_pct, slow_dur]
			tower_slow_label.modulate = Color(0.5, 0.8, 1.0)
		"chain":
			tower_splash_label.show()
			tower_splash_label.text = "Type: CHAIN ENERGY"
			tower_splash_label.modulate = Color(0.6, 0.5, 1.0)
		"aura":
			tower_splash_label.show()
			var vuln = int(info.get("vulnerability_percent", 0) * 100)
			tower_splash_label.text = "Type: BLEED AURA (+%d%%)" % vuln
			tower_splash_label.modulate = Color(1.0, 0.3, 0.3)
		_:
			tower_splash_label.show()
			tower_splash_label.text = "Type: DIRECT KINETIC"
			tower_splash_label.modulate = Color(0.7, 0.8, 0.9)
	
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
	if result_panel:
		result_panel.hide_result()

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
	
	# Fix: Use hard-coded reset to avoid feedback loops if multiple flashes occur
	var reset_color = Color(0, 0, 0, 0.4)
	
	dim_overlay.color = color
	dim_overlay.show()
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(dim_overlay, "modulate:a", 0.0, duration).from(1.0)
	tween.tween_callback(func():
		dim_overlay.hide()
		dim_overlay.color = reset_color
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

func _setup_right_sidebar_layout() -> void:
	var container = right_sidebar_container
	if container == null: return
	
	# 1. Setup Tower Detail Panel (Existing RightSidebar)
	right_sidebar.name = "TowerDetailPanel"
	right_sidebar.custom_minimum_size = Vector2(0, 260)
	right_sidebar.size_flags_vertical = Control.SIZE_FILL
	
	var style_detail = StyleBoxFlat.new()
	style_detail.bg_color = Color(0.025, 0.045, 0.085, 0.94)
	style_detail.set_border_width_all(1)
	style_detail.border_color = Color(0.22, 0.36, 0.58, 0.85)
	style_detail.set_corner_radius_all(8)
	right_sidebar.add_theme_stylebox_override("panel", style_detail)
	
	# Clean up margins
	var detail_margin = right_sidebar.get_node_or_null("MarginContainer")
	if detail_margin is MarginContainer:
		detail_margin.add_theme_constant_override("margin_left", 14)
		detail_margin.add_theme_constant_override("margin_right", 14)
		detail_margin.add_theme_constant_override("margin_top", 14)
		detail_margin.add_theme_constant_override("margin_bottom", 14)
	
	# Add Target Category Label if missing
	var detail_vbox = right_sidebar.get_node_or_null("MarginContainer/VBoxContainer")
	if detail_vbox:
		tower_target_label = Label.new()
		tower_target_label.name = "TowerTargetLabel"
		tower_target_label.add_theme_font_size_override("font_size", 12)
		tower_target_label.text = "Targets: Land"
		detail_vbox.add_child(tower_target_label)
		# Move it after fire rate
		detail_vbox.move_child(tower_target_label, tower_fire_rate_label.get_index() + 1)

	# 2. Setup No Selection Panel (Placeholder)
	no_selection_panel = PanelContainer.new()
	no_selection_panel.name = "NoSelectionPanel"
	no_selection_panel.custom_minimum_size = Vector2(0, 120)
	no_selection_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var ns_style = style_detail.duplicate()
	ns_style.bg_color = Color(0.04, 0.05, 0.08, 0.5)
	ns_style.border_color = Color(0.2, 0.3, 0.4, 0.3)
	no_selection_panel.add_theme_stylebox_override("panel", ns_style)
	container.add_child(no_selection_panel)
	container.move_child(no_selection_panel, 1)
	
	var ns_label = Label.new()
	ns_label.text = "Select a tower or build tile\nto view details"
	ns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ns_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ns_label.add_theme_font_size_override("font_size", 13)
	ns_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	no_selection_panel.add_child(ns_label)

	# 3. Setup Wave Intel Panel
	wave_intel_panel = PanelContainer.new()
	wave_intel_panel.name = "WaveIntelPanel"
	wave_intel_panel.custom_minimum_size = Vector2(0, 160)
	wave_intel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL # Use remaining space
	wave_intel_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(wave_intel_panel)
	
	var style_intel = style_detail.duplicate()
	style_intel.bg_color = Color(0.02, 0.03, 0.06, 0.85)
	wave_intel_panel.add_theme_stylebox_override("panel", style_intel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	wave_intel_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6) # Tighter spacing
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)
	
	# Header
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 1)
	vbox.add_child(header)
	
	var title = _create_wave_intel_label("WAVE INTEL", 15, Color(0.7, 0.9, 1.0))
	header.add_child(title)
	
	wave_intel_current_label = _create_wave_intel_label("", 13, Color(0.9, 0.95, 1.0))
	header.add_child(wave_intel_current_label)
	
	wave_intel_name_label = _create_wave_intel_label("", 12, Color(0.6, 0.8, 1.0))
	header.add_child(wave_intel_name_label)
	
	wave_intel_status_label = _create_wave_intel_label("", 11, Color(0.9, 0.8, 0.4))
	header.add_child(wave_intel_status_label)
	
	wave_intel_reward_label = _create_wave_intel_label("", 11, Color(1.0, 0.8, 0.2))
	header.add_child(wave_intel_reward_label)
	
	vbox.add_child(_create_wave_intel_separator())
	
	# Scrollable Body
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)
	
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(body)
	
	wave_intel_section_label = _create_wave_intel_label("Upcoming", 11, Color(0.5, 0.7, 0.9))
	body.add_child(wave_intel_section_label)
	
	wave_intel_main_summary_label = _create_wave_intel_richtext(13, Color(1, 1, 1))
	body.add_child(wave_intel_main_summary_label)
	
	wave_intel_next_title_label = _create_wave_intel_label("Next", 10, Color(0.5, 0.7, 0.9))
	body.add_child(wave_intel_next_title_label)
	
	wave_intel_next_summary_label = _create_wave_intel_richtext(12, Color(0.8, 0.8, 0.8))
	body.add_child(wave_intel_next_summary_label)
	
	body.add_child(_create_wave_intel_separator())
	
	var threats_title = _create_wave_intel_label("Threats", 10, Color(0.5, 0.7, 0.9))
	body.add_child(threats_title)
	
	wave_intel_threats_label = _create_wave_intel_richtext(12, Color(1, 0.6, 0.4))
	body.add_child(wave_intel_threats_label)
	
	var suggested_title = _create_wave_intel_label("Recommended", 10, Color(0.5, 0.7, 0.9))
	body.add_child(suggested_title)
	
	wave_intel_suggested_label = _create_wave_intel_richtext(12, Color(0.5, 0.9, 1.0))
	body.add_child(wave_intel_suggested_label)
	
	wave_intel_warnings_label = _create_wave_intel_label("", 10, Color(1, 0.4, 0.4))
	wave_intel_warnings_label.visible = false
	body.add_child(wave_intel_warnings_label)

	_refresh_right_info_column_visibility()

func _layout_right_sidebar_container(width: float = 260.0) -> void:
	var container = $Root/ScreenLayout/MainContent/RightSidebarContainer
	if container:
		container.custom_minimum_size.x = width

func _create_wave_intel_label(text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _create_wave_intel_richtext(font_size: int, color: Color) -> RichTextLabel:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
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
	if wave_intel_name_label:
		wave_intel_name_label.text = ""
	if wave_intel_status_label:
		wave_intel_status_label.text = ""
	if wave_intel_reward_label:
		wave_intel_reward_label.text = ""
	if wave_intel_section_label:
		wave_intel_section_label.text = ""
	if wave_intel_main_summary_label:
		wave_intel_main_summary_label.text = ""
	if wave_intel_threats_label:
		wave_intel_threats_label.text = ""
	if wave_intel_suggested_label:
		wave_intel_suggested_label.text = ""
	if wave_intel_warnings_label:
		wave_intel_warnings_label.text = ""
		wave_intel_warnings_label.visible = false
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
	wave_intel_name_label.text = current_preview.get("name", "Unknown Wave")
	wave_intel_status_label.text = "Status: " + status_text
	wave_intel_status_label.add_theme_color_override("font_color", Color(0.38, 0.92, 0.62) if is_running else Color(0.95, 0.78, 0.36))
	
	var reward = current_preview.get("reward", 0)
	if reward > 0:
		wave_intel_reward_label.text = "Reward: %d Credits" % reward
		wave_intel_reward_label.visible = true
	else:
		wave_intel_reward_label.visible = false
		
	wave_intel_section_label.text = "Current" if is_running else "Upcoming"
	wave_intel_main_summary_label.text = _format_wave_preview_summary(current_preview)
	wave_intel_threats_label.text = _format_wave_intel_list(current_preview.get("traits", []), "None")
	wave_intel_suggested_label.text = _format_wave_intel_list(current_preview.get("recommended_roles", []), "None")
	
	var warnings = current_preview.get("warnings", [])
	if not warnings.is_empty():
		wave_intel_warnings_label.text = "Note: " + "\n".join(warnings)
		wave_intel_warnings_label.visible = true
	else:
		wave_intel_warnings_label.visible = false
	
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
	var container = $Root/ScreenLayout/MainContent/RightSidebarContainer
	if container == null: return
	
	var tower_visible = right_sidebar != null and right_sidebar.visible
	var wave_visible = wave_intel_panel != null and wave_intel_panel.visible
	
	if right_sidebar:
		right_sidebar.visible = tower_visible
	
	if no_selection_panel:
		no_selection_panel.visible = not tower_visible
	
	if wave_intel_panel:
		wave_intel_panel.visible = wave_visible
	
	container.visible = true

func _format_wave_preview_summary(preview: Dictionary) -> String:
	var lane_info = preview.get("lane_info", {})
	
	if lane_info.keys().size() > 1:
		var lane_parts = []
		var sorted_ids = lane_info.keys()
		sorted_ids.sort()
		
		for p_id in sorted_ids:
			var info = lane_info[p_id]
			var counts = info.get("counts", {})
			var lane_name = "Lane A" if str(p_id) == "default" else str(p_id).capitalize()
			lane_parts.append("[%s]: %s" % [lane_name, _format_counts(counts)])
		return "\n".join(lane_parts)
		
	var counts = preview.get("enemy_counts", {})
	if counts.is_empty():
		return "Malformed Wave"
	return _format_counts(counts)

func _format_counts(counts: Dictionary) -> String:
	var parts = []
	var type_order = ["Normal", "Fast", "Heavy", "Swarm", "Air"]
	for type_name in type_order:
		if counts.has(type_name):
			var tooltip = enemy_role_tooltips.get(type_name, "")
			if tooltip != "":
				parts.append("[hint=%s]%s[/hint] x%d" % [tooltip, type_name, int(counts[type_name])])
			else:
				parts.append("%s x%d" % [type_name, int(counts[type_name])])
	for type_name in counts.keys():
		if not type_order.has(str(type_name)):
			var tooltip = enemy_role_tooltips.get(str(type_name), "")
			if tooltip != "":
				parts.append("[hint=%s]%s[/hint] x%d" % [tooltip, str(type_name), int(counts[type_name])])
			else:
				parts.append("%s x%d" % [str(type_name), int(counts[type_name])])
	return ", ".join(parts)

func _format_wave_intel_list(values: Array, fallback: String) -> String:
	if values.is_empty():
		return fallback
	var parts = []
	for value in values:
		var txt = str(value)
		var tooltip = enemy_role_tooltips.get(txt, "")
		if tooltip != "":
			parts.append("[hint=%s]%s[/hint]" % [tooltip, txt])
		else:
			parts.append(txt)
	return ", ".join(parts)

func _get_trait_description(trait_name: String) -> String:
	match trait_name.to_lower():
		"shield": return "Bulwark: Energy shield protects nearby."
		"anti-hero": return "Hunter: Focuses on your Guardian."
		"fast": return "High Speed: Fast, hard to track."
		"armored": return "Heavy Armor: Reduces incoming damage."
		"boss": return "COMMAND UNIT: Extreme durability."
		"healing": return "Support: Heals nearby units."
		"invisible": return "Stealth: Hidden unless close/scanned."
		"air": return "Airborne: Requires anti-air."
		"splash": return "Area Damage: Strong against swarms."
		"slow": return "Support: Reduces movement speed."
		"sniper": return "Precision: High dmg, extreme range."
		"lightning": return "Chain: Hits multiple targets."
		"sawblade": return "Bleed: Extra damage over time."
		_: return trait_name.capitalize()
