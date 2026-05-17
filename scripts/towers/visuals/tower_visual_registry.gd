extends RefCounted
class_name TowerVisualRegistry

# Lookup order: tower_id (BY_ID) first, visual_type (VISUALS) second, "basic" default last.
# Add a by_id entry to scripts/towers/visuals/by_id/ to override any tower independently.

# Per-tower-id overrides. Tower identity takes precedence over shared visual_type families.
const BY_ID := {
	"trickery_t1": preload("res://scripts/towers/visuals/by_id/trickery_t1_visual.gd"),
	"blacksmith_t1": preload("res://scripts/towers/visuals/by_id/blacksmith_t1_visual.gd"),
	"electricity_t1": preload("res://scripts/towers/visuals/by_id/electricity_t1_visual.gd"),
	"quark_t1": preload("res://scripts/towers/visuals/by_id/quark_t1_visual.gd"),
	"vapor_t1": preload("res://scripts/towers/visuals/by_id/vapor_t1_visual.gd"),
	"roots_t1": preload("res://scripts/towers/visuals/by_id/roots_t1_visual.gd"),
	"muck_t1": preload("res://scripts/towers/visuals/by_id/muck_t1_visual.gd"),
	"zealot_t1": preload("res://scripts/towers/visuals/by_id/zealot_t1_visual.gd"),
	"flamethrower_t1": preload("res://scripts/towers/visuals/by_id/flamethrower_t1_visual.gd"),
}

# Shared visual_type families — fallback when no by_id entry exists.
const VISUALS := {
	"acid_vat": preload("res://scripts/towers/visuals/acid_vat_tower_visual.gd"),
	"basic": preload("res://scripts/towers/visuals/basic_tower_visual.gd"),
	"bio_vine": preload("res://scripts/towers/visuals/bio_vine_tower_visual.gd"),
	"cannon": preload("res://scripts/towers/visuals/cannon_tower_visual.gd"),
	"chaos_orb": preload("res://scripts/towers/visuals/chaos_orb_tower_visual.gd"),
	"crystal_emitter": preload("res://scripts/towers/visuals/crystal_emitter_tower_visual.gd"),
	"dual_nozzle": preload("res://scripts/towers/visuals/dual_nozzle_tower_visual.gd"),
	"ember_bloom": preload("res://scripts/towers/visuals/ember_bloom_tower_visual.gd"),
	"forge_anvil": preload("res://scripts/towers/visuals/forge_anvil_tower_visual.gd"),
	"furnace": preload("res://scripts/towers/visuals/furnace_tower_visual.gd"),
	"gold_refinery": preload("res://scripts/towers/visuals/gold_refinery_tower_visual.gd"),
	"golem_body": preload("res://scripts/towers/visuals/golem_body_tower_visual.gd"),
	"hail_crystal": preload("res://scripts/towers/visuals/hail_crystal_tower_visual.gd"),
	"heavy_mortar": preload("res://scripts/towers/visuals/heavy_mortar_tower_visual.gd"),
	"hydro_cannon": preload("res://scripts/towers/visuals/hydro_cannon_tower_visual.gd"),
	"lightning": preload("res://scripts/towers/visuals/lightning_tower_visual.gd"),
	"particle_accel": preload("res://scripts/towers/visuals/particle_accel_tower_visual.gd"),
	"prism_lens": preload("res://scripts/towers/visuals/prism_lens_tower_visual.gd"),
	"rail_laser": preload("res://scripts/towers/visuals/rail_laser_tower_visual.gd"),
	"rapid": preload("res://scripts/towers/visuals/rapid_tower_visual.gd"),
	"root_cage": preload("res://scripts/towers/visuals/root_cage_tower_visual.gd"),
	"sawblade": preload("res://scripts/towers/visuals/sawblade_tower_visual.gd"),
	"seismic_drill": preload("res://scripts/towers/visuals/seismic_drill_tower_visual.gd"),
	"slow": preload("res://scripts/towers/visuals/slow_tower_visual.gd"),
	"sniper": preload("res://scripts/towers/visuals/sniper_tower_visual.gd"),
	"solar_bloom": preload("res://scripts/towers/visuals/solar_bloom_tower_visual.gd"),
	"spore_cap": preload("res://scripts/towers/visuals/spore_cap_tower_visual.gd"),
	"steam_boiler": preload("res://scripts/towers/visuals/steam_boiler_tower_visual.gd"),
	"stone_bastion": preload("res://scripts/towers/visuals/stone_bastion_tower_visual.gd"),
	"storm_turbine": preload("res://scripts/towers/visuals/storm_turbine_tower_visual.gd"),
	"strike_blades": preload("res://scripts/towers/visuals/strike_blades_tower_visual.gd"),
	"support_halo": preload("res://scripts/towers/visuals/support_halo_tower_visual.gd"),
	"tar_pool": preload("res://scripts/towers/visuals/tar_pool_tower_visual.gd"),
	"toxin_vial": preload("res://scripts/towers/visuals/toxin_vial_tower_visual.gd"),
	"tri_reactor": preload("res://scripts/towers/visuals/tri_reactor_tower_visual.gd"),
	"trickery": preload("res://scripts/towers/visuals/trickery_tower_visual.gd"),
	"void_flower": preload("res://scripts/towers/visuals/void_flower_tower_visual.gd"),
	"void_orb": preload("res://scripts/towers/visuals/void_orb_tower_visual.gd"),
	"void_vortex": preload("res://scripts/towers/visuals/void_vortex_tower_visual.gd"),
	"voodoo_totem": preload("res://scripts/towers/visuals/voodoo_totem_tower_visual.gd")
}

static func get_visual_script(tower_id: String, visual_type: String) -> Script:
	if BY_ID.has(tower_id):
		return BY_ID[tower_id]
	return VISUALS.get(visual_type, VISUALS.get("basic"))
