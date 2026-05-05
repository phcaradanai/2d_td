extends Node2D

# Preload scripts for dynamic node creation if missing in scene
const LEVEL_MANAGER_SCRIPT = preload("res://scripts/managers/level_manager.gd")
const MAP_VISUAL_LAYER_SCRIPT = preload("res://scripts/map/map_visual_layer.gd")
const UI_THEME_MANAGER_SCRIPT = preload("res://scripts/ui/ui_theme_manager.gd")

enum GameState { MENU, LEVEL_SELECT, PLAYING, PAUSED, GAME_OVER, VICTORY }

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

const VERSION = "v0.1.0 Prototype"

# Layout Constants
const TOP_BAR_HEIGHT = 60
const LEFT_SIDEBAR_WIDTH = 200
const RIGHT_SIDEBAR_WIDTH = 260
const OUTER_MARGIN = 10

var level_manager: Node = null
var map_visual_layer: Node2D = null
var selected_tower: Node2D = null
var current_state: GameState = GameState.MENU
var current_level_path: String = ""
var current_level_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Apply global UI theme
	var theme_mgr = UI_THEME_MANAGER_SCRIPT.new()
	if main_menu: theme_mgr.apply_theme(main_menu)
	if game_hud: theme_mgr.apply_theme(game_hud)
	if level_select: theme_mgr.apply_theme(level_select)
	if debug_panel: theme_mgr.apply_theme(debug_panel)
	
	if debug_panel:
		debug_panel.layer = 500
		debug_panel.visible = false
		debug_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		
	if debug_button:
		# Show only in debug or if enabled
		debug_button.visible = _can_show_debug_panel()
		debug_button.pressed.connect(_on_debug_button_pressed)
		debug_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_ensure_level_nodes_exist()
	
	if OS.has_feature("web"):
		_show_audio_unlock_overlay()
	
	if build_manager:
		build_manager.setup(game_manager, tower_container, projectile_container)
		if game_hud:
			var prices = {}
			for id in ["basic_tower", "rapid_tower", "cannon_tower", "slow_tower"]:
				var config = build_manager.towers_config.get(id, {})
				prices[id] = config.get("cost", 0)
			game_hud.set_tower_prices(prices)
	
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
	var playfield_x = LEFT_SIDEBAR_WIDTH + OUTER_MARGIN
	var playfield_y = TOP_BAR_HEIGHT + OUTER_MARGIN
	var playfield_w = view_size.x - LEFT_SIDEBAR_WIDTH - RIGHT_SIDEBAR_WIDTH - (OUTER_MARGIN * 2)
	var playfield_h = view_size.y - TOP_BAR_HEIGHT - (OUTER_MARGIN * 2)
	
	var playfield_rect = Rect2(playfield_x, playfield_y, playfield_w, playfield_h)
	
	# Position WorldRoot at top-left of playfield
	world_root.position = playfield_rect.position
	
	if background:
		background.size = playfield_rect.size
		background.position = Vector2.ZERO
	
	# 2. Fit Map inside playfield
	if level_manager and level_manager.level_id != "" and map_root:
		_fit_map_to_playfield(playfield_rect)

func _fit_map_to_playfield(playfield_rect: Rect2) -> void:
	if not level_manager or not map_root: return
	
	# Calculate logical map size
	var map_w = level_manager.grid_cols * level_manager.grid_size
	var map_h = level_manager.grid_rows * level_manager.grid_size
	var map_pixel_size = Vector2(map_w, map_h)
	
	# Calculate fit scale
	var scale_x = playfield_rect.size.x / map_pixel_size.x
	var scale_y = playfield_rect.size.y / map_pixel_size.y
	var fit_scale = min(scale_x, scale_y)
	
	# Clamp scale to avoid tiny maps or huge maps
	fit_scale = min(fit_scale, 1.0)
	fit_scale = max(fit_scale, 0.4)
	
	map_root.scale = Vector2.ONE * fit_scale
	
	# Center map inside playfield (MapRoot local offset)
	var scaled_map_size = map_pixel_size * fit_scale
	var centering_offset = (playfield_rect.size - scaled_map_size) * 0.5
	
	# Apply offset to MapRoot (relative to WorldRoot which is already at playfield.pos)
	# Divide by fit_scale if we want it to be "unscaled local offset" 
	# but since MapRoot is child of WorldRoot, and we want it centered in playfield,
	# and WorldRoot is at playfield.pos, we just need to set map_root.position = centering_offset
	# Wait, if map_root is scaled, its position is in WorldRoot space (unscaled).
	map_root.position = centering_offset

