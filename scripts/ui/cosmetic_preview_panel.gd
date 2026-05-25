extends PanelContainer

signal closed()

const SLOT_TOWER_SKIN := "tower_skin"
const SLOT_PROJECTILE_SKIN := "projectile_skin"
const SLOT_IMPACT_SKIN := "impact_skin"
const CosmeticPreviewCanvasScript := preload("res://scripts/ui/cosmetic_preview_canvas.gd")
const CosmeticTowerCatalogScript := preload("res://systems/cosmetics/cosmetic_tower_catalog.gd")

var _content: VBoxContainer = null
var _preview: Control = null
var _slot_container: VBoxContainer = null
var _tower_list_container: VBoxContainer = null
var _subtitle_label: Label = null
var _slot_lists: Dictionary = {}
var _preview_selection: Dictionary = {}
var _tower_configs: Array[Dictionary] = []
var _selected_tower_id: String = "basic_tower_t1"

func _ready() -> void:
	_build()
	_load_tower_catalog()
	refresh(false)

func refresh(sync_progress: bool = true) -> void:
	if _content == null:
		return
	if sync_progress:
		_sync_unlocks_from_progress()
	_reset_preview_selection_to_equipped()
	_refresh_tower_list()
	_clear_slot_lists()
	_add_slot(SLOT_TOWER_SKIN, "Tower Skin")
	_add_slot(SLOT_PROJECTILE_SKIN, "Projectile")
	_add_slot(SLOT_IMPACT_SKIN, "Impact")
	_update_preview()

func _build() -> void:
	custom_minimum_size = Vector2(1040, 590)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.045, 0.985)
	style.border_color = Color(0.22, 0.92, 1.0, 0.72)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.85, 1.0, 0.18)
	style.shadow_size = 18
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	margin.add_child(_content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_content.add_child(header)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)
	var title := Label.new()
	title.text = "COSMETIC LOADOUT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	title_col.add_child(title)
	var sub := Label.new()
	sub.text = "SELECT TOWER · VISUAL ONLY"
	_subtitle_label = sub
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84, 0.82))
	title_col.add_child(sub)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 34)
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	header.add_child(close_btn)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(body)

	var tower_panel := PanelContainer.new()
	tower_panel.custom_minimum_size = Vector2(230, 0)
	tower_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.72, 0.46, 1.0, 0.32)))
	body.add_child(tower_panel)
	var tower_margin := MarginContainer.new()
	tower_margin.add_theme_constant_override("margin_left", 12)
	tower_margin.add_theme_constant_override("margin_top", 14)
	tower_margin.add_theme_constant_override("margin_right", 12)
	tower_margin.add_theme_constant_override("margin_bottom", 14)
	tower_panel.add_child(tower_margin)
	var tower_box := VBoxContainer.new()
	tower_box.add_theme_constant_override("separation", 8)
	tower_margin.add_child(tower_box)
	var tower_title := Label.new()
	tower_title.text = "TOWERS"
	tower_title.add_theme_font_size_override("font_size", 13)
	tower_title.add_theme_color_override("font_color", Color(0.82, 0.70, 1.0))
	tower_box.add_child(tower_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower_box.add_child(scroll)
	_tower_list_container = VBoxContainer.new()
	_tower_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_tower_list_container)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(300, 0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.72, 1.0, 0.35)))
	body.add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 16)
	preview_margin.add_theme_constant_override("margin_top", 16)
	preview_margin.add_theme_constant_override("margin_right", 16)
	preview_margin.add_theme_constant_override("margin_bottom", 16)
	preview_panel.add_child(preview_margin)
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 10)
	preview_margin.add_child(preview_box)
	var preview_title := Label.new()
	preview_title.text = "LIVE PREVIEW"
	preview_title.add_theme_font_size_override("font_size", 13)
	preview_title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	preview_box.add_child(preview_title)
	_preview = CosmeticPreviewCanvasScript.new()
	_preview.registry = get_node_or_null("/root/CosmeticRegistry")
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_child(_preview)
	var preview_note := Label.new()
	preview_note.text = "All cosmetics are visual-only and never change tower stats."
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_note.add_theme_font_size_override("font_size", 11)
	preview_note.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82, 0.78))
	preview_box.add_child(preview_note)

	var loadout_panel := PanelContainer.new()
	loadout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.72, 0.22, 0.28)))
	body.add_child(loadout_panel)
	var loadout_margin := MarginContainer.new()
	loadout_margin.add_theme_constant_override("margin_left", 16)
	loadout_margin.add_theme_constant_override("margin_top", 16)
	loadout_margin.add_theme_constant_override("margin_right", 16)
	loadout_margin.add_theme_constant_override("margin_bottom", 16)
	loadout_panel.add_child(loadout_margin)
	_slot_container = VBoxContainer.new()
	_slot_container.add_theme_constant_override("separation", 12)
	loadout_margin.add_child(_slot_container)

