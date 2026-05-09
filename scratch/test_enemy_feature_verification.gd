extends SceneTree

const VERIFIER_SCRIPT := preload("res://scripts/debug/enemy_feature_verifier.gd")

func _init() -> void:
	ProjectSettings.set_setting("application/config/enable_balance_tools", true)
	call_deferred("_run")

func _run() -> void:
	var root_scene := Node2D.new()
	root_scene.name = "EnemyFeatureVerificationTestScene"
	root.add_child(root_scene)
	current_scene = root_scene

	var verifier = VERIFIER_SCRIPT.new()
	root_scene.add_child(verifier)
	await process_frame

	var report: Dictionary = await verifier.run_all_checks()
	print(verifier.format_report(report))

	var failed := int(report.get("summary", {}).get("failed", 1))
	if failed > 0:
		push_error("Enemy feature verification failed: %d checks failed." % failed)
		quit(1)
	else:
		print("[TEST][PASS] Enemy feature verification checks passed.")
		quit(0)
