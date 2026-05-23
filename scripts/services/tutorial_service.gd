extends Node

const DONE_FLAG_PATH := "user://tutorial_done"

const PANEL_W   := 640.0
const PANEL_H   := 175.0
const PANEL_TOP := 62.0   # just below HUD bar

enum Step { INACTIVE, BUILD_HINT, PLACE_HINT, WAVE_HINT, DONE }

var _step: Step = Step.INACTIVE
var _overlay: CanvasLayer = null
var _panel: Panel = null
var _label: RichTextLabel = null
var _prev_button: Button = null
var _next_button: Button = null
var _skip_button: Button = null

var _connected_build_manager: Node = null
var _connected_hud: Node = null
var _auto_dismiss_timer: float = 0.0
var _level_check_timer: float = 0.0
var _triggering_blocked: bool = false   # prevents re-trigger; does NOT stop dismiss timer

const STEP_TITLES := {
	Step.BUILD_HINT: "Step 1 / 3  —  Build a Tower",
	Step.PLACE_HINT: "Step 2 / 3  —  Place It",
	Step.WAVE_HINT:  "Step 3 / 3  —  Start the Wave",
	Step.DONE:       "You're ready, Commander!",
}

const STEP_BODY := {
	Step.BUILD_HINT: "Select any tower from the [color=#ffe066][b]BUILD TOWERS[/b][/color] panel on the [color=#ffe066][b]left side[/b][/color] of the screen.",
	Step.PLACE_HINT: "Click a [color=#ffe066][b]highlighted cell[/b][/color] on the map to place your tower.",
	Step.WAVE_HINT:  "Press [color=#ffe066][b]START WAVE[/b][/color] at the top of the screen when you are ready.",
	Step.DONE:       "Between waves you can [color=#ffe066][b]upgrade[/b][/color] or [color=#ffe066][b]sell[/b][/color] towers to adapt your strategy.\n[color=#888888]This panel will close in a moment...[/color]",
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if FileAccess.file_exists(DONE_FLAG_PATH):
		_triggering_blocked = true
		return
	_build_overlay()
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	# Auto-dismiss timer runs even while triggering is blocked (needed for DONE step)
	if _auto_dismiss_timer > 0.0:
		_auto_dismiss_timer -= delta
		if _auto_dismiss_timer <= 0.0:
			_hide_overlay()
		return

	if _triggering_blocked:
		return

	if _step == Step.INACTIVE:
		_level_check_timer -= delta
		if _level_check_timer <= 0.0:
			_level_check_timer = 0.5
			_check_level_id()

# ── Node detection ────────────────────────────────────────────────────────────

func _on_node_added(node: Node) -> void:
	if _connected_build_manager == null and node.name == "BuildManager":
		_connected_build_manager = node
		if node.has_signal("tower_placed"):
			node.tower_placed.connect(_on_tower_placed)
	if _connected_hud == null and node.name == "GameHUD":
		_connected_hud = node
		if node.has_signal("tower_build_selected"):
			node.tower_build_selected.connect(_on_tower_build_selected)
		if node.has_signal("start_wave_requested"):
			node.start_wave_requested.connect(_on_wave_started)

func _check_level_id() -> void:
	if _step != Step.INACTIVE:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var level_id := str(main.get("current_level_id") if "current_level_id" in main else "")
	if level_id == "level_01" or level_id == "1":
		_advance_to(Step.BUILD_HINT)

# ── Game-action triggers ──────────────────────────────────────────────────────

func _on_tower_build_selected(_id: String) -> void:
	if _step == Step.BUILD_HINT:
		_advance_to(Step.PLACE_HINT)

func _on_tower_placed(_tower, _id, _cost) -> void:
	if _step == Step.PLACE_HINT:
		_advance_to(Step.WAVE_HINT)

func _on_wave_started() -> void:
	if _step == Step.WAVE_HINT:
		_advance_to(Step.DONE)

# ── Step machine ──────────────────────────────────────────────────────────────

func _advance_to(step: Step) -> void:
	_step = step
	match step:
		Step.INACTIVE:
			_hide_overlay()
		Step.BUILD_HINT:
			_show_step(step)
			_prev_button.visible = false   # no previous from first step
			_next_button.visible = true
			_skip_button.visible = true
		Step.PLACE_HINT:
			_show_step(step)
			_prev_button.visible = true
			_next_button.visible = true
			_skip_button.visible = true
		Step.WAVE_HINT:
			_show_step(step)
			_prev_button.visible = true
			_next_button.visible = true
			_skip_button.visible = true
		Step.DONE:
			_show_step(step)
			_prev_button.visible = false
			_next_button.visible = false
			_skip_button.visible = false
			_triggering_blocked = true   # stop level re-check
			_auto_dismiss_timer = 3.5   # dismiss timer still ticks in _process
			_mark_done()

func _on_prev_pressed() -> void:
	match _step:
		Step.PLACE_HINT: _advance_to(Step.BUILD_HINT)
		Step.WAVE_HINT:  _advance_to(Step.PLACE_HINT)

func _on_next_pressed() -> void:
	match _step:
		Step.BUILD_HINT: _advance_to(Step.PLACE_HINT)
		Step.PLACE_HINT: _advance_to(Step.WAVE_HINT)
		Step.WAVE_HINT:  _advance_to(Step.DONE)

func _on_skip() -> void:
	_triggering_blocked = true
	_mark_done()
	_hide_overlay()

# ── Overlay UI ────────────────────────────────────────────────────────────────

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	add_child(_overlay)

	# Main panel — top-center, below HUD bar
	_panel = Panel.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -PANEL_W * 0.5
	_panel.offset_right  =  PANEL_W * 0.5
	_panel.offset_top    = PANEL_TOP
	_panel.offset_bottom = PANEL_TOP + PANEL_H

	var bg := StyleBoxFlat.new()
	bg.bg_color            = Color(0.04, 0.08, 0.18, 0.96)
	bg.border_width_left   = 2
	bg.border_width_right  = 2
	bg.border_width_top    = 2
	bg.border_width_bottom = 2
	bg.border_color        = Color(0.15, 0.75, 1.00, 1.0)
	bg.shadow_size         = 0
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		bg.set("corner_radius_" + corner, 8)
	_panel.add_theme_stylebox_override("panel", bg)
	_overlay.add_child(_panel)

	# Cyan accent bar
	var bar := Panel.new()
	bar.anchor_left  = 0.0
	bar.anchor_right = 1.0
	bar.offset_left  = 8
	bar.offset_right = -8
	bar.offset_top   = 0
	bar.offset_bottom= 3
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.15, 0.85, 1.00, 1.0)
	bar_style.corner_radius_top_left  = 2
	bar_style.corner_radius_top_right = 2
	bar.add_theme_stylebox_override("panel", bar_style)
	_panel.add_child(bar)

	# Title
	var title := Label.new()
	title.name = "TitleLabel"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00))
	title.anchor_left  = 0.0
	title.anchor_right = 1.0
	title.offset_left  = 14
	title.offset_right = -14
	title.offset_top   = 8
	title.offset_bottom= 26
	_panel.add_child(title)

	# Body
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active  = false
	_label.anchor_left    = 0.0
	_label.anchor_right   = 1.0
	_label.anchor_top     = 0.0
	_label.anchor_bottom  = 1.0
	_label.offset_left    = 14
	_label.offset_right   = -14
	_label.offset_top     = 30
	_label.offset_bottom  = -38
	_label.add_theme_color_override("default_color", Color(0.88, 0.95, 1.00))
	_label.add_theme_font_size_override("normal_font_size", 14)
	_panel.add_child(_label)

	# ── Bottom row buttons: [← Prev]  [Next →]  [Skip] ───────────────────────
	_prev_button = Button.new()
	_prev_button.text = "← Prev"
	_prev_button.anchor_left   = 1.0
	_prev_button.anchor_right  = 1.0
	_prev_button.anchor_top    = 1.0
	_prev_button.anchor_bottom = 1.0
	_prev_button.offset_left   = -342
	_prev_button.offset_right  = -236
	_prev_button.offset_top    = -38
	_prev_button.offset_bottom = -10
	_prev_button.add_theme_color_override("font_color", Color(0.60, 0.75, 0.90))
	_prev_button.pressed.connect(_on_prev_pressed)
	_panel.add_child(_prev_button)

	_next_button = Button.new()
	_next_button.text = "Next →"
	_next_button.anchor_left   = 1.0
	_next_button.anchor_right  = 1.0
	_next_button.anchor_top    = 1.0
	_next_button.anchor_bottom = 1.0
	_next_button.offset_left   = -228
	_next_button.offset_right  = -122
	_next_button.offset_top    = -38
	_next_button.offset_bottom = -10
	_next_button.add_theme_color_override("font_color", Color(0.15, 0.85, 1.00))
	_next_button.pressed.connect(_on_next_pressed)
	_panel.add_child(_next_button)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.anchor_left   = 1.0
	_skip_button.anchor_right  = 1.0
	_skip_button.anchor_top    = 1.0
	_skip_button.anchor_bottom = 1.0
	_skip_button.offset_left   = -114
	_skip_button.offset_right  = -8
	_skip_button.offset_top    = -38
	_skip_button.offset_bottom = -10
	_skip_button.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	_skip_button.pressed.connect(_on_skip)
	_panel.add_child(_skip_button)

	_panel.visible = false

func _show_step(step: Step) -> void:
	if _panel == null or _overlay == null:
		return
	var title := _panel.get_node_or_null("TitleLabel")
	if title:
		title.text = STEP_TITLES.get(step, "")
	_label.text = STEP_BODY.get(step, "")
	_overlay.visible = true
	_panel.visible = true

func _hide_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.visible = false
	if _panel and is_instance_valid(_panel):
		_panel.visible = false
	_step = Step.INACTIVE

func _mark_done() -> void:
	var f := FileAccess.open(DONE_FLAG_PATH, FileAccess.WRITE)
	if f:
		f.store_string("done")
		f.close()
