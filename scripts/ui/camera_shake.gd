extends Camera2D

var shake_strength: float = 0.0
var shake_decay: float = 5.0
var original_offset: Vector2

func _ready() -> void:
	original_offset = offset

func _process(delta: float) -> void:
	# Note: Camera shake usually shouldn't pause if the game is paused 
	# but since we trigger it on gameplay events, it naturally won't increment if events don't happen.
	# However, if it's already shaking and we pause, we might want it to stop or continue.
	# The requirement says "Manual pause compatible".
	
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if game_manager and game_manager.is_paused:
		return

	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		offset = original_offset + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		offset = original_offset

func shake(strength: float, duration_factor: float = 1.0) -> void:
	shake_strength = strength
	# Duration is implicitly handled by decay
	shake_decay = 5.0 / duration_factor
