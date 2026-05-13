extends RefCounted
class_name GameplayContext

# Shared dependency container for main.gd split controllers.
# Controllers can receive one GameplayContext instead of many loose parameters.

var main: Node = null
var game_hud: Node = null
var game_manager: Node = null
var wave_manager: Node = null
var build_manager: Node = null
var level_manager: Node = null
var element_progression_manager: Node = null
var hud_state_presenter: RefCounted = null
var auto_next_wave_service: RefCounted = null
var element_td_interest_service: RefCounted = null

func bind(
	p_main: Node,
	p_game_hud: Node,
	p_game_manager: Node,
	p_wave_manager: Node,
	p_build_manager: Node,
	p_level_manager: Node,
	p_element_progression_manager: Node,
	p_hud_state_presenter: RefCounted,
	p_auto_next_wave_service: RefCounted,
	p_element_td_interest_service: RefCounted
) -> void:
	main = p_main
	game_hud = p_game_hud
	game_manager = p_game_manager
	wave_manager = p_wave_manager
	build_manager = p_build_manager
	level_manager = p_level_manager
	element_progression_manager = p_element_progression_manager
	hud_state_presenter = p_hud_state_presenter
	auto_next_wave_service = p_auto_next_wave_service
	element_td_interest_service = p_element_td_interest_service

func clear() -> void:
	main = null
	game_hud = null
	game_manager = null
	wave_manager = null
	build_manager = null
	level_manager = null
	element_progression_manager = null
	hud_state_presenter = null
	auto_next_wave_service = null
	element_td_interest_service = null

func has_gameplay_hud() -> bool:
	return game_hud != null and game_manager != null and wave_manager != null

func has_element_pick_dependencies() -> bool:
	return game_hud != null and element_progression_manager != null

func has_wave_flow_dependencies() -> bool:
	return wave_manager != null and auto_next_wave_service != null

func has_interest_dependencies() -> bool:
	return game_manager != null and element_td_interest_service != null
