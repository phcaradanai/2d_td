## TowerAttackVFX — central tower attack VFX resolver.
##
## Usage (from tower.gd shoot()):
##   TowerAttackVFX.spawn_attack_vfx(self, current_target)
##
## No scene file needed.  The dispatcher creates a bare Node2D, attaches
## attack_vfx.gd as the script, adds it to the EffectsContainer, then calls
## setup().  The node self-frees after its lifetime expires.
##
## Rules:
## - Never changes gameplay stats, damage, or targeting.
## - All VFX are short-lived and queue_free themselves.
## - Direction is always computed from origin -> target, never hardcoded.
class_name TowerAttackVFX
extends RefCounted

const _VFX_SCRIPT = preload("res://scripts/effects/attack_vfx.gd")

## visual_type  →  attack VFX style.
## Towers not listed fall back to "rapid_tracer".
const _VFX_MAP: Dictionary = {
	# ── Neutral ──────────────────────────────────────────────────────────────
	"basic":           "rapid_tracer",
	# ── Cannon / heavy ───────────────────────────────────────────────────────
	"cannon":          "cannon_blast",
	"heavy_mortar":    "cannon_blast",
	"golem_body":      "cannon_blast",
	"forge_anvil":     "cannon_blast",
	"dual_nozzle":     "flame_cone",       # Flamethrower
	"seismic_drill":   "earth_impact",
	"stone_bastion":   "earth_impact",
	"hydro_cannon":    "water_jet",
	# ── Rapid / bolt ─────────────────────────────────────────────────────────
	"rapid":           "rapid_tracer",
	"strike_blades":   "rapid_tracer",
	"tri_reactor":     "light_pulse",
	# ── Fire ─────────────────────────────────────────────────────────────────
	"furnace":         "flame_cone",
	"ember_bloom":     "flame_cone",
	"steam_boiler":    "steam_burst",
	# ── Nature / vine ────────────────────────────────────────────────────────
	"bio_vine":        "nature_vine",
	"root_cage":       "nature_vine",
	# ── Electric / chain ─────────────────────────────────────────────────────
	"lightning":       "chain_lightning",
	"storm_turbine":   "chain_lightning",
	# ── Slow / water / ice ───────────────────────────────────────────────────
	"slow":            "frost_beam",
	"crystal_emitter": "frost_beam",
	"hail_crystal":    "frost_beam",
	"water_jet":       "water_jet",        # explicit type (unused visual_type, future-proof)
	# ── Void / dark ──────────────────────────────────────────────────────────
	"void_vortex":     "void_rift",
	"void_orb":        "shadow_lash",
	"void_flower":     "void_rift",
	"chaos_orb":       "void_rift",
	"tar_pool":        "void_rift",
	"voodoo_totem":    "void_rift",
	# ── Toxic / spore ────────────────────────────────────────────────────────
	"acid_vat":        "acid_splash",
	"toxin_vial":      "poison_spray",
	"spore_cap":       "spore_puff",
	# ── Precision / sniper ───────────────────────────────────────────────────
	"sniper":          "precision_beam",
	"prism_lens":      "precision_beam",
	"rail_laser":      "precision_beam",
	"particle_accel":  "precision_beam",
	# ── Light / gold / solar ─────────────────────────────────────────────────
	"gold_refinery":   "light_pulse",
	"solar_bloom":     "light_pulse",
	# ── Enchant / magic / support ────────────────────────────────────────────
	"support_halo":    "magic_enchant",
	# ── Trickery ─────────────────────────────────────────────────────────────
	"trickery":        "trickery_shimmer",
}

## Resolve the VFX style string for a tower node.
static func resolve_vfx_type(tower: Node2D) -> String:
	var vt: String = str(tower.get("visual_type")) if "visual_type" in tower else "basic"
	return _VFX_MAP.get(vt, "rapid_tracer")

## Main entry point.  Call from tower.shoot() in place of spawn_muzzle_flash().
static func spawn_attack_vfx(tower: Node2D, target: Node2D,
							  _context: Dictionary = {}) -> void:
	if PerformanceFirebreak.disable_all_attack_vfx:
		return
	if not is_instance_valid(tower) or not is_instance_valid(target):
		return

	# EffectsContainer is the standard bucket for short-lived VFX nodes.
	var container: Node = \
		tower.get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container:
		container = tower.get_tree().current_scene
	if not container:
		return

	# Attack origin: use muzzle marker if tower exposes get_fire_origin().
	var origin: Vector2 = \
		tower.get_fire_origin() if tower.has_method("get_fire_origin") else tower.global_position

	# Target anchor: prefer get_hit_origin() over raw global_position.
	var tgt_pos: Vector2 = target.global_position
	if target.has_method("get_hit_origin"):
		tgt_pos = target.get_hit_origin()

	# Baker-style owned VFX: draw once, Tween fade — no pool, no global cap.
	# Each registered tower owns a permanent VFX node set up in apply_level_visuals().
	var owned_vfx = tower.get("_owned_vfx")
	if owned_vfx != null and is_instance_valid(owned_vfx) \
			and owned_vfx.has_method("show_shot_static"):
		var origin_o: Vector2 = tower.get_fire_origin() \
			if tower.has_method("get_fire_origin") else tower.global_position
		var tgt_o: Vector2 = target.get_hit_origin() \
			if target.has_method("get_hit_origin") else target.global_position
		var color_o: Color = tower._get_tower_color() \
			if tower.has_method("_get_tower_color") else Color.WHITE
		owned_vfx.show_shot_static(origin_o, tgt_o, color_o)
		return

	# Budget cap for pool-based (legacy / unregistered) towers only.
	var perf_service := tower.get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("can_spawn_attack_vfx"):
		if not perf_service.can_spawn_attack_vfx(AttackVFX._active_count):
			return
	else:
		if AttackVFX._active_count >= AttackVFX.MAX_ACTIVE:
			return

	# Pool path: try registry first for non-owned towers.
	var tower_id: String = str(tower.get("tower_id")) if "tower_id" in tower else ""
	if tower_id != "" and TowerAttackVFXRegistry.get_vfx_script(tower_id) != null:
		TowerAttackVFXService.spawn(tower, target)
		return

	# Legacy visual_type dispatch (unchanged — runs for unknown tower_ids).
	var vfx_type := resolve_vfx_type(tower)

	# Element-aware color (calls tower's own helper; falls back to white).
	var color: Color = Color.WHITE
	if tower.has_method("_get_tower_color"):
		color = tower._get_tower_color()

	var pool := tower.get_node_or_null("/root/VisualEffectPoolService")
	var node: Node2D = null
	if pool != null and pool.has_method("acquire_script"):
		node = pool.acquire_script(_VFX_SCRIPT, container, "attack_vfx_legacy", "attack_vfx") as Node2D
	if node == null:
		return
	node.setup(vfx_type, origin, tgt_pos, color)
