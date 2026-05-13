extends RefCounted
class_name WaveFlowController

var auto_next_wave_service: RefCounted = null
var wave_manager: Node = null
var build_state: int = 0
var wave_complete_state: int = 0
var paused_state: int = 0
var get_current_state: Callable
var has_pending_element_pick: Callable
var is_tree_paused: Callable
var refresh_start_wave_ui: Callable
var start_wave_requested: Callable

func bind(deps: Dictionary) -> void:
	auto_next_wave_service = deps.get("auto_next_wave_service") as RefCounted
	wave_manager = deps.get("wave_manager") as Node
	build_state = int(deps.get("build_state", 0))
	wave_complete_state = int(deps.get("wave_complete_state", 0))
	paused_state = int(deps.get("paused_state", 0))
	get_current_state = deps.get("get_current_state", Callable())
	has_pending_element_pick = deps.get("has_pending_element_pick", Callable())
	is_tree_paused = deps.get("is_tree_paused", Callable())
	refresh_start_wave_ui = deps.get("refresh_start_wave_ui", Callable())
	start_wave_requested = deps.get("start_wave_requested", Callable())

func is_waiting_for_manual_first_wave() -> bool:
	if auto_next_wave_service == null or wave_manager == null:
		return false
	return auto_next_wave_service.is_waiting_for_manual_first_wave(
		wave_manager.get_next_wave_number(),
		wave_manager.is_wave_running
	)

func can_auto_next_wave_countdown() -> bool:
	var current_state: int = int(get_current_state.call()) if get_current_state.is_valid() else -1
	if current_state != build_state and current_state != wave_complete_state:
		return false
	if wave_manager == null or wave_manager.is_wave_running or not wave_manager.has_next_wave():
		return false
	if has_pending_element_pick.is_valid() and bool(has_pending_element_pick.call()):
		return false
	return true

func maybe_start_auto_next_wave_countdown() -> void:
	if auto_next_wave_service == null:
		return
	auto_next_wave_service.maybe_start_countdown(
		can_auto_next_wave_countdown(),
		is_waiting_for_manual_first_wave()
	)
	_call_refresh_start_wave_ui()

func stop_auto_next_wave_countdown() -> void:
	if auto_next_wave_service:
		auto_next_wave_service.stop_countdown()
	_call_refresh_start_wave_ui()

func update_auto_next_wave_countdown(delta: float) -> void:
	if auto_next_wave_service == null:
		return
	var current_state: int = int(get_current_state.call()) if get_current_state.is_valid() else -1
	var paused := false
	if is_tree_paused.is_valid():
		paused = bool(is_tree_paused.call())
	var pending_pick := false
	if has_pending_element_pick.is_valid():
		pending_pick = bool(has_pending_element_pick.call())
	var should_start: bool = bool(auto_next_wave_service.tick(
		delta,
		can_auto_next_wave_countdown(),
		paused or pending_pick or current_state == paused_state
	))
	if should_start:
		if start_wave_requested.is_valid():
			start_wave_requested.call()
	else:
		_call_refresh_start_wave_ui()

func _call_refresh_start_wave_ui() -> void:
	if refresh_start_wave_ui.is_valid():
		refresh_start_wave_ui.call()
