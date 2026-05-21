class_name TowerCatalogPreview
extends Control

const CatalogPreviewModeScript = preload("res://scripts/debug/catalog_preview_mode.gd")
const CatalogRenderGuardScript = preload("res://scripts/debug/catalog_render_guard.gd")
const TowerPreviewResolverScript = preload("res://scripts/debug/tower_preview_resolver.gd")
const TowerEffectPreviewServiceScript = preload("res://scripts/effects/tower_effect_preview_service.gd")

## Displays a real Tower scene inside a SubViewport so the catalog preview
## matches actual gameplay visuals, including idle animation and element glow.

var tower_id: String = ""
var tower_config: Dictionary = {}
@export var preview_size: Vector2 = Vector2(340, 220)
@export var camera_zoom: float = 1.5
@export var show_range_ring: bool = true
@export var show_projectile_preview: bool = false
@export var show_effects_preview: bool = false
@export var show_impact_preview: bool = true
@export var static_preview: bool = true
@export var preview_paused: bool = false:
	set(value):
		_preview_paused = value
		if is_inside_tree():
			set_active(_active)
	get:
		return _preview_paused
var fallback_reason: String = ""

var _viewport: SubViewport = null
var _viewport_container: SubViewportContainer = null
var _preview_world: Node2D = null
var _tower_root: Node2D = null
var _dummy_target_root: Node2D = null
var _projectile_root: Node2D = null
var _impact_root: Node2D = null
var _effect_root: Node2D = null
var _tower: Node2D = null
var _tower_world_position := Vector2.ZERO
var _preview_paused := false
var _active := true
var _resolver_data: Dictionary = {}
var _attack_vfx_node: Node2D = null
var _projectile_node: Node2D = null
var _impact_node: Node2D = null
var _projectile_t: float = 0.0
var _shot_elapsed: float = 0.0
var _last_draw_hash: int = 0   # Redraw guard: only queue_redraw when visual state changed.
var _counted_active: bool = false  # Tracks whether this instance is counted in _s_active_count.

# Global counters for debug telemetry.
static var _s_active_count: int = 0
static var _s_redraw_count: int = 0

class PreviewDummyTarget:
	extends Node2D

	var radius: float = 10.0

	func _draw() -> void:
		TowerVisualDrawUtils.safe_draw_circle(self, Vector2.ZERO, radius, Color(0.18, 0.55, 0.75, 0.28))
		TowerVisualDrawUtils.safe_draw_line(self, Vector2(-14, 0), Vector2(14, 0), Color(0.75, 0.95, 1.0, 0.55), 1.0)
		TowerVisualDrawUtils.safe_draw_line(self, Vector2(0, -14), Vector2(0, 14), Color(0.75, 0.95, 1.0, 0.55), 1.0)

	func get_hit_origin() -> Vector2:
		return global_position

	func get_hit_anchor_global_position() -> Vector2:
		return global_position

	func take_damage(_amount: float, _hit_pos: Vector2 = Vector2.ZERO, _source_id: String = "", _attack_type: String = "") -> void:
		pass

