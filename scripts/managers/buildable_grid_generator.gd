extends RefCounted
class_name BuildableGridGenerator

const MODE_FULL_NON_PATH := "full_non_path"
const MODE_PATH_RADIUS := "path_radius"
const MODE_MANUAL := "manual"
const DEFAULT_MODE := MODE_FULL_NON_PATH
const DEFAULT_PATH_RADIUS := 2

const BLOCKING_LIST_KEYS := [
	"blocked_cells",
	"obstacle_cells",
	"wall_cells",
	"water_cells",
	"void_cells",
	"cliff_cells",
	"reserved_cells",
	"non_buildable_cells",
	"static_occupied_cells"
]

static func resolve_buildable_mode(level_data: Dictionary) -> String:
	var mode := str(level_data.get("buildable_mode", DEFAULT_MODE)).strip_edges().to_lower()
	if [MODE_FULL_NON_PATH, MODE_PATH_RADIUS, MODE_MANUAL].has(mode):
		return mode
	return DEFAULT_MODE

static func generate_buildable_grid(level_data: Dictionary) -> Array[Vector2i]:
	match resolve_buildable_mode(level_data):
		MODE_MANUAL:
			return sort_cells(_filter_valid_manual_cells(_cells_from_array(level_data.get("buildable_cells", [])), level_data))
		MODE_PATH_RADIUS:
			return generate_path_radius_buildable(level_data, int(level_data.get("buildable_radius", DEFAULT_PATH_RADIUS)))
		_:
			return generate_full_non_path_buildable_grid(level_data)

