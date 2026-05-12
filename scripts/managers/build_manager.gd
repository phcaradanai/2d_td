extends Node

signal tower_selected(tower_id: String)
signal tower_selection_cleared()
signal tower_placed(tower: Node2D, tower_id: String, cost: int)
signal placement_failed(reason: String)
signal hover_cell_changed(cell: Vector2i, is_valid: bool, reason: String)

@export var grid_size: int = 64
@export var grid_cols: int = 20
@export var grid_rows: int = 12
@export var grid_origin: Vector2 = Vector2.ZERO

@export var tower_scene: PackedScene = preload("res://scenes/towers/Tower.tscn")
@export var towers_data_path: String = "res://data/towers.json"
@export var towers_tree_data_path: String = "res://data/towers_tree.json"

var towers_config: Dictionary = {}
var towers_tree_config: Dictionary = {}
var selected_tower_id: String = ""
var occupied_cells: Dictionary = {} # cell: bool
var tower_by_cell: Dictionary = {} # cell_key: tower
var blocked_cells: Array[Vector2i] = [] # fixed road/spawn/base/non-buildable cells
var active_loadout: Array[String] = []
var unlocked_tower_ids: Array[String] = ["basic_tower_t1"]

var game_manager: Node
var level_manager: Node
var tower_container: Node2D
var projectile_container: Node2D

const DEFAULT_FOOTPRINT_RADIUS: float = 20.0
const ELEMENT_TD_ELEMENTS: Array[String] = ["light", "darkness", "water", "fire", "nature", "earth"]
const ELEMENT_TD_LABELS := {
	"light": "Light",
	"darkness": "Darkness",
	"water": "Water",
	"fire": "Fire",
	"nature": "Nature",
	"earth": "Earth"
}

func setup(p_game_manager: Node, p_tower_container: Node2D, p_projectile_container: Node2D) -> void:
	game_manager = p_game_manager
	tower_container = p_tower_container
	projectile_container = p_projectile_container
	load_towers_config()

func configure_from_level(p_level_manager: Node) -> void:
	level_manager = p_level_manager
	grid_size = level_manager.grid_size
	grid_cols = level_manager.grid_cols
	grid_rows = level_manager.grid_rows
	grid_origin = level_manager.grid_origin
	blocked_cells = level_manager.get_all_blocked_cells()

func set_pathfinding_manager(_p_pathfinding_manager: Node) -> void:
	# Compatibility shim. Element TD WC3 mode is fixed-path only, so build
	# validation is handled by level blocked/buildable cells instead of dynamic
	# maze path validation.
	pass

func load_towers_config() -> void:
	# Load tower tree config (Element TD progression system)
	if FileAccess.file_exists(towers_tree_data_path):
		var file2 = FileAccess.open(towers_tree_data_path, FileAccess.READ)
		var json_text2 = file2.get_as_text()
		file2.close()
		
		var json2 = JSON.new()
		var error2 = json2.parse(json_text2)
		if error2 == OK:
			towers_tree_config = json2.data
			# Merge into towers_config so place_tower can find all configs
			for key in towers_tree_config:
				towers_config[key] = towers_tree_config[key]
			_inject_element_td_combo_towers()
			if OS.is_debug_build(): print("Loaded tower tree: ", towers_tree_config.size(), " entries.")

func _inject_element_td_combo_towers() -> void:
	# Element TD WC3-like tower availability is combination-based.
	# The authored JSON contains starter/single/pure towers. This generated
	# layer fills temporary dual/triple combo families until the final authored
	# Element TD catalog replaces it.
	for i in range(ELEMENT_TD_ELEMENTS.size()):
		for j in range(i + 1, ELEMENT_TD_ELEMENTS.size()):
			var elements := [ELEMENT_TD_ELEMENTS[i], ELEMENT_TD_ELEMENTS[j]]
			_inject_combo_family(elements, "dual", 260 + (i * 10) + j)

	for i in range(ELEMENT_TD_ELEMENTS.size()):
		for j in range(i + 1, ELEMENT_TD_ELEMENTS.size()):
			for k in range(j + 1, ELEMENT_TD_ELEMENTS.size()):
				var elements := [ELEMENT_TD_ELEMENTS[i], ELEMENT_TD_ELEMENTS[j], ELEMENT_TD_ELEMENTS[k]]
				_inject_combo_family(elements, "triple", 520 + (i * 100) + (j * 10) + k)

