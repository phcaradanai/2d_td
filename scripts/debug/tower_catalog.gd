extends Control

## Tower Effect Catalog — debug scene for reviewing all tower VFX, models, and badges.
## Open directly: res://scenes/debug/tower_catalog.tscn
## No gameplay changes — reads PerformanceFirebreak flags as read-only.

const BASE_SIZE := Vector2(1920, 1080)
const MIN_WINDOW_SIZE := Vector2(1280, 720)

@onready var _main_panel: Control = $RootMargin/MainPanel
@onready var _root_margin: MarginContainer = $RootMargin
@onready var _item_list: ItemList = $RootMargin/MainPanel/MainMargin/MainVBox/BodySplit/TowerListPanel/TowerNameList
@onready var top_toolbar: HBoxContainer = $RootMargin/MainPanel/MainMargin/MainVBox/ToolbarScroll/Toolbar
@onready var _detail_title: Label = $RootMargin/MainPanel/MainMargin/MainVBox/BodySplit/DetailPanel/DetailMargin/DetailVBox/SelectedTowerName
@onready var _detail_body: Label = $RootMargin/MainPanel/MainMargin/MainVBox/BodySplit/DetailPanel/DetailMargin/DetailVBox/SelectedTowerStats

const TOWER_TREE_PATH := "res://data/towers_tree.json"
const CatalogVfxModeScript = preload("res://scripts/debug/catalog_vfx_mode.gd")
const TowerCatalogVirtualListScript = preload("res://scripts/debug/tower_catalog_virtual_list.gd")
const CatalogPerformanceMonitorScript = preload("res://scripts/debug/catalog_performance_monitor.gd")
const CatalogRenderGuardScript = preload("res://scripts/debug/catalog_render_guard.gd")
const TowerPreviewPopupScene = preload("res://scenes/debug/tower_preview_popup.tscn")

const ELEM_SHORT := {
	"light": "L", "darkness": "D", "water": "W", "fire": "F",
	"nature": "Na", "earth": "E",
}

const ELEM_COLOR := {
	"light":    Color(0.95, 0.92, 0.3),
	"darkness": Color(0.55, 0.15, 0.75),
	"water":    Color(0.2, 0.55, 0.95),
	"fire":     Color(1.0, 0.35, 0.15),
	"nature":   Color(0.25, 0.85, 0.3),
	"earth":    Color(0.65, 0.4, 0.2),
}

const ELEM_DISPLAY := {
	"light": "Light", "darkness": "Darkness", "water": "Water",
	"fire": "Fire", "nature": "Nature", "earth": "Earth",
}

const TIER_BADGE_COLOR := {
	1: Color(1.0, 0.78, 0.18),
	2: Color(0.75, 0.78, 0.82),
	3: Color(0.2, 0.90, 0.98),
	4: Color(0.72, 0.42, 1.0),
	6: Color(1.0, 0.42, 0.88),
}

const SECTION_ORDER := ["neutral", "single", "dual", "triple", "pure", "periodic"]
const SECTION_LABELS := {
	"neutral":  "Neutral",
	"single":   "Single Element",
	"dual":     "Dual Element",
	"triple":   "Triple Element",
	"pure":     "Pure",
	"periodic": "Periodic",
}

var _towers_config: Dictionary = {}
var _selected_tower_id: String = ""
var _selected_tower_cfg: Dictionary = {}

var _controller: TowerEffectCatalogController = null
var _zoom_controller: TowerEffectCatalogZoomController = null
var _virtual_list: Node = null
var _performance_monitor: Node = null
var _catalog_safe_mode_toggle: CheckButton = null
var _catalog_load_more_button: Button = null
var _catalog_visible_limit: int = 24
var _catalog_last_build_truncated: bool = false
var current_preview: Node = null
var popup_open: bool = false

func _ready() -> void:
	CatalogRenderGuardScript.reset_to_defaults()
	_load_tower_data()
	_setup_controller()
	_setup_zoom_controller()
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_activated.connect(_on_item_activated)
	_build_toolbar()
	_build_catalog()
	_fit_catalog_to_viewport()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_catalog_to_viewport()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if popup_open:
			_close_preview_popup()
			get_viewport().set_input_as_handled()
			return
		get_tree().quit()
	if event is InputEventMouseButton and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_controller.zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_controller.zoom_out()
			get_viewport().set_input_as_handled()

