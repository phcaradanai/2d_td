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


func get_selected_tower_info() -> Dictionary:
	var tower := get_selected_tower()
	if tower == null:
		return {}
	if not tower.has_method("get_info"):
		return {}
	var info = tower.get_info()
	if info is Dictionary:
		return info
	return {}


func can_show_selected_tower_info() -> bool:
	return game_hud != null and game_hud.has_method("show_tower_info") and not get_selected_tower_info().is_empty()


func can_hide_selected_tower_info() -> bool:
	return game_hud != null and game_hud.has_method("hide_tower_info")


func get_selected_tower_display_name() -> String:
	var info := get_selected_tower_info()
	return str(info.get("name", "Tower")) if not info.is_empty() else "Tower"


func can_upgrade_selected_tower() -> bool:
	var tower := get_selected_tower()
	if tower == null:
		return false
	if not tower.has_method("can_upgrade"):
		return false
	return bool(tower.can_upgrade())


func can_sell_selected_tower() -> bool:
	return is_instance_valid(selected_tower)


func get_selected_tower_sell_value() -> int:
	var tower := get_selected_tower()
	if tower == null:
		return 0
	if tower.has_method("get_sell_refund"):
		return int(tower.get_sell_refund())
	return 0


func get_selected_tower_upgrade_cost() -> int:
	var tower := get_selected_tower()
	if tower == null:
		return 0
	if tower.has_method("get_upgrade_cost"):
		return int(tower.get_upgrade_cost())
	return 0


func get_current_gold() -> int:
	if game_manager == null:
		return 0
	return int(game_manager.get("gold"))


func can_afford_selected_tower_upgrade() -> bool:
	if not can_upgrade_selected_tower():
		return false
	return get_current_gold() >= get_selected_tower_upgrade_cost()


func get_selected_tower_upgrade_missing_gold() -> int:
	if not can_upgrade_selected_tower():
		return 0
	return max(0, get_selected_tower_upgrade_cost() - get_current_gold())


func get_selected_tower_upgrade_preview() -> Dictionary:
	var tower := get_selected_tower()
	if tower == null:
		return {}
	if not tower.has_method("can_upgrade") or not tower.can_upgrade():
		return {}
	var info := get_selected_tower_info()
	var cost: int = get_selected_tower_upgrade_cost()
	var next_ids: Array = []
	var raw_ids = info.get("next_upgrade_ids", [])
	if raw_ids is Array:
		for entry in raw_ids:
			next_ids.append(str(entry))
	return {
		"name": str(info.get("name", "Tower")),
		"upgrade_cost": cost,
		"next_upgrade_ids": next_ids,
		"can_afford": get_current_gold() >= cost,
		"missing_gold": max(0, cost - get_current_gold()),
	}


func get_selected_tower_action_state() -> Dictionary:
	var tower := get_selected_tower()
	var info := get_selected_tower_info()
	var upgrade_cost: int = get_selected_tower_upgrade_cost()
	var current_gold: int = get_current_gold()
	var can_upgrade: bool = can_upgrade_selected_tower()
	var can_afford_upgrade: bool = can_upgrade and current_gold >= upgrade_cost
	return {
		"has_selection": tower != null,
		"name": str(info.get("name", "Tower")) if not info.is_empty() else "Tower",
		"info": info,
		"can_show_info": can_show_selected_tower_info(),
		"can_hide_info": can_hide_selected_tower_info(),
		"can_sell": can_sell_selected_tower(),
		"sell_value": get_selected_tower_sell_value(),
		"can_upgrade": can_upgrade,
		"upgrade_cost": upgrade_cost,
		"current_gold": current_gold,
		"can_afford_upgrade": can_afford_upgrade,
		"missing_gold": max(0, upgrade_cost - current_gold) if can_upgrade else 0,
		"upgrade_preview": get_selected_tower_upgrade_preview(),
	}
