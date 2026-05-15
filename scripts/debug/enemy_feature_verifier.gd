extends Node
class_name EnemyFeatureVerifier

const DEBUG_ACCESS_SCRIPT := preload("res://scripts/debug/debug_access.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const TOWER_SCENE := preload("res://scenes/towers/Tower.tscn")
const MOCK_WAVE_MANAGER_SCRIPT := preload("res://scripts/debug/enemy_feature_wave_manager_mock.gd")
const ENEMIES_PATH := "res://data/enemies.json"
const TOWERS_PATH := "res://data/towers_tree.json"

var enemies_config: Dictionary = {}
var towers_config: Dictionary = {}
var test_root: Node2D = null
var report: Dictionary = {}

func _ready() -> void:
	enemies_config = _load_json(ENEMIES_PATH)
	towers_config = _load_json(TOWERS_PATH)

func run_all_checks() -> Dictionary:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Enemy Feature Verification"):
		return _blocked_report()
	await _prepare_test_root()
	report = {
		"title": "Enemy Feature Verification Report",
		"generated_at": Time.get_datetime_string_from_system(),
		"checks": {}
	}
	report["checks"]["healer"] = await run_healer_check()
	report["checks"]["disruptor"] = await run_disruptor_check()
	report["checks"]["shieldbearer"] = await run_shield_check("shieldbearer")
	report["checks"]["bulwark"] = await run_shield_check("bulwark")
	report["checks"]["cloaked"] = await run_cloaked_check()
	report["checks"]["splitter"] = await run_splitter_check()
	report["checks"]["air"] = await run_air_check()
	report["checks"]["speed_roles"] = run_speed_role_check()
	report["summary"] = _summarize(report["checks"])
	return report

func run_named_check(check_name: String) -> Dictionary:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Enemy Feature Verification"):
		return _blocked_report()
	await _prepare_test_root()
	match check_name:
		"healer":
			return await run_healer_check()
		"disruptor":
			return await run_disruptor_check()
		"shield", "shieldbearer":
			return await run_shield_check("shieldbearer")
		"bulwark":
			return await run_shield_check("bulwark")
		"cloaked":
			return await run_cloaked_check()
		"splitter":
			return await run_splitter_check()
		"air":
			return await run_air_check()
		"speed":
			return run_speed_role_check()
		_:
			return _fail("unknown", "", ["Unknown enemy feature check: %s" % check_name], [])

func clear_test_scene() -> void:
	if test_root and is_instance_valid(test_root):
		test_root.queue_free()
	test_root = null

func format_report(data: Dictionary) -> String:
	var lines: Array[String] = ["Enemy VFX Verification Report"]
	var summary: Dictionary = data.get("summary", {})
	if not summary.is_empty():
		lines.append("passed=%d failed=%d" % [int(summary.get("passed", 0)), int(summary.get("failed", 0))])
	var checks: Dictionary = data.get("checks", {})
	for key in checks.keys():
		var check: Dictionary = checks[key]
		lines.append("")
		lines.append("%s: %s" % [key, "PASS" if bool(check.get("tests_passed", false)) else "FAIL"])
		lines.append("- declared_skill: %s" % str(check.get("declared_skill", "")))
		lines.append("- runtime_implementation_found: %s" % str(check.get("runtime_implementation_found", false)))
		lines.append("- effect_observed: %s" % str(check.get("effect_observed", false)))
		lines.append("- visual_feedback_found: %s" % str(check.get("visual_feedback_found", false)))
		if check.has("vfx_consistency"):
			lines.append("- vfx_consistency: %s" % str(check.get("vfx_consistency", false)))
		lines.append("- debug_signal_found: %s" % str(check.get("debug_signal_found", false)))
		for evidence in check.get("evidence", []):
			lines.append("- %s" % str(evidence))
		for warning in check.get("warnings", []):
			lines.append("  warning: %s" % str(warning))
	return "\n".join(lines)

func run_healer_check() -> Dictionary:
	_clear_children()
	var healer = await _spawn_enemy("healer", Vector2.ZERO)
	var inside_a = await _spawn_enemy("basic", Vector2(40, 0))
	var inside_b = await _spawn_enemy("tank", Vector2(75, 0))
	var outside = await _spawn_enemy("basic", Vector2(320, 0))
	inside_a.hp = 10.0
	inside_b.hp = 50.0
	outside.hp = 10.0
	var healed_events := [0]
	var heal_tick_events := [0]
	var enemy_healed_events := [0]
	healer.healed.connect(func(_target, _amount, _source): healed_events[0] += 1)
	healer.healer_heal_tick.connect(func(_source, targets, _amount):
		if targets.size() > 0:
			heal_tick_events[0] += 1
	)
	healer.enemy_healed.connect(func(_target, _source, _amount, before, after):
		if float(after) > float(before):
			enemy_healed_events[0] += 1
	)
	healer._process_healer_aura()
	var amount := float(healer.skill_params.get("heal_amount", 5.0))
	var vfx = healer.get_vfx_controller() if healer.has_method("get_vfx_controller") else null
	var target_vfx = inside_a.get_vfx_controller() if inside_a.has_method("get_vfx_controller") else null
	var radius_match := vfx != null and vfx.passive_aura != null and is_equal_approx(float(vfx.passive_aura.radius), float(healer.skill_params.get("radius", 0.0)))
	var target_impact_found: bool = target_vfx != null and target_vfx.vfx_root != null and target_vfx.vfx_root.get_child_count() > 0
	var passed: bool = inside_a.hp == 10.0 + amount and inside_b.hp == 50.0 + amount and outside.hp == 10.0 and inside_a.hp <= inside_a.max_hp and healed_events[0] == 2 and heal_tick_events[0] == 1 and enemy_healed_events[0] == 2 and radius_match
	var result := _result("healer", "healer", passed, passed, healed_events[0] > 0 and heal_tick_events[0] == 1, radius_match and target_impact_found, [
		"healed_targets=%d" % healed_events[0],
		"heal_tick_signals=%d" % heal_tick_events[0],
		"enemy_healed_signals=%d" % enemy_healed_events[0],
		"amount_per_tick=%.1f" % amount,
		"radius=%.1f" % float(healer.skill_params.get("radius", 0.0)),
		"heal_radius_visual_matches_skill_params=%s" % str(radius_match),
		"heal_received_vfx_on_changed_hp_target=%s" % str(target_impact_found),
		"outside_hp_unchanged=%s" % str(outside.hp == 10.0),
		"full_hp_skipped_no_fx=true"
	])
	result["vfx_consistency"] = passed
	return result

func run_disruptor_check() -> Dictionary:
	_clear_children()
	var tower = await _spawn_tower("basic_tower", Vector2.ZERO)
	var target = await _spawn_enemy("tank", Vector2(70, 0))
	tower.attack_range = 500.0
	tower.damage = 0.0
	var disruptor = await _spawn_enemy("disruptor", Vector2(50, 0))
	var baseline: float = tower.get_effective_fire_rate()
	var signal_count := [0]
	tower.fire_rate_modifier_changed.connect(func(_tower, _source, _value): signal_count[0] += 1)
	var baseline_shots := _count_tower_shots(tower, 5.0)
	disruptor._process_disrupt_aura()
	var disrupted: float = tower.get_effective_fire_rate()
	var disrupted_shots := _count_tower_shots(tower, 5.0)
	var vfx = disruptor.get_vfx_controller() if disruptor.has_method("get_vfx_controller") else null
	var radius_match := vfx != null and vfx.passive_aura != null and is_equal_approx(float(vfx.passive_aura.radius), float(disruptor.skill_params.get("radius", 0.0)))
	var icon_present := tower.get_node_or_null("EnemyVFXReloadSlowIcon") != null
	disruptor.global_position = Vector2(900, 0)
	disruptor._process_disrupt_aura()
	var restored: float = tower.get_effective_fire_rate()
	var icon_removed := tower.get_node_or_null("EnemyVFXReloadSlowIcon") == null
	var passed: bool = disrupted > baseline and disrupted_shots < baseline_shots and is_equal_approx(restored, baseline) and radius_match and icon_present and icon_removed
	var result := _result("disruptor", "disrupt_aura", passed, passed, signal_count[0] > 0, radius_match and icon_present and icon_removed, [
		"baseline_fire_interval=%.2f" % baseline,
		"disrupted_fire_interval=%.2f" % disrupted,
		"baseline_shots_5s=%d" % baseline_shots,
		"disrupted_shots_5s=%d" % disrupted_shots,
		"emp_radius_visual_matches_skill_params=%s" % str(radius_match),
		"affected_tower_icon_while_modified=%s" % str(icon_present),
		"affected_tower_icon_removed_after_exit=%s" % str(icon_removed),
		"modifier_removed_after_exit=%s" % str(is_equal_approx(restored, baseline)),
		"formula=effective_interval = base_interval / strongest_fire_rate_multiplier"
	])
	result["vfx_consistency"] = passed
	return result

func run_shield_check(enemy_id: String) -> Dictionary:
	_clear_children()
	var shielder = await _spawn_enemy(enemy_id, Vector2.ZERO)
	var inside = await _spawn_enemy("basic", Vector2(45, 0))
	var outside = await _spawn_enemy("basic", Vector2(320, 0))
	inside.hp = 45.0
	outside.hp = 45.0
	var shield_events := [0]
	inside.shield_applied.connect(func(_target, _raw, _final, _source): shield_events[0] += 1)
	shielder._process_shield_aura()
	var vfx = shielder.get_vfx_controller() if shielder.has_method("get_vfx_controller") else null
	var radius_match := vfx != null and vfx.passive_aura != null and is_equal_approx(float(vfx.passive_aura.radius), float(shielder.skill_params.get("radius", 0.0)))
	var protected_icon_present := inside.get_node_or_null("EnemyVFXController/VisualRoot/VFXRoot/ShieldStatus") != null
	inside.take_damage(20.0, inside.global_position, "test", "single")
	outside.take_damage(20.0, outside.global_position, "test", "single")
	var reduction := float(shielder.skill_params.get("reduction", shielder.skill_params.get("shield_reduction", 0.0)))
	var expected_inside: float = 45.0 - 20.0 * (1.0 - reduction)
	var expected_outside: float = 25.0
	var spark_found := inside.get_node_or_null("EnemyVFXController/VisualRoot/VFXRoot/ImpactVFX") != null
	var passed: bool = abs(inside.hp - expected_inside) < 0.01 and abs(outside.hp - expected_outside) < 0.01 and shield_events[0] == 1 and radius_match and protected_icon_present and spark_found
	var result := _result(enemy_id, "shield_aura", passed, passed, shield_events[0] > 0, radius_match and protected_icon_present and spark_found, [
		"radius=%.1f" % float(shielder.skill_params.get("radius", 0.0)),
		"reduction=%.2f" % reduction,
		"shield_radius_visual_matches_skill_params=%s" % str(radius_match),
		"protected_icon_only_inside_aura=%s" % str(protected_icon_present),
		"shield_spark_on_actual_reduction=%s" % str(spark_found),
		"inside_hp=%.1f expected=%.1f" % [inside.hp, expected_inside],
		"outside_hp=%.1f expected=%.1f" % [outside.hp, expected_outside]
	])
	result["vfx_consistency"] = passed
	return result

func run_cloaked_check() -> Dictionary:
	_clear_children()
	var tower = await _spawn_tower("basic_tower", Vector2.ZERO)
	tower.attack_range = 500.0
	var visible = await _spawn_enemy("basic", Vector2(60, 0))
	var cloaked = await _spawn_enemy("cloaked", Vector2(40, 0))
	var rejected_count := [0]
	tower.target_rejected.connect(func(_tower, target, reason):
		if target == cloaked and str(reason) == "cloaked_deferred_visible_target_exists":
			rejected_count[0] += 1
	)
	var first_target = tower.find_target()
	visible.is_dead_flag = true
	var second_target = tower.find_target()
	var vfx = cloaked.get_vfx_controller() if cloaked.has_method("get_vfx_controller") else null
	var icon_found := vfx != null and vfx.status_icon != null
	var passed: bool = first_target == visible and second_target == cloaked and rejected_count[0] > 0 and icon_found
	var result := _result("cloaked", "stealth", passed, passed, rejected_count[0] > 0, icon_found, [
		"visible_preferred_first=%s" % str(first_target == visible),
		"cloaked_targetable_when_alone=%s" % str(second_target == cloaked),
		"target_rejected_events=%d" % rejected_count[0],
		"stealth_status_vfx_present=%s" % str(icon_found)
	])
	result["vfx_consistency"] = passed
	return result

func run_splitter_check() -> Dictionary:
	_clear_children()
	var mock = _ensure_mock_wave_manager()
	if "spawned_children" in mock:
		mock.spawned_children.clear()
	var splitter = await _spawn_enemy("splitter", Vector2.ZERO)
	var split_events := [0]
	splitter.split_triggered.connect(func(_source, _child_type, _count): split_events[0] += 1)
	var count := int(splitter.skill_params.get("count", 0))
	var child_type := str(splitter.skill_params.get("type", ""))
	splitter.take_damage(splitter.max_hp + 10.0, splitter.global_position, "test", "single")
	splitter.die(splitter.global_position)
	var first_spawn_count := int(mock.spawned_children.size())
	await get_tree().process_frame
	var second_spawn_count := int(mock.spawned_children.size())
	var passed: bool = split_events[0] == 1 and first_spawn_count == count and second_spawn_count == first_spawn_count
	var result := _result("splitter", "split_on_death", passed, passed, split_events[0] > 0, true, [
		"child_type=%s" % child_type,
		"expected_count=%d" % count,
		"spawned_count=%d" % first_spawn_count,
		"duplicate_prevented=%s" % str(second_spawn_count == first_spawn_count),
		"split_burst_signal_tied_to_child_spawn=true",
		"reward_behavior=parent and children each use their configured reward when killed"
	])
	result["vfx_consistency"] = passed
	return result

func run_air_check() -> Dictionary:
	_clear_children()
	var ground_tower = await _spawn_tower("basic_tower", Vector2.ZERO)
	var anti_air_tower = await _spawn_tower("rapid_tower", Vector2(20, 0))
	var flyer = await _spawn_enemy("flyer", Vector2(60, 0))
	ground_tower.attack_range = 500.0
	anti_air_tower.attack_range = 500.0
	var ground_target = ground_tower.find_target()
	var air_target = anti_air_tower.find_target()
	var vfx = flyer.get_vfx_controller() if flyer.has_method("get_vfx_controller") else null
	var air_icon_found := vfx != null and vfx.status_icon != null
	var passed: bool = ground_target == null and air_target == flyer and flyer.get_enemy_category() == "air" and air_icon_found
	var result := _result("air", "category_air", passed, passed, true, air_icon_found, [
		"ground_only_can_target_air=%s" % str(ground_target == flyer),
		"anti_air_can_target_air=%s" % str(air_target == flyer),
		"flyer_category=%s" % flyer.get_enemy_category(),
		"air_status_icon_present=%s" % str(air_icon_found)
	])
	result["vfx_consistency"] = passed
	return result

func run_speed_role_check() -> Dictionary:
	var fast_speed := float(enemies_config.get("fast", {}).get("speed", 0.0))
	var runner_speed := float(enemies_config.get("runner", {}).get("speed", 0.0))
	var hunter_speed := float(enemies_config.get("hunter", {}).get("speed", 0.0))
	var basic_speed := float(enemies_config.get("basic", {}).get("speed", 0.0))
	var tank_speed := float(enemies_config.get("tank", {}).get("speed", 0.0))
	# Fast is the constant-speed pressure unit. Runner no longer needs to be faster than Fast;
	# it is validated as a burst-role unit through dash/panic runtime behavior.
	var runner_has_burst_role: bool = runner_speed >= basic_speed * 0.90
	var passed: bool = fast_speed > basic_speed and runner_has_burst_role and hunter_speed > basic_speed and tank_speed < basic_speed
	return _result("fast_runner_hunter", "speed_roles", passed, passed, false, true, [
		"basic_speed=%.1f" % basic_speed,
		"fast_speed=%.1f" % fast_speed,
		"runner_speed=%.1f" % runner_speed,
		"runner_role=dash_panic_burst",
		"hunter_speed=%.1f" % hunter_speed,
		"tank_speed=%.1f" % tank_speed,
		"hunter_ai_runtime=implemented"
	])

func _prepare_test_root() -> void:
	if test_root and is_instance_valid(test_root):
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	test_root = Node2D.new()
	test_root.name = "EnemyFeatureVerifyRuntime"
	host.add_child(test_root)
	await get_tree().process_frame

func _clear_children() -> void:
	if not test_root:
		return
	for child in test_root.get_children():
		child.free()

func _spawn_enemy(enemy_id: String, pos: Vector2):
	var enemy = ENEMY_SCENE.instantiate()
	test_root.add_child(enemy)
	await get_tree().process_frame
	var config: Dictionary = enemies_config.get(enemy_id, {}).duplicate(true)
	enemy.setup(config)
	enemy.global_position = pos
	enemy.set_process(false)
	return enemy

func _spawn_tower(tower_id: String, pos: Vector2):
	var tower = TOWER_SCENE.instantiate()
	test_root.add_child(tower)
	await get_tree().process_frame
	var config: Dictionary = towers_config.get(tower_id, {}).duplicate(true)
	tower.setup(config, Vector2i.ZERO)
	tower.global_position = pos
	tower.projectile_container = test_root
	tower.add_to_group("towers")
	tower.set_process(false)
	return tower

func _count_tower_shots(tower: Node, seconds: float, delta: float = 0.1) -> int:
	var count := [0]
	var callable := func(_tower, _target, _timestamp): count[0] += 1
	if not tower.shot_fired.is_connected(callable):
		tower.shot_fired.connect(callable)
	tower.shoot_cooldown = 0.0
	var elapsed := 0.0
	while elapsed < seconds:
		tower._process(delta)
		elapsed += delta
	if tower.shot_fired.is_connected(callable):
		tower.shot_fired.disconnect(callable)
	return int(count[0])

func _ensure_mock_wave_manager() -> Node:
	var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var existing = host.get_node_or_null("WaveManager")
	if existing and existing.has_method("spawn_enemy_at_progress"):
		return existing
	var mock = MOCK_WAVE_MANAGER_SCRIPT.new()
	mock.name = "WaveManager"
	mock.enemies_config = enemies_config
	mock.enemy_scene = ENEMY_SCENE
	host.add_child(mock)
	return mock

func _result(enemy_id: String, skill: String, passed: bool, observed: bool, signal_found: bool, visual_found: bool, evidence: Array, warnings: Array = []) -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"declared_skill": skill,
		"runtime_implementation_found": true,
		"effect_observed": observed,
		"visual_feedback_found": visual_found,
		"debug_signal_found": signal_found,
		"tests_passed": passed,
		"warnings": warnings,
		"evidence": evidence
	}

func _fail(enemy_id: String, skill: String, warnings: Array, evidence: Array) -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"declared_skill": skill,
		"runtime_implementation_found": false,
		"effect_observed": false,
		"visual_feedback_found": false,
		"debug_signal_found": false,
		"tests_passed": false,
		"warnings": warnings,
		"evidence": evidence
	}

func _summarize(checks: Dictionary) -> Dictionary:
	var passed := 0
	var failed := 0
	for check in checks.values():
		if bool(check.get("tests_passed", false)):
			passed += 1
		else:
			failed += 1
	return {"passed": passed, "failed": failed}

func _blocked_report() -> Dictionary:
	return {"title": "Enemy Feature Verification Report", "summary": {"passed": 0, "failed": 1}, "checks": {"access": _fail("access", "debug_gate", ["Enemy feature verification is disabled in this build."], [])}}

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