func _load_tower_data() -> void:
	if not FileAccess.file_exists(TOWER_TREE_PATH):
		push_error("[TowerCatalog] towers_tree.json not found: %s" % TOWER_TREE_PATH)
		return
	var file := FileAccess.open(TOWER_TREE_PATH, FileAccess.READ)
	if file == null:
		push_error("[TowerCatalog] Failed to open towers_tree.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[TowerCatalog] JSON parse error: %s" % json.get_error_message())
		return
	_towers_config = json.data

func _build_families() -> Dictionary:
	var sections: Dictionary = {}
	for tid: String in _towers_config:
		var cfg: Dictionary = _towers_config[tid]
		var ctype: String = str(cfg.get("combo_type", "neutral")).to_lower()
		if not sections.has(ctype):
			sections[ctype] = []
		sections[ctype].append([tid, cfg])
	for ctype in sections:
		var arr: Array = sections[ctype]
		arr.sort_custom(func(a, b):
			var ta: int = int(a[1].get("tier", 0))
			var tb: int = int(b[1].get("tier", 0))
			if ta != tb:
				return ta < tb
			return str(a[0]) < str(b[0])
		)
	return sections

func _group_into_families(section_entries: Array) -> Array:
	var family_map: Dictionary = {}
	var family_order: Array[String] = []
	var re := RegEx.new()
	re.compile("_t\\d+$")
	for pair in section_entries:
		var tid: String = pair[0]
		var fk: String = re.sub(tid, "")
		if not family_map.has(fk):
			family_map[fk] = []
			family_order.append(fk)
		family_map[fk].append(pair)
	var result: Array = []
	for fk in family_order:
		result.append({"family_key": fk, "members": family_map[fk]})
	return result

func _build_catalog() -> void:
	_selected_tower_id = ""
	_selected_tower_cfg = {}
	_virtual_list = null
	_apply_filters()
	_update_detail_panel()

func _build_virtual_entries(limit: int = -1) -> Array:
	var entries: Array = []
	var card_count := 0
	var limit_reached := false

	var sections := _build_families()

	for ctype in SECTION_ORDER:
		if limit_reached:
			break
		if not sections.has(ctype):
			continue
		var families := _group_into_families(sections[ctype])
		if families.is_empty():
			continue
		var section_added := false
		for family in families:
			if limit_reached:
				break
			var members: Array = family["members"]
			var visible_members: Array = []
			for pair in members:
				if limit >= 0 and card_count >= limit:
					limit_reached = true
					break
				var tid: String = pair[0]
				var cfg: Dictionary = pair[1].duplicate(true)
				if _entry_passes_filters(tid, cfg):
					visible_members.append([tid, cfg])
					card_count += 1
			if visible_members.is_empty():
				continue
			if not section_added:
				entries.append({"type": "section", "label": SECTION_LABELS.get(ctype, ctype)})
				section_added = true
			entries.append({"type": "row", "members": visible_members})
		if section_added:
			entries.append({"type": "separator"})
		if limit_reached:
			break
	_catalog_last_build_truncated = limit_reached
	return entries

func _setup_controller() -> void:
	_controller = TowerEffectCatalogController.new()
	_controller.name = "CatalogController"
	add_child(_controller)
	_controller.filters_changed.connect(_apply_filters)

func _setup_zoom_controller() -> void:
	_zoom_controller = TowerEffectCatalogZoomController.new()

func _apply_filters() -> void:
	_populate_tower_name_list()
	_update_load_more_button()
	if _item_list and _item_list.item_count > 0 and _item_list.get_selected_items().is_empty():
		_item_list.select(0)
		_on_item_selected(0)
	elif _item_list and _item_list.get_selected_items().is_empty():
		_update_detail_panel()

