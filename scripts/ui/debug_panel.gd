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

@onready var panel: PanelContainer = $Root/Panel
@onready var info_label: Label = $Root/Panel/MarginContainer/Scroll/Content/InfoLabel
@onready var god_mode_check: CheckBox = $Root/Panel/MarginContainer/Scroll/Content/GodModeCheck

var game_manager: Node = null
var wave_manager: Node = null
var tower_container: Node2D = null
var projectile_container: Node2D = null

signal level_load_requested(path: String)

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")
	tower_container = get_tree().current_scene.get_node_or_null("WorldRoot/TowerContainer")
	projectile_container = get_tree().current_scene.get_node_or_null("WorldRoot/ProjectileContainer")
	
	_add_level_debug_buttons()
	_connect_buttons()
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)

func _add_level_debug_buttons() -> void:
	var root = $Root/Panel/MarginContainer/Scroll/Content
	
	var label = Label.new()
	label.text = "LEVELS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	root.add_child(label)
	
	var grid = GridContainer.new()
	grid.columns = 3
	root.add_child(grid)
	
	for i in range(1, 4):
		var btn = Button.new()
		btn.text = "L%d" % i
		btn.custom_minimum_size = Vector2(40, 30)
		btn.pressed.connect(func(): level_load_requested.emit("res://data/levels/level_0%d.json" % i))
		grid.add_child(btn)
	
	var sep = HSeparator.new()
	root.add_child(sep)

func _connect_buttons() -> void:
	var root = $Root/Panel/MarginContainer/Scroll/Content
	root.get_node("Gold100").pressed.connect(func(): add_gold_requested.emit(100))
	root.get_node("Gold500").pressed.connect(func(): add_gold_requested.emit(500))
	root.get_node("StartWave").pressed.connect(func(): start_next_wave_requested.emit())
	root.get_node("KillAll").pressed.connect(func(): kill_all_enemies_requested.emit())
	root.get_node("ClearProj").pressed.connect(func(): clear_projectiles_requested.emit())
	root.get_node("Victory").pressed.connect(func(): trigger_victory_requested.emit())
	root.get_node("GameOver").pressed.connect(func(): trigger_game_over_requested.emit())
	root.get_node("Restart").pressed.connect(func(): restart_requested.emit())
	god_mode_check.toggled.connect(func(v): god_mode_toggled.emit(v))
	root.get_node("HardAudioTest").pressed.connect(func(): hard_audio_test_requested.emit())
	root.get_node("AudioTests/TestSfx").pressed.connect(func(): test_sfx_requested.emit())
	root.get_node("AudioTests/TestMusic").pressed.connect(func(): test_music_requested.emit())
	root.get_node("TestSfxMaster").pressed.connect(func(): test_sfx_master_requested.emit())

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
