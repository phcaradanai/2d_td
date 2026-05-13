extends RefCounted
class_name WaveFlowController

var main = null

func _init(owner: Node = null) -> void:
	main = owner

func is_waiting_for_manual_first_wave() -> bool:
	if main.auto_next_wave_service == null or main.wave_manager == null:
		return false
	return main.auto_next_wave_service.is_waiting_for_manual_first_wave(
		main.wave_manager.get_next_wave_number(),
		main.wave_manager.is_wave_running
	)

func can_auto_next_wave_countdown() -> bool:
	if main.current_state != main.GameState.BUILD and main.current_state != main.GameState.WAVE_COMPLETE:
		return false
	if main.wave_manager == null or main.wave_manager.is_wave_running or not main.wave_manager.has_next_wave():
		return false
	if main._has_pending_element_pick():
		return false
	return true

func maybe_start_auto_next_wave_countdown() -> void:
	if main.auto_next_wave_service == null:
		return
	main.auto_next_wave_service.maybe_start_countdown(
		can_auto_next_wave_countdown(),
		is_waiting_for_manual_first_wave()
	)
	main._refresh_start_wave_ui()

func stop_auto_next_wave_countdown() -> void:
	if main.auto_next_wave_service:
		main.auto_next_wave_service.stop_countdown()
	main._refresh_start_wave_ui()

func update_auto_next_wave_countdown(delta: float) -> void:
	if main.auto_next_wave_service == null:
		return
	var should_start: bool = bool(main.auto_next_wave_service.tick(
		delta,
		can_auto_next_wave_countdown(),
		main.get_tree().paused or main._has_pending_element_pick() or main.current_state == main.GameState.PAUSED
	))
	if should_start:
		main._on_start_wave_requested()
	else:
		main._refresh_start_wave_ui()
