extends CanvasLayer

signal new_game_pressed()
signal continue_pressed()
signal leaderboard_pressed()
signal quit_pressed()

# Backward-compat aliases kept so existing connections in main.gd don't break.
signal start_pressed()
signal level_select_pressed()

@onready var player_name_input: LineEdit = $Root/NameContainer/PlayerNameInput
@onready var play_button: Button = $Root/VBoxContainer/PlayButton
@onready var continue_button: Button = $Root/VBoxContainer/ContinueButton
@onready var leaderboard_button: Button = $Root/VBoxContainer/LeaderboardButton
@onready var credits_button: Button = $Root/VBoxContainer/CreditsButton
@onready var quit_button: Button = $Root/VBoxContainer/QuitButton
@onready var version_label: Label = $Root/VersionLabel
@onready var credits_panel: PanelContainer = $Root/CreditsPanel
@onready var credits_close_button: Button = $Root/CreditsPanel/MarginContainer/VBoxContainer/CloseCreditsButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true

	if leaderboard_button:
		leaderboard_button.pressed.connect(func(): leaderboard_pressed.emit())
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

func show_menu() -> void:
	show()

func hide_menu() -> void:
	hide()
