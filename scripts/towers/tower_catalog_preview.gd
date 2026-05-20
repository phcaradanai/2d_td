class_name TowerCatalogPreview
extends Control

const CatalogPreviewMode = preload("res://scripts/debug/catalog_preview_mode.gd")

## Displays a real Tower scene inside a SubViewport so the catalog preview
## matches actual gameplay visuals, including idle animation and element glow.

var tower_id: String = ""
var tower_config: Dictionary = {}
@export var preview_size: Vector2 = Vector2(340, 220)
@export var camera_zoom: float = 1.5
@export var show_range_ring: bool = true
@export var show_projectile_preview: bool = false
@export var show_effects_preview: bool = false
@export var static_preview: bool = true
@export var preview_paused: bool = false:
	set(value):
		_preview_paused = value
		if _fx_layer:
			_fx_layer.paused = value
	get:
		return _preview_paused
var fallback_reason: String = ""

const TOWER_SCENE := preload("res://scenes/towers/Tower.tscn")

var _viewport: SubViewport = null
var _tower: Node2D = null
var _texture_rect: TextureRect = null
var _fx_layer: PreviewFxLayer = null
var _tower_world_position := Vector2.ZERO
var _preview_paused := false
var _active := true

class PreviewFxLayer:
	extends Node2D

	var config: Dictionary = {}
	var preview_projectile := false
	var preview_effects := false
	var paused := false
	var start_pos := Vector2.ZERO
	var target_pos := Vector2(120, 0)
	var _shot_timer := 0.25
	var _projectile_t := -1.0
	var _impact_t := -1.0
	var _pulse_time := 0.0

	func configure(p_config: Dictionary, p_start: Vector2, p_target: Vector2) -> void:
		config = p_config
		start_pos = p_start
		target_pos = p_target
		queue_redraw()

	func _process(delta: float) -> void:
		if paused or PerformanceFirebreak.disable_catalog_vfx:
			return
		_pulse_time += delta
		if _is_support_style():
			queue_redraw()
			return
		if preview_projectile:
			_shot_timer -= delta
			if _shot_timer <= 0.0 and _projectile_t < 0.0:
				_projectile_t = 0.0
				_shot_timer = 1.45
			if _projectile_t >= 0.0:
				_projectile_t += delta / 0.72
				if _projectile_t >= 1.0:
					_projectile_t = -1.0
					_impact_t = 0.0
			if _impact_t >= 0.0:
				_impact_t += delta / 0.45
				if _impact_t >= 1.0:
					_impact_t = -1.0
		queue_redraw()

	func _draw() -> void:
		if preview_projectile or preview_effects:
			_draw_fake_target()
		if preview_effects or _is_support_style():
			_draw_aura_or_support_preview()
		if preview_projectile and not _is_support_style():
			_draw_projectile_preview()
		if _impact_t >= 0.0:
			_draw_impact_preview()

	func _draw_fake_target() -> void:
		var c := _style_color()
		draw_arc(target_pos, 10.0, 0, TAU, 24, Color(c.r, c.g, c.b, 0.45), 1.4)
		draw_line(target_pos + Vector2(-14, 0), target_pos + Vector2(14, 0), Color(0.75, 0.95, 1.0, 0.45), 1.0)
		draw_line(target_pos + Vector2(0, -14), target_pos + Vector2(0, 14), Color(0.75, 0.95, 1.0, 0.45), 1.0)

	func _draw_aura_or_support_preview() -> void:
		var c := _style_color()
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 3.0)
		if _is_support_style():
			var r := 42.0 + pulse * 14.0
			draw_arc(start_pos, r, 0, TAU, 48, Color(c.r, c.g, c.b, 0.38), 2.0)
			draw_arc(start_pos, r * 0.68, 0, TAU, 36, Color(0.85, 0.95, 1.0, 0.20), 1.2)
			if str(config.get("visual_type", "")).to_lower() == "trickery" or str(config.get("attack_type", "")).contains("clone"):
				var ghost_pos := target_pos + Vector2(-18, -4)
				draw_rect(Rect2(ghost_pos - Vector2(14, 18), Vector2(28, 36)), Color(0.55, 0.35, 1.0, 0.12), false, 2.0)
				draw_arc(ghost_pos, 20.0 + pulse * 8.0, 0, TAU, 36, Color(0.75, 0.55, 1.0, 0.42), 1.6)
			return
		draw_arc(start_pos, 34.0 + pulse * 8.0, 0, TAU, 36, Color(c.r, c.g, c.b, 0.28), 1.5)

	func _draw_projectile_preview() -> void:
		if _projectile_t < 0.0:
			return
		var c := _style_color()
		var p := start_pos.lerp(target_pos, clampf(_projectile_t, 0.0, 1.0))
		var dir := (target_pos - start_pos).normalized()
		var attack_type := str(config.get("attack_type", "single"))
		var visual_type := str(config.get("visual_type", "basic"))
		draw_circle(start_pos + dir * 22.0, 6.0 * (1.0 - _projectile_t), Color(c.r, c.g, c.b, 0.55))
		if attack_type == "splash" or visual_type == "cannon":
			draw_circle(p, 7.0, c)
			draw_line(p - dir * 24.0, p - dir * 4.0, Color(c.r, c.g, c.b, 0.36), 4.0)
		elif attack_type == "slow":
			draw_circle(p, 5.0, Color(c.r, c.g, c.b, 0.9))
			draw_arc(p, 10.0, 0, TAU, 20, Color(0.7, 0.9, 1.0, 0.45), 1.0)
		elif visual_type == "light" or visual_type == "laser":
			draw_line(start_pos, p, Color(c.r, c.g, c.b, 0.55), 3.0)
			draw_circle(p, 4.5, Color(1.0, 0.96, 0.55, 1.0))
		elif visual_type == "darkness":
			draw_circle(p, 6.0, c)
			draw_arc(p, 12.0, _pulse_time, _pulse_time + PI * 1.4, 18, Color(0.9, 0.55, 1.0, 0.45), 1.4)
		else:
			draw_line(p - dir * 18.0, p + dir * 8.0, c, 3.0)
			draw_circle(p + dir * 8.0, 3.0, Color(0.9, 1.0, 1.0, 0.95))

	func _draw_impact_preview() -> void:
		var c := _style_color()
		var t := clampf(_impact_t, 0.0, 1.0)
		var radius := lerpf(4.0, 28.0, t)
		draw_arc(target_pos, radius, 0, TAU, 36, Color(c.r, c.g, c.b, 0.65 * (1.0 - t)), 2.0)
		draw_circle(target_pos, 8.0 * (1.0 - t), Color(c.r, c.g, c.b, 0.28 * (1.0 - t)))

	func _is_support_style() -> bool:
		var attack_type := str(config.get("attack_type", "")).to_lower()
		var support_type := str(config.get("support_type", "")).to_lower()
		return attack_type.contains("support") or support_type != "" or attack_type == "aura"

	func _style_color() -> Color:
		var attack_type := str(config.get("attack_type", "single")).to_lower()
		var visual_type := str(config.get("visual_type", "")).to_lower()
		var elements: Array = config.get("elements", [])
		if visual_type == "trickery" or attack_type.contains("clone"):
			return Color(0.68, 0.42, 1.0, 1.0)
		if attack_type == "splash" or visual_type == "cannon" or visual_type == "fire" or visual_type == "earth":
			return Color(1.0, 0.52, 0.18, 1.0)
		if attack_type == "slow" or visual_type == "water":
			return Color(0.25, 0.68, 1.0, 1.0)
		if visual_type == "light" or elements.has("light"):
			return Color(1.0, 0.88, 0.24, 1.0)
		if visual_type == "darkness" or elements.has("darkness"):
			return Color(0.62, 0.22, 0.9, 1.0)
		if visual_type == "nature" or elements.has("nature"):
			return Color(0.35, 1.0, 0.42, 1.0)
		return Color(0.45, 0.92, 1.0, 1.0)


