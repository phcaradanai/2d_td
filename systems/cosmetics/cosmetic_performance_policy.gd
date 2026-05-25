extends RefCounted
class_name CosmeticPerformancePolicy

const MAX_IMPACTS_HIGH := 16
const MAX_IMPACTS_BALANCED := 10
const MAX_IMPACTS_LOW := 0
const MAX_IMPACT_SPAWNS_PER_FRAME_HIGH := 4
const MAX_IMPACT_SPAWNS_PER_FRAME_BALANCED := 2
const IMPACT_REDRAW_INTERVAL_HIGH := 0.055
const IMPACT_REDRAW_INTERVAL_BALANCED := 0.075

static func max_active_impacts(caller: Node) -> int:
	if PerformanceFirebreak.disable_all_attack_vfx:
		return 0
	match _quality_name(caller):
		"LOW":
			return MAX_IMPACTS_LOW
		"BALANCED":
			return MAX_IMPACTS_BALANCED
		_:
			return MAX_IMPACTS_HIGH

static func max_impact_spawns_per_frame(caller: Node) -> int:
	match _quality_name(caller):
		"LOW":
			return 0
		"BALANCED":
			return MAX_IMPACT_SPAWNS_PER_FRAME_BALANCED
		_:
			return MAX_IMPACT_SPAWNS_PER_FRAME_HIGH

static func impact_redraw_interval(caller: Node) -> float:
	match _quality_name(caller):
		"BALANCED":
			return IMPACT_REDRAW_INTERVAL_BALANCED
		_:
			return IMPACT_REDRAW_INTERVAL_HIGH

static func should_use_low_detail(caller: Node) -> bool:
	return _quality_name(caller) != "HIGH"

static func _quality_name(caller: Node) -> String:
	if caller == null:
		return "HIGH"
	var perf_service := caller.get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("get_quality_name"):
		return str(perf_service.get_quality_name()).to_upper()
	return "HIGH"
