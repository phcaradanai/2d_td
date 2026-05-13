extends RefCounted
class_name ElementalPickController

# Stage 5O-1 skeleton.
# Owns Element TD pick-related dependencies before moving logic out of main.gd.
# Keep this class side-effect-light for now: bind dependencies, expose safe accessors,
# and let later stages move one behavior at a time.

var main = null
var game_hud: Node = null
var build_manager: Node = null
var element_progression_manager: Node = null
var hud_state_presenter: RefCounted = null
var interest_service: RefCounted = null

func _init(owner: Node = null) -> void:
	if owner != null:
		main = owner

func bind(dependencies: Dictionary) -> void:
	main = dependencies.get("main") as Node
	game_hud = dependencies.get("game_hud") as Node
	build_manager = dependencies.get("build_manager") as Node
	element_progression_manager = dependencies.get("element_progression_manager") as Node
	hud_state_presenter = dependencies.get("hud_state_presenter") as RefCounted
	interest_service = dependencies.get("interest_service") as RefCounted

func clear() -> void:
	main = null
	game_hud = null
	build_manager = null
	element_progression_manager = null
	hud_state_presenter = null
	interest_service = null

func is_bound() -> bool:
	return main != null and game_hud != null and element_progression_manager != null

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
	if main != null:
		return main.element_td_interest_service != null and main.element_td_interest_service.can_choose_upgrade()
	if interest_service == null or not interest_service.has_method("can_choose_upgrade"):
		return false
	return bool(interest_service.call("can_choose_upgrade"))

func format_interest_rate_percent() -> String:
	if main != null:
		if main.element_td_interest_service:
			return main.element_td_interest_service.format_rate_percent()
		return "%.0f%%" % (ElementTDInterestService.DEFAULT_BASE_RATE * 100.0)
	if interest_service != null and interest_service.has_method("format_rate_percent"):
		return str(interest_service.call("format_rate_percent"))
	return ""

func format_next_interest_rate_percent() -> String:
	if main != null:
		if main.element_td_interest_service:
			return main.element_td_interest_service.format_next_rate_percent()
		return "%.0f%%" % ((ElementTDInterestService.DEFAULT_BASE_RATE + main.DEFAULT_INTEREST_UPGRADE_STEP) * 100.0)
	if interest_service != null and interest_service.has_method("format_next_rate_percent"):
		return str(interest_service.call("format_next_rate_percent"))
	return ""

func set_build_status(message: String) -> void:
	if hud_state_presenter != null and hud_state_presenter.has_method("set_build_status"):
		hud_state_presenter.call("set_build_status", message)
	elif game_hud != null and game_hud.has_method("set_build_status"):
		game_hud.call("set_build_status", message)

func has_pending_element_pick() -> bool:
	return main.element_progression_manager != null and main.element_progression_manager.has_method("has_pending_pick") and main.element_progression_manager.has_pending_pick()

func on_element_choice_requested(element_id: String) -> void:
	if main.element_progression_manager == null:
		return
	if element_id == main.INTEREST_PICK_ID:
		choose_interest_upgrade_pick()
		return
	if main.element_progression_manager.choose_element(element_id):
		main._refresh_elemental_shop()
		if main.game_hud:
			main._bind_hud_state_presenter()
			main.hud_state_presenter.set_build_status("Element unlocked: %s" % main.element_progression_manager.get_element_label(element_id))
			if main.element_progression_manager.pending_picks > 0:
				main._show_pending_element_choice()
			else:
				main.game_hud.hide_element_choice()
				main._resume_auto_next_wave_after_element_choice()
	else:
		if main.game_hud:
			main._bind_hud_state_presenter()
			main.hud_state_presenter.set_build_status("Cannot choose that element")

func choose_interest_upgrade_pick() -> void:
	if main.element_progression_manager == null:
		return
	if int(main.element_progression_manager.pending_picks) <= 0:
		return
	if not can_choose_interest_upgrade():
		if main.game_hud:
			main._bind_hud_state_presenter()
		main.hud_state_presenter.set_build_status("Interest upgrade is already maxed")
		return
	main.element_progression_manager.pending_picks = max(0, int(main.element_progression_manager.pending_picks) - 1)
	if main.element_td_interest_service:
		main.element_td_interest_service.apply_upgrade()
	main._recalculate_element_td_interest_rate()
	if main.element_td_interest_service:
		main.element_td_interest_service.elapsed = 0.0
	if main.game_hud:
		main._bind_hud_state_presenter()
		main.hud_state_presenter.set_build_status("Interest upgraded to %s" % format_interest_rate_percent())
		main.show_wave_feedback("Interest %s" % format_interest_rate_percent(), Color(1.0, 0.85, 0.25))
		if int(main.element_progression_manager.pending_picks) > 0:
			main._show_pending_element_choice()
		else:
			main.game_hud.hide_element_choice()
			main._resume_auto_next_wave_after_element_choice()
