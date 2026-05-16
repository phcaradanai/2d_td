extends CanvasLayer

signal start_wave_requested()
signal tower_build_selected(tower_id: String)
signal cancel_build_requested()
signal pause_requested()
signal restart_requested()
signal upgrade_tower_requested()
signal deselect_tower_requested()
signal sell_tower_requested()
signal element_choice_requested(option: Variant)
signal target_mode_changed(mode: String)
signal main_menu_requested()
signal audio_settings_changed(settings: Dictionary)
signal test_audio_requested(type: String)
signal reset_audio_requested()
signal next_level_requested()
signal back_to_map_requested()

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")
const ElementIconControl = preload("res://scripts/ui/element_icon.gd")
const TowerRowTrimControl = preload("res://scripts/ui/tower_row_trim.gd")
const BuildSectionHeaderControl = preload("res://scripts/ui/build_section_header.gd")
const HUDStatChipControl = preload("res://scripts/ui/hud_stat_chip.gd")
const CreditCostDisplayControl = preload("res://scripts/ui/credit_cost_display.gd")
const HUDDrawerHeaderControl = preload("res://scripts/ui/hud_drawer_header.gd")
const CommandHeaderButtonControl = HUDDrawerHeaderControl
const ELEMENT_ORDER: Array[String] = ["light", "darkness", "water", "fire", "nature", "earth"]
const ELEMENT_SHORT_LABELS := {
	"light": "Light",
	"darkness": "Dark",
	"water": "Water",
	"fire": "Fire",
	"nature": "Nature",
	"earth": "Earth",
}

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
var interest_status_label: Label = null
var start_wave_countdown_badge: Label = null
var top_bar_total_waves: int = 0
var credits_chip: HUDStatChipControl = null
var core_chip: HUDStatChipControl = null
var wave_chip: HUDStatChipControl = null
var status_chip: HUDStatChipControl = null
var next_wave_chip: HUDStatChipControl = null
var interest_chip: HUDStatChipControl = null

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
@onready var tower_special_effect_label: Label = null
@onready var upgrade_tower_button: Button = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/UpgradeTowerButton
@onready var deselect_tower_button: Button = $Root/ScreenLayout/MainContent/RightSidebarContainer/RightSidebar/MarginContainer/VBoxContainer/DeselectTowerButton
var sell_tower_button: Button = null

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
var wave_intel_collapsed: bool = true
var _wi_wrapper: VBoxContainer = null
var _wi_header_btn: HUDDrawerHeaderControl = null
var _wi_tab_panel: HUDDrawerHeaderControl = null
var _wi_summary_label: Label = null
var _wi_chevron_label: Label = null
var _wi_reward_row: HBoxContainer = null
var _wi_reward_display: CreditCostDisplayControl = null
var _upgrade_cost_display: CreditCostDisplayControl = null
var _upgrade_text_label: Label = null
var _sell_cost_display: CreditCostDisplayControl = null
var _sell_text_label: Label = null

# Tower Detail premium nodes
var _td_name_label: Label = null
var _td_tier_chip: Label = null
var _td_el_badge: Control = null          # ElementIconControl or placeholder
var _td_stat_dmg: Label = null
var _td_stat_rng: Label = null
var _td_stat_spd: Label = null
var _td_stat_tgt: Label = null
var _td_stat_eff: Label = null            # KINETIC / SPLASH / etc badge
var _td_effect_section: Control = null    # whole EFFECT section (hide if empty)
var _td_effect_title: Label = null        # effect-colored badge title
var _td_effect_body: Label = null         # effect body + upgrade preview text
var _td_header_row: HBoxContainer = null  # for showing/hiding when no tower
var _td_header_panel: HUDDrawerHeaderControl = null
var _td_chevron_label: Label = null
var _td_content_nodes: Array[Control] = []
var tower_detail_collapsed: bool = true
var tower_detail_has_selection: bool = false

const SHOW_DAMAGE_PANEL := true
const DAMAGE_PANEL_REFRESH_INTERVAL := 0.20
const LEFT_DRAWER_WIDTH := 310.0
const LEFT_TAB_RAIL_WIDTH := 58.0
const RIGHT_DRAWER_WIDTH := LEFT_DRAWER_WIDTH
const DRAWER_SECTION_GAP := 10
const DRAWER_BODY_MIN_HEIGHT := 260.0
const PLAYFIELD_SAFE_MARGIN := 6.0
var damage_stats_tracker: Node = null
var damage_stats_panel: PanelContainer = null
var damage_stats_header_button: HUDDrawerHeaderControl = null
var damage_stats_summary_label: Label = null
var damage_stats_details: RichTextLabel = null
var damage_stats_expanded: bool = false
var _damage_stats_dirty: bool = true
var _damage_stats_refresh_elapsed: float = 0.0

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
var tower_catalog: Dictionary = {} # id: full tower config
var tower_shop_scroll: ScrollContainer = null
var tower_shop_list: VBoxContainer = null
var dynamic_tower_buttons: Dictionary = {} # id: Button
var active_build_tower_id: String = ""
var build_drawer_header_button: HUDDrawerHeaderControl = null
var build_drawer_expanded: bool = true
var build_towers_header_block: VBoxContainer = null
var build_panel_bottom_separator: ColorRect = null
var element_mastery_grid: GridContainer = null
var element_chip_nodes: Dictionary = {} # element_id: {panel, icon, name, level}
var _touch_points_down: Dictionary = {}

# Build-button hover card (desktop hover / mobile long-press).
var _hover_card: PanelContainer = null
var _hover_card_rtl: RichTextLabel = null
var _hover_long_press_timer: SceneTreeTimer = null

# Selected-tower floating info card.
var _tower_float_card: Control = null
var element_status_label: Label = null
var element_hint_label: Label = null
var element_choice_panel: PanelContainer = null
var element_choice_list: VBoxContainer = null
var current_element_levels: Dictionary = {}

## ── Element Modal (UI-ELEMENT-1) ────────────────────────────────────────────
## Display-only metadata — never used for any gameplay calculation.
const ELEMENT_UI_META := {
	"light": {
		"description": "The power of radiance and purification. Precise and far-reaching.",
		"attack_types": ["Single Target", "Precision Beam", "Long Range"],
		"strengths": ["Highest range tier", "Reliable single-target DPS", "Hits Air"],
		"weaknesses": ["No native AoE", "Costly dual combos"],
		"best_against": "High-HP targets, fast flyers, armored units",
		"recommended": "Long-range precision — effective from wave 1.",
		"icon": "✦",
	},
	"darkness": {
		"description": "Void entropy that weakens and debuffs anything caught in its field.",
		"attack_types": ["Aura / Debuff", "Vulnerability AoE", "DoT"],
		"strengths": ["Amplifies all other towers", "Strong AoE debuffs", "Scales late"],
		"weaknesses": ["Ground only", "Low raw damage alone"],
		"best_against": "Tanky groups, armored enemies, clustered waves",
		"recommended": "Pair with any damage element for massive synergy.",
		"icon": "☽",
	},
	"water": {
		"description": "Ice and tidal force that freezes enemies in their path.",
		"attack_types": ["Slow / Control", "AoE Freeze", "Zone Denial"],
		"strengths": ["Best crowd control", "Effective vs all speeds", "Hits Air"],
		"weaknesses": ["Lower direct damage", "Relies on other DPS towers"],
		"best_against": "Fast enemies, boss rushes, air units",
		"recommended": "Always strong — pairs with every damage element.",
		"icon": "❋",
	},
	"fire": {
		"description": "Explosive plasma that burns everything in a radius.",
		"attack_types": ["AoE Splash", "Cannon Burst", "Ground Only"],
		"strengths": ["Heavy splash damage", "Melts groups fast"],
		"weaknesses": ["Ground only", "Slow fire rate", "High build cost"],
		"best_against": "Grouped ground enemies, tanky clumps",
		"recommended": "Place at chokepoints and path bends.",
		"icon": "⬡",
	},
	"nature": {
		"description": "Rapid bio-circuit energy and spreading vine spores.",
		"attack_types": ["Rapid Fire", "Multi-Shot", "Spore DoT"],
		"strengths": ["Fastest attack speed", "Hits Air", "Spore debuffs"],
		"weaknesses": ["Lower damage per hit", "Short-medium range"],
		"best_against": "Swarm waves, fast enemies, healers",
		"recommended": "Consistent DPS filler — never wasted.",
		"icon": "✿",
	},
	"earth": {
		"description": "Seismic armored stone that crushes the heaviest targets.",
		"attack_types": ["Single Target", "Heavy Cannon", "Seismic AoE"],
		"strengths": ["Highest raw damage", "Hard-hitting shots"],
		"weaknesses": ["Ground only", "Slowest attack rate"],
		"best_against": "Tanks, bosses, high-HP priority targets",
		"recommended": "Mid-to-late game when HP pools scale.",
		"icon": "◆",
	},
	"__interest__": {
		"description": "Invest your pick in passive gold generation instead of combat power.",
		"attack_types": ["Economy", "Passive Gold / 15s"],
		"strengths": ["Compounds across all future waves", "No tower slot needed"],
		"weaknesses": ["No combat benefit", "Weaker value late game"],
		"best_against": "Economy strategy, first few picks",
		"recommended": "Strongest when chosen early — compounding adds up fast.",
		"icon": "◈",
	},
}

## Modal nodes
var _em_overlay: Control = null
var _em_panel: PanelContainer = null
var _em_selected: String = ""
var _em_data: Dictionary = {}
var _em_card_nodes: Dictionary = {}
var _em_card_container: VBoxContainer = null
var _em_center_col: VBoxContainer = null
var _em_right_col: VBoxContainer = null
var _em_confirm_btn: Button = null
var _em_picks_label: Label = null
var _em_close_btn: Button = null

const RESULT_PANEL_SCENE = preload("res://scenes/ui/ResultPanel.tscn")
const SHOP_LOCKED_TEXT_COLOR  := NeonStyle.INK_3
const SHOP_ENABLED_TEXT_COLOR := NeonStyle.INK_1
const SHOP_HEADER_COLOR       := NeonStyle.CYAN_2
const SHOP_GOLD_COLOR         := NeonStyle.WARN
var result_panel: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	start_wave_button.pressed.connect(func(): start_wave_requested.emit())
	_configure_start_wave_button_layout()
	settings_button.pressed.connect(func(): set_panel_active(settings_panel, true, true))
	pause_button.pressed.connect(func(): pause_requested.emit())
	
	restart_button.pressed.connect(_on_restart_pressed)
	center_restart_button.pressed.connect(_on_restart_pressed)
	
	_setup_right_sidebar_layout()
	_setup_hover_card()
	_ensure_elemental_shop_ui()
	_ensure_element_modal()
	
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
	
	basic_tower_button.pressed.connect(func(): _on_tower_btn_pressed("basic_tower_t1", basic_tower_button))
	rapid_tower_button.pressed.connect(func(): _on_tower_btn_pressed("rapid_tower", rapid_tower_button))
	cannon_tower_button.pressed.connect(func(): _on_tower_btn_pressed("cannon_tower", cannon_tower_button))
	slow_tower_button.pressed.connect(func(): _on_tower_btn_pressed("slow_tower", slow_tower_button))
	sniper_tower_button.pressed.connect(func(): _on_tower_btn_pressed("sniper_tower", sniper_tower_button))
	lightning_tower_button.pressed.connect(func(): _on_tower_btn_pressed("lightning_tower", lightning_tower_button))
	sawblade_tower_button.pressed.connect(func(): _on_tower_btn_pressed("sawblade_tower", sawblade_tower_button))
	cancel_build_button.pressed.connect(func():
		cancel_build_requested.emit()
		_set_build_towers_drawer_expanded(true))
	upgrade_tower_button.pressed.connect(func(): upgrade_tower_requested.emit())
	deselect_tower_button.pressed.connect(func(): deselect_tower_requested.emit())
	
	# Create Sell Tower button — composite: text + CreditCostDisplayControl
	var tower_info_vbox := upgrade_tower_button.get_parent()
	if tower_info_vbox:
		sell_tower_button = Button.new()
		sell_tower_button.name = "SellTowerButton"
		sell_tower_button.text = ""
		sell_tower_button.size_flags_horizontal = Control.SIZE_FILL
		sell_tower_button.pressed.connect(func(): sell_tower_requested.emit())
		sell_tower_button.hide()

		var sell_row := HBoxContainer.new()
		sell_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		sell_row.offset_left = 10
		sell_row.offset_right = -8
		sell_row.add_theme_constant_override("separation", 6)
		sell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sell_tower_button.add_child(sell_row)

		_sell_text_label = Label.new()
		_sell_text_label.text = "Sell +"
		_sell_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sell_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_sell_text_label.add_theme_font_size_override("font_size", 12)
		_sell_text_label.add_theme_color_override("font_color", NeonStyle.OK)
		_sell_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sell_row.add_child(_sell_text_label)

		_sell_cost_display = CreditCostDisplayControl.new()
		_sell_cost_display.custom_minimum_size = Vector2(58, 28)
		_sell_cost_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_sell_cost_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sell_row.add_child(_sell_cost_display)

		tower_info_vbox.add_child(sell_tower_button)
		tower_info_vbox.move_child(sell_tower_button, tower_info_vbox.get_child_count() - 2) # above Deselect
		_register_tower_detail_content(sell_tower_button)
	
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
	
	_ensure_top_hud_stat_chips()
	set_status("Ready")
	set_build_status("Build: None")
	_ensure_interest_status_label()
	_ensure_start_wave_countdown_badge()
	_ensure_damage_stats_panel()
	set_interest_status("Interest: Off")
	
	# Final skin pass (also styles buttons added above)
	_apply_terminal_hud_skin()

	# Top-bar HBox spacing
	var top_hbox := gold_label.get_parent()
	if top_hbox is HBoxContainer:
		top_hbox.add_theme_constant_override("separation", 8)

func _process(delta: float) -> void:
	if damage_stats_panel == null or not SHOW_DAMAGE_PANEL:
		return
	_damage_stats_refresh_elapsed += delta
	if _damage_stats_refresh_elapsed >= DAMAGE_PANEL_REFRESH_INTERVAL:
		_damage_stats_refresh_elapsed = 0.0
		_refresh_damage_stats_panel()

func _input(event: InputEvent) -> void:
	if _handle_build_cancel_input(event):
		return
	if not build_drawer_expanded and not damage_stats_expanded:
		return
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if not pressed:
		return
	if left_sidebar and left_sidebar.visible and left_sidebar.get_global_rect().has_point(pos):
		return
	_collapse_left_drawers()

func _handle_build_cancel_input(event: InputEvent) -> bool:
	if active_build_tower_id.is_empty():
		if event is InputEventScreenTouch:
			_touch_points_down.erase(event.index)
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_build_requested.emit()
		_set_active_build_row("")
		return true
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points_down[event.index] = true
			if _touch_points_down.size() >= 2:
				cancel_build_requested.emit()
				_set_active_build_row("")
				return true
		else:
			_touch_points_down.erase(event.index)
	return false

func _get_left_sidebar_content_box() -> VBoxContainer:
	if left_sidebar == null:
		return null
	var margin := left_sidebar.get_node_or_null("MarginContainer")
	if margin == null:
		return null
	var box := margin.get_node_or_null("VBoxContainer")
	return box as VBoxContainer

func _ensure_left_drawer_headers(container: VBoxContainer) -> void:
	if build_drawer_header_button == null or not is_instance_valid(build_drawer_header_button):
		build_drawer_header_button = CommandHeaderButtonControl.new()
		build_drawer_header_button.name = "BuildTowersDrawerHeader"
		build_drawer_header_button.configure("BUILD TOWERS", "build", NeonStyle.CYAN, build_drawer_expanded, true)
		build_drawer_header_button.pressed.connect(_toggle_build_towers_drawer)
		container.add_child(build_drawer_header_button)
		container.move_child(build_drawer_header_button, basic_tower_button.get_index())
	if damage_stats_header_button == null or not is_instance_valid(damage_stats_header_button):
		damage_stats_header_button = CommandHeaderButtonControl.new()
		damage_stats_header_button.name = "DamageStatsDrawerHeader"
		damage_stats_header_button.configure("DAMAGE STATS", "damage", NeonStyle.WARN, damage_stats_expanded, true)
		damage_stats_header_button.pressed.connect(_toggle_damage_stats_panel)
		container.add_child(damage_stats_header_button)
		container.move_child(damage_stats_header_button, build_drawer_header_button.get_index() + 1)
	_position_unified_left_drawer_tabs(container)
	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()

func _position_unified_left_drawer_tabs(container: VBoxContainer) -> void:
	# Accordion-style left menu:
	# [BUILD TOWERS header]
	# [Build body when active]
	# [WAVE INTEL header]
	# [Wave Intel body when active]
	# [DAMAGE STATS header]
	# [Damage Stats body when active]
	#
	# Keep the expanded content directly under its matching header so the panel
	# reads as one continuous menu instead of a row of unrelated buttons.
	if _wi_wrapper:
		# Wave Intel header + body should remain a single wrapper. Older layout code
		# may have moved the body into the root container, so repair that here.
		if wave_intel_panel and wave_intel_panel.get_parent() != _wi_wrapper:
			var old_parent := wave_intel_panel.get_parent()
			if old_parent:
				old_parent.remove_child(wave_intel_panel)
			_wi_wrapper.add_child(wave_intel_panel)
			if _wi_tab_panel and _wi_tab_panel.get_parent() == _wi_wrapper:
				_wi_wrapper.move_child(wave_intel_panel, _wi_tab_panel.get_index() + 1)

	var index := 0

	# 1) Build Towers header + body
	if build_drawer_header_button and build_drawer_header_button.get_parent() == container:
		container.move_child(build_drawer_header_button, index)
		index += 1
	if build_towers_header_block and build_towers_header_block.get_parent() == container:
		container.move_child(build_towers_header_block, index)
		index += 1
	if tower_shop_scroll and tower_shop_scroll.get_parent() == container:
		container.move_child(tower_shop_scroll, index)
		index += 1
	if build_panel_bottom_separator and build_panel_bottom_separator.get_parent() == container:
		container.move_child(build_panel_bottom_separator, index)
		index += 1
	if build_status_label and build_status_label.get_parent() == container:
		container.move_child(build_status_label, index)
		index += 1

	# 2) Wave Intel header + body wrapper
	if _wi_wrapper and _wi_wrapper.get_parent() == container:
		container.move_child(_wi_wrapper, index)
		index += 1

	# 3) Damage Stats header + body
	if damage_stats_header_button and damage_stats_header_button.get_parent() == container:
		container.move_child(damage_stats_header_button, index)
		index += 1
	if damage_stats_panel and damage_stats_panel.get_parent() == container:
		container.move_child(damage_stats_panel, index)

func _cancel_active_build_for_info_menu() -> void:
	# Switching from the build menu to an information menu should leave
	# tower placement mode. Otherwise Damage Stats / Wave Intel still feel
	# like they are stuck inside Build Mode.
	if active_build_tower_id.is_empty():
		return
	cancel_build_requested.emit()
	_set_active_build_row("")


func _toggle_build_towers_drawer() -> void:
	# Build Towers is the primary menu. It does not collapse the whole left
	# panel; it switches the active menu body back to the tower shop.
	_set_build_towers_drawer_expanded(true)

