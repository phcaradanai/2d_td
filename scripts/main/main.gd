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

enum GameState { MENU, LEVEL_SELECT, BUILD, WAVE, WAVE_COMPLETE, PAUSED, GAME_OVER, VICTORY }
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
var current_level_path: String = ""
var current_level_id: String = ""
var selected_level_id: int = 0

var pending_unlock_level_id: String = ""
var leaderboard_service: Node = null
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
const ELEMENT_PICK_INTERVAL: int = 5
const STARTING_ELEMENT_PICKS: int = 0
const INTEREST_PICK_ID: String = "__interest__"
const DEFAULT_INTEREST_UPGRADE_STEP: float = 0.01
const DEFAULT_MAX_INTEREST_UPGRADES: int = 5

const STARTER_TOWER_IDS := ["basic_tower_t1", "neutral_cannon_tower"]

var sandbox_layer: CanvasLayer = null
var sandbox_panel: PanelContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Apply global UI theme
	var theme_mgr = UI_THEME_MANAGER_SCRIPT.new()
	if main_menu: theme_mgr.apply_theme(main_menu)
	if game_hud: theme_mgr.apply_theme(game_hud)
	if level_select: theme_mgr.apply_theme(level_select)
	if debug_panel: theme_mgr.apply_theme(debug_panel)

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

	if main_menu:
		main_menu.set_version(VERSION)
	if game_hud:
		game_hud.set_version(VERSION)

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

func _on_viewport_size_changed() -> void:
	_update_world_layout()

func _update_world_layout() -> void:
	if not is_instance_valid(world_root): return

	var view_size = get_viewport().get_visible_rect().size

	# 1. Compute playfield rect
	var playfield_rect = Rect2()
	if game_hud and game_hud.has_method("get_playfield_rect"):
		playfield_rect = game_hud.get_playfield_rect()
		# No outer margin for maximal expansion
	else:
		# Fallback to old constants if HUD not ready
		var playfield_x = LEFT_SIDEBAR_WIDTH + OUTER_MARGIN
		var playfield_y = TOP_BAR_HEIGHT + OUTER_MARGIN
		var playfield_w = view_size.x - LEFT_SIDEBAR_WIDTH - RIGHT_SIDEBAR_WIDTH - (OUTER_MARGIN * 2)
		var playfield_h = view_size.y - TOP_BAR_HEIGHT - (OUTER_MARGIN * 2)
		playfield_rect = Rect2(playfield_x, playfield_y, playfield_w, playfield_h)

	# 2. Fit Map inside playfield
	if level_manager and level_manager.level_id != "" and map_root:
		_fit_map_to_playfield(playfield_rect)
	
	if background:
		background.color = Color.BLACK
		# Ensure background covers at least the playfield area in screen space
		# Since we use camera, we'll just make it very large for now
		background.size = Vector2(8000, 8000)
		background.position = Vector2(-4000, -4000)

func _fit_map_to_playfield(playfield_rect: Rect2) -> void:
	if not level_manager or not map_root or not camera: return

	# 1. Calculate map content bounds in world space
	var content_bounds = _get_map_content_bounds()
	if content_bounds.size == Vector2.ZERO: return
	
	# Add padding
	var padding = 40.0
	content_bounds = content_bounds.grow(padding)
	
	# 2. Calculate scale to fit bounds into playfield
	var scale_x = playfield_rect.size.x / content_bounds.size.x
	var scale_y = playfield_rect.size.y / content_bounds.size.y
	var fit_zoom = min(scale_x, scale_y)
	
	# Maximize scale (allow up to 5x for small maps on large screens)
	fit_zoom = clamp(fit_zoom, 0.4, 5.0)
	
	# 3. Apply to camera
	camera.zoom = Vector2.ONE * fit_zoom
	
	var content_center = content_bounds.get_center()
	var camera_pos = content_center - (playfield_rect.get_center() / fit_zoom)
	camera.position = camera_pos
	
	if OS.is_debug_build():
		var window_size = get_viewport().get_visible_rect().size
		var unused_x = playfield_rect.size.x - (content_bounds.size.x * fit_zoom)
		var unused_y = playfield_rect.size.y - (content_bounds.size.y * fit_zoom)
		print("[LAYOUT_DEBUG] window_size=", window_size)
		print("[LAYOUT_DEBUG] center_frame_rect=", playfield_rect)
		print("[LAYOUT_DEBUG] content_bounds=", content_bounds)
		print("[LAYOUT_DEBUG] camera_zoom=", fit_zoom)
		print("[LAYOUT_DEBUG] camera_position=", camera_pos)
		print("[LAYOUT_DEBUG] unused_px_h=", unused_x, " unused_px_v=", unused_y)

	# Reset map_root transform (we use camera now)
	map_root.scale = Vector2.ONE
	map_root.position = Vector2.ZERO
	world_root.position = Vector2.ZERO

