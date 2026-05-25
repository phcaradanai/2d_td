extends Control

const CosmeticDrawUtilsScript := preload("res://systems/cosmetics/cosmetic_draw_utils.gd")
const TowerVisualRegistryScript := preload("res://scripts/towers/visuals/tower_visual_registry.gd")
const TowerAttackVFXRegistryScript := preload("res://scripts/vfx/core/tower_attack_vfx_registry.gd")

var tower_skin_id: String = ""
var projectile_skin_id: String = ""
var impact_skin_id: String = ""
var aura_skin_id: String = ""
var attack_vfx_skin_id: String = ""
var registry: Node = null
var tower_node: Node2D = null
var tower_cfg: Dictionary = {}

var _attack_vfx_node: Node2D = null
var _last_vfx_tower_id: String = ""
var _vfx_tween: Tween = null

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

func set_cosmetics(tower_skin: String, projectile_skin: String, impact_skin: String, aura_skin: String = "", attack_vfx_skin: String = "") -> void:
	tower_skin_id = tower_skin
	projectile_skin_id = projectile_skin
	impact_skin_id = impact_skin
	aura_skin_id = aura_skin
	attack_vfx_skin_id = attack_vfx_skin
	_update_tower_node()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_tower_node()
		_apply_attack_vfx_state()

