extends Node

# Example helper for loading the ripped darkness turret frames.
# Update BASE_PATH to match your project.
const BASE_PATH := "res://darkness_turret_ripped/frames_fixed_48/"

func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var groups = {
		"idle": 4,
		"attack": 8,
		"build": 4,
		"destroy": 4,
		"projectile": 8,
		"attack_vfx": 8,
		"impact_vfx": 8,
	}
	for anim in groups.keys():
		var count = groups[anim]
		for i in range(1, count + 1):
			var path = BASE_PATH + "%s_%02d.png" % [anim, i]
			var tex = load(path)
			if tex:
				sf.add_frame(anim, tex)
	return sf
