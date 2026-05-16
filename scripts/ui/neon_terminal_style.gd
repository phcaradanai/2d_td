extends RefCounted
## Tactical Neon Terminal — design-system tokens and helpers.
## Colors match the "TD HUD Refined" reference exactly.

# ── Surfaces ──────────────────────────────────────────────────────────────────
const BG_0   := Color(0.024, 0.031, 0.051, 1.00)  # deepest void  #06080d
const BG_1   := Color(0.043, 0.059, 0.090, 0.96)  # panel base    #0b0f17
const BG_2   := Color(0.059, 0.082, 0.129, 1.00)  # elevated      #0f1521
const BG_3   := Color(0.078, 0.110, 0.169, 1.00)  # active row    #141c2b

# Legacy aliases kept so callers don't break.
const BG          := BG_0
const PANEL       := BG_1
const PANEL_DENSE := BG_0

# ── Ink / text ────────────────────────────────────────────────────────────────
const INK_1 := Color(0.914, 0.969, 0.976, 1.00)  # bright white  #e9f7f9
const INK_2 := Color(0.643, 0.741, 0.769, 1.00)  # body          #a4bdc4
const INK_3 := Color(0.420, 0.502, 0.533, 1.00)  # muted         #6b8088
const INK_4 := Color(0.267, 0.329, 0.357, 1.00)  # faint         #44545b

# Legacy aliases
const TEXT     := INK_1
const TEXT_DIM := INK_2

# ── Primary (cyan) ────────────────────────────────────────────────────────────
const CYAN        := Color(0.302, 0.851, 0.902, 1.00)  # #4DD9E6
const CYAN_2      := Color(0.435, 0.902, 0.941, 1.00)  # #6FE6F0
const CYAN_FAINT  := Color(0.302, 0.851, 0.902, 0.08)  # pri-soft
const CYAN_DIM    := Color(0.302, 0.851, 0.902, 0.28)  # line-2
const CYAN_SOFT   := Color(0.302, 0.851, 0.902, 0.16)  # line

# ── Border lines ─────────────────────────────────────────────────────────────
const LINE        := Color(0.302, 0.851, 0.902, 0.16)  # subtle border
const LINE_2      := Color(0.302, 0.851, 0.902, 0.28)  # medium border
const LINE_STRONG := Color(0.302, 0.851, 0.902, 0.55)  # active border

# ── State ──────────────────────────────────────────────────────────────────────
const WARN   := Color(1.000, 0.710, 0.278, 1.00)  # #FFB547  gold/amber
const DANGER := Color(1.000, 0.353, 0.420, 1.00)  # #FF5A6B  red
const OK     := Color(0.357, 0.878, 0.549, 1.00)  # #5BE08C  green

# Legacy
const GOLD  := WARN
const CORAL := DANGER
const GREEN := OK

# ── Element palette ──────────────────────────────────────────────────────────
const EL_LIGHT    := Color(1.000, 0.824, 0.247, 1.00)  # #FFD23F
const EL_DARKNESS := Color(0.698, 0.482, 1.000, 1.00)  # #B27BFF
const EL_WATER    := Color(0.310, 0.659, 1.000, 1.00)  # #4FA8FF
const EL_FIRE     := Color(1.000, 0.478, 0.290, 1.00)  # #FF7A4A
const EL_NATURE   := Color(0.357, 0.878, 0.549, 1.00)  # #5BE08C
const EL_EARTH    := Color(0.902, 0.647, 0.361, 1.00)  # #E6A55C
const EL_INTEREST := Color(0.780, 0.573, 0.918, 1.00)  # #C792EA
const EL_LIFE     := Color(0.718, 0.910, 0.290, 1.00)  # #B7E84A
const EL_TRICKERY := Color(1.000, 0.424, 0.780, 1.00)  # #FF6CC7
const EL_DISEASE  := Color(0.529, 0.761, 0.420, 1.00)  # #87C26B

# ── StyleBox factories ────────────────────────────────────────────────────────