func _ready() -> void:
	_setup_viewport()
	_spawn_preview_tower()
	custom_minimum_size = preview_size
	size = preview_size
	set_static_preview(static_preview)
	set_active(_active)


func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(preview_size.x), int(preview_size.y))
	_viewport.transparent_bg = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var cam := Camera2D.new()
	cam.position = Vector2(0, -2)
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	cam.enabled = true
	_viewport.add_child(cam)

	# Dark grid background plane inside the viewport
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 1)
	bg.size = Vector2(1200, 900)
	bg.position = Vector2(-600, -450)
	bg.z_index = -100
	_viewport.add_child(bg)

	_fx_layer = PreviewFxLayer.new()
	_fx_layer.z_index = 80
	_fx_layer.preview_projectile = show_projectile_preview
	_fx_layer.preview_effects = show_effects_preview
	_fx_layer.paused = preview_paused
	_viewport.add_child(_fx_layer)

	add_child(_viewport)

	_texture_rect = TextureRect.new()
	_texture_rect.texture = _viewport.get_texture()
	_texture_rect.custom_minimum_size = preview_size
	_texture_rect.size = preview_size
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_texture_rect)


func _spawn_preview_tower() -> void:
	if tower_config.is_empty():
		_show_fallback("no config data")
		return

	_tower = TOWER_SCENE.instantiate()
	if _tower == null or not _tower.has_method("setup_preview"):
		_show_fallback("Tower scene missing setup_preview method")
		return

	_viewport.add_child(_tower)
	_tower_world_position = _get_tower_world_position()
	_tower.position = _tower_world_position
	_tower.setup_preview(tower_config)
	CatalogPreviewMode.mark_preview_tree(_tower, true, false)
	_configure_fx_layer()