func _get_map_content_bounds() -> Rect2:
	if not level_manager:
		return Rect2()

	var gs = level_manager.grid_size
	var map_w = level_manager.grid_cols * gs
	var map_h = level_manager.grid_rows * gs
	var fit_mode := str(level_manager.level_data.get("camera_fit_mode", ""))

	# Optional road-focused framing for polished small maps.
	if fit_mode == "road_focus":
		var focus_cells: Array[Vector2i] = []
		for p_id in level_manager.multi_paths:
			for cell in level_manager.multi_paths[p_id]:
				if cell is Vector2i and not focus_cells.has(cell):
					focus_cells.append(cell)
		for cell in _cells_from_level_arrays(level_manager.level_data.get("spawn_cells", [])):
			if not focus_cells.has(cell):
				focus_cells.append(cell)
		for cell in _cells_from_level_arrays(level_manager.level_data.get("base_cells", [])):
			if not focus_cells.has(cell):
				focus_cells.append(cell)
		if level_manager.spawn_cell != Vector2i.ZERO and not focus_cells.has(level_manager.spawn_cell):
			focus_cells.append(level_manager.spawn_cell)
		if level_manager.base_cell != Vector2i.ZERO and not focus_cells.has(level_manager.base_cell):
			focus_cells.append(level_manager.base_cell)

		if not focus_cells.is_empty():
			var min_cell: Vector2i = focus_cells[0]
			var max_cell: Vector2i = focus_cells[0]
			for cell in focus_cells:
				min_cell.x = min(min_cell.x, cell.x)
				min_cell.y = min(min_cell.y, cell.y)
				max_cell.x = max(max_cell.x, cell.x)
				max_cell.y = max(max_cell.y, cell.y)

			var bounds := Rect2(
				Vector2(min_cell.x * gs, min_cell.y * gs),
				Vector2((max_cell.x - min_cell.x + 1) * gs, (max_cell.y - min_cell.y + 1) * gs)
			)
			var margin_x := float(level_manager.level_data.get("camera_focus_margin_cells_x", 2.0)) * float(gs)
			var margin_y := float(level_manager.level_data.get("camera_focus_margin_cells_y", 1.5)) * float(gs)
			bounds = bounds.grow_side(SIDE_LEFT, margin_x)
			bounds = bounds.grow_side(SIDE_RIGHT, margin_x)
			bounds = bounds.grow_side(SIDE_TOP, margin_y)
			bounds = bounds.grow_side(SIDE_BOTTOM, margin_y)
			return bounds

	var points: Array[Vector2] = []

	# Default full-grid framing.
	points.append(Vector2.ZERO)
	points.append(Vector2(map_w, map_h))

	if level_manager.spawn_cell != Vector2i.ZERO:
		points.append(Vector2(level_manager.spawn_cell) * gs + Vector2(gs, gs) * 0.5)
	if level_manager.base_cell != Vector2i.ZERO:
		points.append(Vector2(level_manager.base_cell) * gs + Vector2(gs, gs) * 0.5)

	for cell in level_manager.path_cells:
		points.append(Vector2(cell) * gs + Vector2(gs, gs) * 0.5)

	for cell in level_manager.buildable_cells:
		points.append(Vector2(cell) * gs + Vector2(gs, gs) * 0.5)

	if points.is_empty():
		return Rect2(0, 0, map_w, map_h)

	var min_p = points[0]
	var max_p = points[0]
	for p in points:
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x)
		max_p.y = max(max_p.y, p.y)

	var bounds = Rect2(min_p, max_p - min_p)
	bounds = bounds.grow_side(SIDE_LEFT, 64)
	bounds = bounds.grow_side(SIDE_RIGHT, 48)
	bounds = bounds.grow_side(SIDE_TOP, 48)
	bounds = bounds.grow_side(SIDE_BOTTOM, 48)
	return bounds

func _cells_from_level_arrays(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (raw is Array):
		return out
	for item in raw:
		if item is Array and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out

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
	hud_state_presenter.refresh_start_wave_button(
		can_start,
		_is_waiting_for_manual_first_wave(),
		countdown_active,
		countdown_remaining,
		wave_manager.get_next_wave_number()
	)

func _refresh_gameplay_hud_state() -> void:
	_refresh_start_wave_ui()
	_refresh_hud_wave_intel()
	_refresh_route_preview()

var active_path_nodes: Dictionary = {}

func _setup_game_from_level() -> void:
	if level_manager == null: return

	# Clear existing gameplay state
	_clear_gameplay_state()
	_configure_auto_next_wave_from_level()
	_configure_element_td_interest_from_level()
	auto_next_wave_service.reset() if auto_next_wave_service else null
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
		wave_manager.setup(active_path_nodes)
		if level_manager.level_data.has("waves") and level_manager.level_data["waves"] is Array and not level_manager.level_data["waves"].is_empty():
			wave_manager.load_waves_from_data(level_manager.level_data["waves"])
		else:
			wave_manager.load_waves_from_file(level_manager.waves_path)
		wave_manager.reset_waves()
		_log_wave_intel_source()
		
		if OS.is_debug_build() and level_validator:
			level_validator.validate_level(level_manager.level_id, level_manager.get_config_as_dict(), wave_manager.waves)

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
			print("[AUTO_CLEAR] Applied debug-only starting_gold override: ", gold_to_apply)
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
	# Removed _spawn_hero() as it's now manual deployment
	_setup_hero_if_enabled()

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
	if element_td_interest_service:
		return element_td_interest_service.format_rate_percent()
	return "%.0f%%" % (ElementTDInterestService.DEFAULT_BASE_RATE * 100.0)

func _format_next_interest_rate_percent() -> String:
	if element_td_interest_service:
		return element_td_interest_service.format_next_rate_percent()
	return "%.0f%%" % ((ElementTDInterestService.DEFAULT_BASE_RATE + DEFAULT_INTEREST_UPGRADE_STEP) * 100.0)

func _can_choose_interest_upgrade() -> bool:
	return element_td_interest_service != null and element_td_interest_service.can_choose_upgrade()

func _has_pending_element_pick() -> bool:
	return element_progression_manager != null and element_progression_manager.has_method("has_pending_pick") and element_progression_manager.has_pending_pick()

func _is_waiting_for_manual_first_wave() -> bool:
	if auto_next_wave_service == null or wave_manager == null:
		return false
	return auto_next_wave_service.is_waiting_for_manual_first_wave(
		wave_manager.get_next_wave_number(),
		wave_manager.is_wave_running
	)

func _can_auto_next_wave_countdown() -> bool:
	if current_state != GameState.BUILD and current_state != GameState.WAVE_COMPLETE:
		return false
	if wave_manager == null or wave_manager.is_wave_running or not wave_manager.has_next_wave():
		return false
	if _has_pending_element_pick():
		return false
	return true

func _maybe_start_auto_next_wave_countdown() -> void:
	if auto_next_wave_service == null:
		return
	auto_next_wave_service.maybe_start_countdown(
		_can_auto_next_wave_countdown(),
		_is_waiting_for_manual_first_wave()
	)
	_refresh_start_wave_ui()

func _stop_auto_next_wave_countdown() -> void:
	if auto_next_wave_service:
		auto_next_wave_service.stop_countdown()
	_refresh_start_wave_ui()

func _update_auto_next_wave_countdown(delta: float) -> void:
	if auto_next_wave_service == null:
		return
	var should_start: bool = bool(auto_next_wave_service.tick(
		delta,
		_can_auto_next_wave_countdown(),
		get_tree().paused or _has_pending_element_pick() or current_state == GameState.PAUSED
	))
	if should_start:
		_on_start_wave_requested()
	else:
		_refresh_start_wave_ui()

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

func _level_uses_fixed_pathing() -> bool:
	if level_manager == null:
		return false
	var mode := str(level_manager.level_data.get("enemy_pathing_mode", level_manager.level_data.get("pathing_mode", "fixed_path"))).to_lower()
	return mode == "fixed_path" or bool(level_manager.level_data.get("fixed_path", false))


func _refresh_hud_stats() -> void:
	if game_hud and game_manager:
		game_hud.set_gold(game_manager.gold)
		game_hud.set_lives(game_manager.lives)
		game_hud.set_wave(game_manager.current_wave)

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
		
	# Initialize Leaderboard Service
	leaderboard_service = load("res://scripts/core/leaderboard_service.gd").new()
	add_child(leaderboard_service)
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
	if build_manager.has_method("set_unlocked_tower_ids"):
		build_manager.set_unlocked_tower_ids(ids)
	game_hud.refresh_tower_shop(ids)
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

func _on_element_choice_requested(element_id: String) -> void:
	if element_progression_manager == null:
		return
	if element_id == INTEREST_PICK_ID:
		_choose_interest_upgrade_pick()
		return
	if element_progression_manager.choose_element(element_id):
		_refresh_elemental_shop()
		if game_hud:
			game_hud.set_build_status("Element unlocked: %s" % element_progression_manager.get_element_label(element_id))
			if element_progression_manager.pending_picks > 0:
				_show_pending_element_choice()
			else:
				game_hud.hide_element_choice()
				_resume_auto_next_wave_after_element_choice()
	else:
		if game_hud:
			game_hud.set_build_status("Cannot choose that element")

func _choose_interest_upgrade_pick() -> void:
	if element_progression_manager == null:
		return
	if int(element_progression_manager.pending_picks) <= 0:
		return
	if not _can_choose_interest_upgrade():
		if game_hud:
			game_hud.set_build_status("Interest upgrade is already maxed")
		return
	element_progression_manager.pending_picks = max(0, int(element_progression_manager.pending_picks) - 1)
	if element_td_interest_service:
		element_td_interest_service.apply_upgrade()
	_recalculate_element_td_interest_rate()
	if element_td_interest_service:
		element_td_interest_service.elapsed = 0.0
	if game_hud:
		game_hud.set_build_status("Interest upgraded to %s" % _format_interest_rate_percent())
		show_wave_feedback("Interest %s" % _format_interest_rate_percent(), Color(1.0, 0.85, 0.25))
		if int(element_progression_manager.pending_picks) > 0:
			_show_pending_element_choice()
		else:
			game_hud.hide_element_choice()
			_resume_auto_next_wave_after_element_choice()

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
		main_menu.start_pressed.connect(_on_level_select_requested)
		main_menu.level_select_pressed.connect(_on_level_select_requested)
		main_menu.quit_pressed.connect(func(): get_tree().quit())

	if level_select:
		level_select.level_selected.connect(start_game)
		level_select.back_pressed.connect(_on_level_select_back)
		level_select.leaderboard_requested.connect(_on_leaderboard_requested)

	if game_hud:
		game_hud.start_wave_requested.connect(_on_start_wave_requested)
		game_hud.tower_build_selected.connect(_on_tower_build_selected)
		game_hud.cancel_build_requested.connect(_on_cancel_build_requested)
		game_hud.pause_requested.connect(_on_pause_requested)
		game_hud.restart_requested.connect(restart_level)
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
		game_hud.test_audio_requested.connect(_on_test_audio_requested)
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
		wave_manager.enemy_killed.connect(_on_enemy_killed)
		wave_manager.base_damaged.connect(_on_base_damaged)

	if game_manager:
		game_manager.gold_changed.connect(game_hud.set_gold)
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
			elif event.keycode == KEY_F11:
				if auto_play_verifier:
					_start_debug_auto_play()

	if current_state != GameState.BUILD: return

	if event is InputEventMouseButton and event.pressed:
		var local_mouse = map_root.to_local(get_global_mouse_position())

		# Right click cancels build mode or selection
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

# --- Session Flow ---

func return_to_menu() -> void:
	set_game_phase(GameState.MENU)
	_clear_route_preview()
	_resume_game()
	_clear_gameplay_state()
	if audio_manager:
		audio_manager.play_music("menu")

func _on_level_select_requested() -> void:
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
	leaderboard_panel.show_leaderboard(leaderboard_service, level_id)

func start_game(level_path: String) -> void:
	start_level(level_path)

func start_level(level_path: String) -> void:
	current_level_path = level_path

	# STANDARD: Ensure engine is unpaused when starting a level
	get_tree().paused = false
	if game_manager: game_manager.is_paused = false

	if game_hud:
		game_hud.exit_end_game_ui_state()
		game_hud.clear_wave_intel()

	if OS.is_debug_build(): print("[Main] start_level: ", level_path)

	_clear_gameplay_state()

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

func restart_level() -> void:
	if OS.is_debug_build(): print("[Main] restart_level requested for: ", current_level_path)
	if get_tree().paused:
		get_tree().paused = false

	if game_hud:
		game_hud.exit_end_game_ui_state()

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
	if tower_container:
		for tower in tower_container.get_children():
			tower.queue_free()
	if projectile_container:
		for proj in projectile_container.get_children():
			proj.queue_free()
	if effects_container:
		for effect in effects_container.get_children():
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
	var camera = get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(strength, duration)

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
				# Title screen should block mouse to its buttons
				main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().paused = false

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
	if audio_manager:
		audio_manager.play_sfx("tower_place")

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
		if selected_tower.has_method("set_selected"):
			selected_tower.set_selected(true)
		if game_hud:
			game_hud.show_tower_info(selected_tower.get_info())
	else:
		clear_selected_tower()

func clear_selected_tower() -> void:
	if selected_tower and is_instance_valid(selected_tower):
		if selected_tower.has_method("set_selected"):
			selected_tower.set_selected(false)
	selected_tower = null
	if game_hud:
		game_hud.hide_tower_info()

func _deselect_tower() -> void:
	clear_selected_tower()

func _on_upgrade_tower_requested() -> void:
	if current_state != GameState.BUILD: return
	if selected_tower == null or not selected_tower.can_upgrade(): return

	var next_ids: Array = selected_tower.get_info().get("next_upgrade_ids", [])
	if not next_ids.is_empty():
		var next_cfg: Dictionary = build_manager.towers_config.get(str(next_ids[0]), {})
		if not _config_unlocked_for_upgrade(next_cfg):
			if game_hud:
				game_hud.set_build_status(_locked_upgrade_reason(next_cfg))
			return

	var cost: int = selected_tower.get_upgrade_cost()
	if cost <= 0:
		if game_hud:
			game_hud.set_build_status("Upgrade unavailable")
		return

	if game_manager and game_manager.spend_gold(cost):
		var tower := selected_tower
		tower.upgrade()
		if game_manager.battle_telemetry:
			game_manager.battle_telemetry.log_tower_upgraded(tower.tower_id, tower.tree_tier - 1, tower.tree_tier, cost)
		# Re-select to fully refresh UI with new upgrade_id
		clear_selected_tower()
		_select_tower(tower)
		if game_hud:
			game_hud.set_build_status("Tower Upgraded!")
		if audio_manager:
			audio_manager.play_sfx("tower_upgrade")
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
		return
	if wave_manager == null or not wave_manager.has_next_wave():
		return
	_stop_auto_next_wave_countdown()
	auto_next_wave_service.mark_first_wave_started() if auto_next_wave_service else null
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
	if element_td_interest_service:
		element_td_interest_service.elapsed = 0.0
	else:
		if element_td_interest_service:
			element_td_interest_service.elapsed = 0.0
	if element_td_interest_service:
		element_td_interest_service.disabled_for_wave = false
	else:
		if element_td_interest_service:
			element_td_interest_service.disabled_for_wave = false
	_stop_auto_next_wave_countdown()
	_clear_route_preview()
	set_game_phase(GameState.WAVE)
	if game_manager:
		game_manager.set_current_wave(wave_number)
	if game_hud:
		game_hud.set_status("Wave %d: %s" % [wave_number, wave_name])
		show_wave_feedback("Wave %d: %s" % [wave_number, wave_name], Color(1, 0.8, 0.2))
		_refresh_gameplay_hud_state()

func _on_wave_completed(wave_number: int, wave_name: String, reward: int) -> void:
	if element_td_interest_service:
		element_td_interest_service.elapsed = 0.0
	else:
		if element_td_interest_service:
			element_td_interest_service.elapsed = 0.0
	if element_td_interest_service:
		element_td_interest_service.disabled_for_wave = false
	else:
		if element_td_interest_service:
			element_td_interest_service.disabled_for_wave = false
	set_game_phase(GameState.WAVE_COMPLETE)
	if game_manager:
		game_manager.award_wave_completion(reward)
	if game_hud:
		game_hud.set_status("Wave %d cleared! +%d Gold" % [wave_number, reward])
		show_wave_feedback("Wave Cleared! +%d Gold" % reward, Color(0.2, 1.0, 0.4))
		_refresh_gameplay_hud_state()
	if audio_manager:
		audio_manager.play_sfx("gold_gain")
	if element_progression_manager and wave_number > 0 and wave_number % ELEMENT_PICK_INTERVAL == 0:
		element_progression_manager.grant_pick(1)
		_show_pending_element_choice()
	# Auto-advance to planning after a brief reward moment
	get_tree().create_timer(2.5).timeout.connect(func():
		if current_state == GameState.WAVE_COMPLETE:
			set_game_phase(GameState.BUILD)
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

func _on_base_damaged(base_damage: int, global_pos: Vector2) -> void:
	# Element TD-style leak respawn still lets the creep be killed later,
	# but interest for this wave stops after a leak to avoid abuse.
	if element_td_interest_service:
		element_td_interest_service.disable_for_current_wave()
	else:
		if element_td_interest_service:
			element_td_interest_service.disable_for_current_wave()
	if element_td_interest_service:
		element_td_interest_service.elapsed = 0.0
	else:
		if element_td_interest_service:
			element_td_interest_service.elapsed = 0.0
	if game_manager:
		game_manager.damage_base(base_damage)

	shake_camera(15.0, 0.4)
	if game_hud:
		game_hud.show_screen_flash(Color(0.8, 0.1, 0.1, 0.4), 0.3)

	# Spawn impact effect at leak position
	var impact_scene = preload("res://scenes/effects/ImpactEffect.tscn")
	if impact_scene:
		var effect = impact_scene.instantiate()
		var container = get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if container:
			container.add_child(effect)
			effect.global_position = global_pos
			effect.setup(Color(1, 0, 0), 3.0)

			if OS.is_debug_build():
				print("[BaseDamageFX] leak_global=", global_pos, " fx.global=", effect.global_position, " parent=", container.name)
		else:
			add_child(effect)
			effect.global_position = global_pos
			effect.setup(Color(1, 0, 0), 3.0)

	# Spawn floating text
	var damage_number_scene = preload("res://scenes/effects/DamageNumber.tscn")
	if damage_number_scene:
		var dn = damage_number_scene.instantiate()
		var container = get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if container:
			container.add_child(dn)
			dn.global_position = global_pos + Vector2(0, -30)
			dn.setup(base_damage, Color(1, 0.2, 0.2)) # Red for base damage

	if audio_manager:
		audio_manager.play_sfx("enemy_reach_base")

func _on_game_over() -> void:
	if OS.is_debug_build(): print("[Main] Game Over Triggered")
	set_game_phase(GameState.GAME_OVER)
	_clear_route_preview()

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
		if leaderboard_service:
			rank = leaderboard_service.submit_score(level_manager.level_id, summary, save_manager.get_player_name())
	
	if game_hud:
		game_hud.show_run_summary(summary, improvements, rank)
		if OS.is_debug_build(): print("[ResultPanel] shown for ", current_level_id)

	_refresh_gameplay_hud_state()
	if audio_manager:
		audio_manager.play_sfx("game_over")

func _clear_projectiles_and_targeting() -> void:
	if projectile_container:
		for proj in projectile_container.get_children():
			proj.queue_free()

	# Clear all tower targeting lines
	if tower_container:
		for tower in tower_container.get_children():
			if tower.has_method("clear_targeting_line"):
				tower.clear_targeting_line()

func _on_victory() -> void:
	set_game_phase(GameState.VICTORY)
	_clear_route_preview()

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
		
		if leaderboard_service:
			rank = leaderboard_service.submit_score(level_manager.level_id, summary, save_manager.get_player_name())
		
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

# --- Audio Handlers ---

func _on_audio_settings_changed(settings: Dictionary) -> void:
	if audio_manager:
		audio_manager.apply_settings(settings)
	if save_manager:
		save_manager.update_audio_settings(settings)

func _on_test_audio_requested(type: String) -> void:
	if audio_manager:
		if type == "sfx":
			audio_manager.play_sfx("ui_click")
		elif type == "music":
			# Normal test
			audio_manager.play_music("menu")
			# Also trigger diagnostics
			audio_manager.print_bus_diagnostics()
		elif type == "fallback_test":
			audio_manager.play_music_fallback_test()

func _on_reset_audio_requested() -> void:
	if audio_manager:
		audio_manager.reset_to_defaults()
		if game_hud:
			game_hud.set_audio_settings_ui(audio_manager.get_settings())
		if save_manager:
			save_manager.update_audio_settings(audio_manager.get_settings())

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
		_add_sandbox_button(box, "+1 " + eid.capitalize(), Callable(self, "_sandbox_add_element").bind(eid, 1))
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
		game_hud.hide_element_choice()
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
		game_hud.hide_element_choice()
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
	var text = str(level_id_value)
	if text == "": return 0
	if text.is_valid_int(): return int(text)
	var parts = text.split("_")
	if parts.is_empty(): return 0
	var suffix = parts[parts.size() - 1]
	return int(suffix) if suffix.is_valid_int() else 0

func format_level_id(level_id: int) -> String:
	return "level_%02d" % level_id

func normalize_enemy_type(raw: String) -> String:
	var value = raw.to_lower()
	match value:
		"basic", "normal", "grunt": return "Normal"
		"fast", "runner", "scout": return "Fast"
		"tank", "heavy", "brute": return "Heavy"
		"swarm", "small": return "Swarm"
		"air", "flyer": return "Air"
		"air_fast", "fast_air", "flyer_fast": return "Fast"
		"air_basic", "basic_air", "flyer_basic": return "Normal"
		_: return raw.capitalize()

func normalize_enemy_category(raw_category) -> String:
	var normalized = str(raw_category).strip_edges().to_lower()
	if VALID_ENEMY_CATEGORIES.has(normalized):
		return normalized
	return ENEMY_CATEGORY_LAND

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
	if enemy_category == ENEMY_CATEGORY_AIR and normalized_type != "Air":
		return "Air " + normalized_type
	return normalized_type

func derive_wave_traits(enemy_counts: Dictionary, total_count: int, categories: Dictionary = {}) -> Array[String]:
	var traits: Array[String] = []
	if total_count == 0: return ["Standard"]
	
	if categories.has(ENEMY_CATEGORY_AIR): traits.append("Air")
	
	# Majority/Significance checks
	var has_fast = false
	var has_heavy = false
	var has_swarm = false
	var has_shield = false
	var has_anti_hero = false
	
	for type_name in enemy_counts.keys():
		var count = enemy_counts[type_name]
		var ratio = float(count) / total_count
		
		if type_name.contains("Fast") and ratio > 0.2: has_fast = true
		if type_name.contains("Heavy") and ratio > 0.2: has_heavy = true
		if type_name.contains("Swarm") and ratio > 0.4: has_swarm = true
		if type_name.contains("Bulwark") or type_name.contains("Shield"): has_shield = true
		if type_name.contains("Hunter") or type_name.contains("Anti-Hero"): has_anti_hero = true
		if type_name.contains("Healer"): traits.append("Healing")
		if type_name.contains("Cloaked") or type_name.contains("Ghost"): traits.append("Stealth")
		if type_name.contains("Disruptor") or type_name.contains("EMP"): traits.append("Disruption")
		if type_name.contains("Splitter"): traits.append("Splitting")
		
	if has_fast: traits.append("Fast")
	if has_heavy: traits.append("Heavy")
	if has_swarm or total_count >= 15: traits.append("Swarm")
	if has_shield: traits.append("Shield")
	if has_anti_hero: traits.append("Anti-Hero")
	
	if enemy_counts.keys().size() >= 3:
		traits.append("Mixed")
	
	if traits.is_empty():
		traits.append("Standard")
		
	return traits

func recommend_roles_for_wave(traits: Array[String]) -> Array[String]:
	var roles: Array[String] = []

	# Element TD-style guidance: recommend element roles and combo directions,
	# not old tower classes such as Basic/Rapid/Cannon/Slow/Guardian.
	if traits.has("Air"):
		roles.append("Light/Nature anti-air")
		roles.append("Dual universal tower")

	if traits.has("Fast"):
		roles.append("Water slow")
		roles.append("Light rapid")

	if traits.has("Heavy"):
		roles.append("Fire splash")
		roles.append("Earth high damage")

	if traits.has("Shield"):
		roles.append("Fire + Earth splash")
		roles.append("Darkness vulnerability")

	if traits.has("Anti-Hero"):
		roles.append("Light burst")
		roles.append("Water control")

	if traits.has("Swarm"):
		roles.append("Fire splash")
		roles.append("Water + Nature slow field")

	if traits.has("Mixed"):
		roles.append("Dual element coverage")
		roles.append("Triple combo tower")

	if traits.has("Stealth"):
		roles.append("Light reveal damage")
		roles.append("Darkness chain pressure")

	if traits.has("Healing") or traits.has("Splitting"):
		roles.append("Light + Darkness chain")
		roles.append("Earth single-target focus")

	if traits.has("Disruption"):
		roles.append("Long range element combo")
		roles.append("Split tower placement")

	if roles.is_empty():
		roles.append("Starter tower")
		roles.append("Choose first element")

	var unique: Array[String] = []
	for r in roles:
		if not unique.has(r):
			unique.append(r)
	return unique


func _get_preview_wave_groups(wave_data: Dictionary) -> Array:
	if wave_data.has("groups") and wave_data["groups"] is Array:
		return wave_data["groups"]
	if wave_data.has("spawns") and wave_data["spawns"] is Array:
		return wave_data["spawns"]
	if wave_data.has("enemies") and wave_data["enemies"] is Array:
		return wave_data["enemies"]
	if wave_data.has("enemy_type") or wave_data.has("type"):
		return [wave_data]
	return []

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
	var formation_preview = _summarize_wave_formations_for_preview(wave_data)
	
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
	var warnings: Array[String] = []
	if traits.has("Shield"):
		warnings.append("Protected units take reduced damage inside the dome.")
	if traits.has("Anti-Hero"):
		warnings.append("Hunter targets Guardian directly. Priority target him.")
	if traits.has("Shield") and traits.has("Anti-Hero"):
		warnings.append("Danger: Shielded high-threat units detected.")
	return warnings

func _validate_wave_design(wave_data: Dictionary, traits: Array[String], total_count: int) -> void:
	if not OS.is_debug_build(): return
	
	var wave_name = wave_data.get("name", "Unknown")
	
	if traits.has("Shield"):
		if total_count < 6:
			print("[WaveDesign] WARNING: Isolated Bulwark in wave '%s' (total_count=%d). Shield aura has low value." % [wave_name, total_count])
		else:
			print("[WaveDesign] PASS: Bulwark escorted in wave '%s' (total_count=%d)." % [wave_name, total_count])
			
	if traits.has("Anti-Hero"):
		if total_count < 4:
			print("[WaveDesign] WARNING: Isolated Hunter in wave '%s' (total_count=%d). No distraction/pressure units." % [wave_name, total_count])
		else:
			print("[WaveDesign] PASS: Hunter joined pack in wave '%s' (total_count=%d)." % [wave_name, total_count])

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
	var waves_data = _get_wave_source_for_preview(level_id)
	var result: Array[Dictionary] = []
	for wave in waves_data:
		var preview = summarize_wave_for_preview(wave)
		if not preview.is_empty():
			result.append(preview)
	return result

func get_wave_preview_for_index(level_id: int, wave_index: int) -> Dictionary:
	if wave_index < 0:
		return {}
	var previews = get_wave_preview_data(level_id)
	if wave_index >= previews.size():
		return {}
	return previews[wave_index]

func format_wave_enemy_summary(summary: Dictionary) -> String:
	var counts = summary.get("enemy_counts", {})
	if counts.is_empty(): return "Malformed Wave"
	var parts = []
	var type_order = ["Normal", "Fast", "Heavy", "Swarm", "Air", "Air Normal", "Air Fast", "Air Heavy", "Air Swarm"]
	for type_name in type_order:
		if counts.has(type_name):
			parts.append("%s x%d" % [type_name, int(counts[type_name])])
	for type_name in counts.keys():
		if not type_order.has(str(type_name)):
			parts.append("%s x%d" % [str(type_name), int(counts[type_name])])
	return ", ".join(parts)

func _refresh_hud_wave_intel() -> void:
	if not game_hud or not wave_manager: return

	if current_state != GameState.BUILD and current_state != GameState.WAVE:
		game_hud.clear_wave_intel()
		return

	if selected_level_id <= 0:
		game_hud.clear_wave_intel()
		return

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

	var report = balance_solver.generate_consolidated_report(results)
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
		print(" - ", type, " at ", cell, " (Lv", lvl, ") pos=", tower.global_position)

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

func get_auto_verify_plan_for_level(level_id: int) -> Dictionary:
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
	var verifier_script = preload("res://scripts/debug/auto_play_verifier.gd")
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
	if plan.is_empty():
		return false
	if not plan.has("level_id"):
		return false
	if not plan.has("initial_actions"):
		return false
	if not plan.has("wave_actions"):
		return false
	if not bool(plan.get("validated", false)):
		return false
	if int(plan.get("expected_lives_lost", 999)) != 0:
		return false
	if bool(plan.get("covers_all_waves", false)) != true:
		return false
	var total_waves: int = _get_plan_total_waves(plan)
	if total_waves <= 0:
		return false
	for wave_num in range(1, total_waves + 1):
		if not plan.get("wave_actions", {}).has(str(wave_num)):
			return false
		var before_actions: Array = get_wave_action_list(plan, wave_num, "before_wave")
		var after_actions: Array = get_wave_action_list(plan, wave_num, "after_wave")
		for action in before_actions + after_actions:
			if not (action is Dictionary):
				return false
			var action_type: String = str(action.get("type", ""))
			if not ["place_tower", "upgrade_tower", "start_wave", "wait_seconds"].has(action_type):
				return false
	if total_waves > 1 and not _plan_has_between_wave_non_start_action(plan):
		print("[AUTO_CLEAR] Planner selected upgrades/builds during search, but final plan contains no between-wave actions.")
		return false
	return true

func _normalize_auto_clear_plan(plan: Dictionary) -> void:
	if not plan.has("wave_actions") or not (plan["wave_actions"] is Dictionary):
		plan["wave_actions"] = {}
		return
	var normalized: Dictionary = {}
	for wave_key in plan["wave_actions"].keys():
		var wave_data = plan["wave_actions"][wave_key]
		if wave_data is Dictionary:
			var wave_dict: Dictionary = wave_data
			normalized[str(wave_key)] = {
				"before_wave": wave_dict.get("before_wave", []),
				"after_wave": wave_dict.get("after_wave", [])
			}
		elif wave_data is Array:
			var before: Array = []
			var after: Array = []
			for action in wave_data:
				if action is Dictionary and str(action.get("timing", "before_wave")) == "after_wave":
					after.append(action)
				elif action is Dictionary:
					before.append(action)
			normalized[str(wave_key)] = {"before_wave": before, "after_wave": after}
	plan["wave_actions"] = normalized

func get_wave_action_list(plan: Dictionary, wave_number: int, timing: String) -> Array:
	var wave_key := str(wave_number)
	var wave_actions: Dictionary = plan.get("wave_actions", {})
	if not wave_actions.has(wave_key):
		return []
	var entry = wave_actions[wave_key]
	if entry is Dictionary:
		return entry.get(timing, [])
	var result: Array = []
	if entry is Array:
		for action in entry:
			if action is Dictionary and str(action.get("timing", "before_wave")) == timing:
				result.append(action)
	return result

func _get_plan_total_waves(plan: Dictionary) -> int:
	var total_waves: int = 0
	for wave_key in plan.get("wave_actions", {}).keys():
		total_waves = max(total_waves, int(str(wave_key)))
	return total_waves

func _plan_has_between_wave_non_start_action(plan: Dictionary) -> bool:
	var total_waves: int = _get_plan_total_waves(plan)
	for wave_num in range(1, total_waves + 1):
		for action in get_wave_action_list(plan, wave_num, "after_wave"):
			if action is Dictionary and str(action.get("type", "")) != "start_wave":
				return true
		if wave_num > 1:
			for action in get_wave_action_list(plan, wave_num, "before_wave"):
				if action is Dictionary and str(action.get("type", "")) != "start_wave":
					return true
	return false

func _format_auto_clear_final_plan(plan: Dictionary) -> String:
	var lines: Array[String] = ["[AUTO_CLEAR] FINAL PLAN:"]
	lines.append("Initial actions:")
	for action in plan.get("initial_actions", []):
		if action is Dictionary:
			lines.append(" - %s" % _auto_clear_action_text(action))
	var total_waves: int = _get_plan_total_waves(plan)
	for wave_num in range(1, total_waves + 1):
		lines.append("Wave %d before:" % wave_num)
		for action in get_wave_action_list(plan, wave_num, "before_wave"):
			if action is Dictionary:
				lines.append(" - %s" % _auto_clear_action_text(action))
		lines.append("Wave %d after:" % wave_num)
		for action in get_wave_action_list(plan, wave_num, "after_wave"):
			if action is Dictionary:
				lines.append(" - %s" % _auto_clear_action_text(action))
	return "\n".join(lines)

func _auto_clear_action_text(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"place_tower":
			return "place %s %s" % [str(action.get("tower_type", "")), str(action.get("cell", []))]
		"upgrade_tower":
			return "upgrade %s" % str(action.get("tower_ref", action.get("cell", [])))
		"start_wave":
			return "start_wave"
		_:
			return str(action)

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
