## TowerAttackVFXService — resolves tower_id → VFX script and spawns the node.
## Per-tower slot model: each tower owns one active VFX at a time.
## Replaces the old global-cap model that caused some towers to show no effect.
class_name TowerAttackVFXService
extends RefCounted

const _BakedSpriteScript := preload("res://scripts/vfx/core/baked_attack_vfx_sprite.gd")

## instance_id(tower) → WeakRef(active VFX node)
## Every tower gets its own slot; the previous VFX is released when a new one spawns.
static var _tower_slots: Dictionary = {}

static func spawn(tower: Node2D, target: Node2D) -> void:
	if PerformanceFirebreak.disable_all_attack_vfx:
		return
	if not is_instance_valid(tower) or not is_instance_valid(target):
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
	var script: GDScript = TowerAttackVFXRegistry.get_vfx_script(tower_id)
	if script == null:
		return  # caller falls back to legacy system

	var color: Color = tower._get_tower_color() \
		if tower.has_method("_get_tower_color") else Color.WHITE
	var secondary_override: Color = Color(-1, -1, -1, -1)
	var svc := tower.get_node_or_null("/root/CosmeticApplyService")
	if svc != null and svc.has_method("get_attack_vfx_skin_colors"):
		var ov : Variant = svc.get_attack_vfx_skin_colors(tower_id)
		if ov.has("primary_color"):
			color = ov["primary_color"]
		if ov.has("secondary_color"):
			secondary_override = ov["secondary_color"]

	var pool := tower.get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_for_tower"):
		return

	var tower_iid := tower.get_instance_id()

	# Release the previous VFX for this tower so the slot is always fresh.
	if _tower_slots.has(tower_iid):
		var old_node = (_tower_slots[tower_iid] as WeakRef).get_ref()
		if old_node != null and is_instance_valid(old_node) \
				and old_node.has_method("_release_to_pool"):
			old_node._release_to_pool()
		_tower_slots.erase(tower_iid)

	# Prefer baked sprite frames when the baker has them — zero draw-API calls per shot.
	var baker := tower.get_node_or_null("/root/AttackVFXFrameBaker")
	if baker != null and baker.has_method("has_frames") and baker.has_frames(tower_id):
		var frames: Array = baker.get_frames(tower_id)
		var sprite := _BakedSpriteScript.new()
		container.add_child(sprite)
		sprite.play(origin, tgt_pos, frames, 0.15, color)
		return
	# Trigger background bake for next shot so subsequent ones use the sprite path.
	if baker != null and baker.has_method("request_bake"):
		baker.request_bake(tower_id, script)

	# Acquire — pool grows on demand, never returns null.
	var node := pool.acquire_for_tower(script, container) as Node2D
	if node == null:
		return

	_tower_slots[tower_iid] = weakref(node)
	node.setup(origin, tgt_pos, color)
	if secondary_override.a >= 0.0:
		node.set("palette_secondary", secondary_override)
	node.configure({})
