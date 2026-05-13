extends RefCounted
class_name TowerInteractionController

# Stage 5O-6A skeleton.
# Keeps tower-selection, upgrade, sell, and tower-info dependencies in one place
# before moving behavior out of main.gd one flow at a time.

var game_hud: Node = null
var build_manager: Node = null
var game_manager: Node = null
var selected_tower: Node2D = null
var hud_state_presenter: RefCounted = null
var refresh_hud: Callable
var refresh_tower_shop: Callable
var show_wave_feedback: Callable


func bind(deps: Dictionary) -> void:
	clear()
	game_hud = deps.get("game_hud") as Node
	build_manager = deps.get("build_manager") as Node
	game_manager = deps.get("game_manager") as Node
	selected_tower = deps.get("selected_tower") as Node2D
	hud_state_presenter = deps.get("hud_state_presenter") as RefCounted
	refresh_hud = deps.get("refresh_hud", Callable())
	refresh_tower_shop = deps.get("refresh_tower_shop", Callable())
	show_wave_feedback = deps.get("show_wave_feedback", Callable())


func clear() -> void:
	game_hud = null
	build_manager = null
	game_manager = null
	selected_tower = null
	hud_state_presenter = null
	refresh_hud = Callable()
	refresh_tower_shop = Callable()
	show_wave_feedback = Callable()


func is_bound() -> bool:
	return build_manager != null


func has_selected_tower() -> bool:
	return is_instance_valid(selected_tower)


func set_selected_tower(tower: Node2D) -> void:
	selected_tower = tower


func clear_selected_tower() -> void:
	selected_tower = null


func get_selected_tower() -> Node2D:
	if is_instance_valid(selected_tower):
		return selected_tower
	return null


func has_refresh_hud_callback() -> bool:
	return refresh_hud.is_valid()


func has_refresh_tower_shop_callback() -> bool:
	return refresh_tower_shop.is_valid()


func has_show_wave_feedback_callback() -> bool:
	return show_wave_feedback.is_valid()
