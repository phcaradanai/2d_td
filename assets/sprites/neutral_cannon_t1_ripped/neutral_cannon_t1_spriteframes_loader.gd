# neutral_cannon_t1_spriteframes_loader.gd
# Put the extracted folder under res://art/neutral_cannon_t1_ripped/
# Then call: var frames = NeutralCannonT1SpriteFramesLoader.build()

class_name NeutralCannonT1SpriteFramesLoader

static func _load_tex(path: String) -> Texture2D:
	return load(path) as Texture2D

static func build(base_path := "res://art/neutral_cannon_t1_ripped/frames_fixed_256/") -> SpriteFrames:
	var sf := SpriteFrames.new()

	sf.add_animation("turret_rotation")
	sf.set_animation_loop("turret_rotation", true)
	sf.set_animation_speed("turret_rotation", 8.0)
	for i in range(8):
		sf.add_frame("turret_rotation", _load_tex(base_path + "turret_rotation/turret_rotation_%02d.png" % i))

	sf.add_animation("turret_fire")
	sf.set_animation_loop("turret_fire", false)
	sf.set_animation_speed("turret_fire", 12.0)
	for i in range(5):
		sf.add_frame("turret_fire", _load_tex(base_path + "turret_fire/turret_fire_%02d.png" % i))

	sf.add_animation("splash_impact")
	sf.set_animation_loop("splash_impact", false)
	sf.set_animation_speed("splash_impact", 12.0)
	for i in range(7):
		sf.add_frame("splash_impact", _load_tex(base_path + "splash_impact/splash_impact_%02d.png" % i))

	return sf
