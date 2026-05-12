extends Node

# Element TD WC3-like real-time action bridge.
# This node intentionally handles only the active WAVE state so the existing
# pre-wave build flow in main.gd remains untouched and duplicate-safe.

const GAME_STATE_BUILD := 2
const GAME_STATE_WAVE := 3
const GAME_STATE_WAVE_COMPLETE := 4
const GAME_STATE_PAUSED := 5
const GAME_STATE_GAME_OVER := 6
const GAME_STATE_VICTORY := 7

const REALTIME_BUILD_LOCKOUT_SEC := 0.45
const REALTIME_UPGRADE_LOCKOUT_SEC := 0.55
const DEFAULT_SELL_REFUND_RATE := 0.70

@export var realtime_build_enabled: bool = true
@export var realtime_upgrade_enabled: bool = true
@export var realtime_sell_enabled: bool = true
@export var select_radius: float = 36.0

var main: Node = null
var game_manager: Node = null
var build_manager: Node = null
var game_hud: Node = null
var tower_container: Node2D = null
var selected_tower: Node2D = null
var _handling_hud_action: bool = false
var _last_upgrade_press_msec: int = 0
var _last_sell_press_msec: int = 0

func _ready() -> void:
	main = get_tree().current_scene
	if main == null:
		return
	game_manager = main.get_node_or_null("GameManager")
	build_manager = main.get_node_or_null("BuildManager")
	game_hud = main.get_node_or_null("GameHUD")
	tower_container = main.get_node_or_null("WorldRoot/MapRoot/TowerContainer") as Node2D
	set_process(true)
	set_process_unhandled_input(true)
	call_deferred("_connect_runtime_signals")

func _process(_delta: float) -> void:
	if _is_wave_realtime_window():
		_sync_realtime_hud_controls()

func _connect_runtime_signals() -> void:
	_connect_signal(game_hud, "tower_build_selected", Callable(self, "_on_tower_build_selected"))
	_connect_signal(game_hud, "cancel_build_requested", Callable(self, "_on_cancel_build_requested"))
	_connect_signal(game_hud, "upgrade_tower_requested", Callable(self, "_on_upgrade_tower_requested"))
	_connect_signal(game_hud, "branch_upgrade_requested", Callable(self, "_on_branch_upgrade_requested"))
	_connect_signal(game_hud, "sell_tower_requested", Callable(self, "_on_sell_tower_requested"))
	_connect_signal(game_hud, "deselect_tower_requested", Callable(self, "_on_deselect_tower_requested"))
	_connect_signal(build_manager, "tower_placed", Callable(self, "_on_tower_placed"))
	_connect_hud_button_press("upgrade_tower_button", Callable(self, "_on_upgrade_button_pressed_direct"))
	_connect_hud_button_press("sell_tower_button", Callable(self, "_on_sell_button_pressed_direct"))
	_connect_hud_button_press("deselect_tower_button", Callable(self, "_on_deselect_button_pressed_direct"))

func _connect_signal(source: Object, signal_name: String, callable: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callable):
		return
	source.connect(signal_name, callable)

func _connect_hud_button_press(property_name: String, callable: Callable) -> void:
	if game_hud == null:
		return
	var control = game_hud.get(property_name)
	if control is BaseButton and is_instance_valid(control):
		_connect_signal(control, "pressed", callable)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_wave_realtime_window():
		return
	if build_manager == null:
		return

	if event is InputEventMouseMotion:
		if _has_selected_build_tower() and build_manager.has_method("update_hover"):
			build_manager.update_hover(_get_tower_container_mouse_position())
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if _has_selected_build_tower():
				_clear_build_selection()
				get_viewport().set_input_as_handled()
				return
			if _get_selected_tower() != null:
				_clear_tower_selection()
				get_viewport().set_input_as_handled()
				return

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if _has_selected_build_tower():
			var placed := build_manager.try_place_tower(_get_tower_container_mouse_position())
			if placed:
				_refresh_hud_after_economy_change()
			get_viewport().set_input_as_handled()
			return

		var clicked_tower := _find_tower_under_mouse()
		if clicked_tower != null:
			_select_tower(clicked_tower)
			get_viewport().set_input_as_handled()

func _on_tower_build_selected(tower_id: String) -> void:
	if _handling_hud_action or not realtime_build_enabled or not _is_wave_realtime_window():
		return
	if build_manager == null or tower_id == "":
		return
	_handling_hud_action = true
	if build_manager.has_method("set_selected_tower"):
		build_manager.set_selected_tower(tower_id)
	_set_status("Build during wave: %s" % _format_tower_id(tower_id))
	_handling_hud_action = false

func _on_cancel_build_requested() -> void:
	if not _is_wave_realtime_window():
		return
	_clear_build_selection()

