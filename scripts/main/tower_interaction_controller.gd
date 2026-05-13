extends RefCounted
class_name TowerInteractionController

# Stage 5O-6A skeleton.
# Keeps tower-selection, upgrade, sell, and tower-info dependencies in one place
# before moving behavior out of main.gd one flow at a time.

var game_hud: Node = null
var build_manager: Node = null
var game_manager: Node = null
var element_progression_manager: Node = null
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
	element_progression_manager = deps.get("element_progression_manager") as Node
	selected_tower = deps.get("selected_tower") as Node2D
	hud_state_presenter = deps.get("hud_state_presenter") as RefCounted
	refresh_hud = deps.get("refresh_hud", Callable())
	refresh_tower_shop = deps.get("refresh_tower_shop", Callable())
	show_wave_feedback = deps.get("show_wave_feedback", Callable())


func clear() -> void:
	game_hud = null
	build_manager = null
	game_manager = null
	element_progression_manager = null
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


func get_selected_tower_next_upgrade_id() -> String:
	var tower := get_selected_tower()
	if tower == null:
		return ""
	if tower.has_method("get_next_upgrade_id"):
		return str(tower.get_next_upgrade_id())
	var info := get_selected_tower_info()
	var raw_next_ids = info.get("next_upgrade_ids", [])
	if raw_next_ids is Array and not raw_next_ids.is_empty():
		return str(raw_next_ids[0])
	var raw_tower_next_ids = tower.get("next_upgrade_ids")
	if raw_tower_next_ids is Array and not raw_tower_next_ids.is_empty():
		return str(raw_tower_next_ids[0])
	return ""


func get_selected_tower_next_upgrade_config() -> Dictionary:
	var next_id := get_selected_tower_next_upgrade_id()
	if next_id.is_empty() or build_manager == null:
		return {}
	var raw_config = build_manager.get("towers_config")
	if raw_config is Dictionary:
		return raw_config.get(next_id, {})
	return {}


func is_selected_tower_next_upgrade_element_unlocked() -> bool:
	var next_config := get_selected_tower_next_upgrade_config()
	if next_config.is_empty():
		return true
	if element_progression_manager == null or not element_progression_manager.has_method("can_build_tower"):
		return true
	return bool(element_progression_manager.call("can_build_tower", next_config))


func get_selected_tower_upgrade_locked_reason() -> String:
	var next_config := get_selected_tower_next_upgrade_config()
	if next_config.is_empty():
		return ""
	if is_selected_tower_next_upgrade_element_unlocked():
		return ""
	if element_progression_manager != null and element_progression_manager.has_method("get_locked_reason"):
		return str(element_progression_manager.call("get_locked_reason", next_config))
	return "Required elements are not unlocked"


func can_upgrade_selected_tower() -> bool:
	var tower := get_selected_tower()
	if tower == null:
		return false
	if not tower.has_method("can_upgrade"):
		return false
	if not bool(tower.can_upgrade()):
		return false
	return is_selected_tower_next_upgrade_element_unlocked()


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
	if not tower.has_method("can_upgrade") or not bool(tower.can_upgrade()):
		return {}
	var info := get_selected_tower_info()
	var cost: int = get_selected_tower_upgrade_cost()
	var next_id := get_selected_tower_next_upgrade_id()
	var next_config := get_selected_tower_next_upgrade_config()
	var next_ids: Array = []
	var raw_ids = info.get("next_upgrade_ids", [])
	if raw_ids is Array:
		for entry in raw_ids:
			next_ids.append(str(entry))
	elif not next_id.is_empty():
		next_ids.append(next_id)
	var locked_reason := get_selected_tower_upgrade_locked_reason()
	var element_locked := not locked_reason.is_empty()
	return {
		"name": str(info.get("name", "Tower")),
		"upgrade_cost": cost,
		"next_upgrade_id": next_id,
		"next_upgrade_ids": next_ids,
		"next_config": next_config,
		"elements": next_config.get("elements", []),
		"required_element_level": int(next_config.get("required_element_level", 0)),
		"element_locked": element_locked,
		"locked": element_locked,
		"locked_reason": locked_reason,
		"can_upgrade": not element_locked,
		"can_afford": not element_locked and get_current_gold() >= cost,
		"missing_gold": max(0, cost - get_current_gold()) if not element_locked else 0,
	}


func get_selected_tower_action_state() -> Dictionary:
	var tower := get_selected_tower()
	var info := get_selected_tower_info()
	var upgrade_cost: int = get_selected_tower_upgrade_cost()
	var current_gold: int = get_current_gold()
	var locked_reason := get_selected_tower_upgrade_locked_reason()
	var element_locked := not locked_reason.is_empty()
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
		"element_locked": element_locked,
		"locked": element_locked,
		"locked_reason": locked_reason,
		"missing_gold": max(0, upgrade_cost - current_gold) if can_upgrade else 0,
		"upgrade_preview": get_selected_tower_upgrade_preview(),
	}
