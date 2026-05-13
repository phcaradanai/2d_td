extends RefCounted
class_name HUDStatePresenter

const DEFAULT_STATUS_COLOR: Color = Color(0.85, 0.95, 1.0)
const WARNING_STATUS_COLOR: Color = Color(1.0, 0.78, 0.25)
const SUCCESS_STATUS_COLOR: Color = Color(0.45, 1.0, 0.65)
const DANGER_STATUS_COLOR: Color = Color(1.0, 0.35, 0.35)

var hud: Node = null

func bind(target_hud: Node) -> void:
	hud = target_hud

func clear() -> void:
	hud = null

func is_bound() -> bool:
	return hud != null

func set_status(message: String, color: Color = DEFAULT_STATUS_COLOR) -> void:
	if hud == null:
		return
	if hud.has_method("set_status"):
		hud.set_status(message, color)
	elif hud.has_method("show_status"):
		hud.show_status(message, color)

func set_build_status(message: String) -> void:
	if hud == null:
		return
	_call_optional("set_build_status", [message])

func set_warning(message: String) -> void:
	set_status(message, WARNING_STATUS_COLOR)

func set_success(message: String) -> void:
	set_status(message, SUCCESS_STATUS_COLOR)

func set_danger(message: String) -> void:
	set_status(message, DANGER_STATUS_COLOR)

func refresh_core_stats(gold: int, lives: int, wave_number: int, total_waves: int) -> void:
	if hud == null:
		return
	_call_optional("update_gold", [gold])
	_call_optional("set_gold", [gold])
	_call_optional("update_lives", [lives])
	_call_optional("set_lives", [lives])
	_call_optional("update_wave", [wave_number, total_waves])
	_call_optional("set_wave", [wave_number])

func refresh_start_wave_button(
	can_start: bool,
	manual_first_wave: bool,
	countdown_active: bool,
	countdown_remaining: float,
	next_wave_number: int
) -> void:
	if hud == null:
		return

	var text := build_start_wave_button_text(
		manual_first_wave,
		countdown_active,
		countdown_remaining,
		next_wave_number
	)

	if hud.has_method("set_start_wave_button"):
		hud.set_start_wave_button(can_start, text)
		return
	if hud.has_method("set_start_wave_button_state"):
		hud.set_start_wave_button_state(can_start, text)
		return
	_call_optional("set_start_wave_enabled", [can_start])
	_call_optional("set_start_wave_text", [text])

func build_start_wave_button_text(
	manual_first_wave: bool,
	countdown_active: bool,
	countdown_remaining: float,
	next_wave_number: int
) -> String:
	if manual_first_wave:
		return "Start Wave 1"
	if countdown_active:
		return "Wave %d in %.0fs" % [next_wave_number, ceil(countdown_remaining)]
	return "Start Wave %d" % next_wave_number

func refresh_tower_shop(tower_ids: Array[String]) -> void:
	if hud == null:
		return
	if hud.has_method("refresh_tower_shop"):
		hud.refresh_tower_shop(tower_ids)

func refresh_selected_tower(tower: Node) -> void:
	if hud == null:
		return
	_call_optional("set_selected_tower", [tower])
	_call_optional("refresh_selected_tower", [tower])

func refresh_element_pick_status(pending_pick_count: int, available_elements: Array[String]) -> void:
	if hud == null:
		return
	if hud.has_method("set_element_pick_status"):
		hud.set_element_pick_status(pending_pick_count, available_elements)
		return
	if pending_pick_count > 0:
		set_warning("Choose %d element%s" % [pending_pick_count, "" if pending_pick_count == 1 else "s"])

func show_wave_feedback(message: String, color: Color = DEFAULT_STATUS_COLOR) -> void:
	if hud == null:
		return
	if hud.has_method("show_wave_feedback"):
		hud.show_wave_feedback(message, color)
		return
	set_status(message, color)

func _call_optional(method_name: StringName, args: Array = []) -> Variant:
	if hud == null or not hud.has_method(method_name):
		return null
	return hud.callv(method_name, args)