func _set_build_towers_drawer_expanded(expanded: bool) -> void:
	# The left panel is now a persistent menu system. Build Towers is one menu
	# body; Wave Intel and Damage Stats are alternate menu bodies.
	build_drawer_expanded = expanded
	if build_drawer_expanded:
		wave_intel_collapsed = true
		damage_stats_expanded = false
	if not build_drawer_expanded and wave_intel_collapsed and not damage_stats_expanded:
		# Never leave the drawer with no active body.
		build_drawer_expanded = true

	if build_drawer_header_button:
		build_drawer_header_button.set_expanded(build_drawer_expanded)
	_hide_hover_card()
	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()

func _collapse_left_drawers() -> void:
	# Do not collapse the left panel anymore. It is a persistent command menu.
	# Keep the current active menu; if no menu body is active, return to Build.
	if wave_intel_collapsed and not damage_stats_expanded:
		_set_build_towers_drawer_expanded(true)
	else:
		_apply_build_drawer_visibility()
		_apply_left_drawer_layout()

func _apply_build_drawer_visibility() -> void:
	# Tower Detail lives only in the floating tower card. The left drawer is a
	# menu: Build Towers, Wave Intel, or Damage Stats. Only one body is visible.
	tower_detail_collapsed = true

	if not build_drawer_expanded and wave_intel_collapsed and not damage_stats_expanded:
		build_drawer_expanded = true

	var wave_intel_expanded := not wave_intel_collapsed

	if build_drawer_header_button:
		build_drawer_header_button.set_tab_mode(false)
		build_drawer_header_button.set_expanded(build_drawer_expanded)
	if _td_header_panel:
		_td_header_panel.visible = false
	if _wi_tab_panel:
		_wi_tab_panel.set_tab_mode(false)
		_wi_tab_panel.set_expanded(wave_intel_expanded)
	if damage_stats_header_button:
		damage_stats_header_button.set_tab_mode(false)
		damage_stats_header_button.set_expanded(damage_stats_expanded)

	if build_towers_header_block:
		build_towers_header_block.visible = build_drawer_expanded
	if tower_shop_scroll:
		tower_shop_scroll.visible = build_drawer_expanded
	if build_panel_bottom_separator:
		build_panel_bottom_separator.visible = build_drawer_expanded
	if build_status_label:
		build_status_label.visible = build_drawer_expanded and not active_build_tower_id.is_empty()
	if cancel_build_button:
		cancel_build_button.visible = false

	# Hide legacy Tower Detail drawer/body. The floating card is the single
	# selected-tower action UI.
	if right_sidebar:
		right_sidebar.visible = false
	if no_selection_panel:
		no_selection_panel.visible = false

	if _wi_wrapper:
		_wi_wrapper.visible = true
		_wi_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL if wave_intel_expanded else Control.SIZE_SHRINK_BEGIN
	if wave_intel_panel:
		wave_intel_panel.visible = wave_intel_expanded
		wave_intel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if wave_intel_expanded else Control.SIZE_SHRINK_BEGIN
		# Let the active body use the remaining drawer height instead of locking it
		# to a small card that immediately shows an inner scrollbar.
		wave_intel_panel.custom_minimum_size.y = 0.0
	if damage_stats_panel:
		damage_stats_panel.visible = damage_stats_expanded
		damage_stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if damage_stats_expanded else Control.SIZE_SHRINK_BEGIN
		damage_stats_panel.custom_minimum_size.y = 0.0

func _apply_left_drawer_layout() -> void:
	if left_sidebar == null:
		return

	# The left side is now the always-open primary command drawer.
	var drawer_open := true

	left_sidebar.visible = true
	left_sidebar.clip_contents = false
	left_sidebar.custom_minimum_size.x = LEFT_DRAWER_WIDTH
	left_sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_sidebar.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := left_sidebar.get_node_or_null("MarginContainer")
	if margin:
		var m := 8
		margin.add_theme_constant_override("margin_left", m)
		margin.add_theme_constant_override("margin_right", m)
		margin.add_theme_constant_override("margin_top", m)
		margin.add_theme_constant_override("margin_bottom", m)

		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.mouse_filter = Control.MOUSE_FILTER_PASS

		var vbox := margin.get_node_or_null("VBoxContainer")
		if vbox:
			vbox.add_theme_constant_override("separation", 10)
			vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.mouse_filter = Control.MOUSE_FILTER_PASS
			_position_unified_left_drawer_tabs(vbox)

	_style_left_sidebar_shell(drawer_open)
	_sync_tower_shop_list_width()

func _style_left_sidebar_shell(drawer_open: bool) -> void:
	if left_sidebar == null:
		return

	# Keep one consistent visual direction for the left side:
	# a persistent command rail is always visible while collapsed,
	# and the same shell expands into the full drawer.
	# This avoids the inconsistent "border exists before opening, disappears after collapse" state.
	var style := StyleBoxFlat.new()
	style.bg_color = NeonStyle.BG_1 if drawer_open else Color(NeonStyle.BG_1.r, NeonStyle.BG_1.g, NeonStyle.BG_1.b, 0.72)
	style.border_color = NeonStyle.LINE if drawer_open else Color(NeonStyle.LINE.r, NeonStyle.LINE.g, NeonStyle.LINE.b, 0.42)
	style.set_border_width_all(1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	left_sidebar.add_theme_stylebox_override("panel", style)

func set_damage_stats_tracker(tracker: Node) -> void:
	damage_stats_tracker = tracker
	if damage_stats_tracker and damage_stats_tracker.has_signal("stats_changed"):
		damage_stats_tracker.stats_changed.connect(_on_damage_stats_changed)
	_ensure_damage_stats_panel()
	_on_damage_stats_changed()

func _on_damage_stats_changed() -> void:
	_damage_stats_dirty = true
	if damage_stats_expanded:
		_refresh_damage_stats_panel()

func _ensure_damage_stats_panel() -> void:
	if damage_stats_panel != null or left_sidebar == null or not SHOW_DAMAGE_PANEL:
		return
	var container := _get_left_sidebar_content_box()
	if container == null:
		return
	_ensure_left_drawer_headers(container)

	damage_stats_panel = PanelContainer.new()
	damage_stats_panel.name = "DamageStatsPanel"
	damage_stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	damage_stats_panel.custom_minimum_size = Vector2(0.0, 0.0)
	damage_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	damage_stats_panel.visible = false

	# Panel style matching the design system
	var ps := StyleBoxFlat.new()
	ps.bg_color = NeonStyle.BG_1
	ps.border_color = Color(NeonStyle.WARN.r, NeonStyle.WARN.g, NeonStyle.WARN.b, 0.42)
	ps.set_border_width_all(1)
	ps.set_border_width(SIDE_LEFT, 3)
	ps.set_corner_radius_all(0)
	ps.content_margin_left   = 10
	ps.content_margin_right  = 10
	ps.content_margin_top    = 8
	ps.content_margin_bottom = 8
	damage_stats_panel.add_theme_stylebox_override("panel", ps)
	container.add_child(damage_stats_panel)
	container.move_child(damage_stats_panel, damage_stats_header_button.get_index() + 1)

	var box := VBoxContainer.new()
	box.name = "DamageStatsBox"
	box.add_theme_constant_override("separation", 7)
	damage_stats_panel.add_child(box)

	var top_row := HBoxContainer.new()
	top_row.name = "DamageStatsPanelHeader"
	top_row.add_theme_constant_override("separation", 8)
	box.add_child(top_row)

	damage_stats_summary_label = Label.new()
	damage_stats_summary_label.name = "DamageStatsSummary"
	damage_stats_summary_label.text = "DMG  0  ·  Top: —"
	damage_stats_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	damage_stats_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_stats_summary_label.add_theme_font_size_override("font_size", 11)
	damage_stats_summary_label.add_theme_color_override("font_color", NeonStyle.INK_2)
	top_row.add_child(damage_stats_summary_label)

	# Hairline separator
	var sep := ColorRect.new()
	sep.color = Color(NeonStyle.WARN.r, NeonStyle.WARN.g, NeonStyle.WARN.b, 0.30)
	sep.custom_minimum_size.y = 1
	box.add_child(sep)

	# Expandable details table
	damage_stats_details = RichTextLabel.new()
	damage_stats_details.name = "DamageStatsDetails"
	damage_stats_details.bbcode_enabled = false
	damage_stats_details.fit_content = false
	damage_stats_details.scroll_active = true
	damage_stats_details.custom_minimum_size = Vector2(0.0, 0.0)
	damage_stats_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	damage_stats_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	damage_stats_details.add_theme_font_size_override("normal_font_size", 11)
	damage_stats_details.add_theme_color_override("default_color", NeonStyle.INK_2)
	box.add_child(damage_stats_details)

	_refresh_damage_stats_panel()

func _toggle_damage_stats_panel() -> void:
	_set_damage_stats_expanded(not damage_stats_expanded)

func _set_damage_stats_expanded(expanded: bool) -> void:
	damage_stats_expanded = expanded
	if damage_stats_expanded:
		_cancel_active_build_for_info_menu()
		build_drawer_expanded = false
		wave_intel_collapsed = true
	else:
		if wave_intel_collapsed:
			build_drawer_expanded = true

	if damage_stats_header_button:
		damage_stats_header_button.set_expanded(damage_stats_expanded)
	if _wi_tab_panel:
		_wi_tab_panel.set_expanded(not wave_intel_collapsed)
	if damage_stats_panel:
		damage_stats_panel.visible = damage_stats_expanded

	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()
	_refresh_damage_stats_panel()

func _refresh_damage_stats_panel() -> void:
	_damage_stats_dirty = false
	if damage_stats_header_button == null:
		return
	var summary: Dictionary = {}
	if damage_stats_tracker:
		if damage_stats_expanded and damage_stats_tracker.has_method("get_summary"):
			summary = damage_stats_tracker.get_summary()
		elif damage_stats_tracker.has_method("get_compact_summary"):
			summary = damage_stats_tracker.get_compact_summary()
	var wave_damage: float = float(summary.get("wave_damage", 0.0))
	var top_entry: Dictionary = summary.get("top_entry", {})
	var top_name: String = str(top_entry.get("tower_name", "—")) if not top_entry.is_empty() else "—"
	var top_damage: float = float(top_entry.get("wave_damage", 0.0)) if not top_entry.is_empty() else 0.0
	if damage_stats_summary_label:
		damage_stats_summary_label.text = "DMG  %d  ·  Top: %s  %d" % [
			int(round(wave_damage)), top_name, int(round(top_damage))]
	if not damage_stats_expanded or damage_stats_details == null:
		return
	var lines: Array[String] = []
	var total_damage := int(round(float(summary.get("total_damage", 0.0))))
	lines.append("Wave: %d    Total: %d" % [int(round(wave_damage)), total_damage])
	lines.append("─────────────────────────────────────────")
	lines.append("%-22s %5s %5s %7s" % ["Tower", "Wave", "Hits", "Total"])
	lines.append("─────────────────────────────────────────")
	var entries: Array = summary.get("entries", [])
	var shown := 0
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var entry_wave_damage: float = float(entry.get("wave_damage", 0.0))
		if entry_wave_damage <= 0.0:
			continue
		var tower_name: String = str(entry.get("tower_name", entry.get("tower_id", "?")))
		lines.append("%-22s %5d %5d %7d" % [
			tower_name.substr(0, 22),
			int(round(entry_wave_damage)),
			int(entry.get("wave_hit_count", 0)),
			int(round(float(entry.get("total_damage", 0.0)))),
		])
		shown += 1
	if shown == 0:
		lines.append("No damage recorded yet.")
	damage_stats_details.text = "\n".join(lines)

func set_panel_active(panel: Control, active: bool, block_mouse: bool = true) -> void:
	if panel == null: return
	
	panel.visible = active
	if active:
		panel.process_mode = Node.PROCESS_MODE_INHERIT
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if block_mouse else Control.MOUSE_FILTER_IGNORE
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_layout_for_viewport() -> void:
	if not is_inside_tree():
		return

	var view_size = get_viewport().get_visible_rect().size
	var portrait: bool = view_size.x <= 760.0 or view_size.y > view_size.x * 1.22

	# Keep the left drawer stable, but let the gameplay area consume every
	# remaining pixel. The right panel is retired, so it must not reserve width.
	_apply_left_drawer_layout()
	_apply_full_playfield_layout()

	if right_sidebar_container:
		right_sidebar_container.custom_minimum_size = Vector2.ZERO
		right_sidebar_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		right_sidebar_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_sidebar_container.visible = false
		right_sidebar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_sync_tower_shop_list_width()
	_apply_mobile_portrait_layout(portrait)
	_apply_full_playfield_layout()
func _apply_terminal_hud_skin() -> void:
	if dim_overlay:
		dim_overlay.color = Color(0.012, 0.016, 0.028, 0.76)
	if screen_layout:
		screen_layout.add_theme_constant_override("separation", 0)

	# Top bar — subtle gradient base
	var top_bar := $Root/ScreenLayout/TopBar
	if top_bar is PanelContainer:
		var tb_style := StyleBoxFlat.new()
		tb_style.bg_color = Color(0.043, 0.059, 0.090, 0.96)
		tb_style.border_color = NeonStyle.LINE
		tb_style.set_border_width_all(0)
		tb_style.border_width_bottom = 1
		tb_style.content_margin_left   = 20
		tb_style.content_margin_right  = 20
		tb_style.content_margin_top    = 0
		tb_style.content_margin_bottom = 0
		top_bar.add_theme_stylebox_override("panel", tb_style)
		top_bar.custom_minimum_size.y = 68

	# Settings panel (right_sidebar styled separately in _setup_right_sidebar_layout)
	if settings_panel:
		var s := NeonStyle.panel(NeonStyle.BG_1, NeonStyle.LINE, false)
		s.content_margin_left   = 0
		s.content_margin_right  = 0
		s.content_margin_top    = 0
		s.content_margin_bottom = 0
		settings_panel.add_theme_stylebox_override("panel", s)
	_apply_left_drawer_layout()

	if center_message_panel:
		var s := NeonStyle.panel(NeonStyle.BG_1, NeonStyle.LINE_STRONG, true)
		center_message_panel.add_theme_stylebox_override("panel", s)

	# Top-bar stat labels
	if gold_label:
		NeonStyle.apply_terminal_label(gold_label, 14, NeonStyle.WARN, true)
	if lives_label:
		NeonStyle.apply_terminal_label(lives_label, 14, NeonStyle.CYAN_2, false)
	if wave_label:
		NeonStyle.apply_terminal_label(wave_label, 14, NeonStyle.INK_2, false)
	if status_label:
		NeonStyle.apply_terminal_label(status_label, 11, NeonStyle.CYAN)
		status_label.uppercase = true
	if next_wave_label:
		NeonStyle.apply_terminal_label(next_wave_label, 11, NeonStyle.INK_3)
	if interest_status_label:
		NeonStyle.apply_terminal_label(interest_status_label, 11, NeonStyle.EL_INTEREST)
	if build_status_label:
		NeonStyle.apply_terminal_label(build_status_label, 11, NeonStyle.INK_3)
	_style_top_hud_backing_labels()

	# Buttons — refined sizing
	for btn in [settings_button, pause_button, restart_button,
			cancel_build_button,
			close_settings_button, test_sfx_button, test_music_button, reset_audio_button]:
		if btn:
			NeonStyle.style_button(btn, NeonStyle.CYAN, false)
			btn.custom_minimum_size.y = 32

	# Primary action buttons stay taller
	for btn in [start_wave_button, center_restart_button, center_menu_button]:
		if btn:
			NeonStyle.style_button(btn, NeonStyle.CYAN,
				btn == start_wave_button or btn == center_restart_button)
			btn.custom_minimum_size.y = 38

	# Upgrade button — WARN (amber/gold) primary action
	if upgrade_tower_button:
		NeonStyle.style_button(upgrade_tower_button, NeonStyle.WARN, false)
		upgrade_tower_button.custom_minimum_size.y = 36

	if sell_tower_button:
		NeonStyle.style_button(sell_tower_button, NeonStyle.OK, false)
		sell_tower_button.add_theme_color_override("font_color", NeonStyle.OK)
		sell_tower_button.custom_minimum_size.y = 32

func _apply_mobile_portrait_layout(portrait: bool) -> void:
	if left_sidebar == null or screen_layout == null:
		return
	if portrait:
		if left_sidebar.get_parent() != screen_layout:
			var old_parent := left_sidebar.get_parent()
			if old_parent:
				old_parent.remove_child(left_sidebar)
			screen_layout.add_child(left_sidebar)
		var top_bar := $Root/ScreenLayout/TopBar
		if top_bar is PanelContainer:
			top_bar.custom_minimum_size.y = 96
		var top_hbox := gold_label.get_parent()
		if top_hbox is HBoxContainer:
			top_hbox.add_theme_constant_override("separation", 10)
		if start_wave_button:
			start_wave_button.custom_minimum_size = Vector2(136, 42)
	else:
		var main_content := $Root/ScreenLayout/MainContent
		if main_content and left_sidebar.get_parent() != main_content:
			left_sidebar.get_parent().remove_child(left_sidebar)
			main_content.add_child(left_sidebar)
			main_content.move_child(left_sidebar, 0)
		var top_bar := $Root/ScreenLayout/TopBar
		if top_bar is PanelContainer:
			top_bar.custom_minimum_size.y = 64

func _apply_full_playfield_layout() -> void:
	var main_content := $Root/ScreenLayout/MainContent
	if main_content is HBoxContainer:
		main_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_content.add_theme_constant_override("separation", 0)

	if playfield_area:
		playfield_area.custom_minimum_size = Vector2.ZERO
		playfield_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		playfield_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		playfield_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if right_sidebar_container:
		right_sidebar_container.custom_minimum_size = Vector2.ZERO
		right_sidebar_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		right_sidebar_container.visible = false
		right_sidebar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_playfield_rect() -> Rect2:
	# Return the largest usable gameplay rectangle instead of the old fixed/
	# right-sidebar-aware slot. The main scene uses this rect to fit/scale the
	# board, so keeping it tied to the retired right panel caused large black
	# unused margins after the UI moved to the left drawer.
	var view_rect := get_viewport().get_visible_rect()
	var view_size := view_rect.size

	var left_edge := 0.0
	if left_sidebar and left_sidebar.is_inside_tree() and left_sidebar.visible:
		var left_rect := left_sidebar.get_global_rect()
		left_edge = max(left_edge, left_rect.position.x + left_rect.size.x)
	elif left_sidebar:
		left_edge = max(left_edge, left_sidebar.custom_minimum_size.x)

	var top_edge := 0.0
	var top_bar := $Root/ScreenLayout/TopBar
	if top_bar is Control and top_bar.is_inside_tree() and top_bar.visible:
		var top_rect: Rect2 = top_bar.get_global_rect()
		top_edge = max(top_edge, top_rect.position.y + top_rect.size.y)
	else:
		top_edge = 60.0

	var margin := PLAYFIELD_SAFE_MARGIN
	var rect := Rect2(
		Vector2(left_edge + margin, top_edge + margin),
		Vector2(
			max(100.0, view_size.x - left_edge - margin * 2.0),
			max(100.0, view_size.y - top_edge - margin * 2.0)
		)
	)

	return rect

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

func _ensure_top_hud_stat_chips() -> void:
	var top_hbox := gold_label.get_parent()
	if not top_hbox is HBoxContainer:
		return
	if credits_chip != null and is_instance_valid(credits_chip):
		return
	top_hbox.add_theme_constant_override("separation", 8)
	credits_chip = _make_hud_stat_chip("CreditsChip", "credits", "0", NeonStyle.WARN, Vector2(86, 38))
	core_chip = _make_hud_stat_chip("CoreChip", "core", "20", NeonStyle.CYAN_2, Vector2(72, 38))
	wave_chip = _make_hud_stat_chip("WaveChip", "wave", "WAVE 0/60", NeonStyle.CYAN, Vector2(118, 38))
	status_chip = _make_hud_stat_chip("StatusChip", "status", "READY", NeonStyle.CYAN, Vector2(92, 38))
	next_wave_chip = _make_hud_stat_chip("NextWaveChip", "next", "NEXT W1", NeonStyle.INK_2, Vector2(210, 38))
	interest_chip = _make_hud_stat_chip("InterestChip", "interest", "OFF", NeonStyle.EL_INTEREST, Vector2(164, 38))
	var chips: Array[HUDStatChipControl] = [credits_chip, core_chip, wave_chip, status_chip, next_wave_chip, interest_chip]
	var insert_index := gold_label.get_index()
	for chip in chips:
		top_hbox.add_child(chip)
		top_hbox.move_child(chip, insert_index)
		insert_index += 1
	_style_top_hud_backing_labels()

func _make_hud_stat_chip(node_name: String, kind: String, text: String, accent: Color, min_size: Vector2) -> HUDStatChipControl:
	var chip := HUDStatChipControl.new()
	chip.name = node_name
	chip.custom_minimum_size = min_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.configure(kind, text, accent, false)
	return chip

func _style_top_hud_backing_labels() -> void:
	for label in [gold_label, lives_label, wave_label, status_label, next_wave_label, interest_status_label]:
		if label is Label:
			label.visible = false
			label.custom_minimum_size = Vector2.ZERO
			label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func set_gold(value: int) -> void:
	var old_text := gold_label.text
	gold_label.text = "✦ %d" % value
	gold_label.add_theme_color_override("font_color", NeonStyle.WARN)
	if old_text != gold_label.text:
		pulse_label(credits_chip if credits_chip else gold_label)
	if credits_chip:
		credits_chip.set_value(str(value), NeonStyle.WARN, false)
	_update_tower_affordability(value)

func _update_tower_affordability(current_gold: int) -> void:
	for tower_id in dynamic_tower_buttons.keys():
		var btn: Button = dynamic_tower_buttons[tower_id]
		if btn == null or not is_instance_valid(btn):
			continue
		if btn.disabled:
			continue  # Skip locked towers; they keep their gray state.
		var cost: int = int(tower_prices.get(tower_id, 50))
		var can_afford := current_gold >= cost
		btn.set_meta("row_affordable", can_afford)
		btn.modulate = Color(1, 1, 1, 1)
		var cost_display := btn.get_node_or_null("Row/CostDisplay")
		if cost_display is CreditCostDisplayControl:
			cost_display.configure(cost, can_afford)
		var cost_label := btn.get_node_or_null("Row/CostLabel")
		if cost_label is Label:
			cost_label.add_theme_color_override("font_color", NeonStyle.WARN if can_afford else Color(NeonStyle.DANGER.r, NeonStyle.DANGER.g, NeonStyle.DANGER.b, 0.82))
		var name_label := btn.get_node_or_null("Row/NameColumn/NameLabel")
		if name_label is Label:
			name_label.add_theme_color_override("font_color", NeonStyle.INK_1 if can_afford else NeonStyle.INK_2)
		_update_tower_row_trim(btn, bool(btn.get_meta("row_hovered", false)))

func refresh_tower_shop(tower_ids: Array[String]) -> void:
	_ensure_elemental_shop_ui()
	_hide_static_tower_buttons()
	_clear_dynamic_tower_buttons()

	var unlocked_set: Dictionary = {}
	for tid in tower_ids:
		unlocked_set[tid] = true

	# Collect all build_entry towers from catalog, grouped by combo_type
	var sections: Dictionary = {
		"neutral": [],
		"single": [],
		"dual": [],
		"triple": [],
		"pure": [],
		"periodic": [],
	}
	for tower_id in tower_catalog.keys():
		var cfg: Dictionary = tower_catalog[tower_id]
		if not bool(cfg.get("build_entry", false)):
			continue
		var combo: String = str(cfg.get("combo_type", "neutral"))
		if not sections.has(combo):
			sections[combo] = []
		sections[combo].append({"id": str(tower_id), "cfg": cfg})

	# Sort each section by shop_order
	for key in sections:
		sections[key].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["cfg"].get("shop_order", 9999)) < int(b["cfg"].get("shop_order", 9999))
		)

	# Section display config
	var section_order: Array[String] = ["neutral", "single", "dual", "triple", "pure", "periodic"]
	var section_labels: Dictionary = {
		"neutral": "Neutral",
		"single": "Single Element",
		"dual": "Dual Element",
		"triple": "Triple Element",
		"pure": "Pure",
		"periodic": "Periodic",
	}

	for section_key in section_order:
		var entries: Array = sections.get(section_key, [])
		var visible_entries := _get_tower_section_visible_entries(section_key, entries, unlocked_set)
		var show_hint := _should_show_section_unlock_hint(section_key, entries, visible_entries)
		if visible_entries.is_empty() and not show_hint:
			continue

		_add_tower_section_header(section_key, str(section_labels.get(section_key, section_key.to_upper())))

		for entry in visible_entries:
			var tower_id: String = entry["id"]
			var cfg: Dictionary = entry["cfg"]
			var is_unlocked: bool = unlocked_set.has(tower_id)
			_add_tower_shop_button(tower_id, cfg, is_unlocked)

		if show_hint:
			_add_tower_section_hint(_get_section_unlock_hint(section_key, visible_entries.is_empty()))

	_refresh_element_mastery_strip()

	_update_tower_affordability(_get_current_gold_for_hud())
	if tower_shop_scroll:
		tower_shop_scroll.set_deferred("scroll_vertical", 0)

