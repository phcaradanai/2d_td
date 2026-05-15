extends Node

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG          = Color(0.012, 0.022, 0.042, 0.97)
const C_BORDER      = Color(0.18,  0.68,  0.90,  0.85)
const C_ACCENT      = Color(0.30,  0.90,  1.00,  1.00)
const C_GOLD        = Color(1.00,  0.82,  0.22,  1.00)
const C_CORAL       = Color(1.00,  0.48,  0.32,  1.00)
const C_TEXT        = Color(0.88,  0.96,  1.00,  1.00)
const C_TEXT_DIM    = Color(0.52,  0.65,  0.76,  0.90)
const C_BTN         = Color(0.032, 0.072, 0.140, 1.00)
const C_BTN_HOVER   = Color(0.060, 0.165, 0.265, 1.00)
const C_BTN_PRESS   = Color(0.016, 0.042, 0.085, 1.00)
const C_SEP         = Color(0.18,  0.68,  0.90,  0.22)

func apply_theme(root: Node) -> void:
	_process_node(root)

func _process_node(node: Node) -> void:
	if node is PanelContainer:
		_apply_panel_style(node)
	elif node is Button:
		_apply_button_style(node)
	elif node is Label:
		_apply_label_style(node)
	elif node is HSeparator:
		_apply_separator_style(node)
	elif node is OptionButton:
		_apply_option_style(node)
	for child in node.get_children():
		_process_node(child)

