extends Node
class_name SceneNavigationService

var go_to_main_menu: Callable
var go_to_level_select: Callable
var restart_current_level: Callable
var stop_auto_next_wave_countdown: Callable
var clear_transient_combat_ui: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind(deps: Dictionary) -> void:
	go_to_main_menu = deps.get("go_to_main_menu", Callable())
	go_to_level_select = deps.get("go_to_level_select", Callable())
	restart_current_level = deps.get("restart_current_level", Callable())
	stop_auto_next_wave_countdown = deps.get("stop_auto_next_wave_countdown", Callable())
	clear_transient_combat_ui = deps.get("clear_transient_combat_ui", Callable())

func go_to_main_menu_safe() -> void:
	_unpause_tree()
	if go_to_main_menu.is_valid():
		go_to_main_menu.call()

func go_to_level_select_safe() -> void:
	if stop_auto_next_wave_countdown.is_valid():
		stop_auto_next_wave_countdown.call()
	if clear_transient_combat_ui.is_valid():
		clear_transient_combat_ui.call()
	_unpause_tree()
	if go_to_level_select.is_valid():
		go_to_level_select.call()

func restart_current_level_safe() -> void:
	_unpause_tree()
	if restart_current_level.is_valid():
		restart_current_level.call()

func safe_change_scene(path: String) -> void:
	_unpause_tree()
	if path.strip_edges().is_empty():
		return
	get_tree().change_scene_to_file(path)

func _unpause_tree() -> void:
	get_tree().paused = false
	var main := get_tree().current_scene
	if main:
		var gm := main.get_node_or_null("GameManager")
		if gm and "is_paused" in gm:
			gm.is_paused = false
