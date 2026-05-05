extends CanvasLayer

signal level_selected(level_path: String)
signal back_pressed()

@onready var level1_button: Button = $Root/VBoxContainer/Level1Container/Level1Button
@onready var level1_record: Label = $Root/VBoxContainer/Level1Container/Level1Record

@onready var level2_button: Button = $Root/VBoxContainer/Level2Container/Level2Button
@onready var level2_record: Label = $Root/VBoxContainer/Level2Container/Level2Record

@onready var level3_button: Button = $Root/VBoxContainer/Level3Container/Level3Button
@onready var level3_record: Label = $Root/VBoxContainer/Level3Container/Level3Record

@onready var back_button: Button = $Root/BackButton

func _ready() -> void:
	level1_button.pressed.connect(func(): _on_level_pressed("res://data/levels/level_01.json"))
	level2_button.pressed.connect(func(): _on_level_pressed("res://data/levels/level_02.json"))
	level3_button.pressed.connect(func(): _on_level_pressed("res://data/levels/level_03.json"))
	back_button.pressed.connect(func(): back_pressed.emit())

func _on_level_pressed(path: String) -> void:
	_unlock_audio()
	level_selected.emit(path)

func _unlock_audio() -> void:
	var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("unlock_audio"):
		audio_manager.unlock_audio()

func update_ui(save_manager: Node) -> void:
	_update_level_card("level_01", level1_button, level1_record, save_manager)
	_update_level_card("level_02", level2_button, level2_record, save_manager)
	_update_level_card("level_03", level3_button, level3_record, save_manager)

func _update_level_card(id: String, btn: Button, label: Label, save_manager: Node) -> void:
	var record = save_manager.get_level_record(id)
	var unlocked = save_manager.is_level_unlocked(id)
	
	btn.disabled = not unlocked
	
	if not unlocked:
		btn.text = "LOCKED"
		label.text = "Complete previous level"
		btn.modulate = Color(0.5, 0.5, 0.5, 0.8)
	else:
		# Restore original text from name if possible, or just use ID
		match id:
			"level_01": btn.text = "Level 1: Training Grounds"
			"level_02": btn.text = "Level 2: Crossroad Bend"
			"level_03": btn.text = "Level 3: Iron Route"
		
		btn.modulate = Color(1, 1, 1, 1)
		
		if record.get("completed", false):
			var stars = record.get("best_stars", 0)
			var stars_text = ""
			for i in range(stars): stars_text += "★"
			for i in range(3 - stars): stars_text += "☆"
			label.text = "Best: %d | %s" % [record.get("best_score", 0), stars_text]
		else:
			label.text = "Not Completed"

func show_select() -> void:
	show()

func hide_select() -> void:
	hide()
