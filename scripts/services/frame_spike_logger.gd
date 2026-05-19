## FrameSpikeLogger — debug-only per-frame spike detector.
## Prints a compact line when delta exceeds SPIKE_THRESHOLD.
## Cooldown prevents log spam.
class_name FrameSpikeLogger
extends Node

const SPIKE_THRESHOLD := 0.05
const COOLDOWN := 2.0

var _cooldown_remaining := 0.0

func _process(delta: float) -> void:
	if not OS.is_debug_build():
		return
	_cooldown_remaining -= delta
	if delta >= SPIKE_THRESHOLD and _cooldown_remaining <= 0.0:
		_cooldown_remaining = COOLDOWN
		var vfx_count := get_tree().get_nodes_in_group("attack_vfx").size()
		var node_count := get_tree().get_node_count()
		var scene_name := "none"
		if get_tree().current_scene:
			scene_name = str(get_tree().current_scene.name)
		print("[SPIKE] delta=%.1fms fps=%d nodes=%d active_vfx=%d scene=%s" % [
			delta * 1000.0,
			Engine.get_frames_per_second(),
			node_count,
			vfx_count,
			scene_name,
		])
