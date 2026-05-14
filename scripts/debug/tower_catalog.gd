extends Control

## Debug Tower Catalog — standalone scene for reviewing tower models, roles, and element identity.
## Does NOT depend on main.gd, gameplay systems, or live tower nodes.
## Runs by opening res://scenes/debug/tower_catalog.tscn directly in Godot.

@onready var content_vbox: VBoxContainer = $RootMargin/MainVBox/ScrollContainer/ContentVBox

const TOWER_TREE_PATH := "res://data/towers_tree.json"

var _detail_overlay: Control = null
var _detail_content: VBoxContainer = null
var _detail_preview: TowerCatalogPreview = null

# ── Element label helpers ──────────────────────────────────────────────

const ELEM_SHORT := {
	"light": "L", "darkness": "D", "water": "W", "fire": "F",
	"nature": "Na","earth": "E",
}

const ELEM_COLOR := {
	"light": Color(0.95, 0.92, 0.3),
	"darkness": Color(0.55, 0.15, 0.75),
	"water": Color(0.2, 0.55, 0.95),
	"fire": Color(1.0, 0.35, 0.15),
	"nature": Color(0.25, 0.85, 0.3),
	"earth": Color(0.65, 0.4, 0.2),
}

const ELEM_DISPLAY := {
	"light": "Light", "darkness": "Darkness", "water": "Water",
	"fire": "Fire", "nature": "Nature", "earth": "Earth",
}

# ── Tower definitions ──────────────────────────────────────────────────

## Towers to display in the catalog, in display order.
## Each entry maps to a key in towers_tree.json + catalog-specific overrides.
const CATALOG_ENTRIES := [
	# Neutral
	{"id": "basic_tower_t1",       "group": "Neutral",         "role": "Single Target", "target": "Land + Air"},
	{"id": "neutral_cannon_tower",  "group": "Neutral",         "role": "AoE Splash",    "target": "Land"},

	# Single Element
	{"id": "light_t1",    "group": "Single Element", "role": "Precision Sniper", "target": "Land + Air"},
	{"id": "darkness_t1", "group": "Single Element", "role": "Void Amplifier",   "target": "Land"},
	{"id": "water_t1",    "group": "Single Element", "role": "Cryo Control",     "target": "Land + Air"},
	{"id": "fire_t1",     "group": "Single Element", "role": "Plasma Splash",    "target": "Land"},
	{"id": "nature_t1",   "group": "Single Element", "role": "Rapid Fire",       "target": "Land + Air"},
	{"id": "earth_t1",    "group": "Single Element", "role": "Seismic Impact",   "target": "Land"},

	# Dual Element
	{"id": "trickery_t1",      "group": "Dual Element", "role": "Clone Support",     "target": "Tower Support"},
	{"id": "blacksmith_t1",    "group": "Dual Element", "role": "Damage Buffer",     "target": "Tower Support"},
	{"id": "electricity_t1",   "group": "Dual Element", "role": "Chain Lightning",   "target": "Land + Air"},
	{"id": "ice_t1",           "group": "Dual Element", "role": "Deep Freeze",       "target": "Land + Air"},
	{"id": "life_t1",          "group": "Dual Element", "role": "Regen Support",     "target": "Tower Support"},
	{"id": "quark_t1",         "group": "Dual Element", "role": "Precision Cannon",  "target": "Land + Air"},
	{"id": "magic_t1",         "group": "Dual Element", "role": "Chaos Damage",      "target": "Land"},
	{"id": "poison_t1",        "group": "Dual Element", "role": "DoT / Debuff",      "target": "Land + Air"},
	{"id": "disease_t1",       "group": "Dual Element", "role": "Spread DoT",        "target": "Land"},
	{"id": "gunpowder_t1",     "group": "Dual Element", "role": "Heavy Artillery",   "target": "Land"},
	{"id": "vapor_t1",         "group": "Dual Element", "role": "Steam AoE",         "target": "Land"},
	{"id": "well_t1",          "group": "Dual Element", "role": "Speed Buffer",      "target": "Tower Support"},
	{"id": "hydro_t1",         "group": "Dual Element", "role": "Erosion Splash",    "target": "Land"},
	{"id": "flame_t1",         "group": "Dual Element", "role": "Wildfire",          "target": "Land"},
	{"id": "mushroom_t1",      "group": "Dual Element", "role": "Spore AoE",         "target": "Land"},

	# Triple Element
	{"id": "hail_t1",          "group": "Triple Element", "role": "Storm Barrage",     "target": "Land + Air"},
	{"id": "jinx_t1",          "group": "Triple Element", "role": "Chaos Curse",       "target": "Land"},
	{"id": "laser_t1",         "group": "Triple Element", "role": "Piercing Beam",     "target": "Land + Air"},
	{"id": "oblivion_t1",      "group": "Triple Element", "role": "Entropy Nova",      "target": "Land"},
	{"id": "windstorm_t1",     "group": "Triple Element", "role": "Tempest",           "target": "Land + Air"},
	{"id": "tidal_t1",         "group": "Triple Element", "role": "Healing Wave",      "target": "Land + Air"},
	{"id": "polar_t1",         "group": "Triple Element", "role": "Absolute Zero",     "target": "Land + Air"},
	{"id": "nova_t1",          "group": "Triple Element", "role": "Solar Flare",       "target": "Land"},
	{"id": "gold_t1",          "group": "Triple Element", "role": "Midas Ray",         "target": "Land + Air"},
	{"id": "enchantment_t1",   "group": "Triple Element", "role": "Empower Aura",      "target": "Tower Support"},
	{"id": "corrosion_t1",     "group": "Triple Element", "role": "Acid Splash",       "target": "Land"},
	{"id": "drowning_t1",      "group": "Triple Element", "role": "Suffocation",       "target": "Land"},
	{"id": "muck_t1",          "group": "Triple Element", "role": "Tar Pit",           "target": "Land"},
	{"id": "voodoo_t1",        "group": "Triple Element", "role": "Hex Curse",         "target": "Land"},
	{"id": "flamethrower_t1",  "group": "Triple Element", "role": "Inferno Cone",      "target": "Land"},
	{"id": "roots_t1",         "group": "Triple Element", "role": "Entangling Snare",  "target": "Land"},
	{"id": "impulse_t1",       "group": "Triple Element", "role": "Volatile Burst",    "target": "Land"},
	{"id": "zealot_t1",        "group": "Triple Element", "role": "Fervent Strike",    "target": "Land + Air"},
	{"id": "flesh_golem_t1",   "group": "Triple Element", "role": "Regenerating Tank", "target": "Tower Support"},
	{"id": "quaker_t1",        "group": "Triple Element", "role": "Earthquake",        "target": "Land"},
]

