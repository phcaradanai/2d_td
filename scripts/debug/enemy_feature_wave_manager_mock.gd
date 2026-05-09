extends Node

var enemy_scene: PackedScene = null
var enemies_config: Dictionary = {}
var spawned_children: Array = []

func spawn_enemy_at_progress(enemy_type: String, prog: float, path_node: Node2D) -> void:
	spawned_children.append({"type": enemy_type, "progress": prog})
	if enemy_scene == null or path_node == null:
		return
	var enemy = enemy_scene.instantiate()
	path_node.add_child(enemy)
	if enemy.has_method("setup"):
		enemy.setup(enemies_config.get(enemy_type, {}).duplicate(true))
	enemy.progress = prog
