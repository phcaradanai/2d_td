## TowerAttackVFXService — resolves tower_id → VFX script and spawns the node.
## Called from the updated TowerAttackVFX.spawn_attack_vfx().
class_name TowerAttackVFXService
extends RefCounted

static func spawn(tower: Node2D, target: Node2D) -> void:
	if not is_instance_valid(tower) or not is_instance_valid(target):
		return
	if not TowerAttackVFXPool.can_spawn():
		return

	var container: Node = tower.get_tree().current_scene \
		.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container:
		container = tower.get_tree().current_scene
	if not container:
		return

	var origin: Vector2 = tower.get_fire_origin() \
		if tower.has_method("get_fire_origin") else tower.global_position
	var tgt_pos: Vector2 = target.get_hit_origin() \
		if target.has_method("get_hit_origin") else target.global_position

	var tower_id: String = str(tower.get("tower_id")) if "tower_id" in tower else ""
	var script: GDScript = TowerAttackVFXRegistry.get_script(tower_id)
	if script == null:
		return  # caller falls back to legacy system

	var color: Color = tower._get_tower_color() \
		if tower.has_method("_get_tower_color") else Color.WHITE

	var node: Node2D = Node2D.new()
	node.set_script(script)
	container.add_child(node)
	node.setup(origin, tgt_pos, color)
	node.configure({})
