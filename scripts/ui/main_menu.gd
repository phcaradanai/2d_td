extends CanvasLayer

signal new_game_pressed()
signal continue_pressed()
signal settings_pressed()
signal leaderboard_pressed()
signal quit_pressed()

# Backward-compat aliases kept so existing connections in main.gd don't break.
signal start_pressed()
signal level_select_pressed()

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

@onready var player_name_input: LineEdit = $Root/NameContainer/PlayerNameInput
@onready var play_button: Button = $Root/VBoxContainer/PlayButton
@onready var continue_button: Button = $Root/VBoxContainer/ContinueButton
@onready var settings_button: Button = $Root/VBoxContainer/SettingsButton
@onready var leaderboard_button: Button = $Root/VBoxContainer/LeaderboardButton
@onready var credits_button: Button = $Root/VBoxContainer/CreditsButton
@onready var quit_button: Button = $Root/VBoxContainer/QuitButton
@onready var version_label: Label = $Root/VersionLabel
@onready var credits_panel: PanelContainer = $Root/CreditsPanel
@onready var credits_close_button: Button = $Root/CreditsPanel/MarginContainer/VBoxContainer/CloseCreditsButton

var _access_status_label: Label = null
var _identity_panel: CanvasLayer = null   # RuntimeIdentityPanel, lazy-created

func _ready() -> void:
	_apply_neon_terminal_layout()
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true

	if leaderboard_button:
		leaderboard_button.pressed.connect(func(): leaderboard_pressed.emit())
	if settings_button:
		settings_button.pressed.connect(func(): settings_pressed.emit())
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	if credits_close_button:
		credits_close_button.pressed.connect(_on_credits_close_pressed)
	if credits_panel:
		credits_panel.hide()

	if player_name_input:
		player_name_input.max_length = 20
		player_name_input.placeholder_text = "Enter your name..."

	if OS.get_name() == "Web":
		quit_button.hide()
	else:
		quit_button.pressed.connect(func(): quit_pressed.emit())

func _on_play_pressed() -> void:
	_unlock_audio()
	_commit_player_name()
	new_game_pressed.emit()
	start_pressed.emit()  # backward compat

func _on_continue_pressed() -> void:
	_unlock_audio()
	_commit_player_name()
	continue_pressed.emit()

func _commit_player_name() -> void:
	if player_name_input == null:
		return
	var name_val = player_name_input.text.strip_edges()
	if name_val.is_empty():
		name_val = "Player"
	player_name_input.text = name_val

func get_player_name() -> String:
	if player_name_input == null:
		return "Player"
	var name_val = player_name_input.text.strip_edges()
	return name_val if not name_val.is_empty() else "Player"

func set_player_name(player_name: String) -> void:
	if player_name_input:
		player_name_input.text = player_name

# Called by main.gd when showing the menu to reflect current save state.
func set_has_save(has_save: bool) -> void:
	if continue_button:
		continue_button.disabled = not has_save

func set_version(text: String) -> void:
	if version_label:
		version_label.text = text

func _on_credits_pressed() -> void:
	if credits_panel:
		credits_panel.show()

func _on_credits_close_pressed() -> void:
	if credits_panel:
		credits_panel.hide()

func _unlock_audio() -> void:
	var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("unlock_audio"):
		audio_manager.unlock_audio()

func _apply_neon_terminal_layout() -> void:
	var bg := $Root/Background
	if bg is ColorRect:
		bg.color = NeonStyle.BG

	var title := $Root/Title
	if title is Label:
		title.text = "TOWER DEFENSE"
		title.add_theme_font_size_override("font_size", 56)
		title.add_theme_color_override("font_color", NeonStyle.CYAN)
		title.add_theme_color_override("font_shadow_color", Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.38))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 2)
		title.add_theme_constant_override("shadow_size", 9)

	var name_label := $Root/NameContainer/NameLabel
	if name_label is Label:
		name_label.text = "OPERATOR ID"
		NeonStyle.apply_terminal_label(name_label, 12, NeonStyle.TEXT_DIM)
	if player_name_input:
		player_name_input.placeholder_text = "CALLSIGN"
		NeonStyle.style_line_edit(player_name_input)

	for btn in [play_button, continue_button, settings_button, leaderboard_button, credits_button, quit_button, credits_close_button]:
		if btn:
			NeonStyle.style_button(btn, NeonStyle.CYAN, btn == play_button)
			btn.custom_minimum_size.y = 44

	if version_label:
		NeonStyle.apply_terminal_label(version_label, 11, NeonStyle.TEXT_DIM)

	if credits_panel:
		credits_panel.add_theme_stylebox_override("panel", NeonStyle.panel(NeonStyle.PANEL_DENSE, NeonStyle.CYAN_DIM, true))

	_build_identity_button()

