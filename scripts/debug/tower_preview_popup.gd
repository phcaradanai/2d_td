class_name TowerPreviewPopup
extends Control

const DEFAULT_WARNING_TEXT := "Popup preview is transient and model-only until toggles are enabled."
const POPUP_MAX_SIZE := Vector2(1040, 620)
const POPUP_VIEWPORT_RATIO := Vector2(0.78, 0.70)
const POPUP_MIN_SIZE := Vector2(640, 420)
const POPUP_SAFE_MARGIN := Vector2(24, 24)

const CatalogPreviewModeScript = preload("res://scripts/debug/catalog_preview_mode.gd")
const TowerPreviewResolverScript = preload("res://scripts/debug/tower_preview_resolver.gd")

signal close_requested

@onready var _popup_card: PanelContainer = $PopupCard
@onready var _popup_title: Label = $PopupCard/PopupMargin/PopupVBox/PopupHeader/PopupTitle
@onready var _close_button: Button = $PopupCard/PopupMargin/PopupVBox/PopupHeader/CloseButton
@onready var _preview_root: Control = $PopupCard/PopupMargin/PopupVBox/PopupBody/PreviewStage/PreviewStageMargin/PreviewRoot
@onready var _preview_info_title: Label = $PopupCard/PopupMargin/PopupVBox/PopupBody/PreviewInfoPanel/StatSummary
@onready var _preview_info_body: Label = $PopupCard/PopupMargin/PopupVBox/PopupBody/PreviewInfoPanel/EffectDescription
@onready var _warning_label: Label = $PopupCard/PopupMargin/PopupVBox/PopupBody/PreviewInfoPanel/WarningLabel
@onready var _model_toggle: CheckButton = $PopupCard/PopupMargin/PopupVBox/PopupFooter/ModelToggle
@onready var _vfx_toggle: CheckButton = $PopupCard/PopupMargin/PopupVBox/PopupFooter/VfxToggle
@onready var _projectile_toggle: CheckButton = $PopupCard/PopupMargin/PopupVBox/PopupFooter/ProjectileToggle
@onready var _impact_toggle: CheckButton = $PopupCard/PopupMargin/PopupVBox/PopupFooter/ImpactToggle
@onready var _auto_play_toggle: CheckButton = $PopupCard/PopupMargin/PopupVBox/PopupFooter/AutoPlayToggle
@onready var _pause_button: Button = $PopupCard/PopupMargin/PopupVBox/PopupFooter/PauseButton
@onready var _replay_button: Button = $PopupCard/PopupMargin/PopupVBox/PopupFooter/ReplayButton

var tower_id: String = ""
var tower_config: Dictionary = {}
var preview_data: Dictionary = {}
var popup_open: bool = false
var current_preview: TowerCatalogPreview = null
var model_enabled: bool = true
var vfx_enabled: bool = false
var projectile_enabled: bool = false
var impact_enabled: bool = false
var auto_play_enabled: bool = false
var preview_paused: bool = true
var _low_fps_guard_active: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_compact_control_text()
	_close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	_model_toggle.toggled.connect(set_model_enabled)
	_vfx_toggle.toggled.connect(set_vfx_enabled)
	_projectile_toggle.toggled.connect(set_projectile_preview_enabled)
	_impact_toggle.toggled.connect(set_impact_preview_enabled)
	_auto_play_toggle.toggled.connect(set_auto_play)
	_pause_button.pressed.connect(func() -> void:
		if preview_paused:
			play_preview()
		else:
			pause_preview()
	)
	_replay_button.pressed.connect(replay_preview)
	_sync_toggle_labels()
	_warning_label.text = DEFAULT_WARNING_TEXT
	get_viewport().size_changed.connect(func() -> void:
		if popup_open:
			_fit_to_viewport()
			call_deferred("_resize_preview_viewport")
	)
	_fit_to_viewport()
	set_process(false)
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and popup_open:
		_fit_to_viewport()
		call_deferred("_resize_preview_viewport")

