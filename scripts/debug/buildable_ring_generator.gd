extends RefCounted

const DEFAULT_RADIUS := 2
const DEFAULT_DISTANCE_MODE := "chebyshev"
const LANE_WIDTH := 64.0
const PLACEMENT_PADDING := 4.0
const DEFAULT_FOOTPRINT_RADIUS := 20.0

var buildable_radius_cells: int = DEFAULT_RADIUS
var distance_mode: String = DEFAULT_DISTANCE_MODE

func analyze_level(level_data: Dictionary, radius: int = DEFAULT_RADIUS, mode: String = DEFAULT_DISTANCE_MODE) -> Dictionary:
	buildable_radius_cells = radius
	distance_mode = mode
	var existing := _cells_from_array(level_data.get("buildable_cells", []))
	var generated := generate_ring_cells(level_data, radius, mode)
	var merged := merge_buildable_cells(level_data, generated)
	var final_cells: Array[Vector2i] = merged.get("cells", [])
	var coverage := validate_coverage(level_data, final_cells, radius, mode)
	return {
		"level_id": str(level_data.get("id", "unknown")),
		"total_path_cells": _unique_path_cells(level_data).size(),
		"existing_buildable_count": existing.size(),
		"generated_added_count": int(merged.get("added_count", 0)),
		"final_buildable_count": final_cells.size(),
		"generated_cells": _cells_to_arrays(merged.get("added_cells", [])),
		"final_buildable_cells": _cells_to_arrays(final_cells),
		"coverage": coverage,
		"pass": bool(coverage.get("pass", false))
	}

func generate_ring_cells(level_data: Dictionary, radius: int = DEFAULT_RADIUS, mode: String = DEFAULT_DISTANCE_MODE) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	var path_cells := _unique_path_cells(level_data)
	for path_cell in path_cells:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if dx == 0 and dy == 0:
					continue
				if mode == "manhattan" and abs(dx) + abs(dy) > radius:
					continue
				if mode != "manhattan" and max(abs(dx), abs(dy)) > radius:
					continue
				var candidate := path_cell + Vector2i(dx, dy)
				var key := _cell_key(candidate)
				if seen.has(key):
					continue
				if is_valid_buildable_candidate(candidate, level_data):
					out.append(candidate)
					seen[key] = true
	out.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	return out

func merge_buildable_cells(level_data: Dictionary, generated_cells: Array[Vector2i]) -> Dictionary:
	var existing := _cells_from_array(level_data.get("buildable_cells", []))
	var existing_set := _set_from_cells(existing)
	var merged_set := {}
	var merged: Array[Vector2i] = []
	var added: Array[Vector2i] = []
	for cell in existing:
		if is_valid_buildable_candidate(cell, level_data):
			var key := _cell_key(cell)
			if not merged_set.has(key):
				merged.append(cell)
				merged_set[key] = true
	for cell in generated_cells:
		if not is_valid_buildable_candidate(cell, level_data):
			continue
		var key := _cell_key(cell)
		if merged_set.has(key):
			continue
		merged.append(cell)
		merged_set[key] = true
		if not existing_set.has(key):
			added.append(cell)
	merged.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	added.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	return {
		"cells": merged,
		"added_cells": added,
		"added_count": added.size()
	}

func patch_level_data(level_data: Dictionary, radius: int = DEFAULT_RADIUS, mode: String = DEFAULT_DISTANCE_MODE) -> Dictionary:
	var patched := level_data.duplicate(true)
	var generated := generate_ring_cells(patched, radius, mode)
	var merged := merge_buildable_cells(patched, generated)
	patched["buildable_cells"] = _cells_to_arrays(merged.get("cells", []))
	return patched