func _inject_combo_family(elements: Array, combo_type: String, shop_order: int) -> void:
	var family_id := "%s_%s" % [combo_type, _combo_slug(elements)]
	var display_base := "%s Tower" % _combo_display_name(elements)
	var costs := [150, 150, 150] if combo_type == "dual" else [250, 250, 250]
	var upgrade_costs := [0, 190, 360] if combo_type == "dual" else [0, 320, 620]
	var tiers := [1, 2, 3]

	for idx in range(tiers.size()):
		var tier: int = tiers[idx]
		var tower_id := "%s_t%d" % [family_id, tier]
		if towers_config.has(tower_id):
			continue
		var next_ids: Array[String] = []
		if tier < 3:
			next_ids.append("%s_t%d" % [family_id, tier + 1])
		var cfg := _build_combo_tower_config(
			tower_id,
			display_base,
			elements,
			combo_type,
			tier,
			shop_order,
			int(costs[idx]),
			int(upgrade_costs[idx]),
			next_ids
		)
		towers_tree_config[tower_id] = cfg
		towers_config[tower_id] = cfg

func _build_combo_tower_config(tower_id: String, display_base: String, elements: Array, combo_type: String, tier: int, shop_order: int, cost: int, upgrade_cost: int, next_ids: Array[String]) -> Dictionary:
	var attack_profile := _combo_attack_profile(elements, combo_type)
	var tier_scale := 1.0 + float(tier - 1) * (0.78 if combo_type == "dual" else 0.86)
	var combo_count := elements.size()
	var base_damage := float(attack_profile.get("damage", 20.0)) * tier_scale
	var base_range := int(attack_profile.get("range", 165)) + (tier - 1) * 16
	var base_fire_rate : float = max(0.24, float(attack_profile.get("fire_rate", 0.9)) * (1.0 - float(tier - 1) * 0.07))
	var level_data := {
		"level": 1,
		"damage": snapped(base_damage, 0.1),
		"range": base_range,
		"fire_rate": snapped(base_fire_rate, 0.01)
	}
	for key in ["splash_radius", "slow_percent", "slow_duration", "slow_radius", "chain_count", "chain_range", "vulnerability_percent", "vulnerability_duration"]:
		if attack_profile.has(key):
			level_data[key] = attack_profile[key]
	var cfg := {
		"id": tower_id,
		"name": "%s %s" % [display_base, _roman(tier)],
		"display_name": "%s %s" % [display_base, _roman(tier)],
		"tier": tier,
		"combo_type": combo_type,
		"elements": elements.duplicate(true),
		"required_element_level": tier,
		"build_entry": tier == 1,
		"shop_order": shop_order,
		"next_upgrade_ids": next_ids,
		"cost": cost,
		"upgrade_cost": upgrade_cost,
		"description": _combo_description(elements, combo_type),
		"projectile_speed": int(attack_profile.get("projectile_speed", 560)),
		"visual_type": str(attack_profile.get("visual_type", "basic")),
		"attack_type": str(attack_profile.get("attack_type", "single")),
		"target_categories": attack_profile.get("target_categories", ["land", "air"]),
		"levels": [level_data]
	}
	for key in ["splash_radius", "slow_percent", "slow_duration", "slow_radius", "chain_count", "chain_range", "vulnerability_percent", "vulnerability_duration"]:
		if attack_profile.has(key):
			cfg[key] = attack_profile[key]
	return cfg

