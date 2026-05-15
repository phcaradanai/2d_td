extends RefCounted

const PATCH_DIR := "user://balance_patches/"
const BACKUP_DIR := "user://balance_backups/"
const LEVELS_DIR := "res://data/levels/"
const ENEMIES_PATH := "res://data/enemies.json"
const TOWERS_PATH := "res://data/towers_tree.json"
const SOLVER_SCRIPT := "res://scripts/debug/balance_solver.gd"
const DEBUG_ACCESS_SCRIPT := preload("res://scripts/debug/debug_access.gd")
const PATCH_STATUS_ACCEPTED := "accepted"
const PATCH_STATUS_REJECTED_NO_DATA_CHANGE := "rejected_no_data_change"
const PATCH_STATUS_REJECTED_DOMINANT_STRATEGY_STILL_CLEARS := "rejected_dominant_strategy_still_clears"
const PATCH_STATUS_REJECTED_MIXED_DEFENSE_FAILED := "rejected_mixed_defense_failed"
const PATCH_STATUS_REJECTED_FILE_VERIFY_FAILED := "rejected_file_verify_failed"
const PATCH_STATUS_NEEDS_SOFTENING := "needs_softening"
const PATCH_SEARCH_MAX_ATTEMPTS := 5

const THREAT_SCORES := {
	"basic": 1.0,
	"fast": 1.2,
	"tank": 2.5,
	"bulwark": 6.5,
	"hunter": 3.5,
	"swarm": 0.4,
	"runner": 1.5,
	"shieldbearer": 3.0,
	"healer": 3.5,
	"splitter": 4.5,
	"cloaked": 2.2,
	"flyer": 1.5,
	"fast_flyer": 2.0,
	"armored_flyer": 4.5,
	"disruptor": 5.0
}

const ENEMY_ROLES := {
	"bulwark": ["frontliner", "tank", "punishment"],
	"armored_flyer": ["frontliner", "tank", "durability"],
	"tank": ["frontliner", "tank", "durability"],
	"healer": ["support"],
	"shieldbearer": ["support"],
	"disruptor": ["support", "disruption"],
	"fast": ["pressure"],
	"swarm": ["pressure"],
	"runner": ["pressure"],
	"flyer": ["pressure"],
	"fast_flyer": ["pressure"],
	"cloaked": ["disruption"],
	"splitter": ["durability", "punishment"],
	"hunter": ["punishment"],
	"basic": ["filler"]
}

const WAVE_TEMPLATES := {
	"early": {
		"min_roles": 2,
		"max_roles": 3,
		"synergy_weight": 0.2,
		"allowed_roles": ["frontliner", "pressure", "filler"]
	},
	"mid": {
		"min_roles": 3,
		"max_roles": 3,
		"synergy_weight": 0.5,
		"allowed_roles": ["frontliner", "support", "pressure", "durability"]
	},
	"late": {
		"min_roles": 3,
		"max_roles": 5,
		"synergy_weight": 0.8,
		"allowed_roles": ["frontliner", "support", "pressure", "disruption", "durability"]
	},
	"final": {
		"min_roles": 4,
		"max_roles": 6,
		"synergy_weight": 1.0,
		"allowed_roles": ["frontliner", "support", "pressure", "disruption", "durability", "punishment"]
	}
}

const ROLE_SYNERGY := {
	"frontliner": ["support"],
	"tank": ["support", "disruption"],
	"support": ["frontliner", "tank"],
	"disruption": ["pressure", "frontliner"],
	"pressure": ["disruption"],
	"durability": ["support"]
}

var last_saved_patch_path: String = ""
var last_backup_manifest_path: String = ""
var last_error: String = ""
var last_operation_log: String = ""
var last_runtime_patch_hash: int = 0
var last_runtime_patch_signature: int = 0
var last_runtime_level_id: String = ""
var last_runtime_wave_data: Array = []
var last_stage_2_patch: Dictionary = {}
var last_softened_patch: Dictionary = {}
var last_patch_acceptance: Dictionary = {}
var file_patch_signatures: Dictionary = {}
var runtime_original_baselines: Dictionary = {}
var file_original_baselines: Dictionary = {}

func _balance_tool_blocked(action: String, lines: Array[String] = []) -> bool:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool(action):
		if not lines.is_empty():
			_fail_operation("Balance tool blocked: %s is not allowed in this build." % action, lines)
		else:
			last_error = "Balance tool blocked: %s is not allowed in this build." % action
			last_operation_log = last_error
		return true
	return false

func generate_patch(level_id: String, aggregate: Dictionary, latest_report: Dictionary) -> Dictionary:
	if _balance_tool_blocked("Generate Balance Patch"):
		return {}
	last_error = ""
	var source_count := int(aggregate.get("source_reports_count", 1))
	var report_analysis: Dictionary = latest_report.get("balance_analysis", {})
	var source := report_analysis if source_count <= 0 else aggregate
	var gold_remaining_ratio := float(source.get("gold_remaining_ratio", report_analysis.get("gold_remaining_ratio", 0.0)))
	var tower_dominance := str(source.get("tower_dominance", report_analysis.get("tower_dominance", "None"))).replace("_tower", "")
	var tower_dominance_ratio := float(source.get("tower_dominance_ratio", report_analysis.get("tower_dominance_ratio", 0.0)))
	var tower_variety_count := int(round(float(source.get("tower_variety_count", report_analysis.get("tower_variety_count", 0)))))
	var tower_total_count := int(round(float(source.get("tower_total_count", report_analysis.get("tower_total_count", 0)))))
	var victory := str(latest_report.get("result", "")).to_lower() == "victory"
	var dominant_risk := bool(source.get("dominant_strategy_risk", report_analysis.get("dominant_strategy_risk", false)))
	var proposed_changes: Array[Dictionary] = []
	var risk_label := "normal"

	# High remaining gold suggests the wave budget is too low or rewards too high
	if gold_remaining_ratio > 0.35:
		proposed_changes.append({
			"type": "formation_adjustment",
			"target_waves": "all",
			"formation_policy": "auto_tactical",
			"reason": "Improve formation pressure before changing enemy counts"
		})
		proposed_changes.append({
			"type": "lane_timing_adjustment",
			"target_waves": "multi_lane",
			"flank_offset": 0.35,
			"reason": "Coordinate lane pressure while keeping density high"
		})
		proposed_changes.append({
			"type": "threat_budget_adjustment",
			"target_waves": "all",
			"budget_multiplier": clampf(1.0 + (gold_remaining_ratio - 0.25) * 0.5, 1.1, 1.4),
			"reason": "High remaining gold; increasing wave intensity"
		})
		proposed_changes.append({
			"type": "reward_multiplier",
			"target": level_id,
			"kill_reward_multiplier": 0.85,
			"wave_reward_multiplier": 0.90,
			"reason": "Tuning economy for high gold"
		})

	# Handle dominant tower types with role-based counters
	if tower_dominance != "None" and tower_dominance_ratio > 0.65:
		proposed_changes.append({
			"type": "spawn_order_adjustment",
			"dominant_tower": tower_dominance,
			"target_waves": "mid_to_late",
			"reason": "Use tactical ordering and protected priority targets before stat/count changes"
		})
		proposed_changes.append({
			"type": "counter_role_adjustment",
			"dominant_tower": tower_dominance,
			"target_waves": "mid_to_late",
			"reason": "Countering dominant %s usage with specific role pressure" % tower_dominance
		})

	if victory and (tower_variety_count <= 1 or tower_total_count <= 2):
		dominant_risk = true
		risk_label = "critical"
		proposed_changes.append({
			"type": "dominant_strategy_test_required",
			"strategy": "solo_%s_only" % tower_dominance,
			"expected_result": "fail_or_leak"
		})

	if level_id == "level_20":
		proposed_changes.append({
			"type": "composition_synergy_boost",
			"target_waves": [4, 5],
			"min_roles": 5,
			"reason": "Ensure final level has maximum synergy and diversity"
		})

	return {
		"level_id": level_id,
		"created_at": Time.get_datetime_string_from_system(),
		"patch_stage": 1,
		"source_reports_count": source_count,
		"diagnosis": {
			"difficulty_rating": str(source.get("difficulty_rating", report_analysis.get("difficulty_rating", "Unknown"))),
			"dominant_strategy_risk": dominant_risk,
			"dominant_strategy_risk_level": risk_label if dominant_risk else "normal",
			"gold_remaining_ratio": gold_remaining_ratio,
			"tower_dominance": tower_dominance,
			"tower_dominance_ratio": tower_dominance_ratio,
			"tower_variety_count": tower_variety_count,
			"tower_total_count": tower_total_count,
			"is_boring": gold_remaining_ratio > 0.45 or tower_variety_count < 2
		},
		"proposed_changes": proposed_changes,
		"apply_mode": "preview_only"
	}

func generate_stage_2_patch(base_patch: Dictionary) -> Dictionary:
	if _balance_tool_blocked("Generate Stage 2 Balance Patch"):
		return {}
	var patch := base_patch.duplicate(true)
	patch["patch_stage"] = 2
	patch["created_at"] = Time.get_datetime_string_from_system()
	patch["escalation_reason"] = "dominant strategy still clears"
	var changes: Array[Dictionary] = []
	changes.append({
		"type": "reward_multiplier",
		"target": str(patch.get("level_id", "")),
		"kill_reward_multiplier": 0.65,
		"wave_reward_multiplier": 0.75,
		"reason": "Stage 2: force tighter economy"
	})
	changes.append({"type": "wave_spacing_adjustment", "target_wave": 3, "spacing_multiplier": 1.35, "reason": "Stage 2: reduce chain efficiency"})
	changes.append({"type": "wave_spacing_adjustment", "target_wave": 5, "spacing_multiplier": 1.35, "reason": "Stage 2: reduce chain efficiency"})
	changes.append({
		"type": "wave_composition_adjustment",
		"target_wave": 4,
		"add_existing_enemy_pressure": ["fast_flyer", "hunter"],
		"count_per_type": 10,
		"reason": "Stage 2: increase fast/hunter pressure"
	})
	changes.append({
		"type": "wave_composition_adjustment",
		"target_wave": 5,
		"add_existing_enemy_pressure": ["armored_flyer", "bulwark"],
		"count_per_type": 6,
		"reason": "Stage 2: increase armored/bulwark pressure"
	})
	changes.append({
		"type": "economy_gate",
		"target_wave": 1,
		"reward_multiplier": 0.60,
		"reason": "Delay second Lightning L3 timing"
	})
	changes.append({
		"type": "tower_upgrade_cost_adjustment",
		"tower": "lightning_tower",
		"level": 3,
		"upgrade_cost_multiplier": 1.15,
		"test_patch_only": true,
		"reason": "Optional test-only Lightning L3 timing pressure"
	})
	changes.append({
		"type": "dominant_strategy_test_required",
		"strategy": "2x_lightning_l3_only",
		"expected_result": "fail_or_leak"
	})
	patch["proposed_changes"] = changes
	last_stage_2_patch = patch
	return patch

