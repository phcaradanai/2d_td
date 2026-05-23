## FrameSpikeLogger — debug-only per-frame spike detector with section timing.
##
## Registered as an autoload ("FrameSpikeLogger") in project.godot.
## Access via the singleton: FrameSpikeLogger.begin("name") / FrameSpikeLogger.end("name")
##
## On any frame where delta > SPIKE_THRESHOLD_MS, prints a breakdown of every
## section timed that frame. PerfOverlay reads get_section_report() every 0.25s.
extends Node

const SPIKE_THRESHOLD_MS := 20.0
const COOLDOWN_S         := 1.5

## Per-section accumulated microseconds for the current frame.
var _frame_sections: Dictionary = {}
## Snapshot of the previous completed frame's section times (us).
var _last_frame_report: Dictionary = {}
## Rolling peak time seen per section (us).
var _peak_times: Dictionary = {}

var _cooldown_remaining: float = 0.0
var total_spike_frames: int = 0

# ── API ──────────────────────────────────────────────────────────────────────

func begin(section: String) -> void:
	if not OS.is_debug_build():
		return
	_frame_sections[section + "_start"] = Time.get_ticks_usec()

func end(section: String) -> void:
	if not OS.is_debug_build():
		return
	var key := section + "_start"
	if not _frame_sections.has(key):
		return
	var elapsed_us: int = Time.get_ticks_usec() - int(_frame_sections[key])
	_frame_sections.erase(key)
	_frame_sections[section] = int(_frame_sections.get(section, 0)) + elapsed_us
	if elapsed_us > int(_peak_times.get(section, 0)):
		_peak_times[section] = elapsed_us

## Returns last frame's section times as {name: float_ms}.
func get_section_report() -> Dictionary:
	var out: Dictionary = {}
	for key in _last_frame_report:
		out[key] = float(_last_frame_report[key]) / 1000.0
	return out

## Returns all-time peak times per section as {name: float_ms}.
func get_peak_report() -> Dictionary:
	var out: Dictionary = {}
	for key in _peak_times:
		out[key] = float(_peak_times[key]) / 1000.0
	return out

# ── Node lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
	name = "FrameSpikeLogger"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process(false)

func _process(delta: float) -> void:
	_cooldown_remaining -= delta

	# Snapshot accumulated sections, then clear for next frame.
	var snapshot: Dictionary = {}
	for key in _frame_sections:
		if not key.ends_with("_start"):
			snapshot[key] = _frame_sections[key]
	_last_frame_report = snapshot
	for key in snapshot.keys():
		_frame_sections.erase(key)

	var delta_ms := delta * 1000.0
	if delta_ms >= SPIKE_THRESHOLD_MS and _cooldown_remaining <= 0.0:
		_cooldown_remaining = COOLDOWN_S
		total_spike_frames += 1
		_print_spike(delta_ms, snapshot)

func _print_spike(delta_ms: float, sections: Dictionary) -> void:
	var fps        := Engine.get_frames_per_second()
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var vfx_active := _count_active_vfx()

	print("[SPIKE #%d] delta=%.1fms  fps=%d  nodes=%d  draws=%d  vfx_active=%d" % [
		total_spike_frames, delta_ms, fps, node_count, draw_calls, vfx_active
	])

func _count_active_vfx() -> int:
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool == null:
		return get_tree().get_nodes_in_group("attack_vfx").size()
	var total := 0
	var active_by_key: Dictionary = pool.get("_active_by_key") if pool.get("_active_by_key") != null else {}
	for key in active_by_key:
		total += (active_by_key[key] as Array).size()
	return total

	if sections.is_empty():
		print("  (no sections timed this frame)")
		return

	var pairs: Array = []
	for key in sections:
		pairs.append([key, int(sections[key])])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])

	var total_us: int = 0
	for pair in pairs:
		total_us += int(pair[1])

	print("  ── Section breakdown ──────────────────────────────────────")
	for pair in pairs:
		var sec_name: String = pair[0]
		var us: int          = pair[1]
		var pct: float       = 100.0 * float(us) / maxf(float(total_us), 1.0)
		var peak_us: int     = int(_peak_times.get(sec_name, us))
		print("  %-36s  %6.2f ms  %5.1f%%  peak=%6.2f ms" % [
			sec_name, float(us) / 1000.0, pct, float(peak_us) / 1000.0
		])
	print("  ── Total timed: %.2f ms  /  frame: %.2f ms ────────────────" % [
		float(total_us) / 1000.0, delta_ms
	])
