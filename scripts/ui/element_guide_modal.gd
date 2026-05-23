extends "res://scripts/ui/modal_panel_controller.gd"
## Element Guide Modal
##
## A reference popup showing each element's role, attack types, strengths,
## weaknesses, best targets, and recommended usage.
##
## Public API:
##   set_element_levels(levels: Dictionary)  -- call whenever HUD levels update
##   open_at(element_id: String = "")        -- show the modal, optionally pre-selecting an element

const _ELEMENT_ORDER: Array[String] = ["light", "darkness", "water", "fire", "nature", "earth"]

const _ELEMENT_META := {
	"light": {
		"description": "The power of radiance and purification. Precise and far-reaching.",
		"attack_types": ["Single Target", "Precision Beam", "Long Range"],
		"strengths": ["Highest range tier", "Reliable single-target DPS", "Hits Air"],
		"weaknesses": ["No native AoE", "Costly dual combos"],
		"best_against": "High-HP targets, fast flyers, armored units",
		"recommended": "Long-range precision — effective from wave 1.",
	},
	"darkness": {
		"description": "Void entropy that weakens and debuffs anything caught in its field.",
		"attack_types": ["Aura / Debuff", "Vulnerability AoE", "DoT"],
		"strengths": ["Amplifies all other towers", "Strong AoE debuffs", "Scales late"],
		"weaknesses": ["Ground only", "Low raw damage alone"],
		"best_against": "Tanky groups, armored enemies, clustered waves",
		"recommended": "Pair with any damage element for massive synergy.",
	},
	"water": {
		"description": "Ice and tidal force that freezes enemies in their path.",
		"attack_types": ["Slow / Control", "AoE Freeze", "Zone Denial"],
		"strengths": ["Best crowd control", "Effective vs all speeds", "Hits Air"],
		"weaknesses": ["Lower direct damage", "Relies on other DPS towers"],
		"best_against": "Fast enemies, boss rushes, air units",
		"recommended": "Always strong — pairs with every damage element.",
	},
	"fire": {
		"description": "Explosive plasma that burns everything in a radius.",
		"attack_types": ["AoE Splash", "Cannon Burst", "Ground Only"],
		"strengths": ["Heavy splash damage", "Melts groups fast"],
		"weaknesses": ["Ground only", "Slow fire rate", "High build cost"],
		"best_against": "Grouped ground enemies, tanky clumps",
		"recommended": "Place at chokepoints and path bends.",
	},
	"nature": {
		"description": "Rapid bio-circuit energy and spreading vine spores.",
		"attack_types": ["Rapid Fire", "Multi-Shot", "Spore DoT"],
		"strengths": ["Fastest attack speed", "Hits Air", "Spore debuffs"],
		"weaknesses": ["Lower damage per hit", "Short-medium range"],
		"best_against": "Swarm waves, fast enemies, healers",
		"recommended": "Consistent DPS filler — never wasted.",
	},
	"earth": {
		"description": "Seismic armored stone that crushes the heaviest targets.",
		"attack_types": ["Single Target", "Heavy Cannon", "Seismic AoE"],
		"strengths": ["Highest raw damage", "Hard-hitting shots"],
		"weaknesses": ["Ground only", "Slowest attack rate"],
		"best_against": "Tanks, bosses, high-HP priority targets",
		"recommended": "Mid-to-late game when HP pools scale.",
	},
}

var _element_levels: Dictionary = {}
var _selected_element: String = ""

var _left_col: VBoxContainer = null
var _detail_col: VBoxContainer = null
var _row_panels: Dictionary = {}  # element_id -> PanelContainer (left list rows)
var _row_icons: Dictionary = {}   # element_id -> ElementIcon (for locked/unlocked refresh)

func _ready() -> void:
	_max_panel_width = 680.0
	super._ready()
	set_title("ELEMENT GUIDE")

# ── Public API ─────────────────────────────────────────────────────────────────

func set_element_levels(levels: Dictionary) -> void:
	_element_levels = levels.duplicate()
	_refresh_level_badges()

func open_at(element_id: String = "") -> void:
	var target: String = element_id if _ELEMENT_META.has(element_id) else _ELEMENT_ORDER[0]
	_select_element(target)
	show()

# ── Content build ──────────────────────────────────────────────────────────────

func _build_modal_content() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	_scroll_content.add_child(columns)

	# Left: element list
	_left_col = VBoxContainer.new()
	_left_col.custom_minimum_size = Vector2(178.0, 0.0)
	_left_col.add_theme_constant_override("separation", 3)
	columns.add_child(_left_col)

	var list_hdr := _make_label("ELEMENTS", 10, _C_INK3)
	_left_col.add_child(list_hdr)

	for eid in _ELEMENT_ORDER:
		var row := _make_element_row(eid)
		_left_col.add_child(row)

	# Vertical separator
	var vsep := VSeparator.new()
	vsep.add_theme_color_override("color", _C_LINE2)
	vsep.custom_minimum_size = Vector2(1.0, 0.0)
	columns.add_child(vsep)

	# Right: detail content
	_detail_col = VBoxContainer.new()
	_detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_col.add_theme_constant_override("separation", 8)
	columns.add_child(_detail_col)

	_add_detail_placeholder()

	# Footer close
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0.0, 40.0)
	close_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(close_btn, _C_CYAN)
	close_btn.pressed.connect(_close_self)
	_footer.add_child(close_btn)

# ── Element list rows ──────────────────────────────────────────────────────────