func _add_tower_shop_button(tower_id: String, cfg: Dictionary, is_unlocked: bool) -> void:
	var cost: int = int(tower_prices.get(tower_id, cfg.get("cost", 50)))
	var el_array: Array = cfg.get("elements", [])
	var btn := Button.new()
	btn.name = "TowerButton_%s" % tower_id
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = false
	btn.custom_minimum_size.y = 46
	btn.text = ""
	var display_name := _get_tower_shop_display_name(tower_id, cfg)

	if is_unlocked:
		# btn.tooltip_text = _build_tower_tooltip(tower_id, cfg, cost)
		var captured_tower_id: String = tower_id
		var captured_cfg: Dictionary = cfg
		var captured_cost: int = cost
		var captured_button: Button = btn
		btn.pressed.connect(func(): _on_tower_btn_pressed(captured_tower_id, captured_button))

		# Desktop: hover in/out controls the card.
		btn.mouse_entered.connect(func():
			_update_tower_row_trim(captured_button, true)
			_show_hover_card(captured_tower_id, captured_cfg, captured_cost, captured_button))
		btn.mouse_exited.connect(func():
			_update_tower_row_trim(captured_button, false)
			_hide_hover_card())

		# Mobile/touch: long-press (≥0.45s) shows the card; release hides it.
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventScreenTouch:
				if ev.pressed:
					_hover_long_press_timer = get_tree().create_timer(0.45)
					_hover_long_press_timer.timeout.connect(func():
						_show_hover_card(captured_tower_id, captured_cfg, captured_cost, captured_button))
				else:
					_hover_long_press_timer = null
					_hide_hover_card())
	else:
		btn.disabled = true
		btn.tooltip_text = _build_locked_tooltip(tower_id, cfg, cost)
	_style_tower_shop_button(btn, is_unlocked)
	_populate_tower_row_button(btn, display_name, cost, el_array, is_unlocked)

	tower_shop_list.add_child(btn)
	dynamic_tower_buttons[tower_id] = btn

func _populate_tower_row_button(btn: Button, display_name: String, cost: int, elements: Array, is_unlocked: bool) -> void:
	btn.set_meta("tower_id", btn.name.replace("TowerButton_", ""))
	btn.set_meta("row_elements", elements.duplicate(true))
	btn.set_meta("row_locked", not is_unlocked)
	btn.set_meta("row_affordable", true)
	btn.set_meta("row_hovered", false)

	var trim := TowerRowTrimControl.new()
	trim.name = "RowTrim"
	trim.set_anchors_preset(Control.PRESET_FULL_RECT)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(trim)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left   = 12
	row.offset_top    = 0
	row.offset_right  = -8
	row.offset_bottom = 0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	btn.add_child(row)

	var icon := _create_element_icon(elements, is_unlocked)
	if not is_unlocked:
		icon.modulate = Color(1.0, 1.0, 1.0, 0.86)
	row.add_child(icon)

	# Name + optional requirement sub-label in VBox
	var name_col := VBoxContainer.new()
	name_col.name = "NameColumn"
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_theme_constant_override("separation", 1)
	row.add_child(name_col)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name if is_unlocked else _compact_tower_display_name(display_name)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color",
		NeonStyle.INK_1 if is_unlocked else NeonStyle.INK_3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_child(name_label)

	if not is_unlocked and not elements.is_empty():
		var req_label := Label.new()
		req_label.name = "RequireLabel"
		req_label.text = _format_tower_requirement(elements)
		req_label.add_theme_font_size_override("font_size", 10)
		req_label.add_theme_color_override("font_color", NeonStyle.INK_3)
		req_label.clip_text = true
		req_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_col.add_child(req_label)

	if is_unlocked:
		var cost_display := CreditCostDisplayControl.new()
		cost_display.name = "CostDisplay"
		cost_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_display.configure(cost, true)
		row.add_child(cost_display)
	else:
		var cost_label := Label.new()
		cost_label.name = "CostLabel"
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.text = "LOCKED"
		cost_label.custom_minimum_size.x = 54
		cost_label.add_theme_font_size_override("font_size", 9)
		cost_label.add_theme_color_override("font_color", NeonStyle.INK_4)
		row.add_child(cost_label)
	_update_tower_row_trim(btn, false)

func _get_tower_shop_display_name(tower_id: String, cfg: Dictionary) -> String:
	var raw_name := str(cfg.get("display_name", cfg.get("name", tower_id)))
	var compact := _compact_tower_display_name(raw_name)
	var normalized_id := tower_id.to_lower()
	if normalized_id.contains("arrow"):
		return "Arrow"
	if normalized_id.contains("cannon"):
		return "Cannon"
	if compact.is_empty() or compact == "/" or compact == "(":
		return tower_id.capitalize().replace("_", " ")
	return compact

func _format_tower_cost(cost: int) -> String:
	if cost < 0:
		return "—"
	return str(cost)

func _format_tower_requirement(elements: Array) -> String:
	if elements.is_empty():
		return "Locked"
	if elements.size() == 1:
		return "Requires %s" % _element_label(str(elements[0]))
	return "Requires %s" % _elements_full(elements)

func _add_tower_section_header(section_key: String, label_text: String) -> void:
	var header := _make_build_section_header(label_text, false)
	header.name = "SectionHeader_%s" % section_key
	# Top margin spacer for visual breathing room between sections
	if tower_shop_list.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 5
		tower_shop_list.add_child(spacer)
	tower_shop_list.add_child(header)

func _make_build_section_header(label_text: String, important: bool = false) -> BuildSectionHeaderControl:
	var header := BuildSectionHeaderControl.new()
	header.custom_minimum_size = Vector2(0, 24)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.configure(label_text, NeonStyle.CYAN, not important)
	return header

func _add_tower_section_hint(text: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "SectionHint"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Dashed-border hint panel matching reference
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.03)
	style.border_color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	tower_shop_list.add_child(panel)

	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", NeonStyle.INK_3)
	panel.add_child(label)

func _get_tower_section_visible_entries(section_key: String, entries: Array, unlocked_set: Dictionary) -> Array:
	if section_key == "neutral" or section_key == "single":
		return entries
	var visible: Array = []
	for entry in entries:
		if unlocked_set.has(str(entry["id"])):
			visible.append(entry)
	return visible

func _should_show_section_unlock_hint(section_key: String, entries: Array, visible_entries: Array) -> bool:
	if section_key == "dual" or section_key == "triple":
		return not entries.is_empty() and visible_entries.size() < entries.size()
	return false

func _get_section_unlock_hint(section_key: String, is_empty_section: bool) -> String:
	if section_key == "dual":
		return "Unlock 2 elements to reveal dual towers" if is_empty_section else "Unlock 2 elements to reveal more dual towers"
	if section_key == "triple":
		return "Unlock 3 elements to reveal triple element towers" if is_empty_section else "Unlock 3 elements to reveal more triple towers"
	return "Unlock more elements to reveal towers"

func _style_tower_shop_button(btn: Button, is_unlocked: bool) -> void:
	var normal   := NeonStyle.row_normal(is_unlocked)
	var hover_sb := NeonStyle.row_hover()
	var pressed  := NeonStyle.row_normal(is_unlocked)
	pressed.bg_color = NeonStyle.BG_3
	var disabled := NeonStyle.row_normal(false)
	disabled.bg_color = Color(NeonStyle.BG_1.r, NeonStyle.BG_1.g, NeonStyle.BG_1.b, 0.78)
	disabled.border_color = Color(NeonStyle.LINE.r, NeonStyle.LINE.g, NeonStyle.LINE.b, 0.16)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover_sb if is_unlocked else disabled)
	btn.add_theme_stylebox_override("pressed",  pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",          SHOP_ENABLED_TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color",    NeonStyle.CYAN_2)
	btn.add_theme_color_override("font_disabled_color", NeonStyle.INK_4)

func _build_locked_tooltip(tower_id: String, cfg: Dictionary, cost: int) -> String:
	var desc: String = str(cfg.get("description", ""))
	var elements_text: String = _elements_full(cfg.get("elements", []))
	var required_lvl: int = int(cfg.get("required_element_level", 1))
	var missing_parts: Array[String] = []
	for raw_el in cfg.get("elements", []):
		var el_id: String = str(raw_el)
		var owned: int = int(current_element_levels.get(el_id, 0))
		if owned < required_lvl:
			missing_parts.append("%s Lv.%d" % [_element_label(el_id), required_lvl])
	var lock_reason: String = "Requires: " + ", ".join(missing_parts) if not missing_parts.is_empty() else "Locked"
	return "%s\n\nElements: %s\n%s\nCost: %d Credits" % [desc, elements_text, lock_reason, cost]

func _create_element_icon(raw_elements: Array, is_unlocked: bool) -> ElementIconControl:
	var icon := ElementIconControl.new()
	icon.name = "ElementIcon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_width := 34
	if raw_elements.size() == 2:
		icon_width = 50
	elif raw_elements.size() >= 3:
		icon_width = 64
	icon.custom_minimum_size = Vector2(icon_width, 34)
	icon.configure(raw_elements, is_unlocked)
	return icon

func _update_tower_row_trim(btn: Button, hovered: bool) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.set_meta("row_hovered", hovered)
	var trim := btn.get_node_or_null("RowTrim") as TowerRowTrimControl
	if trim == null:
		return
	var tower_id := str(btn.get_meta("tower_id", btn.name.replace("TowerButton_", "")))
	var elements: Array = btn.get_meta("row_elements", [])
	var locked := bool(btn.get_meta("row_locked", btn.disabled))
	var affordable := bool(btn.get_meta("row_affordable", true))
	var selected := not active_build_tower_id.is_empty() and tower_id == active_build_tower_id
	trim.configure(elements, locked, affordable, selected, hovered)

func _set_active_build_row(tower_id: String) -> void:
	if active_build_tower_id == tower_id:
		return
	active_build_tower_id = tower_id
	for button_id in dynamic_tower_buttons.keys():
		var btn := dynamic_tower_buttons[button_id] as Button
		if btn != null and is_instance_valid(btn):
			_update_tower_row_trim(btn, bool(btn.get_meta("row_hovered", false)))

func _element_badge_color(raw_elements: Array, is_unlocked: bool) -> Color:
	if not is_unlocked:
		return Color(0.25, 0.28, 0.33, 0.96)
	if raw_elements.is_empty():
		return Color(0.56, 0.62, 0.7, 0.9)
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	for raw in raw_elements:
		var color := _get_element_ui_color(str(raw))
		red += color.r
		green += color.g
		blue += color.b
	var count := float(raw_elements.size())
	var mixed := Color(red / count, green / count, blue / count, 0.92)
	return mixed.lightened(0.18)

func _compact_tower_display_name(display_name: String) -> String:
	var compact := display_name
	compact = compact.replace("Neutral ", "")
	compact = compact.replace(" Tower III", "")
	compact = compact.replace(" Tower II", "")
	compact = compact.replace(" Tower I", "")
	compact = compact.replace(" Tower 3", "")
	compact = compact.replace(" Tower 2", "")
	compact = compact.replace(" Tower 1", "")
	compact = compact.replace(" Tower", "")
	compact = compact.replace(" III", "")
	compact = compact.replace(" II", "")
	compact = compact.replace(" I", "")
	compact = compact.replace(" 3", "")
	compact = compact.replace(" 2", "")
	compact = compact.replace(" 1", "")
	return compact.strip_edges()

func set_tower_catalog(catalog: Dictionary) -> void:
	tower_catalog = catalog.duplicate(true)
	for tower_id in tower_catalog.keys():
		var cfg: Dictionary = tower_catalog[tower_id]
		if not tower_prices.has(tower_id):
			tower_prices[tower_id] = int(cfg.get("cost", 0))

func set_tower_prices(prices: Dictionary) -> void:
	tower_prices = prices

func set_element_levels(levels: Dictionary) -> void:
	current_element_levels = levels.duplicate(true)
	_refresh_element_mastery_strip()

func show_element_choice(levels: Dictionary, pending_picks: int = 1, interest_rate_label: String = "2%", next_interest_rate_label: String = "3%", can_upgrade_interest: bool = true, interest_upgrade_count: int = 0, interest_max_upgrades: int = 5) -> void:
	_ensure_element_modal()
	set_element_levels(levels)
	_em_data = {
		"levels": levels,
		"pending_picks": pending_picks,
		"interest_rate": interest_rate_label,
		"next_interest_rate": next_interest_rate_label,
		"interest_preview_label": "Interest  %s  →  %s" % [interest_rate_label, next_interest_rate_label],
		"can_upgrade_interest": can_upgrade_interest,
		"interest_upgrade_count": interest_upgrade_count,
		"interest_max_upgrades": interest_max_upgrades,
	}
	if _em_picks_label:
		_em_picks_label.text = "Choose one element to continue"
	if _em_close_btn:
		_em_close_btn.visible = pending_picks <= 0
		_em_close_btn.disabled = pending_picks > 0
	_em_rebuild_cards()
	# Auto-select first unlockable option
	var first_id := ""
	for eid in ["light", "darkness", "water", "fire", "nature", "earth"]:
		if int(levels.get(eid, 0)) < 3:
			first_id = eid
			break
	if first_id.is_empty() and can_upgrade_interest:
		first_id = "__interest__"
	if first_id.is_empty():
		first_id = "light"
	_em_select(first_id)
	if _em_overlay:
		_em_overlay.visible = true

func hide_element_choice(force: bool = false) -> void:
	if _em_pick_required() and not force:
		if _em_picks_label:
			_em_picks_label.text = "Choose one element to continue"
		return
	_hide_element_choice_now()

func _hide_element_choice_now() -> void:
	if _em_overlay:
		_em_overlay.visible = false
	if element_choice_panel:
		element_choice_panel.hide()

func _em_pick_required() -> bool:
	return int(_em_data.get("pending_picks", 0)) > 0

