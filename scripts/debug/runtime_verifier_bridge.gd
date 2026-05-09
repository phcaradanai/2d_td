extends SceneTree

# Runtime Verifier Bridge
# Usage: godot -s scripts/debug/runtime_verifier_bridge.gd --headless --plan_path="user://tmp_plan.json"

func _init():
	var args = OS.get_cmdline_args()
	var plan_path = ""
	for arg in args:
		if arg.begins_with("--plan_path="):
			plan_path = arg.split("=")[1]
	
	if plan_path == "":
		print("ERROR: No plan_path provided")
		quit(1)
		return

	var file = FileAccess.open(plan_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open plan file: ", plan_path)
		quit(1)
		return
		
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		print("ERROR: Failed to parse plan JSON")
		quit(1)
		return
		
	var plan = json.data
	call_deferred("_run_verification", plan)

func _run_verification(plan: Dictionary):
	# Load the Main scene
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		print("ERROR: Could not load Main scene")
		quit(1)
		return
		
	var main = main_scene.instantiate()
	root.add_child(main)
	
	# Add the verifier
	var verifier_script = load("res://scripts/debug/auto_play_verifier.gd")
	var verifier = Node.new()
	verifier.set_script(verifier_script)
	verifier.name = "AutoPlayVerifier"
	main.add_child(verifier)
	
	# Speed up simulation
	Engine.time_scale = 10.0
	
	verifier.state_changed.connect(func(state, msg):
		# print("[BRIDGE] State: ", state, " - ", msg)
		pass
	)
	
	# Start verification
	verifier.start_verification(plan)
	
	# Monitor for completion or failure
	while verifier.is_active:
		await get_tree().create_timer(0.1).timeout
	
	# Final report
	var results = {
		"status": "PASS" if verifier.state == 15 else "FAIL", # 15 = COMPLETED, 16 = FAILED
		"fail_reason": verifier.fail_reason,
		"wave": verifier.current_wave,
		"lives_lost": verifier.starting_lives - main.get_node("GameManager").lives if main.get_node_or_null("GameManager") else 0,
		"gold_remaining": main.get_node("GameManager").gold if main.get_node_or_null("GameManager") else 0,
		"enemies_killed": main.get_node("GameManager").battle_telemetry.metrics.get("enemies_killed_total", 0) if main.get_node_or_null("GameManager") and main.get_node("GameManager").battle_telemetry else 0,
		"enemies_leaked": main.get_node("GameManager").battle_telemetry.metrics.get("enemies_leaked_total", 0) if main.get_node_or_null("GameManager") and main.get_node("GameManager").battle_telemetry else 0,
		"damage_by_tower_type": main.get_node("GameManager").battle_telemetry.metrics.get("damage_by_tower_type", {}) if main.get_node_or_null("GameManager") and main.get_node("GameManager").battle_telemetry else {}
	}
	
	print("---VERIFICATION_RESULT_START---")
	print(JSON.stringify(results))
	print("---VERIFICATION_RESULT_END---")
	
	quit(0 if results.status == "PASS" else 1)