static func generate_full_non_path_buildable_grid(level_data: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var forbidden := collect_forbidden_cells(level_data)
	var cols := int(level_data.get("grid_cols", level_data.get("grid_width", 20)))
	var rows := int(level_data.get("grid_rows", level_data.get("grid_height", 12)))
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			if forbidden.has(cell_key(cell)):
				continue
			if not is_valid_terrain_for_building(cell, level_data):
				continue
			result.append(cell)
	return sort_cells(result)

static func generate_path_radius_buildable(level_data: Dictionary, radius: int = DEFAULT_PATH_RADIUS) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	for path_cell in unique_path_cells(level_data):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx == 0 and dy == 0:
					continue
				if max(abs(dx), abs(dy)) > radius:
					continue
				var cell := path_cell + Vector2i(dx, dy)
				var key := cell_key(cell)
				if seen.has(key):
					continue
				if is_cell_buildable_static(cell, level_data):
					result.append(cell)
					seen[key] = true
	return sort_cells(result)

static func collect_forbidden_cells(level_data: Dictionary) -> Dictionary:
	var out := {}
	
	# Path is the primary forbidden area
	for cell in unique_path_cells(level_data):
		out[cell_key(cell)] = "path"
		
	# Spawn and Base are also forbidden if they are on path (they usually are)
	for cell in spawn_cells(level_data):
		if not out.has(cell_key(cell)):
			out[cell_key(cell)] = "spawn"
	for cell in base_cells(level_data):
		if not out.has(cell_key(cell)):
			out[cell_key(cell)] = "base"
			
	# Explicit blocking keys (except decorative)
	for key in BLOCKING_LIST_KEYS:
		for cell in _cells_from_array(level_data.get(key, [])):
			if not out.has(cell_key(cell)):
				out[cell_key(cell)] = _reason_from_key(key)
				
	_collect_path_endpoint_metadata(level_data, out)
	_collect_terrain_forbidden(level_data, out)
	return out

static func is_cell_buildable_static(cell: Vector2i, level_data: Dictionary) -> bool:
	if not inside_grid(cell, level_data):
		return false
	if collect_forbidden_cells(level_data).has(cell_key(cell)):
		return false
	return is_valid_terrain_for_building(cell, level_data)

static func get_static_block_reason(cell: Vector2i, level_data: Dictionary) -> String:
	if not inside_grid(cell, level_data):
		return "out_of_bounds"
	var forbidden := collect_forbidden_cells(level_data)
	var key := cell_key(cell)
	if forbidden.has(key):
		return str(forbidden[key])
	if not is_valid_terrain_for_building(cell, level_data):
		return "terrain"
	return ""

static func is_valid_terrain_for_building(cell: Vector2i, level_data: Dictionary) -> bool:
	var terrain_value = _terrain_value_for_cell(cell, level_data)
	if terrain_value == null:
		return true
	if terrain_value is Dictionary:
		if terrain_value.has("buildable") and not bool(terrain_value.get("buildable", true)):
			return false
		var terrain_id := str(terrain_value.get("type", terrain_value.get("terrain", ""))).to_lower()
		return not ["path", "water", "void", "wall", "cliff"].has(terrain_id)
	var terrain_name := str(terrain_value).to_lower()
	return not ["path", "water", "void", "wall", "cliff"].has(terrain_name)

static func analyze_full_non_path(level_data: Dictionary, solver_candidate_count: int = -1) -> Dictionary:
	var old_cells := _cells_from_array(level_data.get("buildable_cells", []))
	var new_cells := generate_full_non_path_buildable_grid(level_data)
	var forbidden := collect_forbidden_cells(level_data)
	var total := int(level_data.get("grid_cols", 20)) * int(level_data.get("grid_rows", 12))
	return {
		"level_id": str(level_data.get("id", "unknown")),
		"mode": resolve_buildable_mode(level_data),
		"grid_size": "%dx%d" % [int(level_data.get("grid_cols", 20)), int(level_data.get("grid_rows", 12))],
		"total_cells": total,
		"path_cells": unique_path_cells(level_data).size(),
		"spawn_cells": spawn_cells(level_data).size(),
		"base_cells": base_cells(level_data).size(),
		"blocked_cells": _cells_from_blocking_keys(level_data).size(),
		"obstacle_cells": _cells_from_array(level_data.get("obstacle_cells", [])).size(),
		"non_buildable_cells": _cells_from_array(level_data.get("non_buildable_cells", [])).size(),
		"final_buildable_cells": new_cells.size(),
		"buildable_ratio": 0.0 if total <= 0 else snappedf(float(new_cells.size()) / float(total) * 100.0, 0.1),
		"old_buildable_count": old_cells.size(),
		"new_buildable_count": new_cells.size(),
		"forbidden_count": forbidden.size(),
		"solver_candidate_count": solver_candidate_count if solver_candidate_count >= 0 else new_cells.size(),
		"pass": _no_overlap_with_forbidden(new_cells, forbidden)
	}

static func validate_disruptor_counterplay(level_data: Dictionary, sniper_range: float, disruptor_aura_radius: float) -> Dictionary:
	var buildable := generate_buildable_grid(level_data)
	var safe_counts := {}
	var weak_segments := []
	var total_safe := 0
	var grid_size := float(level_data.get("grid_size", 64.0))
	var min_safe_distance := disruptor_aura_radius + grid_size * 0.35
	for path_name in path_map(level_data).keys():
		var path: Array[Vector2i] = path_map(level_data)[path_name]
		var path_safe := 0
		for path_cell in path:
			var path_center := cell_world_center(path_cell, level_data)
			var segment_safe := 0
			for build_cell in buildable:
				var build_center := cell_world_center(build_cell, level_data)
				var dist := build_center.distance_to(path_center)
				if dist <= sniper_range and dist > min_safe_distance:
					segment_safe += 1
			if segment_safe <= 0:
				weak_segments.append({"path": path_name, "cell": _cell_to_array(path_cell), "reason": "no_safe_sniper_cell"})
			path_safe += segment_safe
		safe_counts[path_name] = path_safe
		total_safe += path_safe
	return {
		"level_id": str(level_data.get("id", "unknown")),
		"disruptor_aura_radius": disruptor_aura_radius,
		"sniper_range": sniper_range,
		"valid_safe_sniper_cells_count": total_safe,
		"per_path_safe_counts": safe_counts,
		"weak_segments": weak_segments,
		"pass": weak_segments.is_empty() and total_safe > 0
	}

static func format_full_non_path_report(report: Dictionary) -> String:
	return "\n".join([
		"Full Non-Path Buildable Report:",
		"level_id=%s" % str(report.get("level_id", "unknown")),
		"mode=%s" % str(report.get("mode", DEFAULT_MODE)),
		"grid_size=%s" % str(report.get("grid_size", "")),
		"total_cells=%d" % int(report.get("total_cells", 0)),
		"path_cells=%d" % int(report.get("path_cells", 0)),
		"spawn_cells=%d" % int(report.get("spawn_cells", 0)),
		"base_cells=%d" % int(report.get("base_cells", 0)),
		"blocked_cells=%d" % int(report.get("blocked_cells", 0)),
		"obstacle_cells=%d" % int(report.get("obstacle_cells", 0)),
		"non_buildable_cells=%d" % int(report.get("non_buildable_cells", 0)),
		"final_buildable_cells=%d" % int(report.get("final_buildable_cells", 0)),
		"buildable_ratio=%.1f%%" % float(report.get("buildable_ratio", 0.0)),
		"old_buildable_count=%d" % int(report.get("old_buildable_count", 0)),
		"new_buildable_count=%d" % int(report.get("new_buildable_count", 0)),
		"can_build_preview_mismatch_count=%d" % int(report.get("can_build_preview_mismatch_count", 0)),
		"solver_candidate_count=%d" % int(report.get("solver_candidate_count", 0)),
		"disruptor_safe_sniper_cells=%d" % int(report.get("disruptor_safe_sniper_cells", 0)),
		"pass=%s" % str(report.get("pass", false))
	])

static func sort_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	return cells

static func path_map(level_data: Dictionary) -> Dictionary:
	var out := {}
	var paths = level_data.get("paths", {})
	if paths is Dictionary and not paths.is_empty():
		for path_name in paths.keys():
			out[str(path_name)] = _cells_from_array(paths[path_name])
	var legacy := _cells_from_array(level_data.get("path_cells", []))
	if not legacy.is_empty() and not out.has("default"):
		out["default"] = legacy
	if out.is_empty():
		out["default"] = []
	return out

static func unique_path_cells(level_data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	var paths := path_map(level_data)
	for path_name in paths.keys():
		for cell in paths[path_name]:
			var key := cell_key(cell)
			if not seen.has(key):
				out.append(cell)
				seen[key] = true
	return out

static func spawn_cells(level_data: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if level_data.has("spawn_cell"):
		cells.append_array(_cells_from_array([level_data.get("spawn_cell", [])]))
	cells.append_array(_cells_from_array(level_data.get("spawn_cells", [])))
	return sort_cells(_dedupe_cells(cells))

static func base_cells(level_data: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key in ["base_cell", "goal_cell", "end_cell"]:
		if level_data.has(key):
			cells.append_array(_cells_from_array([level_data.get(key, [])]))
	cells.append_array(_cells_from_array(level_data.get("base_cells", [])))
	return sort_cells(_dedupe_cells(cells))

static func inside_grid(cell: Vector2i, level_data: Dictionary) -> bool:
	var cols := int(level_data.get("grid_cols", level_data.get("grid_width", 20)))
	var rows := int(level_data.get("grid_rows", level_data.get("grid_height", 12)))
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows

static func cell_world_center(cell: Vector2i, level_data: Dictionary) -> Vector2:
	var grid_size := float(level_data.get("grid_size", 64.0))
	var origin_data = level_data.get("grid_origin", {"x": 0, "y": 0})
	var origin := Vector2.ZERO
	if origin_data is Dictionary:
		origin = Vector2(float(origin_data.get("x", 0)), float(origin_data.get("y", 0)))
	return origin + Vector2(cell.x * grid_size + grid_size / 2.0, cell.y * grid_size + grid_size / 2.0)

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _filter_valid_manual_cells(cells: Array[Vector2i], level_data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		if is_cell_buildable_static(cell, level_data):
			out.append(cell)
	return out

static func _cells_from_array(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not (raw is Array):
		return cells
	for item in raw:
		if item is Vector2i:
			cells.append(item)
		elif item is Vector2 and item != null:
			cells.append(Vector2i(int(item.x), int(item.y)))
		elif item is Array and item.size() >= 2:
			cells.append(Vector2i(int(item[0]), int(item[1])))
		elif item is Dictionary and item.has("x") and item.has("y"):
			cells.append(Vector2i(int(item.get("x")), int(item.get("y"))))
	return cells

static func _cells_from_blocking_keys(level_data: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key in BLOCKING_LIST_KEYS:
		cells.append_array(_cells_from_array(level_data.get(key, [])))
	return _dedupe_cells(cells)

static func _dedupe_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for cell in cells:
		var key := cell_key(cell)
		if not seen.has(key):
			out.append(cell)
			seen[key] = true
	return out

static func _reason_from_key(key: String) -> String:
	match key:
		"blocked_cells", "decorative_blocked_cells":
			return "blocked"
		"obstacle_cells", "static_occupied_cells":
			return "obstacle"
		"water_cells":
			return "water"
		"void_cells":
			return "void"
		"cliff_cells":
			return "cliff"
		"wall_cells":
			return "wall"
		"reserved_cells":
			return "reserved"
		"non_buildable_cells":
			return "non_buildable"
		_:
			return "blocked"

static func _collect_path_endpoint_metadata(level_data: Dictionary, out: Dictionary) -> void:
	for key in ["path_spawns", "path_spawn_cells", "path_goals", "path_goal_cells"]:
		var raw = level_data.get(key, {})
		if raw is Dictionary:
			for path_name in raw.keys():
				for cell in _cells_from_array([raw[path_name]]):
					out[cell_key(cell)] = "spawn" if key.contains("spawn") else "base"

static func _collect_terrain_forbidden(level_data: Dictionary, out: Dictionary) -> void:
	var terrain = level_data.get("terrain", {})
	if terrain is Dictionary:
		for raw_key in terrain.keys():
			var cell := _cell_from_string(str(raw_key))
			if cell == Vector2i(-99999, -99999):
				continue
			if not is_valid_terrain_for_building(cell, {"terrain": {raw_key: terrain[raw_key]}}):
				out[cell_key(cell)] = "terrain"
	var terrain_cells = level_data.get("terrain_cells", [])
	if terrain_cells is Array:
		for entry in terrain_cells:
			if entry is Dictionary and entry.has("cell"):
				var cells := _cells_from_array([entry.get("cell")])
				if cells.is_empty():
					continue
				var cell := cells[0]
				if entry.has("buildable") and not bool(entry.get("buildable", true)):
					out[cell_key(cell)] = "terrain"
				elif ["path", "water", "void", "wall", "cliff"].has(str(entry.get("type", entry.get("terrain", ""))).to_lower()):
					out[cell_key(cell)] = str(entry.get("type", entry.get("terrain", "terrain"))).to_lower()

static func _terrain_value_for_cell(cell: Vector2i, level_data: Dictionary) -> Variant:
	var terrain = level_data.get("terrain", {})
	if terrain is Dictionary:
		var key := cell_key(cell)
		if terrain.has(key):
			return terrain[key]
		var array_key := "[%d, %d]" % [cell.x, cell.y]
		if terrain.has(array_key):
			return terrain[array_key]
	var terrain_cells = level_data.get("terrain_cells", [])
	if terrain_cells is Array:
		for entry in terrain_cells:
			if entry is Dictionary and entry.has("cell"):
				var cells := _cells_from_array([entry.get("cell")])
				if not cells.is_empty() and cells[0] == cell:
					return entry
	return null

static func _cell_from_string(value: String) -> Vector2i:
	var cleaned := value.strip_edges().replace("[", "").replace("]", "").replace("(", "").replace(")", "")
	var parts := cleaned.split(",", false)
	if parts.size() < 2:
		return Vector2i(-99999, -99999)
	return Vector2i(int(parts[0]), int(parts[1]))

static func _cell_to_array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]

static func _no_overlap_with_forbidden(cells: Array[Vector2i], forbidden: Dictionary) -> bool:
	for cell in cells:
		if forbidden.has(cell_key(cell)):
			return false
	return true