const GROUP_ORDER := ["Neutral", "Single Element", "Dual Element", "Triple Element"]

var _towers_config: Dictionary = {}


# ── Lifecycle ──────────────────────────────────────────────────────────

func _ready() -> void:
	_load_tower_data()
	_ensure_detail_overlay()
	_build_catalog()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _detail_overlay and _detail_overlay.visible:
			_close_detail_overlay()
			return
		get_tree().quit()


func _load_tower_data() -> void:
	if not FileAccess.file_exists(TOWER_TREE_PATH):
		push_error("[TowerCatalog] towers_tree.json not found at: %s" % TOWER_TREE_PATH)
		return
	var file := FileAccess.open(TOWER_TREE_PATH, FileAccess.READ)
	if file == null:
		push_error("[TowerCatalog] Failed to open towers_tree.json")
		return
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[TowerCatalog] JSON parse error: %s" % json.get_error_message())
		return
	_towers_config = json.data


# ── Catalog builder ────────────────────────────────────────────────────

func _build_catalog() -> void:
	for child in content_vbox.get_children():
		child.queue_free()

	for group_name in GROUP_ORDER:
		var towers: Array = []
		for entry in CATALOG_ENTRIES:
			if entry.get("group", "") != group_name:
				continue
			var tid: String = entry.get("id", "")
			var cfg: Dictionary = _towers_config.get(tid, {}).duplicate(true)
			if cfg.is_empty():
				push_warning("[TowerCatalog] No config found for tower id: %s" % tid)
				continue
			# Merge catalog-specific overrides into the config copy
			cfg["_role"] = entry.get("role", "")
			cfg["_target"] = entry.get("target", "")
			towers.append(cfg)

		if towers.is_empty():
			continue

		content_vbox.add_child(_make_section_label(group_name))
		content_vbox.add_child(_make_grid(towers))
		content_vbox.add_child(_make_separator())


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = "▸  " + text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	label.custom_minimum_size = Vector2(0, 36)
	return label


func _make_separator() -> Control:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	return sep


func _make_grid(towers: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)

	for cfg in towers:
		grid.add_child(_make_tower_card(cfg))

	return grid