func _populate_tower_name_list() -> void:
	if _item_list == null:
		return
	_item_list.clear()

	var sorted_tower_ids: Array = _towers_config.keys()
	sorted_tower_ids.sort_custom(func(a: String, b: String) -> bool:
		var cfg_a: Dictionary = _towers_config.get(a, {})
		var cfg_b: Dictionary = _towers_config.get(b, {})
		var name_a := _get_tower_display_name(a, cfg_a).to_lower()
		var name_b := _get_tower_display_name(b, cfg_b).to_lower()
		if name_a != name_b:
			return name_a < name_b
		return a < b
	)

	for tower_id in sorted_tower_ids:
		var cfg: Dictionary = _towers_config.get(tower_id, {})
		if not _entry_passes_filters(tower_id, cfg):
			continue
		var row_text := "%s | %s | %s | %s" % [
			_get_tower_display_name(tower_id, cfg),
			_get_tower_tier_text(cfg),
			_get_tower_element_text(cfg),
			_get_tower_role_text(cfg),
		]
		_item_list.add_item(row_text)
		_item_list.set_item_metadata(_item_list.item_count - 1, tower_id)

func _on_item_selected(index: int) -> void:
	if _item_list == null or index < 0 or index >= _item_list.item_count:
		_update_detail_panel()
		return
	var tower_id := str(_item_list.get_item_metadata(index))
	var cfg: Dictionary = _towers_config.get(tower_id, {})
	_selected_tower_id = tower_id
	_selected_tower_cfg = cfg.duplicate(true)
	_update_detail_panel(tower_id, cfg)

func _on_item_activated(index: int) -> void:
	if _item_list == null or index < 0 or index >= _item_list.item_count:
		return
	var tower_id := str(_item_list.get_item_metadata(index))
	_open_preview_popup(tower_id)

func _entry_passes_filters(tower_id: String, cfg: Dictionary) -> bool:
	if _controller == null:
		return true
	if _controller.search_text != "":
		var s := _controller.search_text.to_lower()
		if not (tower_id.to_lower().contains(s) or str(cfg.get("display_name", "")).to_lower().contains(s)):
			return false
	if _controller.element_filter != "all":
		var elements: Array = cfg.get("elements", [])
		if not elements.has(_controller.element_filter):
			return false
	if _controller.tier_filter != "all":
		var tier_map := {"t1": 1, "t2": 2, "t3": 3, "pure": 4}
		if cfg.get("tier", 0) != tier_map.get(_controller.tier_filter, -1):
			return false
	if _controller.attack_filter != "all":
		if str(cfg.get("attack_type", "")).to_lower() != _controller.attack_filter:
			return false
	return true

func _populate_virtual_row(row: Control, entry: Dictionary) -> void:
	match str(entry.get("type", "row")):
		"section":
			var label := _make_section_label(str(entry.get("label", "")))
			label.position = Vector2(0, 4)
			row.add_child(label)
		"separator":
			row.add_child(_make_separator())
		_:
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			hbox.size = row.size
			hbox.custom_minimum_size = row.size
			row.add_child(hbox)
			for pair in entry.get("members", []):
				var tid: String = pair[0]
				var cfg: Dictionary = pair[1].duplicate(true)
				hbox.add_child(_make_tower_card(tid, cfg))
			if entry.get("members", []).size() < 3:
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(spacer)

func _deactivate_virtual_row(row: Control) -> void:
	for child in row.get_children():
		_deactivate_card_scripts(child)

func _deactivate_card_scripts(node: Node) -> void:
	if node is TowerEffectCatalogCard:
		(node as TowerEffectCatalogCard).deactivate()
	for child in node.get_children():
		_deactivate_card_scripts(child)

func _get_vfx_badge(tower_id: String, tier: int) -> String:
	var script := TowerAttackVFXRegistry.get_vfx_script(tower_id)
	if script == null:
		return "Missing"
	if tier >= 2:
		var base_re := RegEx.new()
		base_re.compile("_t\\d+$")
		var t1_id := base_re.sub(tower_id, "_t1")
		var t1_class := t1_id + "_attack_vfx"
		# source_code is only populated in editor/debug mode; empty in exports.
		# Badge may show "OK" instead of "T1 Fallback" in exported builds — acceptable for a debug tool.
		if not script.source_code.is_empty() and script.source_code.contains("extends " + t1_class):
			return "T1 Fallback"
	return "OK"

func _make_tower_card(tower_id: String, cfg: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 400)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.04, 0.06, 0.10, 0.92)
	normal_style.border_color = Color(0.12, 0.55, 0.85, 0.6)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 10
	normal_style.content_margin_right = 10
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", normal_style)

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.04, 0.08, 0.14, 0.98)
	selected_style.border_color = Color(0.35, 0.95, 1.0, 1.0)
	selected_style.set_border_width_all(2)
	selected_style.set_corner_radius_all(8)
	selected_style.content_margin_left = 10
	selected_style.content_margin_right = 10
	selected_style.content_margin_top = 8
	selected_style.content_margin_bottom = 8

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	var elements: Array = cfg.get("elements", [])
	if not elements.is_empty():
		top_row.add_child(_make_element_badge(elements))

	var name_label := Label.new()
	name_label.text = str(cfg.get("display_name", cfg.get("name", tower_id)))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)

	var tier: int = int(cfg.get("tier", 1))
	var tier_label := Label.new()
	tier_label.text = "T%d" % tier if tier <= 3 else ("P" if tier == 4 else "T%d" % tier)
	tier_label.add_theme_font_size_override("font_size", 11)
	var tier_color: Color = TIER_BADGE_COLOR.get(tier, Color(0.5, 0.5, 0.5))
	tier_label.add_theme_color_override("font_color", tier_color)
	top_row.add_child(tier_label)

	vbox.add_child(_make_stat_label(
		"ATK: %s  TYPE: %s" % [str(cfg.get("attack_type", "-")), str(cfg.get("visual_type", "-"))],
		Color(0.55, 0.65, 0.85)
	))

	_make_passthrough(vbox)
	return card

func _make_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_make_passthrough(child)

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = "▸  " + text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	label.custom_minimum_size = Vector2(0, 32)
	return label

func _make_separator() -> Control:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	return sep

func _make_element_badge(elements: Array) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	for i in range(elements.size()):
		var elem: String = str(elements[i])
		var label := Label.new()
		label.text = ELEM_SHORT.get(elem, elem.substr(0, 1))
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = ELEM_COLOR.get(elem, Color(0.4, 0.5, 0.7))
		bg.set_corner_radius_all(3)
		bg.content_margin_left = 3
		bg.content_margin_right = 3
		bg.content_margin_top = 1
		bg.content_margin_bottom = 1
		label.add_theme_stylebox_override("normal", bg)
		hbox.add_child(label)
		if i < elements.size() - 1:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 9)
			plus.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			hbox.add_child(plus)
	return hbox

func _make_stat_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label

func _get_tower_display_name(tower_id: String, cfg: Dictionary) -> String:
	var display_name := str(cfg.get("display_name", cfg.get("name", "")))
	return display_name if display_name != "" else tower_id

func _get_tower_tier_text(cfg: Dictionary) -> String:
	var tier: int = int(cfg.get("tier", 1))
	if tier == 4:
		return "Pure"
	if tier <= 3:
		return "T%d" % tier
	return "T%d" % tier

func _get_tower_element_text(cfg: Dictionary) -> String:
	var elements: Array = cfg.get("elements", [])
	if elements.is_empty():
		return "—"
	var labels: Array[String] = []
	for element in elements:
		labels.append(ELEM_DISPLAY.get(str(element), str(element).capitalize()))
	return "+".join(labels)

func _get_tower_role_text(cfg: Dictionary) -> String:
	var role := str(cfg.get("support_type", ""))
	if role == "" or role == "null":
		role = str(cfg.get("attack_type", ""))
	if role == "" or role == "null":
		role = str(cfg.get("visual_type", ""))
	if role == "" or role == "null":
		role = str(cfg.get("combo_type", ""))
	if role == "" or role == "null":
		role = "—"
	return role.capitalize() if role != "—" else role

func _str_or_dash(value: float) -> String:
	return "—" if value == 0.0 else str(value)

func _get_first_level_value(cfg: Dictionary, key: String, fallback: float) -> Variant:
	if cfg.has("levels") and cfg["levels"] is Array and cfg["levels"].size() > 0:
		return cfg["levels"][0].get(key, fallback)
	return cfg.get(key, fallback)

func _build_toolbar() -> void:
	var search := LineEdit.new()
	search.placeholder_text = "Search tower..."
	search.custom_minimum_size = Vector2(160, 0)
	search.text_changed.connect(func(val: String) -> void:
		_controller.search_text = val
		_controller.filters_changed.emit()
	)
	top_toolbar.add_child(search)

	top_toolbar.add_child(_make_toolbar_sep())

	var elem_opt := OptionButton.new()
	for entry in [["All", "all"], ["Light", "light"], ["Darkness", "darkness"],
			["Water", "water"], ["Fire", "fire"], ["Nature", "nature"], ["Earth", "earth"]]:
		elem_opt.add_item(entry[0])
		elem_opt.set_item_metadata(elem_opt.item_count - 1, entry[1])
	elem_opt.item_selected.connect(func(idx: int) -> void:
		_controller.element_filter = elem_opt.get_item_metadata(idx)
		_controller.filters_changed.emit()
	)
	top_toolbar.add_child(elem_opt)

	var tier_opt := OptionButton.new()
	for entry in [["All Tiers", "all"], ["T1", "t1"], ["T2", "t2"], ["T3", "t3"], ["Pure", "pure"]]:
		tier_opt.add_item(entry[0])
		tier_opt.set_item_metadata(tier_opt.item_count - 1, entry[1])
	tier_opt.item_selected.connect(func(idx: int) -> void:
		_controller.tier_filter = tier_opt.get_item_metadata(idx)
		_controller.filters_changed.emit()
	)
	top_toolbar.add_child(tier_opt)

	var atk_opt := OptionButton.new()
	for entry in [["All Types", "all"], ["Single", "single"], ["Splash", "splash"],
			["Slow", "slow"], ["Support", "support"], ["Aura", "aura"]]:
		atk_opt.add_item(entry[0])
		atk_opt.set_item_metadata(atk_opt.item_count - 1, entry[1])
	atk_opt.item_selected.connect(func(idx: int) -> void:
		_controller.attack_filter = atk_opt.get_item_metadata(idx)
		_controller.filters_changed.emit()
	)
	top_toolbar.add_child(atk_opt)

	top_toolbar.add_child(_make_toolbar_sep())

	top_toolbar.add_child(_make_toolbar_toggle("Models", true, func(v: bool) -> void:
		_controller.show_models = v
	))
	_catalog_safe_mode_toggle = _make_toolbar_toggle("Safe Mode", CatalogRenderGuardScript.catalog_safe_mode, func(v: bool) -> void:
		CatalogRenderGuardScript.catalog_safe_mode = v
		_catalog_visible_limit = CatalogRenderGuardScript.max_preview_cards if v else -1
		_sync_safe_mode_toggle_text(v)
		_apply_filters()
	)
	top_toolbar.add_child(_catalog_safe_mode_toggle)
	_sync_safe_mode_toggle_text(CatalogRenderGuardScript.catalog_safe_mode)

	_catalog_load_more_button = Button.new()
	_catalog_load_more_button.text = "Load More"
	_catalog_load_more_button.pressed.connect(func() -> void:
		if CatalogRenderGuardScript.catalog_safe_mode:
			_catalog_visible_limit += CatalogRenderGuardScript.max_preview_cards
			_apply_filters()
	)
	top_toolbar.add_child(_catalog_load_more_button)

	var vfx_mode_opt := OptionButton.new()
	for entry in [["VFX Off", CatalogVfxModeScript.VFX_OFF], ["Selected Only", CatalogVfxModeScript.VFX_SELECTED_ONLY], ["All", CatalogVfxModeScript.VFX_ALL]]:
		vfx_mode_opt.add_item(entry[0])
		vfx_mode_opt.set_item_metadata(vfx_mode_opt.item_count - 1, entry[1])
	vfx_mode_opt.selected = 0
	_controller.vfx_mode = CatalogVfxModeScript.VFX_OFF
	vfx_mode_opt.item_selected.connect(func(idx: int) -> void:
		_controller.vfx_mode = str(vfx_mode_opt.get_item_metadata(idx))
		if _controller.vfx_mode == CatalogVfxModeScript.VFX_OFF:
			_clear_attack_vfx_nodes()
		if _virtual_list:
			_virtual_list.refresh_visible_rows()
	)
	top_toolbar.add_child(vfx_mode_opt)
	top_toolbar.add_child(_make_toolbar_toggle("Status FX", true, func(v: bool) -> void:
		_controller.show_status_fx = v
	))
	top_toolbar.add_child(_make_toolbar_toggle("Support FX", true, func(v: bool) -> void:
		_controller.show_support_fx = v
	))

	var open_selected_btn := Button.new()
	open_selected_btn.text = "Open Selected"
	open_selected_btn.pressed.connect(func() -> void:
		if _selected_tower_id != "":
			_open_preview_popup(_selected_tower_id)
	)
	top_toolbar.add_child(open_selected_btn)

	top_toolbar.add_child(_make_toolbar_sep())

	top_toolbar.add_child(_make_toolbar_toggle("Auto Play", false, func(v: bool) -> void:
		_controller.set_auto_play(v)
	))
	top_toolbar.add_child(_make_toolbar_toggle("Pause", false, func(v: bool) -> void:
		_controller.set_paused(v)
	))

	var replay_btn := Button.new()
	replay_btn.text = "Replay"
	replay_btn.pressed.connect(func() -> void:
		_controller.replay_selected_requested.emit()
	)
	top_toolbar.add_child(replay_btn)

	top_toolbar.add_child(_make_toolbar_sep())

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.custom_minimum_size = Vector2(28, 0)
	zoom_out_btn.pressed.connect(func() -> void: _zoom_controller.zoom_out())
	top_toolbar.add_child(zoom_out_btn)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(28, 0)
	zoom_in_btn.pressed.connect(func() -> void: _zoom_controller.zoom_in())
	top_toolbar.add_child(zoom_in_btn)

	var zoom_reset_btn := Button.new()
	zoom_reset_btn.text = "1×"
	zoom_reset_btn.pressed.connect(func() -> void: _zoom_controller.reset_zoom())
	top_toolbar.add_child(zoom_reset_btn)

	var fit_btn := Button.new()
	fit_btn.text = "Fit"
	fit_btn.pressed.connect(func() -> void: _zoom_controller.fit_grid())
	top_toolbar.add_child(fit_btn)

	top_toolbar.add_child(_make_toolbar_sep())

	var fps_label := Label.new()
	fps_label.add_theme_font_size_override("font_size", 12)
	fps_label.add_theme_color_override("font_color", Color(0.45, 0.65, 0.45))
	fps_label.text = "FPS: --"
	top_toolbar.add_child(fps_label)

	var vfx_label := Label.new()
	vfx_label.add_theme_font_size_override("font_size", 12)
	vfx_label.add_theme_color_override("font_color", Color(0.45, 0.65, 0.85))
	vfx_label.text = "VFX: 0"
	top_toolbar.add_child(vfx_label)

	var process_label := _make_perf_label("Process: --")
	top_toolbar.add_child(process_label)

	var drawn_label := _make_perf_label("Drawn: --")
	top_toolbar.add_child(drawn_label)

	var node_label := _make_perf_label("Nodes: --")
	top_toolbar.add_child(node_label)

	var active_preview_label := _make_perf_label("Active: 0")
	top_toolbar.add_child(active_preview_label)

	_performance_monitor = CatalogPerformanceMonitorScript.new()
	_performance_monitor.name = "CatalogPerformanceMonitor"
	add_child(_performance_monitor)
	_performance_monitor.setup(
		{
			"fps": fps_label,
			"process": process_label,
			"drawn": drawn_label,
			"nodes": node_label,
			"active": active_preview_label,
		},
		func() -> int:
			return _virtual_list.get_active_preview_count() if _virtual_list else 0
	)

func _make_perf_label(text: String) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.45, 0.65, 0.85))
	label.text = text
	return label

func _update_detail_panel(tower_id: String = "", cfg: Dictionary = {}) -> void:
	if _detail_title == null or _detail_body == null:
		return
	if tower_id == "":
		_detail_title.text = "Detail"
		_detail_body.text = "Select a tower to inspect its text summary."
		return
	_detail_title.text = _get_tower_display_name(tower_id, cfg)
	var lines: Array[String] = [
		"ID: %s" % tower_id,
		"Tier: %s" % _get_tower_tier_text(cfg),
		"Elements: %s" % _get_tower_element_text(cfg),
		"Role: %s" % _get_tower_role_text(cfg),
		"Attack: %s" % str(cfg.get("attack_type", "—")),
		"Visual: %s" % str(cfg.get("visual_type", "—")),
	]
	_detail_body.text = "\n".join(lines)

func _open_preview_popup(tower_id: String) -> void:
	if tower_id == "":
		return
	_clear_preview_nodes()
	var cfg: Dictionary = _towers_config.get(tower_id, {})
	var popup := TowerPreviewPopupScene.instantiate()
	if popup == null:
		push_error("[TowerCatalog] Failed to create TowerPreviewPopup")
		return
	add_child(popup)
	current_preview = popup
	popup_open = true
	if popup.has_signal("close_requested"):
		popup.close_requested.connect(_close_preview_popup)
	if popup.has_method("open_for_tower"):
		popup.open_for_tower(tower_id, cfg)

func _close_preview_popup() -> void:
	_clear_preview_nodes()
	popup_open = false

func _clear_preview_nodes() -> void:
	if current_preview == null or not is_instance_valid(current_preview):
		current_preview = null
		return
	if current_preview.has_method("stop_preview"):
		current_preview.stop_preview()
	if current_preview.has_method("close_popup"):
		current_preview.close_popup()
	current_preview.set_process(false)
	current_preview.set_physics_process(false)
	current_preview.set_process_input(false)
	current_preview.queue_free()
	current_preview = null

func _make_toolbar_sep() -> VSeparator:
	return VSeparator.new()

func _make_toolbar_toggle(label: String, initial: bool, callback: Callable) -> CheckButton:
	var btn := CheckButton.new()
	btn.text = label
	btn.button_pressed = initial
	btn.add_theme_font_size_override("font_size", 12)
	btn.toggled.connect(func(v: bool) -> void: callback.call(v))
	return btn

func _clear_attack_vfx_nodes() -> void:
	for node in get_tree().get_nodes_in_group("attack_vfx"):
		node.queue_free()

func _update_load_more_button() -> void:
	if _catalog_load_more_button == null:
		return
	if CatalogRenderGuardScript.catalog_list_first:
		_catalog_load_more_button.disabled = true
		_catalog_load_more_button.text = "List Only"
		return
	if not CatalogRenderGuardScript.catalog_safe_mode:
		_catalog_load_more_button.disabled = true
		_catalog_load_more_button.text = "Load More"
		return
	_catalog_load_more_button.disabled = not _catalog_last_build_truncated
	if _catalog_last_build_truncated:
		_catalog_load_more_button.text = "Load More +%d" % CatalogRenderGuardScript.max_preview_cards
	else:
		_catalog_load_more_button.text = "All Loaded"

func _sync_safe_mode_toggle_text(enabled: bool) -> void:
	if _catalog_safe_mode_toggle:
		_catalog_safe_mode_toggle.text = "Safe Mode: ON" if enabled else "Safe Mode: OFF"

func _fit_catalog_to_viewport() -> void:
	if _main_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_main_panel.custom_minimum_size = Vector2.ZERO
	if _root_margin:
		var compact := viewport_size.x < MIN_WINDOW_SIZE.x or viewport_size.y < MIN_WINDOW_SIZE.y
		_root_margin.add_theme_constant_override("margin_left", 12 if compact else 24)
		_root_margin.add_theme_constant_override("margin_top", 8 if compact else 16)
		_root_margin.add_theme_constant_override("margin_right", 12 if compact else 24)
		_root_margin.add_theme_constant_override("margin_bottom", 12 if compact else 24)
	_apply_catalog_font_scale(viewport_size)

func _apply_catalog_font_scale(viewport_size: Vector2) -> void:
	var compact := viewport_size.x < MIN_WINDOW_SIZE.x or viewport_size.y < MIN_WINDOW_SIZE.y
	var row_font := 14 if compact else 16
	if _item_list:
		_item_list.add_theme_font_size_override("font_size", row_font)