func _clear_slot_lists() -> void:
	for slot in _slot_lists:
		var node: Node = _slot_lists[slot]
		if is_instance_valid(node):
			node.queue_free()
	_slot_lists.clear()

func _add_slot(slot: String, title_text: String) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 5)
	_slot_lists[slot] = wrap
	if _slot_container:
		_slot_container.add_child(wrap)
	else:
		_content.add_child(wrap)
	var title := Label.new()
	title.text = title_text.to_upper()
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	wrap.add_child(title)
	wrap.add_child(_make_row(slot, "", "Default", true))
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if registry == null:
		return
	var found_any := false
	for cfg in registry.get_for_tower_slot(_selected_tower_id, slot):
		found_any = true
		wrap.add_child(_make_row(slot, str(cfg.get("id", "")), str(cfg.get("display_name", cfg.get("id", ""))), _is_unlocked(str(cfg.get("id", "")))))
	if not found_any:
		var empty := Label.new()
		empty.text = "No cosmetics for this tower yet."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.52, 0.60, 0.68, 0.72))
		wrap.add_child(empty)

func _make_row(slot: String, cosmetic_id: String, label_text: String, available: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(cosmetic_id, available))
	panel.mouse_entered.connect(func() -> void:
		if available:
			_preview_selection[slot] = cosmetic_id
			_update_preview()
	)
	panel.mouse_exited.connect(func() -> void:
		_preview_selection[slot] = _equipped(slot)
		_update_preview()
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(5, 34)
	swatch.color = _cosmetic_color(cosmetic_id, available)
	row.add_child(swatch)
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	row.add_child(name_col)
	var name := Label.new()
	name.text = label_text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 13)
	name.add_theme_color_override("font_color", Color.WHITE if available else Color(0.44, 0.48, 0.54))
	name_col.add_child(name)
	var meta := Label.new()
	meta.text = "DEFAULT" if cosmetic_id == "" else ("UNLOCKED" if available else "LOCKED")
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", _cosmetic_color(cosmetic_id, available))
	name_col.add_child(meta)
	var btn := Button.new()
	var equipped := _equipped(slot) == cosmetic_id
	btn.text = "EQUIPPED" if equipped else ("EQUIP" if cosmetic_id != "" else "USE")
	btn.custom_minimum_size = Vector2(90, 30)
	btn.disabled = equipped or not available
	btn.pressed.connect(func() -> void:
		var inventory := get_node_or_null("/root/CosmeticInventory")
		if inventory != null:
			inventory.equip(_selected_tower_id, slot, cosmetic_id)
		_preview_selection[slot] = cosmetic_id
		refresh()
	)
	row.add_child(btn)
	return panel

func _update_preview() -> void:
	if _preview == null:
		return
	_preview.registry = get_node_or_null("/root/CosmeticRegistry")
	if _preview.has_method("set_tower_config"):
		_preview.set_tower_config(_selected_tower_cfg())
	_preview.set_cosmetics(
		str(_preview_selection.get(SLOT_TOWER_SKIN, _equipped(SLOT_TOWER_SKIN))),
		str(_preview_selection.get(SLOT_PROJECTILE_SKIN, _equipped(SLOT_PROJECTILE_SKIN))),
		str(_preview_selection.get(SLOT_IMPACT_SKIN, _equipped(SLOT_IMPACT_SKIN)))
	)

