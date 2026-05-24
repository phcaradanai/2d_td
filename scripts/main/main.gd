extends Node2D

# Preload scripts for dynamic node creation if missing in scene
const LEVEL_MANAGER_SCRIPT_PATH = "res://scripts/managers/level_manager.gd"
const MAP_VISUAL_LAYER_SCRIPT_PATH = "res://scripts/map/map_visual_layer.gd"
const MAZE_MAP_RENDERER_SCRIPT = preload("res://scripts/map/maze_map_renderer.gd")
const ENEMY_ROUTE_OVERLAY_SCRIPT = preload("res://scripts/map/enemy_route_overlay.gd")
const GRID_PATHFINDING_MANAGER_SCRIPT = preload("res://scripts/navigation/grid_pathfinding_manager.gd")
const UI_THEME_MANAGER_SCRIPT = preload("res://scripts/ui/ui_theme_manager.gd")
const BALANCE_SOLVER_SCRIPT = "res://scripts/debug/balance_solver.gd"
const AUTO_PLAY_VERIFIER_SCRIPT = preload("res://scripts/debug/auto_play_verifier.gd")
const LEVEL_VALIDATOR_SCRIPT = preload("res://scripts/debug/level_validator.gd")
const SPAWN_FORMATION_PLANNER_SCRIPT = preload("res://scripts/managers/spawn_formation_planner.gd")
const ELEMENT_PROGRESSION_MANAGER_SCRIPT = preload("res://scripts/managers/element_progression_manager.gd")
const ELEMENT_TD_INTEREST_SERVICE_SCRIPT = preload("res://scripts/main/element_td_interest_service.gd")
const AUTO_NEXT_WAVE_SERVICE_SCRIPT = preload("res://scripts/main/auto_next_wave_service.gd")
const HUD_STATE_PRESENTER_SCRIPT = preload("res://scripts/main/hud_state_presenter.gd")
const WAVE_PREVIEW_HELPER_SCRIPT = preload("res://scripts/main/wave_preview_helper.gd")
const AUTO_CLEAR_PLAN_HELPER_SCRIPT = preload("res://scripts/main/auto_clear_plan_helper.gd")
const GAMEPLAY_CONTROLLER_BINDER_SCRIPT = preload("res://scripts/main/gameplay_controller_binder.gd")
const DAMAGE_STATS_TRACKER_SCRIPT = preload("res://scripts/core/damage_stats_tracker.gd")
const COMBAT_AUDIO_SERVICE_SCRIPT = preload("res://scripts/services/combat_audio_service.gd")
const DISPLAY_MODE_SERVICE_SCRIPT = preload("res://scripts/services/display_mode_service.gd")
const SETTINGS_SERVICE_SCRIPT = preload("res://scripts/services/settings_service.gd")
const SCENE_NAVIGATION_SERVICE_SCRIPT = preload("res://scripts/services/scene_navigation_service.gd")
const SETTINGS_MENU_SCENE = preload("res://scenes/ui/settings_menu.tscn")
const LEVEL_ACCESS_SERVICE_SCRIPT = preload("res://scripts/services/level_access_service.gd")
const REMOTE_ACCESS_CONFIG_PATH = "res://scripts/services/remote_access_config_service.gd"
const RUNTIME_IDENTITY_PATH = "res://scripts/services/runtime_identity_service.gd"
const DEMO_GATE_MODAL_PATH = "res://scripts/ui/demo_gate_modal.gd"

enum GameState {MENU, LEVEL_SELECT, BUILD, WAVE, WAVE_COMPLETE, PAUSED, GAME_OVER, VICTORY}
enum AutoClearState {
	IDLE,
	SOLVING,
	TESTING_GOLD_CANDIDATE,
	SIMULATING_CANDIDATE,
	PLAN_FOUND,
	AUTOPLAY_STARTING_LEVEL,
	AUTOPLAY_INITIAL_ACTIONS,
	AUTOPLAY_BEFORE_WAVE_ACTIONS,
	AUTOPLAY_STARTING_WAVE,
	AUTOPLAY_WAVE_RUNNING,
	AUTOPLAY_AFTER_WAVE_ACTIONS,
	AUTOPLAY_SUCCESS,
	AUTOPLAY_FAILED,
	NO_PLAN_FOUND
}

@onready var camera: Camera2D = $Camera2D
@onready var world_root: Node2D = $WorldRoot
@onready var map_root: Node2D = %MapRoot
@onready var background: ColorRect = $WorldRoot/Background
@onready var path_visual: Line2D = $WorldRoot/MapRoot/PathVisual
@onready var enemy_container: Node2D = $WorldRoot/MapRoot/EnemyContainer
@onready var enemy_path: Path2D = $WorldRoot/MapRoot/EnemyContainer/EnemyPath
@onready var tower_container: Node2D = $WorldRoot/MapRoot/TowerContainer
@onready var projectile_container: Node2D = $WorldRoot/MapRoot/ProjectileContainer
@onready var effects_container: Node2D = $WorldRoot/MapRoot/EffectsContainer
@onready var build_preview: Node2D = $WorldRoot/MapRoot/BuildPreviewLayer

@onready var game_manager: Node = $GameManager
@onready var wave_manager: Node = $WaveManager
@onready var build_manager: Node = $BuildManager
@onready var save_manager: Node = $SaveManager
@onready var audio_manager: Node = $AudioManager
@onready var game_hud: CanvasLayer = $GameHUD
@onready var main_menu: CanvasLayer = $MainMenu
@onready var level_select: CanvasLayer = $LevelSelect
@onready var debug_panel: CanvasLayer = $DebugPanel
@onready var debug_button: Button = $DebugLayer/DebugButton

@export var debug_panel_enabled: bool = false
@export var debug_coordinates: bool = false
@export var enable_debug_tools: bool = false

const VERSION = "v1.0.0-RC1"
const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const VALID_ENEMY_CATEGORIES := [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]

# Layout Constants
const TOP_BAR_HEIGHT = 60
const LEFT_SIDEBAR_WIDTH = 200
const RIGHT_SIDEBAR_WIDTH = 260
const OUTER_MARGIN = 0 # Removed for maximal expansion

var level_manager: LevelManager = null
var pathfinding_manager: Node = null
var level_validator: Node = null
var balance_solver: Node = null
var auto_play_verifier: Node = null
var debug_starting_gold_override: int = -1
var map_visual_layer: Node2D = null
var maze_map_renderer: Node2D = null
var enemy_route_overlay: Node2D = null
var selected_tower: Node2D = null
var current_state: GameState = GameState.MENU
var _show_wave_complete_status_feedback: bool = false
var _last_shop_ids_hash: int = 0 # Guards _refresh_elemental_shop against redundant rebuilds.

# ── Wave preview cache ──────────────────────────────────────────────────────
# Caches per-level wave summaries so SpawnFormationPlanner is not run every UI refresh.
# Key: level_id (int). Invalidated on level start / wave data reload.
var _wave_preview_cache: Dictionary = {} # level_id (int) -> Array[Dictionary]
var wave_preview_cache_hits: int = 0
var wave_preview_cache_misses: int = 0

# ── Wave intel dirty tracking ────────────────────────────────────────────────
# Prevents redundant _refresh_hud_wave_intel calls when nothing changed.
var _wave_intel_dirty: bool = true
var _last_wi_level_id: int = -1
var _last_wi_wave_index: int = -1
var _last_wi_running: bool = false

# ── Debug performance counters ───────────────────────────────────────────────
var tower_preview_active_count: int = 0
var tower_preview_redraw_count: int = 0
var _touch_points: Dictionary = {} # active touch indices for two-finger deselect
var current_level_path: String = ""
var current_level_id: String = ""
var selected_level_id: int = 0

var pending_unlock_level_id: String = ""
var save_game_service: Node = null # [MetaLayer] Run-state save/continue
var leaderboard_service: Node = null
var online_lb_client: Node = null # [MetaLayer] Online leaderboard client
var leaderboard_panel: Node = null
var current_hero: Node = null
var hero_panel: Node = null
var hero_cooldown: float = 0.0
var hero_active_duration: float = 0.0
var hero_is_deployed: bool = false
var element_progression_manager = null
var auto_next_wave_service: RefCounted = null
var element_td_interest_service: RefCounted = null
var hud_state_presenter: RefCounted = null
var _gameplay_controller_binder: RefCounted = null
var damage_stats_tracker: Node = null
const ELEMENT_PICK_INTERVAL: int = 5
const STARTING_ELEMENT_PICKS: int = 0
const INTEREST_PICK_ID: String = "__interest__"
const DEFAULT_INTEREST_UPGRADE_STEP: float = 0.01
const DEFAULT_MAX_INTEREST_UPGRADES: int = 5

const STARTER_TOWER_IDS := ["basic_tower_t1", "neutral_cannon_tower"]

var sandbox_layer: CanvasLayer = null
var sandbox_panel: PanelContainer = null
var combat_audio_service: Node = null
var display_mode_service: Node = null
var settings_service: Node = null
var scene_navigation_service: Node = null
var settings_menu: CanvasLayer = null
var runtime_identity_service: Node = null # [Identity] Stable install/session/runtime IDs
var level_access_service: Node = null # [DemoGate] Level/wave access control
var remote_access_config_service: Node = null # [DemoGate] Remote OTA config fetcher
var _demo_gate_modal: CanvasLayer = null # [DemoGate] Shared locked/complete modal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Apply global UI theme
	var theme_mgr = UI_THEME_MANAGER_SCRIPT.new()
	if main_menu: theme_mgr.apply_theme(main_menu)
	if game_hud: theme_mgr.apply_theme(game_hud)
	if level_select: theme_mgr.apply_theme(level_select)
	if debug_panel: theme_mgr.apply_theme(debug_panel)
	_ensure_damage_stats_tracker()

	if OS.is_debug_build() or enable_debug_tools:
		ensure_debug_input_actions()

	if debug_panel:
		debug_panel.layer = 500
		debug_panel.visible = false
		debug_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	if debug_button:
		# Hide by default, only show if debug build AND specifically enabled
		debug_button.visible = false
		debug_button.pressed.connect(_on_debug_button_pressed)
		debug_button.mouse_filter = Control.MOUSE_FILTER_STOP

	_ensure_level_nodes_exist()
	_ensure_element_progression_manager()
	if auto_next_wave_service == null:
		auto_next_wave_service = AUTO_NEXT_WAVE_SERVICE_SCRIPT.new()

	if OS.has_feature("web"):
		_show_audio_unlock_overlay()

	if build_manager:
		build_manager.setup(game_manager, tower_container, projectile_container)
		_refresh_elemental_tower_catalog()

	# Initial Audio Setup
	if audio_manager and save_manager:
		var audio_settings = save_manager.get_audio_settings()
		audio_manager.apply_settings(audio_settings)
		if game_hud:
			game_hud.set_audio_settings_ui(audio_settings)

	# Combat Audio Service — throttled, pooled SFX for tower/projectile attacks
	combat_audio_service = COMBAT_AUDIO_SERVICE_SCRIPT.new()
	combat_audio_service.name = "CombatAudioService"
	add_child(combat_audio_service)
	combat_audio_service.setup(audio_manager)
	if save_manager:
		var _initial_mode: String = save_manager.get_audio_settings().get("audio_combat_mode", "balanced")
		combat_audio_service.set_combat_mode(_initial_mode)

	# Display mode service — owns desktop window/borderless/fullscreen changes.
	display_mode_service = DISPLAY_MODE_SERVICE_SCRIPT.new()
	display_mode_service.name = "DisplayModeService"
	add_child(display_mode_service)
	display_mode_service.display_mode_changed.connect(_on_display_mode_service_changed)
	if game_hud and game_hud.has_method("set_display_mode_options"):
		game_hud.set_display_mode_options(display_mode_service.get_mode_options())
	var display_settings: Dictionary = save_manager.get_display_settings() if save_manager else display_mode_service.get_default_settings()
	display_mode_service.apply_settings(display_settings, false)
	if game_hud and game_hud.has_method("set_display_settings_ui"):
		game_hud.set_display_settings_ui(display_mode_service.get_current_settings())

	var performance_budget_service := get_node_or_null("/root/PerformanceBudgetService")
	if performance_budget_service:
		var performance_settings: Dictionary = save_manager.get_performance_settings() if save_manager and save_manager.has_method("get_performance_settings") else performance_budget_service.get_default_settings()
		performance_budget_service.apply_settings(performance_settings)
		if game_hud and game_hud.has_method("set_performance_settings_ui"):
			game_hud.set_performance_settings_ui(performance_budget_service.get_settings())

	settings_service = SETTINGS_SERVICE_SCRIPT.new()
	settings_service.name = "SettingsService"
	add_child(settings_service)
	settings_service.bind({
		"save_manager": save_manager,
		"audio_manager": audio_manager,
		"display_mode_service": display_mode_service,
		"performance_budget_service": performance_budget_service,
	})
	settings_service.load_and_apply()

	settings_menu = SETTINGS_MENU_SCENE.instantiate()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)
	if settings_menu.has_method("bind_settings_service"):
		settings_menu.bind_settings_service(settings_service)

	scene_navigation_service = SCENE_NAVIGATION_SERVICE_SCRIPT.new()
	scene_navigation_service.name = "SceneNavigationService"
	add_child(scene_navigation_service)
	scene_navigation_service.bind({
		"go_to_main_menu": Callable(self , "return_to_menu"),
		"go_to_level_select": Callable(self , "_on_level_select_requested"),
		"restart_current_level": Callable(self , "restart_level"),
		"stop_auto_next_wave_countdown": Callable(self , "_stop_auto_next_wave_countdown"),
		"clear_transient_combat_ui": Callable(self , "_clear_transient_combat_ui"),
	})

	# [Identity] Runtime identity — stable install_id + fresh session_id each launch.
	var _ris_script = load(RUNTIME_IDENTITY_PATH)
	if _ris_script:
		runtime_identity_service = _ris_script.new()
		runtime_identity_service.name = "RuntimeIdentityService"
		add_child(runtime_identity_service)
	else:
		push_error("[Identity] Failed to load RuntimeIdentityService script.")

	# [DemoGate] Remote OTA config — fetches access rules from backend, caches locally.
	var _rac_script = load(REMOTE_ACCESS_CONFIG_PATH)
	if _rac_script:
		remote_access_config_service = _rac_script.new()
		remote_access_config_service.name = "RemoteAccessConfigService"
		add_child(remote_access_config_service)
		remote_access_config_service.config_updated.connect(_on_access_config_updated)
		remote_access_config_service.fetch_failed.connect(_on_access_config_fetch_failed)
		if runtime_identity_service:
			remote_access_config_service.bind_identity_service(runtime_identity_service)
	else:
		push_error("[DemoGate] Failed to load RemoteAccessConfigService script.")

	# [DemoGate] Level access service — delegates to remote config when bound.
	level_access_service = LEVEL_ACCESS_SERVICE_SCRIPT.new()
	level_access_service.name = "LevelAccessService"
	add_child(level_access_service)
	if remote_access_config_service:
		level_access_service.bind_remote_config(remote_access_config_service)
		if level_select and level_select.has_method("bind_access_config_service"):
			level_select.bind_access_config_service(remote_access_config_service)

	# [DemoGate] Shared modal (locked level + demo complete + maintenance + force-update).
	var _modal_script = load(DEMO_GATE_MODAL_PATH)
	if _modal_script:
		_demo_gate_modal = _modal_script.new()
		_demo_gate_modal.name = "DemoGateModal"
		_demo_gate_modal.back_to_menu.connect(return_to_menu)
		add_child(_demo_gate_modal)
	else:
		push_error("[DemoGate] Failed to load DemoGateModal script.")

	if main_menu:
		main_menu.set_version(VERSION)
	if game_hud:
		game_hud.set_version(VERSION)

	# [DemoGate] Kick off the remote fetch after the scene is fully ready.
	# call_deferred so all child nodes finish _ready() before the HTTP node is used.
	call_deferred("_fetch_remote_access_config")

	if OS.is_debug_build():
		var script = load(BALANCE_SOLVER_SCRIPT)
		if script:
			balance_solver = script.new()
			balance_solver.name = "BalanceSolver"
			add_child(balance_solver)

		auto_play_verifier = Node.new()
		auto_play_verifier.name = "AutoPlayVerifier"
		auto_play_verifier.set_script(AUTO_PLAY_VERIFIER_SCRIPT)
		add_child(auto_play_verifier)
		auto_play_verifier.state_changed.connect(_on_verifier_state_changed)

		level_validator = LEVEL_VALIDATOR_SCRIPT.new()
		level_validator.name = "LevelValidator"
		add_child(level_validator)

	_connect_signals()
	_hide_old_path_visuals()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_world_layout()

	return_to_menu()
	# current_state is already MENU at startup, so set_game_phase's early-return guard
	# prevents _refresh_ui_for_phase from running. Force the continue button here.
	if main_menu and save_game_service:
		main_menu.set_has_save(save_game_service.has_valid_save())

	# [MetaLayer] Retry any pending online score submissions from previous sessions
	if online_lb_client:
		online_lb_client.retry_pending()

func _on_viewport_size_changed() -> void:
	_update_world_layout()
	# Deferred pass ensures Godot's layout system has settled HUD sizes before
	# get_playfield_rect() reads left_sidebar.get_global_rect().
	call_deferred("_update_world_layout")

func _get_gameplay_controller_binder() -> RefCounted:
	if _gameplay_controller_binder == null:
		_gameplay_controller_binder = GAMEPLAY_CONTROLLER_BINDER_SCRIPT.new()
	return _gameplay_controller_binder

func _get_gameplay_layout_controller() -> RefCounted:
	return _get_gameplay_controller_binder().get_gameplay_layout_controller(self )

func _get_elemental_pick_controller() -> RefCounted:
	return _get_gameplay_controller_binder().get_elemental_pick_controller(self )

func _get_wave_flow_controller() -> RefCounted:
	return _get_gameplay_controller_binder().get_wave_flow_controller(self )

func _get_tower_interaction_controller() -> RefCounted:
	return _get_gameplay_controller_binder().get_tower_interaction_controller(self )

func _get_visible_viewport_size_for_layout() -> Vector2:
	return get_viewport().get_visible_rect().size

func _get_current_game_state() -> int:
	return current_state

func _is_tree_paused_for_wave_flow() -> bool:
	return get_tree().paused

func _set_bound_hud_build_status(message: String) -> void:
	hud_state_presenter.set_build_status(message)

func _hide_element_choice() -> void:
	game_hud.hide_element_choice(true)

func _ensure_damage_stats_tracker() -> void:
	if damage_stats_tracker == null or not is_instance_valid(damage_stats_tracker):
		damage_stats_tracker = get_node_or_null("DamageStatsTracker")
	if damage_stats_tracker == null:
		damage_stats_tracker = DAMAGE_STATS_TRACKER_SCRIPT.new()
		add_child(damage_stats_tracker)
	if game_hud and game_hud.has_method("set_damage_stats_tracker"):
		game_hud.set_damage_stats_tracker(damage_stats_tracker)

