## TowerFloatCard
## Full Tower Detail floating card anchored near the selected tower.
## Replaces the left-drawer Tower Detail expanded body.
## Emits signals that game_hud.gd proxies to main.gd.
## UI-only — no gameplay logic.
extends Control

signal upgrade_requested()
signal sell_requested()
signal target_mode_changed(mode: String)

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

# Target mode data — must stay in sync with game_hud.gd target_modes / target_mode_labels.
const _MODES: Array = [
	"first","last","nearest","strongest","weakest",
	"fastest","air_first","support_first","shield_first"
]
const _MODE_LABELS: Dictionary = {
	"first":"First","last":"Last","nearest":"Closest",
	"strongest":"Strongest","weakest":"Weakest","fastest":"Fastest",
	"air_first":"Air First","support_first":"Support First","shield_first":"Shield First"
}

const CARD_WIDTH  := 292.0
const OFFSET_X    := 56.0    # gap from tower centre to near card edge
const LEFT_GUARD  := 316.0   # left of drawable area (left drawer + gap)
const TOP_GUARD   := 68.0    # top of drawable area (top HUD + gap)
const SAFE_MARGIN := 8.0
const OFFSCREEN_TOLERANCE := 96.0

var _tracked_tower: Node2D = null
var _updating_ui: bool = false

# ── UI refs ──────────────────────────────────────────────────────────────────
var _panel: PanelContainer     = null
var _name_lbl: Label           = null
var _tier_lbl: Label           = null
var _stat_dmg: Label           = null
var _stat_rng: Label           = null
var _stat_spd: Label           = null
var _stat_tgt: Label           = null
var _eff_section: Control      = null
var _eff_title_lbl: Label      = null
var _eff_body_lbl: Label       = null
var _tgt_opt: OptionButton     = null
var _upg_btn: Button           = null
var _upg_text_lbl: Label       = null
var _upg_cost_ctrl: CreditCostDisplay = null
var _sell_btn: Button          = null
var _sell_cost_ctrl: CreditCostDisplay = null

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	anchor_left   = 0.0
	anchor_top    = 0.0
	anchor_right  = 0.0
	anchor_bottom = 0.0
	mouse_filter  = MOUSE_FILTER_IGNORE
	z_index       = 10
	_build_ui()
	visible = false