func _equipped(slot: String) -> String:
	var inventory := get_node_or_null("/root/CosmeticInventory")
	if inventory != null:
		return str(inventory.get_equipped(_selected_tower_id, slot))
	return ""

func _is_unlocked(cosmetic_id: String) -> bool:
	var inventory := get_node_or_null("/root/CosmeticInventory")
	return inventory != null and inventory.is_unlocked(cosmetic_id)

func _sync_unlocks_from_progress() -> void:
	var reward_service := get_node_or_null("/root/CosmeticRewardService")
	if reward_service != null and reward_service.has_method("process_current_progress"):
		reward_service.process_current_progress()

func _reset_preview_selection_to_equipped() -> void:
	_preview_selection[SLOT_TOWER_SKIN] = _equipped(SLOT_TOWER_SKIN)
	_preview_selection[SLOT_PROJECTILE_SKIN] = _equipped(SLOT_PROJECTILE_SKIN)
	_preview_selection[SLOT_IMPACT_SKIN] = _equipped(SLOT_IMPACT_SKIN)

func _load_tower_catalog() -> void:
	_tower_configs = CosmeticTowerCatalogScript.load_towers()
	if _tower_configs.is_empty():
		_tower_configs = [{"id": _selected_tower_id, "display_name": "Neutral Arrow Tower", "visual_type": "basic", "tier": 1}]
	var has_selected := false
	for cfg in _tower_configs:
		if str(cfg.get("id", "")) == _selected_tower_id:
			has_selected = true
			break
	if not has_selected:
		_selected_tower_id = str(_tower_configs[0].get("id", _selected_tower_id))

func _refresh_tower_list() -> void:
	if _tower_list_container == null:
		return
	for child in _tower_list_container.get_children():
		child.queue_free()
	for cfg in _tower_configs:
		_tower_list_container.add_child(_make_tower_row(cfg))
	if _subtitle_label:
		_subtitle_label.text = "%s · VISUAL ONLY" % CosmeticTowerCatalogScript.display_name(_selected_tower_cfg()).to_upper()

func _make_tower_row(cfg: Dictionary) -> Control:
	var tower_id := str(cfg.get("id", ""))
	var selected := tower_id == _selected_tower_id
	var btn := Button.new()
	btn.text = CosmeticTowerCatalogScript.display_name(cfg)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 12)
	btn.disabled = selected
	btn.add_theme_color_override("font_color", Color.WHITE if selected else Color(0.76, 0.84, 0.92))
	btn.add_theme_stylebox_override("normal", _tower_button_style(selected))
	btn.add_theme_stylebox_override("hover", _tower_button_style(true))
	btn.add_theme_stylebox_override("pressed", _tower_button_style(true))
	btn.add_theme_stylebox_override("disabled", _tower_button_style(true))
	btn.pressed.connect(func() -> void:
		_selected_tower_id = tower_id
		refresh(false)
	)
	return btn

func _selected_tower_cfg() -> Dictionary:
	for cfg in _tower_configs:
		if str(cfg.get("id", "")) == _selected_tower_id:
			return cfg
	return {"id": _selected_tower_id, "display_name": _selected_tower_id, "visual_type": "basic", "tier": 1}

func _tower_button_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95) if selected else Color(0.028, 0.038, 0.060, 0.74)
	style.border_color = Color(0.72, 0.46, 1.0, 0.70) if selected else Color(0.22, 0.28, 0.36, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _panel_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.026, 0.038, 0.064, 0.94)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _row_style(cosmetic_id: String, available: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.052, 0.082, 0.92) if available else Color(0.024, 0.030, 0.044, 0.84)
	style.border_color = _cosmetic_color(cosmetic_id, available)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _cosmetic_color(cosmetic_id: String, available: bool) -> Color:
	if cosmetic_id == "":
		return Color(0.45, 0.56, 0.66, 0.75)
	if not available:
		return Color(0.28, 0.31, 0.36, 0.75)
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if registry != null:
		var cfg: Dictionary = registry.get_cosmetic(cosmetic_id)
		if not cfg.is_empty():
			return registry.get_rarity_color(str(cfg.get("rarity", "common")))
	return Color(0.45, 0.95, 1.0, 0.85)