func open_for_tower(p_tower_id: String, p_tower_config: Dictionary) -> void:
	tower_id = p_tower_id
	tower_config = p_tower_config.duplicate(true)
	preview_data = TowerPreviewResolverScript.resolve(tower_id, tower_config)
	popup_open = true
	visible = true
	_refresh_info_panel()
	_clear_preview_nodes()
	_low_fps_guard_active = false
	_warning_label.text = DEFAULT_WARNING_TEXT
	_fit_to_viewport()
	set_process(true)
	await get_tree().process_frame
	_resize_preview_viewport()
	_spawn_selected_model()
	_apply_preview_toggles()

func close_popup() -> void:
	_clear_preview_nodes()
	popup_open = false
	set_process(false)
	hide()

func stop_preview() -> void:
	_clear_preview_nodes()
	popup_open = false
	set_process(false)

func play_preview() -> void:
	auto_play_enabled = true
	preview_paused = false
	if current_preview:
		current_preview.play_preview()
	_sync_toggle_labels()

func pause_preview() -> void:
	preview_paused = true
	if current_preview:
		current_preview.pause_preview()
	_sync_toggle_labels()

func set_auto_play(enabled: bool) -> void:
	auto_play_enabled = enabled
	if enabled:
		play_preview()
	else:
		pause_preview()
	_sync_toggle_labels()

func set_model_enabled(enabled: bool) -> void:
	model_enabled = enabled
	if current_preview and is_instance_valid(current_preview):
		if not enabled:
			_clear_preview_nodes()
	if enabled and current_preview == null and tower_id != "":
		_spawn_selected_model()
		_apply_preview_toggles()
	_sync_toggle_labels()

func set_vfx_enabled(enabled: bool) -> void:
	vfx_enabled = enabled
	if current_preview and is_instance_valid(current_preview):
		current_preview.set_vfx_enabled(enabled)
	_sync_toggle_labels()

func set_projectile_preview_enabled(enabled: bool) -> void:
	projectile_enabled = enabled
	if current_preview and is_instance_valid(current_preview):
		current_preview.set_projectile_preview_enabled(enabled)
	_sync_toggle_labels()

func set_impact_preview_enabled(enabled: bool) -> void:
	impact_enabled = enabled
	if current_preview and is_instance_valid(current_preview):
		current_preview.set_impact_preview_enabled(enabled)
	_sync_toggle_labels()

func replay_preview() -> void:
	if tower_id == "":
		return
	_clear_preview_nodes()
	_fit_to_viewport()
	await get_tree().process_frame
	_resize_preview_viewport()
	_spawn_selected_model()
	_apply_preview_toggles()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_requested.emit()

func _process(delta: float) -> void:
	if not popup_open:
		return
	var fps := Engine.get_frames_per_second()
	if fps < 45:
		if not _low_fps_guard_active:
			_low_fps_guard_active = true
			if vfx_enabled:
				set_vfx_enabled(false)
			if projectile_enabled:
				set_projectile_preview_enabled(false)
			if impact_enabled:
				set_impact_preview_enabled(false)
		_warning_label.text = "Low FPS: preview effects disabled."
	else:
		if _low_fps_guard_active:
			_low_fps_guard_active = false
			_warning_label.text = DEFAULT_WARNING_TEXT

func _spawn_selected_model() -> void:
	if tower_config.is_empty():
		_show_preview_fallback("missing tower data")
		return
	var preview := TowerCatalogPreview.new()
	preview.tower_id = tower_id
	preview.tower_config = tower_config
	var stage_size := _preview_root.size
	if stage_size.x < 64.0 or stage_size.y < 64.0:
		stage_size = Vector2(720, 440)
	preview.preview_size = Vector2(maxf(320.0, stage_size.x), maxf(220.0, stage_size.y))
	preview.camera_zoom = 1.0
	preview.show_range_ring = true
	preview.show_projectile_preview = projectile_enabled
	preview.show_effects_preview = vfx_enabled
	preview.show_impact_preview = impact_enabled
	preview.static_preview = true
	preview.preview_paused = preview_paused
	preview.custom_minimum_size = preview.preview_size
	preview.visible = model_enabled
	_preview_root.add_child(preview)
	current_preview = preview
	CatalogPreviewModeScript.mark_preview_tree(preview, true, true)
	preview.resize_preview_viewport(preview.preview_size)
	if not model_enabled:
		preview.set_active(false)
	elif preview_paused:
		preview.pause_preview()
	else:
		preview.play_preview()

