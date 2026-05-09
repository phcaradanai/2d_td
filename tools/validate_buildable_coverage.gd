extends SceneTree

const GENERATOR_SCRIPT := preload("res://scripts/debug/buildable_ring_generator.gd")
const LEVEL_DIR := "res://data/levels"

var generator = GENERATOR_SCRIPT.new()
var mode := "--check"
var failed := false

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg in ["--check", "--preview", "--apply"]:
			mode = arg
	if args.is_empty():
		for arg in OS.get_cmdline_args():
			if arg in ["--check", "--preview", "--apply"]:
				mode = arg
	print("[BUILDABLE_COVERAGE_VALIDATION] mode=%s" % mode)
	for i in range(1, 21):
		_process_level("res://data/levels/level_%02d.json" % i)
	print("[BUILDABLE_COVERAGE_VALIDATION] ok=%s" % str(not failed))
	quit(1 if failed else 0)

func _process_level(path: String) -> void:
	var level_data = _load_json(path)
	if not (level_data is Dictionary):
		failed = true
		print("%s FAIL load_error" % path)
		return
	var report: Dictionary = generator.analyze_level(level_data)
	var coverage: Dictionary = report.get("coverage", {})
	var uncovered: Array = coverage.get("uncovered_path_cells_radius_2", [])
	var status := "PASS" if bool(report.get("pass", false)) else "FAIL"
	if status == "FAIL":
		failed = true
	print("%s %s path_cells=%d existing_buildable=%d added=%d final_buildable=%d uncovered_radius2=%d" % [
		str(report.get("level_id", path.get_file().get_basename())),
		status,
		int(report.get("total_path_cells", 0)),
		int(report.get("existing_buildable_count", 0)),
		int(report.get("generated_added_count", 0)),
		int(report.get("final_buildable_count", 0)),
		uncovered.size()
	])
	if mode == "--preview":
		print("  added=%s" % str(report.get("generated_cells", [])))
	if not uncovered.is_empty():
		print("  uncovered=%s" % str(uncovered))
		print("  blocked_reasons=%s" % str(coverage.get("blocked_reasons", {})))
	if mode == "--apply":
		var patched: Dictionary = generator.patch_level_data(level_data)
		var patched_report: Dictionary = generator.analyze_level(patched)
		var ok := _write_json(path, patched)
		if not ok or not bool(patched_report.get("pass", false)):
			failed = true
			print("  apply=FAIL write_ok=%s pass_after_patch=%s" % [str(ok), str(patched_report.get("pass", false))])
		else:
			print("  apply=OK final_buildable=%d" % int(patched_report.get("final_buildable_count", 0)))

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data

func _write_json(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return true
