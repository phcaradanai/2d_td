## ProjectilePool — recycles Projectile nodes to eliminate per-shot instantiate/free.
## Registered as autoload "ProjectilePool" in project.godot.
##
## Usage:
##   var proj := ProjectilePool.acquire(projectile_container)
##   proj.global_position = spawn_pos
##   proj.setup(...)
##   # When done: call ProjectilePool.release(proj) instead of queue_free()
extends Node

const POOL_SIZE := 200
const ProjectileScene := preload("res://scenes/projectiles/Projectile.tscn")

var _free_list: Array[Node] = []

func _ready() -> void:
	name = "ProjectilePool"
	for i in range(POOL_SIZE):
		var proj := ProjectileScene.instantiate()
		proj.visible = false
		proj.set_process(false)
		proj.set_physics_process(false)
		proj.set_meta("pooled", true)
		add_child(proj)
		_free_list.append(proj)

## Acquire a projectile and reparent it to `container`.
## Returns a pooled node, or instantiates an overflow if pool is exhausted.
func acquire(container: Node) -> Node:
	var proj: Node
	if _free_list.is_empty():
		# Pool exhausted — instantiate overflow (not pooled, self-frees normally).
		proj = ProjectileScene.instantiate()
		container.add_child(proj)
		return proj
	proj = _free_list.pop_back()
	proj.reparent(container)
	proj.visible = true
	proj.set_process(true)
	proj.set_physics_process(true)
	return proj

## Return a projectile to the pool and reset its state.
func release(proj: Node) -> void:
	if not is_instance_valid(proj):
		return
	if not proj.has_meta("pooled"):
		# Overflow node — free normally.
		proj.queue_free()
		return
	_reset_projectile(proj)
	proj.reparent(self)
	proj.visible = false
	proj.set_process(false)
	_free_list.append(proj)

## Release all active pooled projectiles back to the pool.
## Call from main.gd before clearing the projectile container.
func release_active() -> void:
	for child in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(child) and child.has_meta("pooled"):
			release(child)

func _reset_projectile(proj: Node) -> void:
	proj.set("target", null)
	proj.set("lifetime", 5.0)
	proj.set("chained_enemies", [])
	proj.set("status_effects", [])
	proj.set("attack_elements_override", [])
	proj.set("chain_jumps", 0)
	proj.set("last_known_target_pos", Vector2.ZERO)
	proj.modulate = Color.WHITE
	proj.rotation = 0.0
	proj.scale = Vector2.ONE
	proj.set("trail_points", [])
	proj.set("damage", 0.0)
	proj.set("speed", 500.0)
	proj.set("attack_type", "single")
	proj.set("effect_radius", 0.0)
	proj.set("slow_percent", 0.0)
	proj.set("slow_duration", 0.0)
	proj.set("vulnerability_percent", 0.0)
	proj.set("vulnerability_duration", 0.0)
	proj.set("source_id", "")
	proj.set("chain_range", 0.0)
	proj.set("chain_falloff", 1.0)
	proj.set("target_categories", ["land"])