func _apply_preview_toggles() -> void:
	set_model_enabled(model_enabled)
	set_vfx_enabled(vfx_enabled)
	set_projectile_preview_enabled(projectile_enabled)
	set_impact_preview_enabled(impact_enabled)
	if auto_play_enabled:
		play_preview()
	else:
		pause_preview()
	_sync_toggle_labels()

func _clear_preview_nodes() -> void:
	if current_preview and is_instance_valid(current_preview):
		if current_preview.has_method("stop_preview"):
			current_preview.stop_preview()
		current_preview.set_process(false)
		current_preview.set_physics_process(false)
		current_preview.set_process_input(false)
		current_preview.queue_free()
	current_preview = null

func _refresh_info_panel() -> void:
	_popup_title.text = _get_display_name()
	_preview_info_title.text = "%s | %s | %s" % [
		_get_display_name(),
		_get_tier_text(),
		_get_element_text(),
	]
	_preview_info_body.text = "\n".join([
		"ID: %s" % tower_id,
		"Role: %s" % _get_role_text(),
		"Attack: %s" % str(tower_config.get("attack_type", "—")),
		"Visual: %s" % str(tower_config.get("visual_type", "—")),
		"Model: %s" % ("On" if model_enabled else "Off"),
		"Attack VFX: %s" % _preview_capability_text("has_attack_vfx", vfx_enabled, "not mapped"),
		"Projectile: %s" % _preview_capability_text("has_projectile", projectile_enabled, "not used by this tower"),
		"Impact: %s" % _preview_capability_text("has_impact", impact_enabled, "not configured"),
		_debug_preview_info(),
	])
	_warning_label.text = "Popup preview is temporary and model-only until toggles are enabled."

func _preview_capability_text(key: String, enabled: bool, unavailable_text: String) -> String:
	if not bool(preview_data.get(key, false)):
		return unavailable_text
	return "On" if enabled else "Off"

func _sync_toggle_labels() -> void:
	_model_toggle.text = "Model On" if model_enabled else "Model Off"
	_vfx_toggle.text = "VFX On" if vfx_enabled else "VFX Off"
	_projectile_toggle.text = "Proj On" if projectile_enabled else "Proj Off"
	_impact_toggle.text = "Impact On" if impact_enabled else "Impact Off"
	_auto_play_toggle.text = "Auto On" if auto_play_enabled else "Auto Off"
	_pause_button.text = "Resume" if preview_paused else "Pause"
	if popup_open:
		_refresh_info_panel()

func _show_preview_fallback(reason: String) -> void:
	var label := Label.new()
	label.name = "PreviewFallback"
	label.text = "Preview unavailable\n%s\n%s" % [_get_display_name(), reason]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.35))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_root.add_child(label)

func _fit_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	var available_size := Vector2(
		maxf(320.0, viewport_size.x - POPUP_SAFE_MARGIN.x * 2.0),
		maxf(280.0, viewport_size.y - POPUP_SAFE_MARGIN.y * 2.0)
	)
	var popup_size := Vector2(
		minf(POPUP_MAX_SIZE.x, viewport_size.x * POPUP_VIEWPORT_RATIO.x),
		minf(POPUP_MAX_SIZE.y, viewport_size.y * POPUP_VIEWPORT_RATIO.y)
	)
	if available_size.x >= POPUP_MIN_SIZE.x:
		popup_size.x = maxf(popup_size.x, POPUP_MIN_SIZE.x)
	if available_size.y >= POPUP_MIN_SIZE.y:
		popup_size.y = maxf(popup_size.y, POPUP_MIN_SIZE.y)
	popup_size.x = minf(popup_size.x, available_size.x)
	popup_size.y = minf(popup_size.y, available_size.y)
	position = Vector2.ZERO
	_popup_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_popup_card.custom_minimum_size = Vector2.ZERO
	_popup_card.size = popup_size
	_popup_card.offset_left = 0.0
	_popup_card.offset_top = 0.0
	_popup_card.offset_right = popup_size.x
	_popup_card.offset_bottom = popup_size.y
	_popup_card.position = Vector2(
		maxf(POPUP_SAFE_MARGIN.x, floor((viewport_size.x - popup_size.x) * 0.5)),
		maxf(POPUP_SAFE_MARGIN.y, floor((viewport_size.y - popup_size.y) * 0.5))
	)
	_apply_responsive_density(popup_size)

