extends PanelContainer

signal closed()

const SLOT_TOWER_SKIN     := "tower_skin"
const SLOT_PROJECTILE_SKIN := "projectile_skin"
const SLOT_IMPACT_SKIN    := "impact_skin"
const SLOT_AURA_SKIN      := "aura_skin"
const SLOT_ATTACK_VFX_SKIN := "attack_vfx_skin"
const CosmeticPreviewCanvasScript := preload("res://scripts/ui/cosmetic_preview_canvas.gd")
const CosmeticTowerCatalogScript  := preload("res://systems/cosmetics/cosmetic_tower_catalog.gd")

var _content: VBoxContainer       = null
var _preview: Control             = null
var _slot_container: VBoxContainer = null
var _tower_list_container: VBoxContainer = null
var _subtitle_label: Label        = null
var _slot_lists: Dictionary       = {}
var _preview_selection: Dictionary = {}
var _tower_configs: Array[Dictionary] = []
var _selected_tower_id: String    = "basic_tower_t1"
var _vfx_mode_btn: Button         = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()
	_load_tower_catalog()
	refresh(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refit()

func _refit() -> void:
	if not is_inside_tree():
		return
	var vp_size := get_tree().get_root().get_visible_rect().size
	var w := clampf(vp_size.x - 24.0, 400.0, vp_size.x - 8.0)
	var h := clampf(vp_size.y - 24.0, 300.0, vp_size.y - 8.0)
	set_size(Vector2(w, h))
	var gx := floorf((vp_size.x - w) * 0.5)
	var gy := floorf((vp_size.y - h) * 0.5)
	set_global_position(Vector2(maxf(gx, 0.0), maxf(gy, 0.0)))

# ── Public API ────────────────────────────────────────────────────────────────

func refresh(sync_progress: bool = true) -> void:
	if _content == null:
		return
	if sync_progress:
		_sync_unlocks_from_progress()
	_reset_preview_selection_to_equipped()
	_refresh_tower_list()
	_clear_slot_lists()
	_add_slot(SLOT_TOWER_SKIN, "Tower Skin")
	if _is_support_tower(_selected_tower_cfg()):
		_add_slot(SLOT_AURA_SKIN, "Aura Style")
	else:
		_add_vfx_mode_row()
		_add_slot(SLOT_ATTACK_VFX_SKIN, "Attack VFX")
		_add_slot(SLOT_PROJECTILE_SKIN, "Projectile")
		_add_slot(SLOT_IMPACT_SKIN, "Impact")
	_update_preview()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build() -> void:
	custom_minimum_size = Vector2(400, 300)
	add_theme_stylebox_override("panel", _make_panel_style())

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left",   20)
	root_margin.add_theme_constant_override("margin_top",    16)
	root_margin.add_theme_constant_override("margin_right",  20)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	root_margin.add_child(_content)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_content.add_child(header)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header.add_child(title_col)

	var title := Label.new()
	title.text = "COSMETIC LOADOUT"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.40, 0.92, 1.0))
	title_col.add_child(title)

	_subtitle_label = Label.new()
	_subtitle_label.text = "SELECT TOWER  ·  VISUAL ONLY"
	_subtitle_label.add_theme_font_size_override("font_size", 10)
	_subtitle_label.add_theme_color_override("font_color", Color(0.52, 0.64, 0.76, 0.75))
	title_col.add_child(_subtitle_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_stylebox_override("normal",   _btn_style(Color(0.20, 0.88, 1.0, 0.12)))
	close_btn.add_theme_stylebox_override("hover",    _btn_style(Color(1.0, 0.35, 0.35, 0.25)))
	close_btn.add_theme_stylebox_override("pressed",  _btn_style(Color(1.0, 0.35, 0.35, 0.40)))
	close_btn.add_theme_color_override("font_color",       Color(0.70, 0.80, 0.88))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	header.add_child(close_btn)

	# ── Divider ──
	_content.add_child(_make_divider(Color(0.22, 0.88, 1.0, 0.18)))

	# ── Three-column body ──
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(body)

	# Left: tower list
	var tower_col := _make_column_panel(Color(0.68, 0.42, 1.0, 0.25))
	tower_col.custom_minimum_size = Vector2(190, 0)
	body.add_child(tower_col)
	var tc_inner := _column_inner(tower_col)
	var tower_header_row := HBoxContainer.new()
	tc_inner.add_child(tower_header_row)
	var towers_lbl := Label.new()
	towers_lbl.text = "TOWERS"
	towers_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	towers_lbl.add_theme_font_size_override("font_size", 11)
	towers_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	tower_header_row.add_child(towers_lbl)
	var tower_scroll := ScrollContainer.new()
	tower_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tc_inner.add_child(tower_scroll)
	_tower_list_container = VBoxContainer.new()
	_tower_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_list_container.add_theme_constant_override("separation", 4)
	tower_scroll.add_child(_tower_list_container)

	# Center: live preview
	var preview_col := _make_column_panel(Color(0.20, 0.78, 1.0, 0.28))
	preview_col.custom_minimum_size = Vector2(360, 0)
	body.add_child(preview_col)
	var pc_inner := _column_inner(preview_col)
	var preview_title_row := HBoxContainer.new()
	pc_inner.add_child(preview_title_row)
	var prev_lbl := Label.new()
	prev_lbl.text = "LIVE PREVIEW"
	prev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_lbl.add_theme_font_size_override("font_size", 11)
	prev_lbl.add_theme_color_override("font_color", Color(0.38, 0.90, 1.0))
	preview_title_row.add_child(prev_lbl)
	_preview = CosmeticPreviewCanvasScript.new()
	_preview.registry = get_node_or_null("/root/CosmeticRegistry")
	_preview.custom_minimum_size = Vector2(0, 260)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc_inner.add_child(_preview)
	var preview_note := Label.new()
	preview_note.text = "Visual only — no stats affected."
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_note.add_theme_font_size_override("font_size", 9)
	preview_note.add_theme_color_override("font_color", Color(0.48, 0.58, 0.68, 0.65))
	pc_inner.add_child(preview_note)

	# Right: loadout slots
	var loadout_col := _make_column_panel(Color(1.0, 0.72, 0.20, 0.22))
	loadout_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(loadout_col)
	var lc_inner := _column_inner(loadout_col)
	var loadout_title_row := HBoxContainer.new()
	lc_inner.add_child(loadout_title_row)
	var loadout_lbl := Label.new()
	loadout_lbl.text = "LOADOUT"
	loadout_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_lbl.add_theme_font_size_override("font_size", 11)
	loadout_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	loadout_title_row.add_child(loadout_lbl)
	var slot_scroll := ScrollContainer.new()
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lc_inner.add_child(slot_scroll)
	_slot_container = VBoxContainer.new()
	_slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_container.add_theme_constant_override("separation", 10)
	slot_scroll.add_child(_slot_container)

# ── Slot management ───────────────────────────────────────────────────────────

func _clear_slot_lists() -> void:
	for key in _slot_lists:
		var node: Node = _slot_lists[key]
		if is_instance_valid(node):
			node.queue_free()
	_slot_lists.clear()

func _add_slot(slot: String, title_text: String) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	_slot_lists[slot] = wrap
	(_slot_container if _slot_container else _content).add_child(wrap)

	# Section header with extending rule
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	wrap.add_child(hrow)
	var lbl := Label.new()
	lbl.text = title_text.to_upper()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.72, 0.84, 0.85))
	hrow.add_child(lbl)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(0.22, 0.38, 0.55, 0.35)
	rule.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	hrow.add_child(rule)

	wrap.add_child(_make_row(slot, "", "Default", true))
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if registry == null:
		return
	var found_any := false
	for cfg in registry.get_for_tower_slot(_selected_tower_id, slot):
		found_any = true
		wrap.add_child(_make_row(
			slot,
			str(cfg.get("id", "")),
			str(cfg.get("display_name", cfg.get("id", ""))),
			_is_unlocked(str(cfg.get("id", "")))
		))
	if not found_any:
		var empty := Label.new()
		empty.text = "No cosmetics for this tower yet."
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.38, 0.46, 0.54, 0.65))
		empty.add_theme_constant_override("margin_left", 4)
		wrap.add_child(empty)

