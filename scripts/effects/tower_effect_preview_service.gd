class_name TowerEffectPreviewService
extends RefCounted

const ProjectileScene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
const ImpactScene: PackedScene = preload("res://scenes/effects/ImpactEffect.tscn")
const CatalogPreviewModeScript = preload("res://scripts/debug/catalog_preview_mode.gd")
const TOWER_ATTACK_VFX_DIR := "res://scripts/vfx/towers"

static func spawn_attack_vfx_preview(tower_id: String, from_pos: Vector2, to_pos: Vector2, parent: Node, color: Color) -> Node2D:
	if parent == null:
		return null
	var script := _load_exact_tower_vfx_script(tower_id)
	if script == null:
		return null
	var node := Node2D.new()
	node.set_script(script)
	parent.add_child(node)
	CatalogPreviewModeScript.mark_preview_tree(node, false, true)
	node.set_meta("catalog_effect_preview", true)
	if node.has_method("setup"):
		node.setup(from_pos, to_pos, color)
	if node.has_method("configure"):
		node.configure({})
	return node

static func spawn_projectile_preview(tower_id: String, cfg: Dictionary, from_pos: Vector2, to_pos: Vector2, parent: Node, color: Color) -> Node2D:
	if parent == null:
		return null
	var projectile := ProjectileScene.instantiate() as Node2D
	if projectile == null:
		return null
	parent.add_child(projectile)
	CatalogPreviewModeScript.mark_preview_tree(projectile, false, true)
	projectile.set_meta("catalog_projectile_preview", true)
	projectile.global_position = from_pos
	projectile.rotation = (to_pos - from_pos).angle()
	projectile.modulate = color
	projectile.set("source_id", tower_id)
	projectile.set("attack_type", str(cfg.get("attack_type", "single")))
	projectile.set("attack_elements_override", _elements(cfg))
	if projectile.has_method("setup"):
		projectile.setup(null, 0.0, float(cfg.get("projectile_speed", 500.0)), str(cfg.get("attack_type", "single")), 0.0, 0.0, 0.0, [], tower_id, 0.0, 0.0, _elements(cfg))
	projectile.set_process(false)
	projectile.set_physics_process(false)
	projectile.queue_redraw()
	return projectile

static func spawn_impact_preview(cfg: Dictionary, impact_pos: Vector2, parent: Node, color: Color) -> Node2D:
	if parent == null:
		return null
	var impact := ImpactScene.instantiate() as Node2D
	if impact == null:
		return null
	parent.add_child(impact)
	CatalogPreviewModeScript.mark_preview_tree(impact, false, true)
	impact.set_meta("preview_static", true)
	impact.global_position = impact_pos
	if impact.has_method("setup"):
		impact.setup(color, 1.4, str(cfg.get("attack_type", "single")), color.lightened(0.25), Color.WHITE)
	impact.set_process(false)
	impact.set_physics_process(false)
	return impact

static func _elements(cfg: Dictionary) -> Array:
	var out: Array = []
	var raw = cfg.get("elements", [])
	if raw is Array:
		for value in raw:
			out.append(str(value))
	return out

static func _load_exact_tower_vfx_script(tower_id: String) -> GDScript:
	var exact_path := "%s/%s_attack_vfx.gd" % [TOWER_ATTACK_VFX_DIR, tower_id]
	if ResourceLoader.exists(exact_path):
		return load(exact_path) as GDScript
	return TowerAttackVFXRegistry.get_vfx_script(tower_id)