func _draw() -> void:
	var center := size * 0.5 + Vector2(-42, 8)
	var is_support := str(tower_cfg.get("attack_type", "")) == "support_aura"

	if is_support:
		draw_set_transform(center, 0.0, Vector2.ONE)
		if aura_skin_id == "":
			CosmeticDrawUtilsScript.draw_aura_default(self, tower_cfg)
		else:
			CosmeticDrawUtilsScript.draw_aura(self, aura_skin_id, _get_cosmetic_cfg(aura_skin_id))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var bolt_center := center + Vector2(112, -24)
		draw_set_transform(bolt_center, 0.0, Vector2.ONE)
		if projectile_skin_id == "":
			CosmeticDrawUtilsScript.draw_projectile_default(self, tower_cfg)
		else:
			CosmeticDrawUtilsScript.draw_projectile(self, projectile_skin_id, _get_cosmetic_cfg(projectile_skin_id), 560.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var impact_center := center + Vector2(116, 34)
		draw_set_transform(impact_center, 0.0, Vector2.ONE)
		if impact_skin_id == "":
			CosmeticDrawUtilsScript.draw_impact_default(self, tower_cfg)
		else:
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
	var tower_id := str(tower_cfg.get("id", ""))
	var is_support := str(tower_cfg.get("attack_type", "")) == "support_aura"
	if is_support:
		if _vfx_tween != null:
			_vfx_tween.kill()
			_vfx_tween = null
		if _attack_vfx_node != null and is_instance_valid(_attack_vfx_node):
			_attack_vfx_node.visible = false
	elif tower_id != _last_vfx_tower_id:
		_rebuild_attack_vfx_node()
	else:
		_apply_attack_vfx_state()

func _rebuild_attack_vfx_node() -> void:
	if _vfx_tween != null:
		_vfx_tween.kill()
		_vfx_tween = null
	if _attack_vfx_node != null and is_instance_valid(_attack_vfx_node):
		_attack_vfx_node.queue_free()
	_attack_vfx_node = null
	var tower_id := str(tower_cfg.get("id", ""))
	if tower_id == "":
		_last_vfx_tower_id = ""
		return
	var script: GDScript = TowerAttackVFXRegistryScript.get_vfx_script(tower_id)
	if script == null:
		_last_vfx_tower_id = tower_id
		return
	# Warm the baker cache so in-game is ready on first shot.
	var baker := get_node_or_null("/root/AttackVFXFrameBaker")
	if baker != null and baker.has_method("request_bake") and not baker.has_frames(tower_id):
		baker.request_bake(tower_id, script)
	# static_mode=false so _draw() uses elapsed for the full t=0→1 animation.
	# has_meta("pooled") prevents _begin_pooled_lifecycle() from running in _ready().
	var node: Node2D = script.new() as Node2D
	node.set_meta("pooled", true)
	add_child(node)
	# Disable _process() after _ready() runs so the node never auto-releases.
	node.set_process(false)
	node.set("elapsed", 0.0)
	_attack_vfx_node = node
	_last_vfx_tower_id = tower_id
	if node.has_method("configure"):
		node.configure({})
	_apply_attack_vfx_state()

func _apply_attack_vfx_state() -> void:
	if _attack_vfx_node == null or not is_instance_valid(_attack_vfx_node):
		return
	var center := size * 0.5 + Vector2(-42, 8)
	# Start from just past the tower model edge (tower draws at ~1.45× scale, radius ~29px).
	_attack_vfx_node.position = center + Vector2(40, 0)
	_attack_vfx_node.rotation = 0.0
	_attack_vfx_node.set("distance", 95.0)
	var primary := _get_tower_preview_color()
	var secondary := primary.lightened(0.28)
	if attack_vfx_skin_id != "":
		var cfg := _get_cosmetic_cfg(attack_vfx_skin_id)
		if cfg.has("primary_color"):
			primary = Color.from_string(str(cfg["primary_color"]), primary)
		if cfg.has("secondary_color"):
			secondary = Color.from_string(str(cfg["secondary_color"]), secondary)
	_attack_vfx_node.set("palette_primary", primary)
	_attack_vfx_node.set("palette_secondary", secondary)
	_attack_vfx_node.visible = true
	_start_vfx_loop()

func _start_vfx_loop() -> void:
	if _vfx_tween != null:
		_vfx_tween.kill()
	_vfx_tween = null
	if _attack_vfx_node == null or not is_instance_valid(_attack_vfx_node):
		return
	var lifetime: float = maxf(0.08, float(_attack_vfx_node.get("lifetime") \
		if "lifetime" in _attack_vfx_node else 0.12))
	_attack_vfx_node.set("elapsed", 0.0)
	_attack_vfx_node.queue_redraw()
	_vfx_tween = create_tween().set_loops()
	# Play at preview speed (0.5s) regardless of in-game lifetime so it's readable.
	_vfx_tween.tween_method(func(v: float) -> void:
		if is_instance_valid(_attack_vfx_node):
			_attack_vfx_node.set("elapsed", v)
			_attack_vfx_node.queue_redraw()
	, 0.0, lifetime, 0.5)
	# Pause at end state before next loop so the user can see the full trail.
	_vfx_tween.tween_interval(0.65)

func _get_tower_preview_color() -> Color:
	var elements: Array = tower_cfg.get("elements", [])
	var visual_type := str(tower_cfg.get("visual_type", "basic"))
	var combo_type := str(tower_cfg.get("combo_type", "neutral"))
	if elements.size() > 0:
		if combo_type == "periodic":
			return Color(0.9, 0.95, 1.0)
		match str(elements[0]).to_lower():
			"light": return Color(1.0, 0.9, 0.25)
			"darkness", "dark": return Color(0.6, 0.2, 0.9)
			"water": return Color(0.2, 0.55, 1.0)
			"fire": return Color(1.0, 0.35, 0.1)
			"nature": return Color(0.25, 0.85, 0.3)
			"earth": return Color(0.65, 0.42, 0.2)
	match visual_type:
		"basic": return Color(0.2, 0.8, 1.0)
		"rapid": return Color(0.0, 1.0, 0.8)
		"cannon": return Color(1.0, 0.4, 0.1)
		"slow": return Color(0.6, 1.0, 1.0)
		"sniper": return Color(0.1, 0.5, 1.0)
		"lightning": return Color(0.5, 0.4, 1.0)
		"trickery": return Color(0.75, 0.45, 1.0)
	return Color.WHITE

func _get_cosmetic_cfg(cosmetic_id: String) -> Dictionary:
	if cosmetic_id == "" or registry == null:
		return {}
	if registry.has_method("get_cosmetic"):
		return registry.get_cosmetic(cosmetic_id)
	return {}