func _on_upgrade_button_pressed_direct() -> void:
	# Direct button hook fixes cases where GameHUD/Main consumes or ignores the
	# upgrade signal during WAVE before the bridge can act.
	if not _is_wave_realtime_window():
		return
	var now := Time.get_ticks_msec()
	if now - _last_upgrade_press_msec < 120:
		return
	_last_upgrade_press_msec = now
	_on_upgrade_tower_requested()

func _on_sell_button_pressed_direct() -> void:
	if not _is_wave_realtime_window():
		return
	var now := Time.get_ticks_msec()
	if now - _last_sell_press_msec < 120:
		return
	_last_sell_press_msec = now
	_on_sell_tower_requested()

func _on_deselect_button_pressed_direct() -> void:
	if _is_wave_realtime_window():
		_clear_tower_selection()

func _on_upgrade_tower_requested() -> void:
	if _handling_hud_action or not realtime_upgrade_enabled or not _is_wave_realtime_window():
		return
	_handling_hud_action = true
	_try_upgrade_selected_tower("")
	_handling_hud_action = false

func _on_branch_upgrade_requested(branch_id: String) -> void:
	if _handling_hud_action or not realtime_upgrade_enabled or not _is_wave_realtime_window():
		return
	_handling_hud_action = true
	_try_upgrade_selected_tower(branch_id)
	_handling_hud_action = false

func _on_sell_tower_requested() -> void:
	if _handling_hud_action or not realtime_sell_enabled or not _is_wave_realtime_window():
		return
	_handling_hud_action = true
	_try_sell_selected_tower()
	_handling_hud_action = false

func _on_deselect_tower_requested() -> void:
	if not _is_wave_realtime_window():
		return
	_clear_tower_selection()

func _on_tower_placed(tower: Node2D, tower_id: String, _cost: int) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	# WC3-like build timing: towers placed mid-wave should not fire on the exact
	# same frame they appear. This gives real-time building pressure without
	# needing a full construction animation pass yet.
	_apply_short_fire_lockout(tower, REALTIME_BUILD_LOCKOUT_SEC)
	if _is_wave_realtime_window():
		_set_status("Built %s" % _format_tower_id(tower_id))
		_refresh_hud_after_economy_change()

func _is_wave_realtime_window() -> bool:
	if not realtime_build_enabled and not realtime_upgrade_enabled and not realtime_sell_enabled:
		return false
	if main == null or get_tree().paused:
		return false
	var state := int(main.get("current_state"))
	if state == GAME_STATE_PAUSED or state == GAME_STATE_GAME_OVER or state == GAME_STATE_VICTORY:
		return false
	return state == GAME_STATE_WAVE

func _sync_realtime_hud_controls() -> void:
	if game_hud == null:
		return

	# Some existing UI paths disable build/upgrade controls during WAVE. Element TD
	# expects these actions to stay available, while the actual validators still
	# reject invalid/too-expensive actions.
	var dynamic_buttons = game_hud.get("dynamic_tower_buttons")
	if dynamic_buttons is Dictionary:
		for tower_id in dynamic_buttons.keys():
			var button = dynamic_buttons[tower_id]
			if button is Button and is_instance_valid(button):
				button.disabled = false

	for property_name in ["upgrade_tower_button", "sell_tower_button", "deselect_tower_button", "cancel_build_button"]:
		var control = game_hud.get(property_name)
		if control is BaseButton and is_instance_valid(control):
			control.disabled = false

	var target_mode_control = game_hud.get("target_mode_option_button")
	if target_mode_control is OptionButton and is_instance_valid(target_mode_control):
		target_mode_control.disabled = false

func _has_selected_build_tower() -> bool:
	return build_manager != null and build_manager.has_method("has_selected_tower") and bool(build_manager.has_selected_tower())

func _clear_build_selection() -> void:
	if build_manager != null and build_manager.has_method("clear_selected_tower"):
		build_manager.clear_selected_tower()
	_set_status("Build cancelled")

func _get_tower_container_mouse_position() -> Vector2:
	if tower_container == null:
		return Vector2.ZERO
	return tower_container.to_local(tower_container.get_global_mouse_position())