func set_preview_options(p_show_range: bool, p_show_projectile: bool, p_show_effects: bool, p_paused: bool = false) -> void:
	show_range_ring = p_show_range
	show_projectile_preview = p_show_projectile
	show_effects_preview = p_show_effects
	preview_paused = p_paused
	if _fx_layer:
		_fx_layer.preview_projectile = show_projectile_preview
		_fx_layer.preview_effects = show_effects_preview
		_fx_layer.paused = preview_paused
	queue_redraw()

func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if _fx_layer:
		_fx_layer.set_process(active and not static_preview)
		_fx_layer.paused = (not active) or preview_paused or static_preview
	if _tower:
		CatalogPreviewMode.set_static_preview(_tower, static_preview or not active)
		CatalogPreviewMode.set_selected_demo(_tower, active and not static_preview)
		if _tower.has_method("mark_visual_dirty"):
			_tower.mark_visual_dirty()
		_set_processing_recursive(_tower, active and not static_preview)

func set_static_preview(enabled: bool) -> void:
	static_preview = enabled
	if enabled:
		show_projectile_preview = false
		show_effects_preview = false
		preview_paused = true
		if _fx_layer:
			_fx_layer.preview_projectile = false
			_fx_layer.preview_effects = false
	else:
		preview_paused = false
	if _tower:
		CatalogPreviewMode.set_static_preview(_tower, enabled)
		CatalogPreviewMode.set_selected_demo(_tower, not enabled)
		if _tower.has_method("mark_visual_dirty"):
			_tower.mark_visual_dirty()
	set_active(_active)
	queue_redraw()

func set_vfx_enabled(enabled: bool) -> void:
	if static_preview and enabled:
		set_static_preview(false)
	show_projectile_preview = enabled
	show_effects_preview = enabled
	if _fx_layer:
		_fx_layer.preview_projectile = enabled
		_fx_layer.preview_effects = enabled
		_fx_layer.paused = (not enabled) or preview_paused or (not _active)
	queue_redraw()

func get_vfx_viewport() -> SubViewport:
	return _viewport

func disable_simulation() -> void:
	if _fx_layer:
		_fx_layer.preview_projectile = false
		_fx_layer.preview_effects = false
		_fx_layer.paused = true
		_fx_layer.set_process(false)

func _set_processing_recursive(node: Node, enabled: bool) -> void:
	node.set_process(enabled)
	node.set_physics_process(false)
	for child in node.get_children():
		_set_processing_recursive(child, enabled)

func _get_tower_world_position() -> Vector2:
	if show_projectile_preview or show_effects_preview:
		return Vector2(-preview_size.x / maxf(camera_zoom, 0.1) * 0.18, 8)
	return Vector2(0, 6)

func _get_fake_target_world_position() -> Vector2:
	return Vector2(preview_size.x / maxf(camera_zoom, 0.1) * 0.30, 4)

func _configure_fx_layer() -> void:
	if _fx_layer == null:
		return
	_fx_layer.configure(tower_config, _tower_world_position, _get_fake_target_world_position())
	_fx_layer.preview_projectile = show_projectile_preview
	_fx_layer.preview_effects = show_effects_preview
	_fx_layer.paused = preview_paused


func _show_fallback(reason: String) -> void:
	fallback_reason = reason
	DebugLog.warn_once("catalog_fallback_" + tower_id, "[TowerCatalogPreview] Fallback for '%s': %s" % [tower_id, reason])

	var label := Label.new()
	label.text = "[Fallback]\n%s\n%s" % [tower_id, reason]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.2))
	label.size = preview_size
	add_child(label)


func _draw() -> void:
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
	draw_circle(Vector2(cx, cy), ring_r, Color(0.15, 0.45, 0.6, 0.10))
	draw_arc(Vector2(cx, cy), ring_r, 0, TAU, 48, Color(0.15, 0.45, 0.6, 0.22), 1.0)