func _add_vfx_mode_row() -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	_slot_lists["_vfx_mode_row"] = wrap  # tracked so _clear_slot_lists removes it
	(_slot_container if _slot_container else _content).add_child(wrap)

	# Header rule
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	wrap.add_child(hrow)
	var lbl := Label.new()
	lbl.text = "VFX MODE"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.72, 0.84, 0.85))
	hrow.add_child(lbl)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(0.22, 0.38, 0.55, 0.35)
	hrow.add_child(rule)

	# Compact toggle row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)

	var inventory := get_node_or_null("/root/CosmeticInventory")
	var current_mode := "attack_vfx"
	if inventory != null and inventory.has_method("get_attack_mode"):
		current_mode = inventory.get_attack_mode(_selected_tower_id)

	var btn_vfx := _make_toggle_btn("Attack VFX", current_mode == "attack_vfx")
	var btn_proj := _make_toggle_btn("Projectile (Fast)", current_mode == "projectile")
	_vfx_mode_btn = btn_vfx  # track primary toggle

	btn_vfx.pressed.connect(func() -> void:
		var inv := get_node_or_null("/root/CosmeticInventory")
		if inv == null: return
		inv.set_attack_mode(_selected_tower_id, "attack_vfx")
		btn_vfx.add_theme_stylebox_override("normal",  _toggle_style(true))
		btn_proj.add_theme_stylebox_override("normal", _toggle_style(false))
	)
	btn_proj.pressed.connect(func() -> void:
		var inv := get_node_or_null("/root/CosmeticInventory")
		if inv == null: return
		inv.set_attack_mode(_selected_tower_id, "projectile")
		btn_vfx.add_theme_stylebox_override("normal",  _toggle_style(false))
		btn_proj.add_theme_stylebox_override("normal", _toggle_style(true))
	)

	row.add_child(btn_vfx)
	row.add_child(btn_proj)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