func _find_tower_under_mouse() -> Node2D:
	if tower_container == null:
		return null
	var local_pos := _get_tower_container_mouse_position()
	if build_manager != null and build_manager.has_method("local_to_cell") and build_manager.has_method("get_tower_at_cell"):
		var cell: Vector2i = build_manager.local_to_cell(local_pos)
		var cell_tower = build_manager.get_tower_at_cell(cell)
		if cell_tower is Node2D and is_instance_valid(cell_tower):
			return cell_tower

	var best_tower: Node2D = null
	var best_distance := select_radius
	for node in get_tree().get_nodes_in_group("placed_towers"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var tower := node as Node2D
		var dist := tower.position.distance_to(local_pos)
		if dist <= best_distance:
			best_distance = dist
			best_tower = tower
	return best_tower

func _select_tower(tower: Node2D) -> void:
	if tower == null or not is_instance_valid(tower):
		return

	# Ask main.gd to do its normal selection work first when available, but do
	# not trust it during WAVE because the legacy flow can ignore tower clicks.
	for method_name in ["_on_tower_clicked", "_select_tower", "select_tower"]:
		if main != null and main.has_method(method_name):
			main.call(method_name, tower)
			break

	# Force the canonical selected tower for real-time upgrade/sell actions.
	_clear_tower_visual_selection_only()
	selected_tower = tower
	if main != null:
		main.set("selected_tower", tower)
	_set_tower_selected(tower, true)
	_update_tower_panel(tower)
	_set_status("Selected %s" % str(tower.get("display_name")))

func _clear_tower_selection() -> void:
	_clear_tower_visual_selection_only()
	selected_tower = null
	if main != null:
		main.set("selected_tower", null)
	if game_hud != null:
		for method_name in ["hide_tower_info", "clear_tower_info", "hide_selected_tower"]:
			if game_hud.has_method(method_name):
				game_hud.call(method_name)
				break
	_set_status("Tower deselected")

func _clear_tower_visual_selection_only() -> void:
	var current := _get_selected_tower()
	if current != null and is_instance_valid(current):
		_set_tower_selected(current, false)

func _get_selected_tower() -> Node2D:
	if main != null:
		var main_selected = main.get("selected_tower")
		if main_selected is Node2D and is_instance_valid(main_selected):
			return main_selected
	if selected_tower != null and is_instance_valid(selected_tower):
		return selected_tower
	return null

func _set_tower_selected(tower: Node2D, value: bool) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	if tower.has_method("set_selected"):
		tower.call("set_selected", value)
	else:
		tower.set("is_selected", value)
		if tower.has_method("queue_redraw"):
			tower.queue_redraw()

func _update_tower_panel(tower: Node2D) -> void:
	if game_hud == null or tower == null:
		return
	for method_name in ["show_tower_info", "show_tower_details", "update_tower_info", "set_selected_tower"]:
		if game_hud.has_method(method_name):
			game_hud.call(method_name, tower)
			return

func _try_upgrade_selected_tower(branch_id: String) -> bool:
	var tower := _get_selected_tower()
	if tower == null:
		_set_status("Select a tower to upgrade")
		return false

	var upgrade_id := _pick_upgrade_id(tower, branch_id)
	if upgrade_id == "":
		_set_status("No upgrade available")
		return false

	var upgrade_config := _get_tower_config(upgrade_id)
	if upgrade_config.is_empty():
		_set_status("Upgrade config missing: %s" % upgrade_id)
		return false

	if not _is_upgrade_unlocked(upgrade_id, upgrade_config):
		_set_status("Need matching element level for %s" % _format_tower_id(upgrade_id))
		return false

	var cost := int(upgrade_config.get("upgrade_cost", upgrade_config.get("cost", 0)))
	if cost <= 0:
		cost = int(upgrade_config.get("cost", 0))
	if game_manager == null or not game_manager.has_method("spend_gold"):
		_set_status("Game manager missing")
		return false
	if not game_manager.spend_gold(cost):
		_set_status("Not enough gold for upgrade: %d" % cost)
		return false

	_apply_upgrade_config_to_tower(tower, upgrade_config, cost)
	_apply_short_fire_lockout(tower, REALTIME_UPGRADE_LOCKOUT_SEC)
	_update_tower_panel(tower)
	_refresh_hud_after_economy_change()
	_set_status("Upgraded to %s" % str(upgrade_config.get("display_name", upgrade_config.get("name", upgrade_id))))
	return true

func _pick_upgrade_id(tower: Node2D, branch_id: String) -> String:
	var raw_upgrades = tower.get("next_upgrade_ids")
	var options: Array[String] = []
	if raw_upgrades is Array:
		for raw in raw_upgrades:
			var id := str(raw)
			if id != "":
				options.append(id)
	if options.is_empty():
		return ""
	if branch_id == "" and options.size() == 1:
		return options[0]

	for id in options:
		var cfg := _get_tower_config(id)
		if id == branch_id or str(cfg.get("branch_id", "")) == branch_id:
			return id
	if branch_id == "" and options.size() > 1:
		_set_status("Choose an upgrade branch")
	return ""

func _get_tower_config(tower_id: String) -> Dictionary:
	if build_manager == null or tower_id == "":
		return {}
	var merged = build_manager.get("towers_config")
	if merged is Dictionary and merged.has(tower_id):
		return (merged[tower_id] as Dictionary).duplicate(true)
	var tree = build_manager.get("towers_tree_config")
	if tree is Dictionary and tree.has(tower_id):
		return (tree[tower_id] as Dictionary).duplicate(true)
	return {}

func _is_upgrade_unlocked(upgrade_id: String, upgrade_config: Dictionary) -> bool:
	if build_manager != null and build_manager.has_method("is_tower_unlocked"):
		return bool(build_manager.is_tower_unlocked(upgrade_id))
	return int(upgrade_config.get("required_element_level", 0)) <= 0

func _apply_upgrade_config_to_tower(tower: Node2D, upgrade_config: Dictionary, upgrade_cost: int) -> void:
	var previous_invested := _get_tower_invested_gold(tower)
	var cell := _get_tower_cell(tower)

	for method_name in ["upgrade_to_config", "upgrade_to", "apply_upgrade_config"]:
		if tower.has_method(method_name):
			tower.call(method_name, upgrade_config)
			tower.set("total_invested_gold", previous_invested + upgrade_cost)
			return

	# Fallback: Tower.setup already exists and applies all current tower stats.
	if tower.has_method("setup"):
		tower.call("setup", upgrade_config, cell)
		tower.set("total_invested_gold", previous_invested + upgrade_cost)
		if tower.has_method("set_projectile_container") and main != null:
			var projectiles := main.get_node_or_null("WorldRoot/MapRoot/ProjectileContainer")
			if projectiles != null:
				tower.call("set_projectile_container", projectiles)

func _try_sell_selected_tower() -> bool:
	var tower := _get_selected_tower()
	if tower == null:
		_set_status("Select a tower to sell")
		return false
	if build_manager == null or not build_manager.has_method("remove_tower_at_cell"):
		_set_status("Build manager cannot sell towers")
		return false

	var cell := _get_tower_cell(tower)
	var refund := _get_sell_refund(tower)
	var sold := bool(build_manager.remove_tower_at_cell(cell))
	if not sold:
		_set_status("Sell failed")
		return false
	if game_manager != null and game_manager.has_method("add_gold") and refund > 0:
		game_manager.add_gold(refund)
	_clear_tower_selection()
	_refresh_hud_after_economy_change()
	_set_status("Sold tower +%d" % refund)
	return true

func _get_tower_cell(tower: Node2D) -> Vector2i:
	if tower != null and tower.has_method("get_grid_cell"):
		return tower.call("get_grid_cell")
	var raw_cell = tower.get("grid_cell") if tower != null else null
	if raw_cell is Vector2i:
		return raw_cell
	if build_manager != null and build_manager.has_method("local_to_cell") and tower != null:
		return build_manager.local_to_cell(tower.position)
	return Vector2i.ZERO

func _get_tower_invested_gold(tower: Node2D) -> int:
	if tower == null:
		return 0
	var invested = tower.get("total_invested_gold")
	if invested == null:
		invested = tower.get("cost")
	return max(0, int(invested))

func _get_sell_refund(tower: Node2D) -> int:
	if tower == null:
		return 0
	if tower.has_method("get_sell_refund_amount"):
		return int(tower.call("get_sell_refund_amount"))
	if tower.has_method("get_sell_value"):
		return int(tower.call("get_sell_value"))

	var invested := _get_tower_invested_gold(tower)
	var cfg = tower.get("config")
	if cfg is Dictionary:
		var mode := str(cfg.get("sell_refund_mode", ""))
		if mode == "nearly_full":
			var loss := int(cfg.get("sell_refund_loss", 1))
			return max(0, invested - loss)
	return int(floor(float(invested) * DEFAULT_SELL_REFUND_RATE))

func _apply_short_fire_lockout(tower: Node2D, seconds: float) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	var fire_timer = tower.get("fire_timer")
	if fire_timer != null:
		tower.set("fire_timer", maxf(float(fire_timer), seconds))
	var shoot_cooldown = tower.get("shoot_cooldown")
	if shoot_cooldown != null:
		tower.set("shoot_cooldown", maxf(float(shoot_cooldown), seconds))

func _refresh_hud_after_economy_change() -> void:
	if main != null and main.has_method("update_hud"):
		main.call("update_hud")
	elif game_hud != null and game_manager != null:
		if game_hud.has_method("set_gold"):
			game_hud.call("set_gold", int(game_manager.get("gold")))
		if game_hud.has_method("set_lives"):
			game_hud.call("set_lives", int(game_manager.get("lives")))

func _set_status(message: String) -> void:
	if game_hud != null and game_hud.has_method("set_status"):
		game_hud.call("set_status", message)
	if main != null and main.has_method("show_wave_feedback"):
		main.call("show_wave_feedback", message, Color(0.45, 0.9, 1.0))

func _format_tower_id(tower_id: String) -> String:
	return tower_id.replace("_", " ").capitalize()