func _combo_attack_profile(elements: Array, combo_type: String) -> Dictionary:
	var has_fire := elements.has("fire")
	var has_water := elements.has("water")
	var has_nature := elements.has("nature")
	var has_earth := elements.has("earth")
	var has_light := elements.has("light")
	var has_darkness := elements.has("darkness")
	var combo_bonus := 1.0 if combo_type == "dual" else 1.32

	if has_fire and has_earth:
		return {"visual_type": "cannon", "attack_type": "splash", "target_categories": ["land"], "damage": 38.0 * combo_bonus, "range": 160, "fire_rate": 1.35, "splash_radius": 84, "projectile_speed": 440}
	if has_water and has_nature:
		return {"visual_type": "slow", "attack_type": "slow", "target_categories": ["land", "air"], "damage": 9.0 * combo_bonus, "range": 182, "fire_rate": 0.92, "slow_percent": 0.32, "slow_duration": 2.2, "slow_radius": 76, "projectile_speed": 520}
	if has_light and has_nature:
		return {"visual_type": "rapid", "attack_type": "single", "target_categories": ["land", "air"], "damage": 12.0 * combo_bonus, "range": 178, "fire_rate": 0.32, "projectile_speed": 760}
	if has_light and has_darkness:
		return {"visual_type": "lightning", "attack_type": "chain", "target_categories": ["land", "air"], "damage": 18.0 * combo_bonus, "range": 184, "fire_rate": 0.82, "chain_count": 3, "chain_range": 86, "projectile_speed": 900}
	if has_darkness and has_fire:
		return {"visual_type": "sawblade", "attack_type": "aura", "target_categories": ["land"], "damage": 8.5 * combo_bonus, "range": 146, "fire_rate": 0.7, "vulnerability_percent": 0.18, "vulnerability_duration": 2.0, "projectile_speed": 500}
	if has_water and has_earth:
		return {"visual_type": "cannon", "attack_type": "splash", "target_categories": ["land"], "damage": 31.0 * combo_bonus, "range": 170, "fire_rate": 1.18, "splash_radius": 74, "projectile_speed": 470}
	if has_fire:
		return {"visual_type": "cannon", "attack_type": "splash", "target_categories": ["land"], "damage": 27.0 * combo_bonus, "range": 165, "fire_rate": 1.12, "splash_radius": 70, "projectile_speed": 480}
	if has_water:
		return {"visual_type": "slow", "attack_type": "slow", "target_categories": ["land", "air"], "damage": 8.0 * combo_bonus, "range": 178, "fire_rate": 0.95, "slow_percent": 0.28, "slow_duration": 2.0, "slow_radius": 70, "projectile_speed": 520}
	if has_nature:
		return {"visual_type": "rapid", "attack_type": "single", "target_categories": ["land", "air"], "damage": 10.0 * combo_bonus, "range": 170, "fire_rate": 0.34, "projectile_speed": 760}
	if has_darkness:
		return {"visual_type": "sawblade", "attack_type": "aura", "target_categories": ["land"], "damage": 7.0 * combo_bonus, "range": 138, "fire_rate": 0.72, "vulnerability_percent": 0.16, "vulnerability_duration": 1.8, "projectile_speed": 500}
	return {"visual_type": "sniper", "attack_type": "single", "target_categories": ["land", "air"], "damage": 28.0 * combo_bonus, "range": 215, "fire_rate": 0.9, "projectile_speed": 800}

func _combo_slug(elements: Array) -> String:
	var parts: Array[String] = []
	for element_id in elements:
		parts.append(str(element_id))
	return "_".join(parts)

func _combo_display_name(elements: Array) -> String:
	var parts: Array[String] = []
	for element_id in elements:
		parts.append(str(ELEMENT_TD_LABELS.get(str(element_id), str(element_id).capitalize())))
	return " + ".join(parts)

func _combo_description(elements: Array, combo_type: String) -> String:
	return "%s-element combo tower unlocked by %s. Inspired by Element TD WC3 combination towers." % [combo_type.capitalize(), _combo_display_name(elements)]