## Update the small access-config status line shown on the main menu.
## source: "remote" | "cache" | "default"
## version: config_version integer from the backend
func set_access_status(source: String, version: int) -> void:
	if _access_status_label == null:
		_build_access_status_label()
	if _access_status_label == null:
		return
	var text: String
	if source == "remote":
		text = "Access Config: Online v%d" % version
		_access_status_label.add_theme_color_override("font_color", Color(0.302, 0.851, 0.902, 0.75))
	elif source == "cache":
		text = "Access Config: Cached v%d" % version
		_access_status_label.add_theme_color_override("font_color", Color(1.000, 0.710, 0.278, 0.75))
	else:
		text = "Access Config: Default"
		_access_status_label.add_theme_color_override("font_color", Color(0.420, 0.502, 0.533, 0.75))
	_access_status_label.text = text

## Open the runtime identity panel (shows IDs + access config for admin use).
func open_identity_panel() -> void:
	if _identity_panel == null or not is_instance_valid(_identity_panel):
		var script = load("res://scripts/ui/runtime_identity_panel.gd")
		if script == null:
			push_warning("[MainMenu] RuntimeIdentityPanel script not found.")
			return
		_identity_panel = script.new()
		_identity_panel.name = "RuntimeIdentityPanel"
		get_parent().add_child(_identity_panel)   # sibling of MainMenu in scene
	var main = get_tree().current_scene
	var identity_svc = main.get_node_or_null("RuntimeIdentityService")
	var access_svc   = main.get_node_or_null("LevelAccessService")
	_identity_panel.refresh(identity_svc, access_svc)
	_identity_panel.show()

func _build_identity_button() -> void:
	var root_node = get_node_or_null("Root")
	if root_node == null:
		return
	var btn = Button.new()
	btn.name = "IdentityInfoButton"
	btn.text = "ID"
	btn.tooltip_text = "Runtime Identity & Access Info"
	btn.add_theme_font_size_override("font_size", 10)
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	btn.offset_left   = 8
	btn.offset_top    = -28
	btn.offset_right  = 40
	btn.offset_bottom = -8
	btn.mouse_filter  = Control.MOUSE_FILTER_STOP
	# Minimal styling
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.043, 0.059, 0.090, 0.70)
	s.set_border_width_all(1)
	s.border_color = Color(0.302, 0.851, 0.902, 0.28)
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal",   s)
	btn.add_theme_stylebox_override("hover",    s)
	btn.add_theme_stylebox_override("pressed",  s)
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.420, 0.502, 0.533, 0.85))
	btn.pressed.connect(open_identity_panel)
	root_node.add_child(btn)

func _build_access_status_label() -> void:
	var root_node = get_node_or_null("Root")
	if root_node == null:
		return
	_access_status_label = Label.new()
	_access_status_label.name = "AccessStatusLabel"
	_access_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_access_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_access_status_label.add_theme_font_size_override("font_size", 10)
	_access_status_label.add_theme_color_override("font_color", Color(0.420, 0.502, 0.533, 0.75))
	_access_status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_access_status_label.offset_left   = -220
	_access_status_label.offset_top    = -28
	_access_status_label.offset_right  = -8
	_access_status_label.offset_bottom = -8
	_access_status_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root_node.add_child(_access_status_label)

func show_menu() -> void:
	show()

func hide_menu() -> void:
	hide()