func _make_element_row(eid: String) -> PanelContainer:
	var color := ElementIcon.color_for(eid)
	var panel := PanelContainer.new()
	panel.name = "ElementRow_%s" % eid
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 40.0)
	panel.add_theme_stylebox_override("panel", _row_style(color, false))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_select_element(eid))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   7)
	margin.add_theme_constant_override("margin_right",  7)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := ElementIcon.new()
	icon.configure([eid], false)  # starts locked; updated by _refresh_level_badges
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_row_icons[eid] = icon

	var name_lbl := Label.new()
	name_lbl.text = ElementIconDraw.get_display_name(eid)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", _C_INK1)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var level_lbl := Label.new()
	level_lbl.name = "LevelBadge"
	level_lbl.text = ""
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.add_theme_color_override("font_color", _C_INK3)
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_lbl)

	_row_panels[eid] = panel
	return panel

func _row_style(color: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(color.r, color.g, color.b, 0.18)
		s.border_color = Color(color.r, color.g, color.b, 0.70)
		s.set_border_width_all(1)
		s.set_border_width(SIDE_LEFT, 3)
	else:
		s.bg_color = Color(color.r, color.g, color.b, 0.04)
		s.border_color = Color(color.r, color.g, color.b, 0.0)
		s.set_border_width_all(0)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 0
	s.content_margin_right  = 0
	s.content_margin_top    = 0
	s.content_margin_bottom = 0
	return s

# ── Selection & detail ─────────────────────────────────────────────────────────

func _select_element(eid: String) -> void:
	if not _ELEMENT_META.has(eid):
		return
	_selected_element = eid
	_refresh_row_highlights()
	_rebuild_detail(eid)

func _refresh_row_highlights() -> void:
	for eid in _row_panels:
		var panel: PanelContainer = _row_panels[eid]
		if not is_instance_valid(panel):
			continue
		var color := ElementIcon.color_for(eid)
		panel.add_theme_stylebox_override("panel", _row_style(color, eid == _selected_element))

func _refresh_level_badges() -> void:
	for eid in _row_panels:
		var panel: PanelContainer = _row_panels[eid]
		if not is_instance_valid(panel):
			continue
		var level: int = int(_element_levels.get(eid, 0))
		var unlocked: bool = level > 0

		# Update the ElementIcon locked/unlocked state
		var icon: ElementIcon = _row_icons.get(eid)
		if icon != null and is_instance_valid(icon):
			icon.configure([eid], unlocked)

		# Update the level text badge
		var margin := panel.get_child(0) as MarginContainer
		if margin == null:
			continue
		var hbox := margin.get_child(0) as HBoxContainer
		if hbox == null:
			continue
		for child in hbox.get_children():
			if child.name == "LevelBadge":
				child.text = "Lv%d" % level if unlocked else ""
				break

func _add_detail_placeholder() -> void:
	var lbl := _make_label("Select an element from the list.", 13, _C_INK3)
	lbl.name = "Placeholder"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_col.add_child(lbl)

func _rebuild_detail(eid: String) -> void:
	for child in _detail_col.get_children():
		child.queue_free()

	var meta: Dictionary = _ELEMENT_META.get(eid, {})
	if meta.is_empty():
		_add_detail_placeholder()
		return

	var color := ElementIcon.color_for(eid)
	var level: int = int(_element_levels.get(eid, 0))
	var unlocked: bool = level > 0

	# Header: large icon + name + level
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_detail_col.add_child(header)

	var big_icon := ElementIcon.new()
	big_icon.configure([eid], unlocked)
	big_icon.custom_minimum_size = Vector2(48.0, 48.0)
	big_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(big_icon)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.add_theme_constant_override("separation", 2)
	header.add_child(name_col)

	var name_lbl := _make_label(ElementIconDraw.get_display_name(eid).to_upper(), 20, color)
	name_col.add_child(name_lbl)

	var sub_text := "Lv. %d / 3" % level if unlocked else "Not yet chosen"
	var sub_lbl := _make_label(sub_text, 11, _C_INK3 if not unlocked else color)
	name_col.add_child(sub_lbl)

	# Description
	var desc_lbl := _make_label(meta.get("description", ""), 13, _C_INK2, true)
	_detail_col.add_child(desc_lbl)

	_add_separator(_detail_col)

	# Attack types
	_add_detail_section("Attack Types", meta.get("attack_types", []), _C_CYAN)

	# Strengths & weaknesses
	_add_detail_section("Strengths", meta.get("strengths", []), _C_OK)
	_add_detail_section("Weaknesses", meta.get("weaknesses", []), _C_RED)

	_add_separator(_detail_col)

	# Best against
	_add_key_value("Best Against", meta.get("best_against", ""), color)

	# Recommended
	_add_key_value("Tip", meta.get("recommended", ""), _C_WARN)

func _add_detail_section(title: String, items: Array, accent: Color) -> void:
	if items.is_empty():
		return
	var title_lbl := _make_label(title.to_upper(), 10, accent)
	_detail_col.add_child(title_lbl)

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 3)
	_detail_col.add_child(wrap)

	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		wrap.add_child(row)

		var bullet := _make_label("·", 13, Color(accent.r, accent.g, accent.b, 0.70))
		row.add_child(bullet)

		var lbl := _make_label(str(item), 13, _C_INK2, true)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

func _add_key_value(key: String, value: String, accent: Color) -> void:
	if value.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail_col.add_child(row)

	var key_lbl := _make_label(key + ":", 11, accent)
	key_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key_lbl.custom_minimum_size = Vector2(78.0, 0.0)
	row.add_child(key_lbl)

	var val_lbl := _make_label(value, 12, _C_INK2, true)
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val_lbl)
