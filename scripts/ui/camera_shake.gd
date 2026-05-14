extends Camera2D

## Screen shake is disabled by default.
## Set SCREEN_SHAKE_ENABLED = true here (or via a Settings node) to re-enable.
## Readability during heavy combat takes priority over camera impact effects.
const SCREEN_SHAKE_ENABLED := false

var shake_strength: float = 0.0
var shake_decay: float = 5.0
var original_offset: Vector2

func _ready() -> void:
	original_offset = offset

func _process(delta: float) -> void:
	if not SCREEN_SHAKE_ENABLED:
		# Keep offset locked — no drift after enabling/disabling mid-session
		if offset != original_offset:
			offset = original_offset
		return

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

## No-op when SCREEN_SHAKE_ENABLED = false.
func shake(strength: float, duration_factor: float = 1.0) -> void:
	if not SCREEN_SHAKE_ENABLED:
		return
	shake_strength = strength
	shake_decay = 5.0 / duration_factor