class RealTowerVisualPreview:
	extends Node2D

	var tower_id: String = ""
	var visual_type: String = "basic"
	var tree_tier: int = 1
	var elements: Array[String] = []
	var is_selected: bool = true
	var is_hovered: bool = true
	var hovered: bool = true
	var is_catalog_preview: bool = true
	var attack_range: float = 160.0

	func configure(p_tower_id: String, cfg: Dictionary) -> void:
		tower_id = p_tower_id
		visual_type = str(cfg.get("visual_type", "basic"))
		tree_tier = int(cfg.get("tier", 1))
		attack_range = float(cfg.get("range", 160.0))
		elements.clear()
		var raw_elements = cfg.get("elements", [])
		if raw_elements is Array:
			for element in raw_elements:
				elements.append(str(element))
		queue_redraw()

	func _draw() -> void:
		TowerVisualRenderer.draw_base_plate(self)
		TowerVisualRenderer.draw_turret_contour(self)
		TowerVisualRenderer.draw_turret_top(self)

	func mark_visual_dirty() -> void:
		queue_redraw()

	func get_fire_origin() -> Vector2:
		return global_position + _get_visual_muzzle_local_position().rotated(global_rotation) * global_scale

	func _get_all_element_colors() -> Array[Color]:
		var colors: Array[Color] = []
		for element in elements:
			colors.append(_get_element_color(element))
		return colors

	func _get_tower_color() -> Color:
		if not elements.is_empty():
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

	func _get_visual_muzzle_local_position() -> Vector2:
		var lvl := tree_tier
		match visual_type:
			"basic":
				return Vector2(26 + lvl * 4, 0)
			"rapid":
				return Vector2(22 + lvl * 2, 0)
			"cannon":
				return Vector2(18 + lvl * 4, 0)
			"sniper":
				return Vector2(42 + lvl * 6, 0)
			"forge_anvil":
				return Vector2(28 + lvl * 2, 0)
			"rail_laser":
				return Vector2(42 + lvl * 5, 0)
			"hydro_cannon", "dual_nozzle":
				return Vector2(28 + lvl * 3, 0)
			"furnace", "bio_vine", "steam_boiler":
				return Vector2(24 + lvl * 2, 0)
			_:
				return Vector2(28, 0)


func _ready() -> void:
	_setup_viewport()
	_spawn_preview_tower()
	custom_minimum_size = preview_size
	size = preview_size
	set_static_preview(static_preview)
	set_active(_active)

func _process(delta: float) -> void:
	if preview_paused or static_preview or _projectile_node == null or not is_instance_valid(_projectile_node):
		return
	_shot_elapsed += delta
	_projectile_t = fmod(_shot_elapsed / 0.85, 1.0)
	var from_pos := _get_muzzle_position()
	var to_pos := _get_fake_target_world_position()
	var pos := from_pos.lerp(to_pos, _projectile_t)
	_projectile_node.global_position = pos
	_projectile_node.rotation = (to_pos - from_pos).angle()

func _setup_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "PreviewViewportContainer"
	_viewport_container.stretch = false
	_viewport_container.custom_minimum_size = preview_size
	_viewport_container.size = preview_size
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.size = Vector2i(int(preview_size.x), int(preview_size.y))
	_viewport.transparent_bg = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_container.add_child(_viewport)

	var cam := Camera2D.new()
	cam.name = "PreviewCamera"
	cam.position = Vector2(0, -2)
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	cam.enabled = true
	_viewport.add_child(cam)
	cam.make_current()

	_preview_world = Node2D.new()
	_preview_world.name = "PreviewWorld2D"
	_viewport.add_child(_preview_world)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 1)
	bg.size = Vector2(1200, 900)
	bg.position = Vector2(-600, -450)
	bg.z_index = -100
	_preview_world.add_child(bg)

	_tower_root = Node2D.new()
	_tower_root.name = "TowerPreviewRoot"
	_preview_world.add_child(_tower_root)
	_dummy_target_root = Node2D.new()
	_dummy_target_root.name = "DummyTargetRoot"
	_preview_world.add_child(_dummy_target_root)
	_projectile_root = Node2D.new()
	_projectile_root.name = "ProjectileRoot"
	_preview_world.add_child(_projectile_root)
	_impact_root = Node2D.new()
	_impact_root.name = "ImpactRoot"
	_preview_world.add_child(_impact_root)
	_effect_root = Node2D.new()
	_effect_root.name = "EffectRoot"
	_preview_world.add_child(_effect_root)