func _update_world_layout() -> void:
	_get_gameplay_layout_controller().update_world_layout()

func _fit_map_to_playfield(playfield_rect: Rect2) -> void:
	_get_gameplay_layout_controller().fit_map_to_playfield(playfield_rect)

func _get_map_content_bounds() -> Rect2:
	return _get_gameplay_layout_controller().get_map_content_bounds()

func _cells_from_level_arrays(raw: Variant) -> Array[Vector2i]:
	return _get_gameplay_layout_controller().cells_from_level_arrays(raw)

func _bind_hud_state_presenter() -> void:
	if hud_state_presenter == null:
		hud_state_presenter = HUD_STATE_PRESENTER_SCRIPT.new()
	if game_hud:
		hud_state_presenter.bind(game_hud)

func _refresh_start_wave_ui() -> void:
	if game_hud == null or wave_manager == null:
		return
	_bind_hud_state_presenter()
	var can_start := current_state == GameState.BUILD or current_state == GameState.WAVE_COMPLETE
	can_start = can_start and wave_manager.has_next_wave()
	can_start = can_start and not wave_manager.is_wave_running
	can_start = can_start and not _has_pending_element_pick()
	var countdown_active := false
	var countdown_remaining := 0.0
	if auto_next_wave_service:
		countdown_active = bool(auto_next_wave_service.countdown_active)
		countdown_remaining = float(auto_next_wave_service.remaining)
	var next_wave_number: int = wave_manager.get_next_wave_number()
	var total_waves: int = wave_manager.get_total_waves()
	var next_wave_name := ""
	if wave_manager.has_method("get_next_wave_name"):
		next_wave_name = wave_manager.get_next_wave_name()
	var active_wave_number: int = 0
	var raw_active_wave_number = wave_manager.get("active_wave_number")
	if raw_active_wave_number != null:
		active_wave_number = int(raw_active_wave_number)
	var current_wave: int = int(game_manager.current_wave) if game_manager else active_wave_number
	var has_next_wave: bool = wave_manager.has_next_wave()
	var level_cleared: bool = not wave_manager.has_next_wave() and not wave_manager.is_wave_running
	var gameplay_status: String = _get_top_bar_gameplay_status(countdown_active, countdown_remaining)
	var interest_status_text: String = _format_interest_status_text()
	var locked_label := "Choose Element First" if _has_pending_element_pick() else ""
	hud_state_presenter.refresh_start_wave_button(
		can_start,
		_is_waiting_for_manual_first_wave(),
		countdown_active,
		countdown_remaining,
		next_wave_number,
		total_waves,
		next_wave_name,
		wave_manager.is_wave_running,
		level_cleared,
		locked_label,
		current_wave,
		has_next_wave,
		gameplay_status,
		interest_status_text
	)

func _get_top_bar_gameplay_status(countdown_active: bool, countdown_remaining: float) -> String:
	if current_state == GameState.GAME_OVER:
		return "Defeat"
	if current_state == GameState.VICTORY:
		return "Victory"
	if current_state == GameState.PAUSED or get_tree().paused:
		return "Paused"
	if _has_pending_element_pick():
		return "Choose Element"
	if wave_manager and wave_manager.is_wave_running:
		return "In Progress"
	if countdown_active:
		return "Auto next in %ds" % int(ceil(max(0.0, countdown_remaining)))
	if _show_wave_complete_status_feedback:
		return "Wave Complete"
	if current_state == GameState.WAVE_COMPLETE:
		return "Wave Complete"
	return "Ready"

func _format_interest_status_text() -> String:
	if element_td_interest_service == null:
		return "Interest: Off"
	var current_gold := 0
	if game_manager:
		current_gold = int(game_manager.gold)
	if element_td_interest_service.has_method("format_status"):
		return str(element_td_interest_service.call("format_status", current_gold))
	if bool(element_td_interest_service.get("enabled")):
		return "Interest: %s" % _format_interest_rate_percent()
	return "Interest: Off"

func _refresh_interest_status_ui() -> void:
	if game_hud == null:
		return
	_bind_hud_state_presenter()
	hud_state_presenter.set_interest_status(_format_interest_status_text())

func _refresh_gameplay_hud_state() -> void:
	FrameSpikeLogger.begin("hud_gameplay_state")
	_refresh_start_wave_ui()
	_refresh_hud_wave_intel()
	_refresh_route_preview()
	FrameSpikeLogger.end("hud_gameplay_state")

var active_path_nodes: Dictionary = {}

func _setup_game_from_level() -> void:
	if level_manager == null: return

	# Clear existing gameplay state
	_clear_gameplay_state()
	_configure_auto_next_wave_from_level()
	_configure_element_td_interest_from_level()
	if auto_next_wave_service:
		auto_next_wave_service.reset()
	_stop_auto_next_wave_countdown()

	# Hide old map visual layer — MazeMapRenderer handles lightweight drawing now
	if map_visual_layer:
		map_visual_layer.visible = false

	if maze_map_renderer == null:
		maze_map_renderer = MAZE_MAP_RENDERER_SCRIPT.new()
		maze_map_renderer.name = "MazeMapRenderer"
		map_root.add_child(maze_map_renderer)
		map_root.move_child(maze_map_renderer, 0)

	maze_map_renderer.setup(level_manager)

	if pathfinding_manager:
		pathfinding_manager.setup_grid(level_manager)

	# Enemy route overlay — draws one lightweight route per spawn to core
	if enemy_route_overlay == null:
		enemy_route_overlay = ENEMY_ROUTE_OVERLAY_SCRIPT.new()
		enemy_route_overlay.name = "EnemyRouteOverlay"
		map_root.add_child(enemy_route_overlay)

	if pathfinding_manager:
		enemy_route_overlay.setup(
			pathfinding_manager,
			pathfinding_manager.spawn_cells,
			pathfinding_manager.target_cells
		)
		if level_manager:
			var show_dynamic_overlay := bool(level_manager.level_data.get("show_dynamic_route_overlay", false))
			enemy_route_overlay.visible = show_dynamic_overlay and not _level_uses_fixed_pathing()

	# Clear and setup paths
	for p in active_path_nodes.values():
		if p != enemy_path and is_instance_valid(p):
			p.queue_free()
	active_path_nodes.clear()
	
	# Clear extra path visuals
	for child in map_root.get_children():
		if child is Line2D and child.name.begins_with("PathVisual_"):
			child.queue_free()

	var active_path_portals := _build_active_path_portals()
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		
		# Setup Logic Node
		var p_node = enemy_path if p_id == "default" else Path2D.new()
		if p_node != enemy_path:
			p_node.name = "EnemyPath_" + p_id
			enemy_container.add_child(p_node)
		
		p_node.curve = _create_curve_from_points(points)
		active_path_nodes[p_id] = p_node
		
		# Setup Visual
		if p_id == "default":
			if path_visual: path_visual.points = points
		else:
			if path_visual:
				var visual = path_visual.duplicate()
				visual.name = "PathVisual_" + p_id
				visual.points = points
				map_root.add_child(visual)

	# Center the map inside the playfield area
	_update_world_layout()

	if wave_manager:
		if wave_manager.has_method("set_pathfinding_manager"):
			wave_manager.set_pathfinding_manager(pathfinding_manager)
		if wave_manager.has_method("configure_from_level"):
			wave_manager.configure_from_level(level_manager)
		wave_manager.setup(active_path_nodes, active_path_portals)
		if level_manager.level_data.has("waves") and level_manager.level_data["waves"] is Array and not level_manager.level_data["waves"].is_empty():
			wave_manager.load_waves_from_data(level_manager.level_data["waves"])
		else:
			wave_manager.load_waves_from_file(level_manager.waves_path)
		wave_manager.reset_waves()
		_log_wave_intel_source()
		

	if build_manager:
		build_manager.configure_from_level(level_manager)
		if build_manager.has_method("set_pathfinding_manager"):
			build_manager.set_pathfinding_manager(pathfinding_manager)
		build_manager.reset_build_state()

	if element_progression_manager:
		element_progression_manager.reset()
		element_progression_manager.grant_pick(STARTING_ELEMENT_PICKS)
		_refresh_elemental_shop()

	if game_manager:
		var gold_to_apply: int = level_manager.starting_gold
		if debug_starting_gold_override >= 0 and is_debug_auto_play_allowed():
			gold_to_apply = debug_starting_gold_override
			debug_starting_gold_override = -1
		game_manager.apply_level_config(gold_to_apply, level_manager.starting_lives)
		game_manager.reset_runtime_state()
		game_manager.set_total_waves(wave_manager.get_total_waves())

		if OS.is_debug_build():
			print("START LEVEL ", level_manager.level_id, " money ", game_manager.gold, " hp ", game_manager.lives)

	if game_hud:
		game_hud.set_level_name(level_manager.level_name)
		_refresh_elemental_shop()
		_show_pending_element_choice()

	update_hud()
	_refresh_hud_wave_intel()
	_refresh_route_preview()
	# Pre-warm canvas shaders for all enemy visual types so the first AoE hit
	# never causes a shader-compilation spike mid-wave.
	call_deferred("_prewarm_enemy_visuals")
	# Removed _spawn_hero() as it's now manual deployment
	_setup_hero_if_enabled()

## Prewarm canvas shaders and bake all enemy textures before wave 1.
## Eliminates first-AoE shader-compilation spikes and texture-baking stutter.
func _prewarm_enemy_visuals() -> void:
	const PREWARMER = preload("res://scripts/enemies/enemy_visual_prewarmer.gd")
	var pw: Node = PREWARMER.new()
	add_child(pw)
	pw.start()
	# Kick off EnemyTextureBaker prewarm in parallel — all 45 combinations
	# bake over the next ~90 frames so they're cached before enemies spawn.
	var baker := get_node_or_null("/root/EnemyTextureBaker")
	if baker != null and baker.has_method("prewarm_all"):
		baker.prewarm_all()

func _setup_hero_if_enabled() -> void:
	if game_hud and level_manager and level_manager.hero_config.get("enabled", false):
		_setup_hero_ui()
		if level_manager.hero_config.get("unlock_message", "") != "":
			show_wave_feedback(level_manager.hero_config["unlock_message"], Color(0.4, 0.8, 1.0))
	elif hero_panel:
		hero_panel.hide()

	if build_preview:
		build_preview.setup(level_manager.grid_size, level_manager.grid_cols, level_manager.grid_rows)
		build_preview.set_blocked_cells(level_manager.get_all_blocked_cells())
		build_preview.set_buildable_cells(level_manager.buildable_cells)
		
		if OS.is_debug_build():
			print("[BuildZone] level=%s buildable=%d" % [level_manager.level_id, level_manager.buildable_cells.size()])
			if level_manager.buildable_cells.is_empty():
				print("[BuildZone] mode=free (no restricted foundations)")
			else:
				print("[BuildZone] mode=restricted (foundations only)")

