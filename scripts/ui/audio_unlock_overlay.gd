extends CanvasLayer

signal unlocked()

@onready var start_button: Button = $Control/Panel/StartButton

func _ready() -> void:
	# Only show on Web
	if not OS.has_feature("web"):
		queue_free()
		return
		
	show()
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	if OS.is_debug_build(): print("[AudioUnlockOverlay] Button pressed, unlocking audio...")
	var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("unlock_audio"):
		audio_manager.unlock_audio()
	
	unlocked.emit()
	if OS.is_debug_build(): print("[AudioUnlockOverlay] hidden after unlock")
	queue_free()