# ── Card builder ───────────────────────────────────────────────────────

func _make_tower_card(cfg: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 430)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var captured_cfg := cfg.duplicate(true)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_detail_overlay(captured_cfg)
	)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.10, 0.92)
	panel_style.border_color = Color(0.12, 0.55, 0.85, 0.6)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Top row: element badge(s) + name
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	var elements: Array = cfg.get("elements", [])
	if not elements.is_empty():
		var badge := _make_element_badge(elements)
		top_row.add_child(badge)

	var name_str: String = cfg.get("display_name", cfg.get("name", "Unknown"))
	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	# Preview area — uses real Tower scene via SubViewport
	var preview := TowerCatalogPreview.new()
	preview.tower_id = cfg.get("id", "")
	preview.tower_config = cfg
	preview.preview_size = Vector2(340, 220)
	preview.camera_zoom = 1.5
	preview.show_range_ring = true
	preview.show_projectile_preview = false
	preview.show_effects_preview = false
	preview.custom_minimum_size = preview.preview_size
	preview.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(preview)

	# Stat rows
	var role_text := "Role: %s" % cfg.get("_role", "-")
	vbox.add_child(_make_stat_label(role_text, Color(0.70, 0.82, 0.90)))

	var cost_text := "Cost: $%s" % str(cfg.get("cost", "-"))
	vbox.add_child(_make_stat_label(cost_text, Color(1.0, 0.82, 0.18)))

	var rng: float = 0.0
	var dmg: float = 0.0
	var fr: float = 0.0
	if cfg.has("levels") and cfg["levels"].size() > 0:
		rng = cfg["levels"][0].get("range", 0.0)
		dmg = cfg["levels"][0].get("damage", 0.0)
		fr = cfg["levels"][0].get("fire_rate", 0.0)
	else:
		rng = cfg.get("range", 0.0)
		dmg = cfg.get("damage", 0.0)
		fr = cfg.get("fire_rate", 0.0)

	var stats_text := "Rng: %s  Dmg: %s  Spd: %s" % [
		str(rng),
		_str_or_dash(dmg),
		_str_or_dash(fr),
	]
	vbox.add_child(_make_stat_label(stats_text, Color(0.55, 0.65, 0.85)))

	var target_text := "Target: %s" % cfg.get("_target", "-")
	vbox.add_child(_make_stat_label(target_text, Color(0.45, 0.55, 0.7)))

	var desc: String = cfg.get("description", "")
	if desc != "":
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(0, 28)
		vbox.add_child(desc_label)

	_make_click_passthrough(margin)
	return card


func _make_click_passthrough(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_make_click_passthrough(child)


# ── Detail overlay ─────────────────────────────────────────────────────

func _ensure_detail_overlay() -> void:
	if _detail_overlay != null:
		return
	_detail_overlay = Control.new()
	_detail_overlay.name = "DetailOverlay"
	_detail_overlay.visible = false
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_detail_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_overlay.add_child(dim)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 56)
	outer_margin.add_theme_constant_override("margin_right", 56)
	outer_margin.add_theme_constant_override("margin_top", 42)
	outer_margin.add_theme_constant_override("margin_bottom", 42)
	_detail_overlay.add_child(outer_margin)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.075, 0.98)
	style.border_color = Color(0.18, 0.72, 0.95, 0.80)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	outer_margin.add_child(panel)

	_detail_content = VBoxContainer.new()
	_detail_content.add_theme_constant_override("separation", 12)
	panel.add_child(_detail_content)


