extends RefCounted
class_name TowerHitVFXDispatcher

const TowerHitVFXScript := preload("res://scripts/effects/tower_hit_vfx.gd")

static func spawn(
		caller: Node,
		hit_pos: Vector2,
		mode: String,
		radius_hint: float,
		core_color: Color,
		glow_color: Color,
		accent_color: Color,
		hit_angle: float = 0.0) -> void:
	if caller == null or PerformanceFirebreak.disable_all_attack_vfx:
		return

	var perf_service := caller.get_node_or_null("/root/PerformanceBudgetService")
	var quality_name := "HIGH"
	if perf_service != null and perf_service.has_method("get_quality_name"):
		quality_name = str(perf_service.get_quality_name())
	if quality_name == "LOW":
		return
	if perf_service != null and perf_service.has_method("can_spawn_attack_vfx"):
		if not perf_service.can_spawn_attack_vfx(int(TowerHitVFXScript.active_count)):
			return

	var tree := caller.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var effects_container := tree.current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	var parent_node: Node = effects_container if effects_container else tree.current_scene
	var pool := caller.get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_script"):
		return

	var effect := pool.acquire_script(TowerHitVFXScript, parent_node, "tower_hit_vfx", "attack_vfx") as Node2D
	if effect == null:
		return
	effect.global_position = hit_pos
	if effect.has_method("setup"):
		effect.setup(mode, radius_hint, core_color, glow_color, accent_color, hit_angle, quality_name)