func _spawn_preview_tower() -> void:
	if tower_config.is_empty():
		_show_fallback("no config data")
		return
	_resolver_data = TowerPreviewResolverScript.resolve(tower_id, tower_config)

	if str(_resolver_data.get("visual_script_path", "")).is_empty():
		_show_fallback("missing by-id visual script")
		return
	_tower = RealTowerVisualPreview.new()
	_tower.name = "%s_RealVisualPreview" % tower_id

	_tower_root.add_child(_tower)
	_tower_world_position = _get_tower_world_position()
	_tower.position = _tower_world_position
	_tower.rotation = 0.0
	_tower.scale = Vector2.ONE * 3.4
	_tower.z_index = 10
	_tower.visible = true
	_tower.modulate = Color.WHITE
	(_tower as RealTowerVisualPreview).configure(tower_id, tower_config)
	CatalogPreviewModeScript.mark_preview_tree(_tower, true, true)
	_force_one_safe_redraw(_tower)
	_sync_real_preview_nodes()

func set_preview_options(p_show_range: bool, p_show_projectile: bool, p_show_effects: bool, p_paused: bool = false, p_show_impact: bool = true) -> void:
	show_range_ring = p_show_range
	show_projectile_preview = p_show_projectile
	show_effects_preview = p_show_effects
	preview_paused = p_paused
	show_impact_preview = p_show_impact
	_sync_real_preview_nodes()
	set_active(_active)
	_queue_redraw_if_changed()

func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if active and not _counted_active:
		_counted_active = true
		_s_active_count += 1
	elif not active and _counted_active:
		_counted_active = false
		_s_active_count = maxi(0, _s_active_count - 1)
	if _viewport:
		if not active:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif (show_projectile_preview or show_effects_preview) and not preview_paused and not static_preview:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif CatalogRenderGuardScript.allow_animated_redraw and not static_preview:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _tower:
		CatalogPreviewModeScript.set_static_preview(_tower, static_preview or not active)
		CatalogPreviewModeScript.set_selected_demo(_tower, active)
		if _tower.has_method("mark_visual_dirty"):
			_tower.mark_visual_dirty()
		var wants_tower_process := active and not static_preview and (show_projectile_preview or show_effects_preview or CatalogRenderGuardScript.allow_animated_redraw)
		_set_processing_recursive(_tower, wants_tower_process)
	set_process(active and not preview_paused and not static_preview and show_projectile_preview and _projectile_node != null)
	_set_effect_roots_processing(active and not preview_paused and not static_preview)
	if _projectile_node:
		_projectile_node.set_process(false)
		_projectile_node.set_physics_process(false)

func set_static_preview(enabled: bool) -> void:
	static_preview = enabled
	if enabled:
		show_projectile_preview = false
		show_effects_preview = false
		preview_paused = true
		_clear_real_effect_nodes()
	else:
		preview_paused = _preview_paused
	if _tower:
		CatalogPreviewModeScript.set_static_preview(_tower, enabled)
		CatalogPreviewModeScript.set_selected_demo(_tower, true)
		if _tower.has_method("mark_visual_dirty"):
			_tower.mark_visual_dirty()
	_sync_real_preview_nodes()
	set_active(_active)
	_queue_redraw_if_changed()

func set_vfx_enabled(enabled: bool) -> void:
	if static_preview and enabled:
		set_static_preview(false)
	show_effects_preview = enabled
	_sync_real_preview_nodes()
	set_active(_active)
	_queue_redraw_if_changed()

func set_projectile_preview_enabled(enabled: bool) -> void:
	show_projectile_preview = enabled
	if enabled and static_preview:
		set_static_preview(false)
	_sync_real_preview_nodes()
	set_active(_active)
	_queue_redraw_if_changed()

func set_impact_preview_enabled(enabled: bool) -> void:
	show_impact_preview = enabled
	if enabled and static_preview:
		set_static_preview(false)
	_sync_real_preview_nodes()
	set_active(_active)
	_queue_redraw_if_changed()

func play_preview() -> void:
	preview_paused = false
	set_active(_active)
	if _attack_vfx_node == null and show_effects_preview:
		_spawn_attack_vfx_preview()
	if _impact_node == null and show_impact_preview:
		_spawn_impact_preview()

func pause_preview() -> void:
	preview_paused = true
	set_active(_active)

func stop_preview() -> void:
	if _viewport:
		_stop_preview_subtree(_viewport)
	disable_simulation()
	set_active(false)
	set_process(false)
	set_physics_process(false)
	set_process_input(false)