func _make_toggle_btn(label: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(130, 28)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_stylebox_override("normal",  _toggle_style(active))
	btn.add_theme_stylebox_override("hover",   _toggle_style(active))
	btn.add_theme_stylebox_override("pressed", _toggle_style(true))
	btn.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0) if active else Color(0.50, 0.62, 0.75))
	return btn

func _toggle_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.72, 1.0, 0.18) if active else Color(0.06, 0.10, 0.16, 0.80)
	s.border_color = Color(0.22, 0.80, 1.0, 0.75) if active else Color(0.22, 0.35, 0.50, 0.40)
	s.set_border_width_all(1)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s

# ── Row builder ───────────────────────────────────────────────────────────────

func _make_row(slot: String, cosmetic_id: String, label_text: String, available: bool) -> Control:
	var equipped := _equipped(slot) == cosmetic_id
	var rarity_color := _cosmetic_color(cosmetic_id, available)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(rarity_color, available))
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
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	# Rarity accent bar
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(3, 28)
	swatch.color = rarity_color if available else Color(0.25, 0.30, 0.38)
	row.add_child(swatch)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	var name_color := Color(0.92, 0.96, 1.0) if available else Color(0.36, 0.42, 0.50)
	name_lbl.add_theme_color_override("font_color", name_color)
	row.add_child(name_lbl)

	# Status pill
	var pill := _make_status_pill(cosmetic_id, available, equipped)
	row.add_child(pill)

	# Action button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(76, 26)
	btn.add_theme_font_size_override("font_size", 10)
	if equipped:
		btn.text = "EQUIPPED"
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.22, 0.88, 1.0, 0.10)))
		btn.add_theme_color_override("font_disabled_color", Color(0.22, 0.88, 1.0, 0.70))
	else:
		btn.text = "USE" if cosmetic_id == "" else "EQUIP"
		btn.disabled = not available
		if available:
			btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.88, 1.0, 0.10)))
			btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.22, 0.88, 1.0, 0.26)))
			btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.22, 0.88, 1.0, 0.40)))
			btn.add_theme_color_override("font_color", Color(0.30, 0.90, 1.0))
		else:
			btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.15, 0.18, 0.26, 0.60)))
			btn.add_theme_color_override("font_disabled_color", Color(0.32, 0.38, 0.46))
	btn.pressed.connect(func() -> void:
		var inventory := get_node_or_null("/root/CosmeticInventory")
		if inventory != null:
			inventory.equip(_selected_tower_id, slot, cosmetic_id)
			if slot == SLOT_ATTACK_VFX_SKIN and inventory.has_method("set_attack_mode"):
				inventory.set_attack_mode(_selected_tower_id, "attack_vfx")
		_preview_selection[slot] = cosmetic_id
		refresh()
	)
	row.add_child(btn)
	return panel

