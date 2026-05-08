extends SceneTree

# Run with: godot -s scripts/debug/qa_suite.gd --headless

func _init():
	print("========================================")
	print("    STARTING PRODUCTION QA SUITE        ")
	print("========================================")
	
	var report_lines = []
	report_lines.append("PRODUCTION QA REPORT")
	report_lines.append("Generated: " + Time.get_datetime_string_from_system())
	report_lines.append("----------------------------------------")
	
	var validator = load("res://scripts/debug/level_validator.gd").new()
	var all_ok = true
	
	# 1. Check towers.json
	report_lines.append("\\n[1] Checking Towers Configuration...")
	var towers_file = FileAccess.open("res://data/towers.json", FileAccess.READ)
	if not towers_file:
		report_lines.append("ERROR: data/towers.json not found!")
		all_ok = false
	else:
		var json = JSON.new()
		var err = json.parse(towers_file.get_as_text())
		if err != OK:
			report_lines.append("ERROR: towers.json syntax is invalid.")
			all_ok = false
		else:
			report_lines.append("OK: towers.json parsed successfully. (" + str(json.data.size()) + " towers)")
			
	# 2. Check enemies.json
	report_lines.append("\\n[2] Checking Enemies Configuration...")
	var enemies_file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if not enemies_file:
		report_lines.append("ERROR: data/enemies.json not found!")
		all_ok = false
	else:
		var json = JSON.new()
		var err = json.parse(enemies_file.get_as_text())
		if err != OK:
			report_lines.append("ERROR: enemies.json syntax is invalid.")
			all_ok = false
		else:
			report_lines.append("OK: enemies.json parsed successfully. (" + str(json.data.size()) + " enemies)")
	
	# 3. Validate Levels
	report_lines.append("\\n[3] Validating 20 Levels...")
	for i in range(1, 21):
		var level_id = "level_%02d" % i
		var waves_id = "waves_%02d" % i
		# Level 10-20 don't seem to be zero-padded in the QA output if they are? Wait, ls output shows level_10.json, so %02d works!
		var level_path = "res://data/levels/" + level_id + ".json"
		var waves_path = "res://data/waves/" + waves_id + ".json"
		
		if not FileAccess.file_exists(level_path):
			report_lines.append("ERROR: " + level_path + " not found.")
			all_ok = false
			continue
			
		if not FileAccess.file_exists(waves_path):
			report_lines.append("ERROR: " + waves_path + " not found.")
			all_ok = false
			continue
			
		var l_file = FileAccess.open(level_path, FileAccess.READ)
		var w_file = FileAccess.open(waves_path, FileAccess.READ)
		
		var l_json = JSON.new()
		var w_json = JSON.new()
		
		if l_json.parse(l_file.get_as_text()) != OK:
			report_lines.append("ERROR: " + level_path + " syntax error.")
			all_ok = false
			continue
			
		if w_json.parse(w_file.get_as_text()) != OK:
			report_lines.append("ERROR: " + waves_path + " syntax error.")
			all_ok = false
			continue
			
		var config = l_json.data
		var waves = w_json.data
		
		var is_valid = validator.validate_level(level_id, config, waves)
		if is_valid:
			report_lines.append("OK: " + level_id + " validated.")
		else:
			report_lines.append("FAIL: " + level_id + " has validation errors. (Check console for validator output)")
			all_ok = false
			
	report_lines.append("\\n----------------------------------------")
	if all_ok:
		report_lines.append("RESULT: PASS - All systems ready for production.")
	else:
		report_lines.append("RESULT: FAIL - Production readiness blocked by errors.")
		
	var report_path = "user://QA_REPORT.txt"
	var out = FileAccess.open(report_path, FileAccess.WRITE)
	if out:
		var final_text = "\n".join(report_lines)
		out.store_string(final_text)
		out.close()
		print("\\n" + final_text)
		print("\\nSaved QA_REPORT.txt to " + ProjectSettings.globalize_path(report_path))
	else:
		print("Failed to write QA_REPORT.txt")
		
	quit()
