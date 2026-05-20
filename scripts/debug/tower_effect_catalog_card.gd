# scripts/debug/tower_effect_catalog_card.gd
class_name TowerEffectCatalogCard
extends Node

const CatalogVfxModeScript = preload("res://scripts/debug/catalog_vfx_mode.gd")
const CatalogRenderGuardScript = preload("res://scripts/debug/catalog_render_guard.gd")

signal card_selected(tower_id: String, cfg: Dictionary)
signal card_hovered(tower_id: String, cfg: Dictionary, hovered: bool)

var tower_id: String = ""
var cfg: Dictionary = {}
var vfx_mode: String = CatalogVfxModeScript.DEFAULT_MODE

var _is_selected: bool = false
var _is_hovered: bool = false
var _card_panel: PanelContainer = null
var _vfx_badge_label: Label = null
var _preview: TowerCatalogPreview = null

var _normal_style: StyleBoxFlat = null
var _selected_style: StyleBoxFlat = null

func setup(p_panel: PanelContainer, p_tower_id: String, p_cfg: Dictionary, p_preview: TowerCatalogPreview = null) -> void:
	_card_panel = p_panel
	_preview = p_preview
	tower_id = p_tower_id
	cfg = p_cfg
	_card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_panel.gui_input.connect(_on_panel_gui_input)
	_card_panel.mouse_entered.connect(func() -> void:
		set_hovered(true)
		card_hovered.emit(tower_id, cfg, true)
	)
	_card_panel.mouse_exited.connect(func() -> void:
		set_hovered(false)
		card_hovered.emit(tower_id, cfg, false)
	)
	_update_preview_activity()

func bind_entry(p_tower_id: String, p_cfg: Dictionary, p_vfx_mode: String, selected: bool, hovered: bool = false) -> void:
	tower_id = p_tower_id
	cfg = p_cfg
	vfx_mode = p_vfx_mode
	_is_selected = selected
	_is_hovered = hovered
	set_selected(selected)
	_update_preview_activity()

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_selected.emit(tower_id, cfg)

func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _card_panel == null:
		return
	if selected and _selected_style:
		_card_panel.add_theme_stylebox_override("panel", _selected_style)
	elif _normal_style:
		_card_panel.add_theme_stylebox_override("panel", _normal_style)
	_update_preview_activity()

func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered
	_update_preview_activity()

func set_vfx_mode(mode: String) -> void:
	vfx_mode = mode
	_update_preview_activity()

func deactivate() -> void:
	_is_hovered = false
	_is_selected = false
	if _preview:
		_preview.disable_simulation()
		_preview.set_active(false)

func _update_preview_activity() -> void:
	if _preview == null:
		return
	var allow_vfx := CatalogVfxModeScript.allows_grid_vfx(vfx_mode, _is_selected, _is_hovered)
	var use_detail := _is_selected or _is_hovered
	_preview.set_active(true)
	if CatalogRenderGuardScript.catalog_safe_mode:
		_preview.set_static_preview(not use_detail)
	else:
		_preview.set_static_preview(not allow_vfx and not use_detail)
	_preview.set_vfx_enabled(allow_vfx and use_detail)

func set_vfx_badge(badge_text: String) -> void:
	if _vfx_badge_label == null:
		return
	_vfx_badge_label.text = badge_text
	match badge_text:
		"OK":       _vfx_badge_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		"Missing":  _vfx_badge_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
		"T1 Fallback": _vfx_badge_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2))
		"Legacy":   _vfx_badge_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
		_:          _vfx_badge_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func passes_filters(search: String, element_filter: String, tier_filter: String, attack_filter: String) -> bool:
	if search != "":
		var s := search.to_lower()
		if not (tower_id.to_lower().contains(s) or str(cfg.get("display_name", "")).to_lower().contains(s)):
			return false
	if element_filter != "all":
		var elements: Array = cfg.get("elements", [])
		if not elements.has(element_filter):
			return false
	if tier_filter != "all":
		var tier_map := {"t1": 1, "t2": 2, "t3": 3, "pure": 4}
		if cfg.get("tier", 0) != tier_map.get(tier_filter, -1):
			return false
	if attack_filter != "all":
		if str(cfg.get("attack_type", "")).to_lower() != attack_filter:
			return false
	return true