# ── Build UI ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name            = "FCPanel"
	_panel.custom_minimum_size.x = CARD_WIDTH
	_panel.mouse_filter    = MOUSE_FILTER_STOP
	add_child(_panel)

	var sbg := StyleBoxFlat.new()
	sbg.bg_color     = Color(0.043, 0.059, 0.090, 0.95)
	sbg.border_color = Color(0.302, 0.851, 0.902, 0.65)
	sbg.set_border_width_all(1)
	sbg.set_corner_radius_all(2)
	sbg.content_margin_left   = 10
	sbg.content_margin_right  = 10
	sbg.content_margin_top    = 9
	sbg.content_margin_bottom = 9
	_panel.add_theme_stylebox_override("panel", sbg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(vbox)

	# ── Header: name + tier ───────────────────────────────────────────────────
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	hdr.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(hdr)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 14)
	_name_lbl.add_theme_color_override("font_color", NeonStyle.CYAN_2)
	_name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_lbl.clip_text  = true
	_name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hdr.add_child(_name_lbl)

	_tier_lbl = Label.new()
	_tier_lbl.add_theme_font_size_override("font_size", 10)
	_tier_lbl.add_theme_color_override("font_color", NeonStyle.INK_3)
	_tier_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hdr.add_child(_tier_lbl)

	vbox.add_child(_make_sep())

	# ── STATS ─────────────────────────────────────────────────────────────────
	vbox.add_child(_eyebrow("STATS"))

	var r_dmg := _make_stat_row("DMG",    NeonStyle.CYAN_2)
	_stat_dmg = r_dmg[1]; vbox.add_child(r_dmg[0])

	var r_rng := _make_stat_row("RNG",    NeonStyle.INK_2)
	_stat_rng = r_rng[1]; vbox.add_child(r_rng[0])

	var r_spd := _make_stat_row("SPD",    NeonStyle.INK_2)
	_stat_spd = r_spd[1]; vbox.add_child(r_spd[0])

	var r_tgt := _make_stat_row("TARGET", NeonStyle.INK_2)
	_stat_tgt = r_tgt[1]; vbox.add_child(r_tgt[0])

	# ── EFFECT section (hidden when no effects) ───────────────────────────────
	_eff_section = VBoxContainer.new()
	_eff_section.name = "EffectSection"
	_eff_section.add_theme_constant_override("separation", 3)
	_eff_section.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_eff_section)

	_eff_section.add_child(_make_sep())
	_eff_section.add_child(_eyebrow("EFFECT"))

	_eff_title_lbl = Label.new()
	_eff_title_lbl.add_theme_font_size_override("font_size", 12)
	_eff_title_lbl.add_theme_color_override("font_color", NeonStyle.INK_2)
	_eff_title_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	_eff_section.add_child(_eff_title_lbl)

	_eff_body_lbl = Label.new()
	_eff_body_lbl.add_theme_font_size_override("font_size", 11)
	_eff_body_lbl.add_theme_color_override("font_color", NeonStyle.INK_2)
	_eff_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_eff_body_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	_eff_section.add_child(_eff_body_lbl)

	# ── TARGETING ─────────────────────────────────────────────────────────────
	vbox.add_child(_make_sep())
	vbox.add_child(_eyebrow("TARGETING"))

	_tgt_opt = OptionButton.new()
	_tgt_opt.size_flags_horizontal = SIZE_FILL
	_tgt_opt.add_theme_font_size_override("font_size", 12)
	_tgt_opt.add_theme_color_override("font_color", NeonStyle.INK_1)
	for m in _MODES:
		_tgt_opt.add_item(_MODE_LABELS.get(m, m.capitalize()))

	var os := StyleBoxFlat.new()
	os.bg_color = NeonStyle.BG_1
	os.border_color = NeonStyle.LINE_2
	os.set_border_width_all(1)
	os.content_margin_left = 8; os.content_margin_right  = 8
	os.content_margin_top  = 4; os.content_margin_bottom = 4
	_tgt_opt.add_theme_stylebox_override("normal", os)
	_tgt_opt.add_theme_stylebox_override("hover",  os.duplicate())
	_tgt_opt.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	_tgt_opt.item_selected.connect(_on_target_selected)
	vbox.add_child(_tgt_opt)

	# ── ACTIONS ───────────────────────────────────────────────────────────────
	vbox.add_child(_make_sep())

	# Upgrade
	_upg_btn = Button.new()
	_upg_btn.text = ""
	_upg_btn.size_flags_horizontal = SIZE_FILL
	_upg_btn.custom_minimum_size.y  = 36
	_upg_btn.pressed.connect(func(): upgrade_requested.emit())
	NeonStyle.style_button(_upg_btn, NeonStyle.WARN, false)
	vbox.add_child(_upg_btn)

	var upg_row := HBoxContainer.new()
	upg_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	upg_row.offset_left  = 10; upg_row.offset_right  = -8
	upg_row.add_theme_constant_override("separation", 6)
	upg_row.mouse_filter = MOUSE_FILTER_IGNORE
	_upg_btn.add_child(upg_row)

	_upg_text_lbl = Label.new()
	_upg_text_lbl.size_flags_horizontal  = SIZE_EXPAND_FILL
	_upg_text_lbl.vertical_alignment     = VERTICAL_ALIGNMENT_CENTER
	_upg_text_lbl.add_theme_font_size_override("font_size", 12)
	_upg_text_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	upg_row.add_child(_upg_text_lbl)

	_upg_cost_ctrl = CreditCostDisplay.new()
	_upg_cost_ctrl.custom_minimum_size   = Vector2(58, 34)
	_upg_cost_ctrl.size_flags_vertical   = SIZE_SHRINK_CENTER
	_upg_cost_ctrl.mouse_filter          = MOUSE_FILTER_IGNORE
	upg_row.add_child(_upg_cost_ctrl)

	# Sell
	_sell_btn = Button.new()
	_sell_btn.text = ""
	_sell_btn.size_flags_horizontal = SIZE_FILL
	_sell_btn.custom_minimum_size.y  = 32
	_sell_btn.pressed.connect(func(): sell_requested.emit())
	NeonStyle.style_button(_sell_btn, NeonStyle.OK, false)
	vbox.add_child(_sell_btn)

	var sell_row := HBoxContainer.new()
	sell_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	sell_row.offset_left  = 10; sell_row.offset_right  = -8
	sell_row.add_theme_constant_override("separation", 6)
	sell_row.mouse_filter = MOUSE_FILTER_IGNORE
	_sell_btn.add_child(sell_row)

	var sell_lbl := Label.new()
	sell_lbl.text = "Sell +"
	sell_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	sell_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	sell_lbl.add_theme_font_size_override("font_size", 12)
	sell_lbl.add_theme_color_override("font_color", NeonStyle.OK)
	sell_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	sell_row.add_child(sell_lbl)

	_sell_cost_ctrl = CreditCostDisplay.new()
	_sell_cost_ctrl.custom_minimum_size = Vector2(58, 28)
	_sell_cost_ctrl.size_flags_vertical = SIZE_SHRINK_CENTER
	_sell_cost_ctrl.mouse_filter        = MOUSE_FILTER_IGNORE
	sell_row.add_child(_sell_cost_ctrl)