func _roman(value: int) -> String:
	match value:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		_: return str(value)

func reset_build_state() -> void:
	selected_tower_id = ""
	occupied_cells.clear()
	tower_by_cell.clear()
	tower_selection_cleared.emit()

func mark_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells = cells

func set_selected_tower(tower_id: String) -> void:
	selected_tower_id = tower_id
	if selected_tower_id != "":
		tower_selected.emit(selected_tower_id)
	else:
		tower_selection_cleared.emit()

func clear_selected_tower() -> void:
	set_selected_tower("")

func set_unlocked_tower_ids(ids: Array[String]) -> void:
	unlocked_tower_ids = ids.duplicate()
	active_loadout = ids.duplicate()

func is_tower_unlocked(tower_id: String) -> bool:
	if unlocked_tower_ids.is_empty():
		return tower_id == "basic_tower_t1"
	return unlocked_tower_ids.has(tower_id)

func has_selected_tower() -> bool:
	return selected_tower_id != ""

func is_build_mode_active() -> bool:
	return has_selected_tower()

func get_selected_tower_config() -> Dictionary:
	return towers_config.get(selected_tower_id, {})

func get_selected_tower_range() -> float:
	var config = get_selected_tower_config()
	if config.has("levels") and config["levels"].size() > 0:
		return config["levels"][0].get("range", 0.0)
	return 0.0

func get_selected_tower_footprint() -> float:
	var config = get_selected_tower_config()
	return config.get("footprint_radius", DEFAULT_FOOTPRINT_RADIUS)

func update_hover(local_pos: Vector2) -> void:
	if not has_selected_tower(): return
	
	var cell = local_to_cell(local_pos)
	var validation = validate_placement(cell)
	hover_cell_changed.emit(cell, validation["is_valid"], validation["reason"])

func try_place_tower(local_pos: Vector2) -> bool:
	if not has_selected_tower(): return false
	
	var cell = local_to_cell(local_pos)
	var validation = validate_placement(cell)
	
	if not validation["is_valid"]:
		if OS.is_debug_build(): print("[BuildFlow] place failed reason=%s" % validation["reason"])
		placement_failed.emit(validation["reason"])
		return false
	
	if game_manager.spend_gold(validation["cost"]):
		if OS.is_debug_build(): print("[BuildFlow] placed tower=%s pos=%s cost=%d" % [selected_tower_id, cell, validation["cost"]])
		place_tower(cell, validation["config"])
		return true
	
	if OS.is_debug_build(): print("[BuildFlow] place failed: Not enough gold! (needed %d)" % validation["cost"])
	placement_failed.emit("Not enough gold!")
	return false

func validate_placement(cell: Vector2i) -> Dictionary:
	var config = get_selected_tower_config()
	if config.is_empty():
		return {"is_valid": false, "reason": "Tower config missing", "cost": 0}
	var cost = config.get("cost", 0)

	# Elemental TD mode: direct build options are filtered by unlocked element
	# combinations. Upgrades are handled separately by Main/Tower.
	if not is_tower_unlocked(selected_tower_id):
		return {"is_valid": false, "reason": "Tower is not unlocked by current elements", "cost": cost}

	if not is_in_bounds(cell):
		return {"is_valid": false, "reason": "Cannot build outside map", "cost": cost}
	
	# Occupancy Check
	for footprint_cell in _get_tower_footprint_cells(cell, config):
		if occupied_cells.has(footprint_cell):
			return {"is_valid": false, "reason": "Cannot build on existing tower", "cost": cost}
		var build_reason := get_build_block_reason(footprint_cell)
		if build_reason != "":
			return {"is_valid": false, "reason": _format_build_reason(build_reason), "cost": cost}
	
	return {"is_valid": true, "reason": "Valid", "cost": cost, "config": config}

