extends Resource

# Example helper for Godot 4 AnimatedSprite2D/SpriteFrames.
# Put this script near the extracted PNG files and adapt paths as needed.

static func add_animation_from_files(sprite_frames: SpriteFrames, animation_name: String, file_paths: Array[String], fps: float = 8.0, loop: bool = true) -> void:
	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, loop)
	for path in file_paths:
		var tex := load(path) as Texture2D
		if tex != null:
			sprite_frames.add_frame(animation_name, tex)