# ── Public API ───────────────────────────────────────────────────────────────

func show_for_tower(info: Dictionary, tower: Node2D) -> void:
	if not is_instance_valid(tower):
		hide_card()
		return
	_tracked_tower = tower
	_populate(info)
	visible = true
	_update_pos()

func hide_card() -> void:
	visible = false
	_tracked_tower = null

## Refresh displayed data without repositioning (e.g. after target mode change).
func refresh_info(info: Dictionary) -> void:
	if not visible:
		return
	_populate(info)

# ── Per-frame position ───────────────────────────────────────────────────────

func _process(_d: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_tracked_tower):
		hide_card()
		return
	_update_pos()

# ── Populate ─────────────────────────────────────────────────────────────────

func _populate(info: Dictionary) -> void:
	_updating_ui = true

	# Header
	_name_lbl.text = str(info.get("name", "Tower"))
	var tier: int    = int(info.get("tier", 1))
	var is_max: bool = bool(info.get("is_max_tier", false))
	var el_arr: Array = info.get("elements", [])
	var tier_text := "T%d" % tier
	if not el_arr.is_empty():
		tier_text += "  ·  %s" % _elements_short(el_arr)
	if is_max:
		tier_text += "  ·  MAX"
	_tier_lbl.text = tier_text

	# Stats
	var dmg: float   = float(info.get("damage", 0.0))
	var rng: int     = int(round(float(info.get("range", 0))))
	var spd: float   = float(info.get("fire_rate", 0.0))
	var a_dmg_bonus: int = int(info.get("active_damage_bonus_percent", 0))
	var a_spd_bonus: int = int(info.get("active_fire_rate_bonus_percent", 0))

	if a_dmg_bonus > 0:
		var eff := int(round(float(info.get("effective_damage", dmg))))
		_stat_dmg.text = "%s  (+%d%%→%d)" % [str(int(round(dmg))), a_dmg_bonus, eff]
		_stat_dmg.add_theme_color_override("font_color", NeonStyle.WARN)
	else:
		_stat_dmg.text = str(int(round(dmg))) if dmg > 0.0 else "—"
		_stat_dmg.add_theme_color_override("font_color", NeonStyle.CYAN_2)

	_stat_rng.text = ("%d tiles" % rng) if rng > 0 else "—"

	if a_spd_bonus > 0:
		var eff_rate := float(info.get("effective_fire_rate", spd))
		_stat_spd.text = "%.2fs  (+%d%%→%.2fs)" % [spd, a_spd_bonus, eff_rate]
		_stat_spd.add_theme_color_override("font_color", NeonStyle.CYAN)
	else:
		_stat_spd.text = ("%.2fs" % spd) if spd > 0.0 else "—"
		_stat_spd.add_theme_color_override("font_color", NeonStyle.INK_2)

	var a_type: String  = str(info.get("attack_type", "single"))
	var targets: Array  = info.get("target_categories", ["land"])
	if a_type in ["support_aura", "clone_support"]:
		_stat_tgt.text = "Nearby Towers"
		_stat_tgt.add_theme_color_override("font_color", NeonStyle.CYAN)
	elif targets.has("land") and targets.has("air"):
		_stat_tgt.text = "Ground + Air"
		_stat_tgt.add_theme_color_override("font_color", NeonStyle.EL_NATURE)
	elif targets.has("air"):
		_stat_tgt.text = "Air Only"
		_stat_tgt.add_theme_color_override("font_color", NeonStyle.EL_NATURE)
	else:
		_stat_tgt.text = "Ground Only"
		_stat_tgt.add_theme_color_override("font_color", NeonStyle.INK_2)

	# Effect
	var badge: String       = TowerEffectFormatter.attack_badge(info)
	var eff_lines: PackedStringArray = TowerEffectFormatter.effect_lines(info)
	var eff_body: String    = "\n".join(eff_lines)
	var has_effect: bool    = badge != "Kinetic" or eff_body != ""

	if has_effect:
		_eff_title_lbl.text = badge
		_eff_title_lbl.add_theme_color_override("font_color", _badge_color(info, badge))
		_eff_body_lbl.text    = eff_body
		_eff_body_lbl.visible = eff_body != ""
		_eff_section.visible  = true
	else:
		_eff_section.visible  = false

	# Target mode dropdown
	var cur_mode: String = str(info.get("target_mode", "first"))
	var idx: int = _MODES.find(cur_mode)
	if idx != -1:
		_tgt_opt.select(idx)

	# Upgrade button
	var upgrade_preview := _get_upgrade_preview_for_card()
	var raw_next_ids = info.get("next_upgrade_ids", upgrade_preview.get("next_upgrade_ids", []))
	var has_next_upgrade := false
	if raw_next_ids is Array:
		has_next_upgrade = not raw_next_ids.is_empty()
	if not has_next_upgrade:
		has_next_upgrade = not str(upgrade_preview.get("next_upgrade_id", "")).is_empty()
	var upgrade_cost := int(info.get("upgrade_cost", upgrade_preview.get("upgrade_cost", -1)))
	var locked_reason := str(info.get("locked_reason", upgrade_preview.get("locked_reason", ""))).strip_edges()
	var current_gold := int(info.get("current_gold", _get_current_gold_for_card()))
	var preview_can_upgrade := bool(upgrade_preview.get("can_upgrade", true))
	var can_upgrade := bool(info.get("can_upgrade", false)) and preview_can_upgrade
	var can_afford := bool(info.get("can_afford_upgrade", upgrade_preview.get("can_afford", current_gold >= upgrade_cost)))
	if is_max or not has_next_upgrade:
		_upg_btn.disabled = true
		_upg_text_lbl.text = "MAX TIER"
		_upg_text_lbl.add_theme_color_override("font_color", NeonStyle.INK_3)
		_upg_cost_ctrl.visible = false
	elif not locked_reason.is_empty():
		_upg_btn.disabled = true
		_upg_text_lbl.text = "LOCKED"
		_upg_text_lbl.add_theme_color_override("font_color", NeonStyle.INK_3)
		_upg_cost_ctrl.visible = false
	elif upgrade_cost <= 0:
		_upg_btn.disabled = true
		_upg_text_lbl.text = "Upgrade (N/A)"
		_upg_text_lbl.add_theme_color_override("font_color", NeonStyle.INK_3)
		_upg_cost_ctrl.visible = false
	elif can_upgrade and can_afford:
		_upg_btn.disabled = false
		_upg_text_lbl.text = "Upgrade  ·  Lv%d" % (tier + 1)
		_upg_text_lbl.add_theme_color_override("font_color", NeonStyle.INK_1)
		_upg_cost_ctrl.configure(upgrade_cost, true)
		_upg_cost_ctrl.visible = true
	elif can_upgrade:
		_upg_btn.disabled = true
		_upg_text_lbl.text = "Need Credits"
		_upg_text_lbl.add_theme_color_override("font_color", NeonStyle.WARN)
		_upg_cost_ctrl.configure(upgrade_cost, false)
		_upg_cost_ctrl.visible = true
	else:
		_upg_btn.disabled = true
		_upg_text_lbl.text = "Upgrade (N/A)"
		_upg_text_lbl.add_theme_color_override("font_color", NeonStyle.INK_3)
		_upg_cost_ctrl.visible = false

	# Sell button
	var refund: int = int(info.get("sell_refund", 0))
	_sell_cost_ctrl.configure(refund, true)

	_updating_ui = false