func validate_coverage(level_data: Dictionary, buildable_cells: Array[Vector2i], radius: int = DEFAULT_RADIUS, mode: String = DEFAULT_DISTANCE_MODE) -> Dictionary:
	var buildable_set := _set_from_cells(buildable_cells)
	var spawn_set := _spawn_set(level_data)
	var base_set := _base_set(level_data)
	var per_path := {}
	var uncovered_r1: Array[Vector2i] = []
	var uncovered_r2: Array[Vector2i] = []
	var weak_segments: Array = []
	var blocked_reasons := {}
	for path_name in _path_map(level_data).keys():
		var cells: Array[Vector2i] = _path_map(level_data)[path_name]
		var path_uncovered: Array[Vector2i] = []
		var covered_count := 0
		var generated_near_path := 0
		for path_cell in cells:
			if spawn_set.has(_cell_key(path_cell)) or base_set.has(_cell_key(path_cell)):
				continue
			var ring_1 := _buildable_count_in_ring(path_cell, buildable_set, 1, mode)
			var ring_2 := _buildable_count_in_radius(path_cell, buildable_set, radius, mode)
			if ring_1 <= 0:
				uncovered_r1.append(path_cell)
			if ring_2 <= 0:
				uncovered_r2.append(path_cell)
				path_uncovered.append(path_cell)
				blocked_reasons[_cell_key(path_cell)] = _blocked_reasons_for_path_cell(path_cell, level_data, radius, mode)
			else:
				covered_count += 1
				generated_near_path += ring_2
			if ring_2 > 0 and ring_2 < 2:
				weak_segments.append({"path": path_name, "cell": _cell_to_array(path_cell), "options_radius_2": ring_2})
		var checked: int = max(1, cells.size() - _path_endpoint_exclusion_count(cells, spawn_set, base_set))
		per_path[path_name] = {
			"path_cell_count": cells.size(),
			"coverage_score": snappedf(float(covered_count) / float(checked), 0.001),
			"uncovered_cells": _cells_to_arrays(path_uncovered),
			"generated_buildable_count_near_this_path": generated_near_path
		}
	return {
		"pass": uncovered_r2.is_empty(),
		"uncovered_path_cells_radius_1": _cells_to_arrays(_dedupe_cells(uncovered_r1)),
		"uncovered_path_cells_radius_2": _cells_to_arrays(_dedupe_cells(uncovered_r2)),
		"weak_segments": weak_segments,
		"blocked_reasons": blocked_reasons,
		"per_path": per_path
	}

func is_valid_buildable_candidate(cell: Vector2i, level_data: Dictionary) -> bool:
	if not _inside_grid(cell, level_data):
		return false
	var key := _cell_key(cell)
	if _set_from_cells(_unique_path_cells(level_data)).has(key):
		return false
	if _spawn_set(level_data).has(key):
		return false
	if _base_set(level_data).has(key):
		return false
	if _blocked_set(level_data).has(key):
		return false
	if _overlaps_runtime_path(cell, level_data):
		return false
	return true

func format_report(report: Dictionary) -> String:
	var lines: Array[String] = [
		"Buildable Coverage Report:",
		"level_id=%s" % str(report.get("level_id", "unknown")),
		"total_path_cells=%d" % int(report.get("total_path_cells", 0)),
		"existing_buildable_count=%d" % int(report.get("existing_buildable_count", 0)),
		"generated_added_count=%d" % int(report.get("generated_added_count", 0)),
		"final_buildable_count=%d" % int(report.get("final_buildable_count", 0)),
		"pass=%s" % str(report.get("pass", false))
	]
	var coverage: Dictionary = report.get("coverage", {})
	lines.append("uncovered_radius_1=%s" % str(coverage.get("uncovered_path_cells_radius_1", [])))
	lines.append("uncovered_radius_2=%s" % str(coverage.get("uncovered_path_cells_radius_2", [])))
	lines.append("weak_segments=%s" % str(coverage.get("weak_segments", [])))
	lines.append("blocked_reasons=%s" % str(coverage.get("blocked_reasons", {})))
	lines.append("per_path=%s" % str(coverage.get("per_path", {})))
	return "\n".join(lines)

func _path_map(level_data: Dictionary) -> Dictionary:
	var out := {}
	var paths = level_data.get("paths", {})
	if paths is Dictionary and not paths.is_empty():
		for path_name in paths.keys():
			out[str(path_name)] = _cells_from_array(paths[path_name])
	if level_data.has("path_cells"):
		var legacy := _cells_from_array(level_data.get("path_cells", []))
		if not legacy.is_empty() and not out.has("default"):
			out["default"] = legacy
	if out.is_empty():
		out["default"] = []
	return out

