extends RefCounted
class_name ElementalPickController

const DEFAULT_INTEREST_UPGRADE_STEP: float = 0.01

# Stage 5O-1 skeleton.
# Owns Element TD pick-related dependencies before moving logic out of main.gd.
# Keep this class side-effect-light for now: bind dependencies, expose safe accessors,
# and let later stages move one behavior at a time.

var game_hud: Node = null
var build_manager: Node = null
var element_progression_manager: Node = null
var hud_state_presenter: RefCounted = null
var interest_service: RefCounted = null
var interest_pick_id: String = ""
var default_interest_upgrade_step: float = DEFAULT_INTEREST_UPGRADE_STEP
var refresh_elemental_shop: Callable
var bind_hud_state_presenter: Callable
var set_bound_build_status: Callable
var show_pending_element_choice: Callable
var hide_element_choice: Callable
var resume_auto_next_wave_after_element_choice: Callable
var recalculate_interest_rate: Callable
var show_wave_feedback: Callable

func _init(owner: Node = null) -> void:
	# Transitional compatibility path for older setup code. main.gd now uses
	# explicit bind(deps); remove this once no callers pass the owner directly.
	if owner != null:
		bind({"main": owner})

func bind(dependencies: Dictionary) -> void:
	_reset_dependencies()
	if dependencies.has("main"):
		# Transitional compatibility path. Prefer explicit dependency keys below
		# so this controller does not treat main.gd as a hidden global object.
		var main = dependencies.get("main")
		game_hud = main.game_hud
		build_manager = main.build_manager
		element_progression_manager = main.element_progression_manager
		hud_state_presenter = main.hud_state_presenter
		interest_service = main.element_td_interest_service
		interest_pick_id = main.INTEREST_PICK_ID
		default_interest_upgrade_step = main.DEFAULT_INTEREST_UPGRADE_STEP
		refresh_elemental_shop = Callable(main, "_refresh_elemental_shop")
		bind_hud_state_presenter = Callable(main, "_bind_hud_state_presenter")
		set_bound_build_status = Callable(main, "_set_bound_hud_build_status")
		show_pending_element_choice = Callable(main, "_show_pending_element_choice")
		hide_element_choice = Callable(main, "_hide_element_choice")
		resume_auto_next_wave_after_element_choice = Callable(main, "_resume_auto_next_wave_after_element_choice")
		recalculate_interest_rate = Callable(main, "_recalculate_element_td_interest_rate")
		show_wave_feedback = Callable(main, "show_wave_feedback")
		return
	game_hud = dependencies.get("game_hud") as Node
	build_manager = dependencies.get("build_manager") as Node
	element_progression_manager = dependencies.get("element_progression_manager") as Node
	hud_state_presenter = dependencies.get("hud_state_presenter") as RefCounted
	interest_service = dependencies.get("interest_service") as RefCounted
	interest_pick_id = str(dependencies.get("interest_pick_id", ""))
	default_interest_upgrade_step = float(dependencies.get("default_interest_upgrade_step", DEFAULT_INTEREST_UPGRADE_STEP))
	refresh_elemental_shop = dependencies.get("refresh_elemental_shop", Callable())
	bind_hud_state_presenter = dependencies.get("bind_hud_state_presenter", Callable())
	set_bound_build_status = dependencies.get("set_bound_build_status", Callable())
	show_pending_element_choice = dependencies.get("show_pending_element_choice", Callable())
	hide_element_choice = dependencies.get("hide_element_choice", Callable())
	resume_auto_next_wave_after_element_choice = dependencies.get("resume_auto_next_wave_after_element_choice", Callable())
	recalculate_interest_rate = dependencies.get("recalculate_interest_rate", Callable())
	show_wave_feedback = dependencies.get("show_wave_feedback", Callable())

func clear() -> void:
	_reset_dependencies()

func _reset_dependencies() -> void:
	game_hud = null
	build_manager = null
	element_progression_manager = null
	hud_state_presenter = null
	interest_service = null
	interest_pick_id = ""
	default_interest_upgrade_step = DEFAULT_INTEREST_UPGRADE_STEP
	refresh_elemental_shop = Callable()
	bind_hud_state_presenter = Callable()
	set_bound_build_status = Callable()
	show_pending_element_choice = Callable()
	hide_element_choice = Callable()
	resume_auto_next_wave_after_element_choice = Callable()
	recalculate_interest_rate = Callable()
	show_wave_feedback = Callable()

func is_bound() -> bool:
	return game_hud != null and element_progression_manager != null

