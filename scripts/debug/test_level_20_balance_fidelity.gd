extends SceneTree

# Level 20 Balance Verification Script
# This will test if the solver correctly identifies passes/fails and if the runtime bridge works.

func _init():
	var args = OS.get_cmdline_args()
	var level_id = "level_20"
	for arg in args:
		if arg.begins_with("--level="):
			level_id = arg.split("=")[1]
	
	print("[TEST] Starting %s Balance Verification..." % level_id)
	
	var solver_script = load("res://scripts/debug/balance_solver.gd")
	if not solver_script:
		print("[TEST] ERROR: Solver script not found")
		quit(1)
		return
		
	var solver = solver_script.new()
	solver.load_configs()
	
	print("[TEST] Solving %s (this will include runtime verification)..." % level_id)
	var result = solver.solve_level_with_gold_testing(level_id)
	
	print("\n[TEST] Status: ", result.get("status", "UNKNOWN"))
	if result.get("status") == "PASS":
		print("[TEST] PASSED: Perfect-clear confirmed by runtime replay.")
		print("[TEST] Starting Gold Used: ", result.get("starting_gold"))
	else:
		print("[TEST] FAILED: ", result.get("reason", "No reason provided"))
		if result.has("mismatch_report"):
			print("[TEST] MISMATCH DETECTED: ", result["mismatch_report"].get("reason"))
	
	quit(0 if result.get("status") == "PASS" else 1)
