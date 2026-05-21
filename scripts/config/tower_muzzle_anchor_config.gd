extends RefCounted
class_name TowerMuzzleAnchorConfig

# Runtime muzzle anchors resolve by tower_id first. visual_type is only fallback
# for towers that have not been calibrated yet.
const BY_TOWER_ID := {
	"neutral_cannon_tower": Vector2(28, 0),
	"fire_t1": Vector2(37, 0),
	"fire_t2": Vector2(39, 0),
	"fire_t3": Vector2(41, 0),
	"pure_fire": Vector2(43, 0),
	"gunpowder_t1": Vector2(38, 0),
	"gunpowder_t2": Vector2(40, 0),
	"gunpowder_t3": Vector2(42, 0),
	"hail_t1": Vector2(36, 0),
	"hail_t2": Vector2(38, 0),
	"hail_t3": Vector2(40, 0),
	"hydro_t1": Vector2(39, 0),
	"hydro_t2": Vector2(42, 0),
	"hydro_t3": Vector2(44, 0),
	"ice_t1": Vector2(39, 0),
	"ice_t2": Vector2(41, 0),
	"ice_t3": Vector2(44, 0),
	"light_t1": Vector2(35, 0),
	"light_t2": Vector2(36, 0),
	"light_t3": Vector2(38, 0),
	"pure_light": Vector2(39, 0),
	"laser_t1": Vector2(35, 0),
	"laser_t2": Vector2(35, 0),
	"laser_t3": Vector2(35, 0),
	"nature_t1": Vector2(34, 0),
	"nature_t2": Vector2(36, 0),
	"nature_t3": Vector2(38, 0),
	"poison_t1": Vector2(31, 0),
	"poison_t2": Vector2(33, 0),
	"poison_t3": Vector2(35, 0),
	"pure_nature": Vector2(40, 0),
	"vapor_t1": Vector2(40, 0),
	"vapor_t2": Vector2(42, 0),
	"vapor_t3": Vector2(44, 0),
	"flamethrower_t1": Vector2(30, 0),
	"flamethrower_t2": Vector2(31, 0),
	"flamethrower_t3": Vector2(32, 0),
}

static func get_muzzle_local_position(
		tower_id: String,
		visual_type: String,
		tree_tier: int,
		visual_family: String = ""
) -> Vector2:
	var by_id = BY_TOWER_ID.get(tower_id, null)
	if by_id is Vector2:
		return by_id

	var lvl := tree_tier
	match visual_type:
		"basic": return Vector2(26 + lvl * 4, 0)
		"rapid": return Vector2(22 + lvl * 2, 0)
		"cannon": return Vector2(18 + lvl * 4, 0)
		"sniper": return Vector2(42 + lvl * 6, 0)
		"prism_lens":
			match visual_family if not visual_family.is_empty() else get_visual_family(tower_id, visual_type):
				"ice":
					return Vector2.ZERO
				"polar":
					return Vector2(20, 0)
				_:
					return Vector2(32 + lvl * 4, 0)
		"furnace": return Vector2(24 + lvl * 3, 0)
		"bio_vine": return Vector2(24 + lvl * 2, 0)
		"stone_bastion": return Vector2(26 + lvl * 3, 0)
		"forge_anvil": return Vector2(28 + lvl * 2, 0)
		"particle_accel": return Vector2(36 + lvl * 5, 0)
		"heavy_mortar": return Vector2(26 + lvl * 2, 0)
		"steam_boiler": return Vector2(24 + lvl * 2, 0)
		"hydro_cannon": return Vector2(28 + lvl * 3, 0)
		"dual_nozzle": return Vector2(28 + lvl * 2, 0)
		"tri_reactor": return Vector2(30 + lvl * 4, 0)
		"golem_body": return Vector2(24 + lvl * 2, 0)
		"seismic_drill": return Vector2(28 + lvl * 3, 0)
		"gold_refinery": return Vector2(24 + lvl * 2, 0)
		"acid_vat": return Vector2(20 + lvl * 2, 0)
		"rail_laser": return Vector2(42 + lvl * 5, 0)
		"strike_blades": return Vector2(24, 0)
		"slow", "lightning", "trickery", "sawblade", "void_orb", "crystal_emitter", "support_halo", "chaos_orb", "toxin_vial", "spore_cap", "tar_pool", "voodoo_totem", "root_cage", "solar_bloom", "void_vortex", "hail_crystal", "void_flower", "storm_turbine":
			return Vector2.ZERO
	return Vector2(28, 0)

static func get_visual_family(tower_id: String, visual_type: String) -> String:
	var id := tower_id.to_lower()
	if id.begins_with("ice_"): return "ice"
	if id.begins_with("polar_"): return "polar"
	if id.begins_with("light_") or id == "pure_light": return "light"
	if id.begins_with("life_"): return "life"
	if id.begins_with("well_"): return "well"
	if id.begins_with("tidal_"): return "tidal"
	if id.begins_with("enchantment_"): return "enchantment"
	if id.begins_with("electricity_"): return "electricity"
	if id.begins_with("jinx_"): return "jinx"
	if id.begins_with("periodic_"): return "periodic"
	if id.begins_with("disease_"): return "disease"
	if id.begins_with("mushroom_"): return "mushroom"
	return visual_type