func _ensure_elemental_shop_ui() -> void:
	if tower_shop_list != null and is_instance_valid(tower_shop_list):
		return
	var container := basic_tower_button.get_parent()
	if container == null:
		return
	_hide_static_tower_buttons()

	var old_spacer := container.get_node_or_null("Spacer")
	if old_spacer is Control:
		old_spacer.hide()
		old_spacer.custom_minimum_size = Vector2.ZERO
		old_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_ensure_build_towers_header_ui(container)

	tower_shop_scroll = ScrollContainer.new()
	tower_shop_scroll.name = "ElementalTowerShopScroll"
	tower_shop_scroll.custom_minimum_size = Vector2(0, 260)
	tower_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tower_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(tower_shop_scroll)
	container.move_child(tower_shop_scroll, build_towers_header_block.get_index() + 1)

	tower_shop_list = VBoxContainer.new()
	tower_shop_list.name = "ElementalTowerShopList"
	tower_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tower_shop_list.add_theme_constant_override("separation", 4)
	tower_shop_scroll.add_child(tower_shop_list)
	_sync_tower_shop_list_width()

	var bottom_separator := ColorRect.new()
	bottom_separator.name = "TowerPanelBottomSeparator"
	bottom_separator.custom_minimum_size.y = 1
	bottom_separator.color = NeonStyle.LINE
	container.add_child(bottom_separator)
	container.move_child(bottom_separator, build_status_label.get_index())
	build_panel_bottom_separator = bottom_separator

	NeonStyle.apply_terminal_label(build_status_label, 11, NeonStyle.INK_3)
	cancel_build_button.custom_minimum_size.y = 44
	_refresh_element_mastery_strip()
	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()

func _ensure_build_towers_header_ui(container: Control) -> void:
	if build_towers_header_block != null and is_instance_valid(build_towers_header_block):
		return
	if container is VBoxContainer:
		_ensure_left_drawer_headers(container)
	var old_title := container.get_node_or_null("Label")
	if old_title is Control:
		old_title.hide()
		old_title.custom_minimum_size = Vector2.ZERO
	var old_separator := container.get_node_or_null("HSeparator")
	if old_separator is Control:
		old_separator.hide()
		old_separator.custom_minimum_size = Vector2.ZERO

	build_towers_header_block = VBoxContainer.new()
	build_towers_header_block.name = "BuildTowersHeaderBlock"
	build_towers_header_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_towers_header_block.add_theme_constant_override("separation", 6)
	container.add_child(build_towers_header_block)
	if damage_stats_header_button:
		container.move_child(build_towers_header_block, damage_stats_header_button.get_index() + 1)
	else:
		container.move_child(build_towers_header_block, basic_tower_button.get_index())

	var divider := ColorRect.new()
	divider.name = "BuildTowersDivider"
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.45)
	build_towers_header_block.add_child(divider)

	element_status_label = Label.new()
	element_status_label.name = "ElementStatusLabel"
	element_status_label.visible = false
	element_status_label.custom_minimum_size = Vector2.ZERO

	var mastery_row := _make_build_section_header("Element Mastery", true)
	mastery_row.name = "ElementMasteryTitleRow"
	build_towers_header_block.add_child(mastery_row)

	element_mastery_grid = GridContainer.new()
	element_mastery_grid.name = "ElementMasteryGrid"
	element_mastery_grid.columns = 2
	element_mastery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_mastery_grid.add_theme_constant_override("h_separation", 6)
	element_mastery_grid.add_theme_constant_override("v_separation", 5)
	build_towers_header_block.add_child(element_mastery_grid)

	for element_id in ELEMENT_ORDER:
		var chip := _make_element_mastery_chip(element_id)
		element_mastery_grid.add_child(chip)

	build_towers_header_block.add_child(_make_element_hint_card())

func _make_element_hint_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ElementHintCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 38)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.055)
	style.border_color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.28)
	style.set_border_width_all(1)
	style.set_border_width(SIDE_LEFT, 3)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.name = "HintRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 7)
	card.add_child(row)

	var info_chip := PanelContainer.new()
	info_chip.name = "HintInfoChip"
	info_chip.custom_minimum_size = Vector2(20, 20)
	info_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.10)
	chip_style.border_color = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.46)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(3)
	chip_style.content_margin_left = 0
	chip_style.content_margin_right = 0
	chip_style.content_margin_top = 0
	chip_style.content_margin_bottom = 0
	info_chip.add_theme_stylebox_override("panel", chip_style)
	row.add_child(info_chip)

	var hint_icon := Label.new()
	hint_icon.name = "HintIcon"
	hint_icon.text = "i"
	hint_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_icon.add_theme_font_size_override("font_size", 11)
	hint_icon.add_theme_color_override("font_color", NeonStyle.CYAN)
	info_chip.add_child(hint_icon)

	element_hint_label = Label.new()
	element_hint_label.name = "ElementHintLabel"
	element_hint_label.text = "Choose elements between waves to unlock tower paths."
	element_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	element_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	element_hint_label.add_theme_font_size_override("font_size", 10)
	element_hint_label.add_theme_color_override("font_color", NeonStyle.INK_2)
	row.add_child(element_hint_label)

	return card

func _make_element_mastery_chip(element_id: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "ElementChip_%s" % element_id.capitalize()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0, 40)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)

	var icon := ElementIconControl.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure([element_id], false)
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.name = "Text"
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 0)
	row.add_child(text_col)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = str(ELEMENT_SHORT_LABELS.get(element_id, _element_label(element_id)))
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 10)
	text_col.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Locked"
	level_label.clip_text = true
	level_label.add_theme_font_size_override("font_size", 10)
	text_col.add_child(level_label)

	element_chip_nodes[element_id] = {
		"panel": chip,
		"icon": icon,
		"name": name_label,
		"level": level_label,
	}
	return chip

func _refresh_element_mastery_strip() -> void:
	if element_mastery_grid == null or not is_instance_valid(element_mastery_grid):
		return
	for element_id in ELEMENT_ORDER:
		var nodes: Dictionary = element_chip_nodes.get(element_id, {})
		if nodes.is_empty():
			continue
		var level := int(current_element_levels.get(element_id, 0))
		var unlocked := level > 0
		var color := _get_element_ui_color(element_id)
		var panel := nodes.get("panel") as PanelContainer
		if panel:
			panel.add_theme_stylebox_override("panel", _element_mastery_chip_style(color, unlocked))
			panel.tooltip_text = "%s mastery level %d" % [_element_label(element_id), level]
		var icon := nodes.get("icon") as ElementIconControl
		if icon:
			icon.configure([element_id], unlocked)
		var name_label := nodes.get("name") as Label
		if name_label:
			name_label.add_theme_color_override("font_color", NeonStyle.INK_1 if unlocked else NeonStyle.INK_3)
		var level_label := nodes.get("level") as Label
		if level_label:
			level_label.text = "Lv. %d" % level if unlocked else "Locked"
			level_label.add_theme_color_override("font_color", color if unlocked else NeonStyle.INK_4)
	if element_hint_label:
		element_hint_label.text = "Choose elements between waves to unlock tower paths."

func _element_mastery_chip_style(color: Color, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.105) if unlocked else Color(NeonStyle.BG_0.r, NeonStyle.BG_0.g, NeonStyle.BG_0.b, 0.72)
	style.border_color = Color(color.r, color.g, color.b, 0.54) if unlocked else Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	if unlocked:
		style.set_border_width(SIDE_LEFT, 3)
	return style

func _sync_tower_shop_list_width() -> void:
	if tower_shop_list == null or not is_instance_valid(tower_shop_list):
		return
	var sidebar_width := 310.0
	if left_sidebar:
		sidebar_width = left_sidebar.size.x if left_sidebar.size.x > 0.0 else left_sidebar.custom_minimum_size.x
	var content_width: float = max(210.0, sidebar_width - 42.0)
	tower_shop_list.custom_minimum_size.x = content_width

## ── Element Modal builder (UI-ELEMENT-1) ─────────────────────────────────────
## Built once; show/hide by toggling _em_overlay.visible.

func _em_sb(fill: Color, border: Color = Color.TRANSPARENT, bw: float = 1.5, r: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(int(bw))
	s.set_corner_radius_all(int(r))
	return s

func _em_lbl(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_FILL
	return l

func _em_sec_hdr(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	for _i in range(2):
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(16, 2)
		bar.add_theme_stylebox_override("panel", _em_sb(Color(0.25, 0.55, 0.9, 0.45)))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		if _i == 0:
			var lbl := _em_lbl("  %s  " % text, 11, Color(0.45, 0.78, 1.0, 0.85))
			lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			row.add_child(lbl)
	return row

func _em_chip(text: String, col: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _em_sb(Color(col.r, col.g, col.b, 0.18), Color(col.r, col.g, col.b, 0.65), 1.0, 4.0))
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col.lightened(0.25))
	chip.add_child(lbl)
	return chip

func _ensure_element_modal() -> void:
	if _em_overlay != null and is_instance_valid(_em_overlay):
		return
	if root == null:
		return

	# Full-screen dim
	_em_overlay = Control.new()
	_em_overlay.name = "ElementModalOverlay"
	_em_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_em_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_em_overlay.visible = false
	_em_overlay.z_index = 150
	root.add_child(_em_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.010, 0.026, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_em_overlay.add_child(dim)

	# Centered modal card
	_em_panel = PanelContainer.new()
	_em_panel.name = "ElementModalPanel"
	_em_panel.set_anchors_preset(Control.PRESET_CENTER)
	_em_panel.custom_minimum_size = Vector2(1320, 720)
	_em_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_em_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_em_panel.add_theme_stylebox_override("panel", NeonStyle.panel(NeonStyle.PANEL_DENSE, NeonStyle.CYAN_DIM, true))
	_em_overlay.add_child(_em_panel)

	var outer := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		outer.add_theme_constant_override("margin_"+s, 22)
	_em_panel.add_child(outer)

	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 12)
	outer.add_child(main_v)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	main_v.add_child(title_row)

	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_theme_constant_override("separation", 3)
	title_row.add_child(head_col)
	var t1 := _em_lbl("CHOOSE ELEMENT", 22, NeonStyle.CYAN)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head_col.add_child(t1)
	var t2 := _em_lbl("Choose one element to unlock new towers before the next wave.", 12, NeonStyle.TEXT_DIM)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head_col.add_child(t2)

	_em_picks_label = Label.new()
	_em_picks_label.add_theme_font_size_override("font_size", 13)
	_em_picks_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.22))
	_em_picks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_em_picks_label)

	_em_close_btn = Button.new()
	_em_close_btn.text = "X"
	_em_close_btn.custom_minimum_size = Vector2(38, 38)
	_em_close_btn.add_theme_font_size_override("font_size", 16)
	_em_close_btn.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	NeonStyle.style_button(_em_close_btn)
	_em_close_btn.pressed.connect(hide_element_choice)
	title_row.add_child(_em_close_btn)

	var hdiv := HSeparator.new()
	hdiv.add_theme_color_override("color", Color(0.2, 0.48, 0.82, 0.4))
	main_v.add_child(hdiv)

	# 3-column body
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 0)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_v.add_child(cols)

	# ── Left column (element list) ──
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 252
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)

	var left_v := VBoxContainer.new()
	left_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left_v)

	var left_hdr := _em_lbl("ELEMENTS", 11, NeonStyle.TEXT_DIM)
	left_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_v.add_child(left_hdr)
	var left_gap := Control.new()
	left_gap.custom_minimum_size.y = 2
	left_v.add_child(left_gap)

	_em_card_container = VBoxContainer.new()
	_em_card_container.add_theme_constant_override("separation", 5)
	_em_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_v.add_child(_em_card_container)

	# ── VSep ──
	var vs1 := VSeparator.new()
	vs1.add_theme_color_override("color", Color(0.2, 0.48, 0.82, 0.3))
	vs1.custom_minimum_size.x = 14
	cols.add_child(vs1)

	# ── Center column (details) ──
	var ctr_scroll := ScrollContainer.new()
	ctr_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctr_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	ctr_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(ctr_scroll)

	_em_center_col = VBoxContainer.new()
	_em_center_col.name = "EmCenterCol"
	_em_center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_em_center_col.add_theme_constant_override("separation", 10)
	ctr_scroll.add_child(_em_center_col)

	# ── VSep ──
	var vs2 := VSeparator.new()
	vs2.add_theme_color_override("color", Color(0.2, 0.48, 0.82, 0.3))
	vs2.custom_minimum_size.x = 14
	cols.add_child(vs2)

	# ── Right column (summary) ──
	_em_right_col = VBoxContainer.new()
	_em_right_col.name = "EmRightCol"
	_em_right_col.custom_minimum_size.x = 276
	_em_right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_em_right_col.add_theme_constant_override("separation", 10)
	cols.add_child(_em_right_col)

# Rebuild left-column element cards from current _em_data.
func _em_rebuild_cards() -> void:
	if not is_instance_valid(_em_card_container):
		return
	for c in _em_card_container.get_children():
		c.queue_free()
	_em_card_nodes.clear()

	var levels: Dictionary = _em_data.get("levels", {})
	var all_ids := ["light","darkness","water","fire","nature","earth","__interest__"]
	for element_id in all_ids:
		if element_id == "__interest__":
			var sp := Control.new()
			sp.custom_minimum_size.y = 4
			_em_card_container.add_child(sp)
		var card := _em_make_card(element_id, levels)
		_em_card_container.add_child(card)
		_em_card_nodes[element_id] = card

func _em_make_card(element_id: String, levels: Dictionary) -> PanelContainer:
	var el_col := _get_element_ui_color(element_id) if element_id != "__interest__" else Color(0.68, 0.5, 1.0)
	var cur_lv  := int(levels.get(element_id, 0)) if element_id != "__interest__" else -1
	var is_max  := element_id != "__interest__" and cur_lv >= 3
	var is_lock : bool = element_id == "__interest__" and not _em_data.get("can_upgrade_interest", true)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 58)
	card.size_flags_horizontal = Control.SIZE_FILL

	var s_normal := _em_sb(Color(0.07,0.09,0.14),   Color(0.2,0.32,0.52,0.5),  1.5, 6.0)
	var s_hover  := _em_sb(Color(0.10,0.13,0.20),   Color(el_col.r,el_col.g,el_col.b,0.7), 1.5, 6.0)
	var s_lock   := _em_sb(Color(0.05,0.06,0.09,0.7),Color(0.15,0.22,0.32,0.3), 1.0, 6.0)
	card.add_theme_stylebox_override("panel", s_lock if (is_max or is_lock) else s_normal)
	card.set_meta("s_normal", s_normal)
	card.set_meta("s_hover",  s_hover)
	card.set_meta("s_lock",   s_lock)
	card.set_meta("el_col",   el_col)
	card.set_meta("el_id",    element_id)
	card.set_meta("option_type", _em_option_type(element_id))
	card.set_meta("is_max",   is_max)
	card.set_meta("is_lock",  is_lock)

	var mg := MarginContainer.new()
	for sd in ["left","right","top","bottom"]:
		mg.add_theme_constant_override("margin_"+sd, 8)
	card.add_child(mg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	mg.add_child(row)

	# Icon badge — [DEPLOY-FIX] drawn icon replaces Unicode Label glyph.
	var icon_p := PanelContainer.new()
	icon_p.custom_minimum_size = Vector2(36, 36)
	var ic_dim := Color(el_col.r, el_col.g, el_col.b, 0.2 if (is_max or is_lock) else 0.32)
	var ic_brd := Color(el_col.r, el_col.g, el_col.b, 0.45 if not (is_max or is_lock) else 0.2)
	icon_p.add_theme_stylebox_override("panel", _em_sb(ic_dim, ic_brd, 1.5, 18.0))
	row.add_child(icon_p)
	var icon_draw := ElementIconDraw.new()
	icon_draw.element_id = element_id
	icon_draw.icon_alpha = 0.55 if (is_max or is_lock) else 1.0
	icon_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_p.add_child(icon_draw)

	# Text
	var txt_v := VBoxContainer.new()
	txt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_v.add_theme_constant_override("separation", 2)
	row.add_child(txt_v)

	var name_l := Label.new()
	name_l.text = _element_label(element_id) if element_id != "__interest__" else "Interest Bonus"
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", el_col.lightened(0.18) if not (is_max or is_lock) else Color(0.38,0.48,0.58))
	txt_v.add_child(name_l)

	var sub_l := Label.new()
	sub_l.add_theme_font_size_override("font_size", 11)
	if element_id == "__interest__":
		var ir : String = _em_data.get("interest_rate","2%")
		var nr : String = _em_data.get("next_interest_rate","3%")
		if is_lock:
			sub_l.text = "Max upgrades reached"
			sub_l.add_theme_color_override("font_color", Color(0.45,0.45,0.45))
		else:
			sub_l.text = "%s  →  %s" % [ir, nr]
			sub_l.add_theme_color_override("font_color", Color(0.9,0.72,0.22))
	elif is_max:
		sub_l.text = "Lv.3  ●  MAX"
		sub_l.add_theme_color_override("font_color", Color(0.45,0.45,0.45))
	else:
		sub_l.text = "Lv.%d  →  Lv.%d" % [cur_lv, cur_lv+1]
		sub_l.add_theme_color_override("font_color", Color(0.5,0.74,0.9))
	txt_v.add_child(sub_l)

	# Hover & click (only for selectable cards)
	if not is_max and not is_lock:
		card.mouse_entered.connect(func():
			if _em_selected != element_id:
				card.add_theme_stylebox_override("panel", s_hover))
		card.mouse_exited.connect(func():
			if _em_selected != element_id:
				card.add_theme_stylebox_override("panel", s_normal))
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_em_select(element_id))
	return card

# Select an element and rebuild center + right columns.
func _em_select(element_id: String) -> void:
	_em_selected = element_id
	for eid in _em_card_nodes:
		var card: PanelContainer = _em_card_nodes[eid]
		if not is_instance_valid(card):
			continue
		var is_max: bool  = card.get_meta("is_max",  false)
		var is_lock: bool = card.get_meta("is_lock", false)
		if is_max or is_lock:
			continue
		if eid == element_id:
			var ec: Color = card.get_meta("el_col", Color.WHITE)
			card.add_theme_stylebox_override("panel", _em_sb(Color(ec.r,ec.g,ec.b,0.22), ec, 2.0, 6.0))
		else:
			card.add_theme_stylebox_override("panel", card.get_meta("s_normal"))
	_em_rebuild_center(element_id)
	_em_rebuild_right(element_id)

