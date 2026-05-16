extends RefCounted
class_name GameplayControllerBinder

const GAMEPLAY_LAYOUT_CONTROLLER_SCRIPT = preload("res://scripts/main/gameplay_layout_controller.gd")
const ELEMENTAL_PICK_CONTROLLER_SCRIPT = preload("res://scripts/main/elemental_pick_controller.gd")
const WAVE_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/main/wave_flow_controller.gd")
const TOWER_INTERACTION_CONTROLLER_SCRIPT = preload("res://scripts/main/tower_interaction_controller.gd")

# Mirror main.gd public constants explicitly inside the binder instead of reading
# script-local enums/constants through the main instance. This keeps controller
# binding stable after moving the bind code out of main.gd.
const STATE_BUILD: int = 2
const STATE_WAVE_COMPLETE: int = 4
const STATE_PAUSED: int = 5
const INTEREST_PICK_ID: String = "__interest__"
const DEFAULT_INTEREST_UPGRADE_STEP: float = 0.01
const TOP_BAR_HEIGHT: float = 68.0      # matches _apply_terminal_hud_skin top bar
const LEFT_SIDEBAR_WIDTH: float = 310.0  # matches LEFT_DRAWER_WIDTH in game_hud.gd
const RIGHT_SIDEBAR_WIDTH: float = 0.0   # right panel retired; float card is overlay
const OUTER_MARGIN: float = 0.0

var gameplay_layout_controller: RefCounted = null
var elemental_pick_controller: RefCounted = null
var wave_flow_controller: RefCounted = null
var tower_interaction_controller: RefCounted = null

func get_gameplay_layout_controller(main) -> RefCounted:
	if gameplay_layout_controller == null:
		gameplay_layout_controller = GAMEPLAY_LAYOUT_CONTROLLER_SCRIPT.new()
	gameplay_layout_controller.bind({
		"world_root": main.world_root,
		"map_root": main.map_root,
		"camera": main.camera,
		"background": main.background,
		"game_hud": main.game_hud,
		"level_manager": main.level_manager,
		"top_bar_height": TOP_BAR_HEIGHT,
		"left_sidebar_width": LEFT_SIDEBAR_WIDTH,
		"right_sidebar_width": RIGHT_SIDEBAR_WIDTH,
		"outer_margin": OUTER_MARGIN,
		"get_view_size": Callable(main, "_get_visible_viewport_size_for_layout"),
	})
	return gameplay_layout_controller

func get_elemental_pick_controller(main) -> RefCounted:
	if elemental_pick_controller == null:
		elemental_pick_controller = ELEMENTAL_PICK_CONTROLLER_SCRIPT.new()
	elemental_pick_controller.bind({
		"game_hud": main.game_hud,
		"build_manager": main.build_manager,
		"element_progression_manager": main.element_progression_manager,
		"hud_state_presenter": main.hud_state_presenter,
		"interest_service": main.element_td_interest_service,
		"interest_pick_id": INTEREST_PICK_ID,
		"default_interest_upgrade_step": DEFAULT_INTEREST_UPGRADE_STEP,
		"refresh_elemental_shop": Callable(main, "_refresh_elemental_shop"),
		"bind_hud_state_presenter": Callable(main, "_bind_hud_state_presenter"),
		"set_bound_build_status": Callable(main, "_set_bound_hud_build_status"),
		"show_pending_element_choice": Callable(main, "_show_pending_element_choice"),
		"hide_element_choice": Callable(main, "_hide_element_choice"),
		"resume_auto_next_wave_after_element_choice": Callable(main, "_resume_auto_next_wave_after_element_choice"),
		"recalculate_interest_rate": Callable(main, "_recalculate_element_td_interest_rate"),
		"show_wave_feedback": Callable(main, "show_wave_feedback"),
	})
	return elemental_pick_controller

func get_wave_flow_controller(main) -> RefCounted:
	if wave_flow_controller == null:
		wave_flow_controller = WAVE_FLOW_CONTROLLER_SCRIPT.new()
	wave_flow_controller.bind({
		"auto_next_wave_service": main.auto_next_wave_service,
		"wave_manager": main.wave_manager,
		"build_state": STATE_BUILD,
		"wave_complete_state": STATE_WAVE_COMPLETE,
		"paused_state": STATE_PAUSED,
		"get_current_state": Callable(main, "_get_current_game_state"),
		"has_pending_element_pick": Callable(main, "_has_pending_element_pick"),
		"is_tree_paused": Callable(main, "_is_tree_paused_for_wave_flow"),
		"refresh_start_wave_ui": Callable(main, "_refresh_start_wave_ui"),
		"start_wave_requested": Callable(main, "_on_start_wave_requested"),
	})
	return wave_flow_controller

func get_tower_interaction_controller(main) -> RefCounted:
	if tower_interaction_controller == null:
		tower_interaction_controller = TOWER_INTERACTION_CONTROLLER_SCRIPT.new()
	tower_interaction_controller.bind({
		"game_hud": main.game_hud,
		"build_manager": main.build_manager,
		"game_manager": main.game_manager,
		"element_progression_manager": main.element_progression_manager,
		"selected_tower": main.selected_tower,
		"hud_state_presenter": main.hud_state_presenter,
		"refresh_hud": Callable(main, "update_hud"),
		"refresh_tower_shop": Callable(main, "_refresh_elemental_shop"),
		"show_wave_feedback": Callable(main, "show_wave_feedback"),
	})
	return tower_interaction_controller