func generate_softened_patch(base_patch: Dictionary) -> Dictionary:
	if _balance_tool_blocked("Generate Softened Balance Patch"):
		return {}
	var patch: Dictionary = base_patch.duplicate(true)
	var changes: Array[Dictionary] = []
	patch["patch_stage"] = int(patch.get("patch_stage", 1)) + 1
	patch["softening_reason"] = "mixed defense failed"
	
	for change in patch.get("proposed_changes", []):
		var softened: Dictionary = (change as Dictionary).duplicate(true)
		match str(softened.get("type", "")):
			"reward_multiplier":
				softened["kill_reward_multiplier"] = max(float(softened.get("kill_reward_multiplier", 1.0)), 0.85)
				softened["wave_reward_multiplier"] = max(float(softened.get("wave_reward_multiplier", 1.0)), 0.90)
				changes.append(softened)
			"threat_budget_adjustment":
				var mult := float(softened.get("budget_multiplier", 1.0))
				softened["budget_multiplier"] = 1.0 + (mult - 1.0) * 0.7
				changes.append(softened)
			"counter_role_adjustment":
				changes.append(softened)
			"composition_synergy_boost":
				var roles := int(softened.get("min_roles", 4))
				softened["min_roles"] = max(2, roles - 1)
				changes.append(softened)
			"dominant_strategy_test_required":
				changes.append(softened)
			"tower_upgrade_cost_adjustment":
				changes.append(softened)
			"hero_opportunity_moment":
				changes.append(softened)
			_:
				changes.append(softened)
				
	patch["proposed_changes"] = changes
	last_softened_patch = patch
	return patch

