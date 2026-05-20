class_name TowerPreviewResolver
extends RefCounted

const TOWER_SCENE_PATH := "res://scenes/towers/Tower.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/projectiles/Projectile.tscn"
const IMPACT_SCENE_PATH := "res://scenes/effects/ImpactEffect.tscn"
const TOWER_VISUAL_BY_ID_DIR := "res://scripts/towers/visuals/by_id"
const TOWER_ATTACK_VFX_DIR := "res://scripts/vfx/towers"

static func resolve(tower_id: String, cfg: Dictionary) -> Dictionary:
	var attack_type := str(cfg.get("attack_type", "single")).to_lower()
	var support_type := str(cfg.get("support_type", "")).to_lower()
	var vfx_script := _load_exact_vfx_script(tower_id)
	var visual_script := _load_exact_visual_script(tower_id)
	var uses_projectile := _uses_projectile_preview(attack_type, support_type)
	return {
		"tower_id": tower_id,
		"display_name": str(cfg.get("display_name", cfg.get("name", tower_id))),
		"tier": int(cfg.get("tier", 1)),
		"elements": cfg.get("elements", []),
		"attack_type": attack_type,
		"role": _role_text(cfg),
		"visual_type": str(cfg.get("visual_type", "")),
		"tower_scene_path": TOWER_SCENE_PATH,
		"visual_script_path": visual_script.resource_path if visual_script != null else "",
		"visual_script_source": "by_id" if visual_script != null else "missing",
		"projectile_scene_path": PROJECTILE_SCENE_PATH if uses_projectile else "",
		"attack_vfx_script_path": vfx_script.resource_path if vfx_script != null else "",
		"attack_vfx_source": "scripts/vfx/towers" if vfx_script != null else "missing",
		"impact_effect_scene_path": IMPACT_SCENE_PATH,
		"has_attack_vfx": vfx_script != null,
		"has_projectile": uses_projectile,
		"has_impact": true,
	}

static func _uses_projectile_preview(attack_type: String, support_type: String) -> bool:
	if support_type != "":
		return false
	if attack_type in ["aura", "support"]:
		return false
	return true

static func _load_exact_visual_script(tower_id: String) -> Script:
	var path := "%s/%s_visual.gd" % [TOWER_VISUAL_BY_ID_DIR, tower_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script

static func _load_exact_vfx_script(tower_id: String) -> GDScript:
	var path := "%s/%s_attack_vfx.gd" % [TOWER_ATTACK_VFX_DIR, tower_id]
	if ResourceLoader.exists(path):
		return load(path) as GDScript
	return TowerAttackVFXRegistry.get_vfx_script(tower_id)

static func _role_text(cfg: Dictionary) -> String:
	var role := str(cfg.get("support_type", ""))
	if role == "" or role == "null":
		role = str(cfg.get("attack_type", ""))
	if role == "" or role == "null":
		role = str(cfg.get("visual_type", ""))
	if role == "" or role == "null":
		role = str(cfg.get("combo_type", ""))
	return role