func _unique_path_cells(level_data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for path_name in _path_map(level_data).keys():
		for cell in _path_map(level_data)[path_name]:
			var key := _cell_key(cell)
			if not seen.has(key):
				out.append(cell)
				seen[key] = true
	return out

func _cells_from_array(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not (raw is Array):
		return cells
	for item in raw:
		if item is Vector2i:
			cells.append(item)
		elif item is Array and item.size() >= 2:
			cells.append(Vector2i(int(item[0]), int(item[1])))
	return cells

func _cells_to_arrays(cells: Array) -> Array:
	var out := []
	for cell in cells:
		out.append(_cell_to_array(cell))
	return out

func _cell_to_array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]

func _set_from_cells(cells: Array[Vector2i]) -> Dictionary:
	var out := {}
	for cell in cells:
		out[_cell_key(cell)] = true
	return out

func _spawn_set(level_data: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	if level_data.has("spawn_cell"):
		cells.append_array(_cells_from_array([level_data.get("spawn_cell", [])]))
	if level_data.has("spawn_cells"):
		cells.append_array(_cells_from_array(level_data.get("spawn_cells", [])))
	return _set_from_cells(cells)

func _base_set(level_data: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	if level_data.has("base_cell"):
		cells.append_array(_cells_from_array([level_data.get("base_cell", [])]))
	if level_data.has("base_cells"):
		cells.append_array(_cells_from_array(level_data.get("base_cells", [])))
	return _set_from_cells(cells)

func _blocked_set(level_data: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	for key in ["blocked_cells", "decorative_blocked_cells", "obstacle_cells", "water_cells", "void_cells", "cliff_cells", "reserved_cells", "static_occupied_cells"]:
		cells.append_array(_cells_from_array(level_data.get(key, [])))
	return _set_from_cells(cells)

func _inside_grid(cell: Vector2i, level_data: Dictionary) -> bool:
	var cols := int(level_data.get("grid_cols", 20))
	var rows := int(level_data.get("grid_rows", 12))
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows

func _overlaps_runtime_path(cell: Vector2i, level_data: Dictionary) -> bool:
	var grid_size := float(level_data.get("grid_size", 64.0))
	var center := Vector2(cell.x * grid_size + grid_size / 2.0, cell.y * grid_size + grid_size / 2.0)
	var threshold := (LANE_WIDTH / 2.0) + DEFAULT_FOOTPRINT_RADIUS + PLACEMENT_PADDING
	for path_name in _path_map(level_data).keys():
		var cells: Array[Vector2i] = _path_map(level_data)[path_name]
		if cells.size() < 2:
			continue
		for i in range(cells.size() - 1):
			var p1 := Vector2(cells[i].x * grid_size + grid_size / 2.0, cells[i].y * grid_size + grid_size / 2.0)
			var p2 := Vector2(cells[i + 1].x * grid_size + grid_size / 2.0, cells[i + 1].y * grid_size + grid_size / 2.0)
			var closest := Geometry2D.get_closest_point_to_segment(center, p1, p2)
			if center.distance_to(closest) < threshold:
				return true
	return false

func _buildable_count_in_ring(path_cell: Vector2i, buildable_set: Dictionary, ring: int, mode: String) -> int:
	var count := 0
	for dx in range(-ring, ring + 1):
		for dy in range(-ring, ring + 1):
			if dx == 0 and dy == 0:
				continue
			var dist: int = abs(dx) + abs(dy) if mode == "manhattan" else max(abs(dx), abs(dy))
			if dist != ring:
				continue
			if buildable_set.has(_cell_key(path_cell + Vector2i(dx, dy))):
				count += 1
	return count

func _buildable_count_in_radius(path_cell: Vector2i, buildable_set: Dictionary, radius: int, mode: String) -> int:
	var count := 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if mode == "manhattan" and abs(dx) + abs(dy) > radius:
				continue
			if mode != "manhattan" and max(abs(dx), abs(dy)) > radius:
				continue
			if buildable_set.has(_cell_key(path_cell + Vector2i(dx, dy))):
				count += 1
	return count

func _blocked_reasons_for_path_cell(path_cell: Vector2i, level_data: Dictionary, radius: int, mode: String) -> Array:
	var reasons := []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if mode == "manhattan" and abs(dx) + abs(dy) > radius:
				continue
			var candidate := path_cell + Vector2i(dx, dy)
			if not _inside_grid(candidate, level_data):
				reasons.append("%s:out_of_bounds" % _cell_key(candidate))
			elif _set_from_cells(_unique_path_cells(level_data)).has(_cell_key(candidate)):
				reasons.append("%s:path" % _cell_key(candidate))
			elif _spawn_set(level_data).has(_cell_key(candidate)):
				reasons.append("%s:spawn" % _cell_key(candidate))
			elif _base_set(level_data).has(_cell_key(candidate)):
				reasons.append("%s:base" % _cell_key(candidate))
			elif _blocked_set(level_data).has(_cell_key(candidate)):
				reasons.append("%s:blocked" % _cell_key(candidate))
			elif _overlaps_runtime_path(candidate, level_data):
				reasons.append("%s:path_overlap" % _cell_key(candidate))
	return reasons

func _path_endpoint_exclusion_count(cells: Array[Vector2i], spawn_set: Dictionary, base_set: Dictionary) -> int:
	var count := 0
	for cell in cells:
		if spawn_set.has(_cell_key(cell)) or base_set.has(_cell_key(cell)):
			count += 1
	return count

func _dedupe_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for cell in cells:
		var key := _cell_key(cell)
		if not seen.has(key):
			out.append(cell)
			seen[key] = true
	out.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	return out

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