# ── Panel ─────────────────────────────────────────────────────────────────────
func _apply_panel_style(panel: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color        = C_BG
	s.border_color    = C_BORDER
	s.border_width_left   = 1
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.shadow_color  = Color(0.20, 0.82, 1.0, 0.20)
	s.shadow_size   = 8
	s.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", s)

# ── Button helper ─────────────────────────────────────────────────────────────
func _make_flat(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.border_width_left   = 1
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left   = 12
	s.content_margin_right  = 12
	s.content_margin_top    = 5
	s.content_margin_bottom = 5
	return s

# ── Button ────────────────────────────────────────────────────────────────────
func _apply_button_style(btn: Button) -> void:
	var n := btn.name

	# ── Primary (Start Wave) ──
	if n == "StartWaveButton":
		var bg      := Color(0.030, 0.130, 0.210, 1.0)
		var bg_h    := Color(0.060, 0.240, 0.350, 1.0)
		var border  := Color(0.32,  0.82,  1.00,  0.95)
		var norm    := _make_flat(bg,   border)
		norm.border_width_top = 2
		var hov     := _make_flat(bg_h, C_ACCENT)
		hov.border_width_top = 2
		var prs     := _make_flat(C_BTN_PRESS, border)
		btn.add_theme_stylebox_override("normal",   norm)
		btn.add_theme_stylebox_override("hover",    hov)
		btn.add_theme_stylebox_override("pressed",  prs)
		btn.add_theme_stylebox_override("disabled", _make_flat(Color(0.03, 0.04, 0.06, 0.9), Color(0.22, 0.32, 0.42, 0.45)))
		btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color",       Color(0.82, 0.97, 1.0))
		btn.add_theme_color_override("font_hover_color", C_ACCENT)
		btn.add_theme_color_override("font_disabled_color", C_TEXT_DIM)
		btn.add_theme_font_size_override("font_size", 13)
		return

	# ── Danger (Cancel Build / Main Menu) ──
	if n in ["CancelBuildButton", "CenterMenuButton"]:
		var bg     := Color(0.16, 0.035, 0.035, 1.0)
		var bg_h   := Color(0.26, 0.055, 0.055, 1.0)
		var border := Color(0.90, 0.28,  0.28,  0.72)
		btn.add_theme_stylebox_override("normal",   _make_flat(bg,   border))
		btn.add_theme_stylebox_override("hover",    _make_flat(bg_h, Color(1.0, 0.38, 0.38, 0.90)))
		btn.add_theme_stylebox_override("pressed",  _make_flat(C_BTN_PRESS, border))
		btn.add_theme_stylebox_override("disabled", _make_flat(Color(0.03, 0.04, 0.06, 0.9), Color(0.22, 0.32, 0.42, 0.45)))
		btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color",       Color(1.0, 0.58, 0.58))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.78))
		btn.add_theme_color_override("font_disabled_color", C_TEXT_DIM)
		btn.add_theme_font_size_override("font_size", 12)
		return

	# ── Upgrade ──
	if n == "UpgradeTowerButton":
		var bg     := Color(0.09, 0.10, 0.018, 1.0)
		var bg_h   := Color(0.16, 0.18, 0.030, 1.0)
		var border := Color(0.82, 0.72,  0.10,  0.78)
		btn.add_theme_stylebox_override("normal",   _make_flat(bg,   border))
		btn.add_theme_stylebox_override("hover",    _make_flat(bg_h, Color(1.0, 0.92, 0.28, 0.90)))
		btn.add_theme_stylebox_override("pressed",  _make_flat(C_BTN_PRESS, border))
		btn.add_theme_stylebox_override("disabled", _make_flat(Color(0.03, 0.04, 0.06, 0.9), Color(0.22, 0.32, 0.42, 0.45)))
		btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color",       C_GOLD)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.35))
		btn.add_theme_color_override("font_disabled_color", C_TEXT_DIM)
		return

	# ── Default ──
	var border_col := C_BORDER
	if n in ["CenterRestartButton", "CloseSettingsButton"]:
		border_col = Color(0.32, 0.82, 1.0, 0.80)

	btn.add_theme_stylebox_override("normal",   _make_flat(C_BTN,       border_col))
	btn.add_theme_stylebox_override("hover",    _make_flat(C_BTN_HOVER, C_ACCENT))
	btn.add_theme_stylebox_override("pressed",  _make_flat(C_BTN_PRESS, border_col))
	btn.add_theme_stylebox_override("disabled", _make_flat(Color(0.03, 0.04, 0.06, 0.9), Color(0.22, 0.32, 0.42, 0.45)))
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_hover_color",    C_ACCENT)
	btn.add_theme_color_override("font_pressed_color",  C_TEXT)
	btn.add_theme_color_override("font_disabled_color", C_TEXT_DIM)

# ── Label ─────────────────────────────────────────────────────────────────────
func _apply_label_style(label: Label) -> void:
	match label.name:
		"Title", "CenterMessageLabel":
			label.add_theme_color_override("font_color",        C_ACCENT)
			label.add_theme_color_override("font_shadow_color", Color(0, 0.85, 1.0, 0.28))
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.add_theme_constant_override("shadow_size",      4)
		"GoldLabel":
			label.add_theme_color_override("font_color", C_GOLD)
			label.add_theme_font_size_override("font_size", 15)
		"LivesLabel":
			label.add_theme_color_override("font_color", C_CORAL)
			label.add_theme_font_size_override("font_size", 15)
		"WaveLabel":
			label.add_theme_color_override("font_color",        C_ACCENT)
			label.add_theme_color_override("font_shadow_color", Color(0, 0.85, 1.0, 0.22))
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.add_theme_constant_override("shadow_size",      3)
			label.add_theme_font_size_override("font_size", 17)
		"StatusLabel":
			label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
			label.add_theme_font_size_override("font_size", 13)
		"NextWaveLabel":
			label.add_theme_color_override("font_color", Color(0.52, 0.68, 0.80))
			label.add_theme_font_size_override("font_size", 12)
		"TowerNameLabel":
			label.add_theme_color_override("font_color",        C_ACCENT)
			label.add_theme_color_override("font_shadow_color", Color(0, 0.85, 1.0, 0.22))
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.add_theme_constant_override("shadow_size",      3)
		"TowerUpgradeCostLabel":
			label.add_theme_color_override("font_color", C_GOLD)
			label.add_theme_font_size_override("font_size", 13)
		"TowerLevelLabel", "TowerDamageLabel", "TowerRangeLabel", \
		"TowerFireRateLabel", "TowerSplashLabel", "TowerSlowLabel":
			label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
			label.add_theme_font_size_override("font_size", 13)
		"TowerTargetModeLabel":
			label.add_theme_color_override("font_color", C_TEXT_DIM)
			label.add_theme_font_size_override("font_size", 12)
		"BuildStatusLabel":
			label.add_theme_color_override("font_color", Color(0.52, 0.80, 0.92))
			label.add_theme_font_size_override("font_size", 11)
		"ScoreLabel":
			label.add_theme_color_override("font_color", Color(0.78, 0.96, 0.62))
			label.add_theme_font_size_override("font_size", 22)
		_:
			label.add_theme_color_override("font_color", C_TEXT)

# ── Separator ─────────────────────────────────────────────────────────────────
func _apply_separator_style(sep: HSeparator) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color            = C_SEP
	s.content_margin_top  = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)

# ── OptionButton ──────────────────────────────────────────────────────────────
func _apply_option_style(opt: OptionButton) -> void:
	opt.add_theme_stylebox_override("normal",   _make_flat(C_BTN,       C_BORDER))
	opt.add_theme_stylebox_override("hover",    _make_flat(C_BTN_HOVER, C_ACCENT))
	opt.add_theme_stylebox_override("pressed",  _make_flat(C_BTN_HOVER, C_ACCENT))
	opt.add_theme_stylebox_override("focus",    _make_flat(C_BTN_HOVER, C_ACCENT))
	opt.add_theme_stylebox_override("disabled", _make_flat(Color(0.03, 0.04, 0.06, 0.9), Color(0.22, 0.32, 0.42, 0.45)))
	opt.add_theme_color_override("font_color",       C_TEXT)
	opt.add_theme_color_override("font_hover_color", C_ACCENT)