func has_pending_pick() -> bool:
	if element_progression_manager == null:
		return false
	if not element_progression_manager.has_method("has_pending_pick"):
		return false
	return bool(element_progression_manager.call("has_pending_pick"))

func get_pending_pick_count() -> int:
	if element_progression_manager == null:
		return 0
	var raw_value: Variant = element_progression_manager.get("pending_picks")
	if raw_value == null or typeof(raw_value) != TYPE_INT:
		return 0
	return int(raw_value)

func can_choose_interest_upgrade() -> bool:
	if interest_service == null or not interest_service.has_method("can_choose_upgrade"):
		return false
	return bool(interest_service.call("can_choose_upgrade"))

func format_interest_rate_percent() -> String:
	if interest_service != null and interest_service.has_method("format_rate_percent"):
		return str(interest_service.call("format_rate_percent"))
	return "%.0f%%" % (ElementTDInterestService.DEFAULT_BASE_RATE * 100.0)

func format_next_interest_rate_percent() -> String:
	if interest_service != null and interest_service.has_method("format_next_rate_percent"):
		return str(interest_service.call("format_next_rate_percent"))
	return "%.0f%%" % ((ElementTDInterestService.DEFAULT_BASE_RATE + default_interest_upgrade_step) * 100.0)

func set_build_status(message: String) -> void:
	if hud_state_presenter != null and hud_state_presenter.has_method("set_build_status"):
		hud_state_presenter.call("set_build_status", message)
	elif game_hud != null and game_hud.has_method("set_build_status"):
		game_hud.call("set_build_status", message)

func has_pending_element_pick() -> bool:
	return element_progression_manager != null and element_progression_manager.has_method("has_pending_pick") and element_progression_manager.has_pending_pick()

func on_element_choice_requested(option: Variant) -> void:
	if element_progression_manager == null:
		return
	var pick_option := _normalize_pick_option(option)
	var option_type := str(pick_option.get("option_type", "element"))
	var element_id := str(pick_option.get("element_id", ""))
	if option_type == "interest":
		choose_interest_upgrade_pick()
		return
	if option_type != "element" or element_id.is_empty():
		_callv(set_bound_build_status, ["Cannot choose that option"])
		return
	if element_progression_manager.choose_element(element_id):
		_callv(refresh_elemental_shop)
		if game_hud:
			_callv(bind_hud_state_presenter)
			_callv(set_bound_build_status, ["Element unlocked: %s" % element_progression_manager.get_element_label(element_id)])
			if element_progression_manager.pending_picks > 0:
				_callv(show_pending_element_choice)
			else:
				_callv(hide_element_choice)
				_callv(resume_auto_next_wave_after_element_choice)
	else:
		if game_hud:
			_callv(bind_hud_state_presenter)
			_callv(set_bound_build_status, ["Cannot choose that element"])

func _normalize_pick_option(option: Variant) -> Dictionary:
	if option is Dictionary:
		var option_type := str(option.get("option_type", "element"))
		return {
			"option_type": option_type,
			"element_id": str(option.get("element_id", "")),
		}
	var element_id := str(option)
	if element_id == interest_pick_id:
		return {
			"option_type": "interest",
			"element_id": "",
		}
	return {
		"option_type": "element",
		"element_id": element_id,
	}

func choose_interest_upgrade_pick() -> void:
	if element_progression_manager == null:
		return
	if int(element_progression_manager.pending_picks) <= 0:
		return
	if not can_choose_interest_upgrade():
		if game_hud:
			_callv(bind_hud_state_presenter)
		_callv(set_bound_build_status, ["Interest upgrade is already maxed"])
		return
	element_progression_manager.pending_picks = max(0, int(element_progression_manager.pending_picks) - 1)
	if is_instance_valid(interest_service) and interest_service.has_method("apply_upgrade"):
		interest_service.apply_upgrade()
	_callv(recalculate_interest_rate)
	if is_instance_valid(interest_service):
		interest_service.elapsed = 0.0
	if game_hud:
		_callv(bind_hud_state_presenter)
		_callv(set_bound_build_status, ["Interest upgraded to %s" % format_interest_rate_percent()])
		_callv(show_wave_feedback, ["Interest %s" % format_interest_rate_percent(), Color(1.0, 0.85, 0.25)])
		if int(element_progression_manager.pending_picks) > 0:
			_callv(show_pending_element_choice)
		else:
			_callv(hide_element_choice)
			_callv(resume_auto_next_wave_after_element_choice)

func _callv(callback: Callable, args: Array = []) -> Variant:
	if callback.is_valid():
		return callback.callv(args)
	return null
