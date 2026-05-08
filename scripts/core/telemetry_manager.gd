extends Node

# Telemetry Manager
# Records session data for production QA and post-level balance reports.

const TELEMETRY_DIR = "user://telemetry/"

var current_level_id: String = ""
var start_time: int = 0
var towers_built: Dictionary = {}
var total_gold_earned: int = 0
var total_gold_spent: int = 0
var total_enemies_killed: int = 0
var total_enemies_leaked: int = 0
var wave_stats: Array = []

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(TELEMETRY_DIR):
		DirAccess.make_dir_recursive_absolute(TELEMETRY_DIR)

func start_level(level_id: String, starting_gold: int) -> void:
	current_level_id = level_id
	start_time = Time.get_ticks_msec()
	towers_built.clear()
	total_gold_earned = starting_gold
	total_gold_spent = 0
	total_enemies_killed = 0
	total_enemies_leaked = 0
	wave_stats.clear()
	if OS.is_debug_build():
		print("[Telemetry] Started recording for %s" % level_id)

func record_gold_earned(amount: int) -> void:
	total_gold_earned += amount

func record_gold_spent(amount: int) -> void:
	total_gold_spent += amount

func record_tower_built(type: String, cost: int) -> void:
	if not towers_built.has(type):
		towers_built[type] = 0
	towers_built[type] += 1
	record_gold_spent(cost)

func record_wave_stats(wave_num: int, killed: int, leaked: int, duration_sec: float) -> void:
	total_enemies_killed += killed
	total_enemies_leaked += leaked
	wave_stats.append({
		"wave": wave_num,
		"killed": killed,
		"leaked": leaked,
		"duration": duration_sec
	})

func end_level(victory: bool, final_score: int) -> Dictionary:
	var end_time = Time.get_ticks_msec()
	var duration_sec = (end_time - start_time) / 1000.0
	var gold_efficiency = 0.0
	if total_gold_earned > 0:
		gold_efficiency = float(total_gold_spent) / float(total_gold_earned)
		
	var report = {
		"level_id": current_level_id,
		"victory": victory,
		"score": final_score,
		"duration_sec": duration_sec,
		"gold_earned": total_gold_earned,
		"gold_spent": total_gold_spent,
		"gold_efficiency": gold_efficiency,
		"enemies_killed": total_enemies_killed,
		"enemies_leaked": total_enemies_leaked,
		"towers_built": towers_built,
		"waves": wave_stats,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	_save_report(report)
	return report

func _save_report(report: Dictionary) -> void:
	var filename = TELEMETRY_DIR + current_level_id + "_" + str(Time.get_unix_time_from_system()) + ".json"
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var json = JSON.new()
		file.store_string(json.stringify(report, "\t"))
		file.close()
		if OS.is_debug_build():
			print("[Telemetry] Saved report to %s" % filename)
	else:
		push_error("[Telemetry] Failed to save report to %s" % filename)