# Rebuild center detail column.
func _em_rebuild_center(element_id: String) -> void:
	if not is_instance_valid(_em_center_col):
		return
	for c in _em_center_col.get_children():
		c.queue_free()

	var levels: Dictionary = _em_data.get("levels", {})
	var el_col  := _get_element_ui_color(element_id) if element_id != "__interest__" else Color(0.68,0.5,1.0)
	var meta_d  : Dictionary = ELEMENT_UI_META.get(element_id, {})

	# Header row: large icon + name
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 14)
	_em_center_col.add_child(hdr)

	var big_icon := PanelContainer.new()
	big_icon.custom_minimum_size = Vector2(70, 70)
	big_icon.add_theme_stylebox_override("panel", _em_sb(Color(el_col.r,el_col.g,el_col.b,0.18), el_col.darkened(0.28), 2.0, 35.0))
	hdr.add_child(big_icon)
	# [DEPLOY-FIX] Drawn icon replaces Unicode Label glyph for the detail view header.
	var big_icon_draw := ElementIconDraw.new()
	big_icon_draw.element_id = element_id if element_id != "__interest__" else "__interest__"
	big_icon_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_icon.add_child(big_icon_draw)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 4)
	hdr.add_child(name_col)

	var en := _element_label(element_id) if element_id != "__interest__" else "Interest Bonus"
	var name_l := _em_lbl(en.to_upper(), 24, el_col)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_col.add_child(name_l)

	var desc_l := _em_lbl(meta_d.get("description",""), 13, Color(0.72,0.82,0.92))
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(desc_l)

	if element_id == "__interest__":
		var ir_l := _em_lbl("Interest  %s  →  %s" % [_em_data.get("interest_rate","2%"), _em_data.get("next_interest_rate","3%")], 12, Color(0.95,0.82,0.3))
		ir_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_col.add_child(ir_l)

	# Attack types
	_em_center_col.add_child(_em_sec_hdr("TOWER ATTACK TYPES"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_em_center_col.add_child(flow)
	for at in meta_d.get("attack_types", []):
		flow.add_child(_em_chip(at, el_col))

	# Unlock preview
	if element_id != "__interest__":
		_em_center_col.add_child(_em_sec_hdr("UNLOCK PREVIEW"))
		_em_build_unlock_preview(element_id, el_col)
	else:
		_em_center_col.add_child(_em_sec_hdr("ECONOMY PREVIEW"))
		_em_build_economy_preview()

	# Strengths & use case
	_em_center_col.add_child(_em_sec_hdr("STRENGTHS & USE CASE"))
	var use_v := VBoxContainer.new()
	use_v.add_theme_constant_override("separation", 4)
	_em_center_col.add_child(use_v)
	for s in meta_d.get("strengths", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		use_v.add_child(row)
		var dot := _em_lbl("✓", 12, Color(0.3,0.9,0.5))
		dot.custom_minimum_size.x = 18
		row.add_child(dot)
		row.add_child(_em_lbl(s, 12, Color(0.78,0.9,0.78)))
	for w in meta_d.get("weaknesses", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		use_v.add_child(row)
		var dot := _em_lbl("✗", 12, Color(0.9,0.4,0.3))
		dot.custom_minimum_size.x = 18
		row.add_child(dot)
		row.add_child(_em_lbl(w, 12, Color(0.85,0.68,0.62)))
	var best_l := _em_lbl("Best against: " + meta_d.get("best_against",""), 12, Color(0.62,0.84,1.0))
	best_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_em_center_col.add_child(best_l)
	var rec_l := _em_lbl("Tip: " + meta_d.get("recommended",""), 12, Color(0.88,0.76,0.38))
	rec_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_em_center_col.add_child(rec_l)
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size.y = 12
	_em_center_col.add_child(bottom_pad)

func _em_build_unlock_preview(element_id: String, el_col: Color) -> void:
	var preview := _em_get_unlock_preview_for_element(element_id)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	_em_center_col.add_child(wrap)

	var unlocked_now: Array = []
	unlocked_now.append_array(preview.get("single_element", []))
	unlocked_now.append_array(preview.get("dual_element", []))
	unlocked_now.append_array(preview.get("triple_element", []))

	var now_title := _em_lbl("Unlocked Now", 13, Color(0.78,0.92,1.0))
	now_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wrap.add_child(now_title)
	if unlocked_now.is_empty():
		var none := _em_lbl("No new tower unlocks at this level.", 12, Color(0.62,0.70,0.80))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrap.add_child(none)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		wrap.add_child(grid)
		for cfg in unlocked_now:
			grid.add_child(_em_make_tower_card(cfg, el_col))

	var future: Array = preview.get("enables_later", [])
	if not future.is_empty():
		wrap.add_child(_em_sec_hdr("ENABLES LATER"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		wrap.add_child(flow)
		var max_items: int = mini(future.size(), 10)
		for i in range(max_items):
			flow.add_child(_em_chip(str(future[i]), Color(el_col.r, el_col.g, el_col.b, 0.88)))
		if future.size() > max_items:
			flow.add_child(_em_chip("+%d more" % (future.size() - max_items), Color(0.55,0.70,0.82)))

func _em_build_economy_preview() -> void:
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	_em_center_col.add_child(bv)
	_em_bonus_row(bv, "Interest", _em_data.get("interest_rate","2%"), _em_data.get("next_interest_rate","3%"), Color(0.95,0.82,0.3))
	_em_bonus_row(bv, "Applies", "Every 15s", "", Color(0.6,0.8,1.0))
	_em_bonus_row(bv, "Tower unlocks", "No tower unlock", "", Color(0.62,0.72,0.84))
	_em_bonus_row(bv, "Timing", "Best if chosen early", "", Color(0.88,0.76,0.38))

func _em_make_tower_card(cfg: Dictionary, el_col: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _em_sb(Color(0.07,0.09,0.14), Color(el_col.r,el_col.g,el_col.b,0.3), 1.0, 5.0))
	var mg := MarginContainer.new()
	for sd in ["left","right","top","bottom"]:
		mg.add_theme_constant_override("margin_"+sd, 8)
	card.add_child(mg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	mg.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var tower_name := _compact_tower_display_name(str(cfg.get("display_name", cfg.get("name","Tower"))))
	info.add_child(_em_lbl(tower_name, 13, Color(0.9,0.92,1.0)))
	var elems: Array = cfg.get("elements",[])
	if not elems.is_empty():
		var combo := _format_element_combo_label(elems)
		var combo_l := _em_lbl(combo, 11, Color(0.58,0.78,0.94))
		combo_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(combo_l)

	var tags_v := VBoxContainer.new()
	tags_v.add_theme_constant_override("separation", 3)
	row.add_child(tags_v)

	var at := str(cfg.get("attack_type",""))
	tags_v.add_child(_em_chip(_em_attack_label(at), Color(0.38,0.72,1.0)))
	var tgt: Array = cfg.get("target_categories",["land"])
	var tgt_text := "Ground + Air" if (tgt.has("land") and tgt.has("air")) else ("Air Only" if tgt.has("air") else "Ground")
	tags_v.add_child(_em_chip(tgt_text, Color(0.45,0.82,0.55)))
	return card

func _em_attack_label(at: String) -> String:
	match at:
		"single": return "Single Target"
		"splash": return "AoE Splash"
		"slow":   return "Slow / Control"
		"chain":  return "Chain Lightning"
		"aura":   return "Aura / Debuff"
		"support_aura": return "Support Aura"
		"clone_support": return "Clone Support"
		_: return at.capitalize() if not at.is_empty() else "N/A"

func _em_bonus_row(parent: VBoxContainer, lbl_text: String, cur: String, nxt: String, vc: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var arrow := _em_lbl("▸", 11, Color(vc.r,vc.g,vc.b,0.7))
	arrow.custom_minimum_size.x = 16
	row.add_child(arrow)
	var n := _em_lbl(lbl_text, 12, Color(0.62,0.72,0.84))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var v_text := ("%s  →  %s" % [cur, nxt]) if not nxt.is_empty() else cur
	row.add_child(_em_lbl(v_text, 12, vc))

func _em_get_unlock_preview_for_element(element_id: String) -> Dictionary:
	var current_levels: Dictionary = _em_data.get("levels", {}).duplicate(true)
	var preview_levels := current_levels.duplicate(true)
	preview_levels[element_id] = min(int(preview_levels.get(element_id, 0)) + 1, 3)

	var current_unlocked := _em_get_unlocked_towers_for_levels(current_levels)
	var preview_unlocked := _em_get_unlocked_towers_for_levels(preview_levels)
	var out := {
		"single_element": [],
		"dual_element": [],
		"triple_element": [],
		"enables_later": _em_get_future_combo_labels(element_id, preview_levels),
	}

	for tower_id in preview_unlocked.keys():
		if current_unlocked.has(tower_id):
			continue
		var cfg: Dictionary = preview_unlocked[tower_id]
		var combo_type := str(cfg.get("combo_type", "single"))
		if combo_type == "dual":
			out["dual_element"].append(cfg)
		elif combo_type == "triple":
			out["triple_element"].append(cfg)
		else:
			out["single_element"].append(cfg)

	for key in ["single_element", "dual_element", "triple_element"]:
		out[key].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("shop_order", 9999)) < int(b.get("shop_order", 9999))
		)
	return out

func _em_get_unlocked_towers_for_levels(levels: Dictionary) -> Dictionary:
	var unlocked := {}
	for tower_id in tower_catalog.keys():
		var cfg: Dictionary = tower_catalog[tower_id]
		if not bool(cfg.get("build_entry", false)):
			continue
		if _em_can_build_tower_for_levels(cfg, levels):
			unlocked[str(tower_id)] = cfg
	return unlocked

func _em_can_build_tower_for_levels(cfg: Dictionary, levels: Dictionary) -> bool:
	var combo_type := str(cfg.get("combo_type", "neutral"))
	if combo_type == "neutral":
		return true
	var elements: Array = cfg.get("elements", [])
	if elements.is_empty():
		return true
	var required_level := int(cfg.get("required_element_level", 1))
	for raw_element in elements:
		if int(levels.get(str(raw_element), 0)) < required_level:
			return false
	return true

func _em_get_future_combo_labels(element_id: String, preview_levels: Dictionary) -> Array:
	var labels: Array[String] = []
	for tower_id in tower_catalog.keys():
		var cfg: Dictionary = tower_catalog[tower_id]
		if not bool(cfg.get("build_entry", false)):
			continue
		var combo_type := str(cfg.get("combo_type", ""))
		if combo_type != "dual" and combo_type != "triple":
			continue
		var elements: Array = cfg.get("elements", [])
		if not elements.has(element_id):
			continue
		if _em_can_build_tower_for_levels(cfg, preview_levels):
			continue
		var label := _format_element_combo_label(elements)
		if not labels.has(label):
			labels.append(label)
	labels.sort()
	return labels

func _format_element_combo_label(elements: Array) -> String:
	if elements.is_empty():
		return "Neutral"
	var parts: Array[String] = []
	for raw in elements:
		parts.append(_element_label(str(raw)))
	return " + ".join(parts)

# Rebuild right summary column.
func _em_rebuild_right(element_id: String) -> void:
	if not is_instance_valid(_em_right_col):
		return
	for c in _em_right_col.get_children():
		c.queue_free()
	_em_confirm_btn = null

	var levels : Dictionary = _em_data.get("levels", {})
	var el_col := _get_element_ui_color(element_id) if element_id != "__interest__" else Color(0.68,0.5,1.0)
	var is_max  := element_id != "__interest__" and int(levels.get(element_id,0)) >= 3
	var is_lock : bool = element_id == "__interest__" and not _em_data.get("can_upgrade_interest", true)

	_em_right_col.add_child(_em_sec_hdr("YOU WILL UNLOCK"))
	var get_v := VBoxContainer.new()
	get_v.add_theme_constant_override("separation", 5)
	_em_right_col.add_child(get_v)
	var items: Array[String]
	if element_id == "__interest__":
		items = ["Interest %s → %s" % [_em_data.get("interest_rate","2%"), _em_data.get("next_interest_rate","3%")], "No tower unlock"]
	else:
		items = _em_get_unlock_summary_names(element_id)
		if items.is_empty():
			items = ["No new tower unlocks"]
	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		get_v.add_child(row)
		var ck := _em_lbl("✓", 12, Color(0.3,0.9,0.5))
		ck.custom_minimum_size.x = 18
		row.add_child(ck)
		var il := _em_lbl(item, 12, Color(0.8,0.88,0.96))
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(il)

	# Push confirm to bottom
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_em_right_col.add_child(push)

	# Confirm button
	var btn_text: String
	if element_id == "__interest__":
		btn_text = "CHOOSE INTEREST BONUS"
	else:
		btn_text = "UNLOCK %s" % _element_label(element_id).to_upper()
	_em_confirm_btn = Button.new()
	_em_confirm_btn.text = btn_text
	_em_confirm_btn.disabled = is_max or is_lock
	_em_confirm_btn.custom_minimum_size = Vector2(0, 54)
	_em_confirm_btn.size_flags_horizontal = Control.SIZE_FILL
	_em_confirm_btn.add_theme_font_size_override("font_size", 15)
	if not (is_max or is_lock):
		var bf := Color(el_col.r*0.22, el_col.g*0.22, el_col.b*0.22, 1.0)
		var bh := Color(el_col.r*0.36, el_col.g*0.36, el_col.b*0.36, 1.0)
		_em_confirm_btn.add_theme_color_override("font_color", Color(1,1,1))
		_em_confirm_btn.add_theme_stylebox_override("normal",  _em_sb(bf, el_col, 2.0, 8.0))
		_em_confirm_btn.add_theme_stylebox_override("hover",   _em_sb(bh, el_col.lightened(0.25), 2.5, 8.0))
		_em_confirm_btn.add_theme_stylebox_override("pressed", _em_sb(el_col.darkened(0.4), el_col, 2.0, 8.0))
		var option := _em_make_pick_option(element_id)
		_em_confirm_btn.pressed.connect(func():
			if _em_confirm_btn:
				_em_confirm_btn.disabled = true
			element_choice_requested.emit(option))
	else:
		_em_confirm_btn.add_theme_stylebox_override("disabled", _em_sb(Color(0.08,0.1,0.14), Color(0.2,0.25,0.36,0.4), 1.0, 8.0))
		_em_confirm_btn.add_theme_color_override("font_disabled_color", Color(0.35,0.4,0.5))
	_em_right_col.add_child(_em_confirm_btn)

func _em_get_unlock_summary_names(element_id: String) -> Array[String]:
	var preview := _em_get_unlock_preview_for_element(element_id)
	var all: Array = []
	all.append_array(preview.get("single_element", []))
	all.append_array(preview.get("dual_element", []))
	all.append_array(preview.get("triple_element", []))
	var names: Array[String] = []
	for cfg in all:
		var name := _compact_tower_display_name(str(cfg.get("display_name", cfg.get("name", "Tower"))))
		if not names.has(name):
			names.append(name)
	return names

func _em_option_type(element_id: String) -> String:
	return "interest" if element_id == "__interest__" else "element"

func _em_make_pick_option(element_id: String) -> Dictionary:
	var option_type := _em_option_type(element_id)
	return {
		"option_type": option_type,
		"element_id": element_id if option_type == "element" else "",
	}

func _hide_static_tower_buttons() -> void:
	for btn in [basic_tower_button, rapid_tower_button, cannon_tower_button, slow_tower_button, sniper_tower_button, lightning_tower_button, sawblade_tower_button]:
		if btn:
			btn.hide()

func _clear_dynamic_tower_buttons() -> void:
	if tower_shop_list == null:
		return
	for child in tower_shop_list.get_children():
		child.queue_free()
	dynamic_tower_buttons.clear()
	active_build_tower_id = ""

func _format_tower_button_name(tower_id: String, cfg: Dictionary) -> String:
	var combo_type: String = str(cfg.get("combo_type", "neutral")).capitalize()
	var name: String = str(cfg.get("display_name", cfg.get("name", tower_id)))
	if combo_type != "Neutral":
		return "%s • %s" % [_elements_short(cfg.get("elements", [])), name]
	return name

func _build_tower_tooltip(tower_id: String, cfg: Dictionary, cost: int) -> String:
	return TowerEffectFormatter.build_tooltip(tower_id, cfg, cost, _elements_full)

func _elements_short(raw_elements: Array) -> String:
	if raw_elements.is_empty():
		return "N"
	# [DEPLOY-FIX] Use ElementIconDraw.get_short_code so numeric IDs never appear as-is.
	var out: Array[String] = []
	for raw in raw_elements:
		out.append(ElementIconDraw.get_short_code(str(raw)))
	return "+".join(out)

func _elements_full(raw_elements: Array) -> String:
	if raw_elements.is_empty():
		return "Neutral"
	var out: Array[String] = []
	for raw in raw_elements:
		out.append(_element_label(str(raw)))
	return " + ".join(out)

func _format_element_levels(levels: Dictionary) -> String:
	var parts: Array[String] = []
	for element_id in ["light", "darkness", "water", "fire", "nature", "earth"]:
		var level: int = int(levels.get(element_id, 0))
		if level > 0:
			parts.append("%s%d" % [_element_label(element_id).substr(0, 1), level])
	if parts.is_empty():
		return "Elements: None"
	return "Elements: " + " ".join(parts)

func _element_label(element_id: String) -> String:
	match element_id.to_lower():
		"0", "light":    return "Light"
		"1", "darkness": return "Darkness"
		"2", "water":    return "Water"
		"3", "fire":     return "Fire"
		"4", "nature":   return "Nature"
		"5", "earth":    return "Earth"
		"__interest__":  return "Interest"
		"":              return "Unknown"
		_:               return element_id.capitalize()

func _get_element_ui_color(element_id: String) -> Color:
	return NeonStyle.element_color(element_id)

func _get_current_gold_for_hud() -> int:
	var scene := get_tree().current_scene
	if scene:
		var gm := scene.get_node_or_null("GameManager")
		if gm:
			return int(gm.get("gold"))
	return 0

func set_lives(value: int) -> void:
	var old_text := lives_label.text
	lives_label.text = "● %d" % value
	var live_color := NeonStyle.CYAN_2 if value >= 5 else NeonStyle.DANGER
	lives_label.add_theme_color_override("font_color", live_color)
	if old_text != lives_label.text:
		pulse_label(core_chip if core_chip else lives_label, 1.2 if value < 5 else 1.1)
		# Flash red on damage, then restore
		var flash_tween := create_tween()
		lives_label.add_theme_color_override("font_color", NeonStyle.DANGER)
		if core_chip:
			core_chip.set_value(str(value), NeonStyle.DANGER, false)
		flash_tween.tween_interval(0.35)
		flash_tween.tween_callback(func():
			lives_label.add_theme_color_override("font_color", live_color)
			if core_chip:
				core_chip.set_value(str(value), live_color, false)
		)
	elif core_chip:
		core_chip.set_value(str(value), live_color, false)

func set_wave(value: int) -> void:
	set_current_wave(value, top_bar_total_waves)

func set_current_wave(current_wave: int, total_waves: int) -> void:
	top_bar_total_waves = total_waves
	var old_text := wave_label.text
	if total_waves > 0:
		wave_label.text = "Wave: %d/%d" % [current_wave, total_waves]
	else:
		wave_label.text = "Wave: %d" % current_wave
	if old_text != wave_label.text:
		pulse_label(wave_chip if wave_chip else wave_label)
	if wave_chip:
		var chip_text := "WAVE %d/%d" % [current_wave, total_waves] if total_waves > 0 else "WAVE %d" % current_wave
		wave_chip.set_value(chip_text, NeonStyle.CYAN, false)

func set_next_wave_preview(next_wave_number: int, wave_name: String, has_next_wave: bool) -> void:
	if next_wave_label == null:
		return
	if not has_next_wave or next_wave_number <= 0:
		next_wave_label.text = "Next: None"
		if next_wave_chip:
			next_wave_chip.set_value("NEXT --", NeonStyle.INK_4, true)
		return
	if wave_name != "":
		next_wave_label.text = "Next: Wave %d - %s" % [next_wave_number, wave_name]
	else:
		next_wave_label.text = "Next: Wave %d" % next_wave_number
	if next_wave_chip:
		var chip_text := "NEXT W%d" % next_wave_number
		if wave_name != "":
			chip_text += " · %s" % wave_name
		next_wave_chip.set_value(chip_text, NeonStyle.INK_2, false)

func set_gameplay_status(message: String, color: Color = Color(0.85, 0.95, 1.0)) -> void:
	set_status(message, color)

func set_interest_status(text: String) -> void:
	_ensure_interest_status_label()
	if interest_status_label:
		interest_status_label.text = text
		interest_status_label.tooltip_text = text
	if interest_chip:
		interest_chip.set_value(_format_interest_chip_text(text), NeonStyle.EL_INTEREST, text.to_lower().find("off") >= 0)
		interest_chip.tooltip_text = text

func _format_interest_chip_text(text: String) -> String:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return "OFF"
	normalized = normalized.replace("Interest:", "")
	normalized = normalized.replace("Interest", "")
	normalized = normalized.replace("Next:", "")
	normalized = normalized.replace("Next", "")
	normalized = normalized.replace("every", "/")
	normalized = normalized.replace(" in ", " / ")
	normalized = normalized.replace("  ", " ")
	return normalized.strip_edges().to_upper()

func set_version(text: String) -> void:
	if version_label:
		version_label.text = text

func set_level_name(text: String) -> void:
	if status_label:
		status_label.text = text
		status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	if status_chip:
		status_chip.set_value(text.to_upper(), NeonStyle.CYAN, false)

func set_status(text: String, color: Color = NeonStyle.CYAN) -> void:
	status_label.text = text
	var lower_text := text.to_lower()
	var state_color := color
	if lower_text.find("ready") >= 0 or lower_text.find("planning") >= 0:
		state_color = NeonStyle.CYAN
	elif lower_text.find("progress") >= 0 or lower_text.find("running") >= 0:
		state_color = NeonStyle.WARN
	elif lower_text.find("complete") >= 0:
		state_color = NeonStyle.OK
	elif lower_text.find("choose") >= 0 or lower_text.find("warning") >= 0:
		state_color = NeonStyle.EL_INTEREST
	elif lower_text.find("over") >= 0:
		state_color = NeonStyle.DANGER
	status_label.add_theme_color_override("font_color", state_color)
	status_label.add_theme_font_size_override("font_size", 11)
	if status_chip:
		status_chip.set_value(text.to_upper(), state_color, false)

func set_build_status(text: String) -> void:
	var build_active := text != "Build: None"
	build_status_label.text = "Right-click or two-finger tap to cancel build." if build_active else text
	build_status_label.add_theme_color_override("font_color",
		NeonStyle.CYAN if build_active else NeonStyle.INK_3)
	build_status_label.add_theme_font_size_override("font_size", 11)
	cancel_build_button.visible = false
	if text == "Build: None":
		_set_active_build_row("")
	_apply_build_drawer_visibility()

func _configure_start_wave_button_layout() -> void:
	if start_wave_button == null:
		return
	start_wave_button.custom_minimum_size = Vector2(150, 42)
	start_wave_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_wave_button.clip_text = false
	start_wave_button.add_theme_font_size_override("font_size", 13)
	_ensure_start_wave_countdown_badge()

func _style_start_wave_button(mode: String) -> void:
	if start_wave_button == null:
		return
	start_wave_button.custom_minimum_size = Vector2(164, 42)
	var font_color := Color(0.86, 0.96, 1.0)
	var bg_color := Color(0.035, 0.13, 0.22, 1.0)
	var border_color := Color(0.33, 0.82, 1.0, 0.88)
	match mode:
		"urgent":
			font_color = Color(1.0, 0.35, 0.2)
			border_color = Color(1.0, 0.42, 0.22, 0.9)
		"warning":
			font_color = Color(1.0, 0.78, 0.25)
			border_color = Color(1.0, 0.78, 0.25, 0.9)
		"manual":
			font_color = Color(0.70, 0.98, 1.0)
			bg_color = Color(0.045, 0.17, 0.27, 1.0)
		"running":
			font_color = Color(0.58, 0.74, 0.82)
			bg_color = Color(0.035, 0.050, 0.070, 1.0)
			border_color = Color(0.22, 0.34, 0.44, 0.72)
		"locked":
			font_color = Color(0.95, 0.45, 0.45)
			bg_color = Color(0.060, 0.045, 0.050, 1.0)
			border_color = Color(0.70, 0.24, 0.22, 0.72)
		"cleared":
			font_color = Color(0.4, 1.0, 0.55)
			border_color = Color(0.4, 1.0, 0.55, 0.75)
		_: font_color = Color(0.86, 0.96, 1.0)

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	start_wave_button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.22)
	hover.border_color = border_color.lightened(0.18)
	start_wave_button.add_theme_stylebox_override("hover", hover)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.030, 0.040, 0.055, 1.0)
	start_wave_button.add_theme_stylebox_override("disabled", disabled)

	start_wave_button.add_theme_color_override("font_color", font_color)
	start_wave_button.add_theme_color_override("font_hover_color", font_color.lightened(0.15))
	start_wave_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	start_wave_button.add_theme_color_override("font_disabled_color", font_color)


func set_start_wave_enabled(enabled: bool) -> void:
	if start_wave_button == null:
		return
	start_wave_button.disabled = not enabled

func set_start_wave_text(text: String) -> void:
	if start_wave_button == null:
		return
	start_wave_button.text = text
	_set_start_wave_countdown_badge(false, 0)

func update_start_wave_button(next_wave_number: int, total_waves: int, wave_name: String = "") -> void:
	if next_wave_number <= 0 or next_wave_number > total_waves:
		start_wave_button.text = "Cleared"
		start_wave_button.disabled = true
		set_next_wave_preview(next_wave_number, wave_name, false)
		return

	set_start_wave_action_state(true, false, false, 0.0, next_wave_number)
	set_next_wave_preview(next_wave_number, wave_name, true)

func set_start_wave_action_state(can_start: bool, is_wave_running: bool, countdown_active: bool, countdown_remaining: float, next_wave_number: int) -> void:
	if start_wave_button == null:
		return
	_configure_start_wave_button_layout()

	if is_wave_running:
		start_wave_button.text = "Wave Running"
		start_wave_button.tooltip_text = "In Progress"
		start_wave_button.disabled = true
		_style_start_wave_button("running")
		_set_start_wave_countdown_badge(false, 0)
		return

	if countdown_active:
		var seconds := int(ceil(max(0.0, countdown_remaining)))
		start_wave_button.text = "Auto %ds" % seconds
		start_wave_button.tooltip_text = "Click to start the next wave now"
		start_wave_button.disabled = not can_start
		if seconds <= 5:
			_style_start_wave_button("urgent")
		elif seconds <= 10:
			_style_start_wave_button("warning")
		else:
			_style_start_wave_button("normal")
		_set_start_wave_countdown_badge(true, seconds)
		return

	if next_wave_number <= 0:
		start_wave_button.text = "Cleared"
		start_wave_button.tooltip_text = "All waves cleared"
		start_wave_button.disabled = true
		_style_start_wave_button("cleared")
		_set_start_wave_countdown_badge(false, 0)
		return

	start_wave_button.text = "Start Wave %d" % next_wave_number
	start_wave_button.tooltip_text = "Start the next wave"
	start_wave_button.disabled = not can_start
	_style_start_wave_button("manual" if can_start else "locked")
	_set_start_wave_countdown_badge(false, 0)

func _ensure_interest_status_label() -> void:
	if interest_status_label and is_instance_valid(interest_status_label):
		return
	var top_hbox = gold_label.get_parent()
	if not top_hbox is HBoxContainer:
		return
	interest_status_label = top_hbox.get_node_or_null("InterestStatusLabel")
	if interest_status_label == null:
		interest_status_label = Label.new()
		interest_status_label.name = "InterestStatusLabel"
		interest_status_label.text = "Interest: Off"
		interest_status_label.clip_text = true
		interest_status_label.custom_minimum_size = Vector2(190, 0)
		interest_status_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		top_hbox.add_child(interest_status_label)
		if next_wave_label:
			top_hbox.move_child(interest_status_label, next_wave_label.get_index() + 1)
	interest_status_label.add_theme_font_size_override("font_size", 13)
	interest_status_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.35))
	_style_top_hud_backing_labels()

func _ensure_start_wave_countdown_badge() -> void:
	if start_wave_button == null:
		return
	if start_wave_countdown_badge and is_instance_valid(start_wave_countdown_badge):
		return
	start_wave_countdown_badge = start_wave_button.get_node_or_null("StartWaveCountdownBadge")
	if start_wave_countdown_badge == null:
		start_wave_countdown_badge = Label.new()
		start_wave_countdown_badge.name = "StartWaveCountdownBadge"
		start_wave_countdown_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_wave_countdown_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		start_wave_countdown_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		start_wave_countdown_badge.add_theme_font_size_override("font_size", 10)
		start_wave_countdown_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
		start_wave_button.add_child(start_wave_countdown_badge)
	start_wave_countdown_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	start_wave_countdown_badge.offset_left = -36.0
	start_wave_countdown_badge.offset_top = 3.0
	start_wave_countdown_badge.offset_right = -6.0
	start_wave_countdown_badge.offset_bottom = 19.0
	start_wave_countdown_badge.visible = false

func _set_start_wave_countdown_badge(visible: bool, seconds: int) -> void:
	_ensure_start_wave_countdown_badge()
	if start_wave_countdown_badge == null:
		return
	start_wave_countdown_badge.visible = visible
	if visible:
		start_wave_countdown_badge.text = "%ds" % seconds

func refresh_start_wave_button(total_waves: int, next_wave_number: int, wave_name: String, wave_running: bool, can_start: bool, level_cleared: bool, locked_label: String = "", countdown_active: bool = false, countdown_remaining: float = 0.0, manual_first_wave: bool = false) -> void:
	if start_wave_button == null:
		return
	_configure_start_wave_button_layout()
	
	if total_waves <= 0:
		start_wave_button.text = "No Waves"
		start_wave_button.disabled = true
		_style_start_wave_button("locked")
		_set_start_wave_countdown_badge(false, 0)
		set_next_wave_preview(next_wave_number, wave_name, false)
		return
	
	if locked_label != "":
		start_wave_button.text = locked_label
		start_wave_button.disabled = true
		_style_start_wave_button("locked")
		_set_start_wave_countdown_badge(false, 0)
		return
	
	if wave_running:
		set_start_wave_action_state(false, true, false, 0.0, next_wave_number)
		return

	if level_cleared or next_wave_number <= 0 or next_wave_number > total_waves:
		start_wave_button.text = "Cleared"
		start_wave_button.disabled = true
		_style_start_wave_button("cleared")
		_set_start_wave_countdown_badge(false, 0)
		set_next_wave_preview(next_wave_number, wave_name, false)
		return

	set_next_wave_preview(next_wave_number, wave_name, true)
	set_start_wave_action_state(can_start or manual_first_wave, wave_running, countdown_active, countdown_remaining, next_wave_number)

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
	tower_name_label.add_theme_font_size_override("font_size", 14)
	tower_name_label.add_theme_color_override("font_color", NeonStyle.INK_1)

	# Tier + element chip line
	var info_elements: Array = info.get("elements", [])
	var tier_text := "Lv%d" % info["tier"]
	if not info_elements.is_empty():
		tier_text += "  ·  %s" % _elements_full(info_elements)
	elif info.get("branch_id", "") != "":
		tier_text += "  ·  %s" % info["branch_id"].capitalize()
	if info.get("is_max_tier", false):
		tier_text += "  ·  MAX"
	tower_level_label.text = tier_text
	tower_level_label.add_theme_font_size_override("font_size", 11)
	tower_level_label.add_theme_color_override("font_color", NeonStyle.INK_3)

	var active_damage_bonus := int(info.get("active_damage_bonus_percent", 0))
	if active_damage_bonus > 0:
		var damage_tag := str(info.get("active_damage_bonus_tag", ""))
		var bonus_label := "+DMG"
		var damage_color := NeonStyle.WARN
		if damage_tag == "clone":
			bonus_label = "+CLONE"
			damage_color = NeonStyle.EL_INTEREST
		var eff := int(round(float(info.get("effective_damage", info["damage"]))))
		tower_damage_label.text = "DMG  %s  (%s %d%% → %d)" % [str(info["damage"]), bonus_label, active_damage_bonus, eff]
		tower_damage_label.add_theme_color_override("font_color", damage_color)
	else:
		tower_damage_label.text = "DMG  %s" % str(info["damage"])
		tower_damage_label.add_theme_color_override("font_color", NeonStyle.CYAN_2)
	tower_damage_label.add_theme_font_size_override("font_size", 13)

	tower_range_label.text = "RNG  %s tiles" % str(info["range"])
	tower_range_label.add_theme_color_override("font_color", NeonStyle.INK_2)
	tower_range_label.add_theme_font_size_override("font_size", 13)

	var active_speed_bonus := int(info.get("active_fire_rate_bonus_percent", 0))
	if active_speed_bonus > 0:
		var eff_rate := float(info.get("effective_fire_rate", info["fire_rate"]))
		tower_fire_rate_label.text = "SPD  %0.2fs  (+%d%% → %0.2fs)" % [float(info["fire_rate"]), active_speed_bonus, eff_rate]
		tower_fire_rate_label.add_theme_color_override("font_color", NeonStyle.CYAN)
	else:
		tower_fire_rate_label.text = "SPD  %ss" % str(info["fire_rate"])
		tower_fire_rate_label.add_theme_color_override("font_color", NeonStyle.INK_2)
	tower_fire_rate_label.add_theme_font_size_override("font_size", 13)

	if tower_target_label:
		var a_type_for_targets := str(info.get("attack_type", "single"))
		if a_type_for_targets == "support_aura" or a_type_for_targets == "clone_support":
			tower_target_label.text = "→ Nearby Towers"
			tower_target_label.add_theme_color_override("font_color", NeonStyle.CYAN)
		else:
			var targets : Array = info.get("target_categories", ["land"])
			var target_str: String
			if targets.size() >= 2:   target_str = "→ Ground + Air"
			elif targets.has("air"):  target_str = "→ Air Only"
			else:                     target_str = "→ Ground Only"
			tower_target_label.text = target_str
			tower_target_label.add_theme_color_override("font_color",
				NeonStyle.EL_NATURE if targets.has("air") else NeonStyle.INK_2)
		tower_target_label.add_theme_font_size_override("font_size", 12)
	
	# Clear previous type specific labels
	tower_splash_label.hide()
	tower_slow_label.hide()
	if tower_special_effect_label:
		tower_special_effect_label.hide()
	
	var a_type = info.get("attack_type", "single")
	var _badge := TowerEffectFormatter.attack_badge(info)

	# Unified type label backing text. Legacy labels stay hidden; the EFFECT
	# section below is the single visible effect surface.
	tower_splash_label.hide()
	tower_splash_label.add_theme_font_size_override("font_size", 12)
	match a_type:
		"splash":
			var splash_r := int(info.get("splash_radius", 0))
			tower_splash_label.text = "SPLASH AoE%s" % ("  r%d" % splash_r if splash_r > 0 else "")
			tower_splash_label.add_theme_color_override("font_color", NeonStyle.EL_FIRE)
		"slow":
			tower_slow_label.hide()
			var slow_pct := int(info.get("slow_percent", 0.0) * 100.0)
			var slow_dur := float(info.get("slow_duration", 0.0))
			tower_slow_label.text = "AREA CTRL  -%d%% spd  %.1fs" % [slow_pct, slow_dur]
			tower_slow_label.add_theme_color_override("font_color", NeonStyle.EL_WATER)
			tower_slow_label.add_theme_font_size_override("font_size", 12)
			tower_splash_label.hide()
		"chain":
			var jumps := int(info.get("chain_jumps", 0))
			tower_splash_label.text = "CHAIN%s" % ("  %d jumps" % jumps if jumps > 0 else "")
			tower_splash_label.add_theme_color_override("font_color", NeonStyle.EL_DARKNESS)
		"aura":
			var vuln := int(info.get("vulnerability_percent", 0.0) * 100.0)
			tower_splash_label.text = "AURA%s" % ("  +%d%% dmg" % vuln if vuln > 0 else "")
			tower_splash_label.add_theme_color_override("font_color", NeonStyle.EL_INTEREST)
		"support_aura":
			var sup_type := str(info.get("support_type", ""))
			var sup_pct  := int(round(float(info.get("support_value", 0.0)) * 100.0))
			var sup_cnt  := int(info.get("support_target_count", 0))
			var sup_lim  := int(info.get("support_limit", 4))
			if sup_type == "attack_speed":
				tower_splash_label.text = "SPEED AURA  +%d%%  (%d/%d)" % [sup_pct, sup_cnt, sup_lim]
				tower_splash_label.add_theme_color_override("font_color", NeonStyle.CYAN)
			elif sup_type == "damage":
				tower_splash_label.text = "DAMAGE AURA  +%d%%  (%d/%d)" % [sup_pct, sup_cnt, sup_lim]
				tower_splash_label.add_theme_color_override("font_color", NeonStyle.WARN)
			else:
				tower_splash_label.text = "SUPPORT AURA"
				tower_splash_label.add_theme_color_override("font_color", NeonStyle.CYAN)
		"clone_support":
			var clone_pct := int(float(info.get("clone_damage_multiplier", 0.0)) * 100.0)
			var tgt_name  := str(info.get("clone_target_name", ""))
			tower_splash_label.text = ("CLONE  +%d%%  → %s" % [clone_pct, tgt_name]) if tgt_name != "" \
									else ("CLONE  +%d%%" % clone_pct)
			tower_splash_label.add_theme_color_override("font_color", NeonStyle.EL_INTEREST)
		_:
			tower_splash_label.text = _badge.to_upper()
			tower_splash_label.add_theme_color_override("font_color", NeonStyle.INK_2)

	# Rich effect block — replaces old _build_tower_special_effect_text().
	var eff_lines  := TowerEffectFormatter.effect_lines(info)
	var eff_joined := "\n".join(eff_lines) if eff_lines.size() > 0 else ""

	# Upgrade preview (compact, non-intrusive).
	var upgrade_preview := ""
	if not info.get("is_max_tier", false):
		var next_ids: Array = info.get("next_upgrade_ids", [])
		if not next_ids.is_empty():
			var next_id  := str(next_ids[0])
			var next_cfg: Dictionary = tower_catalog.get(next_id, {})
			if not next_cfg.is_empty():
				upgrade_preview = TowerEffectFormatter.upgrade_preview(info, next_cfg)

	var combined := eff_joined
	if upgrade_preview != "":
		combined = (combined + "\n\n" + upgrade_preview) if combined != "" else upgrade_preview

	if tower_special_effect_label:
		if combined != "":
			tower_special_effect_label.text = combined
			tower_special_effect_label.modulate = Color(0.82, 0.92, 1.0)
			tower_special_effect_label.hide()
		else:
			tower_special_effect_label.hide()

	# ── Premium node updates ──────────────────────────────────────────────────
	if _td_name_label:
		_td_name_label.text = info["name"]

	if _td_tier_chip:
		info_elements = info.get("elements", [])
		tier_text = "Lv%d" % info["tier"]
		if not info_elements.is_empty():
			tier_text += "  ·  %s" % _elements_full(info_elements)
		elif info.get("branch_id", "") != "":
			tier_text += "  ·  %s" % info["branch_id"].capitalize()
		if info.get("is_max_tier", false):
			tier_text += "  ·  MAX"
		_td_tier_chip.text = tier_text

	if _td_el_badge is ElementIconControl:
		var el_arr: Array = info.get("elements", [])
		_td_el_badge.configure(el_arr, true)

	if _td_header_panel:
		_td_header_panel.configure(str(info["name"]).to_upper(), "build", NeonStyle.CYAN, not tower_detail_collapsed, false)
		_td_header_panel.set_subtitle(tier_text)

	if _td_stat_dmg:
		active_damage_bonus = int(info.get("active_damage_bonus_percent", 0))
		if active_damage_bonus > 0:
			var eff := int(round(float(info.get("effective_damage", info["damage"]))))
			_td_stat_dmg.text = "%s  (+%d%%→%d)" % [str(info["damage"]), active_damage_bonus, eff]
			_td_stat_dmg.add_theme_color_override("font_color", NeonStyle.WARN)
		else:
			_td_stat_dmg.text = str(info["damage"])
			_td_stat_dmg.add_theme_color_override("font_color", NeonStyle.CYAN_2)

	if _td_stat_rng:
		_td_stat_rng.text = "%s tiles" % str(info["range"])

	if _td_stat_spd:
		active_speed_bonus = int(info.get("active_fire_rate_bonus_percent", 0))
		if active_speed_bonus > 0:
			var eff_rate := float(info.get("effective_fire_rate", info["fire_rate"]))
			_td_stat_spd.text = "%0.2fs  (+%d%%→%0.2fs)" % [float(info["fire_rate"]), active_speed_bonus, eff_rate]
			_td_stat_spd.add_theme_color_override("font_color", NeonStyle.CYAN)
		else:
			_td_stat_spd.text = "%ss" % str(info["fire_rate"])
			_td_stat_spd.add_theme_color_override("font_color", NeonStyle.INK_2)

	if _td_stat_tgt:
		var a_type_for_targets := str(info.get("attack_type", "single"))
		if a_type_for_targets in ["support_aura", "clone_support"]:
			_td_stat_tgt.text = "Nearby Towers"
			_td_stat_tgt.add_theme_color_override("font_color", NeonStyle.CYAN)
		else:
			var targets: Array = info.get("target_categories", ["land"])
			if targets.size() >= 2:
				_td_stat_tgt.text = "Ground + Air"
				_td_stat_tgt.add_theme_color_override("font_color", NeonStyle.EL_NATURE)
			elif targets.has("air"):
				_td_stat_tgt.text = "Air Only"
				_td_stat_tgt.add_theme_color_override("font_color", NeonStyle.EL_NATURE)
			else:
				_td_stat_tgt.text = "Ground Only"
				_td_stat_tgt.add_theme_color_override("font_color", NeonStyle.INK_2)

	# EFFECT section — colored title + plain body, never duplicated with STATS
	if _td_effect_title:
		var a_type_eff := str(info.get("attack_type", "single"))
		if a_type_eff == "slow":
			_td_effect_title.text = tower_slow_label.text
		else:
			_td_effect_title.text = tower_splash_label.text
		_td_effect_title.add_theme_color_override("font_color", _effect_title_color(info, _td_effect_title.text))

	if _td_effect_section and _td_effect_body:
		var eff_text := tower_special_effect_label.text if tower_special_effect_label else ""
		eff_text = _clean_effect_body_text(eff_text)
		_td_effect_body.text = eff_text
		_td_effect_body.visible = eff_text != ""
		var has_badge := _td_effect_title != null and _td_effect_title.text != ""
		if has_badge or eff_text != "":
			_td_effect_section.set_meta("td_visible_when_expanded", true)
			_td_effect_section.show()
		else:
			_td_effect_section.set_meta("td_visible_when_expanded", false)
			_td_effect_section.hide()
	# ─────────────────────────────────────────────────────────────────────────

	updating_target_mode_ui = true
	var current_mode = info.get("target_mode", "first")
	var mode_index = target_modes.find(current_mode)
	if mode_index != -1:
		target_mode_option_button.select(mode_index)
	updating_target_mode_ui = false
	
	if info.get("is_max_tier", false):
		upgrade_tower_button.disabled = true
		if _upgrade_text_label:
			_upgrade_text_label.text = "MAX TIER"
			_upgrade_text_label.add_theme_color_override("font_color", NeonStyle.INK_3)
		if _upgrade_cost_display:
			_upgrade_cost_display.visible = false
	elif info["can_upgrade"] and info["upgrade_cost"] > 0:
		upgrade_tower_button.disabled = false
		if _upgrade_text_label:
			_upgrade_text_label.text = "Upgrade  ·  Lv%d" % [int(info.get("tier", 1)) + 1]
			_upgrade_text_label.add_theme_color_override("font_color", NeonStyle.INK_1)
		if _upgrade_cost_display:
			_upgrade_cost_display.configure(info["upgrade_cost"], true)
			_upgrade_cost_display.visible = true
	elif info["can_upgrade"]:
		upgrade_tower_button.disabled = true
		if _upgrade_text_label:
			_upgrade_text_label.text = "Upgrade (N/A)"
			_upgrade_text_label.add_theme_color_override("font_color", NeonStyle.INK_3)
		if _upgrade_cost_display:
			_upgrade_cost_display.visible = false
	else:
		upgrade_tower_button.disabled = true
		if _upgrade_text_label:
			_upgrade_text_label.text = "MAX TIER"
			_upgrade_text_label.add_theme_color_override("font_color", NeonStyle.INK_3)
		if _upgrade_cost_display:
			_upgrade_cost_display.visible = false

	if sell_tower_button:
		var refund := int(info.get("sell_refund", 0))
		if _sell_cost_display:
			_sell_cost_display.configure(refund, true)
		sell_tower_button.show()
	_set_tower_detail_collapsed(tower_detail_collapsed)

	# Keep the floating card in sync (e.g. after target-mode or upgrade refresh).
	if _tower_float_card != null and is_instance_valid(_tower_float_card) \
			and _tower_float_card.visible and _tower_float_card.has_method("refresh_info"):
		_tower_float_card.call("refresh_info", info)

func _build_tower_special_effect_text(_info: Dictionary) -> String:
	# Superseded by TowerEffectFormatter.effect_lines() — kept for compatibility.
	return "\n".join(TowerEffectFormatter.effect_lines(_info))

func hide_tower_info() -> void:
	hide_tower_info_panel()
	if tower_special_effect_label:
		tower_special_effect_label.hide()
	if sell_tower_button:
		sell_tower_button.hide()

# ── Floating tower info card ─────────────────────────────────────────────────

func _ensure_tower_float_card() -> void:
	if _tower_float_card != null and is_instance_valid(_tower_float_card):
		return
	var script = load("res://scripts/ui/tower_float_card.gd")
	if script == null:
		return
	_tower_float_card = script.new()
	_tower_float_card.name = "TowerFloatCard"
	$Root.add_child(_tower_float_card)
	# Route float card actions back through game_hud signals so main.gd
	# receives them exactly as before.
	if _tower_float_card.has_signal("upgrade_requested"):
		_tower_float_card.upgrade_requested.connect(func(): upgrade_tower_requested.emit())
	if _tower_float_card.has_signal("sell_requested"):
		_tower_float_card.sell_requested.connect(func(): sell_tower_requested.emit())
	if _tower_float_card.has_signal("target_mode_changed"):
		_tower_float_card.target_mode_changed.connect(
			func(mode: String): target_mode_changed.emit(mode))

func show_tower_float_card(info: Dictionary, tower: Node2D) -> void:
	_ensure_tower_float_card()
	if _tower_float_card and _tower_float_card.has_method("show_for_tower"):
		_tower_float_card.call("show_for_tower", info, tower)

func hide_tower_float_card() -> void:
	if _tower_float_card != null and is_instance_valid(_tower_float_card):
		_tower_float_card.call("hide_card")

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
	if next_wave_chip:
		next_wave_chip.set_value("ALL WAVES CLEARED", NeonStyle.OK, false)

func show_build_panel() -> void:
	set_panel_active(left_sidebar, true, true)
	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()

func hide_build_panel() -> void:
	# Keep the left command rail visible; only collapse drawer content.
	_collapse_left_drawers()
	if left_sidebar:
		left_sidebar.visible = true
		left_sidebar.process_mode = Node.PROCESS_MODE_INHERIT
	_set_active_build_row("")
	_hide_hover_card()

# ── Build-button hover card ──────────────────────────────────────────────────

func _setup_hover_card() -> void:
	_hover_card = PanelContainer.new()
	_hover_card.name = "BuildHoverCard"
	_hover_card.visible = false
	_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.z_index = 300
	_hover_card.custom_minimum_size = Vector2(210, 0)

	var style := NeonStyle.panel(NeonStyle.BG_1, NeonStyle.LINE_STRONG, true)
	style.shadow_color  = Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.30)
	style.shadow_size   = 18
	style.shadow_offset = Vector2.ZERO
	_hover_card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.add_child(margin)

	_hover_card_rtl = RichTextLabel.new()
	_hover_card_rtl.bbcode_enabled = true
	_hover_card_rtl.fit_content = true
	_hover_card_rtl.scroll_active = false
	_hover_card_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card_rtl.custom_minimum_size = Vector2(200, 0)
	_hover_card_rtl.add_theme_font_size_override("normal_font_size", 11)
	_hover_card_rtl.add_theme_color_override("default_color", NeonStyle.INK_1)
	margin.add_child(_hover_card_rtl)

	$Root.add_child(_hover_card)

func _show_hover_card(tower_id: String, cfg: Dictionary, cost: int, anchor: Control) -> void:
	if _hover_card == null or not is_instance_valid(_hover_card):
		return
	_hover_card_rtl.text = TowerEffectFormatter.hover_card_bbcode(tower_id, cfg, cost, _elements_full)
	# Position: right edge of anchor + small gap
	var rect := anchor.get_global_rect()
	_hover_card.global_position = Vector2(rect.end.x + 6.0, rect.position.y)
	_hover_card.visible = true
	# Deferred clamp to prevent off-screen-bottom after layout.
	call_deferred("_clamp_hover_card")

func _clamp_hover_card() -> void:
	if _hover_card == null or not is_instance_valid(_hover_card) or not _hover_card.visible:
		return
	var vp_h := float(get_viewport().get_visible_rect().size.y)
	var card_bottom := _hover_card.global_position.y + _hover_card.size.y
	if card_bottom > vp_h - 8.0:
		_hover_card.global_position.y = maxf(8.0, vp_h - _hover_card.size.y - 8.0)

func _hide_hover_card() -> void:
	_hover_long_press_timer = null
	if _hover_card and is_instance_valid(_hover_card):
		_hover_card.visible = false

func show_tower_info_panel() -> void:
	tower_detail_has_selection = true
	if _td_header_panel:
		_td_header_panel.visible = false
	if right_sidebar:
		right_sidebar.visible = false
	if no_selection_panel:
		no_selection_panel.visible = false
	_refresh_right_info_column_visibility()

func hide_tower_info_panel() -> void:
	tower_detail_has_selection = false
	if _td_header_panel:
		_td_header_panel.visible = false
	if right_sidebar:
		right_sidebar.visible = false
	if no_selection_panel:
		no_selection_panel.visible = false
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
	if next_wave_chip:
		next_wave_chip.set_value("NEXT --", NeonStyle.INK_4, true)

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
	var cost = tower_prices.get(id, 50)
	# Check affordability here for feedback
	var gold = 0
	var scene := get_tree().current_scene
	var gm: Node = null
	if scene:
		gm = scene.get_node_or_null("GameManager")
	if gm:
		gold = int(gm.get("gold"))
	
	if gold < cost:
		shake_node(btn)
		set_build_status("Not enough gold ($%d)!" % cost)
		return

	_set_active_build_row(id)
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

func _make_panel_separator() -> ColorRect:
	var r := ColorRect.new()
	r.color = NeonStyle.LINE
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _make_stat_row(key: String, accent: Color) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)

	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", NeonStyle.INK_3)
	key_label.uppercase = true
	key_label.custom_minimum_size = Vector2(56, 0)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(key_label)

	var divider := ColorRect.new()
	divider.color = NeonStyle.LINE
	divider.custom_minimum_size = Vector2(1, 12)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)

	var val_label := Label.new()
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.add_theme_color_override("font_color", accent)
	val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_label)

	return [row, val_label]

