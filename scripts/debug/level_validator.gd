extends Node

# Level Validator
# Checks level configurations and waves for design standards and errors.

func validate_level(level_id: String, config: Dictionary, waves: Array) -> bool:
	var ok = true
	var errors = []
	var warnings = []

	# 1. Path Validation
	var paths = config.get("paths", {})
	if paths.is_empty():
		var legacy_path = config.get("path_cells", [])
		if legacy_path.is_empty():
			errors.append("No paths defined (neither 'paths' nor 'path_cells')")
			ok = false
		else:
			if legacy_path.size() < 2:
				errors.append("Legacy path has fewer than 2 points")
				ok = false
	else:
		for p_id in paths:
			var pts = paths[p_id]
			if pts.size() < 2:
				errors.append("Path '%s' has fewer than 2 points" % p_id)
				ok = false
			else:
				# Check alignment (consecutive cells must be neighbors)
				for j in range(pts.size() - 1):
					var p1 = Vector2i(pts[j][0], pts[j][1])
					var p2 = Vector2i(pts[j+1][0], pts[j+1][1])
					var dist = abs(p1.x - p2.x) + abs(p1.y - p2.y)
					if dist > 1:
						warnings.append("Path '%s' has jump between %s and %s" % [p_id, p1, p2])

	# 2. Build Zone Validation
	var buildable = config.get("buildable_cells", [])
	var total_cells = config.get("grid_cols", 20) * config.get("grid_rows", 12)
	
	var path_cells_all = []
	if not paths.is_empty():
		for p_id in paths:
			path_cells_all.append_array(paths[p_id])
	else:
		path_cells_all.append_array(config.get("path_cells", []))
	
	var non_path_count = total_cells - path_cells_all.size()
	if non_path_count < 20:
		warnings.append("This map has very little non-path space for tower placement (%d cells)" % non_path_count)
	
	if not buildable.is_empty():
		# If they DID provide manual cells, still validate them but don't require them.
		for b in buildable:
			var cell = Vector2i(b[0], b[1])
			for p in path_cells_all:
				if p[0] == cell.x and p[1] == cell.y:
					errors.append("Manual build spot [%d, %d] overlaps with path" % [cell.x, cell.y])
					ok = false
			
			if cell.x < 0 or cell.x >= config.get("grid_cols", 20) or cell.y < 0 or cell.y >= config.get("grid_rows", 12):
				errors.append("Manual build spot [%d, %d] is outside battlefield bounds" % [cell.x, cell.y])
				ok = false

	# 3. Wave & Special Enemy Isolation Check
	for i in range(waves.size()):
		var wave = waves[i]
		var groups = wave.get("groups", [])
		var has_escort = false
		var bulwarks = []
		var hunters = []
		var normal_count = 0
		
		for group in groups:
			var type = group.get("type", "").to_lower()
			if type == "bulwark":
				bulwarks.append(group)
			elif type == "hunter":
				hunters.append(group)
			elif type == "basic" or type == "fast":
				normal_count += group.get("count", 0)
		
		if not bulwarks.is_empty() and normal_count == 0:
			warnings.append("Wave %d: Bulwark appears without escorts" % (i + 1))
			
		if not hunters.is_empty() and normal_count == 0 and bulwarks.is_empty():
			warnings.append("Wave %d: Hunter appears completely alone" % (i + 1))

	# 4. Area Theme Consistency
	var area_id = config.get("area_id", 0)
	if area_id == 0:
		warnings.append("Missing area_id")
	elif area_id > 4:
		errors.append("Invalid area_id: %d (max 4)" % area_id)
		ok = false

	# Logging
	if ok:
		var path_count = paths.size() if not paths.is_empty() else 1
		print("[LevelValidation] level=%s ok=true paths=%d build_spots=%d waves=%d" % [level_id, path_count, buildable.size(), waves.size()])
	else:
		print("[LevelValidation] level=%s FAILED" % level_id)
		for err in errors:
			print("  [ERROR] %s" % err)
	
	for wrn in warnings:
		print("  [WaveDesign] warning: %s" % wrn)
		
	return ok