static func panel(bg: Color = PANEL, border: Color = LINE, active: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = LINE_STRONG if active else border
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	if active:
		s.shadow_color  = Color(CYAN.r, CYAN.g, CYAN.b, 0.22)
		s.shadow_size   = 12
		s.shadow_offset = Vector2.ZERO
	return s

static func button(bg: Color = BG_1, border: Color = LINE_2, active: bool = false) -> StyleBoxFlat:
	var s := panel(bg, border, active)
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 6
	s.content_margin_bottom = 6
	return s

static func row_normal(unlocked: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = BG_1 if unlocked else BG_0
	s.border_color = LINE if unlocked else Color(LINE.r, LINE.g, LINE.b, 0.10)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 0
	s.content_margin_right  = 0
	s.content_margin_top    = 0
	s.content_margin_bottom = 0
	return s

static func row_hover() -> StyleBoxFlat:
	var s := row_normal(true)
	s.bg_color     = BG_2
	s.border_color = LINE_2
	return s

static func row_selected() -> StyleBoxFlat:
	var s := row_normal(true)
	s.bg_color     = BG_3
	s.border_color = LINE_STRONG
	s.shadow_color  = Color(CYAN.r, CYAN.g, CYAN.b, 0.20)
	s.shadow_size   = 8
	s.shadow_offset = Vector2.ZERO
	return s

static func chip(tone: String = "pri") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	match tone:
		"warn":   s.bg_color = Color(1.0, 0.71, 0.28, 0.10);  s.border_color = Color(1.0, 0.71, 0.28, 0.30)
		"danger": s.bg_color = Color(1.0, 0.35, 0.42, 0.10);  s.border_color = Color(1.0, 0.35, 0.42, 0.32)
		"ok":     s.bg_color = Color(0.36, 0.88, 0.55, 0.10);  s.border_color = Color(0.36, 0.88, 0.55, 0.32)
		"ghost":  s.bg_color = Color.TRANSPARENT;               s.border_color = LINE
		_:        s.bg_color = CYAN_FAINT;                      s.border_color = LINE_2
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left   = 7
	s.content_margin_right  = 7
	s.content_margin_top    = 2
	s.content_margin_bottom = 2
	return s

static func hint_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(CYAN.r, CYAN.g, CYAN.b, 0.04)
	s.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.18)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.border_blend = true
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

# ── Label helpers ─────────────────────────────────────────────────────────────

static func apply_terminal_label(label: Label, size: int = 13,
		color: Color = INK_1, shadow: bool = false) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if shadow:
		label.add_theme_color_override("font_shadow_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.20))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("shadow_size", 5)

static func apply_eyebrow(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", INK_3)
	label.uppercase = true

static func apply_stat_value(label: Label, tone: String = "default") -> void:
	label.add_theme_font_size_override("font_size", 17)
	match tone:
		"pri":    label.add_theme_color_override("font_color", CYAN_2)
		"warn":   label.add_theme_color_override("font_color", WARN)
		"danger": label.add_theme_color_override("font_color", DANGER)
		"ok":     label.add_theme_color_override("font_color", OK)
		_:        label.add_theme_color_override("font_color", INK_1)

# ── Button styler ─────────────────────────────────────────────────────────────

static func style_button(btn: Button, accent: Color = CYAN, active: bool = false) -> void:
	var normal  := button(BG_1,  Color(accent.r, accent.g, accent.b, 0.45), active)
	var hover   := button(BG_2,  Color(accent.r, accent.g, accent.b, 0.90), true)
	var pressed := button(BG_0,  Color(accent.r, accent.g, accent.b, 0.70), active)
	var disabled := button(Color(BG_0.r, BG_0.g, BG_0.b, 0.80), Color(INK_4.r, INK_4.g, INK_4.b, 0.45))
	if active:
		normal.shadow_color  = Color(accent.r, accent.g, accent.b, 0.25)
		normal.shadow_size   = 14
		normal.shadow_offset = Vector2.ZERO
	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",          INK_1)
	btn.add_theme_color_override("font_hover_color",    CYAN_2)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", INK_3)
	btn.add_theme_font_size_override("font_size", 12)

static func style_line_edit(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", button(BG_1, LINE_2))
	input.add_theme_stylebox_override("focus",  button(BG_2, LINE_STRONG, true))
	input.add_theme_color_override("font_color",             INK_1)
	input.add_theme_color_override("font_placeholder_color", INK_3)
	input.add_theme_color_override("caret_color", CYAN)
	input.add_theme_font_size_override("font_size", 15)

# ── Element color lookup ──────────────────────────────────────────────────────

static func element_color(el: String) -> Color:
	match el.to_lower():
		"light":    return EL_LIGHT
		"darkness": return EL_DARKNESS
		"water":    return EL_WATER
		"fire":     return EL_FIRE
		"nature":   return EL_NATURE
		"earth":    return EL_EARTH
		"interest", "__interest__": return EL_INTEREST
		"life":     return EL_LIFE
		"trickery": return EL_TRICKERY
		"disease":  return EL_DISEASE
	return INK_2

static func element_chip_bg(el: String) -> Color:
	var c := element_color(el)
	return Color(c.r, c.g, c.b, 0.10)

static func element_chip_border(el: String) -> Color:
	var c := element_color(el)
	return Color(c.r, c.g, c.b, 0.45)