func place_tower(cell: Vector2i, config: Dictionary) -> void:
	var tower = tower_scene.instantiate()
	tower_container.add_child(tower)
	tower.add_to_group("towers")
	tower.add_to_group("placed_towers")
	# Set LOCAL position relative to TowerContainer
	tower.position = cell_to_local_center(cell)
	
	if OS.is_debug_build(): print("[Build] Placed tower at cell=", cell, " local=", tower.position, " global=", tower.global_position)
	
	tower.setup(config, cell)
	tower.set_projectile_container(projectile_container)
	
	for footprint_cell in _get_tower_footprint_cells(cell, config):
		occupied_cells[footprint_cell] = true
		tower_by_cell[_cell_key(footprint_cell)] = tower
	tower_placed.emit(tower, selected_tower_id, config.get("cost", 0))
	
	if game_manager and "battle_telemetry" in game_manager and game_manager.battle_telemetry:
		game_manager.battle_telemetry.log_tower_built(selected_tower_id, cell, tower.position, config.get("cost", 0))
	
	# After placing, clear selection
	clear_selected_tower()

func local_to_cell(local_pos: Vector2) -> Vector2i:
	var p := local_pos - grid_origin
	return Vector2i(floor(p.x / grid_size), floor(p.y / grid_size))

func cell_to_local_center(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x * grid_size + grid_size/2, cell.y * grid_size + grid_size/2)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_cols and cell.y >= 0 and cell.y < grid_rows

func can_build_at_cell(cell: Vector2i) -> bool:
	return validate_placement(cell)["is_valid"]

func get_build_block_reason(cell: Vector2i) -> String:
	if not is_in_bounds(cell):
		return "out_of_bounds"
	if level_manager and level_manager.has_method("get_build_block_reason"):
		var reason := str(level_manager.get_build_block_reason(cell))
		if reason != "":
			return reason
	elif cell in blocked_cells:
		return "blocked"
	return ""

func _format_build_reason(reason: String) -> String:
	match reason:
		"out_of_bounds":
			return "Cannot build outside map"
		"path":
			return "Cannot build on enemy path"
		"spawn":
			return "Cannot build on spawn point"
		"base":
			return "Cannot build on base point"
		"non_buildable":
			return "Tile is not buildable"
		"occupied":
			return "Cannot build on existing tower"
		"blocked":
			return "Tile is blocked"
		_:
			return reason

func can_place_at(cell: Vector2i) -> bool:
	return validate_placement(cell)["is_valid"]

func _get_tower_footprint_cells(cell: Vector2i, config: Dictionary) -> Array[Vector2i]:
	var footprint_cells: Array[Vector2i] = []
	var raw = config.get("footprint_cells", [])
	if raw is Array and not raw.is_empty():
		for item in raw:
			if item is Vector2i:
				footprint_cells.append(item)
			elif item is Array and item.size() >= 2:
				footprint_cells.append(cell + Vector2i(int(item[0]), int(item[1])))
	if footprint_cells.is_empty():
		footprint_cells.append(cell)
	return footprint_cells

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func get_tower_at_cell(cell: Vector2i) -> Node:
	return tower_by_cell.get(_cell_key(cell), null)

func remove_tower_at_cell(cell: Vector2i) -> bool:
	var footprint_cells: Array[Vector2i] = []
	
	# Find the tower at this cell and determine its full footprint
	var key := _cell_key(cell)
	var tower: Node = tower_by_cell.get(key, null)
	if tower == null:
		return false
	
	if tower.has_method("get_grid_cell"):
		# Gather all footprint cells from tower_by_cell that point to this tower
		for k in tower_by_cell.keys():
			if tower_by_cell[k] == tower:
				footprint_cells.append(_parse_cell_key(k))
	
	if footprint_cells.is_empty():
		footprint_cells.append(cell)
	
	# Remove from occupancy and tower map
	for fc in footprint_cells:
		occupied_cells.erase(fc)
		tower_by_cell.erase(_cell_key(fc))
	
	# Remove the tower node
	if tower is Node and is_instance_valid(tower):
		tower.queue_free()
	
	return true

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)

func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",", false, 1)
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO
