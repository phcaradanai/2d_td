extends Control

## Tower Effect Catalog — debug scene for reviewing all tower VFX, models, and badges.
## Open directly: res://scenes/debug/tower_catalog.tscn
## No gameplay changes — reads PerformanceFirebreak flags as read-only.

@onready var content_vbox: VBoxContainer = $RootMargin/MainVBox/ContentArea/ScrollContainer/ContentVBox
@onready var top_toolbar: HBoxContainer = $RootMargin/MainVBox/TopToolbar
@onready var selected_tower_panel: VBoxContainer = $RootMargin/MainVBox/ContentArea/SelectedTowerPanel
@onready var scroll_container: ScrollContainer = $RootMargin/MainVBox/ContentArea/ScrollContainer

const TOWER_TREE_PATH := "res://data/towers_tree.json"

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
var _all_cards: Array[TowerEffectCatalogCard] = []
var _selected_card: TowerEffectCatalogCard = null

var _controller: TowerEffectCatalogController = null
var _zoom_controller: TowerEffectCatalogZoomController = null

var _side_preview: TowerCatalogPreview = null
var _side_dummy_tower: DummyTowerPreview = null
var _side_dummy_target: DummyTargetPreview = null
var _side_vfx_nodes: Array[Node] = []

func _ready() -> void:
	_load_tower_data()
	_setup_controller()
	_setup_zoom_controller()
	_build_toolbar()
	_build_side_panel_placeholder()
	_build_catalog()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
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
	for child in content_vbox.get_children():
		child.queue_free()
	_all_cards.clear()
	_selected_card = null

	var sections := _build_families()

	for ctype in SECTION_ORDER:
		if not sections.has(ctype):
			continue
		var families := _group_into_families(sections[ctype])
		if families.is_empty():
			continue
		content_vbox.add_child(_make_section_label(SECTION_LABELS.get(ctype, ctype)))
		for family in families:
			var members: Array = family["members"]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			content_vbox.add_child(row)
			for pair in members:
				var tid: String = pair[0]
				var cfg: Dictionary = pair[1].duplicate(true)
				row.add_child(_make_tower_card(tid, cfg))
			if members.size() < 3:
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(spacer)
		content_vbox.add_child(_make_separator())

func _setup_controller() -> void:
	_controller = TowerEffectCatalogController.new()
	_controller.name = "CatalogController"
	add_child(_controller)
	_controller.filters_changed.connect(_apply_filters)
	_controller.replay_selected_requested.connect(_replay_attack_vfx)
	_controller.auto_play_tick.connect(_replay_attack_vfx)

func _setup_zoom_controller() -> void:
	_zoom_controller = TowerEffectCatalogZoomController.new()

func _apply_filters() -> void:
	for card in _all_cards:
		if card._card_panel == null or not is_instance_valid(card._card_panel):
			continue
		card._card_panel.visible = card.passes_filters(
			_controller.search_text,
			_controller.element_filter,
			_controller.tier_filter,
			_controller.attack_filter
		)

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

	var preview := TowerCatalogPreview.new()
	preview.tower_id = tower_id
	preview.tower_config = cfg
	preview.preview_size = Vector2(330, 200)
	preview.camera_zoom = 1.4
	preview.show_range_ring = false
	preview.show_projectile_preview = false
	preview.show_effects_preview = false
	preview.custom_minimum_size = preview.preview_size
	preview.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(preview)

	var badge_text := _get_vfx_badge(tower_id, tier)
	var badge_label := Label.new()
	badge_label.text = "VFX: " + badge_text
	badge_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(badge_label)

	vbox.add_child(_make_stat_label(
		"ATK: %s  TYPE: %s" % [str(cfg.get("attack_type", "-")), str(cfg.get("visual_type", "-"))],
		Color(0.55, 0.65, 0.85)
	))

	var card_script := TowerEffectCatalogCard.new()
	card_script.name = "CardScript"
	card_script._vfx_badge_label = badge_label
	card_script._normal_style = normal_style
	card_script._selected_style = selected_style
	card.add_child(card_script)
	card_script.setup(card, tower_id, cfg)
	card_script.set_vfx_badge(badge_text)
	card_script.card_selected.connect(_on_card_selected)
	_all_cards.append(card_script)

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

func _str_or_dash(value: float) -> String:
	return "—" if value == 0.0 else str(value)

func _get_first_level_value(cfg: Dictionary, key: String, fallback: float) -> Variant:
	if cfg.has("levels") and cfg["levels"] is Array and cfg["levels"].size() > 0:
		return cfg["levels"][0].get(key, fallback)
	return cfg.get(key, fallback)

# stubs — fully implemented in Tasks 5, 6, 7

func _build_toolbar() -> void:
	_zoom_controller.setup(content_vbox, scroll_container)

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
	top_toolbar.add_child(_make_toolbar_toggle("Attack VFX", true, func(v: bool) -> void:
		_controller.show_attack_vfx = v
		if not v:
			_clear_attack_vfx_nodes()
	))
	top_toolbar.add_child(_make_toolbar_toggle("Status FX", true, func(v: bool) -> void:
		_controller.show_status_fx = v
	))
	top_toolbar.add_child(_make_toolbar_toggle("Support FX", true, func(v: bool) -> void:
		_controller.show_support_fx = v
	))

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
	_controller.set_status_labels(fps_label, vfx_label)

func _build_side_panel_placeholder() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.95)
	style.border_color = Color(0.15, 0.45, 0.65, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	selected_tower_panel.add_theme_stylebox_override("panel", style)

	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Click a tower to inspect"
	placeholder.add_theme_font_size_override("font_size", 13)
	placeholder.add_theme_color_override("font_color", Color(0.35, 0.45, 0.55))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selected_tower_panel.add_child(placeholder)

func _on_card_selected(tower_id: String, cfg: Dictionary) -> void:
	if _selected_card != null:
		_selected_card.set_selected(false)
	for card in _all_cards:
		if card.tower_id == tower_id:
			_selected_card = card
			card.set_selected(true)
			break
	_populate_side_panel(tower_id, cfg)

func _replay_attack_vfx() -> void:
	if _selected_card == null or _side_preview == null:
		return
	if not _controller.show_attack_vfx:
		return
	if PerformanceFirebreak.disable_all_attack_vfx:
		return

	var tower_id: String = _selected_card.tower_id
	var script: GDScript = TowerAttackVFXRegistry.get_vfx_script(tower_id)
	if script == null:
		return

	var vfx_viewport: SubViewport = _side_preview.get_vfx_viewport()
	if vfx_viewport == null:
		return

	if _side_dummy_tower == null:
		_side_dummy_tower = DummyTowerPreview.new()
		_side_dummy_tower.position = Vector2(-80, 0)
		vfx_viewport.add_child(_side_dummy_tower)

	if _side_dummy_target == null:
		_side_dummy_target = DummyTargetPreview.new()
		_side_dummy_target.position = Vector2(80, 0)
		vfx_viewport.add_child(_side_dummy_target)

	var elements: Array = _selected_card.cfg.get("elements", [])
	var color: Color = Color(0.45, 0.92, 1.0)
	if not elements.is_empty():
		color = ELEM_COLOR.get(str(elements[0]), color)

	_side_dummy_tower.setup(tower_id, color)

	var vfx_node := Node2D.new()
	vfx_node.set_script(script)
	vfx_viewport.add_child(vfx_node)
	vfx_node.setup(
		_side_dummy_tower.position,
		_side_dummy_target.position,
		color
	)
	vfx_node.configure({})
	_side_vfx_nodes.append(vfx_node)

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

func _populate_side_panel(tower_id: String, cfg: Dictionary) -> void:
	for child in selected_tower_panel.get_children():
		child.queue_free()
	_side_preview = null
	_side_dummy_tower = null
	_side_dummy_target = null
	_side_vfx_nodes.clear()

	var title := Label.new()
	title.text = str(cfg.get("display_name", tower_id))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	title.clip_text = true
	selected_tower_panel.add_child(title)

	selected_tower_panel.add_child(_make_side_stat("ID", tower_id, Color(0.5, 0.65, 0.8)))

	var tier: int = int(cfg.get("tier", 1))
	var tier_str := "T%d" % tier if tier <= 3 else ("Pure" if tier == 4 else "Tier %d" % tier)
	selected_tower_panel.add_child(_make_side_stat("Tier", tier_str, TIER_BADGE_COLOR.get(tier, Color.WHITE)))

	var elements: Array = cfg.get("elements", [])
	if not elements.is_empty():
		selected_tower_panel.add_child(_make_element_badge(elements))

	selected_tower_panel.add_child(_make_side_stat("Attack", str(cfg.get("attack_type", "-")), Color(0.7, 0.82, 0.9)))
	selected_tower_panel.add_child(_make_side_stat("Visual", str(cfg.get("visual_type", "-")), Color(0.6, 0.72, 0.85)))

	var status_effect: String = str(cfg.get("status_effect", ""))
	if status_effect != "" and status_effect != "null":
		selected_tower_panel.add_child(_make_side_stat("Status FX", status_effect, Color(0.55, 0.95, 0.72)))

	var support_type: String = str(cfg.get("support_type", ""))
	if support_type != "" and support_type != "null":
		selected_tower_panel.add_child(_make_side_stat("Support", support_type, Color(0.95, 0.78, 0.38)))

	var vfx_path_label := Label.new()
	vfx_path_label.text = "VFX path:"
	vfx_path_label.add_theme_font_size_override("font_size", 11)
	vfx_path_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	selected_tower_panel.add_child(vfx_path_label)

	var path_edit := LineEdit.new()
	path_edit.text = "res://scripts/vfx/towers/%s_attack_vfx.gd" % tower_id
	path_edit.editable = false
	path_edit.add_theme_font_size_override("font_size", 10)
	selected_tower_panel.add_child(path_edit)

	var badge_text := _get_vfx_badge(tower_id, tier)
	var badge_label := Label.new()
	badge_label.text = "VFX status: " + badge_text
	badge_label.add_theme_font_size_override("font_size", 12)
	selected_tower_panel.add_child(badge_label)

	selected_tower_panel.add_child(_make_side_separator())

	var replay_atk := Button.new()
	replay_atk.text = "▶  Replay Attack"
	replay_atk.pressed.connect(_replay_attack_vfx)
	selected_tower_panel.add_child(replay_atk)

	var replay_status := Button.new()
	replay_status.text = "◉  Replay Status"
	replay_status.pressed.connect(_show_status_preview)
	selected_tower_panel.add_child(replay_status)

	var replay_support := Button.new()
	replay_support.text = "⬡  Replay Support"
	replay_support.pressed.connect(_show_support_preview)
	selected_tower_panel.add_child(replay_support)

	selected_tower_panel.add_child(_make_side_separator())

	_side_preview = TowerCatalogPreview.new()
	_side_preview.tower_id = tower_id
	_side_preview.tower_config = cfg
	_side_preview.preview_size = Vector2(300, 200)
	_side_preview.camera_zoom = 1.2
	_side_preview.show_range_ring = true
	_side_preview.show_projectile_preview = false
	_side_preview.show_effects_preview = false
	_side_preview.custom_minimum_size = _side_preview.preview_size
	selected_tower_panel.add_child(_side_preview)

func _make_side_stat(key: String, value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = "%s: %s" % [key, value]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label

func _make_side_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.custom_minimum_size.y = 1
	sep.color = Color(0.2, 0.5, 0.7, 0.3)
	return sep

# show_effects_preview=true triggers PreviewFxLayer — status icons or support aura based on tower's attack_type
func _show_status_preview() -> void:
	if _side_preview == null:
		return
	_side_preview.set_preview_options(
		_side_preview.show_range_ring,
		false,
		true,
		false
	)

# show_effects_preview=true triggers PreviewFxLayer — same flag, visual differs by tower attack_type/_is_support_style()
func _show_support_preview() -> void:
	if _side_preview == null:
		return
	_side_preview.set_preview_options(
		_side_preview.show_range_ring,
		false,
		true,
		false
	)