func get_vfx_viewport() -> SubViewport:
	return _viewport

func disable_simulation() -> void:
	_clear_real_effect_nodes()

func _set_processing_recursive(node: Node, enabled: bool) -> void:
	node.set_process(enabled)
	node.set_physics_process(false)
	for child in node.get_children():
		_set_processing_recursive(child, enabled)

func _set_effect_roots_processing(enabled: bool) -> void:
	for root in [_effect_root, _projectile_root, _impact_root, _dummy_target_root]:
		if root != null:
			_set_processing_recursive(root, enabled)

func _stop_preview_subtree(node: Node) -> void:
	if node == null:
		return
	if node is Timer:
		(node as Timer).stop()
	if node is AnimationPlayer:
		(node as AnimationPlayer).stop(true)
	if node is GPUParticles2D:
		(node as GPUParticles2D).emitting = false
	if node is CPUParticles2D:
		(node as CPUParticles2D).emitting = false
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child in node.get_children():
		_stop_preview_subtree(child)

func _get_tower_world_position() -> Vector2:
	if show_projectile_preview or show_effects_preview:
		return Vector2(-120, 8)
	return Vector2(0, 6)

func _get_fake_target_world_position() -> Vector2:
	return Vector2(180, 4)

func _sync_real_preview_nodes() -> void:
	if _preview_world == null or static_preview:
		return
	_sync_tower_position()
	_sync_dummy_target()
	if show_effects_preview:
		_spawn_attack_vfx_preview()
	else:
		_clear_node_ref("_attack_vfx_node")
	if show_projectile_preview:
		_spawn_projectile_preview()
	else:
		_clear_node_ref("_projectile_node")
	if show_impact_preview:
		_spawn_impact_preview()
	else:
		_clear_node_ref("_impact_node")

func _sync_tower_position() -> void:
	_tower_world_position = _get_tower_world_position()
	if _tower:
		_tower.position = _tower_world_position

func _sync_dummy_target() -> void:
	if not (show_projectile_preview or show_effects_preview or show_impact_preview):
		_clear_children(_dummy_target_root)
		return
	if _dummy_target_root == null:
		return
	if _dummy_target_root.get_child_count() == 0:
		var dummy := PreviewDummyTarget.new()
		dummy.name = "PreviewDummyTarget"
		_dummy_target_root.add_child(dummy)
	var target := _dummy_target_root.get_child(0) as Node2D
	if target:
		target.position = _get_fake_target_world_position()

func _spawn_attack_vfx_preview() -> void:
	if _attack_vfx_node and is_instance_valid(_attack_vfx_node):
		return
	if not bool(_resolver_data.get("has_attack_vfx", false)):
		return
	var color: Color = _tower._get_tower_color() if _tower and _tower.has_method("_get_tower_color") else Color.WHITE
	_attack_vfx_node = TowerEffectPreviewServiceScript.spawn_attack_vfx_preview(
		tower_id,
		_get_muzzle_position(),
		_get_fake_target_world_position(),
		_effect_root,
		color
	)
	if _attack_vfx_node and preview_paused:
		_attack_vfx_node.set_process(false)

func _spawn_projectile_preview() -> void:
	if _projectile_node and is_instance_valid(_projectile_node):
		return
	if not bool(_resolver_data.get("has_projectile", false)):
		return
	var color: Color = _tower._get_tower_color() if _tower and _tower.has_method("_get_tower_color") else Color.WHITE
	_projectile_node = TowerEffectPreviewServiceScript.spawn_projectile_preview(
		tower_id,
		tower_config,
		_get_muzzle_position(),
		_get_fake_target_world_position(),
		_projectile_root,
		color
	)
	_projectile_t = 0.0
	_shot_elapsed = 0.0

func _spawn_impact_preview() -> void:
	if _impact_node and is_instance_valid(_impact_node):
		return
	if not bool(_resolver_data.get("has_impact", false)):
		return
	var color: Color = _tower._get_tower_color() if _tower and _tower.has_method("_get_tower_color") else Color.WHITE
	_impact_node = TowerEffectPreviewServiceScript.spawn_impact_preview(
		tower_config,
		_get_fake_target_world_position(),
		_impact_root,
		color
	)

