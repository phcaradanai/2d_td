extends Control

const CosmeticDrawUtilsScript := preload("res://systems/cosmetics/cosmetic_draw_utils.gd")
const TowerVisualRegistryScript := preload("res://scripts/towers/visuals/tower_visual_registry.gd")

var tower_skin_id: String = ""
var projectile_skin_id: String = ""
var impact_skin_id: String = ""
var registry: Node = null
var tower_node: Node2D = null
var tower_cfg: Dictionary = {}

class TowerPreviewNode extends Node2D:
	var tower_skin_id: String = ""
	var registry: Node = null
	var tower_id: String = "basic_tower_t1"
	var visual_type: String = "basic"
	var tree_tier: int = 1
	var combo_type: String = "neutral"
	var elements: Array[String] = []
	var static_preview: bool = true
	var preview_mode: bool = true
	var is_static_preview: bool = true

	func set_tower_config(cfg: Dictionary) -> void:
		tower_id = str(cfg.get("id", "basic_tower_t1"))
		visual_type = str(cfg.get("visual_type", "basic"))
		tree_tier = int(cfg.get("tier", 1))
		combo_type = str(cfg.get("combo_type", "neutral"))
		elements.clear()
		var raw_elements = cfg.get("elements", [])
		if raw_elements is Array:
			for element in raw_elements:
				elements.append(str(element))
		queue_redraw()

	func set_skin(skin_id: String, p_registry: Node) -> void:
		tower_skin_id = skin_id
		registry = p_registry
		queue_redraw()

	func _draw() -> void:
		var visual_script := _get_tower_visual_script()
		if visual_script == null:
			return
		var main_color := _get_tower_color()
		var secondary_color := _get_secondary_element_color()
		var core_color := Color(0.7, 0.8, 0.85, 1.0)
		var element_colors := _get_all_element_colors()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.45, 1.45))
		if visual_script.has_method("draw_contour"):
			visual_script.draw_contour(self)
		if visual_script.has_method("draw_top"):
			visual_script.draw_top(self, main_color, secondary_color, core_color, tree_tier, 20.0, element_colors)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _get_tower_visual_script() -> Script:
		if tower_skin_id != "":
			var cfg := _get_cosmetic_cfg(tower_skin_id)
			var path := str(cfg.get("visual_script", ""))
			if path != "" and ResourceLoader.exists(path):
				return load(path) as Script
		return TowerVisualRegistryScript.get_visual_script(tower_id, visual_type)

	func _get_cosmetic_cfg(cosmetic_id: String) -> Dictionary:
		if cosmetic_id == "" or registry == null:
			return {}
		if registry.has_method("get_cosmetic"):
			return registry.get_cosmetic(cosmetic_id)
		return {}

	func _get_all_element_colors() -> Array[Color]:
		var colors: Array[Color] = []
		for element in elements:
			colors.append(_get_element_color(element))
		return colors

	func _get_tower_color() -> Color:
		if not elements.is_empty():
			if combo_type == "periodic":
				return Color(0.9, 0.95, 1.0)
			return _get_element_color(elements[0])
		match visual_type:
			"basic":
				return Color(0.2, 0.8, 1.0)
			"rapid":
				return Color(0.0, 1.0, 0.8)
			"cannon":
				return Color(1.0, 0.4, 0.1)
			"slow":
				return Color(0.6, 1.0, 1.0)
			"sniper":
				return Color(0.1, 0.5, 1.0)
			"lightning":
				return Color(0.5, 0.4, 1.0)
			"trickery":
				return Color(0.75, 0.45, 1.0)
			_:
				return Color.WHITE

	func _get_element_color(element: String) -> Color:
		match element.to_lower():
			"light":
				return Color(1.0, 0.9, 0.25)
			"darkness", "dark":
				return Color(0.6, 0.2, 0.9)
			"water":
				return Color(0.2, 0.55, 1.0)
			"fire":
				return Color(1.0, 0.35, 0.1)
			"nature":
				return Color(0.25, 0.85, 0.3)
			"earth":
				return Color(0.65, 0.42, 0.2)
			_:
				return Color(0.45, 0.92, 1.0)

	func _get_tower_visual_family() -> String:
		var id := tower_id.to_lower()
		if id.begins_with("ice_"):
			return "ice"
		if id.begins_with("polar_"):
			return "polar"
		if id.begins_with("light_") or id == "pure_light":
			return "light"
		if id.begins_with("life_"):
			return "life"
		if id.begins_with("well_"):
			return "well"
		if id.begins_with("tidal_"):
			return "tidal"
		if id.begins_with("enchantment_"):
			return "enchantment"
		if id.begins_with("electricity_"):
			return "electricity"
		if id.begins_with("jinx_"):
			return "jinx"
		if id.begins_with("periodic_"):
			return "periodic"
		if id.begins_with("disease_"):
			return "disease"
		if id.begins_with("mushroom_"):
			return "mushroom"
		return visual_type

	func _get_secondary_element_color() -> Color:
		if elements.size() >= 2:
			return _get_element_color(elements[1])
		return _get_tower_color()

	func _get_tertiary_element_color() -> Color:
		if elements.size() >= 3:
			return _get_element_color(elements[2])
		return _get_secondary_element_color()

	func _get_visual_muzzle_local_position() -> Vector2:
		return Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(240, 150)
	tower_node = TowerPreviewNode.new()
	tower_node.name = "TowerPreviewNode"
	add_child(tower_node)
	_update_tower_node()

func set_tower_config(cfg: Dictionary) -> void:
	tower_cfg = cfg.duplicate(true)
	_update_tower_node()
	queue_redraw()

func set_cosmetics(tower_skin: String, projectile_skin: String, impact_skin: String) -> void:
	tower_skin_id = tower_skin
	projectile_skin_id = projectile_skin
	impact_skin_id = impact_skin
	_update_tower_node()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_tower_node()

func _draw() -> void:
	var center := size * 0.5 + Vector2(-42, 8)

	var bolt_center := center + Vector2(112, -24)
	draw_set_transform(bolt_center, 0.0, Vector2.ONE)
	CosmeticDrawUtilsScript.draw_projectile(self, projectile_skin_id, _get_cosmetic_cfg(projectile_skin_id), 560.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var impact_center := center + Vector2(116, 34)
	draw_set_transform(impact_center, 0.0, Vector2.ONE)
	CosmeticDrawUtilsScript.draw_impact(self, _get_cosmetic_cfg(impact_skin_id), 0.35)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _update_tower_node() -> void:
	if tower_node == null:
		return
	tower_node.position = size * 0.5 + Vector2(-42, 8)
	if tower_node.has_method("set_tower_config"):
		tower_node.set_tower_config(tower_cfg)
	if tower_node.has_method("set_skin"):
		tower_node.set_skin(tower_skin_id, registry)

func _get_cosmetic_cfg(cosmetic_id: String) -> Dictionary:
	if cosmetic_id == "" or registry == null:
		return {}
	if registry.has_method("get_cosmetic"):
		return registry.get_cosmetic(cosmetic_id)
	return {}