func _center_map_in_playfield() -> void:
	# Deprecated by _fit_map_to_playfield but kept for safety if called elsewhere
	var view_size = get_viewport().get_visible_rect().size
	var playfield_x = LEFT_SIDEBAR_WIDTH + OUTER_MARGIN
	var playfield_y = TOP_BAR_HEIGHT + OUTER_MARGIN
	var playfield_w = view_size.x - LEFT_SIDEBAR_WIDTH - RIGHT_SIDEBAR_WIDTH - (OUTER_MARGIN * 2)
	var playfield_h = view_size.y - TOP_BAR_HEIGHT - (OUTER_MARGIN * 2)
	_fit_map_to_playfield(Rect2(playfield_x, playfield_y, playfield_w, playfield_h))

func _refresh_start_wave_ui() -> void:
	if not game_hud or not wave_manager: return
	
	if wave_manager.has_next_wave():
		game_hud.update_start_wave_button(
			wave_manager.get_next_wave_number(),
			wave_manager.get_total_waves(),
			wave_manager.get_next_wave_name()
		)
		var can_start = not wave_manager.is_wave_running and current_state == GameState.PLAYING
		game_hud.set_start_wave_enabled(can_start)
	else:
		game_hud.update_start_wave_button(0, wave_manager.get_total_waves(), "")
		game_hud.set_start_wave_enabled(false)

func _setup_game_from_level() -> void:
	if level_manager == null: return
	
	# Clear existing gameplay state
	_clear_gameplay_state()
	
	if map_visual_layer:
		map_visual_layer.setup(level_manager)
		
	if path_visual:
		path_visual.points = level_manager.get_path_points()
		
	# Center the map inside the playfield area
	_center_map_in_playfield()
	
	if enemy_path:
		enemy_path.curve = _create_curve_from_points(level_manager.get_path_points())
	
	if wave_manager:
		wave_manager.setup(enemy_path)
		wave_manager.load_waves_from_file(level_manager.waves_path)
		wave_manager.reset_waves()
	
	if build_manager:
		build_manager.configure_from_level(level_manager)
		build_manager.reset_build_state()
	
	if game_manager:
		game_manager.apply_level_config(level_manager.starting_gold, level_manager.starting_lives)
		game_manager.reset_runtime_state()
		
		# User requested specific log format
		print("START LEVEL ", level_manager.level_id, " money ", game_manager.gold, " hp ", game_manager.lives)
	
	if game_hud:
		game_hud.set_level_name(level_manager.level_name)
		
	update_hud()
	
	if build_preview:
		build_preview.setup(level_manager.grid_size, level_manager.grid_cols, level_manager.grid_rows)
		build_preview.set_blocked_cells(level_manager.get_all_blocked_cells())

func _create_curve_from_points(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	for point in points:
		curve.add_point(point)
	return curve

func update_hud() -> void:
	_refresh_hud_stats()
	_refresh_start_wave_ui()

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
	level_manager = get_node_or_null("LevelManager")
	map_visual_layer = get_node_or_null("MapVisualLayer")
	
	if level_manager == null:
		level_manager = Node.new()
		level_manager.name = "LevelManager"
		level_manager.set_script(LEVEL_MANAGER_SCRIPT)
		add_child(level_manager)
		
	if map_visual_layer == null:
		map_visual_layer = Node2D.new()
		map_visual_layer.name = "MapVisualLayer"
		map_visual_layer.set_script(MAP_VISUAL_LAYER_SCRIPT)
		if map_root:
			map_root.add_child(map_visual_layer)
			map_root.move_child(map_visual_layer, 0) # Behind path, etc.
		elif world_root:
			world_root.add_child(map_visual_layer)
			world_root.move_child(map_visual_layer, 0)
		else:
			add_child(map_visual_layer)

func _connect_signals() -> void:
	if main_menu:
		main_menu.start_pressed.connect(func(): start_game("res://data/levels/level_01.json"))
		main_menu.level_select_pressed.connect(_on_level_select_requested)
		main_menu.quit_pressed.connect(func(): get_tree().quit())
	
	if level_select:
		level_select.level_selected.connect(start_game)
		level_select.back_pressed.connect(_on_level_select_back)
		
	if game_hud:
		game_hud.start_wave_requested.connect(_on_start_wave_requested)
		game_hud.tower_build_selected.connect(_on_tower_build_selected)
		game_hud.cancel_build_requested.connect(_on_cancel_build_requested)
		game_hud.pause_requested.connect(_on_pause_requested)
		game_hud.restart_requested.connect(restart_level)
		game_hud.upgrade_tower_requested.connect(_on_upgrade_tower_requested)
		game_hud.deselect_tower_requested.connect(_deselect_tower)
		game_hud.target_mode_changed.connect(_on_target_mode_changed)
		game_hud.main_menu_requested.connect(return_to_menu)
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

func _process(_delta: float) -> void:
	if current_state != GameState.PLAYING: return
	
	if build_manager and build_manager.is_build_mode_active():
		var local_mouse = map_root.to_local(get_global_mouse_position())
		var cell: Vector2i = build_manager.local_to_cell(local_mouse)
		
		if debug_coordinates and Engine.get_frames_drawn() % 60 == 0:
			if OS.is_debug_build(): print("[Debug] Mouse: global=", get_global_mouse_position(), " map_local=", local_mouse, " cell=", cell)
		
		if build_preview:
			var validation = build_manager.validate_placement(cell)
			build_preview.update_preview(cell, validation["is_valid"], true, build_manager.get_selected_tower_range(), validation["reason"])
	elif build_preview:
		build_preview.update_preview(Vector2i(-1, -1), false, false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_toggle_debug_panel()
			get_viewport().set_input_as_handled()
			return

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
	if current_state != GameState.PLAYING and current_state != GameState.PAUSED: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if build_manager and build_manager.has_selected_tower():
				build_manager.clear_selected_tower()
			elif selected_tower:
				_deselect_tower()
			elif current_state == GameState.PLAYING:
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

	if current_state != GameState.PLAYING: return
	
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
				# Try place tower using local coordinates
				if build_manager.try_place_tower(local_mouse):
					get_viewport().set_input_as_handled()
					return
			else:
				# Manually check for tower selection if not in build mode
				var tower_clicked = _check_tower_click(local_mouse)
				if not tower_clicked:
					_deselect_tower()

# --- Session Flow ---

func return_to_menu() -> void:
	current_state = GameState.MENU
	_resume_game()
	_clear_gameplay_state()
	
	if main_menu: main_menu.show_menu()
	if level_select: 
		level_select.update_ui(save_manager)
		level_select.hide_select()
	if game_hud: game_hud.hide_hud()
	
	if world_root: world_root.hide()
	
	if audio_manager:
		audio_manager.play_music("menu")

func _on_level_select_requested() -> void:
	current_state = GameState.LEVEL_SELECT
	if main_menu: main_menu.hide_menu()
	if level_select: 
		level_select.update_ui(save_manager)
		level_select.show_select()
	_play_ui_click()

func _on_level_select_back() -> void:
	current_state = GameState.MENU
	if level_select: level_select.hide_select()
	if main_menu: main_menu.show_menu()
	_play_ui_click()

func start_game(level_path: String) -> void:
	start_level(level_path)

func start_level(level_path: String) -> void:
	current_level_path = level_path
	current_state = GameState.PLAYING
	
	# STANDARD: Ensure engine is unpaused when starting a level
	get_tree().paused = false
	if game_manager: game_manager.is_paused = false
	
	if OS.is_debug_build(): print("[Main] start_level: ", level_path)
	
	if main_menu: main_menu.hide_menu()
	if level_select: level_select.hide_select()
	if game_hud: 
		game_hud.show_hud()
		game_hud.hide_center_message()
		game_hud.hide_tower_info()
		game_hud.set_status("Ready")
		game_hud.set_build_status("None")
	
	if world_root: world_root.show()
	
	_clear_gameplay_state()
	
	if level_manager:
		if level_manager.load_level(level_path):
			current_level_id = level_manager.level_id
			_setup_game_from_level()
		else:
			push_error("Failed to load level: " + level_path)
			return_to_menu()
			return
	
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
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
		
	_deselect_tower()
	if build_manager:
		build_manager.reset_build_state()

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

func _on_game_paused() -> void:
	current_state = GameState.PAUSED
	if game_hud:
		game_hud.set_paused(true)

func _on_game_resumed() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
	if game_hud:
		game_hud.set_paused(false)

func _on_tower_build_selected(tower_id: String) -> void:
	if current_state != GameState.PLAYING: return
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
	if current_state != GameState.PLAYING: return
	if build_manager and build_manager.has_selected_tower(): return 
	_select_tower(tower)
	_play_ui_click()

func _select_tower(tower: Node2D) -> void:
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
	if current_state != GameState.PLAYING: return
	if selected_tower == null or not selected_tower.can_upgrade(): return
	var cost = selected_tower.get_upgrade_cost()
	if game_manager and game_manager.spend_gold(cost):
		selected_tower.upgrade()
		game_hud.show_tower_info(selected_tower.get_info())
		game_hud.set_build_status("Tower Upgraded!")
		if audio_manager:
			audio_manager.play_sfx("tower_upgrade")
	elif game_hud:
		game_hud.set_build_status("Not enough gold!")

func _on_target_mode_changed(mode: String) -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return
	if selected_tower.has_method("set_target_mode"):
		selected_tower.set_target_mode(mode)
		game_hud.show_tower_info(selected_tower.get_info())
	_play_ui_click()

func _on_start_wave_requested() -> void:
	if current_state != GameState.PLAYING: return
	if audio_manager: audio_manager.unlock_audio()
	if wave_manager:
		wave_manager.start_next_wave()
	if audio_manager:
		audio_manager.play_sfx("start_wave")

func _on_cancel_build_requested() -> void:
	if build_manager:
		build_manager.clear_selected_tower()
	_play_ui_click()

func _on_tower_selected(_tower_id: String) -> void:
	if build_manager:
		var config = build_manager.get_selected_tower_config()
		var tower_name = config.get("name", _tower_id.capitalize())
		if game_hud:
			game_hud.set_build_status("Selected: " + tower_name)

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
			build_preview.update_preview(cell, is_valid, true, tower_range)
		if build_manager.has_selected_tower() and game_hud:
			game_hud.set_build_status("Hover: " + str(cell) + " " + reason)

func _on_wave_started(wave_number: int, wave_name: String) -> void:
	if game_manager:
		game_manager.set_current_wave(wave_number)
	if game_hud:
		game_hud.set_start_wave_enabled(false)
		game_hud.set_status("Wave %d: %s" % [wave_number, wave_name])
		show_wave_feedback("Wave %d: %s" % [wave_number, wave_name], Color(1, 0.8, 0.2))

func _on_wave_completed(wave_number: int, wave_name: String, reward: int) -> void:
	if current_state == GameState.PLAYING:
		game_manager.award_wave_completion(reward)
		if game_hud:
			game_hud.set_status("Wave %d cleared! +%d Gold" % [wave_number, reward])
			show_wave_feedback("Wave Cleared! +%d Gold" % reward, Color(0.2, 1.0, 0.4))
		_refresh_start_wave_ui()
		if audio_manager:
			audio_manager.play_sfx("gold_gain")

func _on_all_waves_completed() -> void:
	if game_manager:
		game_manager.trigger_victory()
	_refresh_start_wave_ui()

func _on_enemy_killed(reward_gold: int) -> void:
	if game_manager:
		game_manager.add_kill_score(reward_gold)
		game_manager.add_gold(reward_gold)
	if audio_manager:
		audio_manager.play_sfx("enemy_die")

func _on_base_damaged(base_damage: int, global_pos: Vector2) -> void:
	if game_manager:
		game_manager.damage_base(base_damage)
	
	shake_camera(12.0, 0.3)
	
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
	current_state = GameState.GAME_OVER
	
	clear_selected_tower()
	if build_manager and build_manager.has_method("cancel_build_mode"):
		build_manager.cancel_build_mode()
		
	var summary = game_manager.get_run_summary()
	if game_hud:
		game_hud.show_run_summary(summary)
		
	_refresh_start_wave_ui()
	if audio_manager:
		audio_manager.play_sfx("game_over")

func _on_victory() -> void:
	current_state = GameState.VICTORY
	
	clear_selected_tower()
	if build_manager and build_manager.has_method("cancel_build_mode"):
		build_manager.cancel_build_mode()

	var summary = game_manager.get_run_summary()
	
	# Save progress
	if save_manager and level_manager:
		save_manager.update_level_record(level_manager.level_id, summary)
		if level_select: level_select.update_ui(save_manager)
		
	if game_hud:
		game_hud.show_run_summary(summary)
		
	_refresh_start_wave_ui()
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