# ── Position ─────────────────────────────────────────────────────────────────

func _update_pos() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	# vp.get_canvas_transform() correctly maps world → screen pixels regardless
	# of the project's stretch mode, unlike manual camera-based calculations.
	var tower_screen: Vector2 = vp.get_canvas_transform() * _tracked_tower.global_position
	var vp_size: Vector2 = vp.get_visible_rect().size

	var screen_bounds := Rect2(Vector2.ZERO, vp_size).grow(OFFSCREEN_TOLERANCE)
	if not screen_bounds.has_point(tower_screen):
		position = Vector2(-10000.0, -10000.0)
		return

	var card_size := _get_card_size()

	# Preferred X: right of tower; flip left if card would overflow.
	var px: float = tower_screen.x + OFFSET_X
	if px + card_size.x > vp_size.x - SAFE_MARGIN:
		px = tower_screen.x - card_size.x - OFFSET_X

	# Preferred Y: above tower; flip below if card would go above top bar.
	var py: float = tower_screen.y - card_size.y - 20.0
	if py < TOP_GUARD + 4.0:
		py = tower_screen.y + 36.0

	px = clampf(px, LEFT_GUARD, vp_size.x - card_size.x - SAFE_MARGIN)
	py = clampf(py, TOP_GUARD + 4.0, vp_size.y - card_size.y - SAFE_MARGIN)

	position = Vector2(px, py).round()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_card_size() -> Vector2:
	var card_size := _panel.size
	if card_size.x <= 1.0 or card_size.y <= 1.0:
		card_size = _panel.get_combined_minimum_size()
	if card_size.x <= 1.0:
		card_size.x = CARD_WIDTH
	if card_size.y <= 1.0:
		card_size.y = 300.0
	return card_size