func _clear_real_effect_nodes() -> void:
	_clear_node_ref("_attack_vfx_node")
	_clear_node_ref("_projectile_node")
	_clear_node_ref("_impact_node")
	_clear_children(_dummy_target_root)

func _clear_node_ref(property_name: String) -> void:
	var node = get(property_name)
	if node != null and is_instance_valid(node):
		if node.has_method("stop_preview"):
			node.stop_preview()
		node.set_process(false)
		node.set_physics_process(false)
		node.queue_free()
	set(property_name, null)

func _clear_children(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		_stop_preview_subtree(child)
		child.queue_free()

func _get_muzzle_position() -> Vector2:
	if _tower and _tower.has_method("get_fire_origin"):
		return _tower.get_fire_origin()
	return _tower_world_position

func resize_preview_viewport(stage_size: Vector2) -> void:
	if stage_size.x < 64.0 or stage_size.y < 64.0:
		stage_size = Vector2(720, 440)
	preview_size = stage_size
	custom_minimum_size = stage_size
	size = stage_size
	if _viewport_container:
		_viewport_container.custom_minimum_size = stage_size
		_viewport_container.size = stage_size
	if _viewport:
		_viewport.size = Vector2i(int(stage_size.x), int(stage_size.y))
		var camera := _viewport.get_node_or_null("PreviewCamera") as Camera2D
		if camera:
			camera.position = Vector2.ZERO
			camera.zoom = Vector2.ONE
			camera.make_current()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func get_preview_viewport_size() -> Vector2:
	return Vector2(_viewport.size) if _viewport else Vector2.ZERO

func get_preview_child_count() -> int:
	return _tower_root.get_child_count() if _tower_root else 0

func get_preview_node_class() -> String:
	if _tower and is_instance_valid(_tower):
		return _tower.get_class()
	return "none"

func _force_one_safe_redraw(node: Node) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		canvas_item.visible = true
		canvas_item.queue_redraw()
	for child in node.get_children():
		_force_one_safe_redraw(child)


func _show_fallback(reason: String) -> void:
	fallback_reason = reason
	var debug_log := get_node_or_null("/root/DebugLog")
	if debug_log and debug_log.has_method("warn_once"):
		debug_log.warn_once("catalog_fallback_" + tower_id, "[TowerCatalogPreview] Fallback for '%s': %s" % [tower_id, reason])

	var label := Label.new()
	label.text = "[Fallback]\n%s\n%s" % [tower_id, reason]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.2))
	label.size = preview_size
	add_child(label)


func _draw() -> void:
	_s_redraw_count += 1
	if CatalogRenderGuardScript.catalog_safe_mode:
		return
	if not show_range_ring or _tower == null:
		return
	var rng: float = tower_config.get("range", 0.0)
	if "levels" in tower_config and tower_config["levels"].size() > 0:
		rng = tower_config["levels"][0].get("range", rng)
	if rng <= 0:
		return

	var sz := size
	var tower_screen := sz * 0.5 + _tower_world_position * camera_zoom
	var cx := tower_screen.x
	var cy := tower_screen.y
	var ring_r := clampf(rng * 0.35, 24, sz.x * 0.48)
	TowerVisualDrawUtils.safe_draw_circle(self, Vector2(cx, cy), ring_r, Color(0.15, 0.45, 0.6, 0.10))
	TowerVisualDrawUtils.safe_draw_arc(self, Vector2(cx, cy), ring_r, 0, TAU, 12, Color(0.15, 0.45, 0.6, 0.22), 1.0)

func _queue_redraw_if_changed() -> void:
	var new_hash := hash([tower_id, show_range_ring, show_projectile_preview, show_effects_preview, static_preview, _active])
	if new_hash != _last_draw_hash:
		_last_draw_hash = new_hash
		queue_redraw()