func _make_status_pill(cosmetic_id: String, available: bool, equipped: bool) -> Label:
	var pill := Label.new()
	pill.add_theme_font_size_override("font_size", 9)
	if cosmetic_id == "":
		pill.text = " DEFAULT "
		pill.add_theme_color_override("font_color", Color(0.50, 0.64, 0.78))
	elif equipped:
		pill.text = " ● EQUIPPED "
		pill.add_theme_color_override("font_color", Color(0.25, 0.95, 0.65))
	elif available:
		pill.text = " UNLOCKED "
		pill.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.80))
	else:
		pill.text = " LOCKED "
		pill.add_theme_color_override("font_color", Color(0.55, 0.38, 0.55))
	return pill

# ── Tower list ────────────────────────────────────────────────────────────────

func _refresh_tower_list() -> void:
	if _tower_list_container == null:
		return
	for child in _tower_list_container.get_children():
		child.queue_free()
	for cfg in _tower_configs:
		_tower_list_container.add_child(_make_tower_row(cfg))
	if _subtitle_label:
		_subtitle_label.text = "%s  ·  VISUAL ONLY" % \
			CosmeticTowerCatalogScript.display_name(_selected_tower_cfg()).to_upper()

func _make_tower_row(cfg: Dictionary) -> Control:
	var tower_id := str(cfg.get("id", ""))
	var selected := tower_id == _selected_tower_id
	var btn := Button.new()
	btn.text = CosmeticTowerCatalogScript.display_name(cfg)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 11)
	btn.disabled = selected
	var fc := Color(0.88, 0.92, 1.0) if selected else Color(0.62, 0.72, 0.84)
	btn.add_theme_color_override("font_color",          fc)
	btn.add_theme_color_override("font_disabled_color", fc)
	btn.add_theme_stylebox_override("normal",   _tower_btn_style(selected))
	btn.add_theme_stylebox_override("hover",    _tower_btn_style(true))
	btn.add_theme_stylebox_override("pressed",  _tower_btn_style(true))
	btn.add_theme_stylebox_override("disabled", _tower_btn_style(true))
	btn.pressed.connect(func() -> void:
		_selected_tower_id = tower_id
		refresh(false)
	)
	return btn

# ── Preview ───────────────────────────────────────────────────────────────────

func _update_preview() -> void:
	if _preview == null:
		return
	_preview.registry = get_node_or_null("/root/CosmeticRegistry")
	if _preview.has_method("set_tower_config"):
		_preview.set_tower_config(_selected_tower_cfg())
	_preview.set_cosmetics(
		str(_preview_selection.get(SLOT_TOWER_SKIN,      _equipped(SLOT_TOWER_SKIN))),
		str(_preview_selection.get(SLOT_PROJECTILE_SKIN, _equipped(SLOT_PROJECTILE_SKIN))),
		str(_preview_selection.get(SLOT_IMPACT_SKIN,     _equipped(SLOT_IMPACT_SKIN))),
		str(_preview_selection.get(SLOT_AURA_SKIN,       _equipped(SLOT_AURA_SKIN))),
		str(_preview_selection.get(SLOT_ATTACK_VFX_SKIN, _equipped(SLOT_ATTACK_VFX_SKIN)))
	)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_support_tower(cfg: Dictionary) -> bool:
	return str(cfg.get("attack_type", "")) == "support_aura"

func _equipped(slot: String) -> String:
	var inv := get_node_or_null("/root/CosmeticInventory")
	return str(inv.get_equipped(_selected_tower_id, slot)) if inv != null else ""

func _is_unlocked(cosmetic_id: String) -> bool:
	var inv := get_node_or_null("/root/CosmeticInventory")
	return inv != null and inv.is_unlocked(cosmetic_id)

func _sync_unlocks_from_progress() -> void:
	var svc := get_node_or_null("/root/CosmeticRewardService")
	if svc != null and svc.has_method("process_current_progress"):
		svc.process_current_progress()