func _open_detail_overlay(cfg: Dictionary) -> void:
	_ensure_detail_overlay()
	for child in _detail_content.get_children():
		child.queue_free()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_detail_content.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = str(cfg.get("display_name", cfg.get("name", "Unknown Tower")))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.82, 0.98, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s  •  %s  •  %s" % [str(cfg.get("combo_type", "neutral")).capitalize(), str(cfg.get("_role", "-")), str(cfg.get("_target", "-"))]
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.76, 0.88))
	title_box.add_child(subtitle)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(96, 36)
	close_btn.pressed.connect(_close_detail_overlay)
	header.add_child(close_btn)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	_detail_content.add_child(body)

	_detail_preview = TowerCatalogPreview.new()
	_detail_preview.tower_id = cfg.get("id", "")
	_detail_preview.tower_config = cfg
	_detail_preview.preview_size = Vector2(800, 560)
	_detail_preview.camera_zoom = 1.22
	_detail_preview.show_range_ring = true
	_detail_preview.show_projectile_preview = true
	_detail_preview.show_effects_preview = true
	_detail_preview.custom_minimum_size = _detail_preview.preview_size
	body.add_child(_detail_preview)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)

	var elements: Array = cfg.get("elements", [])
	if not elements.is_empty():
		side.add_child(_make_element_badge(elements))
	side.add_child(_make_detail_stat("Cost", "$%s" % str(cfg.get("cost", "-")), Color(1.0, 0.82, 0.18)))
	side.add_child(_make_detail_stat("Range", str(_get_first_level_value(cfg, "range", 0.0)), Color(0.70, 0.88, 1.0)))
	side.add_child(_make_detail_stat("Damage", _str_or_dash(float(_get_first_level_value(cfg, "damage", 0.0))), Color(0.92, 0.96, 1.0)))
	side.add_child(_make_detail_stat("Speed", _str_or_dash(float(_get_first_level_value(cfg, "fire_rate", 0.0))), Color(0.70, 0.82, 0.90)))
	side.add_child(_make_detail_stat("Attack", str(cfg.get("attack_type", "single")), Color(0.55, 0.78, 0.92)))
	side.add_child(_make_detail_stat("Target", str(cfg.get("_target", "-")), Color(0.55, 0.70, 0.82)))

	var desc := Label.new()
	desc.text = str(cfg.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.58, 0.68, 0.78))
	side.add_child(desc)

	side.add_child(_make_detail_separator())
	side.add_child(_make_preview_toggle("Range Ring", true, func(v: bool) -> void:
		if _detail_preview: _detail_preview.set_preview_options(v, _detail_preview.show_projectile_preview, _detail_preview.show_effects_preview, _detail_preview.preview_paused)
	))
	side.add_child(_make_preview_toggle("Projectile Preview", true, func(v: bool) -> void:
		if _detail_preview: _detail_preview.set_preview_options(_detail_preview.show_range_ring, v, _detail_preview.show_effects_preview, _detail_preview.preview_paused)
	))
	side.add_child(_make_preview_toggle("Effects Preview", true, func(v: bool) -> void:
		if _detail_preview: _detail_preview.set_preview_options(_detail_preview.show_range_ring, _detail_preview.show_projectile_preview, v, _detail_preview.preview_paused)
	))
	side.add_child(_make_preview_toggle("Pause Preview", false, func(v: bool) -> void:
		if _detail_preview: _detail_preview.set_preview_options(_detail_preview.show_range_ring, _detail_preview.show_projectile_preview, _detail_preview.show_effects_preview, v)
	))

	_detail_overlay.show()


func _close_detail_overlay() -> void:
	if _detail_overlay:
		_detail_overlay.hide()
	if _detail_preview:
		_detail_preview.queue_free()
		_detail_preview = null


func _make_detail_stat(label_text: String, value_text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = "%s: %s" % [label_text, value_text]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	return label


func _make_detail_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.custom_minimum_size.y = 1
	sep.color = Color(0.25, 0.65, 0.85, 0.35)
	return sep


func _make_preview_toggle(text: String, pressed: bool, callback: Callable) -> CheckBox:
	var toggle := CheckBox.new()
	toggle.text = text
	toggle.button_pressed = pressed
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.toggled.connect(func(value: bool) -> void:
		callback.call(value)
	)
	return toggle


func _get_first_level_value(cfg: Dictionary, key: String, fallback: float) -> Variant:
	if cfg.has("levels") and cfg["levels"] is Array and cfg["levels"].size() > 0:
		return cfg["levels"][0].get(key, fallback)
	return cfg.get(key, fallback)


func _make_element_badge(elements: Array) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	for elem in elements:
		var label := Label.new()
		label.text = ELEM_SHORT.get(elem, str(elem).substr(0, 1))
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var color: Color = ELEM_COLOR.get(elem, Color(0.4, 0.5, 0.7))
		var bg := StyleBoxFlat.new()
		bg.bg_color = color
		bg.set_corner_radius_all(3)
		bg.content_margin_left = 4
		bg.content_margin_right = 4
		bg.content_margin_top = 1
		bg.content_margin_bottom = 1
		label.add_theme_stylebox_override("normal", bg)
		hbox.add_child(label)

		if elements.find(elem) < elements.size() - 1:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 10)
			plus.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			hbox.add_child(plus)

	return hbox


func _make_stat_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	return label


func _str_or_dash(value: float) -> String:
	if value == 0.0:
		return "—"
	return str(value)