func _make_right_panel_eyebrow(text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", color)
	lbl.uppercase = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	var line := ColorRect.new()
	line.color = Color(color.r, color.g, color.b, 0.22)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	return row

func _register_tower_detail_content(node: Control) -> void:
	_td_content_nodes.append(node)

func _set_tower_detail_collapsed(collapsed: bool) -> void:
	# Legacy drawer Tower Detail is disabled. Selected tower actions now live
	# only in the floating tower card.
	tower_detail_collapsed = true
	for node in _td_content_nodes:
		if node != null and is_instance_valid(node):
			node.visible = false
	if _td_chevron_label:
		_td_chevron_label.text = "›"
	if _td_header_panel:
		_td_header_panel.visible = false
		_td_header_panel.set_expanded(false)
	if right_sidebar:
		right_sidebar.visible = false
	if no_selection_panel:
		no_selection_panel.visible = false
	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()

func _toggle_tower_detail_collapsed() -> void:
	_set_tower_detail_collapsed(not tower_detail_collapsed)

func _has_tower_detail_selection() -> bool:
	return tower_detail_has_selection

func _make_right_drawer_body_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NeonStyle.BG_1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.set_border_width_all(1)
	style.set_border_width(SIDE_LEFT, 3)
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _effect_title_color(info: Dictionary, title: String) -> Color:
	var haystack := ("%s %s %s" % [
		str(info.get("attack_type", "")),
		str(info.get("id", info.get("tower_id", ""))),
		title
	]).to_lower()
	if haystack.contains("splash") or haystack.contains("aoe") or haystack.contains("slam"):
		return NeonStyle.EL_FIRE
	if haystack.contains("slow") or haystack.contains("freeze") or haystack.contains("frost") or haystack.contains("ice"):
		return NeonStyle.EL_WATER
	if haystack.contains("burn") or haystack.contains("fire") or haystack.contains("flame") or haystack.contains("nova"):
		return NeonStyle.EL_FIRE
	if haystack.contains("poison") or haystack.contains("venom") or haystack.contains("nature") or haystack.contains("roots"):
		return NeonStyle.EL_NATURE
	if haystack.contains("light") or haystack.contains("holy") or haystack.contains("reveal") or haystack.contains("laser"):
		return NeonStyle.WARN
	if haystack.contains("dark") or haystack.contains("curse") or haystack.contains("void") or haystack.contains("hex") or haystack.contains("jinx"):
		return NeonStyle.EL_DARKNESS
	if haystack.contains("wind") or haystack.contains("storm") or haystack.contains("gale") or haystack.contains("chain"):
		return NeonStyle.CYAN
	return NeonStyle.INK_2

func _clean_effect_body_text(text: String) -> String:
	var output := PackedStringArray()
	for raw_line in text.split("\n", false):
		var line := str(raw_line).strip_edges()
		if line == "":
			output.append("")
			continue
		var colon_idx := line.find(":")
		if colon_idx > 0:
			var prefix := line.substr(0, colon_idx).strip_edges().to_lower()
			if prefix in ["splash", "area slow", "on-hit slow", "chain", "speed aura", "damage aura", "support aura", "clone", "burn", "poison", "venom", "freeze", "frost slow", "hex", "gale", "vulnerability"]:
				line = line.substr(colon_idx + 1).strip_edges()
				if not line.is_empty():
					line = line.substr(0, 1).to_upper() + line.substr(1)
		output.append(line)
	return "\n".join(output)

func _setup_right_sidebar_layout() -> void:
	var old_right_container := right_sidebar_container
	var container := _get_left_sidebar_content_box()
	if container == null: return
	_ensure_left_drawer_headers(container)

	# Tower Detail no longer has a left drawer button/body. Selected tower
	# actions live in the floating card only. Clean up any legacy header left
	# from previous UI construction.
	var legacy_td_header := container.get_node_or_null("TowerDetailDrawerHeader")
	if legacy_td_header:
		legacy_td_header.queue_free()
	_td_header_panel = null

	if old_right_container:
		old_right_container.custom_minimum_size.x = 0
		old_right_container.visible = false
		old_right_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if right_sidebar.get_parent() != container:
		var old_parent := right_sidebar.get_parent()
		if old_parent:
			old_parent.remove_child(right_sidebar)
		container.add_child(right_sidebar)

	container.add_theme_constant_override("separation", DRAWER_SECTION_GAP)

	# 1. Setup Tower Detail Panel (Existing RightSidebar)
	right_sidebar.name = "TowerDetailPanel"
	right_sidebar.custom_minimum_size = Vector2(0, 0)
	right_sidebar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	right_sidebar.add_theme_stylebox_override("panel", _make_right_drawer_body_style(NeonStyle.CYAN))

	# _td_header_panel = CommandHeaderButtonControl.new()
	# _td_header_panel.name = "TowerDetailDrawerHeader"
	# _td_header_panel.configure("TOWER DETAIL", "build", NeonStyle.CYAN, false, false)
	# _td_header_panel.set_subtitle("No selection")
	# _td_header_panel.visible = false
	# # No expand toggle — Tower Detail body lives in the floating card.
	# # The header is a status-only summary tab in the left drawer.
	# container.add_child(_td_header_panel)
	# container.move_child(_td_header_panel, right_sidebar.get_index())

	# Margins
	var detail_margin := right_sidebar.get_node_or_null("MarginContainer")
	if detail_margin is MarginContainer:
		detail_margin.add_theme_constant_override("margin_left",   0)
		detail_margin.add_theme_constant_override("margin_right",  0)
		detail_margin.add_theme_constant_override("margin_top",    0)
		detail_margin.add_theme_constant_override("margin_bottom", 0)

	# Rework tower detail VBox content
	var detail_vbox := right_sidebar.get_node_or_null("MarginContainer/VBoxContainer")
	if detail_vbox:
		detail_vbox.add_theme_constant_override("separation", 7)

		# Hide legacy scene labels (replaced by premium nodes)
		var old_tgt_lbl := detail_vbox.get_node_or_null("TowerTargetModeLabel")
		if old_tgt_lbl is Control:
			old_tgt_lbl.hide()
			old_tgt_lbl.custom_minimum_size = Vector2.ZERO

		for lbl in [tower_name_label, tower_level_label, tower_damage_label,
				tower_range_label, tower_fire_rate_label, tower_splash_label,
				tower_slow_label, tower_upgrade_cost_label]:
			if lbl is Control:
				lbl.hide()
				lbl.custom_minimum_size = Vector2.ZERO

		# Hide scene HSeparator if present
		var old_hsep := detail_vbox.get_node_or_null("HSeparator")
		if old_hsep is Control:
			old_hsep.hide()
			old_hsep.custom_minimum_size = Vector2.ZERO

		# Add tower_target_label and tower_special_effect_label (hidden initially)
		tower_target_label = Label.new()
		tower_target_label.name = "TowerTargetLabel"
		tower_target_label.add_theme_font_size_override("font_size", 12)
		tower_target_label.add_theme_color_override("font_color", NeonStyle.INK_2)
		tower_target_label.text = "→ Ground Only"
		tower_target_label.hide()
		tower_target_label.custom_minimum_size = Vector2.ZERO
		detail_vbox.add_child(tower_target_label)

		tower_special_effect_label = Label.new()
		tower_special_effect_label.name = "TowerSpecialEffectLabel"
		tower_special_effect_label.add_theme_font_size_override("font_size", 11)
		tower_special_effect_label.add_theme_color_override("font_color", NeonStyle.INK_2)
		tower_special_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tower_special_effect_label.text = ""
		tower_special_effect_label.hide()
		tower_special_effect_label.custom_minimum_size = Vector2.ZERO
		detail_vbox.add_child(tower_special_effect_label)

		# ── Build premium body nodes with vi (visual insert index) ──
		var vi := 0

		# THIN SEPARATOR after header
		var sep1 := _make_panel_separator()
		detail_vbox.add_child(sep1)
		detail_vbox.move_child(sep1, vi)
		_register_tower_detail_content(sep1)
		vi += 1

		# STATS eyebrow
		var stats_eyebrow := _make_right_panel_eyebrow("STATS", NeonStyle.INK_3)
		detail_vbox.add_child(stats_eyebrow)
		detail_vbox.move_child(stats_eyebrow, vi)
		_register_tower_detail_content(stats_eyebrow)
		vi += 1

		# Stat rows
		var stats_dmg_result := _make_stat_row("DMG", NeonStyle.CYAN_2)
		var stats_dmg_row: HBoxContainer = stats_dmg_result[0]
		_td_stat_dmg = stats_dmg_result[1]
		detail_vbox.add_child(stats_dmg_row)
		detail_vbox.move_child(stats_dmg_row, vi)
		_register_tower_detail_content(stats_dmg_row)
		vi += 1

		var stats_rng_result := _make_stat_row("RNG", NeonStyle.INK_2)
		var stats_rng_row: HBoxContainer = stats_rng_result[0]
		_td_stat_rng = stats_rng_result[1]
		detail_vbox.add_child(stats_rng_row)
		detail_vbox.move_child(stats_rng_row, vi)
		_register_tower_detail_content(stats_rng_row)
		vi += 1

		var stats_spd_result := _make_stat_row("SPD", NeonStyle.INK_2)
		var stats_spd_row: HBoxContainer = stats_spd_result[0]
		_td_stat_spd = stats_spd_result[1]
		detail_vbox.add_child(stats_spd_row)
		detail_vbox.move_child(stats_spd_row, vi)
		_register_tower_detail_content(stats_spd_row)
		vi += 1

		var stats_tgt_result := _make_stat_row("TARGET", NeonStyle.INK_2)
		var stats_tgt_row: HBoxContainer = stats_tgt_result[0]
		_td_stat_tgt = stats_tgt_result[1]
		detail_vbox.add_child(stats_tgt_row)
		detail_vbox.move_child(stats_tgt_row, vi)
		_register_tower_detail_content(stats_tgt_row)
		vi += 1

		# EFFECT section (TYPE row removed — effect shown in EFFECT section with colored title)
		_td_effect_section = VBoxContainer.new()
		_td_effect_section.name = "TDEffectSection"
		_td_effect_section.set_meta("td_visible_when_expanded", false)
		_td_effect_section.add_theme_constant_override("separation", 4)
		_td_effect_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_td_effect_section.add_child(_make_panel_separator())
		_td_effect_section.add_child(_make_right_panel_eyebrow("EFFECT", NeonStyle.INK_3))
		_td_effect_title = Label.new()
		_td_effect_title.add_theme_font_size_override("font_size", 12)
		_td_effect_title.add_theme_color_override("font_color", NeonStyle.INK_2)
		_td_effect_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_td_effect_section.add_child(_td_effect_title)
		_td_effect_body = Label.new()
		_td_effect_body.add_theme_font_size_override("font_size", 11)
		_td_effect_body.add_theme_color_override("font_color", NeonStyle.INK_2)
		_td_effect_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_td_effect_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_td_effect_section.add_child(_td_effect_body)
		detail_vbox.add_child(_td_effect_section)
		detail_vbox.move_child(_td_effect_section, vi)
		_register_tower_detail_content(_td_effect_section)
		vi += 1
		_td_effect_section.hide()

		# Separator before targeting
		var sep2 := _make_panel_separator()
		detail_vbox.add_child(sep2)
		detail_vbox.move_child(sep2, vi)
		_register_tower_detail_content(sep2)
		vi += 1

		# TARGETING eyebrow
		var tgt_eyebrow := _make_right_panel_eyebrow("TARGETING", NeonStyle.INK_3)
		detail_vbox.add_child(tgt_eyebrow)
		detail_vbox.move_child(tgt_eyebrow, vi)
		_register_tower_detail_content(tgt_eyebrow)
		vi += 1

		# Move target_mode_option_button into position and restyle it
		var opt_style := StyleBoxFlat.new()
		opt_style.bg_color = NeonStyle.BG_1
		opt_style.border_color = NeonStyle.LINE_2
		opt_style.set_border_width_all(1)
		opt_style.set_corner_radius_all(0)
		opt_style.content_margin_left = 8
		opt_style.content_margin_right = 8
		opt_style.content_margin_top = 4
		opt_style.content_margin_bottom = 4
		target_mode_option_button.add_theme_stylebox_override("normal", opt_style)
		target_mode_option_button.add_theme_stylebox_override("hover", opt_style.duplicate())
		target_mode_option_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		target_mode_option_button.add_theme_font_size_override("font_size", 12)
		target_mode_option_button.add_theme_color_override("font_color", NeonStyle.INK_1)
		detail_vbox.move_child(target_mode_option_button, vi)
		_register_tower_detail_content(target_mode_option_button)
		vi += 1

		# Separator + UPGRADE eyebrow
		var sep3 := _make_panel_separator()
		detail_vbox.add_child(sep3)
		detail_vbox.move_child(sep3, vi)
		_register_tower_detail_content(sep3)
		vi += 1

		var upg_eyebrow := _make_right_panel_eyebrow("UPGRADE", NeonStyle.INK_3)
		detail_vbox.add_child(upg_eyebrow)
		detail_vbox.move_child(upg_eyebrow, vi)
		_register_tower_detail_content(upg_eyebrow)
		vi += 1

		# tower_upgrade_cost_label — keep hidden, zero size (already hidden above)

		# Upgrade button — composite: text label + CreditCostDisplayControl
		upgrade_tower_button.text = ""
		upgrade_tower_button.clip_text = false
		for ch in upgrade_tower_button.get_children():
			ch.queue_free()
		var upg_row := HBoxContainer.new()
		upg_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		upg_row.offset_left = 10
		upg_row.offset_right = -8
		upg_row.add_theme_constant_override("separation", 6)
		upg_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upgrade_tower_button.add_child(upg_row)

		_upgrade_text_label = Label.new()
		_upgrade_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_upgrade_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_upgrade_text_label.add_theme_font_size_override("font_size", 12)
		_upgrade_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upg_row.add_child(_upgrade_text_label)

		_upgrade_cost_display = CreditCostDisplayControl.new()
		_upgrade_cost_display.custom_minimum_size = Vector2(58, 34)
		_upgrade_cost_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_upgrade_cost_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upg_row.add_child(_upgrade_cost_display)

		# Style upgrade button as WARN (amber/gold) — primary action
		NeonStyle.style_button(upgrade_tower_button, NeonStyle.WARN, false)
		upgrade_tower_button.custom_minimum_size.y = 36

		# Move upgrade button into position
		detail_vbox.move_child(upgrade_tower_button, vi)
		_register_tower_detail_content(upgrade_tower_button)
		vi += 1

		# Deselect button — hidden; use the tower header row click to deselect
		deselect_tower_button.hide()
		deselect_tower_button.custom_minimum_size = Vector2.ZERO

	# 2. No Selection — Tower Detail's empty drawer body
	no_selection_panel = PanelContainer.new()
	no_selection_panel.name = "NoSelectionPanel"
	no_selection_panel.custom_minimum_size = Vector2(0, 68)
	no_selection_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	no_selection_panel.add_theme_stylebox_override("panel", _make_right_drawer_body_style(NeonStyle.CYAN))
	container.add_child(no_selection_panel)
	container.move_child(no_selection_panel, right_sidebar.get_index() + 1)

	var ns_vbox := VBoxContainer.new()
	ns_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ns_vbox.add_theme_constant_override("separation", 8)
	no_selection_panel.add_child(ns_vbox)

	var ns_sub := Label.new()
	ns_sub.text = "Select a tower or build tile to view details."
	ns_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ns_sub.add_theme_font_size_override("font_size", 11)
	ns_sub.add_theme_color_override("font_color", NeonStyle.INK_3)
	ns_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ns_vbox.add_child(ns_sub)

	# 3. Wave Intel — collapsible wrapper: header button + body panel
	_wi_wrapper = VBoxContainer.new()
	_wi_wrapper.name = "WaveIntelWrapper"
	_wi_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_wi_wrapper.add_theme_constant_override("separation", 6)
	container.add_child(_wi_wrapper)

	_wi_tab_panel = CommandHeaderButtonControl.new()
	_wi_tab_panel.name = "WaveIntelDrawerHeader"
	_wi_tab_panel.configure("WAVE INTEL", "damage", NeonStyle.CYAN, false, false)
	_wi_tab_panel.set_subtitle("Wave --/--")
	_wi_tab_panel.pressed.connect(_toggle_wave_intel)
	_wi_wrapper.add_child(_wi_tab_panel)

	wave_intel_panel = PanelContainer.new()
	wave_intel_panel.name = "WaveIntelPanel"
	wave_intel_panel.custom_minimum_size = Vector2(0, 0)
	wave_intel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wave_intel_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	wave_intel_panel.visible = false
	_wi_wrapper.add_child(wave_intel_panel)

	wave_intel_panel.add_theme_stylebox_override("panel", _make_right_drawer_body_style(NeonStyle.CYAN))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	wave_intel_panel.add_child(vbox)

	# Wave count row (replaces old inline header)
	var wave_count_row := HBoxContainer.new()
	wave_count_row.add_theme_constant_override("separation", 8)
	vbox.add_child(wave_count_row)

	wave_intel_current_label = _create_wave_intel_label("", 11, NeonStyle.INK_3)
	wave_intel_current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_count_row.add_child(wave_intel_current_label)

	wave_intel_name_label = _create_wave_intel_label("", 13, NeonStyle.INK_1)
	vbox.add_child(wave_intel_name_label)

	# Status + reward inline
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	vbox.add_child(status_row)

	wave_intel_status_label = _create_wave_intel_label("", 11, NeonStyle.OK)
	wave_intel_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(wave_intel_status_label)

	# Reward: coin icon + amount via CreditCostDisplayControl
	_wi_reward_row = HBoxContainer.new()
	_wi_reward_row.add_theme_constant_override("separation", 4)
	_wi_reward_row.visible = false
	_wi_reward_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(_wi_reward_row)

	wave_intel_reward_label = _create_wave_intel_label("Reward", 10, NeonStyle.INK_3)
	wave_intel_reward_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wave_intel_reward_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wi_reward_row.add_child(wave_intel_reward_label)

	_wi_reward_display = CreditCostDisplayControl.new()
	_wi_reward_display.custom_minimum_size = Vector2(50, 22)
	_wi_reward_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wi_reward_display.configure(0, true)
	_wi_reward_row.add_child(_wi_reward_display)

	wave_intel_section_label = _create_wave_intel_label("", 10, NeonStyle.INK_3)
	wave_intel_section_label.uppercase = true
	wave_intel_section_label.visible = false
	vbox.add_child(wave_intel_section_label)

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

	wave_intel_section_label = _create_wave_intel_label("Upcoming", 12, Color(0.58, 0.78, 0.96))
	body.add_child(wave_intel_section_label)

	wave_intel_main_summary_label = _create_wave_intel_richtext(12, NeonStyle.INK_1)
	body.add_child(wave_intel_main_summary_label)

	wave_intel_next_title_label = _create_wave_intel_label("NEXT WAVE", 10, NeonStyle.INK_3)
	wave_intel_next_title_label.uppercase = true
	body.add_child(wave_intel_next_title_label)

	wave_intel_next_summary_label = _create_wave_intel_richtext(11, NeonStyle.INK_2)
	body.add_child(wave_intel_next_summary_label)

	body.add_child(_create_wave_intel_separator())

	wave_intel_threats_title_label = _create_wave_intel_label("THREATS", 10, NeonStyle.INK_3)
	wave_intel_threats_title_label.uppercase = true
	body.add_child(wave_intel_threats_title_label)

	wave_intel_threats_label = _create_wave_intel_richtext(12, NeonStyle.DANGER)
	body.add_child(wave_intel_threats_label)

	wave_intel_suggested_title_label = _create_wave_intel_label("RECOMMENDED", 10, NeonStyle.INK_3)
	wave_intel_suggested_title_label.uppercase = true
	body.add_child(wave_intel_suggested_title_label)

	wave_intel_suggested_label = _create_wave_intel_richtext(12, NeonStyle.CYAN)
	body.add_child(wave_intel_suggested_label)

	wave_intel_warnings_label = _create_wave_intel_label("", 11, NeonStyle.WARN)
	wave_intel_warnings_label.visible = false
	body.add_child(wave_intel_warnings_label)

	_refresh_right_info_column_visibility()

func _toggle_wave_intel() -> void:
	_set_wave_intel_collapsed(not wave_intel_collapsed)

func _set_wave_intel_collapsed(collapsed: bool) -> void:
	wave_intel_collapsed = collapsed
	if not wave_intel_collapsed:
		_cancel_active_build_for_info_menu()
		build_drawer_expanded = false
		damage_stats_expanded = false
	else:
		if not damage_stats_expanded:
			build_drawer_expanded = true

	if _wi_header_btn:
		_wi_header_btn.set_expanded(not wave_intel_collapsed)
	if _wi_chevron_label:
		_wi_chevron_label.text = "›" if wave_intel_collapsed else "⌄"
	if _wi_tab_panel:
		_wi_tab_panel.set_expanded(not wave_intel_collapsed)
	if damage_stats_header_button:
		damage_stats_header_button.set_expanded(damage_stats_expanded)
	if wave_intel_panel:
		wave_intel_panel.visible = not wave_intel_collapsed
	if _wi_wrapper:
		_wi_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_apply_build_drawer_visibility()
	_apply_left_drawer_layout()

func _layout_right_sidebar_container(width: float = RIGHT_DRAWER_WIDTH) -> void:
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
	var separator := ColorRect.new()
	separator.custom_minimum_size.y = 1
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.color = NeonStyle.LINE
	return separator

func _set_next_wave_intel_visible(visible: bool) -> void:
	if wave_intel_next_title_label:
		wave_intel_next_title_label.visible = visible
	if wave_intel_next_summary_label:
		wave_intel_next_summary_label.visible = visible

func clear_wave_intel() -> void:
	if wave_intel_panel == null: return

	if _wi_wrapper:
		_wi_wrapper.visible = false
	else:
		wave_intel_panel.visible = false
	_refresh_right_info_column_visibility()
	if wave_intel_current_label:
		wave_intel_current_label.text = ""
	if _wi_summary_label:
		_wi_summary_label.text = "Wave --/--"
	if _wi_tab_panel:
		_wi_tab_panel.set_subtitle("Wave --/--")
	if wave_intel_name_label:
		wave_intel_name_label.text = ""
	if wave_intel_status_label:
		wave_intel_status_label.text = ""
	if _wi_reward_row:
		_wi_reward_row.visible = false
	elif wave_intel_reward_label:
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
	if _wi_wrapper:
		_wi_wrapper.visible = visible
		wave_intel_panel.visible = visible and not wave_intel_collapsed
	else:
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
	
	wave_intel_current_label.text = "%d / %d" % [display_wave_idx + 1, wave_total]
	wave_intel_name_label.text = current_preview.get("name", "Unknown Wave")
	if _wi_summary_label:
		_wi_summary_label.text = "Wave %d/%d  ·  %s" % [
			display_wave_idx + 1,
			wave_total,
			str(current_preview.get("name", "Unknown Wave"))
		]
	if _wi_tab_panel:
		_wi_tab_panel.set_subtitle("Wave %d/%d  ·  %s" % [
			display_wave_idx + 1,
			wave_total,
			str(current_preview.get("name", "Unknown Wave"))
		])
	wave_intel_status_label.text = "● " + status_text
	wave_intel_status_label.add_theme_color_override("font_color",
		NeonStyle.OK if is_running else NeonStyle.WARN)

	var reward : int = current_preview.get("reward", 0)
	if reward > 0:
		if _wi_reward_display and _wi_reward_row:
			_wi_reward_display.configure(reward, true)
			_wi_reward_row.visible = true
		elif wave_intel_reward_label:
			wave_intel_reward_label.text = "Reward  ✦%d" % reward
			wave_intel_reward_label.visible = true
	else:
		if _wi_reward_row:
			_wi_reward_row.visible = false
		elif wave_intel_reward_label:
			wave_intel_reward_label.visible = false

	if wave_intel_section_label:
		wave_intel_section_label.text = "CURRENT" if is_running else "UPCOMING"
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
	
	if _wi_wrapper:
		_wi_wrapper.visible = true
		_wi_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if wave_intel_collapsed else Control.SIZE_EXPAND_FILL
		wave_intel_panel.visible = not wave_intel_collapsed
	else:
		wave_intel_panel.visible = true
	_refresh_right_info_column_visibility()

func _refresh_right_info_column_visibility() -> void:
	if right_sidebar_container:
		right_sidebar_container.custom_minimum_size.x = 0
		right_sidebar_container.visible = false
		right_sidebar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _td_header_panel:
		_td_header_panel.visible = false
	if right_sidebar:
		right_sidebar.visible = false
	if no_selection_panel:
		no_selection_panel.visible = false
	if _wi_wrapper:
		_wi_wrapper.visible = true
	if wave_intel_panel:
		wave_intel_panel.visible = not wave_intel_collapsed
	_apply_build_drawer_visibility()
func _format_wave_preview_summary(preview: Dictionary) -> String:
	var lane_info = preview.get("lane_info", {})
	var formation_lines := _format_wave_formation_lines(preview)
	
	if lane_info.keys().size() > 1:
		var lane_parts = []
		var sorted_ids = lane_info.keys()
		sorted_ids.sort()
		
		for p_id in sorted_ids:
			var info = lane_info[p_id]
			var counts = info.get("counts", {})
			var lane_name = "Lane A" if str(p_id) == "default" else str(p_id).capitalize()
			lane_parts.append("[%s]: %s" % [lane_name, _format_counts(counts)])
		if formation_lines != "":
			lane_parts.append(formation_lines)
		return "\n".join(lane_parts)
		
	var counts = preview.get("enemy_counts", {})
	if counts.is_empty():
		return "Malformed Wave"
	var summary := _format_counts(counts)
	if formation_lines != "":
		summary += "\n" + formation_lines
	return summary

func _format_wave_formation_lines(preview: Dictionary) -> String:
	var formations: Array = preview.get("formations", [])
	var notes: Array = preview.get("formation_notes", [])
	var lines := []
	if not formations.is_empty():
		lines.append("[color=#8fd3ff]Formation[/color]  " + " | ".join(formations))
	if not notes.is_empty():
		lines.append("[color=#ffd36e]Tactic[/color]  " + " | ".join(notes))
	return "\n".join(lines)

func _format_counts(counts: Dictionary) -> String:
	var parts = []
	var type_order = ["Normal", "Fast", "Heavy", "Swarm", "Air"]
	for type_name in type_order:
		if counts.has(type_name):
			var tooltip = enemy_role_tooltips.get(type_name, "")
			var label := "[color=#f1f7ff]%s x%d[/color]" % [type_name, int(counts[type_name])]
			if tooltip != "":
				parts.append("[hint=%s]%s[/hint]" % [tooltip, label])
			else:
				parts.append(label)
	for type_name in counts.keys():
		if not type_order.has(str(type_name)):
			var tooltip = enemy_role_tooltips.get(str(type_name), "")
			var label := "[color=#f1f7ff]%s x%d[/color]" % [str(type_name), int(counts[type_name])]
			if tooltip != "":
				parts.append("[hint=%s]%s[/hint]" % [tooltip, label])
			else:
				parts.append(label)
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


func _on_tower_build_selected(tower_id: String) -> void:
	pass # Replace with function body.