func _create_curve_from_points(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	for point in points:
		curve.add_point(point)
	return curve

func _build_active_path_portals() -> Dictionary:
	var portals_by_path: Dictionary = {}
	if level_manager == null:
		return portals_by_path
	var raw_portals = level_manager.level_data.get("path_portals", [])
	if not (raw_portals is Array):
		return portals_by_path
	for portal in raw_portals:
		if not (portal is Dictionary):
			continue
		var path_id := str(portal.get("path", "default"))
		if not level_manager.multi_paths.has(path_id):
			continue
		var cells: Array = level_manager.multi_paths[path_id]
		var entry_index := int(portal.get("entry_index", -1))
		var exit_index := int(portal.get("exit_index", -1))
		if entry_index < 0 or exit_index <= entry_index or exit_index >= cells.size():
			continue
		var entry_progress := _path_progress_at_cell_index(cells, entry_index)
		var exit_progress := _path_progress_at_cell_index(cells, exit_index)
		if exit_progress <= entry_progress:
			continue
		var data: Dictionary = portal.duplicate()
		data["entry_progress"] = entry_progress
		data["exit_progress"] = exit_progress
		if not data.has("id"):
			data["id"] = "%s_%d_%d" % [path_id, entry_index, exit_index]
		if not portals_by_path.has(path_id):
			portals_by_path[path_id] = []
		portals_by_path[path_id].append(data)
	return portals_by_path

func _path_progress_at_cell_index(cells: Array, index: int) -> float:
	if cells.is_empty() or index <= 0:
		return 0.0
	var total := 0.0
	for i in range(1, min(index, cells.size() - 1) + 1):
		var prev: Vector2i = cells[i - 1]
		var cur: Vector2i = cells[i]
		total += Vector2(prev - cur).length() * float(level_manager.grid_size)
	return total

func update_hud() -> void:
	_refresh_hud_stats()
	_refresh_start_wave_ui()

func _configure_auto_next_wave_from_level() -> void:
	if auto_next_wave_service == null:
		auto_next_wave_service = AUTO_NEXT_WAVE_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	auto_next_wave_service.configure_from_level(level_data)

func _configure_element_td_interest_from_level() -> void:
	if element_td_interest_service == null:
		element_td_interest_service = ELEMENT_TD_INTEREST_SERVICE_SCRIPT.new()
	var level_data := {}
	if level_manager:
		level_data = level_manager.level_data
	element_td_interest_service.configure_from_level(level_data)

func _recalculate_element_td_interest_rate() -> void:
	if element_td_interest_service:
		element_td_interest_service.recalculate_rate()

func _format_interest_rate_percent() -> String:
	return _get_elemental_pick_controller().format_interest_rate_percent()

func _format_next_interest_rate_percent() -> String:
	return _get_elemental_pick_controller().format_next_interest_rate_percent()

func _can_choose_interest_upgrade() -> bool:
	return _get_elemental_pick_controller().can_choose_interest_upgrade()

func _has_pending_element_pick() -> bool:
	return _get_elemental_pick_controller().has_pending_element_pick()

func _is_waiting_for_manual_first_wave() -> bool:
	return _get_wave_flow_controller().is_waiting_for_manual_first_wave()

func _can_auto_next_wave_countdown() -> bool:
	return _get_wave_flow_controller().can_auto_next_wave_countdown()

func _maybe_start_auto_next_wave_countdown() -> void:
	_get_wave_flow_controller().maybe_start_auto_next_wave_countdown()

func _stop_auto_next_wave_countdown() -> void:
	_get_wave_flow_controller().stop_auto_next_wave_countdown()

func _update_auto_next_wave_countdown(delta: float) -> void:
	_get_wave_flow_controller().update_auto_next_wave_countdown(delta)

# --- TowerInteractionController compatibility wrappers (read-only) ---

func get_selected_tower() -> Node2D:
	return _get_tower_interaction_controller().get_selected_tower()

func has_selected_tower() -> bool:
	return _get_tower_interaction_controller().has_selected_tower()

func get_selected_tower_info() -> Dictionary:
	return _get_tower_interaction_controller().get_selected_tower_info()

func get_selected_tower_display_name() -> String:
	return _get_tower_interaction_controller().get_selected_tower_display_name()

func can_show_selected_tower_info() -> bool:
	return _get_tower_interaction_controller().can_show_selected_tower_info()

func can_hide_selected_tower_info() -> bool:
	return _get_tower_interaction_controller().can_hide_selected_tower_info()

func can_upgrade_selected_tower() -> bool:
	return _get_tower_interaction_controller().can_upgrade_selected_tower()

func can_sell_selected_tower() -> bool:
	return _get_tower_interaction_controller().can_sell_selected_tower()

func get_selected_tower_sell_value() -> int:
	return _get_tower_interaction_controller().get_selected_tower_sell_value()

func get_selected_tower_upgrade_preview() -> Dictionary:
	return _get_tower_interaction_controller().get_selected_tower_upgrade_preview()

func _update_element_td_interest(delta: float) -> void:
	if element_td_interest_service == null:
		return

	var active_enemy_count := 0
	if wave_manager and wave_manager.has_method("get_active_enemy_count"):
		active_enemy_count = int(wave_manager.call("get_active_enemy_count"))
	else:
		active_enemy_count = get_tree().get_nodes_in_group("enemies").size()

	var current_gold := 0
	if game_manager:
		current_gold = int(game_manager.gold)

	var interest_gold: int = int(element_td_interest_service.tick(
		delta,
		current_gold,
		active_enemy_count,
		current_state == GameState.WAVE and not get_tree().paused
	))

	if interest_gold <= 0:
		return

	if game_manager:
		game_manager.add_gold(interest_gold)

	if game_hud and game_hud.has_method("show_floating_text"):
		game_hud.show_floating_text("+%d interest" % interest_gold)

	_refresh_interest_status_ui()

func _level_uses_fixed_pathing() -> bool:
	if level_manager == null:
		return false
	var mode := str(level_manager.level_data.get("enemy_pathing_mode", level_manager.level_data.get("pathing_mode", "fixed_path"))).to_lower()
	return mode == "fixed_path" or bool(level_manager.level_data.get("fixed_path", false))


func _refresh_hud_stats() -> void:
	if game_hud == null or game_manager == null:
		return
	_bind_hud_state_presenter()
	var total_waves := 0
	if wave_manager:
		total_waves = wave_manager.get_total_waves()
	hud_state_presenter.refresh_core_stats(
		int(game_manager.gold),
		int(game_manager.lives),
		int(game_manager.current_wave),
		total_waves
	)

func _hide_old_path_visuals() -> void:
	var old_visual = find_child("PathVisual", true, false)
	if old_visual:
		old_visual.visible = false

	if enemy_path:
		for child in enemy_path.get_children():
			if child is Line2D:
				child.visible = false

func _ensure_level_nodes_exist() -> void:
	if not save_manager:
		save_manager = get_node_or_null("SaveManager")

	# [MetaLayer] Run-state save/continue service
	if save_game_service == null:
		save_game_service = load("res://scripts/meta/save_game_service.gd").new()
		save_game_service.name = "SaveGameService"
		add_child(save_game_service)

	# Local leaderboard (existing — keeps result-panel rank working)
	if leaderboard_service == null or not is_instance_valid(leaderboard_service):
		leaderboard_service = load("res://scripts/core/leaderboard_service.gd").new()
		add_child(leaderboard_service)

	# [MetaLayer] Online leaderboard client
	if online_lb_client == null:
		online_lb_client = load("res://scripts/meta/leaderboard_client.gd").new()
		online_lb_client.name = "OnlineLeaderboardClient"
		add_child(online_lb_client)
		online_lb_client.score_submitted.connect(_on_online_score_submitted)
	level_manager = get_node_or_null("LevelManager")
	pathfinding_manager = get_node_or_null("GridPathfindingManager")
	map_visual_layer = get_node_or_null("MapVisualLayer")

	if level_manager == null:
		level_manager = LevelManager.new()
		level_manager.name = "LevelManager"
		add_child(level_manager)

	if pathfinding_manager == null:
		pathfinding_manager = GRID_PATHFINDING_MANAGER_SCRIPT.new()
		pathfinding_manager.name = "GridPathfindingManager"
		add_child(pathfinding_manager)

	if map_visual_layer == null:
		map_visual_layer = Node2D.new()
		map_visual_layer.name = "MapVisualLayer"
		map_visual_layer.set_script(load(MAP_VISUAL_LAYER_SCRIPT_PATH))
		if map_root:
			map_root.add_child(map_visual_layer)
			map_root.move_child(map_visual_layer, 0) # Behind path, etc.
		elif world_root:
			world_root.add_child(map_visual_layer)
			world_root.move_child(map_visual_layer, 0)
		else:
			add_child(map_visual_layer)

func _ensure_element_progression_manager() -> void:
	if element_progression_manager != null and is_instance_valid(element_progression_manager):
		return
	element_progression_manager = get_node_or_null("ElementProgressionManager")
	if element_progression_manager == null:
		element_progression_manager = ELEMENT_PROGRESSION_MANAGER_SCRIPT.new()
		element_progression_manager.name = "ElementProgressionManager"
		add_child(element_progression_manager)
	if element_progression_manager.has_signal("element_levels_changed"):
		element_progression_manager.element_levels_changed.connect(_on_element_levels_changed)

func _refresh_elemental_tower_catalog() -> void:
	if build_manager == null or game_hud == null:
		return
	var catalog: Dictionary = {}
	var prices: Dictionary = {}
	for tower_id in build_manager.towers_config.keys():
		var cfg: Dictionary = build_manager.towers_config.get(tower_id, {})
		catalog[tower_id] = cfg
		prices[tower_id] = int(cfg.get("cost", 0))
	game_hud.set_tower_catalog(catalog)
	game_hud.set_tower_prices(prices)

func _refresh_elemental_shop() -> void:
	if build_manager == null or game_hud == null:
		return
	var ids: Array[String] = []
	if element_progression_manager and element_progression_manager.has_method("get_buildable_tower_ids"):
		ids = element_progression_manager.get_buildable_tower_ids(build_manager.towers_config)
	ids = _ensure_starter_towers_in_shop(ids)
	var ids_hash := hash(ids)
	if ids_hash == _last_shop_ids_hash:
		return
	_last_shop_ids_hash = ids_hash
	FrameSpikeLogger.begin("shop_rebuild")
	if build_manager.has_method("set_unlocked_tower_ids"):
		build_manager.set_unlocked_tower_ids(ids)
	_bind_hud_state_presenter()
	hud_state_presenter.refresh_tower_shop(ids)
	FrameSpikeLogger.end("shop_rebuild")
	if element_progression_manager and element_progression_manager.has_method("get_element_levels"):
		game_hud.set_element_levels(element_progression_manager.get_element_levels())

func _ensure_starter_towers_in_shop(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for starter_id in STARTER_TOWER_IDS:
		if build_manager and build_manager.towers_config.has(starter_id) and not out.has(starter_id):
			out.append(starter_id)
	for id in ids:
		var tid := str(id)
		if not out.has(tid):
			out.append(tid)
	if out.is_empty():
		out.append("basic_tower_t1")
	return out

func _show_pending_element_choice() -> void:
	if game_hud == null or element_progression_manager == null:
		return
	if element_progression_manager.has_method("has_pending_pick") and element_progression_manager.has_pending_pick():
		game_hud.show_element_choice(
			element_progression_manager.get_element_levels(),
			element_progression_manager.pending_picks,
			_format_interest_rate_percent(),
			_format_next_interest_rate_percent(),
			_can_choose_interest_upgrade(),
			int(element_td_interest_service.upgrade_count if element_td_interest_service else 0),
			int(element_td_interest_service.max_upgrades if element_td_interest_service else DEFAULT_MAX_INTEREST_UPGRADES)
		)

func _on_element_levels_changed(levels: Dictionary) -> void:
	if game_hud:
		game_hud.set_element_levels(levels)
	_refresh_elemental_shop()

func _on_element_choice_requested(option: Variant) -> void:
	_get_elemental_pick_controller().on_element_choice_requested(option)

func _choose_interest_upgrade_pick() -> void:
	_get_elemental_pick_controller().choose_interest_upgrade_pick()

func _resume_auto_next_wave_after_element_choice() -> void:
	# Element choices are awarded after wave 5/10/15... and intentionally pause
	# auto-advance while the popup is open. Once the final pending pick is resolved,
	# return to the normal between-wave countdown so the run does not stall.
	if _has_pending_element_pick():
		return
	if wave_manager == null or wave_manager.is_wave_running or not wave_manager.has_next_wave():
		_refresh_start_wave_ui()
		return
	if current_state == GameState.WAVE_COMPLETE:
		set_game_phase(GameState.BUILD)
	elif current_state != GameState.BUILD:
		_refresh_start_wave_ui()
		return
	call_deferred("_maybe_start_auto_next_wave_countdown")
	_refresh_start_wave_ui()

func _config_unlocked_for_upgrade(cfg: Dictionary) -> bool:
	if element_progression_manager == null or not element_progression_manager.has_method("can_build_tower"):
		return true
	return element_progression_manager.can_build_tower(cfg)

func _locked_upgrade_reason(cfg: Dictionary) -> String:
	if element_progression_manager and element_progression_manager.has_method("get_locked_reason"):
		return element_progression_manager.get_locked_reason(cfg)
	return "Required elements are not unlocked"

func _connect_signals() -> void:
	if main_menu:
		# [MetaLayer] New meta-progression menu signals
		main_menu.new_game_pressed.connect(_on_new_game_pressed)
		main_menu.continue_pressed.connect(_on_continue_requested)
		if main_menu.has_signal("settings_pressed"):
			main_menu.settings_pressed.connect(_on_settings_requested)
		main_menu.leaderboard_pressed.connect(_on_leaderboard_from_menu_requested)
		main_menu.quit_pressed.connect(func(): get_tree().quit())

	if level_select:
		level_select.level_selected.connect(start_game)
		level_select.back_pressed.connect(_on_level_select_back)
		level_select.leaderboard_requested.connect(_on_leaderboard_requested)
		if level_select.has_signal("access_refresh_requested"):
			level_select.access_refresh_requested.connect(_fetch_remote_access_config)

	if game_hud:
		game_hud.start_wave_requested.connect(_on_start_wave_requested)
		game_hud.tower_build_selected.connect(_on_tower_build_selected)
		game_hud.cancel_build_requested.connect(_on_cancel_build_requested)
		game_hud.pause_requested.connect(_on_pause_requested)
		if game_hud.has_signal("speed_change_requested"):
			game_hud.speed_change_requested.connect(_on_speed_change_requested)
		game_hud.restart_requested.connect(restart_level)
		if game_hud.has_signal("settings_requested"):
			game_hud.settings_requested.connect(_on_settings_requested)
		if game_hud.has_signal("pause_level_select_requested"):
			game_hud.pause_level_select_requested.connect(_on_pause_level_select_requested)
		game_hud.upgrade_tower_requested.connect(_on_upgrade_tower_requested)
		game_hud.sell_tower_requested.connect(_on_sell_tower_requested)
		if game_hud.has_signal("element_choice_requested"):
			game_hud.element_choice_requested.connect(_on_element_choice_requested)
		game_hud.deselect_tower_requested.connect(_deselect_tower)
		game_hud.target_mode_changed.connect(_on_target_mode_changed)
		game_hud.main_menu_requested.connect(return_to_menu)
		game_hud.back_to_map_requested.connect(_on_level_select_requested)
		game_hud.next_level_requested.connect(start_next_level)
		game_hud.audio_settings_changed.connect(_on_audio_settings_changed)
		if game_hud.has_signal("display_settings_changed"):
			game_hud.display_settings_changed.connect(_on_display_settings_changed)
		if game_hud.has_signal("performance_settings_changed"):
			game_hud.performance_settings_changed.connect(_on_performance_settings_changed)
		game_hud.reset_audio_requested.connect(_on_reset_audio_requested)

	if debug_panel:
		debug_panel.add_gold_requested.connect(func(a): if game_manager: game_manager.add_gold(a))
		debug_panel.start_next_wave_requested.connect(_on_start_wave_requested)
		debug_panel.kill_all_enemies_requested.connect(_debug_kill_all_enemies)
		debug_panel.clear_projectiles_requested.connect(_debug_clear_projectiles)
		debug_panel.trigger_victory_requested.connect(func(): if game_manager: game_manager.trigger_victory())
		debug_panel.trigger_game_over_requested.connect(func(): if game_manager: game_manager.trigger_game_over())
		debug_panel.restart_requested.connect(restart_level)
		debug_panel.god_mode_toggled.connect(_on_debug_god_mode_toggled)
		debug_panel.level_load_requested.connect(start_game)
		debug_panel.hard_audio_test_requested.connect(func(): if audio_manager: audio_manager.play_generated_test_tone())
		debug_panel.test_sfx_requested.connect(func(): if audio_manager: audio_manager.play_sfx("ui_click", true))
		debug_panel.test_music_requested.connect(func(): if audio_manager: audio_manager.play_music("menu", true))
		debug_panel.test_sfx_master_requested.connect(func(): if audio_manager: audio_manager.play_sfx_on_bus("ui_click", "Master"))
		debug_panel.auto_verify_current_requested.connect(debug_start_auto_verify_current_level)
		debug_panel.solve_current_level_requested.connect(debug_start_auto_verify_current_level)
		debug_panel.auto_verify_level_7_requested.connect(func(): _solve_and_play(7))
		debug_panel.auto_verify_all_requested.connect(debug_start_auto_verify_all_known_plans)
		debug_panel.verify_current_board_requested.connect(debug_verify_current_board)
		debug_panel.auto_solve_current_requested.connect(debug_auto_solve_current_level)
		debug_panel.auto_solve_level_7_requested.connect(debug_auto_solve_level_7)
		debug_panel.auto_play_last_plan_requested.connect(debug_auto_play_last_solved_plan)
		debug_panel.solve_all_levels_requested.connect(debug_auto_solve_all_levels)
		debug_panel.auto_clear_current_requested.connect(debug_auto_clear_current_level)
		debug_panel.auto_clear_level_7_requested.connect(debug_auto_clear_level_7)
		debug_panel.generate_balance_report_requested.connect(debug_generate_balance_report)
		debug_panel.apply_verified_starting_gold_requested.connect(_apply_verified_starting_gold)
		debug_panel.reset_progress_requested.connect(func(): if save_manager: save_manager.clear_save(); restart_level())
		debug_panel.print_progress_requested.connect(func(): if save_manager: save_manager.print_progress())

	if auto_play_verifier:
		auto_play_verifier.state_changed.connect(func(s, msg):
			if debug_panel: debug_panel.update_verifier_status(msg, s == 9)
		)

	if build_manager:
		build_manager.tower_selected.connect(_on_tower_selected)
		build_manager.tower_selection_cleared.connect(_on_tower_selection_cleared)
		build_manager.tower_placed.connect(_on_tower_placed)
		build_manager.placement_failed.connect(_on_placement_failed)
		build_manager.hover_cell_changed.connect(_on_hover_cell_changed)

	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)
		wave_manager.boss_wave_started.connect(_on_boss_wave_started)
		wave_manager.enemy_killed.connect(_on_enemy_killed)
		wave_manager.base_damaged.connect(_on_base_damaged)

	if game_manager:
		game_manager.gold_changed.connect(_on_gold_changed)
		game_manager.lives_changed.connect(game_hud.set_lives)
		game_manager.wave_changed.connect(game_hud.set_wave)
		game_manager.game_over.connect(_on_game_over)
		game_manager.victory.connect(_on_victory)
		game_manager.game_paused.connect(_on_game_paused)
		game_manager.game_resumed.connect(_on_game_resumed)

func _process(delta: float) -> void:
	_update_auto_next_wave_countdown(delta)
	_update_element_td_interest(delta)
	if current_state == GameState.WAVE or current_state == GameState.BUILD or current_state == GameState.WAVE_COMPLETE:
		_update_hero_timers(delta)
		
	if current_state != GameState.BUILD and current_state != GameState.WAVE: return

	if build_manager and build_manager.is_build_mode_active():
		var local_mouse = map_root.to_local(get_global_mouse_position())
		var cell: Vector2i = build_manager.local_to_cell(local_mouse)

		if debug_coordinates and Engine.get_frames_drawn() % 60 == 0:
			if OS.is_debug_build(): print("[Debug] Mouse: global=", get_global_mouse_position(), " map_local=", local_mouse, " cell=", cell)

		if build_preview:
			var validation = build_manager.validate_placement(cell)
			if OS.is_debug_build() and Engine.get_frames_drawn() % 120 == 0:
				if debug_coordinates:
					print("[BuildFlow] preview pos=%s cell=%s can_place=%s reason=%s" % [local_mouse, cell, validation["is_valid"], validation["reason"]])
			var tower_config = build_manager.get_selected_tower_config()
			var role_hint = tower_config.get("description", "")
			build_preview.update_preview(cell, validation["is_valid"], true, build_manager.get_selected_tower_range(), validation["reason"], build_manager.get_selected_tower_footprint(), role_hint)
	elif build_preview:
		build_preview.update_preview(Vector2i(-1, -1), false, false)
		
	# Density Control: Prune effects periodically
	if Engine.get_process_frames() % 60 == 0:
		_clean_effects_container()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and Input.is_key_pressed(KEY_F9) and (OS.is_debug_build() or enable_debug_tools):
			_toggle_sandbox_panel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F1 and (OS.is_debug_build() or enable_debug_tools):
			_toggle_debug_panel()
			get_viewport().set_input_as_handled()
			return

	if is_debug_auto_play_allowed():
		if event.is_action_pressed("debug_auto_verify_current"):
			get_viewport().set_input_as_handled()
			if Input.is_key_pressed(KEY_SHIFT):
				debug_verify_current_board() # Verify board (Simulation)
			else:
				debug_auto_play_current_board() # Auto Play (Real)
		elif event.is_action_pressed("debug_auto_verify_all"):
			get_viewport().set_input_as_handled()
			debug_start_auto_verify_all_known_plans()

func _is_mouse_over_hud() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	if hovered == null: return false
	return game_hud != null and game_hud.is_ancestor_of(hovered)

func _check_tower_click(local_pos: Vector2) -> bool:
	if tower_container == null: return false

	for tower in tower_container.get_children():
		if tower is Node2D:
			var dist = local_pos.distance_to(tower.position)
			if dist < 32: # Half a grid cell
				_select_tower(tower)
				return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if current_state != GameState.BUILD and current_state != GameState.WAVE and current_state != GameState.PAUSED: return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _has_pending_element_pick():
				_show_pending_element_choice()
				_refresh_start_wave_ui()
				get_viewport().set_input_as_handled()
				return
			if build_manager and build_manager.has_selected_tower():
				build_manager.clear_selected_tower()
			elif selected_tower:
				_deselect_tower()
			elif current_state == GameState.BUILD or current_state == GameState.WAVE:
				_on_pause_requested()
			elif current_state == GameState.PAUSED:
				_resume_game()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_R:
			if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
				_on_restart_requested()
				get_viewport().set_input_as_handled()
				return

		# Debug Keys
		if OS.is_debug_build():
			if event.keycode == KEY_F2:
				if game_manager: game_manager.add_gold(100)
			elif event.keycode == KEY_F3:
				_on_start_wave_requested()
			elif event.keycode == KEY_F4:
				_debug_kill_all_enemies()
			elif event.keycode == KEY_F5:
				restart_level()
			elif event.keycode == KEY_F6:
				_on_debug_god_mode_toggled(not game_manager.debug_god_mode if game_manager else false)
			elif event.keycode == KEY_F11 and event.shift_pressed:
				if auto_play_verifier:
					_start_debug_auto_play()

	# Allow deselect interactions during both BUILD and WAVE states.
	if current_state != GameState.BUILD and current_state != GameState.WAVE: return

	if event is InputEventMouseButton and event.pressed:
		var local_mouse = map_root.to_local(get_global_mouse_position())

		# Right click cancels build mode or deselects selected tower.
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if build_manager and build_manager.has_selected_tower():
				build_manager.clear_selected_tower()
				get_viewport().set_input_as_handled()
				return
			elif selected_tower:
				_deselect_tower()
				get_viewport().set_input_as_handled()
				return

		# Left click
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _is_mouse_over_hud(): return

			if build_manager and build_manager.has_selected_tower():
				var hovered_control = get_viewport().gui_get_hovered_control()
				if OS.is_debug_build(): print("[BuildInput] click received. mouse_over_hud=%s hovered=%s" % [_is_mouse_over_hud(), hovered_control])

				if _is_mouse_over_hud():
					if OS.is_debug_build(): print("[BuildInput] click ignored: mouse over HUD")
					return

				if OS.is_debug_build(): print("[BuildFlow] confirm input received local_mouse_pos=%s" % local_mouse)
				# Try place tower using local coordinates
				if build_manager.try_place_tower(local_mouse):
					get_viewport().set_input_as_handled()
					return
				else:
					if OS.is_debug_build(): print("[BuildFlow] click-to-place failed for %s" % build_manager.selected_tower_id)
			else:
				# Manually check for tower selection if not in build mode
				var tower_clicked = _check_tower_click(local_mouse)
				if not tower_clicked:
					_deselect_tower()

	# Two-finger tap deselects selected tower (mobile/touch).
	# Build-placement cancel is already handled in game_hud._handle_build_cancel_input.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = true
			if _touch_points.size() >= 2 and selected_tower and \
					not (build_manager and build_manager.has_selected_tower()):
				_deselect_tower()
				get_viewport().set_input_as_handled()
		else:
			_touch_points.erase(event.index)

# --- Remote Access Config Handlers [DemoGate] --------------------------------

func _fetch_remote_access_config() -> void:
	if remote_access_config_service == null:
		return
	if runtime_identity_service:
		# Register runtime first so backend assigns a runtime_id, then fetch config.
		runtime_identity_service.registered.connect(
			func(_rid: String): remote_access_config_service.refresh_remote_access(),
			CONNECT_ONE_SHOT
		)
		runtime_identity_service.registration_failed.connect(
			func(_reason: String): remote_access_config_service.refresh_remote_access(),
			CONNECT_ONE_SHOT
		)
		runtime_identity_service.register_runtime()
	else:
		remote_access_config_service.refresh_remote_access()

func _on_access_config_updated(source: String) -> void:
	if OS.is_debug_build():
		print("[DemoGate] Config updated from: ", source)

	# Refresh the access status chip on the main menu.
	var version = 1
	if remote_access_config_service:
		version = remote_access_config_service.get_config_version()
	if main_menu and main_menu.has_method("set_access_status"):
		main_menu.set_access_status(source, version)

	# If the player is on the menu, check for blocking states immediately.
	if current_state == GameState.MENU:
		_check_blocking_access_states()

	# Refresh level select cards to reflect any rule change.
	if current_state == GameState.LEVEL_SELECT and level_select and save_manager:
		level_select.update_ui(save_manager)

func _on_access_config_fetch_failed(reason: String) -> void:
	if OS.is_debug_build():
		print("[DemoGate] Remote fetch failed: ", reason)
	# Update status UI to show offline/cached state.
	if remote_access_config_service and main_menu and main_menu.has_method("set_access_status"):
		var src = remote_access_config_service.get_config_source()
		var ver = remote_access_config_service.get_config_version()
		main_menu.set_access_status(src, ver)

## Check for maintenance or force-update and show the appropriate blocking modal.
func _check_blocking_access_states() -> void:
	if level_access_service == null or _demo_gate_modal == null:
		return
	if level_access_service.is_force_update():
		_demo_gate_modal.show_force_update()
		return
	if level_access_service.is_maintenance_enabled():
		var announcement = ""
		if remote_access_config_service:
			announcement = remote_access_config_service.get_announcement()
		_demo_gate_modal.show_maintenance(announcement)

# --- Session Flow ---

func return_to_menu() -> void:
	Engine.time_scale = 1.0
	if game_hud and game_hud.has_method("reset_speed"):
		game_hud.reset_speed()
	set_game_phase(GameState.MENU)
	_clear_route_preview()
	_resume_game()
	_clear_gameplay_state()
	if audio_manager:
		audio_manager.play_music("menu")

func _on_level_select_requested() -> void:
	Engine.time_scale = 1.0
	if game_hud and game_hud.has_method("reset_speed"):
		game_hud.reset_speed()
	_fetch_remote_access_config()
	set_game_phase(GameState.LEVEL_SELECT)
	_clear_route_preview()
	_play_ui_click()
	if audio_manager:
		audio_manager.play_music("menu")
	if pending_unlock_level_id != "" and level_select:
		level_select.show_unlocked_notification(pending_unlock_level_id)
		pending_unlock_level_id = ""

func _update_hero_timers(delta: float) -> void:
	if hero_is_deployed:
		if is_instance_valid(current_hero):
			hero_active_duration = current_hero.active_duration_current
			if hero_panel:
				hero_panel.update_duration(hero_active_duration)
		else:
			# Hero retreated
			hero_is_deployed = false
			hero_active_duration = 0
			if level_manager:
				hero_cooldown = level_manager.hero_config.get("cooldown", 30)
				if OS.is_debug_build(): print("[HeroDeploy] cooldown started seconds=%.1f" % hero_cooldown)
	
	elif hero_cooldown > 0:
		hero_cooldown -= delta
		if hero_panel and level_manager:
			hero_panel.set_cooldown(hero_cooldown, level_manager.hero_config.get("cooldown", 30))
		if hero_cooldown <= 0:
			if hero_panel: hero_panel.set_ready()
			if OS.is_debug_build(): print("[HeroDeploy] cooldown ready")
	
	elif hero_panel and game_manager and level_manager:
		var cost = level_manager.hero_config.get("deploy_cost", 120)
		hero_panel.set_insufficient_gold(game_manager.gold < cost)

func _on_level_select_back() -> void:
	set_game_phase(GameState.MENU)
	_clear_route_preview()
	_play_ui_click()

func _on_settings_requested() -> void:
	if settings_menu and settings_menu.has_method("open"):
		settings_menu.open()
	_play_ui_click()

func _on_pause_level_select_requested() -> void:
	_stop_auto_next_wave_countdown()
	_clear_gameplay_state()
	if scene_navigation_service and scene_navigation_service.has_method("go_to_level_select_safe"):
		scene_navigation_service.go_to_level_select_safe()
	else:
		_clear_transient_combat_ui()
		_resume_game()
		_on_level_select_requested()
	_play_ui_click()

func _on_leaderboard_requested(level_id: String) -> void:
	if leaderboard_panel == null:
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 5
		canvas_layer.name = "LeaderboardLayer"
		add_child(canvas_layer)
		
		leaderboard_panel = load("res://scenes/ui/LeaderboardPanel.tscn").instantiate()
		canvas_layer.add_child(leaderboard_panel)
		leaderboard_panel.close_pressed.connect(func(): leaderboard_panel.get_parent().visible = false)
		
	if OS.is_debug_build(): print("[Main] Opening leaderboard for level: %s" % level_id)
	leaderboard_panel.get_parent().visible = true
	# [MetaLayer] Pass online client so the panel can fetch live scores
	if leaderboard_panel.has_method("show_leaderboard"):
		leaderboard_panel.show_leaderboard(leaderboard_service, level_id, online_lb_client)

func start_game(level_path: String) -> void:
	# [MetaLayer] A level was chosen from the selector — this is a new run, discard any existing save.
	# [DemoGate] Enforce access before touching any game state.
	var _level_id_str := level_path.get_file().get_basename()
	var _level_num := level_id_to_int(_level_id_str)
	if level_access_service and not level_access_service.can_play_level(_level_num):
		if OS.is_debug_build():
			var _reason: String = level_access_service.get_locked_reason(_level_num) if level_access_service else "unknown"
			print("[DemoGate] start_game BLOCKED path=%s base=%s level_num=%d reason=%s mode=%s source=%s resolved_from=%s" % [
				level_path,
				_level_id_str,
				_level_num,
				_reason,
				level_access_service.get_access_mode(),
				level_access_service.get_access_source(),
				level_access_service.get_resolved_from()
			])
		if _demo_gate_modal:
			var _cfg_for_modal := get_level_config(_level_id_str)
			var _level_name: String = _cfg_for_modal.get("name", _level_id_str.replace("level_", "Level "))
			_demo_gate_modal.show_locked(_level_name)
		return
	if save_game_service:
		save_game_service.delete_save()
	start_level(level_path)

func start_level(level_path: String) -> void:
	current_level_path = level_path
	_invalidate_wave_preview_cache()
	_last_shop_ids_hash = 0 # Force shop rebuild for this level.

	# STANDARD: Ensure engine is unpaused when starting a level
	get_tree().paused = false
	if game_manager: game_manager.is_paused = false

	if game_hud:
		game_hud.exit_end_game_ui_state()
		game_hud.clear_wave_intel()

	if OS.is_debug_build(): print("[Main] start_level: ", level_path)

	_clear_gameplay_state()
	var vfx_pool := get_node_or_null("/root/VisualEffectPoolService")
	if vfx_pool != null and vfx_pool.has_method("prewarm_level_pools"):
		vfx_pool.prewarm_level_pools()

	if level_manager:
		if level_manager.load_level(level_path):
			current_level_id = level_manager.level_id
			selected_level_id = level_id_to_int(current_level_id)
			_setup_game_from_level()
		else:
			push_error("Failed to load level: " + level_path)
			return_to_menu()
			return

	set_game_phase(GameState.BUILD)
	_refresh_hud_wave_intel()
	_refresh_route_preview()

	if audio_manager:
		audio_manager.play_music("gameplay")

	# Recalculate camera fit after the HUD has finished its layout pass.
	call_deferred("_update_world_layout")

func restart_level() -> void:
	if OS.is_debug_build(): print("[Main] restart_level requested for: ", current_level_path)
	if get_tree().paused:
		get_tree().paused = false

	Engine.time_scale = 1.0
	if game_hud and game_hud.has_method("reset_speed"):
		game_hud.reset_speed()

	if game_hud:
		game_hud.exit_end_game_ui_state()

	# [MetaLayer] Restart = fresh run — discard any existing run save.
	if save_game_service:
		save_game_service.delete_save()

	if current_level_path != "":
		start_level(current_level_path)
	_play_ui_click()

func start_next_level() -> void:
	if save_manager and current_level_id != "":
		var next_id = save_manager.get_next_level_id(current_level_id)
		var next_path = "res://data/levels/%s.json" % next_id
		if FileAccess.file_exists(next_path):
			set_game_phase(GameState.LEVEL_SELECT)
			if level_select:
				level_select.select_level(next_path)
		else:
			return_to_menu()
	else:
		return_to_menu()

func _clear_gameplay_state() -> void:
	_show_wave_complete_status_feedback = false
	if tower_container:
		for tower in tower_container.get_children():
			tower.queue_free()
	if projectile_container:
		var pool := get_node_or_null("/root/ProjectilePool")
		if pool != null:
			pool.release_active()
		# Free any non-pooled overflow projectiles still in the container.
		for proj in projectile_container.get_children():
			if is_instance_valid(proj) and not proj.has_meta("pooled"):
				proj.queue_free()
	if effects_container:
		var imp_pool := get_node_or_null("/root/ImpactVFXPool")
		if imp_pool != null:
			imp_pool.release_active()
		var vfx_pool := get_node_or_null("/root/VisualEffectPoolService")
		if vfx_pool != null and vfx_pool.has_method("release_active"):
			vfx_pool.release_active()
		for effect in effects_container.get_children():
			if is_instance_valid(effect) and not effect.has_meta("pooled"):
				effect.queue_free()

	if current_hero:
		current_hero.queue_free()
		current_hero = null
	if hero_panel:
		hero_panel.queue_free()
		hero_panel = null
		
	hero_is_deployed = false
	hero_cooldown = 0
	hero_active_duration = 0
	if OS.is_debug_build(): print("[HeroLifecycle] reset")

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

	_deselect_tower()
	if wave_manager:
		wave_manager.reset_waves() # Stop spawning and reset counters
	if build_manager:
		build_manager.reset_build_state()
	if build_preview:
		build_preview.update_preview(Vector2i(-1, -1), false, false)
	if game_hud:
		game_hud.clear_wave_intel()
		if game_hud.has_method("exit_end_game_ui_state"):
			game_hud.exit_end_game_ui_state()
	_clear_route_preview()

	# Setup UI
	if game_hud and level_manager and level_manager.hero_config.get("enabled", false):
		_setup_hero_ui()
	elif hero_panel:
		hero_panel.hide()

func _clear_transient_combat_ui() -> void:
	_clear_route_preview()
	if settings_menu:
		settings_menu.hide()
	if game_hud:
		if game_hud.has_method("set_paused"):
			game_hud.set_paused(false)
		if game_hud.has_method("hide_center_message"):
			game_hud.hide_center_message()
		if game_hud.has_method("clear_wave_intel"):
			game_hud.clear_wave_intel()

func _setup_hero_ui() -> void:
	if hero_panel:
		hero_panel.queue_free()
		
	var panel_scene = load("res://scenes/ui/HeroPanel.tscn")
	if not panel_scene: return
	
	hero_panel = panel_scene.instantiate()
	game_hud.add_child(hero_panel)
	
	# Position bottom-left
	hero_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hero_panel.position += Vector2(20, -100)
	
	hero_panel.setup_ui(level_manager.hero_config)
	hero_panel.deploy_requested.connect(_on_hero_deploy_requested)
	
	if hero_cooldown > 0:
		hero_panel.set_cooldown(hero_cooldown, level_manager.hero_config.get("cooldown", 30))
	elif hero_is_deployed:
		# Should not happen on setup unless mid-restart logic is weird
		pass

func _on_hero_deploy_requested() -> void:
	if hero_is_deployed or hero_cooldown > 0: return
	if not level_manager or not game_manager: return
	
	var cost = level_manager.hero_config.get("deploy_cost", 120)
	if game_manager.gold < cost:
		if OS.is_debug_build(): print("[BuildFlow] place failed: Not enough gold for hero! (needed %d)" % cost)
		return
		
	if game_manager.spend_gold(cost):
		if OS.is_debug_build(): print("[BuildFlow] hero deployed cost=%d" % cost)
		_spawn_hero_unit()
		if game_manager.battle_telemetry:
			# Get a reasonable world position (spawn_pos is set in _spawn_hero_unit, but we can log after)
			game_manager.battle_telemetry.log_hero_deployed(current_hero.global_position if current_hero else Vector2.ZERO, cost)
		update_hud() # Update gold display

func _spawn_hero_unit() -> void:
	var hero_scene = load("res://scenes/units/HeroGuardian.tscn")
	if not hero_scene: return
	
	current_hero = hero_scene.instantiate()
	
	# Configuration and Bounds
	var battlefield_bounds = Rect2(Vector2(0, 0), Vector2(2560, 1440))
	if level_manager:
		battlefield_bounds = Rect2(Vector2(0, 0), Vector2(level_manager.grid_cols * level_manager.grid_size, level_manager.grid_rows * level_manager.grid_size))
	
	# Find rally point: near the base (last path point)
	var rally_pos = Vector2(1000, 384) # Default
	if level_manager:
		var path = level_manager.get_path_points()
		if path.size() > 0:
			rally_pos = path[path.size() - 1] + Vector2(-80, 0)
	
	# Intelligent Spawn Position
	var spawn_pos = rally_pos
	var spawn_mode = "rally_point"
	var target_enemy = null
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var active_enemies = []
	for e in enemies:
		if is_instance_valid(e) and e.has_method("is_alive") and e.is_alive():
			active_enemies.append(e)
			
	if active_enemies.size() > 0:
		# Pick best target (furthest along path)
		var max_prog = -1.0
		for e in active_enemies:
			if e.has_method("get_path_progress"):
				var prog = e.get_path_progress()
				if prog > max_prog:
					max_prog = prog
					target_enemy = e
		
		if is_instance_valid(target_enemy):
			spawn_mode = "near_enemy"
			# Spawn offset from enemy (approx 100px)
			# Try to spawn towards the center of map
			var offset_dir = (Vector2(640, 384) - target_enemy.global_position).normalized()
			spawn_pos = target_enemy.global_position + offset_dir * 100.0
	
	# Clamp spawn position to bounds
	spawn_pos.x = clamp(spawn_pos.x, battlefield_bounds.position.x + 50, battlefield_bounds.end.x - 50)
	spawn_pos.y = clamp(spawn_pos.y, battlefield_bounds.position.y + 50, battlefield_bounds.end.y - 50)
	
	if OS.is_debug_build():
		print("[HeroDeploy] active_enemies=%d" % active_enemies.size())
		if spawn_mode == "near_enemy":
			print("[HeroDeploy] spawn_mode=near_enemy target=%s spawn_pos=%s" % [target_enemy.name, str(spawn_pos)])
		else:
			print("[HeroDeploy] spawn_mode=rally_point spawn_pos=%s" % str(spawn_pos))

	var units_container = get_node_or_null("WorldRoot/MapRoot/UnitsContainer")
	if units_container:
		units_container.add_child(current_hero)
	else:
		add_child(current_hero)
		
	# Initialize Hero stats and position
	current_hero.initialize_hero(spawn_pos, rally_pos, battlefield_bounds)
	
	var h_cfg = level_manager.hero_config
	current_hero.active_duration_max = h_cfg.get("duration", 28.0)
	current_hero.active_duration_current = current_hero.active_duration_max
	current_hero.max_hp = h_cfg.get("hp", 450.0)
	current_hero.current_hp = current_hero.max_hp
	current_hero.damage = h_cfg.get("damage", 36.0)
	current_hero.attack_speed = h_cfg.get("attack_speed", 1.4)
	current_hero.attack_range = h_cfg.get("attack_range", 125.0)
	current_hero.move_speed = h_cfg.get("move_speed", 220.0)
	
	if current_hero.has_method("_update_range_collision"): current_hero._update_range_collision()
	if current_hero.has_method("_update_range_visual"): current_hero._update_range_visual()
	
	# Trigger Shockwave at FINAL spawn position
	if current_hero.has_method("trigger_shockwave"):
		current_hero.trigger_shockwave()
	
	hero_is_deployed = true
	if hero_panel:
		hero_panel.set_deployed(current_hero, current_hero.active_duration_max)
		
	if OS.is_debug_build():
		print("[HeroDeploy] deployed hero=Guardian duration=%.1f" % current_hero.active_duration_max)
		print("[HeroDeploy] deploy requested cost=%d gold=%d" % [level_manager.hero_config.get("deploy_cost", 100), game_manager.gold])


# --- Gameplay Handlers ---

func _on_restart_requested() -> void:
	restart_level()

func _on_speed_change_requested(multiplier: float) -> void:
	Engine.time_scale = multiplier

func _on_pause_requested() -> void:
	if game_manager:
		if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
			return
		if game_manager.is_paused:
			_resume_game()
		else:
			_pause_game()

func _pause_game() -> void:
	if game_manager:
		game_manager.pause_game()
	if audio_manager:
		audio_manager.play_sfx("pause")

func _resume_game() -> void:
	if game_manager:
		game_manager.resume_game()
	if audio_manager:
		audio_manager.play_sfx("resume")

func shake_camera(strength: float, duration: float = 1.0) -> void:
	var active_camera = get_node_or_null("Camera2D")
	if active_camera and active_camera.has_method("shake"):
		active_camera.shake(strength, duration)

func show_wave_feedback(text: String, color: Color = Color.WHITE) -> void:
	if game_hud and game_hud.has_method("show_temporary_message"):
		game_hud.show_temporary_message(text, color)

func set_game_phase(new_state: GameState) -> void:
	if current_state == new_state: return

	var old_state = current_state
	current_state = new_state

	if OS.is_debug_build(): print("[Main] State changed: ", old_state, " -> ", new_state)

	_refresh_ui_for_phase()

func _refresh_ui_for_phase() -> void:
	# Hide everything by default for safety, then show what's needed
	var panels = {
		"menu": main_menu,
		"select": level_select,
		"hud": game_hud,
		"world": world_root,
		"debug": debug_panel,
		"hero": hero_panel
	}

	for key in panels:
		var p = panels[key]
		if p:
			p.hide()
			if p is Control: p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			elif p is CanvasLayer:
				# CanvasLayer doesn't have mouse_filter, but its children do.
				# We usually rely on .hide() for CanvasLayer.
				pass

	match current_state:
		GameState.MENU:
			if main_menu:
				main_menu.show()
				main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
				# [MetaLayer] Refresh continue button state and restore saved player name
				if main_menu.has_method("set_has_save") and save_game_service:
					main_menu.set_has_save(save_game_service.has_valid_save())
				if main_menu.has_method("set_player_name") and save_manager:
					main_menu.set_player_name(save_manager.get_player_name())
				# [DemoGate] Update access status chip with current source/version.
				if remote_access_config_service and main_menu.has_method("set_access_status"):
					main_menu.set_access_status(
						remote_access_config_service.get_config_source(),
						remote_access_config_service.get_config_version()
					)
			get_tree().paused = false
			# [DemoGate] Check maintenance / force-update after menu is visible.
			call_deferred("_check_blocking_access_states")

		GameState.LEVEL_SELECT:
			if level_select:
				level_select.update_ui(save_manager)
				level_select.show()
			get_tree().paused = false

		GameState.BUILD:
			if game_hud:
				game_hud.show()
				game_hud.set_paused(false)
				game_hud.enter_gameplay_mode()
				game_hud.show_build_panel()
				game_hud.set_build_status("Planning Phase — build your maze")
				if game_hud.has_method("set_wave_intel_visible"): game_hud.set_wave_intel_visible(true)
				_refresh_gameplay_hud_state()
			if hero_panel:
				var hero_enabled = level_manager.hero_config.get("enabled", false) if level_manager else false
				hero_panel.visible = hero_enabled
				if OS.is_debug_build(): print("[HERO_UI] visible=", hero_panel.visible, " reason=GameState.BUILD")
			if world_root: world_root.show()
			get_tree().paused = false

		GameState.WAVE:
			if game_hud:
				game_hud.show()
				game_hud.set_paused(false)
				game_hud.enter_gameplay_mode()
				if game_hud.has_method("set_wave_intel_visible"): game_hud.set_wave_intel_visible(true)
				_refresh_gameplay_hud_state()
			if hero_panel:
				var hero_enabled = level_manager.hero_config.get("enabled", false) if level_manager else false
				hero_panel.visible = hero_enabled
				if OS.is_debug_build(): print("[HERO_UI] visible=", hero_panel.visible, " reason=GameState.WAVE")
			if world_root: world_root.show()
			get_tree().paused = false

		GameState.WAVE_COMPLETE:
			if game_hud:
				game_hud.show()
				game_hud.set_paused(false)
				game_hud.enter_gameplay_mode()
				if game_hud.has_method("set_wave_intel_visible"): game_hud.set_wave_intel_visible(true)
				_refresh_gameplay_hud_state()
			if hero_panel:
				var hero_enabled = level_manager.hero_config.get("enabled", false) if level_manager else false
				hero_panel.visible = hero_enabled
			if world_root: world_root.show()
			get_tree().paused = false

		GameState.PAUSED:
			if game_hud:
				game_hud.show() # Keep HUD visible behind pause
				game_hud.set_paused(true)
			if world_root: world_root.show()
			get_tree().paused = true

		GameState.GAME_OVER:
			if game_hud:
				game_hud.show()
				game_hud.enter_result_overlay()
			if world_root: world_root.show()

		GameState.VICTORY:
			if game_hud:
				game_hud.show()
				game_hud.enter_result_overlay()
			if world_root: world_root.show()

func _on_game_paused() -> void:
	set_game_phase(GameState.PAUSED)

func _on_game_resumed() -> void:
	if current_state == GameState.PAUSED:
		# Restore based on wave state
		if wave_manager and wave_manager.is_wave_running:
			set_game_phase(GameState.WAVE)
		else:
			set_game_phase(GameState.BUILD)

func _on_tower_build_selected(tower_id: String) -> void:
	if current_state != GameState.BUILD: return
	_deselect_tower()
	if build_manager:
		build_manager.set_selected_tower(tower_id)
	_play_ui_click()

func _on_tower_placed(tower: Node2D, _tower_id: String, _cost: int) -> void:
	if tower.has_signal("clicked"):
		tower.clicked.connect(_on_placed_tower_clicked)
	if tower.has_signal("upgrade_completed"):
		var upgrade_callback := Callable(self , "_on_tower_upgrade_completed")
		if not tower.is_connected("upgrade_completed", upgrade_callback):
			tower.connect("upgrade_completed", upgrade_callback)
	if audio_manager:
		audio_manager.play_sfx("tower_place")

func _on_tower_upgrade_completed(tower: Node2D, _old_tower_id: String, old_tier: int, _new_tower_id: String, new_tier: int, cost: int) -> void:
	if game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_tower_upgraded(tower.tower_id, old_tier, new_tier, cost)
	if selected_tower == tower and game_hud:
		var info: Dictionary = tower.get_info() if tower.has_method("get_info") else {}
		if not info.is_empty():
			game_hud.show_tower_info(info)
			if game_hud.has_method("show_tower_float_card"):
				game_hud.show_tower_float_card(info, tower)
		game_hud.set_build_status("Tower Upgraded!")
	if audio_manager:
		audio_manager.play_sfx("tower_upgrade")

func _on_placed_tower_clicked(tower: Node2D) -> void:
	if current_state != GameState.BUILD and current_state != GameState.WAVE: return
	if build_manager and build_manager.has_selected_tower(): return
	_select_tower(tower)
	_play_ui_click()

func _select_tower(tower: Node2D) -> void:
	# Fix: Always clear previous selection first to avoid stale range circles
	clear_selected_tower()

	if is_instance_valid(tower):
		selected_tower = tower
		_get_tower_interaction_controller().set_selected_tower(tower)
		if selected_tower.has_method("set_selected"):
			selected_tower.set_selected(true)
		if game_hud:
			var _info: Dictionary = selected_tower.get_info()
			game_hud.show_tower_info(_info)
			if game_hud.has_method("show_tower_float_card"):
				game_hud.show_tower_float_card(_info, selected_tower)
	else:
		clear_selected_tower()

func clear_selected_tower() -> void:
	if selected_tower and is_instance_valid(selected_tower):
		if selected_tower.has_method("set_selected"):
			selected_tower.set_selected(false)
	selected_tower = null
	_get_tower_interaction_controller().clear_selected_tower()
	if game_hud:
		game_hud.hide_tower_info()
		if game_hud.has_method("hide_tower_float_card"):
			game_hud.hide_tower_float_card()

func _deselect_tower() -> void:
	clear_selected_tower()

func _on_upgrade_tower_requested() -> void:
	if selected_tower == null:
		return
	if not can_upgrade_selected_tower():
		if game_hud:
			var preview := get_selected_tower_upgrade_preview()
			var locked_reason := str(preview.get("locked_reason", "")).strip_edges()
			if locked_reason.is_empty():
				locked_reason = "Upgrade unavailable"
			game_hud.set_build_status(locked_reason)
			show_wave_feedback(locked_reason, Color(1.0, 0.55, 0.2))
		return

	var next_cfg: Dictionary = {}
	if selected_tower.has_method("get_next_upgrade_config"):
		next_cfg = selected_tower.get_next_upgrade_config()
	else:
		var next_ids: Array = selected_tower.get_info().get("next_upgrade_ids", [])
		if not next_ids.is_empty():
			next_cfg = build_manager.towers_config.get(str(next_ids[0]), {})
	if next_cfg.is_empty():
		if game_hud:
			game_hud.set_build_status("Upgrade unavailable")
		show_wave_feedback("Upgrade unavailable", Color(1.0, 0.55, 0.2))
		return
	if not _config_unlocked_for_upgrade(next_cfg):
		var locked_reason := _locked_upgrade_reason(next_cfg)
		if game_hud:
			game_hud.set_build_status(locked_reason)
		show_wave_feedback(locked_reason, Color(1.0, 0.55, 0.2))
		return

	var cost: int = selected_tower.get_upgrade_cost()
	if cost <= 0:
		if game_hud:
			game_hud.set_build_status("Upgrade unavailable")
			show_wave_feedback("Upgrade unavailable", Color(1.0, 0.55, 0.2))
		return

	if game_manager and game_manager.spend_gold(cost):
		var tower := selected_tower
		if tower.upgrade():
			if game_hud:
				game_hud.set_build_status("Upgrading tower...")
				var info: Dictionary = tower.get_info() if tower.has_method("get_info") else {}
				if not info.is_empty():
					game_hud.show_tower_info(info)
		elif game_hud:
			game_hud.set_build_status("Upgrade unavailable")
	elif game_hud:
		game_hud.set_build_status("Not enough gold!")
	_play_ui_click()


## Reads upgrade_cost from a tower config dict — the cost to upgrade INTO it.
func _read_config_upgrade_cost(p_config: Dictionary) -> int:
	if p_config.is_empty():
		return -1
	if p_config.has("levels") and p_config["levels"].size() > 0:
		var cost_val = p_config["levels"][0].get("upgrade_cost", -1)
		if cost_val > 0:
			return cost_val
	return p_config.get("upgrade_cost", -1)


func _on_sell_tower_requested() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return
	if current_state != GameState.BUILD:
		return

	var cell: Vector2i = selected_tower.get_grid_cell()
	var refund: int = selected_tower.get_sell_refund()

	# Remove tower via build manager (handles occupancy + pathfinding blocker)
	if build_manager and build_manager.has_method("remove_tower_at_cell"):
		build_manager.remove_tower_at_cell(cell)

	# Refund gold
	if game_manager:
		game_manager.add_gold(refund)

	# Clear selection UI
	_deselect_tower()

	if game_hud:
		game_hud.set_build_status("Tower sold ($%d refunded)" % refund)

	if audio_manager:
		audio_manager.play_sfx("ui_click")


func _on_target_mode_changed(mode: String) -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return
	if selected_tower.has_method("set_target_mode"):
		selected_tower.set_target_mode(mode)
		game_hud.show_tower_info(selected_tower.get_info())
	_play_ui_click()

func _on_start_wave_requested() -> void:
	if current_state != GameState.BUILD and current_state != GameState.WAVE_COMPLETE:
		return
	if _has_pending_element_pick():
		if game_hud:
			game_hud.set_build_status("Choose an element before starting the next wave")
		_show_pending_element_choice()
		_refresh_start_wave_ui()
		return
	if wave_manager == null or not wave_manager.has_next_wave():
		return
	_stop_auto_next_wave_countdown()
	if auto_next_wave_service:
		auto_next_wave_service.mark_first_wave_started()
	if audio_manager: audio_manager.unlock_audio()
	wave_manager.start_next_wave()
	if audio_manager:
		audio_manager.play_sfx("start_wave")
	_refresh_start_wave_ui()

func _on_cancel_build_requested() -> void:
	if build_manager:
		build_manager.clear_selected_tower()
	_play_ui_click()

func _on_tower_selected(_tower_id: String) -> void:
	if build_manager:
		var config = build_manager.get_selected_tower_config()
		var tower_name = config.get("name", _tower_id.capitalize())
		if game_hud:
			var hint = " - Select foundation" if level_manager.buildable_mode == "manual" else " - Select location"
			game_hud.set_build_status("Selected: " + tower_name + hint)

func _on_tower_selection_cleared() -> void:
	if game_hud:
		game_hud.set_build_status("None")

func _on_placement_failed(_reason: String) -> void:
	if game_hud:
		game_hud.set_build_status(_reason)

func _on_hover_cell_changed(cell: Vector2i, is_valid: bool, reason: String) -> void:
	if build_manager:
		var tower_range = build_manager.get_selected_tower_range()
		if build_preview:
			# Only update if build mode is actually active
			if build_manager.has_selected_tower():
				var tower_config = build_manager.get_selected_tower_config()
				var role_hint = tower_config.get("description", "")
				build_preview.update_preview(cell, is_valid, true, tower_range, reason, build_manager.get_selected_tower_footprint(), role_hint)
		
		if build_manager.has_selected_tower() and game_hud:
			var status = "Ready to build" if is_valid else reason
			if not is_valid and reason == "Restricted zone":
				status = "Requires Foundation"
			
			# Gate coordinate info behind debug_coordinates to keep production UI clean
			var label_text = status
			if debug_coordinates and OS.is_debug_build():
				label_text += " at " + str(cell)
			game_hud.set_build_status(label_text)

func _on_wave_started(wave_number: int, wave_name: String) -> void:
	_wave_intel_dirty = true
	_show_wave_complete_status_feedback = false
	if damage_stats_tracker and damage_stats_tracker.has_method("reset_wave"):
		damage_stats_tracker.reset_wave()
	if element_td_interest_service:
		element_td_interest_service.elapsed = 0.0
		element_td_interest_service.disabled_for_wave = false
	_stop_auto_next_wave_countdown()
	_clear_route_preview()
	set_game_phase(GameState.WAVE)
	if game_manager:
		game_manager.set_current_wave(wave_number)
	if game_hud:
		game_hud.set_status("In Progress")
		show_wave_feedback("Wave %d: %s" % [wave_number, wave_name], Color(1, 0.8, 0.2))
		_refresh_gameplay_hud_state()

func _on_boss_wave_started(_wave_number: int) -> void:
	if audio_manager:
		audio_manager.play_sfx("boss_alert")
		audio_manager.set_music_pitch(1.18)
	shake_camera(8.0, 0.5)
	show_wave_feedback("BOSS WAVE!", Color(1.0, 0.2, 0.2))

func _on_wave_completed(wave_number: int, _wave_name: String, reward: int) -> void:
	_wave_intel_dirty = true
	if element_td_interest_service:
		element_td_interest_service.elapsed = 0.0
		element_td_interest_service.disabled_for_wave = false
	if game_manager:
		game_manager.award_wave_completion(reward)
	_show_wave_complete_status_feedback = true
	set_game_phase(GameState.BUILD)
	shake_camera(5.5, 0.6)
	if game_hud:
		game_hud.set_status("Wave Complete")
		show_wave_feedback("Wave Cleared! +%d Gold" % reward, Color(0.2, 1.0, 0.4))
		_refresh_gameplay_hud_state()
	if audio_manager:
		audio_manager.play_sfx("wave_clear")
		audio_manager.set_music_pitch(1.0)
	if element_progression_manager and wave_number > 0 and wave_number % ELEMENT_PICK_INTERVAL == 0:
		element_progression_manager.grant_pick(1)
		_show_pending_element_choice()

	# [MetaLayer] Auto-save run state after each wave clear (safe point: gold/wave updated)
	_auto_save_run_state()

	# [DemoGate] If the demo wave cap was just reached, intercept before the next wave.
	if level_access_service and level_access_service.is_demo_wave_cap_reached(wave_number):
		if OS.is_debug_build():
			print("[DemoGate] Demo wave cap reached at wave %d — showing Demo Complete." % wave_number)
		# Stop enemies and prevent further wave progression.
		if wave_manager:
			wave_manager.reset_waves()
		var _summary := {
			"level_id": current_level_id,
			"waves_cleared": wave_number,
			"gold": game_manager.gold if game_manager else 0,
			"lives": game_manager.lives if game_manager else 0,
		}
		get_tree().create_timer(2.0).timeout.connect(func():
			if _demo_gate_modal:
				_demo_gate_modal.show_demo_complete(_summary)
		)
		return

	# Keep the reward moment visual-only; planning controls unlock immediately.
	get_tree().create_timer(2.5).timeout.connect(func():
		if current_state == GameState.BUILD:
			_show_wave_complete_status_feedback = false
			_maybe_start_auto_next_wave_countdown()
	)

func _on_all_waves_completed() -> void:
	if game_manager:
		game_manager.trigger_victory()
	_clear_route_preview()
	_refresh_gameplay_hud_state()
	if game_hud and game_hud.has_method("set_wave_intel_visible"):
		game_hud.set_wave_intel_visible(false)

func _on_enemy_killed(reward_gold: int) -> void:
	if game_manager:
		game_manager.add_kill_score(reward_gold)
		game_manager.add_gold(reward_gold)
	if audio_manager:
		audio_manager.play_sfx("enemy_die")

func _on_gold_changed(new_gold: int) -> void:
	if game_hud:
		game_hud.set_gold(new_gold)
	_refresh_interest_status_ui()

func _on_base_damaged(base_damage: int, global_pos: Vector2) -> void:
	# Element TD-style leak respawn still lets the creep be killed later,
	# but interest for this wave stops after a leak to avoid abuse.
	if element_td_interest_service:
		element_td_interest_service.disable_for_current_wave()
		element_td_interest_service.elapsed = 0.0
	if game_manager:
		game_manager.damage_base(base_damage)

	shake_camera(15.0, 0.4)
	if game_hud:
		game_hud.show_screen_flash(Color(0.8, 0.1, 0.1, 0.4), 0.3)

	# Spawn impact effect at leak position — use ImpactVFXPool to avoid per-leak allocations.
	var container = get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if container == null:
		container = self
	var imp_pool := get_node_or_null("/root/ImpactVFXPool")
	var effect: Node = null
	if imp_pool != null and imp_pool.has_method("acquire"):
		effect = imp_pool.acquire(container)
	if effect == null:
		# Pool exhausted fallback — instantiate directly (rare).
		var impact_scene: PackedScene = load("res://scenes/effects/ImpactEffect.tscn")
		if impact_scene:
			effect = impact_scene.instantiate()
			container.add_child(effect)
	if effect:
		effect.global_position = global_pos
		if effect.has_method("setup"):
			effect.setup(Color(1, 0, 0), 3.0)
		if OS.is_debug_build():
			print("[BaseDamageFX] leak_global=", global_pos, " fx.global=", effect.global_position, " container=", container.name)

	if audio_manager:
		audio_manager.play_sfx("enemy_reach_base")

func _on_game_over() -> void:
	if OS.is_debug_build(): print("[Main] Game Over Triggered")
	set_game_phase(GameState.GAME_OVER)
	_clear_route_preview()
	# [MetaLayer] Run is over — remove run save so continue is disabled
	if save_game_service:
		save_game_service.delete_save()

	clear_selected_tower()
	if build_manager and build_manager.has_method("cancel_build_mode"):
		build_manager.cancel_build_mode()

	# Stop all combat
	if wave_manager:
		wave_manager.reset_waves() # Stop spawning

	_clear_projectiles_and_targeting()

	var total_waves = wave_manager.get_total_waves() if wave_manager else 0
	var summary = game_manager.get_run_summary(total_waves)
	var improvements = {}
	var rank = -1
	
	if save_manager and level_manager:
		improvements = save_manager.update_level_record(level_manager.level_id, summary)
		# [DemoGate] Only submit to leaderboard when permitted.
		var _lb_allowed: bool = (level_access_service == null or level_access_service.can_submit_leaderboard())
		if leaderboard_service and _lb_allowed:
			rank = leaderboard_service.submit_score(level_manager.level_id, summary, save_manager.get_player_name())
		# [MetaLayer] Submit to online leaderboard (async, no crash if offline)
		if _lb_allowed:
			_submit_online_score(summary)

	if game_hud:
		game_hud.show_run_summary(summary, improvements, rank)
		if OS.is_debug_build(): print("[ResultPanel] shown for ", current_level_id)

	_refresh_gameplay_hud_state()
	if audio_manager:
		audio_manager.play_sfx("game_over")

func _clear_projectiles_and_targeting() -> void:
	if projectile_container:
		# Return pooled projectiles before freeing; avoids orphaned pool nodes.
		var pool := get_node_or_null("/root/ProjectilePool")
		if pool != null:
			pool.release_active()
		for proj in projectile_container.get_children():
			if is_instance_valid(proj) and not proj.has_meta("pooled"):
				proj.queue_free()

	# Clear all tower targeting lines
	if tower_container:
		for tower in tower_container.get_children():
			if tower.has_method("clear_targeting_line"):
				tower.clear_targeting_line()

func _on_victory() -> void:
	set_game_phase(GameState.VICTORY)
	_clear_route_preview()
	# [MetaLayer] Run cleared — remove run save so continue is disabled
	if save_game_service:
		save_game_service.delete_save()

	clear_selected_tower()
	if build_manager and build_manager.has_method("cancel_build_mode"):
		build_manager.cancel_build_mode()

	var total_waves = wave_manager.get_total_waves() if wave_manager else 0
	var summary = game_manager.get_run_summary(total_waves)
	var improvements = {}
	var rank = -1

	# Save progress
	if save_manager and level_manager:
		improvements = save_manager.update_level_record(level_manager.level_id, summary)
		if level_select: level_select.update_ui(save_manager)

		# [DemoGate] Only submit to leaderboard when permitted.
		var _lb_ok: bool = (level_access_service == null or level_access_service.can_submit_leaderboard())
		if leaderboard_service and _lb_ok:
			rank = leaderboard_service.submit_score(level_manager.level_id, summary, save_manager.get_player_name())
		# [MetaLayer] Submit to online leaderboard (async, no crash if offline)
		if _lb_ok:
			_submit_online_score(summary)

		# If first time clear, check for next level unlock
		if improvements.get("first_time_clear", false):
			var next_id = save_manager.get_next_level_id(level_manager.level_id)
			if next_id != "":
				pending_unlock_level_id = next_id
				if OS.is_debug_build(): print("[Main] Pending unlock for: ", next_id)

	if game_hud:
		game_hud.show_run_summary(summary, improvements, rank)
		if OS.is_debug_build(): print("[ResultPanel] shown for ", current_level_id)

	_refresh_gameplay_hud_state()
	if audio_manager:
		audio_manager.play_sfx("victory")

# --- MetaLayer: Online Leaderboard ---

func _submit_online_score(summary: Dictionary) -> void:
	if online_lb_client == null or level_manager == null:
		return
	var payload = _build_online_payload(summary)
	online_lb_client.submit_score(payload)

func _build_online_payload(summary: Dictionary) -> Dictionary:
	var player_name = save_manager.get_player_name() if save_manager else "Player"
	var cleared = str(summary.get("result", "")) == "Victory"
	var wave = int(summary.get("waves_completed", game_manager.current_wave if game_manager else 0))
	var lives = int(summary.get("lives", game_manager.lives if game_manager else 0))
	var gold = int(summary.get("gold", game_manager.gold if game_manager else 0))
	var run_time = int(summary.get("clear_time", 0))
	var interest_count = 0
	if element_td_interest_service:
		interest_count = int(element_td_interest_service.upgrade_count)
	var elements: Dictionary = {}
	if element_progression_manager and element_progression_manager.has_method("get_element_levels"):
		elements = element_progression_manager.get_element_levels()
	return {
		"player_name": player_name,
		"level_id": current_level_id,
		"wave_reached": wave,
		"cleared": cleared,
		"lives_remaining": lives,
		"gold_remaining": gold,
		"interest_level": interest_count,
		"run_time_seconds": run_time,
		"elements": elements,
		"client_created_at": int(Time.get_unix_time_from_system())
	}

func _on_online_score_submitted(ok: bool, score: int, rank: int) -> void:
	if OS.is_debug_build():
		print("[MetaLayer] Online submit: ok=%s score=%d rank=%d" % [str(ok), score, rank])

# --- MetaLayer: Player Name, Save/Continue, Leaderboard from Menu ---

func _on_new_game_pressed() -> void:
	# Persist player name, then open level select so the player picks their level.
	# Run save is deleted when they actually confirm a level (in start_game).
	if save_manager and main_menu and main_menu.has_method("get_player_name"):
		save_manager.set_player_name(main_menu.get_player_name())
	_on_level_select_requested()

func _on_continue_requested() -> void:
	if save_game_service == null or not save_game_service.has_valid_save():
		return
	if save_manager and main_menu and main_menu.has_method("get_player_name"):
		save_manager.set_player_name(main_menu.get_player_name())
	_restore_run_from_save()

func _on_leaderboard_from_menu_requested() -> void:
	_on_leaderboard_requested("level_01")

func _restore_run_from_save() -> void:
	if save_game_service == null:
		return
	var data = save_game_service.load_run_state()
	if data.is_empty():
		push_warning("[MetaLayer] Continue: save data empty or corrupt.")
		return
	var level_id = str(data.get("level_id", "level_01"))
	var level_path = "res://data/levels/%s.json" % level_id
	if not FileAccess.file_exists(level_path):
		push_warning("[MetaLayer] Continue: level file not found: %s" % level_path)
		return

	# [DemoGate] Block save/resume that points to a locked level or wave beyond the demo cap.
	if level_access_service:
		var _save_level_num := level_id_to_int(level_id)
		var _save_wave := int(data.get("current_wave", 0))
		var _blocked := false
		if not level_access_service.can_play_level(_save_level_num):
			_blocked = true
		elif not level_access_service.can_play_wave(_save_level_num, _save_wave):
			_blocked = true
		if _blocked:
			push_warning("[DemoGate] Continue blocked: save requires full version (level=%d wave=%d)." % [_save_level_num, _save_wave])
			# Return to menu and show a message — do NOT delete the save.
			return_to_menu()
			if main_menu and main_menu.has_method("show_notification"):
				main_menu.show_notification("This save requires the Full Version.")
			elif game_hud:
				show_wave_feedback("This save requires the Full Version.", Color(1, 0.7, 0.2))
			return

	# Start the level fresh (resets managers), then overlay the saved state.
	start_level(level_path)
	_apply_saved_run_state(data)

func _apply_saved_run_state(data: Dictionary) -> void:
	# Restore economy state
	if game_manager:
		game_manager.gold = int(data.get("gold", game_manager.gold))
		game_manager.lives = int(data.get("lives", game_manager.lives))
		game_manager.current_wave = int(data.get("current_wave", 0))
		game_manager.waves_completed = int(data.get("current_wave", 0))
		game_manager.gold_changed.emit(game_manager.gold)
		game_manager.lives_changed.emit(game_manager.lives)
		game_manager.wave_changed.emit(game_manager.current_wave)

	# Advance wave index so next start_next_wave plays the correct wave
	if wave_manager and data.has("current_wave"):
		wave_manager.current_wave_index = int(data["current_wave"])

	# Restore element levels (direct assignment, avoids pending-pick requirement)
	if element_progression_manager and data.has("element_levels"):
		_restore_element_levels(
			data["element_levels"],
			int(data.get("element_pending_picks", 0))
		)

	# Restore interest upgrade count
	if element_td_interest_service and data.has("interest_upgrade_count"):
		element_td_interest_service.upgrade_count = int(data["interest_upgrade_count"])
		if element_td_interest_service.has_method("recalculate_rate"):
			element_td_interest_service.recalculate_rate()

	# Rebuild towers on the grid
	if build_manager and data.has("towers") and data["towers"] is Array:
		_restore_towers(data["towers"])

	_refresh_elemental_shop()
	update_hud()

	# If the player had an unresolved element pick when they left, re-open the panel.
	if element_progression_manager and element_progression_manager.has_pending_pick():
		_show_pending_element_choice()

	if OS.is_debug_build():
		var tower_count = (data["towers"] as Array).size() if data.has("towers") and data["towers"] is Array else 0
		print("[MetaLayer] Restored — wave=%d gold=%d lives=%d towers=%d" % [
			int(data.get("current_wave", 0)),
			int(data.get("gold", 0)),
			int(data.get("lives", 0)),
			tower_count
		])

func _restore_element_levels(saved_levels: Dictionary, saved_pending: int) -> void:
	if element_progression_manager == null:
		return
	element_progression_manager.reset(false)
	for elem_id in saved_levels:
		if element_progression_manager.element_levels.has(elem_id):
			element_progression_manager.element_levels[elem_id] = int(saved_levels[elem_id])
	element_progression_manager.pending_picks = saved_pending
	if element_progression_manager.has_signal("element_levels_changed"):
		element_progression_manager.element_levels_changed.emit(
			element_progression_manager.get_element_levels()
		)

func _restore_towers(towers_data: Array) -> void:
	if build_manager == null:
		return
	for tower_save in towers_data:
		if not (tower_save is Dictionary):
			continue
		var tower_id = str(tower_save.get("tower_id", ""))
		var cell = Vector2i(
			int(tower_save.get("cell_x", 0)),
			int(tower_save.get("cell_y", 0))
		)
		if tower_id.is_empty():
			continue
		if not build_manager.towers_config.has(tower_id):
			push_warning("[MetaLayer] Restore: unknown tower_id='%s', skipping." % tower_id)
			continue
		if build_manager.is_cell_occupied(cell):
			push_warning("[MetaLayer] Restore: cell %s occupied, skipping." % str(cell))
			continue
		var config = build_manager.towers_config[tower_id].duplicate(true)
		build_manager.place_tower(cell, config, false)

func _auto_save_run_state() -> void:
	if save_game_service == null or game_manager == null or level_manager == null:
		return

	# Collect tower state (skip transient/preview nodes)
	var towers_data: Array = []
	if tower_container:
		for tower in tower_container.get_children():
			if not is_instance_valid(tower):
				continue
			if not tower.is_in_group("placed_towers"):
				continue
			var tower_id_val = tower.get("tower_id") if "tower_id" in tower else ""
			var grid_cell_val = tower.get("grid_cell") if "grid_cell" in tower else Vector2i.ZERO
			if str(tower_id_val).is_empty():
				continue
			towers_data.append({
				"tower_id": str(tower_id_val),
				"cell_x": int(grid_cell_val.x),
				"cell_y": int(grid_cell_val.y)
			})

	# Collect element state
	var elem_levels: Dictionary = {}
	var elem_pending: int = 0
	if element_progression_manager:
		if element_progression_manager.has_method("get_element_levels"):
			elem_levels = element_progression_manager.get_element_levels()
		elem_pending = int(element_progression_manager.pending_picks)

	# Collect interest state
	var interest_count: int = 0
	if element_td_interest_service:
		interest_count = int(element_td_interest_service.upgrade_count)

	var run_time: int = 0
	if game_manager.session_start_time > 0:
		run_time = (Time.get_ticks_msec() - game_manager.session_start_time) / 1000

	var state := {
		"player_name": save_manager.get_player_name() if save_manager else "Player",
		"level_id": current_level_id,
		"current_wave": int(game_manager.current_wave),
		"lives": int(game_manager.lives),
		"gold": int(game_manager.gold),
		"interest_upgrade_count": interest_count,
		"element_levels": elem_levels,
		"element_pending_picks": elem_pending,
		"towers": towers_data,
		"run_time_seconds": run_time
	}

	save_game_service.save_run_state(state)

# --- Audio Handlers ---

func _on_audio_settings_changed(settings: Dictionary) -> void:
	if audio_manager:
		audio_manager.apply_settings(settings)
	if combat_audio_service:
		combat_audio_service.set_combat_mode(settings.get("audio_combat_mode", "balanced"))
	if save_manager:
		save_manager.update_audio_settings(settings)


func _on_reset_audio_requested() -> void:
	if audio_manager:
		audio_manager.reset_to_defaults()
		var default_settings: Dictionary = audio_manager.get_settings()
		default_settings["audio_combat_mode"] = "balanced"
		if combat_audio_service:
			combat_audio_service.set_combat_mode("balanced")
		if game_hud:
			game_hud.set_audio_settings_ui(default_settings)
		if save_manager:
			save_manager.update_audio_settings(default_settings)

func _on_display_settings_changed(settings: Dictionary) -> void:
	if display_mode_service:
		display_mode_service.apply_settings(settings)

func _on_display_mode_service_changed(settings: Dictionary) -> void:
	if game_hud and game_hud.has_method("set_display_settings_ui"):
		game_hud.set_display_settings_ui(settings)
	if save_manager:
		save_manager.update_display_settings(settings)

func _on_performance_settings_changed(settings: Dictionary) -> void:
	var performance_budget_service := get_node_or_null("/root/PerformanceBudgetService")
	var applied_settings := settings
	if performance_budget_service:
		performance_budget_service.apply_settings(settings)
		applied_settings = performance_budget_service.get_settings()
	if save_manager and save_manager.has_method("update_performance_settings"):
		save_manager.update_performance_settings(applied_settings)
	if game_hud and game_hud.has_method("set_performance_settings_ui"):
		game_hud.set_performance_settings_ui(applied_settings)

func _play_ui_click() -> void:
	if audio_manager:
		audio_manager.play_sfx("ui_click")

func _clean_effects_container() -> void:
	var container = get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: return
	
	var children = container.get_children()
	if children.size() > 60: # Limit active visual effects
		# Kill the oldest ones first
		for i in range(children.size() - 60):
			var child = children[i]
			if child.has_method("queue_free"):
				child.queue_free()

# --- Debug Actions ---

func _debug_kill_all_enemies() -> void:
	if OS.is_debug_build(): print("[Debug] Killing all enemies...")
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(999999)

func _debug_clear_projectiles() -> void:
	if OS.is_debug_build(): print("[Debug] Clearing projectiles...")
	if projectile_container:
		for proj in projectile_container.get_children():
			proj.queue_free()

func _on_debug_god_mode_toggled(enabled: bool) -> void:
	if game_manager:
		game_manager.debug_god_mode = enabled
		if OS.is_debug_build(): print("[Debug] God Mode: ", "ON" if enabled else "OFF")
		if game_hud:
			if enabled:
				game_hud.set_status("God Mode ON")
			else:
				game_hud.set_status("Ready")

func _on_debug_button_pressed() -> void:
	if OS.is_debug_build(): print("[DebugButton] pressed web=", OS.has_feature("web"))
	_toggle_debug_panel()

func _can_show_debug_panel() -> bool:
	return debug_panel_enabled or OS.is_debug_build()

func _toggle_debug_panel() -> void:
	if debug_panel == null:
		if OS.is_debug_build(): print("[Debug] panel null")
		return

	if not _can_show_debug_panel():
		if OS.is_debug_build(): print("[Debug] blocked by debug flag")
		return

	if debug_panel.has_method("toggle_panel"):
		debug_panel.toggle_panel()
	else:
		debug_panel.visible = not debug_panel.visible

	debug_panel.layer = 500

	if debug_button:
		debug_button.text = "DEBUG ON" if debug_panel.visible else "DEBUG"

	# Ensure God Mode checkbox is synced if it exists
	if debug_panel.visible and game_manager and debug_panel.has_node("Root/Panel/MarginContainer/Scroll/Content/GodModeCheck"):
		var check = debug_panel.get_node("Root/Panel/MarginContainer/Scroll/Content/GodModeCheck")
		check.button_pressed = game_manager.debug_god_mode

	if OS.is_debug_build(): print("[Debug] toggled. visible=", debug_panel.visible, " layer=", debug_panel.layer)

func _show_audio_unlock_overlay() -> void:
	var overlay_scene = load("res://scenes/ui/AudioUnlockOverlay.tscn")
	if overlay_scene:
		var overlay = overlay_scene.instantiate()
		add_child(overlay)
		if OS.is_debug_build(): print("[Main] Audio unlock overlay shown for Web.")

# Wave Data Processing Helpers
func _toggle_sandbox_panel() -> void:
	_ensure_sandbox_panel()
	if sandbox_layer:
		sandbox_layer.visible = not sandbox_layer.visible
		if game_hud:
			game_hud.set_build_status("Sandbox Lab " + ("ON" if sandbox_layer.visible else "OFF"))

func _ensure_sandbox_panel() -> void:
	if sandbox_layer != null and is_instance_valid(sandbox_layer):
		return
	sandbox_layer = CanvasLayer.new()
	sandbox_layer.name = "SandboxLabLayer"
	sandbox_layer.layer = 450
	sandbox_layer.visible = false
	add_child(sandbox_layer)
	sandbox_panel = PanelContainer.new()
	sandbox_panel.name = "SandboxLabPanel"
	sandbox_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sandbox_panel.offset_left = -260
	sandbox_panel.offset_top = 72
	sandbox_panel.offset_right = -16
	sandbox_panel.offset_bottom = 430
	sandbox_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sandbox_layer.add_child(sandbox_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	sandbox_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title := Label.new()
	title.text = "SANDBOX LAB  F9+D"
	title.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	box.add_child(title)
	_add_sandbox_button(box, "Spawn Land", func(): _sandbox_spawn("basic", "land"))
	_add_sandbox_button(box, "Spawn Air", func(): _sandbox_spawn("flyer", "air"))
	_add_sandbox_button(box, "Spawn Land + Air", func():
		_sandbox_spawn("basic", "land")
		_sandbox_spawn("flyer", "air")
	)
	_add_sandbox_separator(box, "Elements")
	for element_id in ["light", "darkness", "water", "fire", "nature", "earth"]:
		var eid := str(element_id)
		_add_sandbox_button(box, "+1 " + eid.capitalize(), Callable(self , "_sandbox_add_element").bind(eid, 1))
	_add_sandbox_button(box, "All +1", func():
		for eid in ["light", "darkness", "water", "fire", "nature", "earth"]:
			_sandbox_add_element(eid, 1)
	)
	_add_sandbox_button(box, "All Lv3", func(): _sandbox_set_all_elements(3))
	_add_sandbox_separator(box, "Utility")
	_add_sandbox_button(box, "+500 Gold", func():
		if game_manager:
			game_manager.add_gold(500)
			update_hud()
	)
	_add_sandbox_button(box, "Kill All", func(): _debug_kill_all_enemies())

func _add_sandbox_button(parent: Node, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(210, 30)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _add_sandbox_separator(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	parent.add_child(label)

func _sandbox_spawn(enemy_type: String, category: String) -> void:
	if wave_manager == null:
		return
	if wave_manager.has_method("spawn_sandbox_enemy"):
		wave_manager.spawn_sandbox_enemy(enemy_type, category)
	elif wave_manager.has_method("spawn_enemy"):
		wave_manager.spawn_enemy({"type": enemy_type, "enemy_type": enemy_type, "category": category, "path": "default", "debug_probe": true})

func _sandbox_add_element(element_id: String, amount: int = 1) -> void:
	if element_progression_manager == null:
		return
	for i in range(amount):
		element_progression_manager.grant_pick(1)
		element_progression_manager.choose_element(element_id)
	if game_hud:
		game_hud.hide_element_choice(true)
	_refresh_elemental_shop()
	_refresh_start_wave_ui()

func _sandbox_set_all_elements(target_level: int) -> void:
	if element_progression_manager == null:
		return
	var levels: Dictionary = element_progression_manager.get_element_levels()
	for eid in ["light", "darkness", "water", "fire", "nature", "earth"]:
		while int(levels.get(eid, 0)) < target_level:
			element_progression_manager.grant_pick(1)
			element_progression_manager.choose_element(eid)
			levels = element_progression_manager.get_element_levels()
	if game_hud:
		game_hud.hide_element_choice(true)
	_refresh_elemental_shop()
	_refresh_start_wave_ui()


func load_waves_config(path: String) -> Array:
	if path == "" or not FileAccess.file_exists(path): return []
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(json_text)
	return json if json is Array else []

func level_id_to_int(level_id_value) -> int:
	return WAVE_PREVIEW_HELPER_SCRIPT.level_id_to_int(level_id_value)

func format_level_id(level_id: int) -> String:
	return WAVE_PREVIEW_HELPER_SCRIPT.format_level_id(level_id)

func normalize_enemy_type(raw: String) -> String:
	return WAVE_PREVIEW_HELPER_SCRIPT.normalize_enemy_type(raw)

func normalize_enemy_category(raw_category) -> String:
	return WAVE_PREVIEW_HELPER_SCRIPT.normalize_enemy_category(raw_category)

func get_enemy_type_config(enemy_type: String) -> Dictionary:
	var path = "res://data/enemies.json"
	if wave_manager and wave_manager.enemies_config.has(enemy_type):
		var from_manager = wave_manager.enemies_config.get(enemy_type, {})
		return from_manager if from_manager is Dictionary else {}
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(json_text)
	if not (json is Dictionary):
		return {}
	var config = json.get(enemy_type, {})
	return config if config is Dictionary else {}

func resolve_preview_enemy_category(group: Dictionary, enemy_type: String) -> String:
	if group.has("category"):
		return normalize_enemy_category(group["category"])
	var enemy_config = get_enemy_type_config(enemy_type)
	if enemy_config.has("category"):
		return normalize_enemy_category(enemy_config["category"])
	return ENEMY_CATEGORY_LAND

func format_preview_enemy_label(normalized_type: String, enemy_category: String) -> String:
	return WAVE_PREVIEW_HELPER_SCRIPT.format_preview_enemy_label(normalized_type, enemy_category)

func derive_wave_traits(enemy_counts: Dictionary, total_count: int, categories: Dictionary = {}) -> Array[String]:
	return WAVE_PREVIEW_HELPER_SCRIPT.derive_wave_traits(enemy_counts, total_count, categories)

func recommend_roles_for_wave(traits: Array[String]) -> Array[String]:
	return WAVE_PREVIEW_HELPER_SCRIPT.recommend_roles_for_wave(traits)


func _get_preview_wave_groups(wave_data: Dictionary) -> Array:
	return WAVE_PREVIEW_HELPER_SCRIPT.get_preview_wave_groups(wave_data)

func summarize_wave_for_preview(wave) -> Dictionary:
	if not (wave is Dictionary):
		return {}

	var wave_data: Dictionary = wave
	var counts = {}
	var categories = {}
	var total = 0
	var lane_info = {} # path_id -> { "counts": {}, "total": 0 }

	var groups = _get_preview_wave_groups(wave_data)
	for group in groups:
		if not (group is Dictionary):
			continue

		var raw_type = group.get("enemy_type", group.get("type", group.get("enemy", "")))
		var count = int(group.get("count", 0))
		var path_id = group.get("path", "default")
		
		if str(raw_type) == "" or count <= 0:
			continue

		var enemy_type = str(raw_type)
		var norm_type = normalize_enemy_type(enemy_type)
		var enemy_category = resolve_preview_enemy_category(group, enemy_type)
		var display_type = format_preview_enemy_label(norm_type, enemy_category)

		counts[display_type] = counts.get(display_type, 0) + count
		categories[enemy_category] = true
		total += count
		
		# Lane specific tracking
		if not lane_info.has(path_id):
			lane_info[path_id] = {"counts": {}, "total": 0}
		lane_info[path_id]["counts"][display_type] = lane_info[path_id]["counts"].get(display_type, 0) + count
		lane_info[path_id]["total"] += count

	if counts.is_empty():
		return {}

	var traits = derive_wave_traits(counts, total, categories)
	var rec_roles = recommend_roles_for_wave(traits)
	var warnings = derive_wave_warnings(traits)
	FrameSpikeLogger.begin("spawn_formation_plan")
	var formation_preview = _summarize_wave_formations_for_preview(wave_data)
	FrameSpikeLogger.end("spawn_formation_plan")
	
	if wave_data.has("intel") and wave_data["intel"] != "":
		warnings.append(wave_data["intel"])
	
	if lane_info.keys().size() > 1:
		warnings.append("Dual-Lane Pressure: Enemies arriving from multiple routes.")
		if current_level_id == "level_12":
			warnings.append("Note: A = Upper Route | B = Lower Route")

	# Design Validation (Internal Logs)
	_validate_wave_design(wave_data, traits, total)

	return {
		"name": wave_data.get("name", "Unknown Wave"),
		"reward": wave_data.get("reward", 0),
		"enemy_counts": counts,
		"total_count": total,
		"traits": traits,
		"recommended_roles": rec_roles,
		"warnings": warnings,
		"lane_info": lane_info,
		"formations": formation_preview.get("formations", []),
		"formation_notes": formation_preview.get("notes", [])
	}

func _summarize_wave_formations_for_preview(wave_data: Dictionary) -> Dictionary:
	var plan := {}
	if wave_manager and wave_manager.formation_planner:
		plan = wave_manager.formation_planner.build_plan(wave_data)
	else:
		var planner = SPAWN_FORMATION_PLANNER_SCRIPT.new(_load_enemy_config_for_preview())
		plan = planner.build_plan(wave_data)
	var formations := []
	var notes := []
	for item in plan.get("formation_preview", []):
		var path := str(item.get("path", "default"))
		var formation := str(item.get("formation", ""))
		var note := str(item.get("note", ""))
		var lane_name := "Lane A" if path == "default" else path.capitalize()
		if formation != "":
			formations.append("%s: %s" % [lane_name, formation])
		if note != "" and not notes.has(note):
			notes.append(note)
	return {"formations": formations, "notes": notes}

func _load_enemy_config_for_preview() -> Dictionary:
	if wave_manager and wave_manager.get("enemies_config") is Dictionary:
		var live_config: Dictionary = wave_manager.get("enemies_config")
		if not live_config.is_empty():
			return live_config
	var path = "res://data/enemies.json"
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	return json.data if error == OK and json.data is Dictionary else {}

func derive_wave_warnings(traits: Array[String]) -> Array[String]:
	return WAVE_PREVIEW_HELPER_SCRIPT.derive_wave_warnings(traits)

func _validate_wave_design(_wave_data: Dictionary, _traits: Array[String], _total_count: int) -> void:
	if not OS.is_debug_build(): return
	
func _get_wave_source_for_preview(level_id: int) -> Array:
	if level_id <= 0:
		return []

	var requested_level_id = format_level_id(level_id)
	if level_manager and level_manager.level_id == requested_level_id and wave_manager and wave_manager.waves_data_path == level_manager.waves_path and not wave_manager.waves.is_empty():
		return wave_manager.waves

	var level_config = get_level_config(requested_level_id)
	if level_config.is_empty():
		return []

	var waves_path = str(level_config.get("waves_path", ""))
	return load_waves_config(waves_path)

func get_wave_preview_data(level_id: int) -> Array[Dictionary]:
	if _wave_preview_cache.has(level_id):
		wave_preview_cache_hits += 1
		return _wave_preview_cache[level_id]
	wave_preview_cache_misses += 1
	FrameSpikeLogger.begin("wave_preview_build_lv%d" % level_id)
	var waves_data = _get_wave_source_for_preview(level_id)
	var result: Array[Dictionary] = []
	for wave in waves_data:
		var preview = summarize_wave_for_preview(wave)
		if not preview.is_empty():
			result.append(preview)
	_wave_preview_cache[level_id] = result
	FrameSpikeLogger.end("wave_preview_build_lv%d" % level_id)
	return result

func _invalidate_wave_preview_cache(level_id: int = -1) -> void:
	if level_id < 0:
		_wave_preview_cache.clear()
	else:
		_wave_preview_cache.erase(level_id)
	_wave_intel_dirty = true

func get_perf_debug_counters() -> Dictionary:
	return {
		"wave_preview_cache_hits": wave_preview_cache_hits,
		"wave_preview_cache_misses": wave_preview_cache_misses,
		"tower_preview_active_count": TowerCatalogPreview._s_active_count,
		"tower_preview_redraw_count": TowerCatalogPreview._s_redraw_count,
		"element_icon_cache_hits": ElementIcon.element_icon_cache_hits,
		"element_icon_cache_misses": ElementIcon.element_icon_cache_misses,
	}

func get_wave_preview_for_index(level_id: int, wave_index: int) -> Dictionary:
	if wave_index < 0:
		return {}
	var previews = get_wave_preview_data(level_id)
	if wave_index >= previews.size():
		return {}
	return previews[wave_index]

func format_wave_enemy_summary(summary: Dictionary) -> String:
	return WAVE_PREVIEW_HELPER_SCRIPT.format_wave_enemy_summary(summary)

func _refresh_hud_wave_intel() -> void:
	if not game_hud or not wave_manager: return

	if current_state != GameState.BUILD and current_state != GameState.WAVE:
		if _last_wi_level_id >= 0:
			game_hud.clear_wave_intel()
			_last_wi_level_id = -1
		return

	if selected_level_id <= 0:
		if _last_wi_level_id >= 0:
			game_hud.clear_wave_intel()
			_last_wi_level_id = -1
		return

	var cur_wave_idx: int = wave_manager.current_wave_index
	var cur_running: bool = wave_manager.is_wave_running
	if not _wave_intel_dirty and _last_wi_level_id == selected_level_id and _last_wi_wave_index == cur_wave_idx and _last_wi_running == cur_running:
		return
	_wave_intel_dirty = false
	_last_wi_level_id = selected_level_id
	_last_wi_wave_index = cur_wave_idx
	_last_wi_running = cur_running

	FrameSpikeLogger.begin("wave_intel_refresh")
	var previews = get_wave_preview_data(selected_level_id)

	if OS.is_debug_build():
		var idx = wave_manager.current_wave_index
		if wave_manager.is_wave_running: idx -= 1
		if idx >= 0 and idx < previews.size():
			var p = previews[idx]
			print("[WaveIntel] level=%d wave=%d composition=%s" % [selected_level_id, idx + 1, format_wave_enemy_summary(p)])
			print("[WaveIntel] threats=%s" % str(p.get("traits", [])))
			print("[WaveIntel] suggested_towers=%s" % str(p.get("recommended_roles", [])))

	game_hud.refresh_wave_intel(
		selected_level_id,
		previews,
		wave_manager.current_wave_index,
		wave_manager.get_total_waves(),
		wave_manager.is_wave_running
	)
	FrameSpikeLogger.end("wave_intel_refresh")

func _refresh_route_preview() -> void:
	# MazeMapRenderer guideline handles route visualization
	if maze_map_renderer:
		return

	if not map_visual_layer or not wave_manager or not level_manager:
		return
	
	if current_state != GameState.BUILD or wave_manager.is_wave_running or not wave_manager.has_next_wave():
		_clear_route_preview()
		return
	
	map_visual_layer.set_preview_paths(_get_upcoming_wave_active_paths())

func _clear_route_preview() -> void:
	if map_visual_layer and map_visual_layer.has_method("set_preview_paths"):
		map_visual_layer.set_preview_paths([])

func _get_upcoming_wave_active_paths() -> Array[String]:
	var active_paths: Array[String] = []
	if not wave_manager or not level_manager:
		return active_paths
	
	var wave_data = wave_manager.get_current_wave_data()
	if wave_data.is_empty():
		return active_paths
	
	var groups = _extract_wave_groups_for_route_preview(wave_data)
	for group in groups:
		if not (group is Dictionary):
			continue
		
		var path_id = str(group.get("path", "default"))
		if level_manager.multi_paths.has(path_id) and not active_paths.has(path_id):
			active_paths.append(path_id)
	
	return active_paths

func _extract_wave_groups_for_route_preview(wave_data: Dictionary) -> Array:
	if wave_data.has("groups") and wave_data["groups"] is Array:
		return wave_data["groups"]
	if wave_data.has("spawns") and wave_data["spawns"] is Array:
		return wave_data["spawns"]
	if wave_data.has("enemies") and wave_data["enemies"] is Array:
		return wave_data["enemies"]
	if wave_data.has("enemy_type") or wave_data.has("type"):
		return [wave_data]
	return []

func _log_wave_intel_source() -> void:
	if not OS.is_debug_build(): return
	var previews = get_wave_preview_data(selected_level_id)
	var level_name = level_manager.level_name if level_manager else "Unknown"
	print("[WaveIntel] selected_level_id=", selected_level_id, " level=", level_name, " total_waves=", previews.size())
	if previews.size() > 0:
		print("[WaveIntel] wave 1 preview extracted=", format_wave_enemy_summary(previews[0]))
	if previews.size() > 1:
		print("[WaveIntel] wave 2 preview extracted=", format_wave_enemy_summary(previews[1]))

func get_level_config(id: String) -> Dictionary:
	var path = "res://data/levels/" + id + ".json"
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(json_text)
	return json if json is Dictionary else {}

# --- Debug Tooling & Verification ---

func is_debug_auto_play_allowed() -> bool:
	return enable_debug_tools or OS.is_debug_build()

func ensure_debug_input_actions() -> void:
	_ensure_key_action("debug_auto_verify_current", KEY_F9)
	_ensure_key_action("debug_auto_verify_all", KEY_F10)

func _ensure_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var bound := false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			bound = true
			break

	if not bound:
		var ev = InputEventKey.new()
		ev.keycode = keycode
		InputMap.action_add_event(action_name, ev)


func debug_start_auto_verify_current_level() -> void:
	print("[AUTO_SOLVER] SOLVE CURRENT (F9)")
	if not is_debug_auto_play_allowed(): return

	var level_int = level_id_to_int(current_level_id)
	if level_int <= 0: level_int = 7

	_solve_and_play(level_int)

func debug_start_auto_verify_all_known_plans() -> void:
	print("[AUTO_SOLVER] SOLVE ALL (F10)")
	if not is_debug_auto_play_allowed(): return

	var results = []
	for i in range(1, 11):
		var level_id = "level_%02d" % i
		var res = balance_solver.solve_level_with_gold_testing(level_id)
		res["id"] = str(i)
		results.append(res)

	balance_solver.generate_consolidated_report(results)
	print("[AUTO_SOLVER] Batch report generated.")
	if debug_panel: debug_panel.update_verifier_status("Report Generated (All)", false)

func debug_verify_current_board() -> void:
	print("[AUTO_SOLVER] VERIFY CURRENT BOARD (F9) - SIMULATION ONLY")
	if not is_debug_auto_play_allowed(): return
	if not balance_solver: return

	var towers = collect_existing_towers_for_solver()

	if towers.is_empty():
		print("[AUTO_SOLVER] No existing towers found on board")
		if debug_panel: debug_panel.update_verifier_status("No towers found", true)
		return

	var start_wave_index := get_solver_next_wave_index()
	if start_wave_index < 0:
		print("[AUTO_SOLVER] No remaining waves to simulate or level cleared.")
		if debug_panel: debug_panel.update_verifier_status("Level Cleared")
		return

	print("[AUTO_SOLVER] Found %d tower nodes" % towers.size())
	for t in towers:
		var sim_pos = Vector2(t["cell"].x, t["cell"].y) * 64.0 + Vector2(32, 32)
		print("[AUTO_SOLVER] Sim tower %s cell=%s sim_pos=%s" % [t["type"], t["cell"], sim_pos])

	var level_int = level_id_to_int(current_level_id)
	if level_int <= 0: level_int = 7
	var level_id = "level_%02d" % level_int

	if debug_panel: debug_panel.update_verifier_status("Simulating board...")

	var state = balance_solver.create_state_manual(
		game_manager.gold if game_manager else 0,
		game_manager.lives if game_manager else 20,
		start_wave_index,
		towers
	)

	print("[AUTO_SOLVER] Starting simulation from Wave %d (index %d)" % [state.wave_index + 1, state.wave_index])

	var res = balance_solver.solve_from_state(state, level_id)
	if res["status"] == "PASS":
		print("[AUTO_SOLVER] Current board PASSES simulation.")
		if debug_panel: debug_panel.update_verifier_status("Sim OK (Wave %d)" % res["wave"])
	else:
		print("[AUTO_SOLVER] FAIL at Wave %d" % res["wave"])
		print("[AUTO_SOLVER] Reason: ", res["reason"])

		# For current board, use a clearer report format
		print("[AUTO_SOLVER] Current board result:")
		print(" - failed wave: Wave %d" % res["wave"])
		if res.has("best_fail"):
			var bf = res["best_fail"]
			print(" - enemies killed: ", bf.get("enemies_killed", 0))
			print(" - leak time: ", bf.get("leak_time", 0.0), "s")
			print(" - leak enemy: ", bf.get("leak_enemy", "unknown"))

		if debug_panel: debug_panel.update_verifier_status("Sim FAIL: Wave %d" % res["wave"], true)

func get_solver_next_wave_index() -> int:
	if not wave_manager: return -1
	var total: int = wave_manager.get_total_waves()
	if total <= 0: return -1

	# If wave is running, verify the current active wave
	# If wave is NOT running, verify the next wave to be started
	var idx: int = wave_manager.current_wave_index
	if wave_manager.is_wave_running:
		idx -= 1

	idx = clamp(idx, 0, total - 1)

	# If we are already past all waves, return -1
	if not wave_manager.is_wave_running and wave_manager.current_wave_index >= total:
		return -1

	return idx

func debug_auto_play_current_board() -> void:
	print("[AUTO_VERIFY] AUTO PLAY CURRENT BOARD started")
	if not is_debug_auto_play_allowed(): return
	if not auto_play_verifier: return

	var existing_towers := collect_existing_towers_for_solver()

	if existing_towers.is_empty():
		print("[AUTO_VERIFY] Cannot auto-play: no towers found")
		if debug_panel: debug_panel.update_verifier_status("No towers found", true)
		return

	# Configure verifier for real gameplay from current state
	auto_play_verifier.is_active = true
	auto_play_verifier.current_wave = wave_manager.current_wave_index if wave_manager else 1
	auto_play_verifier.starting_lives = game_manager.lives if game_manager else 20
	auto_play_verifier.state = 12 # WAITING_WAVE_COMPLETE

	# If wave is not running, start it
	if wave_manager and not wave_manager.is_wave_running:
		print("[AUTO_VERIFY] Triggering Wave %d start" % auto_play_verifier.current_wave)
		wave_manager.start_next_wave()

	if debug_panel: debug_panel.update_verifier_status("Auto-Playing Wave %d" % auto_play_verifier.current_wave)

func collect_existing_towers_for_solver() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tower_nodes: Array = []

	# Preferred: group lookup
	tower_nodes.append_array(get_tree().get_nodes_in_group("placed_towers"))

	# Fallback: known towers container
	var container = get_node_or_null("WorldRoot/MapRoot/TowerContainer")
	if tower_nodes.is_empty() and container:
		for child in container.get_children():
			tower_nodes.append(child)

	if tower_nodes.is_empty():
		return result

	print("[AUTO_SOLVER] Found %d tower nodes" % tower_nodes.size())

	for tower in tower_nodes:
		if not is_instance_valid(tower): continue

		# Skip previews if any (by convention or meta)
		if tower.has_meta("is_build_preview") and tower.get_meta("is_build_preview") == true:
			continue

		var type := _solver_get_tower_type(tower)
		var cell := _solver_get_tower_cell(tower)
		var lvl := _solver_get_tower_level(tower)

		if type == "":
			print("[AUTO_SOLVER] Skipping tower node without identifiable type: ", tower.name)
			continue

		result.append({"type": type, "cell": cell, "level": lvl})

	return result

func _solver_get_tower_type(tower: Node) -> String:
	if tower.has_method("get_tower_id"): return tower.get_tower_id()
	if "tower_id" in tower: return tower.tower_id
	if tower.has_meta("tower_type"): return str(tower.get_meta("tower_type"))
	if tower.has_meta("tower_id"): return str(tower.get_meta("tower_id"))
	return ""

func _solver_get_tower_cell(tower: Node) -> Vector2i:
	if tower.has_method("get_grid_cell"): return tower.get_grid_cell()
	if "grid_cell" in tower: return tower.grid_cell
	if tower.has_meta("grid_cell"): return tower.get_meta("grid_cell")

	# Fallback: derive from position
	if build_manager and map_root:
		return build_manager.local_to_cell(map_root.to_local(tower.global_position))
	return Vector2i.ZERO

func _solver_get_tower_level(tower: Node) -> int:
	if tower.has_method("get_tower_level"): return tower.get_tower_level()
	if "tower_level" in tower: return tower.tower_level
	if "level_index" in tower: return tower.level_index + 1
	if "level" in tower: return tower.level
	if tower.has_meta("tower_level"): return int(tower.get_meta("tower_level"))
	if tower.has_meta("level"): return int(tower.get_meta("level"))
	return 1

func _solve_and_play(level_int: int) -> void:
	var level_id = "level_%02d" % level_int
	if not balance_solver: return

	if debug_panel: debug_panel.update_verifier_status("Solving L%d..." % level_int)

	var res = balance_solver.solve_level_with_gold_testing(level_id)
	if res["status"] == "PASS":
		print("[AUTO_SOLVER] PASS found at gold: ", res["starting_gold"])
		if debug_panel: debug_panel.update_verifier_status("Plan Found L%d" % level_int)
		start_auto_play_verification(res["plan"])
	else:
		print("[AUTO_SOLVER] FAIL at Wave %d" % res["wave"])
		print("[AUTO_SOLVER] Reason: ", res["reason"])
		if res.has("best_fail"):
			var bf = res["best_fail"]
			print("[AUTO_SOLVER] Best candidate details:")
			print(" - survived until wave: ", bf["wave"])
			print(" - enemies killed: ", bf.get("enemies_killed", 0))
			print(" - leak time: ", bf.get("leak_time", 0.0), "s")
			print(" - leak enemy: ", bf.get("leak_enemy", "unknown"))
		print("[AUTO_SOLVER] Total candidates tested: ", res.get("total_candidates_tested", 0))
		if debug_panel: debug_panel.update_verifier_status("FAIL L%d: Wave %d" % [level_int, res["wave"]], true)

func get_auto_verify_plan_for_level(_level_id: int) -> Dictionary:
	# Now returns empty because we search for plans instead
	return {}

func get_level_7_auto_verify_plan() -> Dictionary:
	# Placeholder for UI compatibility if needed, but we prefer _solve_and_play(7)
	return {}

func start_auto_play_verification(plan: Dictionary) -> void:
	if not auto_play_verifier: return
	print("[AUTO_VERIFY] Executing plan for level %s" % str(plan.get("level_id")))
	auto_play_verifier.start_verification(plan)

func _on_verifier_state_changed(state: int, msg: String) -> void:
	var state_completed = 8 # AutoPlayState.COMPLETED
	var state_failed = 9 # AutoPlayState.FAILED
	
	if debug_panel:
		var is_fail = (state == state_failed)
		debug_panel.update_verifier_status(msg, is_fail)
	
	if state == state_completed and balance_solver and not last_auto_clear_result.is_empty():
		auto_clear_state = AutoClearState.AUTOPLAY_SUCCESS
		auto_clear_active = false
		
		# Capture verifier findings
		if auto_play_verifier:
			var setup_gold = auto_play_verifier.auto_clear_verified_initial_setup_gold
			var setup_actions = auto_play_verifier.auto_clear_initial_setup_actions
			var test_gold = auto_play_verifier.auto_clear_current_test_gold
			
			last_auto_clear_result["success"] = true
			last_auto_clear_result["perfect_clear"] = (game_manager.lives == game_manager.starting_lives) if game_manager else true
			last_auto_clear_result["verified_setup_gold"] = setup_gold
			last_auto_clear_result["verified_setup_actions"] = setup_actions
			last_auto_clear_result["debug_gold_tested"] = test_gold
			
			if last_auto_clear_result.has("plan") and last_auto_clear_result["plan"] is Dictionary:
				last_auto_clear_result["plan"]["verified_setup_gold"] = setup_gold
				last_auto_clear_result["plan"]["verified_setup_actions"] = setup_actions
		
		balance_solver.generate_auto_clear_report(last_auto_clear_result, "AUTO_PLAY_VERIFIED")
		_update_auto_clear_panel({
			"state": "Verified Perfect Clear",
			"level": str(last_auto_clear_result.get("level_id", current_level_id)),
			"gold": str(last_auto_clear_result.get("starting_gold", "-")),
			"best": "All waves, 0 leaks",
			"result": str(last_auto_clear_result.get("result_state", "FOUND")),
			"recommended_gold": int(last_auto_clear_result.get("verified_setup_gold", 0)),
			"lives": "%d / %d" % [game_manager.lives, game_manager.starting_lives] if game_manager else "-"
		})
	elif state == state_failed and balance_solver and not last_auto_clear_result.is_empty():
		auto_clear_state = AutoClearState.AUTOPLAY_FAILED
		balance_solver.generate_auto_clear_report(last_auto_clear_result, "SIMULATED_ONLY")
		if auto_clear_active:
			_retry_auto_clear_after_real_failure(msg)

func _start_debug_auto_play() -> void:
	debug_start_auto_verify_current_level()

var last_solved_plan: Dictionary = {}
var last_found_plan: Dictionary = {}
var last_auto_clear_result: Dictionary = {}
var auto_clear_state: AutoClearState = AutoClearState.IDLE
var auto_clear_active: bool = false
var auto_clear_level_id: int = 0
var auto_clear_real_attempts: int = 0
var max_real_autoplay_attempts_per_gold: int = 3

func set_debug_starting_gold_override(gold: int) -> void:
	if not is_debug_auto_play_allowed(): return
	debug_starting_gold_override = gold

func _apply_verified_starting_gold() -> void:
	print("[BALANCE] Apply Initial Setup Gold clicked")
	
	if last_auto_clear_result.is_empty():
		push_warning("[BALANCE] No verified result available to apply.")
		return
	
	if not last_auto_clear_result.get("success", false):
		push_warning("[BALANCE] Last Auto Clear run did not succeed. Result: %s" % str(last_auto_clear_result))
		return
		
	var setup_gold = int(last_auto_clear_result.get("verified_setup_gold", -1))
	if setup_gold <= 0:
		push_warning("[BALANCE] No valid initial setup gold recorded in result dictionary: %s" % str(last_auto_clear_result))
		return
		
	var level_id = str(last_auto_clear_result.get("level_id", current_level_id))
	var level_path = _get_level_config_path(level_id)
	
	print("[BALANCE] Applying verified initial setup gold=%d to level=%s" % [setup_gold, level_id])
	print("[BALANCE] Config path: %s" % level_path)
	
	if level_manager and level_manager.level_id == level_id:
		print("[BALANCE] Live update level_manager: %d -> %d" % [level_manager.starting_gold, setup_gold])
		level_manager.starting_gold = setup_gold
		
	_update_level_starting_gold_json(level_path, setup_gold)

func _get_level_config_path(level_id) -> String:
	var id_str = str(level_id)
	if id_str.begins_with("level_"):
		if id_str.ends_with(".json"): return id_str
		return "res://data/levels/%s.json" % id_str
	
	var n = int(id_str)
	if n > 0:
		return "res://data/levels/level_%02d.json" % n
		
	return "res://data/levels/%s.json" % id_str

func _update_level_starting_gold_json(path: String, new_gold: int) -> void:
	if not FileAccess.file_exists(path):
		print("[BALANCE] Level file not found for persistence: ", path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) == OK:
		var data = json.data
		if data is Dictionary:
			data["starting_gold"] = new_gold
			var out_file = FileAccess.open(path, FileAccess.WRITE)
			out_file.store_string(JSON.stringify(data, "\t"))
			out_file.close()
			print("[BALANCE] Updated level JSON: ", path)

func debug_auto_clear_current_level() -> void:
	if current_level_id == "":
		if current_level_path != "":
			current_level_id = current_level_path.get_file().get_basename()
		else:
			current_level_id = "level_07"
	debug_auto_clear_level(level_id_to_int(current_level_id))

func debug_auto_clear_level(level_id: int) -> void:
	if not is_debug_auto_play_allowed(): return
	var normalized_id: String = "level_%02d" % level_id
	auto_clear_active = true
	auto_clear_level_id = level_id
	auto_clear_real_attempts = 0
	auto_clear_state = AutoClearState.SOLVING
	print("[AUTO_CLEAR] One-click auto clear started for ", normalized_id)
	if level_manager:
		print("[AUTO_CLEAR] Solving Level %d %s" % [level_id, level_manager.level_name])
	_update_auto_clear_panel({
		"state": "Solving",
		"level": normalized_id,
		"gold": "testing",
		"candidate": "-",
		"best": "-",
		"result": "-"
	})

	if not balance_solver:
		_update_auto_clear_panel({"state": "Failed", "level": normalized_id, "result": "No solver", "is_error": true})
		return

	var res: Dictionary = balance_solver.solve_level_with_gold_testing(normalized_id)
	_handle_auto_clear_solve_result(level_id, res)

func _handle_auto_clear_solve_result(level_id: int, res: Dictionary) -> void:
	var normalized_id: String = "level_%02d" % level_id
	res["level_id"] = normalized_id
	last_auto_clear_result = res

	if res.get("status", "") == "PASS":
		last_found_plan = res["plan"]
		last_solved_plan = last_found_plan
		if not is_plan_valid_for_autoplay(last_found_plan):
			print("[AUTO_CLEAR] No valid plan found")
			_update_auto_clear_panel({
				"state": "No Plan Found",
				"level": normalized_id,
				"result": "Invalid solver plan rejected",
				"is_error": true
			})
			auto_clear_state = AutoClearState.NO_PLAN_FOUND
			auto_clear_active = false
			return
		var result_state: String = str(res.get("result_state", "FOUND_AT_CURRENT_GOLD"))
		var working_gold: int = int(res.get("starting_gold", res.get("original_gold", 0)))
		auto_clear_state = AutoClearState.PLAN_FOUND
		_update_auto_clear_panel({
			"state": "Plan Found",
			"level": "%s / %s" % [normalized_id, str(last_found_plan.get("name", ""))],
			"gold": working_gold,
			"candidate": str(res.get("total_candidates_tested", "-")),
			"best": "All waves, 0 leaks",
			"result": result_state,
			"recommended_gold": working_gold
		})
		balance_solver.generate_auto_clear_report(res, "SIMULATED_ONLY")
		auto_play_plan(last_found_plan)
	else:
		print("[AUTO_CLEAR] No valid plan found")
		var fail_wave: int = int(res.get("wave", 0))
		auto_clear_state = AutoClearState.NO_PLAN_FOUND
		auto_clear_active = false
		_update_auto_clear_panel({
			"state": "Not Found",
			"level": normalized_id,
			"gold": "tested through +100",
			"candidate": str(res.get("total_candidates_tested", "-")),
			"best": "Wave %d, %s" % [fail_wave, str(res.get("reason", "unknown"))],
			"result": "NOT_FOUND",
			"is_error": true
		})
		balance_solver.generate_auto_clear_report(res, "NOT_FOUND")

func debug_auto_clear_level_7() -> void:
	debug_auto_clear_level(7)

func auto_play_plan(plan: Dictionary) -> void:
	if plan.is_empty():
		_update_auto_clear_panel({"state": "Failed", "result": "No plan to replay", "is_error": true})
		return
	_normalize_auto_clear_plan(plan)
	if not is_plan_valid_for_autoplay(plan):
		print("[AUTO_CLEAR] Refusing to autoplay invalid or unvalidated plan.")
		_update_auto_clear_panel({"state": "Failed", "result": "Invalid plan rejected", "is_error": true})
		return
	print(_format_auto_clear_final_plan(plan))
	if not auto_play_verifier:
		_update_auto_clear_panel({"state": "Failed", "result": "No auto-play verifier", "is_error": true})
		return
	auto_clear_state = AutoClearState.AUTOPLAY_STARTING_LEVEL
	auto_clear_real_attempts += 1
	print("[AUTO_CLEAR] Starting real autoplay with starting_gold=%s" % str(plan.get("starting_gold_used", "-")))
	_update_auto_clear_panel({
		"state": "Auto Playing",
		"level": str(plan.get("level_id", "")),
		"gold": str(plan.get("starting_gold_used", plan.get("starting_gold", "-"))),
		"best": "Applying found plan",
		"result": "Running"
	})
	auto_play_verifier.start_verification(plan)

func is_plan_valid_for_autoplay(plan: Dictionary) -> bool:
	return AUTO_CLEAR_PLAN_HELPER_SCRIPT.is_plan_valid_for_autoplay(plan)

func _normalize_auto_clear_plan(plan: Dictionary) -> void:
	AUTO_CLEAR_PLAN_HELPER_SCRIPT.normalize_auto_clear_plan(plan)

func get_wave_action_list(plan: Dictionary, wave_number: int, timing: String) -> Array:
	return AUTO_CLEAR_PLAN_HELPER_SCRIPT.get_wave_action_list(plan, wave_number, timing)

func _get_plan_total_waves(plan: Dictionary) -> int:
	return AUTO_CLEAR_PLAN_HELPER_SCRIPT.get_plan_total_waves(plan)

func _plan_has_between_wave_non_start_action(plan: Dictionary) -> bool:
	return AUTO_CLEAR_PLAN_HELPER_SCRIPT.plan_has_between_wave_non_start_action(plan)

func _format_auto_clear_final_plan(plan: Dictionary) -> String:
	return AUTO_CLEAR_PLAN_HELPER_SCRIPT.format_auto_clear_final_plan(plan)

func _auto_clear_action_text(action: Dictionary) -> String:
	return AUTO_CLEAR_PLAN_HELPER_SCRIPT.auto_clear_action_text(action)

func _retry_auto_clear_after_real_failure(reason: String) -> void:
	if not auto_clear_active:
		return
	var current_gold: int = int(last_auto_clear_result.get("starting_gold", last_auto_clear_result.get("original_gold", 0)))
	var gold_candidates: Array = last_auto_clear_result.get("gold_candidates", [])
	var next_gold: int = -1
	for gold in gold_candidates:
		if int(gold) > current_gold:
			next_gold = int(gold)
			break
	if next_gold < 0 or auto_clear_real_attempts >= max_real_autoplay_attempts_per_gold:
		auto_clear_active = false
		auto_clear_state = AutoClearState.NO_PLAN_FOUND
		print("[AUTO_CLEAR] No valid plan found after real autoplay failure: %s" % reason)
		_update_auto_clear_panel({
			"state": "Failed",
			"level": str(last_auto_clear_result.get("level_id", current_level_id)),
			"gold": current_gold,
			"result": "Real autoplay failed",
			"best": reason,
			"is_error": true
		})
		return

	print("[AUTO_CLEAR] FAIL: %s Retrying at starting_gold=%d" % [reason, next_gold])
	auto_clear_state = AutoClearState.TESTING_GOLD_CANDIDATE
	_update_auto_clear_panel({
		"state": "Retrying",
		"level": str(last_auto_clear_result.get("level_id", current_level_id)),
		"gold": next_gold,
		"result": "Retry after real failure",
		"best": reason
	})
	var normalized_id: String = "level_%02d" % auto_clear_level_id
	var retry_result: Dictionary = balance_solver.solve_level_with_gold_testing(normalized_id, next_gold)
	_handle_auto_clear_solve_result(auto_clear_level_id, retry_result)

func debug_generate_balance_report() -> void:
	if not balance_solver:
		return
	if last_auto_clear_result.is_empty():
		var level_int: int = level_id_to_int(current_level_id)
		if level_int <= 0: level_int = 7
		var level_id: String = "level_%02d" % level_int
		last_auto_clear_result = balance_solver.solve_level_with_gold_testing(level_id)
		last_auto_clear_result["level_id"] = level_id
	var verification_type: String = "AUTO_PLAY_VERIFIED" if not last_found_plan.is_empty() else "SIMULATED_ONLY"
	balance_solver.generate_auto_clear_report(last_auto_clear_result, verification_type)
	_update_auto_clear_panel({
		"state": "Report Generated",
		"level": str(last_auto_clear_result.get("level_id", current_level_id)),
		"result": str(last_auto_clear_result.get("result_state", last_auto_clear_result.get("status", "-")))
	})

func _update_auto_clear_panel(status: Dictionary) -> void:
	if debug_panel and debug_panel.has_method("update_auto_clear_status"):
		debug_panel.update_auto_clear_status(status)
	elif debug_panel:
		debug_panel.update_verifier_status(str(status.get("state", "")), bool(status.get("is_error", false)))

func debug_auto_solve_current_level() -> void:
	if current_level_id == "":
		print("[AUTO_SOLVER] No level currently active.")
		return
	auto_solve_level(current_level_id)

func debug_auto_solve_level_7() -> void:
	auto_solve_level("level_07")

func debug_auto_solve_all_levels() -> void:
	print("[AUTO_SOLVER] BATCH SOLVE started (Levels 1-10)")
	if debug_panel: debug_panel.update_verifier_status("Batch Solving...")

	var batch_results = []
	for i in range(1, 11):
		var level_id = "level_%02d" % i
		var res = auto_solve_level(level_id, false)
		if not res.is_empty():
			batch_results.append(res)

	if balance_solver:
		balance_solver.generate_consolidated_report(batch_results)

	if debug_panel: debug_panel.update_verifier_status("Batch Solve Done")
	print("[AUTO_SOLVER] BATCH SOLVE completed. Report saved.")

func auto_solve_level(level_id: String, update_ui: bool = true) -> Dictionary:
	print("[AUTO_SOLVER] Solving level: ", level_id)
	if update_ui and debug_panel: debug_panel.update_verifier_status("Solving %s..." % level_id)

	if not balance_solver: return {}

	var res = balance_solver.solve_level_with_gold_testing(level_id)
	if res.is_empty(): return {}

	if res["status"] == "PASS":
		last_solved_plan = res["plan"]
		print("[AUTO_SOLVER] SUCCESS! Plan found for ", level_id)
		if res["starting_gold"] > res["original_gold"]:
			print("[AUTO_SOLVER] Note: Requires temporary gold override: ", res["starting_gold"])
		if update_ui and debug_panel:
			debug_panel.update_verifier_status("FOUND: %s (G:%d)" % [level_id, res["starting_gold"]])
	else:
		print("[AUTO_SOLVER] FAILED to solve ", level_id)
		print(" - Last Wave: ", res["wave"])
		print(" - Reason: ", res["reason"])
		if update_ui and debug_panel:
			debug_panel.update_verifier_status("FAIL: %s @W%d" % [level_id, res["wave"]], true)

	return res

func debug_auto_play_last_solved_plan() -> void:
	var plan: Dictionary = last_found_plan if not last_found_plan.is_empty() else last_solved_plan
	if plan.is_empty():
		print("[AUTO_SOLVER] No plan stored to auto-play.")
		if debug_panel: debug_panel.update_verifier_status("No last found plan", true)
		return

	print("[AUTO_SOLVER] Executing last found plan...")
	auto_play_plan(plan)

func get_all_level_ids() -> Array:
	var ids = []
	for i in range(1, 11):
		ids.append("level_%02d" % i)
	return ids