func format_softening(old_patch: Dictionary, new_patch: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[BALANCE_PATCH_SOFTEN]")
	lines.append("reason=%s" % str(new_patch.get("softening_reason", "unknown")))
	lines.append("old_stage=%s" % str(old_patch.get("patch_stage", 1)))
	lines.append("new_stage=%s" % str(new_patch.get("patch_stage", 2)))
	lines.append("changes:")
	
	var old_changes: Array = old_patch.get("proposed_changes", [])
	var new_changes: Array = new_patch.get("proposed_changes", [])
	
	for i in range(min(old_changes.size(), new_changes.size())):
		var oc: Dictionary = old_changes[i]
		var nc: Dictionary = new_changes[i]
		match str(oc.get("type", "")):
			"reward_multiplier":
				lines.append("- kill rewards %.2f -> %.2f" % [float(oc.get("kill_reward_multiplier", 1.0)), float(nc.get("kill_reward_multiplier", 1.0))])
				lines.append("- wave rewards %.2f -> %.2f" % [float(oc.get("wave_reward_multiplier", 1.0)), float(nc.get("wave_reward_multiplier", 1.0))])
			"threat_budget_adjustment":
				lines.append("- budget multiplier %.2f -> %.2f" % [float(oc.get("budget_multiplier", 1.0)), float(nc.get("budget_multiplier", 1.0))])
			"composition_synergy_boost":
				lines.append("- min roles %d -> %d" % [int(oc.get("min_roles", 0)), int(nc.get("min_roles", 0))])
				
	return "\n".join(lines)

func preview_patch(patch: Dictionary) -> String:
	if _balance_tool_blocked("Preview Balance Patch"):
		return last_operation_log
	if patch.is_empty():
		return "[BALANCE_PATCH_PREVIEW]\nNo patch generated."

	var diagnosis: Dictionary = patch.get("diagnosis", {})
	var lines: Array[String] = []
	lines.append("[BALANCE_PATCH_PREVIEW]")
	lines.append("level=%s" % str(patch.get("level_id", "unknown")))
	lines.append("stage=%s" % str(patch.get("patch_stage", 1)))
	lines.append("source_reports=%d" % int(patch.get("source_reports_count", 0)))
	var risk := str(diagnosis.get("dominant_strategy_risk_level", "normal"))
	lines.append("risk=%s%s" % [risk, " dominant strategy" if bool(diagnosis.get("dominant_strategy_risk", false)) else ""])
	lines.append("changes:")

	for change in patch.get("proposed_changes", []):
		match str(change.get("type", "")):
			"reward_multiplier":
				lines.append("- reduce kill rewards by %d%%" % int(round((1.0 - float(change.get("kill_reward_multiplier", 1.0))) * 100.0)))
				lines.append("- reduce wave rewards by %d%%" % int(round((1.0 - float(change.get("wave_reward_multiplier", 1.0))) * 100.0)))
			"threat_budget_adjustment":
				lines.append("- increase wave threat budget by %d%% (%s)" % [
					int(round((float(change.get("budget_multiplier", 1.0)) - 1.0) * 100.0)),
					str(change.get("target_waves", "all"))
				])
			"counter_role_adjustment":
				lines.append("- apply counter-role pressure against %s (%s)" % [
					str(change.get("dominant_tower", "dominant towers")),
					str(change.get("target_waves", "all"))
				])
			"formation_adjustment":
				lines.append("- enable formation-aware tactical scheduling (%s)" % str(change.get("target_waves", "all")))
			"spawn_order_adjustment":
				lines.append("- reorder spawn pressure against %s without reducing count" % str(change.get("dominant_tower", "dominant towers")))
			"lane_timing_adjustment":
				lines.append("- synchronize multi-lane pressure with %.2fs flank offset" % float(change.get("flank_offset", 0.35)))
			"composition_synergy_boost":
				lines.append("- boost composition synergy and role mix (%s)" % str(change.get("target_waves", "all")))
			"economy_gate":
				lines.append("- reduce wave %d reward by %d%% to delay early economy" % [
					int(change.get("target_wave", 0)),
					int(round((1.0 - float(change.get("reward_multiplier", 1.0))) * 100.0))
				])
			"tower_upgrade_cost_adjustment":
				lines.append("- test-only %s L%d upgrade cost +%d%%" % [
					str(change.get("tower", "")),
					int(change.get("level", 0)),
					int(round((float(change.get("upgrade_cost_multiplier", 1.0)) - 1.0) * 100.0))
				])
			"dominant_strategy_test_required":
				lines.append("- require %s strategy test" % str(change.get("strategy", "dominant")))
			"hero_opportunity_moment":
				lines.append("- add optional hero opportunity intel in wave %d" % int(change.get("target_wave", 0)))

	lines.append("")
	lines.append("Expected effect:")
	lines.append("- denser, more challenging waves")
	lines.append("- counter-pressure for dominant %s usage" % str(diagnosis.get("tower_dominance", "tower")))
	lines.append("- forced tower diversity through role mix")
	lines.append("")
	lines.append("Warnings:")
	lines.append("- no production data changed yet")
	return "\n".join(lines)

func save_patch(patch: Dictionary) -> String:
	last_error = ""
	if _balance_tool_blocked("Save Balance Patch"):
		return ""
	if patch.is_empty():
		last_error = "Cannot save empty patch."
		return ""
	_ensure_dir(PATCH_DIR)
	var level_id := str(patch.get("level_id", "unknown"))
	var path := "%s%s_patch_%d.json" % [PATCH_DIR, level_id, Time.get_unix_time_from_system()]
	if not _write_json(path, patch):
		return ""
	last_saved_patch_path = path
	return path

func apply_runtime_patch(patch: Dictionary, wave_manager: Node) -> bool:
	last_error = ""
	var lines: Array[String] = []
	if _balance_tool_blocked("Apply Runtime Patch", lines):
		return false
	if wave_manager == null:
		return _fail_operation("WaveManager is missing.", lines)
	if bool(wave_manager.get("is_wave_running")):
		return _fail_operation("Stop the active wave before applying a runtime patch.", lines)

	var level_id := str(patch.get("level_id", ""))
	var enemies = _load_json(ENEMIES_PATH)
	if not (enemies is Dictionary):
		return _fail_operation("Enemy data could not be loaded.", lines)

	var source_path := str(wave_manager.get("waves_data_path"))
	var live_waves: Array = (wave_manager.get("waves") as Array).duplicate(true)
	if not runtime_original_baselines.has(level_id):
		runtime_original_baselines[level_id] = live_waves.duplicate(true)
	var baseline_waves: Array = (runtime_original_baselines[level_id] as Array).duplicate(true)
	var before_hash := wave_data_hash(live_waves)
	var patch_signature := _patch_signature(patch)
	var patch_path := _save_patch_for_apply(patch)
	var target := _format_target(level_id, "runtime", source_path, patch_path, "")
	lines.append(target)
	lines.append("[BALANCE_PATCH_BASELINE]\nmode=runtime\nsource=%s" % ("original_runtime_snapshot" if wave_data_hash(baseline_waves) != before_hash else "current_wave_manager"))
	lines.append("[WAVE_DATA_CACHE]\nloader=FileAccess\ncache_bypassed=true")

	if patch_signature == last_runtime_patch_signature and before_hash == last_runtime_patch_hash:
		lines.append("[BALANCE_PATCH_ALREADY_APPLIED]")
		last_operation_log = "\n".join(lines)
		last_error = "Duplicate runtime patch rejected."
		return false

	var patched_waves := _apply_changes_to_waves(baseline_waves.duplicate(true), patch, enemies)
	var after_hash := wave_data_hash(patched_waves)
	lines.append(_format_hash(before_hash, after_hash))

	var diff := build_patch_diff(level_id, live_waves, patched_waves, enemies)
	lines.append(format_patch_diff(level_id, diff))
	if not bool(diff.get("changed", false)) or before_hash == after_hash:
		var acceptance := _evaluate_patch_acceptance(false, false, false, false)
		lines.append(_format_acceptance(acceptance))
		lines.append("[BALANCE_PATCH_NOOP]\nPatch applied but level data did not change.")
		last_operation_log = "\n".join(lines)
		last_error = "Runtime patch was a no-op."
		last_patch_acceptance = acceptance
		return false

	var validation := _validate_waves(level_id, patched_waves, enemies)
	if not bool(validation.get("ok", false)):
		return _fail_operation(str(validation.get("reason", "Runtime validation failed.")), lines)

	var reload_before_hash := before_hash
	var reload_ok := false
	if wave_manager.has_method("apply_runtime_wave_data"):
		reload_ok = bool(wave_manager.apply_runtime_wave_data(level_id, patched_waves, after_hash))
	else:
		wave_manager.set("waves", patched_waves.duplicate(true))
		if wave_manager.has_method("reset_waves"):
			wave_manager.reset_waves()
		reload_ok = true
	var live_hash := wave_data_hash(wave_manager.get("waves") as Array)
	lines.append("[WAVE_DATA_RELOAD]\nlevel=%s\nsource=runtime_patch\nwaves=%d\nhash_before=%s\nhash_after=%s\nchanged=%s" % [
		level_id,
		(wave_manager.get("waves") as Array).size(),
		str(reload_before_hash),
		str(live_hash),
		str(reload_before_hash != live_hash)
	])
	if not reload_ok or live_hash != after_hash:
		return _fail_operation("WaveManager reload verification failed.", lines)

	_clear_live_test_nodes(wave_manager)
	_refresh_runtime_hud(wave_manager)
	last_runtime_patch_signature = patch_signature
	last_runtime_patch_hash = after_hash
	last_runtime_level_id = level_id
	last_runtime_wave_data = patched_waves.duplicate(true)

	var dominant := run_dominant_strategy_test(level_id, patch, wave_manager)
	lines.append(dominant)
	var dominant_pass := _dominant_strategy_passed(dominant)
	if not dominant_pass:
		var acceptance := _evaluate_patch_acceptance(true, dominant_pass, false, false)
		lines.append(_format_acceptance(acceptance))
		lines.append(_format_escalation(generate_stage_2_patch(patch)))
		lines.append("[BALANCE_PATCH_RUNTIME]\napplied=false\ndata_changed=true\nreason=dominant_strategy_still_clears")
		lines.append("[BALANCE_PATCH_NOT_COMMITTED]\nreason=dominant_strategy_still_clears")
		last_patch_acceptance = acceptance
		last_operation_log = "\n".join(lines)
		last_error = "Dominant strategy still clears. Generate/apply Stage 2 patch."
		return false

	var mixed := run_mixed_defense_test(level_id, patch, wave_manager)
	lines.append(mixed)
	var mixed_pass := _mixed_defense_passed(mixed)
	var runtime_acceptance := _evaluate_patch_acceptance(true, dominant_pass, mixed_pass, mixed_pass)
	lines.append(_format_acceptance(runtime_acceptance))
	last_patch_acceptance = runtime_acceptance
	if not mixed_pass:
		var softened_patch := generate_softened_patch(patch)
		lines.append(format_softening(patch, softened_patch))
		lines.append("[BALANCE_PATCH_RUNTIME]\napplied=false\ndata_changed=true\nreason=mixed_defense_failed")
		lines.append("[BALANCE_PATCH_NOT_COMMITTED]\nreason=mixed_defense_failed")
		last_operation_log = "\n".join(lines)
		last_error = "Mixed defense validation failed."
		return false

	lines.append("[BALANCE_PATCH_RUNTIME]\napplied=true\nsource_files_changed=false")
	last_operation_log = "\n".join(lines)
	return true

func apply_patch(patch: Dictionary) -> bool:
	last_error = ""
	var lines: Array[String] = []
	if _balance_tool_blocked("Apply File Patch", lines):
		return false
	if patch.is_empty():
		return _fail_operation("Cannot apply empty patch.", lines)

	var level_id := str(patch.get("level_id", ""))
	var level_path := LEVELS_DIR + level_id + ".json"
	var level_data = _load_json(level_path)
	if not (level_data is Dictionary) or level_data.is_empty() or str(level_data.get("id", "")) != level_id:
		return _fail_operation("Level id validation failed for %s." % level_id, lines)

	var waves_path := str(level_data.get("waves_path", ""))
	var original_waves = _load_json(waves_path)
	var enemies = _load_json(ENEMIES_PATH)
	if not (original_waves is Array) or not (enemies is Dictionary):
		return _fail_operation("Wave data is not an array: %s" % waves_path, lines)

	var patch_signature := _patch_signature(patch)
	if not file_original_baselines.has(level_id):
		file_original_baselines[level_id] = (original_waves as Array).duplicate(true)
	var baseline_waves: Array = (file_original_baselines[level_id] as Array).duplicate(true)
	var before_hash := wave_data_hash(original_waves)
	var patch_path := _save_patch_for_apply(patch)
	var target := _format_target(level_id, "file", waves_path, patch_path, "")
	lines.append(target)
	lines.append("[BALANCE_PATCH_BASELINE]\nmode=file\nsource=%s" % ("original_file_snapshot" if wave_data_hash(baseline_waves) != before_hash else "current_file"))
	lines.append("[WAVE_DATA_CACHE]\nloader=FileAccess\ncache_bypassed=true")

	if file_patch_signatures.get(level_id, 0) == patch_signature:
		lines.append("[BALANCE_PATCH_ALREADY_APPLIED]")
		last_operation_log = "\n".join(lines)
		last_error = "Duplicate file patch rejected."
		return false

	var patched_waves := _apply_changes_to_waves(baseline_waves.duplicate(true), patch, enemies)
	if patched_waves.size() != (original_waves as Array).size():
		return _fail_operation("Persistent patch changed wave count.", lines)

	var expected_hash := wave_data_hash(patched_waves)
	lines.append(_format_hash(before_hash, expected_hash))
	var diff := build_patch_diff(level_id, original_waves, patched_waves, enemies)
	lines.append(format_patch_diff(level_id, diff))
	if not bool(diff.get("changed", false)) or before_hash == expected_hash:
		var acceptance := _evaluate_patch_acceptance(false, false, false, false)
		lines.append(_format_acceptance(acceptance))
		lines.append("[BALANCE_PATCH_NOOP]\nPatch applied but level data did not change.")
		last_operation_log = "\n".join(lines)
		last_error = "File patch was a no-op."
		last_patch_acceptance = acceptance
		return false

	var validation := _validate_waves(level_id, patched_waves, enemies)
	if not bool(validation.get("ok", false)):
		return _fail_operation(str(validation.get("reason", "Validation failed.")), lines)
	if bool(validation.get("boring", false)):
		return _fail_operation("Patch rejected: Generated waves are too boring (low density or diversity).", lines)

	var dominant := run_dominant_strategy_test(level_id, patch, null, patched_waves)
	lines.append(dominant)
	var dominant_pass := _dominant_strategy_passed(dominant)
	if not dominant_pass:
		var acceptance := _evaluate_patch_acceptance(true, dominant_pass, false, false)
		lines.append(_format_acceptance(acceptance))
		lines.append(_format_escalation(generate_stage_2_patch(patch)))
		lines.append("[BALANCE_PATCH_APPLY]\napplied=false\nwrite_verified=false\nreason=dominant_strategy_still_clears")
		lines.append("[BALANCE_PATCH_NOT_COMMITTED]\nreason=dominant_strategy_still_clears")
		last_operation_log = "\n".join(lines)
		last_error = "Dominant strategy still clears. Generate/apply Stage 2 patch."
		last_patch_acceptance = acceptance
		return false

	var mixed := run_mixed_defense_test(level_id, patch, null, patched_waves)
	lines.append(mixed)
	var mixed_pass := _mixed_defense_passed(mixed)
	if not mixed_pass:
		var acceptance := _evaluate_patch_acceptance(true, dominant_pass, mixed_pass, false)
		lines.append(_format_acceptance(acceptance))
		var softened_patch := generate_softened_patch(patch)
		lines.append(format_softening(patch, softened_patch))
		lines.append("[BALANCE_PATCH_APPLY]\napplied=false\nwrite_verified=false\nreason=mixed_defense_failed")
		lines.append("[BALANCE_PATCH_NOT_COMMITTED]\nreason=mixed_defense_failed")
		last_operation_log = "\n".join(lines)
		last_error = "Mixed defense validation failed."
		last_patch_acceptance = acceptance
		return false

	var backup_dir := _backup_files(level_id, [waves_path])
	if backup_dir == "":
		return _fail_operation(last_error, lines)
	lines[0] = _format_target(level_id, "file", waves_path, patch_path, backup_dir)

	if not _write_json(waves_path, patched_waves):
		return _fail_operation(last_error, lines)

	var readback = _load_json(waves_path)
	var actual_hash := wave_data_hash(readback)
	var readback_ok := readback is Array and actual_hash == expected_hash
	lines.append("[BALANCE_PATCH_FILE_VERIFY]\nwrite_path=%s\nexists=%s\nreadback_parse_ok=%s\nexpected_hash=%s\nactual_hash=%s\nverified=%s\nhash_method=canonical_json" % [
		waves_path,
		str(FileAccess.file_exists(waves_path)),
		str(readback is Array),
		str(expected_hash),
		str(actual_hash),
		str(readback_ok)
	])
	var acceptance := _evaluate_patch_acceptance(true, dominant_pass, mixed_pass, readback_ok)
	lines.append(_format_acceptance(acceptance))
	if not readback_ok:
		_write_json(waves_path, original_waves)
		lines.append("[BALANCE_PATCH_NOT_COMMITTED]\nreason=file_verify_failed")
		last_operation_log = "\n".join(lines)
		last_error = "File read-back verification failed."
		last_patch_acceptance = acceptance
		return false

	file_patch_signatures[level_id] = patch_signature
	lines.append("[BALANCE_PATCH_APPLY]\napplied=true\nbackup_created=true\nreadback_verified=true")
	last_patch_acceptance = acceptance
	last_operation_log = "\n".join(lines)
	return true

func rollback_last_patch(level_id: String) -> bool:
	last_error = ""
	var lines: Array[String] = []
	if _balance_tool_blocked("Rollback Last Patch", lines):
		return false

	var manifest_path := last_backup_manifest_path
	if manifest_path == "":
		manifest_path = BACKUP_DIR + "last_%s_manifest.json" % level_id
	var manifest = _load_json(manifest_path)
	if not (manifest is Dictionary) or manifest.is_empty():
		return _fail_operation("No backup manifest found for %s." % level_id, lines)

	for entry in manifest.get("files", []):
		var source := str(entry.get("backup_path", ""))
		var target := str(entry.get("original_path", ""))
		var data = _load_json(source)
		if data == null or (data is Dictionary and data.is_empty()) or (data is Array and data.is_empty()):
			return _fail_operation("Backup read failed: %s" % source, lines)
		if not _write_json(target, data):
			return _fail_operation(last_error, lines)

	file_patch_signatures.erase(level_id)
	file_original_baselines.erase(level_id)
	runtime_original_baselines.erase(level_id)
	lines.append("[BALANCE_PATCH_ROLLBACK] restored=%s" % str(manifest.get("backup_dir", "")))
	last_operation_log = "\n".join(lines)
	print(last_operation_log)
	return true

func export_patch_json(patch: Dictionary) -> String:
	if _balance_tool_blocked("Export Patch JSON"):
		return ""
	return save_patch(patch)

func find_acceptable_patch(initial_patch: Dictionary, wave_manager: Node = null) -> Dictionary:
	last_error = ""
	var lines: Array[String] = []
	if _balance_tool_blocked("Find Acceptable Patch", lines):
		return {}
	var patch := initial_patch.duplicate(true)
	var level_id := str(patch.get("level_id", ""))
	var enemies = _load_json(ENEMIES_PATH)
	if not (enemies is Dictionary):
		last_error = "Enemy data could not be loaded."
		return {}
	var source_waves := _patch_search_source_waves(level_id, wave_manager)
	if source_waves.is_empty():
		last_error = "No waves available for patch search."
		return {}

	for attempt in range(1, PATCH_SEARCH_MAX_ATTEMPTS + 1):
		var patched_waves := _apply_changes_to_waves(source_waves.duplicate(true), patch, enemies)
		var dominant := run_dominant_strategy_test(level_id, patch, null, patched_waves)
		var mixed := run_mixed_defense_test(level_id, patch, null, patched_waves)
		var data_changed := wave_data_hash(source_waves) != wave_data_hash(patched_waves)
		var acceptance := _evaluate_patch_acceptance(data_changed, _dominant_strategy_passed(dominant), _mixed_defense_passed(mixed), true)
		lines.append("[BALANCE_PATCH_SEARCH]\nattempt=%d stage=%s dominant=%s mixed=%s status=%s" % [
			attempt,
			str(patch.get("patch_stage", 1)),
			"PASS" if bool(acceptance.get("dominant_strategy_pass", false)) else "FAIL",
			"PASS" if bool(acceptance.get("mixed_defense_pass", false)) else "FAIL",
			str(acceptance.get("status", "unknown"))
		])
		lines.append(_format_acceptance(acceptance))
		if str(acceptance.get("status", "")) == PATCH_STATUS_ACCEPTED:
			last_operation_log = "\n".join(lines)
			last_patch_acceptance = acceptance
			return patch
		if str(acceptance.get("status", "")) == PATCH_STATUS_REJECTED_DOMINANT_STRATEGY_STILL_CLEARS:
			patch = generate_stage_2_patch(patch)
			lines.append(_format_escalation(patch))
		elif str(acceptance.get("status", "")) == PATCH_STATUS_NEEDS_SOFTENING:
			var softened := generate_softened_patch(patch)
			lines.append(format_softening(patch, softened))
			patch = softened
		else:
			break

	last_operation_log = "\n".join(lines)
	last_error = "No acceptable patch found within %d attempts." % PATCH_SEARCH_MAX_ATTEMPTS
	return {}

func run_dominant_strategy_test(level_id: String, patch: Dictionary = {}, wave_manager: Node = null, override_waves: Array = []) -> String:
	if _balance_tool_blocked("Run Dominant Strategy Test"):
		return last_operation_log
	var waves := override_waves.duplicate(true) if not override_waves.is_empty() else _resolve_test_waves(level_id, patch, wave_manager)
	var patch_hash := wave_data_hash(waves)
	var result := _simulate_lightning_economy_strategy(level_id, waves, patch)
	var cleared := bool(result.get("clear", false))
	var leaks := int(result.get("enemies_leaked", 0))
	var perfect := cleared and leaks == 0 and int(result.get("lives_end", 0)) >= int(result.get("lives_start", 20))
	var lines: Array[String] = []
	lines.append("[DOMINANT_STRATEGY_TEST]")
	lines.append("level=%s" % level_id)
	lines.append("patch_hash=%s" % str(patch_hash))
	lines.append("strategy=2x_lightning_l3_only")
	lines.append("result=%s" % ("clear" if cleared else "fail"))
	lines.append("perfect=%s" % str(perfect))
	lines.append("lives_end=%d" % int(result.get("lives_end", 0)))
	lines.append("leaks=%d" % leaks)
	lines.append("waves_completed=%d" % int(result.get("waves_completed", 0)))
	lines.append("verdict=%s" % ("FAIL" if cleared and leaks == 0 else "PASS"))
	return "\n".join(lines)

func run_mixed_defense_test(level_id: String, patch: Dictionary = {}, wave_manager: Node = null, override_waves: Array = []) -> String:
	if _balance_tool_blocked("Run Mixed Defense Test"):
		return last_operation_log
	var waves := override_waves.duplicate(true) if not override_waves.is_empty() else _resolve_test_waves(level_id, patch, wave_manager)
	var patch_hash := wave_data_hash(waves)
	var cells := _strategy_cells(level_id, 5)
	var towers: Array[Dictionary] = [
		{"type": "lightning_tower", "cell": cells[0], "level": 2},
		{"type": "rapid_tower", "cell": cells[1], "level": 2},
		{"type": "sniper_tower", "cell": cells[2], "level": 2},
		{"type": "slow_tower", "cell": cells[3], "level": 2},
		{"type": "cannon_tower", "cell": cells[4], "level": 2}
	]
	var result := _simulate_fixed_strategy(level_id, towers, waves, patch)
	var cleared := bool(result.get("clear", false))
	var gold_ratio := float(result.get("gold_remaining_ratio", 0.0))
	var lines: Array[String] = []
	lines.append("[MIXED_DEFENSE_PLAN]")
	lines.append("builds=%s" % _format_tower_builds(towers))
	lines.append("upgrades=%s" % _format_tower_levels(towers))
	lines.append("hero_timing=wave_4_or_5_optional")
	lines.append("gold_spent_planned=%d" % int(result.get("gold_spent_total", 0)))
	if gold_ratio > 1.0:
		lines.append("[MIXED_DEFENSE_METRIC_WARNING]\ngold_remaining_ratio=%.3f" % gold_ratio)
	lines.append("[MIXED_DEFENSE_TEST]")
	lines.append("level=%s" % level_id)
	lines.append("patch_hash=%s" % str(patch_hash))
	lines.append("result=%s" % ("clear" if cleared else "fail"))
	lines.append("lives_end=%d" % int(result.get("lives_end", 0)))
	lines.append("leaks=%d" % int(result.get("enemies_leaked", 0)))
	lines.append("waves_completed=%d" % int(result.get("waves_completed", 0)))
	lines.append("tower_variety_count=%d" % _tower_variety_count(towers))
	lines.append("damage_by_tower_type=%s" % JSON.stringify(result.get("damage_by_tower_type", {})))
	lines.append("top_damage_tower=%s" % str(result.get("top_damage_tower", "none")))
	lines.append("gold_start=%d" % int(result.get("gold_start", 0)))
	lines.append("gold_earned_total=%d" % int(result.get("gold_earned_total", 0)))
	lines.append("gold_spent_total=%d" % int(result.get("gold_spent_total", 0)))
	lines.append("gold_remaining=%d" % int(result.get("gold_remaining", 0)))
	lines.append("gold_remaining_ratio=%.3f" % gold_ratio)
	lines.append("hero_used=%s" % str(result.get("hero_used", false)))
	lines.append("fail_wave=%s" % str(result.get("fail_wave", "")))
	lines.append("fail_reason=%s" % str(result.get("fail_reason", "")))
	lines.append("leaks_by_enemy_type=%s" % JSON.stringify(result.get("leaks_by_enemy_type", {})))
	return "\n".join(lines)

func wave_data_hash(wave_data) -> int:
	return canonicalize_json_data(wave_data).hash()

func build_patch_diff(level_id: String, before_waves: Array, after_waves: Array, enemies: Dictionary) -> Dictionary:
	var before := summarize_wave_data(before_waves, enemies)
	var after := summarize_wave_data(after_waves, enemies)
	return {
		"level_id": level_id,
		"before": before,
		"after": after,
		"changed": wave_data_hash(before_waves) != wave_data_hash(after_waves),
		"threat_before": before.get("total_threat", 0.0),
		"threat_after": after.get("total_threat", 0.0),
		"role_div_before": before.get("avg_role_diversity", 0.0),
		"role_div_after": after.get("avg_role_diversity", 0.0)
	}

func summarize_wave_data(waves: Array, enemies: Dictionary) -> Dictionary:
	var summary := {
		"wave_count": waves.size(),
		"total_enemies": 0,
		"total_kill_reward_estimate": 0,
		"total_wave_reward": 0,
		"enemy_count_by_type": {},
		"total_threat": 0.0,
		"role_counts": {},
		"per_wave": []
	}
	for i in range(waves.size()):
		var wave: Dictionary = waves[i]
		var groups: Array = wave.get("groups", [])
		var wave_entry := {
			"wave_index": int(wave.get("wave", i + 1)),
			"wave_name": str(wave.get("name", "Unknown Wave")),
			"groups_count": groups.size(),
			"enemy_types": [],
			"counts": {},
			"roles": {},
			"threat": 0.0,
			"intervals": [],
			"reward": int(wave.get("reward", wave.get("completion_reward", 0)))
		}
		summary["total_wave_reward"] += int(wave_entry["reward"])
		for group in groups:
			var enemy_type := str(group.get("enemy_type", group.get("type", "")))
			var count := int(group.get("count", 0))
			var spacing := float(group.get("spawn_delay", group.get("interval", 1.0)))
			if not wave_entry["enemy_types"].has(enemy_type):
				wave_entry["enemy_types"].append(enemy_type)
			
			wave_entry["counts"][enemy_type] = int(wave_entry["counts"].get(enemy_type, 0)) + count
			
			var roles: Array = ENEMY_ROLES.get(enemy_type, ["filler"])
			for r in roles:
				wave_entry["roles"][r] = int(wave_entry["roles"].get(r, 0)) + count
				summary["role_counts"][r] = int(summary["role_counts"].get(r, 0)) + count
			
			var threat: float = float(THREAT_SCORES.get(enemy_type, 1.0)) * count
			wave_entry["threat"] += threat
			summary["total_threat"] += threat
			
			wave_entry["intervals"].append(spacing)
			summary["total_enemies"] += count
			summary["enemy_count_by_type"][enemy_type] = int(summary["enemy_count_by_type"].get(enemy_type, 0)) + count
			var kill_reward := int(group.get("reward_gold", enemies.get(enemy_type, {}).get("reward_gold", 0)))
			summary["total_kill_reward_estimate"] += kill_reward * count
		
		wave_entry["role_diversity"] = wave_entry["roles"].size()
		summary["per_wave"].append(wave_entry)
	
	summary["avg_role_diversity"] = float(summary["role_counts"].size())
	return summary

func format_patch_diff(level_id: String, diff: Dictionary) -> String:
	var before: Dictionary = diff.get("before", {})
	var after: Dictionary = diff.get("after", {})
	return "[BALANCE_PATCH_DIFF]\nlevel=%s\nchanged=%s\ntotal_wave_reward_before=%d\ntotal_wave_reward_after=%d\ntotal_enemy_count_before=%d\ntotal_enemy_count_after=%d\nthreat_before=%.1f\nthreat_after=%.1f\nrole_diversity_before=%.1f\nrole_diversity_after=%.1f" % [
		level_id,
		str(diff.get("changed", false)),
		int(before.get("total_wave_reward", 0)),
		int(after.get("total_wave_reward", 0)),
		int(before.get("total_enemies", 0)),
		int(after.get("total_enemies", 0)),
		float(diff.get("threat_before", 0.0)),
		float(diff.get("threat_after", 0.0)),
		float(diff.get("role_div_before", 0.0)),
		float(diff.get("role_div_after", 0.0))
	]

func _apply_changes_to_waves(waves: Array, patch: Dictionary, enemies: Dictionary) -> Array:
	for change in patch.get("proposed_changes", []):
		var change_type := str(change.get("type", ""))
		match change_type:
			"reward_multiplier":
				var kill_mult := float(change.get("kill_reward_multiplier", 1.0))
				var wave_mult := float(change.get("wave_reward_multiplier", 1.0))
				for wave in waves:
					var reward_key := "reward" if wave.has("reward") else "completion_reward"
					wave[reward_key] = max(0, int(round(float(wave.get(reward_key, 0)) * wave_mult)))
					for group in wave.get("groups", []):
						var enemy_type := str(group.get("enemy_type", group.get("type", "basic")))
						var base_reward := int(enemies.get(enemy_type, {}).get("reward_gold", group.get("reward_gold", 0)))
						group["reward_gold"] = max(0, int(round(float(base_reward) * kill_mult)))
			"economy_gate":
				var idx := int(change.get("target_wave", 0)) - 1
				if idx >= 0 and idx < waves.size():
					var reward_key := "reward" if waves[idx].has("reward") else "completion_reward"
					waves[idx][reward_key] = max(0, int(round(float(waves[idx].get(reward_key, 0)) * float(change.get("reward_multiplier", 1.0)))))
			"formation_adjustment", "spawn_order_adjustment", "lane_timing_adjustment":
				var target_waves := _resolve_patch_target_waves(change, waves)
				for wave_num in target_waves:
					var idx := int(wave_num) - 1
					if idx < 0 or idx >= waves.size(): continue
					_apply_formation_patch_to_wave(waves[idx], change, enemies)
			"threat_budget_adjustment", "counter_role_adjustment", "composition_synergy_boost":
				var target_waves := []
				var waves_val = change.get("target_waves", change.get("target_wave", "all"))
				if waves_val is Array:
					target_waves = waves_val
				elif str(waves_val) == "all":
					for i in range(waves.size()): target_waves.append(i + 1)
				elif str(waves_val) == "mid_to_late":
					for i in range(int(waves.size() * 0.4), waves.size()): target_waves.append(i + 1)

				for wave_num in target_waves:
					var idx = int(wave_num) - 1
					if idx < 0 or idx >= waves.size(): continue
					
					var current_threat := _calculate_wave_threat(waves[idx])
					var target_threat := current_threat
					var forced_roles := []
					
					if change_type == "threat_budget_adjustment":
						target_threat *= float(change.get("budget_multiplier", 1.0))
					
					if change_type == "counter_role_adjustment":
						var dominant = str(change.get("dominant_tower", ""))
						match dominant:
							"lightning": forced_roles.append_array(["tank", "support"])
							"cannon": forced_roles.append_array(["pressure", "tank"])
							"rapid": forced_roles.append_array(["frontliner", "tank"])
							"slow": forced_roles.append_array(["pressure"])
							"sniper": forced_roles.append_array(["support", "pressure"])
							"sawblade": forced_roles.append_array(["pressure", "support"])
						target_threat *= 1.1 # Slight bump for counter waves

					if change_type == "composition_synergy_boost":
						var min_roles = int(change.get("min_roles", 4))
						# Handled in composition generator
						target_threat *= 1.15

					var template_key := _get_template_for_wave(idx, waves.size())
					var new_comp := _generate_composition_from_budget(target_threat, template_key, enemies, forced_roles)
					if not new_comp.is_empty():
						waves[idx]["groups"] = _generate_spawn_groups(new_comp, idx)
						_ensure_wave_formation_metadata(waves[idx], enemies)
						
			"hero_opportunity_moment":
				var idx := int(change.get("target_wave", 0)) - 1
				if idx >= 0 and idx < waves.size():
					var append_text := str(change.get("intel_append", ""))
					if append_text != "" and not str(waves[idx].get("intel", "")).contains(append_text.strip_edges()):
						waves[idx]["intel"] = str(waves[idx].get("intel", "")) + append_text
	return waves

func _resolve_patch_target_waves(change: Dictionary, waves: Array) -> Array:
	var target_waves := []
	var waves_val = change.get("target_waves", change.get("target_wave", "all"))
	if waves_val is Array:
		target_waves = waves_val
	elif str(waves_val) == "all":
		for i in range(waves.size()): target_waves.append(i + 1)
	elif str(waves_val) == "mid_to_late":
		for i in range(int(waves.size() * 0.4), waves.size()): target_waves.append(i + 1)
	elif str(waves_val) == "multi_lane":
		for i in range(waves.size()):
			if _wave_has_multiple_paths(waves[i]):
				target_waves.append(i + 1)
	else:
		target_waves.append(int(waves_val))
	return target_waves

func _wave_has_multiple_paths(wave: Dictionary) -> bool:
	var paths := {}
	for group in wave.get("groups", []):
		if group is Dictionary:
			paths[str(group.get("path", "default"))] = true
	return paths.keys().size() > 1

func _apply_formation_patch_to_wave(wave: Dictionary, change: Dictionary, enemies: Dictionary) -> void:
	var groups: Array = wave.get("groups", [])
	if groups.is_empty():
		return
	var change_type := str(change.get("type", ""))
	if change_type == "lane_timing_adjustment":
		var flank_offset := float(change.get("flank_offset", 0.35))
		for group in groups:
			if group is Dictionary and str(group.get("path", "default")) != "default":
				group["start_offset"] = max(float(group.get("start_offset", group.get("start_delay", 0.0))), flank_offset)
		wave["formation"] = "multi_lane_pincer"
		_ensure_wave_formation_metadata(wave, enemies)
		return
	
	var dominant := str(change.get("dominant_tower", ""))
	for group in groups:
		if not (group is Dictionary):
			continue
		var enemy_type := str(group.get("enemy_type", group.get("type", "basic")))
		var formation := _suggest_formation_for_enemy(enemy_type, groups, dominant, enemies)
		if formation != "":
			group["formation"] = formation
	if _wave_has_multiple_paths(wave):
		wave["formation"] = "multi_lane_pincer"
	_ensure_wave_formation_metadata(wave, enemies)

func _ensure_wave_formation_metadata(wave: Dictionary, enemies: Dictionary) -> void:
	var groups: Array = wave.get("groups", [])
	if groups.is_empty():
		return
	var path_formations := {}
	var path_groups := {}
	for group in groups:
		if not (group is Dictionary):
			continue
		var path := str(group.get("path", "default"))
		if not path_groups.has(path):
			path_groups[path] = []
		path_groups[path].append(group)
	for path in path_groups.keys():
		var formation := _suggest_path_formation(path_groups[path], enemies)
		path_formations[path] = formation
		for group in path_groups[path]:
			group["formation"] = formation
			group["role"] = _primary_role_for_enemy(str(group.get("enemy_type", group.get("type", "basic"))), enemies)
	if path_formations.keys().size() > 1:
		wave["formation"] = "multi_lane_pincer"
		wave["path_formations"] = path_formations
	else:
		wave["formation"] = str(path_formations.values()[0])
	wave["formation_rules"] = {
		"preserve_formation_time": 2.0,
		"frontliner_lead_time": 0.35,
		"max_overtake_distance": 64
	}
	wave["formation_intent"] = _formation_intent(str(wave.get("formation", "")), path_formations)

func _suggest_path_formation(groups: Array, enemies: Dictionary) -> String:
	var types := []
	for group in groups:
		if group is Dictionary:
			var t := str(group.get("enemy_type", group.get("type", "")))
			if t != "" and not types.has(t):
				types.append(t)
	if types.size() == 1:
		var role := _primary_role_for_enemy(types[0], enemies)
		match role:
			"swarm": return "swarm_rush"
			"pressure": return "runner_raid"
			"frontliner": return "heavy_column"
			"support": return "repair_train"
			"disruptor": return "stealth_probe"
			"air": return "air_wing"
			_: return "baseline_column"
	return _suggest_formation_for_enemy(types[0], groups, "", enemies)

func _primary_role_for_enemy(enemy_type: String, enemies: Dictionary) -> String:
	var cfg: Dictionary = enemies.get(enemy_type, {})
	var tags: Array = cfg.get("tags", [])
	var category := str(cfg.get("category", "")).to_lower()
	var skill := str(cfg.get("skill", ""))
	if enemy_type in ["tank", "bulwark", "shieldbearer", "armored_flyer"] or tags.has("heavy") or tags.has("armored") or tags.has("frontline"):
		return "frontliner"
	if enemy_type in ["swarm"] or tags.has("swarm") or tags.has("small"):
		return "swarm"
	if enemy_type in ["runner", "fast", "hunter", "fast_flyer"] or tags.has("fast") or tags.has("runner"):
		return "pressure"
	if enemy_type in ["healer", "shieldbearer", "disruptor"] or tags.has("support") or skill in ["healer", "shield_aura", "disrupt_aura"]:
		return "support"
	if enemy_type in ["cloaked"] or tags.has("stealth"):
		return "disruptor"
	if category == "air" or tags.has("air"):
		return "air"
	if enemy_type == "splitter" or skill == "split_on_death":
		return "splitter"
	return "escort"

func _formation_intent(formation: String, path_formations: Dictionary) -> String:
	if formation == "multi_lane_pincer":
		return "Coordinate path-specific formations into readable lane pressure: %s" % str(path_formations)
	match formation:
		"escort_staggered": return "Frontliners lead while escorts fill gaps behind them."
		"repair_convoy": return "Support trails durable units inside aura range."
		"shield_wall": return "Shieldbearers create a defensive shell around allies."
		"swarm_rush", "swarm_burst": return "Swarm arrives in dense AoE-testing bursts."
		"runner_raid", "delayed_pressure": return "Fast enemies arrive as timing pressure."
		"air_wing", "air_escort": return "Air units arrive as an ordered pressure layer."
		"stealth_probe", "stealth_mask": return "Stealth behavior is explicit and reported."
		_: return "Readable role-aware formation pressure."

func _suggest_formation_for_enemy(enemy_type: String, groups: Array, dominant_tower: String = "", enemies: Dictionary = {}) -> String:
	var types := []
	for group in groups:
		if group is Dictionary:
			var t := str(group.get("enemy_type", group.get("type", "")))
			if not types.has(t):
				types.append(t)
	var has_frontliner := false
	var has_support := false
	var has_swarm := false
	var has_pressure := false
	var has_air := false
	for t in types:
		var roles: Array = ENEMY_ROLES.get(t, [])
		var cfg: Dictionary = enemies.get(t, {})
		if roles.has("frontliner") or roles.has("tank") or str(cfg.get("category", "")) == "air" and str(t).contains("armored"):
			has_frontliner = true
		if roles.has("support") or t in ["healer", "shieldbearer", "disruptor"]:
			has_support = true
		if t == "swarm":
			has_swarm = true
		if roles.has("pressure") or t in ["runner", "fast", "hunter", "fast_flyer"]:
			has_pressure = true
		if str(cfg.get("category", "")) == "air" or t in ["flyer", "fast_flyer", "armored_flyer", "disruptor"]:
			has_air = true
	if has_air:
		return "air_escort"
	if types.has("shieldbearer"):
		return "shield_wall"
	if types.has("healer") and has_frontliner:
		return "repair_convoy"
	if types.has("cloaked") and types.size() > 1:
		return "armored_cloak_mask"
	if types.has("splitter"):
		return "splitter_payload"
	if has_swarm and has_pressure:
		return "swarm_runner_pressure"
	if has_swarm and has_frontliner:
		return "swarm_screen"
	if has_pressure and has_frontliner:
		return "delayed_runner_pressure"
	if has_frontliner and types.size() > 1:
		return "escort_staggered"
	match dominant_tower:
		"lightning": return "shield_wall" if has_support else "armored_cloak_mask"
		"cannon": return "delayed_runner_pressure"
		"rapid": return "tank_support_column"
		"slow": return "delayed_runner_pressure"
		"sniper": return "repair_convoy"
		"sawblade": return "swarm_screen"
	return "auto_tactical"

func _suggest_formation_for_pair(a: String, b: String) -> String:
	var pair := [a, b]
	if pair.has("healer"):
		return "repair_convoy"
	if pair.has("shieldbearer"):
		return "shield_wall"
	if pair.has("cloaked"):
		return "armored_cloak_mask"
	if pair.has("splitter"):
		return "splitter_payload"
	if pair.has("swarm") and (pair.has("runner") or pair.has("fast")):
		return "swarm_runner_pressure"
	if pair.has("swarm"):
		return "swarm_screen"
	if pair.has("runner") or pair.has("fast") or pair.has("hunter"):
		return "delayed_runner_pressure"
	return "escort_staggered"

func _validate_waves(level_id: String, waves, enemies: Dictionary) -> Dictionary:
	if not (waves is Array) or waves.is_empty():
		return {"ok": false, "reason": "No waves found for %s." % level_id}
	
	var boring_found := false
	for i in range(waves.size()):
		var wave = waves[i]
		if not (wave is Dictionary):
			return {"ok": false, "reason": "Wave %d is not a dictionary." % (i + 1)}
		var groups: Array = wave.get("groups", [])
		if groups.is_empty():
			return {"ok": false, "reason": "Wave %d is empty." % (i + 1)}
		
		var comp := []
		for group in groups:
			comp.append({"type": str(group.get("enemy_type", group.get("type", ""))), "count": int(group.get("count", 0))})
		
		if _is_composition_boring(comp, i, waves.size()):
			boring_found = true
			
		var reward := int(wave.get("reward", wave.get("completion_reward", 0)))
		if reward < 0:
			return {"ok": false, "reason": "Wave %d has negative reward." % (i + 1)}
		for group in groups:
			var enemy_type := str(group.get("enemy_type", group.get("type", "")))
			if not enemies.has(enemy_type):
				return {"ok": false, "reason": "Wave %d references missing enemy type: %s" % [i + 1, enemy_type]}
			if int(group.get("count", 0)) <= 0:
				return {"ok": false, "reason": "Wave %d has non-positive enemy count." % (i + 1)}
			if int(group.get("reward_gold", 0)) < 0:
				return {"ok": false, "reason": "Wave %d has negative kill reward override." % (i + 1)}
				
	return {"ok": true, "boring": boring_found}

func _backup_files(level_id: String, paths: Array[String]) -> String:
	_ensure_dir(BACKUP_DIR)
	var backup_dir := "%s%s_%d/" % [BACKUP_DIR, level_id, Time.get_unix_time_from_system()]
	_ensure_dir(backup_dir)
	var entries: Array[Dictionary] = []
	for path in paths:
		var data = _load_json(path)
		if data == null:
			last_error = "Could not read file for backup: %s" % path
			return ""
		var backup_path := backup_dir + path.get_file()
		if not _write_json(backup_path, data):
			return ""
		entries.append({"original_path": path, "backup_path": backup_path})

	var manifest := {
		"level_id": level_id,
		"created_at": Time.get_datetime_string_from_system(),
		"backup_dir": backup_dir,
		"files": entries
	}
	var manifest_path := backup_dir + "manifest.json"
	if not _write_json(manifest_path, manifest):
		return ""
	last_backup_manifest_path = manifest_path
	_write_json(BACKUP_DIR + "last_%s_manifest.json" % level_id, manifest)
	return backup_dir

func _simulate_lightning_economy_strategy(level_id: String, waves: Array, patch: Dictionary) -> Dictionary:
	var level = _load_json(LEVELS_DIR + level_id + ".json")
	if not (level is Dictionary):
		level = {}
	var towers_config := _patched_towers_config(patch)
	var cells := _strategy_cells(level_id, 2)
	var lives := int(level.get("starting_lives", 20))
	var gold := int(level.get("starting_gold", 0))
	var towers: Array[Dictionary] = []
	var waves_completed := 0
	for wave in waves:
		gold = _buy_lightning_progression(gold, towers, cells, towers_config)
		var result := _simulate_fixed_strategy_state(level_id, towers, waves_completed, wave)
		if not bool(result.get("perfect", false)):
			return {
				"clear": false,
				"lives_start": lives,
				"lives_end": lives - 1,
				"enemies_leaked": 1,
				"waves_completed": waves_completed,
				"gold_remaining_ratio": 0.0
			}
		gold += int(result.get("gold_delta", 0))
		waves_completed += 1
	return {
		"clear": true,
		"lives_start": lives,
		"lives_end": lives,
		"enemies_leaked": 0,
		"waves_completed": waves_completed,
		"gold_remaining_ratio": float(gold) / max(1.0, float(level.get("starting_gold", 1)))
	}

func _buy_lightning_progression(gold: int, towers: Array[Dictionary], cells: Array[Vector2i], towers_config: Dictionary) -> int:
	var cfg: Dictionary = towers_config.get("lightning_tower", {})
	var base_cost := int(cfg.get("cost", 999999))
	while towers.size() < 2 and gold >= base_cost:
		towers.append({"type": "lightning_tower", "cell": cells[towers.size()], "level": 1})
		gold -= base_cost
	var bought := true
	while bought:
		bought = false
		for i in range(towers.size()):
			var level := int(towers[i].get("level", 1))
			var levels: Array = cfg.get("levels", [])
			if level >= 3 or level > levels.size():
				continue
			var cost := int(levels[level - 1].get("upgrade_cost", 0))
			if cost > 0 and gold >= cost:
				towers[i]["level"] = level + 1
				gold -= cost
				bought = true
	return gold

func _simulate_fixed_strategy(level_id: String, towers: Array[Dictionary], waves: Array, patch: Dictionary = {}) -> Dictionary:
	var level = _load_json(LEVELS_DIR + level_id + ".json")
	if not (level is Dictionary):
		level = {}
	var lives := int(level.get("starting_lives", 20))
	var gold_start := int(level.get("starting_gold", 0))
	var gold := gold_start
	var gold_spent := _tower_setup_cost(towers, patch)
	var gold_earned := 0
	var damage_by_tower_type: Dictionary = {}
	var waves_completed := 0
	for wave in waves:
		var result := _simulate_fixed_strategy_state(level_id, towers, waves_completed, wave, patch)
		var wave_damage: Dictionary = result.get("damage_by_tower_type", {})
		for tower_type in wave_damage:
			damage_by_tower_type[tower_type] = float(damage_by_tower_type.get(tower_type, 0.0)) + float(wave_damage[tower_type])
		if not bool(result.get("perfect", false)):
			var leak_enemy := str(result.get("leak_enemy", "unknown"))
			var leaks_by_enemy_type := {}
			leaks_by_enemy_type[leak_enemy] = 1
			var remaining: int = max(0, gold_start + gold_earned - gold_spent)
			return {
				"clear": false,
				"lives_end": lives - 1,
				"enemies_leaked": 1,
				"waves_completed": waves_completed,
				"gold_start": gold_start,
				"gold_earned_total": gold_earned,
				"gold_spent_total": gold_spent,
				"gold_remaining": remaining,
				"gold_remaining_ratio": float(remaining) / max(1.0, float(gold_start + gold_earned)),
				"damage_by_tower_type": damage_by_tower_type,
				"top_damage_tower": _top_damage_tower(damage_by_tower_type),
				"fail_wave": waves_completed + 1,
				"fail_reason": str(result.get("reason", "mixed defense leaked")),
				"leaks_by_enemy_type": leaks_by_enemy_type,
				"hero_used": false
			}
		var delta := int(result.get("gold_delta", 0))
		gold += delta
		gold_earned += delta
		waves_completed += 1
	var remaining: int = max(0, gold_start + gold_earned - gold_spent)
	return {
		"clear": true,
		"lives_end": lives,
		"enemies_leaked": 0,
		"waves_completed": waves_completed,
		"gold_start": gold_start,
		"gold_earned_total": gold_earned,
		"gold_spent_total": gold_spent,
		"gold_remaining": remaining,
		"gold_remaining_ratio": float(remaining) / max(1.0, float(gold_start + gold_earned)),
		"damage_by_tower_type": damage_by_tower_type,
		"top_damage_tower": _top_damage_tower(damage_by_tower_type),
		"fail_wave": "",
		"fail_reason": "",
		"leaks_by_enemy_type": {},
		"hero_used": false
	}

func _simulate_fixed_strategy_state(level_id: String, towers: Array[Dictionary], wave_index: int, wave: Dictionary, patch: Dictionary = {}) -> Dictionary:
	var solver_script = load(SOLVER_SCRIPT)
	if solver_script == null:
		return {"perfect": false, "reason": "solver_missing"}
	var solver = solver_script.new()
	solver.load_configs()
	solver.towers_config = _patched_towers_config(patch)
	solver.current_level_id = level_id
	solver.current_level_data = _load_json(LEVELS_DIR + level_id + ".json")
	solver.current_waves_data = [wave]
	solver._build_level_curves()
	var state = solver.create_state_manual(0, 20, wave_index, towers.duplicate(true))
	var telemetry := {"damage_by_tower_type": {}}
	var result: Dictionary = solver.simulate_wave(state, wave, telemetry)
	result["damage_by_tower_type"] = telemetry.get("damage_by_tower_type", {})
	if bool(result.get("perfect", false)):
		var end_state = result.get("state")
		return {"perfect": true, "gold_delta": int(end_state.gold), "damage_by_tower_type": result.get("damage_by_tower_type", {})}
	return result

func _resolve_test_waves(level_id: String, patch: Dictionary, wave_manager: Node = null) -> Array:
	if wave_manager != null and last_runtime_level_id == level_id:
		var live_waves: Array = wave_manager.get("waves")
		if wave_data_hash(live_waves) == last_runtime_patch_hash:
			return live_waves.duplicate(true)
	if not last_runtime_wave_data.is_empty() and last_runtime_level_id == level_id:
		return last_runtime_wave_data.duplicate(true)
	var level = _load_json(LEVELS_DIR + level_id + ".json")
	if not (level is Dictionary):
		level = {}
	var waves = _load_json(str(level.get("waves_path", "")))
	if not (waves is Array):
		return []
	if patch is Dictionary and not patch.is_empty():
		waves = _apply_changes_to_waves((waves as Array).duplicate(true), patch, _load_json(ENEMIES_PATH))
	return (waves as Array).duplicate(true)

func _patch_search_source_waves(level_id: String, wave_manager: Node = null) -> Array:
	if runtime_original_baselines.has(level_id):
		return (runtime_original_baselines[level_id] as Array).duplicate(true)
	if file_original_baselines.has(level_id):
		return (file_original_baselines[level_id] as Array).duplicate(true)
	var level = _load_json(LEVELS_DIR + level_id + ".json")
	if level is Dictionary:
		var waves = _load_json(str(level.get("waves_path", "")))
		if waves is Array:
			return (waves as Array).duplicate(true)
	if wave_manager != null:
		var live_waves: Array = wave_manager.get("waves")
		return live_waves.duplicate(true)
	return []

func _patched_towers_config(patch: Dictionary) -> Dictionary:
	var towers = _load_json(TOWERS_PATH)
	if not (towers is Dictionary):
		return {}
	for change in patch.get("proposed_changes", []):
		if str(change.get("type", "")) != "tower_upgrade_cost_adjustment":
			continue
		var tower_id := str(change.get("tower", ""))
		var target_level := int(change.get("level", 0))
		if not towers.has(tower_id):
			continue
		var levels: Array = towers[tower_id].get("levels", [])
		if target_level >= 2 and target_level <= levels.size():
			var idx := target_level - 2
			levels[idx]["upgrade_cost"] = int(round(float(levels[idx].get("upgrade_cost", 0)) * float(change.get("upgrade_cost_multiplier", 1.0))))
	return towers

func _strategy_cells(level_id: String, count: int) -> Array[Vector2i]:
	var level = _load_json(LEVELS_DIR + level_id + ".json")
	if not (level is Dictionary):
		level = {}
	var raw_cells: Array = level.get("buildable_cells", [])
	var preferred: Array[Vector2i] = [
		Vector2i(10, 7), Vector2i(10, 5), Vector2i(7, 4), Vector2i(7, 8), Vector2i(13, 5), Vector2i(13, 7)
	]
	var cells: Array[Vector2i] = []
	for cell in preferred:
		for raw in raw_cells:
			if raw is Array and raw.size() >= 2 and int(raw[0]) == cell.x and int(raw[1]) == cell.y:
				cells.append(cell)
				break
	for raw in raw_cells:
		if cells.size() >= count:
			break
		var cell := Vector2i(int(raw[0]), int(raw[1]))
		if not cells.has(cell):
			cells.append(cell)
	while cells.size() < count:
		cells.append(Vector2i(5 + cells.size(), 5))
	return cells

func _wave_spacing_summary(summary: Dictionary, wave_number: int) -> String:
	for wave in summary.get("per_wave", []):
		if int(wave.get("wave_index", 0)) == wave_number:
			var parts: Array[String] = []
			for value in wave.get("intervals", []):
				parts.append("%.2f" % float(value))
			return ",".join(parts)
	return ""

func _wave_enemy_count(summary: Dictionary, wave_number: int) -> int:
	for wave in summary.get("per_wave", []):
		if int(wave.get("wave_index", 0)) == wave_number:
			var total := 0
			for count in wave.get("counts", {}).values():
				total += int(count)
			return total
	return 0

func canonicalize_json_data(data: Variant) -> String:
	return JSON.stringify(_canonical_value(data))

func _canonical_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		for key in keys:
			var key_text := str(key)
			if key_text in ["created_at"]:
				continue
			out[key_text] = _canonical_value(value[key])
		return out
	if value is Array:
		var arr := []
		for item in value:
			arr.append(_canonical_value(item))
		return arr
	if value is float:
		return snappedf(float(value), 0.0001)
	return value

func _evaluate_patch_acceptance(data_changed: bool, dominant_strategy_pass: bool, mixed_defense_pass: bool, file_verify_pass: bool) -> Dictionary:
	var status := PATCH_STATUS_ACCEPTED
	if not data_changed:
		status = PATCH_STATUS_REJECTED_NO_DATA_CHANGE
	elif not dominant_strategy_pass:
		status = PATCH_STATUS_REJECTED_DOMINANT_STRATEGY_STILL_CLEARS
	elif not mixed_defense_pass and dominant_strategy_pass:
		status = PATCH_STATUS_NEEDS_SOFTENING
	elif not mixed_defense_pass:
		status = PATCH_STATUS_REJECTED_MIXED_DEFENSE_FAILED
	elif not file_verify_pass:
		status = PATCH_STATUS_REJECTED_FILE_VERIFY_FAILED
	return {
		"dominant_strategy_pass": dominant_strategy_pass,
		"mixed_defense_pass": mixed_defense_pass,
		"file_verify_pass": file_verify_pass,
		"status": status
	}

func _format_acceptance(acceptance: Dictionary) -> String:
	return "[BALANCE_PATCH_ACCEPTANCE]\ndominant_strategy_pass=%s\nmixed_defense_pass=%s\nfile_verify_pass=%s\nstatus=%s" % [
		str(bool(acceptance.get("dominant_strategy_pass", false))).to_lower(),
		str(bool(acceptance.get("mixed_defense_pass", false))).to_lower(),
		str(bool(acceptance.get("file_verify_pass", false))).to_lower(),
		str(acceptance.get("status", "unknown"))
	]

func _dominant_strategy_passed(output: String) -> bool:
	return _last_test_verdict(output) == "PASS"

func _mixed_defense_passed(output: String) -> bool:
	return "result=clear" in output

func _format_tower_builds(towers: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for tower in towers:
		var cell: Vector2i = tower.get("cell", Vector2i.ZERO)
		parts.append("%s@%d,%d" % [str(tower.get("type", "")), cell.x, cell.y])
	return ",".join(parts)

func _format_tower_levels(towers: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for tower in towers:
		parts.append("%s:L%d" % [str(tower.get("type", "")), int(tower.get("level", 1))])
	return ",".join(parts)

func _tower_variety_count(towers: Array[Dictionary]) -> int:
	var seen := {}
	for tower in towers:
		seen[str(tower.get("type", ""))] = true
	return seen.size()

func _tower_setup_cost(towers: Array[Dictionary], patch: Dictionary = {}) -> int:
	var towers_config := _patched_towers_config(patch)
	var total := 0
	for tower in towers:
		var tower_type := str(tower.get("type", ""))
		var cfg: Dictionary = towers_config.get(tower_type, {})
		total += int(cfg.get("cost", 0))
		var levels: Array = cfg.get("levels", [])
		for level in range(1, int(tower.get("level", 1))):
			if level - 1 >= 0 and level - 1 < levels.size():
				total += int(levels[level - 1].get("upgrade_cost", 0))
	return total

func _top_damage_tower(damage_by_tower_type: Dictionary) -> String:
	var best_type := "none"
	var best_damage := -1.0
	for tower_type in damage_by_tower_type:
		var value := float(damage_by_tower_type[tower_type])
		if value > best_damage:
			best_damage = value
			best_type = str(tower_type)
	return best_type

func _format_hash(before_hash: int, after_hash: int) -> String:
	return "[BALANCE_PATCH_HASH]\nbefore=%s\nafter=%s\nchanged=%s" % [str(before_hash), str(after_hash), str(before_hash != after_hash)]

func _format_target(level_id: String, mode: String, source_path: String, patch_path: String, backup_path: String) -> String:
	return "[BALANCE_PATCH_TARGET]\nlevel_id=%s\nmode=%s\nsource_path=%s\nglobal_source_path=%s\nuser_patch_path=%s\nbackup_path=%s" % [
		level_id,
		mode,
		source_path,
		ProjectSettings.globalize_path(source_path),
		patch_path,
		backup_path
	]

func _format_escalation(stage_2_patch: Dictionary) -> String:
	return "[BALANCE_PATCH_ESCALATE]\nreason=dominant strategy still clears\nstage=2\npreview:\n%s" % preview_patch(stage_2_patch)

func _patch_signature(patch: Dictionary) -> int:
	var data := patch.duplicate(true)
	data.erase("created_at")
	return canonicalize_json_data(data).hash()

func _save_patch_for_apply(patch: Dictionary) -> String:
	if last_saved_patch_path != "" and FileAccess.file_exists(last_saved_patch_path):
		return last_saved_patch_path
	return save_patch(patch)

func _last_test_verdict(test_output: String) -> String:
	for line in test_output.split("\n"):
		if line.begins_with("verdict="):
			return line.replace("verdict=", "").strip_edges()
	return "UNKNOWN"

func _clear_live_test_nodes(wave_manager: Node) -> void:
	var tree := wave_manager.get_tree()
	for enemy in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	var scene := tree.current_scene
	if scene:
		for path in ["WorldRoot/MapRoot/ProjectileContainer", "WorldRoot/ProjectileContainer"]:
			var container := scene.get_node_or_null(path)
			if container:
				for child in container.get_children():
					child.queue_free()

func _refresh_runtime_hud(wave_manager: Node) -> void:
	var scene := wave_manager.get_tree().current_scene
	if scene and scene.has_method("_refresh_hud_wave_intel"):
		scene._refresh_hud_wave_intel()
	if scene and scene.has_method("_refresh_route_preview"):
		scene._refresh_route_preview()
	if scene and scene.has_method("update_hud"):
		scene.update_hud()

func _fail_operation(message: String, lines: Array[String]) -> bool:
	last_error = message
	lines.append("[BALANCE_PATCH_ERROR]\n%s" % message)
	last_operation_log = "\n".join(lines)
	print(last_operation_log)
	return false

func _load_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed

func _write_json(path: String, data) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Failed to write %s (error=%s)." % [path, str(FileAccess.get_open_error())]
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func _calculate_wave_threat(wave: Dictionary) -> float:
	var total := 0.0
	for group in wave.get("groups", []):
		var e_type := str(group.get("enemy_type", group.get("type", "basic")))
		var count := int(group.get("count", 0))
		total += float(THREAT_SCORES.get(e_type, 1.0)) * count
	return total

func _get_template_for_wave(wave_index: int, total_waves: int) -> String:
	var progress := float(wave_index) / float(max(1, total_waves))
	if progress <= 0.2: return "early"
	if progress <= 0.5: return "mid"
	if progress <= 0.8: return "late"
	return "final"

func _get_enemies_by_role(role: String) -> Array:
	var out := []
	for e_type in ENEMY_ROLES:
		if role in ENEMY_ROLES[e_type]:
			out.append(e_type)
	return out

func _get_synergy_enemy(enemy_type: String, enemies_data: Dictionary) -> String:
	var roles: Array = ENEMY_ROLES.get(enemy_type, ["filler"])
	var target_roles: Array = []
	for r in roles:
		if ROLE_SYNERGY.has(r):
			target_roles.append_array(ROLE_SYNERGY[r])
	
	if target_roles.is_empty():
		return ""
	
	var candidates := []
	for r in target_roles:
		candidates.append_array(_get_enemies_by_role(r))
	
	if candidates.is_empty():
		return ""
	
	# Prefer enemies that exist in enemies_data
	var valid_candidates := []
	for c in candidates:
		if enemies_data.has(c):
			valid_candidates.append(c)
			
	if valid_candidates.is_empty():
		return ""
		
	return str(valid_candidates[randi() % valid_candidates.size()])

func _generate_composition_from_budget(budget: float, template_key: String, enemies_data: Dictionary, forced_roles: Array = []) -> Array:
	var template: Dictionary = WAVE_TEMPLATES.get(template_key, WAVE_TEMPLATES["mid"])
	var composition := []
	var current_threat := 0.0
	
	var roles_to_fill: Array = forced_roles.duplicate()
	var min_roles := int(template["min_roles"])
	var allowed_roles: Array = template["allowed_roles"]
	
	while roles_to_fill.size() < min_roles:
		var r = allowed_roles[randi() % allowed_roles.size()]
		if not r in roles_to_fill:
			roles_to_fill.append(r)
	
	# 1. Fill mandatory roles and apply AGENTS.md synergy rules
	for role in roles_to_fill:
		var options := _get_enemies_by_role(role)
		if options.is_empty(): continue
		var e_type = options[randi() % options.size()]
		var threat: float = float(THREAT_SCORES.get(e_type, 1.0))
		
		# Target a balanced count based on role
		var target_ratio := 0.20 if roles_to_fill.size() > 2 else 0.40
		var count := int(max(1, round( (budget * target_ratio) / threat )))
		
		if current_threat + (threat * count) > budget * 1.2:
			count = int(max(1, floor((budget - current_threat) / threat)))
		
		if count > 0:
			var lead_speed = float(enemies_data.get(e_type, {}).get("speed", 100.0))
			var interval = 1.0 if role == "tank" or lead_speed < 70 else 0.5
			
			composition.append({
				"type": e_type, 
				"count": count, 
				"interval": interval,
				"start_delay": 0.0
			})
			current_threat += threat * count
			
			# AGENTS.md Rule: Healers must be paired with tanks/frontliners
			if role == "frontliner" or role == "tank":
				var healers = _get_enemies_by_role("support").filter(func(x): return "healer" in x or x == "healer")
				if not healers.is_empty():
					var h_type = healers[0]
					var h_threat = float(THREAT_SCORES.get(h_type, 1.0))
					var h_count = int(max(1, count * 0.5))
					if current_threat + (h_threat * h_count) <= budget * 1.5:
						# FORMATION: Match healer speed to tank speed so they stay together
						composition.append({
							"type": h_type,
							"count": h_count,
							"interval": interval,
							"start_delay": 0.4,
							"formation": "repair_convoy"
						})
						current_threat += h_threat * h_count

			# AGENTS.md Rule: Cloaked enemies must be paired with visible enemies
			if e_type == "cloaked" or "cloaked" in e_type:
				var visible_options = _get_enemies_by_role("pressure")
				var visible = visible_options[0] if not visible_options.is_empty() else "basic"
				var v_threat = float(THREAT_SCORES.get(visible, 1.0))
				var v_count = int(max(1, count))
				# FORMATION: Cloaked unit hides inside visible cluster
				composition.append({
					"type": visible,
					"count": v_count,
					"interval": interval * 0.8,
					"start_delay": 0.1,
					"formation": "armored_cloak_mask"
				})
				current_threat += v_threat * v_count
			
			# Standard synergy if weight allows
			if randf() < float(template["synergy_weight"]) and current_threat < budget:
				var syn := _get_synergy_enemy(e_type, enemies_data)
				if syn != "" and syn != e_type:
					var s_threat: float = float(THREAT_SCORES.get(syn, 1.0))
					var s_count := int(max(1, round( (budget * 0.10) / s_threat )))
					if current_threat + (s_threat * s_count) <= budget * 1.3:
						composition.append({
							"type": syn,
							"count": s_count,
							"interval": interval * 1.2,
							"start_delay": 0.8,
							"formation": _suggest_formation_for_pair(e_type, syn)
						})
						current_threat += s_threat * s_count

	# 3. Fill remaining budget with filler or random allowed roles
	var attempts := 0
	while current_threat < budget * 0.9 and attempts < 10:
		attempts += 1
		var r = allowed_roles[randi() % allowed_roles.size()]
		var options := _get_enemies_by_role(r)
		if options.is_empty(): continue
		var e_type = options[randi() % options.size()]
		var threat: float = float(THREAT_SCORES.get(e_type, 1.0))
		if threat > (budget - current_threat): continue
		
		var count := int(max(1, floor((budget - current_threat) * 0.2 / threat)))
		if count > 0:
			composition.append({"type": e_type, "count": count})
			current_threat += threat * count

	return composition

func _generate_spawn_groups(composition: Array, wave_index: int) -> Array:
	var groups := []
	# Sort composition by role to create logical groups
	var sorted := composition.duplicate()
	sorted.sort_custom(func(a, b):
		var roles_a = ENEMY_ROLES.get(a.type, ["filler"])
		var roles_b = ENEMY_ROLES.get(b.type, ["filler"])
		var priority_a = 10; var priority_b = 10
		if "frontliner" in roles_a: priority_a = 1
		elif "support" in roles_a: priority_a = 2
		elif "pressure" in roles_a: priority_a = 3
		
		if "frontliner" in roles_b: priority_b = 1
		elif "support" in roles_b: priority_b = 2
		elif "pressure" in roles_b: priority_b = 3
		return priority_a < priority_b
	)
	
	var current_time := 0.0
	for comp in sorted:
		var interval := 1.2
		if "fast" in ENEMY_ROLES.get(comp.type, []): interval = 0.6
		elif "tank" in ENEMY_ROLES.get(comp.type, []): interval = 3.0
		
		groups.append({
			"type": comp.type,
			"count": comp.count,
			"interval": interval,
			"spawn_delay": float(comp.get("start_delay", 0.0)),
			"start_offset": float(comp.get("start_delay", 0.0)),
			"path": "lane_b" if (wave_index + groups.size()) % 2 == 1 else "default",
			"formation": str(comp.get("formation", "auto_tactical"))
		})
	return groups

func _is_composition_boring(composition: Array, wave_index: int, total_waves: int) -> bool:
	if composition.is_empty(): return true
	
	var total_enemies := 0
	var roles := {}
	var enemy_types := []
	for comp in composition:
		total_enemies += int(comp.count)
		if not enemy_types.has(comp.type):
			enemy_types.append(comp.type)
		for role in ENEMY_ROLES.get(comp.type, ["filler"]):
			roles[role] = true
			
	# Waves 4+ should never be single-type
	if wave_index >= 3 and enemy_types.size() < 2:
		return true
		
	# Check density (approximate)
	var min_density := 8
	if wave_index > total_waves / 2: min_density = 15
	if total_enemies < min_density:
		return true
		
	# Check role mix
	var template := _get_template_for_wave(wave_index, total_waves)
	var min_roles := int(WAVE_TEMPLATES.get(template, {}).get("min_roles", 1))
	if roles.size() < min_roles:
		return true
		
	return false

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