func _get_upgrade_preview_for_card() -> Dictionary:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_selected_tower_upgrade_preview"):
		var raw = scene.call("get_selected_tower_upgrade_preview")
		if raw is Dictionary:
			return raw
	return {}

func _get_current_gold_for_card() -> int:
	var scene := get_tree().current_scene
	if scene == null:
		return 0
	var gm := scene.get_node_or_null("GameManager")
	if gm == null:
		return 0
	return int(gm.get("gold"))

func _elements_short(elements: Array) -> String:
	const SHORT := {
		"light":"Light","darkness":"Dark","water":"Water",
		"fire":"Fire","nature":"Nature","earth":"Earth"
	}
	var parts := PackedStringArray()
	for el in elements:
		parts.append(SHORT.get(str(el), str(el).capitalize()))
	return " · ".join(parts)

func _badge_color(info: Dictionary, badge: String) -> Color:
	var hay: String = ("%s %s %s" % [
		str(info.get("attack_type", "")),
		str(info.get("id", "")),
		badge
	]).to_lower()
	if hay.contains("splash") or hay.contains("aoe") or hay.contains("slam"):
		return NeonStyle.EL_FIRE
	if hay.contains("slow") or hay.contains("freeze") or hay.contains("frost") or hay.contains("ice") or hay.contains("area control"):
		return NeonStyle.EL_WATER
	if hay.contains("burn") or hay.contains("fire") or hay.contains("flame") or hay.contains("nova"):
		return NeonStyle.EL_FIRE
	if hay.contains("poison") or hay.contains("venom") or hay.contains("nature") or hay.contains("roots"):
		return NeonStyle.EL_NATURE
	if hay.contains("light") or hay.contains("holy") or hay.contains("reveal") or hay.contains("laser"):
		return NeonStyle.WARN
	if hay.contains("dark") or hay.contains("curse") or hay.contains("void") or hay.contains("hex") or hay.contains("jinx"):
		return NeonStyle.EL_DARKNESS
	if hay.contains("wind") or hay.contains("storm") or hay.contains("chain") or hay.contains("gale"):
		return NeonStyle.CYAN
	return NeonStyle.INK_2

func _make_sep() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.302, 0.851, 0.902, 0.14)
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = SIZE_FILL
	r.mouse_filter = MOUSE_FILTER_IGNORE
	return r

func _eyebrow(text: String) -> Label:
	var l := Label.new()
	l.text     = text
	l.uppercase = true
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", NeonStyle.INK_3)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l

func _make_stat_row(key: String, accent: Color) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)

	var kl := Label.new()
	kl.text     = key
	kl.uppercase = true
	kl.add_theme_font_size_override("font_size", 10)
	kl.add_theme_color_override("font_color", NeonStyle.INK_3)
	kl.custom_minimum_size = Vector2(54, 0)
	kl.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(kl)

	var div := ColorRect.new()
	div.color = NeonStyle.LINE
	div.custom_minimum_size = Vector2(1, 12)
	div.size_flags_vertical = SIZE_SHRINK_CENTER
	div.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(div)

	var vl := Label.new()
	vl.add_theme_font_size_override("font_size", 12)
	vl.add_theme_color_override("font_color", accent)
	vl.size_flags_horizontal = SIZE_EXPAND_FILL
	vl.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(vl)

	return [row, vl]

# ── Input handler ────────────────────────────────────────────────────────────

func _on_target_selected(index: int) -> void:
	if _updating_ui:
		return
	if index < 0 or index >= _MODES.size():
		return
	target_mode_changed.emit(_MODES[index])