func _resize_preview_viewport() -> void:
	var stage_size: Vector2 = _preview_root.size
	if stage_size.x < 64.0 or stage_size.y < 64.0:
		stage_size = Vector2(720, 440)
	if current_preview and is_instance_valid(current_preview) and current_preview.has_method("resize_preview_viewport"):
		current_preview.resize_preview_viewport(stage_size)

func _debug_preview_info() -> String:
	if not OS.is_debug_build():
		return ""
	var viewport_size := Vector2.ZERO
	var child_count := 0
	var node_class := "none"
	if current_preview and is_instance_valid(current_preview):
		child_count = current_preview.get_preview_child_count() if current_preview.has_method("get_preview_child_count") else current_preview.get_child_count()
		viewport_size = current_preview.get_preview_viewport_size() if current_preview.has_method("get_preview_viewport_size") else Vector2.ZERO
		node_class = current_preview.get_preview_node_class() if current_preview.has_method("get_preview_node_class") else current_preview.get_class()
	return "\nDebug:\nTower scene: %s\nVisual script: %s\nNode: %s\nPreview children: %d\nViewport: %s" % [
		str(preview_data.get("tower_scene_path", "")),
		str(preview_data.get("visual_script_path", "")),
		node_class,
		child_count,
		str(viewport_size),
	]

func _get_display_name() -> String:
	var display_name := str(tower_config.get("display_name", tower_config.get("name", tower_id)))
	return display_name if display_name != "" else tower_id

func _get_tier_text() -> String:
	var tier: int = int(tower_config.get("tier", 1))
	if tier == 4:
		return "Pure"
	if tier <= 3:
		return "T%d" % tier
	return "T%d" % tier

func _get_element_text() -> String:
	var elements: Array = tower_config.get("elements", [])
	if elements.is_empty():
		return "—"
	var labels: Array[String] = []
	for element in elements:
		labels.append(str(element).capitalize())
	return "+".join(labels)

func _get_role_text() -> String:
	var role := str(tower_config.get("support_type", ""))
	if role == "":
		role = str(tower_config.get("attack_type", ""))
	if role == "":
		role = str(tower_config.get("visual_type", ""))
	if role == "":
		role = str(tower_config.get("combo_type", ""))
	return role.capitalize() if role != "" else "—"

func _apply_compact_control_text() -> void:
	_preview_info_title.clip_text = true
	_preview_info_body.clip_text = true
	_warning_label.clip_text = true
	var controls: Array[Control] = [
		_model_toggle,
		_vfx_toggle,
		_projectile_toggle,
		_impact_toggle,
		_auto_play_toggle,
		_pause_button,
		_replay_button,
		_close_button,
	]
	for control in controls:
		control.add_theme_font_size_override("font_size", 12)

func _apply_responsive_density(popup_size: Vector2) -> void:
	var compact := popup_size.x < 900.0 or popup_size.y < 560.0
	var title_size := 18 if compact else 21
	var summary_size := 13 if compact else 15
	var body_size := 11 if compact else 13
	var control_size := 10 if compact else 12
	_preview_info_title.max_lines_visible = 2
	_preview_info_body.max_lines_visible = 12 if compact else 18
	_warning_label.max_lines_visible = 2 if compact else 3
	_popup_title.add_theme_font_size_override("font_size", title_size)
	_preview_info_title.add_theme_font_size_override("font_size", summary_size)
	_preview_info_body.add_theme_font_size_override("font_size", body_size)
	_warning_label.add_theme_font_size_override("font_size", body_size)
	var controls: Array[Control] = [
		_model_toggle,
		_vfx_toggle,
		_projectile_toggle,
		_impact_toggle,
		_auto_play_toggle,
		_pause_button,
		_replay_button,
		_close_button,
	]
	for control in controls:
		control.add_theme_font_size_override("font_size", control_size)
