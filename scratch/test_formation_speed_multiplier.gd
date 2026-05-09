extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

var failed := false

func _init() -> void:
	var root := Node2D.new()
	root.name = "FormationSpeedTestRoot"
	get_root().add_child(root)
	current_scene = root
	
	var enemy = ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	enemy.setup({
		"id": "basic",
		"name": "Basic",
		"speed": 90.0,
		"max_hp": 30.0,
		"formation_speed_limit": 55.0,
		"formation_limit_duration": 0.10,
		"formation_release_rate": 2.5
	})
	
	_assert_close("base speed remains unchanged during formation throttle", enemy.base_speed, 90.0, 0.01)
	_assert_close("initial effective speed uses formation multiplier", enemy.speed, 55.0, 0.01)
	_assert_close("formation multiplier is limit divided by base speed", enemy.formation_speed_multiplier, 55.0 / 90.0, 0.01)
	
	enemy.apply_slow(0.40, 1.0)
	_assert_close("status slow stacks as a separate multiplier", enemy.speed, 90.0 * (55.0 / 90.0) * 0.60, 0.01)
	
	enemy._process_formation_speed(0.12)
	_assert_true("formation throttle starts releasing after preserve window", enemy.formation_speed_multiplier > 55.0 / 90.0 and enemy.formation_speed_multiplier < 1.0)
	_assert_close("base speed remains unchanged after release begins", enemy.base_speed, 90.0, 0.01)
	
	enemy._process_formation_speed(0.60)
	_assert_close("formation multiplier returns smoothly to normal", enemy.formation_speed_multiplier, 1.0, 0.01)
	_assert_close("effective speed keeps status multiplier after formation release", enemy.speed, 90.0 * 0.60, 0.01)
	
	enemy.clear_slow()
	_assert_close("effective speed returns to normal identity after status clears", enemy.speed, 90.0, 0.01)
	
	if failed:
		print("[TEST][FAIL] Formation speed multiplier checks failed.")
		quit(1)
	else:
		print("[TEST][PASS] Formation speed multiplier checks passed.")
		quit(0)

func _assert_true(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		failed = true
		push_error("[FAIL] %s" % label)

func _assert_close(label: String, actual: float, expected: float, tolerance: float) -> void:
	if abs(actual - expected) <= tolerance:
		print("[PASS] %s actual=%.3f expected=%.3f" % [label, actual, expected])
	else:
		failed = true
		push_error("[FAIL] %s actual=%.3f expected=%.3f" % [label, actual, expected])
