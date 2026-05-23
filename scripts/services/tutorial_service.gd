extends Node

const DONE_FLAG_PATH := "user://tutorial_done"

enum Step { INACTIVE, BUILD_HINT, PLACE_HINT, WAVE_HINT, DONE }

var _step: Step = Step.INACTIVE
var _overlay: CanvasLayer = null
var _label: RichTextLabel = null
var _skip_button: Button = null
var _panel: Panel = null

var _connected_build_manager: Node = null
var _connected_hud: Node = null
var _auto_dismiss_timer: float = 0.0

const STEPS_TEXT := {
	Step.BUILD_HINT: "[center]Welcome, Commander!\n[b]Select a tower[/b] from the build panel at the bottom of the screen.[/center]",
	Step.PLACE_HINT: "[center]Good choice!\n[b]Click a glowing cell[/b] on the map to place your tower.[/center]",
	Step.WAVE_HINT:  "[center]Tower placed!\nPress [b]START WAVE[/b] when you're ready to send the first wave.[/center]",
	Step.DONE:       "[center][b]You're ready, Commander![/b]\nUpgrade and sell towers between waves to adapt your strategy.[/center]",
}

func _ready() -> void:
	if FileAccess.file_exists(DONE_FLAG_PATH):
		return  # tutorial already completed, stay inactive

	_build_overlay()
	get_tree().node_added.connect(_on_node_added)

# ── Scene node detection ───────────────────────────────────────────────────────

func _on_node_added(node: Node) -> void:
	if _step == Step.INACTIVE:
		_try_start_on_level_one(node)

	if _connected_build_manager == null and node.get_class() == "Node2D" and node.name == "BuildManager":
		_connect_build_manager(node)
	elif _connected_build_manager == null and node.name == "BuildManager":
		_connect_build_manager(node)

	if _connected_hud == null and node.name == "GameHUD":
		_connect_hud(node)

func _try_start_on_level_one(node: Node) -> void:
	# Main scene sets current_level_id shortly after GameManager is added
	if node.name != "GameManager":
		return
	# Defer one frame so main.gd has time to set current_level_id
	call_deferred("_check_level_id")

func _check_level_id() -> void:
	if _step != Step.INACTIVE:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var level_id: String = ""
	if "current_level_id" in main:
		level_id = str(main.current_level_id)
	elif main.has_method("get_current_level_id"):
		level_id = main.get_current_level_id()
	if level_id == "level_01" or level_id == "1":
		_advance_to(Step.BUILD_HINT)

# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_build_manager(bm: Node) -> void:
	_connected_build_manager = bm
	if bm.has_signal("tower_placed") and not bm.tower_placed.is_connected(_on_tower_placed):
		bm.tower_placed.connect(_on_tower_placed)

func _connect_hud(hud: Node) -> void:
	_connected_hud = hud
	if hud.has_signal("tower_build_selected") and not hud.tower_build_selected.is_connected(_on_tower_build_selected):
		hud.tower_build_selected.connect(_on_tower_build_selected)
	if hud.has_signal("start_wave_requested") and not hud.start_wave_requested.is_connected(_on_wave_started):
		hud.start_wave_requested.connect(_on_wave_started)

func _on_tower_build_selected(_tower_id: String) -> void:
	if _step == Step.BUILD_HINT:
		_advance_to(Step.PLACE_HINT)

func _on_tower_placed(_tower: Node2D, _tower_id: String, _cost: int) -> void:
	if _step == Step.PLACE_HINT:
		_advance_to(Step.WAVE_HINT)

func _on_wave_started() -> void:
	if _step == Step.WAVE_HINT:
		_advance_to(Step.DONE)

# ── Step machine ──────────────────────────────────────────────────────────────

func _advance_to(step: Step) -> void:
	_step = step
	if step == Step.INACTIVE:
		_hide_overlay()
		return
	if step == Step.DONE:
		_show_step(step)
		_auto_dismiss_timer = 3.5
		_mark_done()
		return
	_show_step(step)

func _process(delta: float) -> void:
	if _auto_dismiss_timer > 0.0:
		_auto_dismiss_timer -= delta
		if _auto_dismiss_timer <= 0.0:
			_hide_overlay()

# ── Overlay UI ────────────────────────────────────────────────────────────────

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128  # above HUD (usually layer 1-10)
	add_child(_overlay)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(560, 110)
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -280
	_panel.offset_right  = 280
	_panel.offset_top    = 18
	_panel.offset_bottom = 128
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.18, 0.92)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.20, 0.70, 1.00, 0.90)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	_overlay.add_child(_panel)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.anchor_left   = 0.0
	_label.anchor_right  = 1.0
	_label.anchor_top    = 0.0
	_label.anchor_bottom = 1.0
	_label.offset_left   = 12
	_label.offset_right  = -90
	_label.offset_top    = 8
	_label.offset_bottom = -8
	_label.add_theme_color_override("default_color", Color(0.85, 0.95, 1.0))
	_panel.add_child(_label)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.anchor_right  = 1.0
	_skip_button.anchor_top    = 0.5
	_skip_button.anchor_bottom = 0.5
	_skip_button.offset_left   = -78
	_skip_button.offset_right  = -8
	_skip_button.offset_top    = -18
	_skip_button.offset_bottom = 18
	_skip_button.pressed.connect(_on_skip)
	_panel.add_child(_skip_button)

	_panel.visible = false

func _show_step(step: Step) -> void:
	if _panel == null:
		return
	_label.text = STEPS_TEXT.get(step, "")
	_panel.visible = true

func _hide_overlay() -> void:
	if _panel != null:
		_panel.visible = false
	_step = Step.INACTIVE

func _on_skip() -> void:
	_mark_done()
	_hide_overlay()

func _mark_done() -> void:
	var f := FileAccess.open(DONE_FLAG_PATH, FileAccess.WRITE)
	if f:
		f.store_string("done")
		f.close()
