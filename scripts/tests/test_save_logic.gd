# Test Script for SaveManager Area Logic
extends SceneTree

func _init():
	print("--- SaveManager Area Logic Test ---")
	var sm = load("res://scripts/core/save_manager.gd").new()
	
	# Test 1: Fresh Save
	sm.save_data["levels"] = {}
	print("L1 unlocked? ", sm.is_level_unlocked("level_01")) # True
	print("L2 unlocked? ", sm.is_level_unlocked("level_02")) # False
	print("Area 2 unlocked? ", sm.is_area_unlocked(2)) # False
	
	# Test 2: Complete L1-L4
	for i in range(1, 5):
		var id = "level_%02d" % i
		sm.save_data["levels"][id] = {"completed": true}
	
	print("L5 unlocked? ", sm.is_level_unlocked("level_05")) # True
	print("L6 unlocked? ", sm.is_level_unlocked("level_06")) # False (L5 not done)
	print("Area 2 unlocked? ", sm.is_area_unlocked(2)) # False
	
	# Test 3: Complete L5
	sm.save_data["levels"]["level_05"] = {"completed": true}
	print("Area 2 unlocked? ", sm.is_area_unlocked(2)) # True
	print("L6 unlocked? ", sm.is_level_unlocked("level_06")) # True
	print("L7 unlocked? ", sm.is_level_unlocked("level_07")) # False
	
	# Test 4: Next Level IDs
	print("Next after L4: ", sm.get_next_level_id("level_04")) # level_05
	print("Next after L5: ", sm.get_next_level_id("level_05")) # level_06
	print("Next after L10: ", sm.get_next_level_id("level_10")) # ""
	
	quit()
