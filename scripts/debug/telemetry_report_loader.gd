extends RefCounted
class_name TelemetryReportLoader

const TELEMETRY_DIR := "user://telemetry/"
const DEBUG_ACCESS_SCRIPT := preload("res://scripts/debug/debug_access.gd")

func list_reports(level_id: String = "") -> Array[String]:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("List Balance Reports"):
		return []
	var reports: Array[String] = []
	var dir := DirAccess.open(TELEMETRY_DIR)
	if dir == null:
		return reports

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			if level_id == "" or file_name.begins_with(level_id + "_"):
				reports.append(TELEMETRY_DIR + file_name)
		file_name = dir.get_next()
	reports.sort()
	return reports

func load_report(path: String) -> Dictionary:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Load Balance Report"):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func load_reports_for_level(level_id: String) -> Array[Dictionary]:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Load Balance Reports For Level"):
		return []
	var reports: Array[Dictionary] = []
	for path in list_reports(level_id):
		var report := load_report(path)
		if not report.is_empty():
			reports.append(report)
	return reports

func get_latest_report(level_id: String) -> Dictionary:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Load Latest Balance Report"):
		return {}
	var reports := load_reports_for_level(level_id)
	if reports.is_empty():
		return {}

	reports.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := int(a.get("ended_at_msec", a.get("started_at_msec", 0)))
		var b_time := int(b.get("ended_at_msec", b.get("started_at_msec", 0)))
		if a_time == b_time:
			return str(a.get("timestamp", "")) < str(b.get("timestamp", ""))
		return a_time < b_time
	)
	return reports[reports.size() - 1]

func analyze_reports(level_id: String) -> Dictionary:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Telemetry Aggregate"):
		return {
			"level_id": level_id,
			"source_reports_count": 0,
			"difficulty_rating": "Blocked",
			"dominant_strategy_risk": false
		}
	var reports := load_reports_for_level(level_id)
	if reports.is_empty():
		return {
			"level_id": level_id,
			"source_reports_count": 0,
			"difficulty_rating": "Unknown",
			"dominant_strategy_risk": false
		}

	var stats := {
		"level_id": level_id,
		"source_reports_count": reports.size(),
		"victories": 0,
		"perfects": 0,
		"hero_runs": 0,
		"total_gold_remaining_ratio": 0.0,
		"total_tower_dominance_ratio": 0.0,
		"total_tower_variety_count": 0.0,
		"total_tower_count": 0.0,
		"total_leaks": 0,
		"tower_dominance_counts": {},
		"difficulty_counts": {},
		"latest_report": reports[reports.size() - 1]
	}

	for report in reports:
		if str(report.get("result", "")).to_lower() == "victory":
			stats["victories"] += 1
		if bool(report.get("perfect_clear", false)):
			stats["perfects"] += 1
		if int(report.get("hero_deploy_count", 0)) > 0:
			stats["hero_runs"] += 1
		stats["total_leaks"] += int(report.get("enemies_leaked_total", 0))

		var analysis: Dictionary = report.get("balance_analysis", {})
		var total_available := float(report.get("gold_start", 0) + report.get("gold_earned_total", 0))
		var gold_remaining_ratio := float(analysis.get("gold_remaining_ratio", 0.0))
		if gold_remaining_ratio <= 0.0 and total_available > 0.0:
			gold_remaining_ratio = float(report.get("gold_remaining", 0)) / total_available

		stats["total_gold_remaining_ratio"] += gold_remaining_ratio
		stats["total_tower_dominance_ratio"] += float(analysis.get("tower_dominance_ratio", _calculate_tower_dominance_ratio(report)))
		stats["total_tower_variety_count"] += float(analysis.get("tower_variety_count", report.get("tower_build_count_by_type", {}).size()))
		stats["total_tower_count"] += float(analysis.get("tower_total_count", _sum_values(report.get("tower_build_count_by_type", {}))))
		_increment(stats["tower_dominance_counts"], str(analysis.get("tower_dominance", _top_key(report.get("damage_by_tower_type", {})))))
		_increment(stats["difficulty_counts"], str(analysis.get("difficulty_rating", "Unknown")))

	var runs := float(reports.size())
	var avg_gold_remaining_ratio := float(stats["total_gold_remaining_ratio"]) / runs
	var avg_tower_dominance_ratio := float(stats["total_tower_dominance_ratio"]) / runs
	var avg_tower_variety_count := float(stats["total_tower_variety_count"]) / runs
	var avg_tower_count := float(stats["total_tower_count"]) / runs
	var victory_rate := float(stats["victories"]) / runs
	var perfect_rate := float(stats["perfects"]) / runs
	var hero_used_rate := float(stats["hero_runs"]) / runs
	var top_tower := _top_key(stats["tower_dominance_counts"])
	var rating := _top_key(stats["difficulty_counts"])
	if rating == "Unknown":
		if avg_gold_remaining_ratio > 0.40:
			rating = "Too Easy"
		elif avg_gold_remaining_ratio > 0.25:
			rating = "Slightly Easy"
		elif victory_rate < 0.50:
			rating = "Too Hard"
		else:
			rating = "Good"

	var dominant_risk := false
	if victory_rate > 0.0:
		dominant_risk = avg_tower_dominance_ratio > 0.75 or avg_tower_variety_count <= 1.0 or avg_tower_count <= 2.0

	return {
		"level_id": level_id,
		"source_reports_count": reports.size(),
		"difficulty_rating": rating,
		"dominant_strategy_risk": dominant_risk,
		"gold_remaining_ratio": avg_gold_remaining_ratio,
		"tower_dominance": top_tower,
		"tower_dominance_ratio": avg_tower_dominance_ratio,
		"tower_variety_count": avg_tower_variety_count,
		"tower_total_count": avg_tower_count,
		"hero_used_rate": hero_used_rate,
		"victory_rate": victory_rate,
		"perfect_rate": perfect_rate,
		"avg_leaks": float(stats["total_leaks"]) / runs,
		"latest_report": stats["latest_report"]
	}

func _calculate_tower_dominance_ratio(report: Dictionary) -> float:
	var damage: Dictionary = report.get("damage_by_tower_type", {})
	var total := 0.0
	var max_damage := 0.0
	for key in damage:
		var amount := float(damage[key])
		total += amount
		max_damage = max(max_damage, amount)
	if total <= 0.0:
		return 0.0
	return max_damage / total

func _sum_values(values: Dictionary) -> int:
	var total := 0
	for key in values:
		total += int(values[key])
	return total

func _top_key(values: Dictionary) -> String:
	var top := "None"
	var best := -INF
	for key in values:
		var amount := float(values[key])
		if amount > best:
			best = amount
			top = str(key)
	return top

func _increment(values: Dictionary, key: String, amount: float = 1.0) -> void:
	if not values.has(key):
		values[key] = 0.0
	values[key] += amount
