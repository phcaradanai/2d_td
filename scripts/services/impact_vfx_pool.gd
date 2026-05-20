## ImpactVFXPool — recycles ImpactEffect nodes to eliminate per-hit instantiate/free.
## Registered as autoload "ImpactVFXPool" in project.godot.
extends Node

const POOL_SIZE := 40
const ImpactScene := preload("res://scenes/effects/ImpactEffect.tscn")

var _free_list: Array[Node] = []

func _ready() -> void:
	name = "ImpactVFXPool"
	for i in range(POOL_SIZE):
		var fx := ImpactScene.instantiate()
		fx.visible = false
		fx.set_meta("pooled", true)
		add_child(fx)
		_free_list.append(fx)

## Acquire an ImpactEffect and reparent it to `container`.
func acquire(container: Node) -> Node:
	if _free_list.is_empty():
		return null
	var pooled_fx : Node = _free_list.pop_back()
	pooled_fx.reparent(container)
	pooled_fx.visible = true
	pooled_fx.process_mode = Node.PROCESS_MODE_INHERIT
	pooled_fx.set_process(true)
	return pooled_fx

## Return an ImpactEffect to the pool after its animation completes.
func release(fx: Node) -> void:
	if not is_instance_valid(fx):
		return
	if not fx.has_meta("pooled"):
		fx.call_deferred("free")
		return
	_reset_fx(fx)
	fx.reparent(self)
	fx.visible = false
	fx.process_mode = Node.PROCESS_MODE_DISABLED
	fx.set_process(false)
	_free_list.append(fx)

## Release all active pooled ImpactEffect nodes back to the pool.
func release_active() -> void:
	for fx in get_tree().get_nodes_in_group("impact_vfx_pool"):
		if is_instance_valid(fx) and fx.has_meta("pooled"):
			release(fx)

func _reset_fx(fx: Node) -> void:
	fx.scale = Vector2.ONE
	fx.modulate = Color.WHITE
	fx.rotation = 0.0
	if fx.has_method("reset_for_pool"):
		fx.reset_for_pool()
