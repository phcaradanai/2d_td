extends RefCounted
class_name ElementalPickController

# Stage 5O-1 skeleton.
# Owns Element TD pick-related dependencies before moving logic out of main.gd.
# Keep this class side-effect-light for now: bind dependencies, expose safe accessors,
# and let later stages move one behavior at a time.

var main: Node = null
var game_hud: Node = null
var build_manager: Node = null
var element_progression_manager: Node = null
var hud_state_presenter: RefCounted = null
var interest_service: RefCounted = null

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
	if interest_service == null or not interest_service.has_method("can_choose_upgrade"):
		return false
	return bool(interest_service.call("can_choose_upgrade"))

func format_interest_rate_percent() -> String:
	if interest_service != null and interest_service.has_method("format_rate_percent"):
		return str(interest_service.call("format_rate_percent"))
	return ""

func format_next_interest_rate_percent() -> String:
	if interest_service != null and interest_service.has_method("format_next_rate_percent"):
		return str(interest_service.call("format_next_rate_percent"))
	return ""

func set_build_status(message: String) -> void:
	if hud_state_presenter != null and hud_state_presenter.has_method("set_build_status"):
		hud_state_presenter.call("set_build_status", message)
	elif game_hud != null and game_hud.has_method("set_build_status"):
		game_hud.call("set_build_status", message)