func _reset_preview_selection_to_equipped() -> void:
	_preview_selection[SLOT_TOWER_SKIN]      = _equipped(SLOT_TOWER_SKIN)
	_preview_selection[SLOT_PROJECTILE_SKIN] = _equipped(SLOT_PROJECTILE_SKIN)
	_preview_selection[SLOT_IMPACT_SKIN]     = _equipped(SLOT_IMPACT_SKIN)
	_preview_selection[SLOT_AURA_SKIN]       = _equipped(SLOT_AURA_SKIN)
	_preview_selection[SLOT_ATTACK_VFX_SKIN] = _equipped(SLOT_ATTACK_VFX_SKIN)

func _load_tower_catalog() -> void:
	_tower_configs = CosmeticTowerCatalogScript.load_towers()
	if _tower_configs.is_empty():
		_tower_configs = [{"id": _selected_tower_id, "display_name": "Neutral Arrow Tower",
			"visual_type": "basic", "tier": 1}]
	var has_sel := false
	for cfg in _tower_configs:
		if str(cfg.get("id", "")) == _selected_tower_id:
			has_sel = true; break
	if not has_sel:
		_selected_tower_id = str(_tower_configs[0].get("id", _selected_tower_id))

func _selected_tower_cfg() -> Dictionary:
	for cfg in _tower_configs:
		if str(cfg.get("id", "")) == _selected_tower_id:
			return cfg
	return {"id": _selected_tower_id, "display_name": _selected_tower_id,
		"visual_type": "basic", "tier": 1}

func _cosmetic_color(cosmetic_id: String, available: bool) -> Color:
	if cosmetic_id == "":
		return Color(0.38, 0.50, 0.62, 0.70)
	if not available:
		return Color(0.28, 0.28, 0.34, 0.65)
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if registry != null:
		var cfg: Dictionary = registry.get_cosmetic(cosmetic_id)
		if not cfg.is_empty():
			return registry.get_rarity_color(str(cfg.get("rarity", "common")))
	return Color(0.38, 0.90, 1.0, 0.80)

# ── Style helpers ─────────────────────────────────────────────────────────────

func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.028, 0.038, 0.068, 0.97)
	s.border_color = Color(0.22, 0.88, 1.0, 0.45)
	s.set_border_width_all(1)
	s.corner_radius_top_left    = 10
	s.corner_radius_top_right   = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	s.shadow_color = Color(0.0, 0.75, 1.0, 0.20)
	s.shadow_size  = 20
	return s

func _make_column_panel(accent: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.022, 0.032, 0.058, 0.90)
	s.border_color = accent
	s.set_border_width_all(1)
	s.corner_radius_top_left    = 7
	s.corner_radius_top_right   = 7
	s.corner_radius_bottom_left = 7
	s.corner_radius_bottom_right = 7
	pc.add_theme_stylebox_override("panel", s)
	return pc

func _column_inner(parent: PanelContainer) -> VBoxContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   12)
	m.add_theme_constant_override("margin_top",    12)
	m.add_theme_constant_override("margin_right",  12)
	m.add_theme_constant_override("margin_bottom", 12)
	parent.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)
	return vb

func _row_style(rarity_color: Color, available: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.040, 0.055, 0.090, 0.92) if available else Color(0.022, 0.028, 0.044, 0.80)
	s.border_color = rarity_color.darkened(0.30) if available else Color(0.22, 0.26, 0.32, 0.45)
	s.set_border_width_all(1)
	s.corner_radius_top_left    = 5
	s.corner_radius_top_right   = 5
	s.corner_radius_bottom_left = 5
	s.corner_radius_bottom_right = 5
	return s

func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = Color(0.22, 0.80, 1.0, 0.45)
	s.set_border_width_all(1)
	s.corner_radius_top_left    = 4
	s.corner_radius_top_right   = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s

func _tower_btn_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.08, 0.12, 0.20, 0.95) if selected else Color(0.0, 0.0, 0.0, 0.0)
	s.border_color = Color(0.65, 0.40, 1.0, 0.65) if selected else Color(0.0, 0.0, 0.0, 0.0)
	s.set_border_width_all(1 if selected else 0)
	s.set_border_width(SIDE_LEFT, 3 if selected else 0)
	s.border_color = Color(0.65, 0.40, 1.0, 0.80) if selected else Color(0.0, 0.0, 0.0, 0.0)
	s.corner_radius_top_left    = 4
	s.corner_radius_top_right   = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s

func _make_divider(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.color = color
	return r
