extends CanvasLayer

signal start_pressed()
signal level_select_pressed()
signal quit_pressed()

@onready var start_button: Button = $Root/VBoxContainer/StartButton
@onready var level_select_button: Button = $Root/VBoxContainer/LevelSelectButton
@onready var credits_button: Button = $Root/VBoxContainer/CreditsButton
@onready var quit_button: Button = $Root/VBoxContainer/QuitButton

@onready var version_label: Label = $Root/VersionLabel
@onready var credits_panel: PanelContainer = $Root/CreditsPanel
@onready var credits_close_button: Button = $Root/CreditsPanel/MarginContainer/VBoxContainer/CloseCreditsButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	if credits_close_button:
		credits_close_button.pressed.connect(_on_credits_close_pressed)
	
	if credits_panel:
		credits_panel.hide()
	
	if OS.get_name() == "Web":
		quit_button.hide()
	else:
		quit_button.pressed.connect(func(): quit_pressed.emit())

func _on_start_pressed() -> void:
	_unlock_audio()
	start_pressed.emit()

func _on_level_select_pressed() -> void:
	_unlock_audio()
	level_select_pressed.emit()

func _unlock_audio() -> void:
	var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("unlock_audio"):
		audio_manager.unlock_audio()

func set_version(text: String) -> void:
	if version_label:
		version_label.text = text

func _on_credits_pressed() -> void:
	if credits_panel:
		credits_panel.show()

func _on_credits_close_pressed() -> void:
	if credits_panel:
		credits_panel.hide()

func show_menu() -> void:
	show()

func hide_menu() -> void:
	hide()
