extends Node
class_name TowerAbilityVerifier

const DEBUG_ACCESS_SCRIPT := preload("res://scripts/debug/debug_access.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectiles/Projectile.tscn")
const TOWER_SCENE := preload("res://scenes/towers/Tower.tscn")
const WAVE_MANAGER_SCRIPT := preload("res://scripts/managers/wave_manager.gd")
const TOWERS_PATH := "res://data/towers.json"

class FakeEnemy:
	extends Node2D

	var hp: float = 1000.0
	var damage_taken: float = 0.0
	var damage_calls: int = 0
	var slow_percent: float = 0.0
	var slow_duration: float = 0.0
	var vulnerability_multiplier: float = 1.0
	var vulnerability_duration: float = 0.0
	var armor_reduction_percent: float = 0.0
	var armor_reduction_duration: float = 0.0
	var root_snare_percent: float = 0.0
	var root_duration: float = 0.0
	var path_progress: float = 0.5
	var enemy_category: String = "land"
	var dead: bool = false

	func is_alive() -> bool:
		return not dead and hp > 0.0

	func take_damage(amount: float, _hit_global: Vector2 = Vector2.ZERO, _source_id: String = "", _attack_type: String = "") -> void:
		damage_taken += amount
		damage_calls += 1
		hp -= amount * vulnerability_multiplier
		if hp <= 0.0:
			dead = true

	func apply_slow(percent: float, duration: float) -> void:
		if percent >= slow_percent:
			slow_percent = percent
			slow_duration = duration

	func apply_vulnerability(multiplier: float, duration: float) -> void:
		if multiplier >= vulnerability_multiplier:
			vulnerability_multiplier = multiplier
			vulnerability_duration = duration

	func apply_damage_amp(multiplier: float, duration: float) -> void:
		apply_vulnerability(multiplier, duration)

	func apply_armor_reduction(percent: float, duration: float) -> void:
		if percent >= armor_reduction_percent:
			armor_reduction_percent = percent
			armor_reduction_duration = duration

	func apply_root(duration: float, snare_percent: float = 1.0) -> void:
		if snare_percent >= root_snare_percent:
			root_snare_percent = snare_percent
			root_duration = duration

	func get_enemy_category() -> String:
		return enemy_category

	func get_path_progress() -> float:
		return path_progress

	func get_priority_score() -> float:
		return 1.0

	func get_hit_anchor_global_position() -> Vector2:
		return global_position

	func get_aim_point() -> Vector2:
		return global_position

class MockGameManager:
	extends Node

	var is_paused: bool = false
	var is_game_over: bool = false
	var battle_telemetry = null
	var gold_added: int = 0
	var lives_added: int = 0

	func add_gold(amount: int) -> void:
		gold_added += amount

	func add_lives(amount: int, _source_id: String = "") -> void:
		lives_added += amount

var towers_config: Dictionary = {}
var test_root: Node2D = null
var report: Dictionary = {}

func _ready() -> void:
	towers_config = _load_json(TOWERS_PATH)

func run_all_checks() -> Dictionary:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Tower Ability Verification"):
		return _blocked_report()
	await _prepare_test_root()
	report = {
		"title": "Tower Ability Verification Report",
		"generated_at": Time.get_datetime_string_from_system(),
		"checks": {}
	}
	report["checks"]["projectile_single"] = run_projectile_single_check()
	report["checks"]["projectile_splash"] = run_projectile_splash_check()
	report["checks"]["projectile_splash_slow"] = run_projectile_splash_slow_check()
	report["checks"]["projectile_status_payload"] = run_projectile_status_payload_check()
	report["checks"]["projectile_slow"] = run_projectile_slow_check()
	report["checks"]["projectile_chain"] = run_projectile_chain_check()
	report["checks"]["tower_projectile_vulnerability_forwarding"] = await run_tower_projectile_vulnerability_forwarding_check()
	report["checks"]["corrosion_family_armor_reduction"] = await run_corrosion_family_armor_reduction_check()
	report["checks"]["polar_family_root"] = await run_polar_family_root_check()
	report["checks"]["enchantment_family_armor_reduction"] = await run_enchantment_family_armor_reduction_check()
	report["checks"]["disease_family_damage_amp"] = await run_aura_damage_amp_family_check("disease_t1")
	report["checks"]["voodoo_family_damage_amp"] = await run_aura_damage_amp_family_check("voodoo_t1")
	report["checks"]["aura_vulnerability"] = await run_aura_vulnerability_check()
	report["checks"]["support_auras"] = await run_support_aura_check()
	report["checks"]["trickery_clone"] = await run_trickery_clone_check()
	report["checks"]["economy_kill_effects"] = await run_economy_kill_effect_check()
	report["checks"]["enemy_status_layer"] = await run_enemy_status_layer_check()
	# Control-family wiring
	report["checks"]["nova_burn_dot"] = await run_tower_status_effect_check("nova_t1", "dot")
	report["checks"]["roots_snare_and_dot"] = await run_roots_family_check()
	report["checks"]["muck_poison_and_armor"] = await run_muck_family_check()
	report["checks"]["windstorm_stagger"] = await run_tower_status_effect_check("windstorm_t1", "root")
	# Special damage-family wiring
	report["checks"]["quark_impact_root"] = await run_tower_status_effect_check("quark_t1", "root")
	report["checks"]["quaker_seismic_shock"] = await run_quaker_check()
	report["checks"]["flesh_golem_vulnerability"] = await run_tower_status_effect_check("flesh_golem_t1", "damage_amp")
	report["checks"]["flamethrower_burn_dot"] = await run_tower_status_effect_check("flamethrower_t1", "dot")
	report["checks"]["impulse_distance_scaling"] = await run_impulse_distance_scaling_check()
	report["checks"]["zealot_hit_streak"] = await run_zealot_streak_check()
	report["checks"]["laser_pierce"] = await run_laser_pierce_check()
	# Control displacement fix
	report["checks"]["hit_pulse_no_path_displacement"] = await run_hit_pulse_no_path_displacement_check()
	report["summary"] = _summarize(report["checks"])
	return report

func clear_test_scene() -> void:
	if test_root and is_instance_valid(test_root):
		test_root.queue_free()
	test_root = null

func format_report(data: Dictionary) -> String:
	var lines: Array[String] = ["Tower Ability Verification Report"]
	var summary: Dictionary = data.get("summary", {})
	if not summary.is_empty():
		lines.append("passed=%d failed=%d" % [int(summary.get("passed", 0)), int(summary.get("failed", 0))])
	var checks: Dictionary = data.get("checks", {})
	for key in checks.keys():
		var check: Dictionary = checks[key]
		lines.append("")
		lines.append("%s: %s" % [key, "PASS" if bool(check.get("tests_passed", false)) else "FAIL"])
		lines.append("- mechanic: %s" % str(check.get("mechanic", "")))
		lines.append("- runtime_implementation_found: %s" % str(check.get("runtime_implementation_found", false)))
		lines.append("- effect_observed: %s" % str(check.get("effect_observed", false)))
		for evidence in check.get("evidence", []):
			lines.append("- %s" % str(evidence))
		for warning in check.get("warnings", []):
			lines.append("  warning: %s" % str(warning))
	return "\n".join(lines)

func run_projectile_single_check() -> Dictionary:
	_clear_children()
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	var projectile := _spawn_projectile(enemy, 25.0, "single", 0.0)
	projectile.hit_target()
	var passed := enemy.damage_calls == 1 and enemy.damage_taken > 0.0
	return _result("projectile_single", passed, passed, [
		"damage_calls=%d" % enemy.damage_calls,
		"damage_taken=%.1f" % enemy.damage_taken
	])

func run_projectile_splash_check() -> Dictionary:
	_clear_children()
	var inside := _spawn_fake_enemy(Vector2(20, 0))
	var outside := _spawn_fake_enemy(Vector2(200, 0))
	var projectile := _spawn_projectile(inside, 40.0, "splash", 80.0)
	projectile.apply_area_effect(Vector2.ZERO)
	var passed := inside.damage_calls == 1 and inside.damage_taken > 0.0 and outside.damage_calls == 0
	return _result("projectile_splash", passed, passed, [
		"inside_damage_calls=%d" % inside.damage_calls,
		"inside_damage=%.1f" % inside.damage_taken,
		"outside_damage_calls=%d" % outside.damage_calls,
		"radius=80"
	])

func run_projectile_splash_slow_check() -> Dictionary:
	_clear_children()
	var inside := _spawn_fake_enemy(Vector2(20, 0))
	var projectile := _spawn_projectile(inside, 40.0, "splash", 80.0, 0.20, 1.5)
	projectile.apply_area_effect(Vector2.ZERO)
	var passed := inside.damage_calls == 1 and inside.slow_percent >= 0.20 and inside.slow_duration >= 1.5
	return _result("projectile_splash_slow", passed, passed, [
		"damage_calls=%d" % inside.damage_calls,
		"slow_percent=%.2f" % inside.slow_percent,
		"slow_duration=%.1f" % inside.slow_duration,
		"radius=80"
	])

func run_projectile_status_payload_check() -> Dictionary:
	_clear_children()
	var inside := _spawn_fake_enemy(Vector2(20, 0))
	var projectile := _spawn_projectile(inside, 40.0, "splash", 80.0)
	projectile.setup_status_effects([{"type": "armor_reduction", "percent": 0.30, "duration": 2.0}])
	projectile.apply_area_effect(Vector2.ZERO)
	var passed := inside.armor_reduction_percent >= 0.30 and inside.armor_reduction_duration >= 2.0
	return _result("projectile_status_payload", passed, passed, [
		"armor_reduction_percent=%.2f" % inside.armor_reduction_percent,
		"armor_reduction_duration=%.1f" % inside.armor_reduction_duration
	])

func run_projectile_slow_check() -> Dictionary:
	_clear_children()
	var inside := _spawn_fake_enemy(Vector2(20, 0))
	var projectile := _spawn_projectile(inside, 10.0, "slow", 80.0, 0.35, 2.0)
	projectile.apply_area_effect(Vector2.ZERO)
	var passed := inside.damage_calls == 1 and inside.slow_percent >= 0.35 and inside.slow_duration >= 2.0
	return _result("projectile_slow", passed, passed, [
		"damage_calls=%d" % inside.damage_calls,
		"slow_percent=%.2f" % inside.slow_percent,
		"slow_duration=%.1f" % inside.slow_duration
	])

func run_projectile_chain_check() -> Dictionary:
	_clear_children()
	var first := _spawn_fake_enemy(Vector2(20, 0))
	first.path_progress = 0.8
	var second := _spawn_fake_enemy(Vector2(65, 0))
	second.path_progress = 0.7
	var projectile := _spawn_projectile(first, 30.0, "chain", 0.0)
	projectile.global_position = Vector2.ZERO
	projectile.setup_chain(1, 90.0, 0.5)
	var before_children := test_root.get_child_count()
	projectile.hit_target()
	var chain_projectile_found := false
	for child in test_root.get_children():
		if child != projectile and child.get_script() == projectile.get_script():
			var target_value = child.get("target")
			if target_value == second:
				chain_projectile_found = true
				break
	var passed := first.damage_calls == 1 and chain_projectile_found and test_root.get_child_count() > before_children
	return _result("projectile_chain", passed, passed, [
		"first_damage_calls=%d" % first.damage_calls,
		"chain_projectile_spawned=%s" % str(chain_projectile_found),
		"chain_range=90",
		"chain_falloff=0.50"
	])

func run_tower_projectile_vulnerability_forwarding_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("basic_tower_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	tower.current_target = enemy
	tower.attack_type = "chain"
	tower.vulnerability_percent = 0.33
	tower.vulnerability_duration = 2.25
	tower.shoot()
	var forwarded_percent := 0.0
	var forwarded_duration := 0.0
	var projectile_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy:
			continue
		if child.has_method("setup_chain") and child.has_method("hit_target"):
			projectile_found = true
			forwarded_percent = float(child.get("vulnerability_percent"))
			forwarded_duration = float(child.get("vulnerability_duration"))
			break
	var passed := projectile_found and forwarded_percent >= 0.33 and forwarded_duration >= 2.25
	return _result("tower_projectile_vulnerability_forwarding", passed, passed, [
		"projectile_found=%s" % str(projectile_found),
		"forwarded_vulnerability_percent=%.2f" % forwarded_percent,
		"forwarded_vulnerability_duration=%.2f" % forwarded_duration
	])

func run_corrosion_family_armor_reduction_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("corrosion_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	tower.current_target = enemy
	tower.shoot()
	var projectile_found := false
	var status_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy:
			continue
		if child.has_method("setup_chain") and child.has_method("hit_target"):
			projectile_found = true
			var effects: Array = child.get("status_effects")
			for effect in effects:
				if effect is Dictionary and str(effect.get("type", "")) == "armor_reduction":
					status_found = true
					break
			child.apply_area_effect(Vector2.ZERO)
			break
	var passed := projectile_found and status_found and enemy.armor_reduction_percent >= float(tower.slow_percent) and enemy.armor_reduction_duration >= float(tower.slow_duration)
	return _result("corrosion_family_armor_reduction", passed, passed, [
		"projectile_found=%s" % str(projectile_found),
		"status_payload_found=%s" % str(status_found),
		"armor_reduction_percent=%.2f" % enemy.armor_reduction_percent,
		"expected_percent=%.2f" % float(tower.slow_percent),
		"armor_reduction_duration=%.1f" % enemy.armor_reduction_duration,
		"expected_duration=%.1f" % float(tower.slow_duration)
	])

func run_polar_family_root_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("polar_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	tower.current_target = enemy
	tower.shoot()
	var projectile_found := false
	var status_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy:
			continue
		if child.has_method("setup_chain") and child.has_method("hit_target"):
			projectile_found = true
			var effects: Array = child.get("status_effects")
			for effect in effects:
				if effect is Dictionary and str(effect.get("type", "")) == "root":
					status_found = true
					break
			child.apply_area_effect(Vector2.ZERO)
			break
	var passed := projectile_found and status_found and enemy.root_snare_percent >= float(tower.slow_percent) and enemy.root_duration >= float(tower.slow_duration)
	return _result("polar_family_root", passed, passed, [
		"projectile_found=%s" % str(projectile_found),
		"status_payload_found=%s" % str(status_found),
		"root_snare_percent=%.2f" % enemy.root_snare_percent,
		"expected_percent=%.2f" % float(tower.slow_percent),
		"root_duration=%.1f" % enemy.root_duration,
		"expected_duration=%.1f" % float(tower.slow_duration)
	])

func run_enchantment_family_armor_reduction_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("enchantment_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	await get_tree().process_frame
	tower.attack_range = 160.0
	tower._perform_aura_attack()
	var expected_percent := float(tower.vulnerability_percent)
	var expected_duration := float(tower.vulnerability_duration)
	var direct_vulnerability_skipped := is_equal_approx(enemy.vulnerability_multiplier, 1.0)
	var passed := enemy.damage_calls == 1 and direct_vulnerability_skipped and enemy.armor_reduction_percent >= expected_percent and enemy.armor_reduction_duration >= expected_duration
	return _result("enchantment_family_armor_reduction", passed, passed, [
		"damage_calls=%d" % enemy.damage_calls,
		"direct_vulnerability_skipped=%s" % str(direct_vulnerability_skipped),
		"armor_reduction_percent=%.2f" % enemy.armor_reduction_percent,
		"expected_percent=%.2f" % expected_percent,
		"armor_reduction_duration=%.1f" % enemy.armor_reduction_duration,
		"expected_duration=%.1f" % expected_duration
	])

func run_aura_damage_amp_family_check(tower_id: String) -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower(tower_id, Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	await get_tree().process_frame
	tower.attack_range = 180.0
	tower._perform_aura_attack()
	var expected_multiplier := 1.0 + float(tower.vulnerability_percent)
	var expected_duration := float(tower.vulnerability_duration)
	var passed := enemy.damage_calls == 1 and enemy.vulnerability_multiplier >= expected_multiplier and enemy.vulnerability_duration >= expected_duration
	return _result("%s_damage_amp" % tower_id, passed, passed, [
		"damage_calls=%d" % enemy.damage_calls,
		"damage_amp_multiplier=%.2f" % enemy.vulnerability_multiplier,
		"expected_multiplier=%.2f" % expected_multiplier,
		"damage_amp_duration=%.1f" % enemy.vulnerability_duration,
		"expected_duration=%.1f" % expected_duration
	])

func run_aura_vulnerability_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("darkness_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(40, 0))
	await get_tree().process_frame
	tower.attack_range = 160.0
	tower.damage = 1.0
	tower.vulnerability_percent = 0.25
	tower.vulnerability_duration = 2.0
	var enemies_in_range: int = int(tower.get_enemies_in_range().size())
	tower._perform_aura_attack()
	var passed := enemy.damage_calls == 1 and enemy.vulnerability_multiplier >= 1.25 and enemy.vulnerability_duration >= 2.0
	return _result("aura_vulnerability", passed, passed, [
		"enemies_in_range_before_attack=%d" % enemies_in_range,
		"damage_calls=%d" % enemy.damage_calls,
		"vulnerability_multiplier=%.2f" % enemy.vulnerability_multiplier,
		"vulnerability_duration=%.1f" % enemy.vulnerability_duration
	])

func run_support_aura_check() -> Dictionary:
	_clear_children()
	var target: Node2D = await _spawn_tower("basic_tower_t1", Vector2(40, 0))
	var well: Node2D = await _spawn_tower("well_t1", Vector2.ZERO)
	var blacksmith: Node2D = await _spawn_tower("blacksmith_t1", Vector2(0, 70))
	well.attack_range = 180.0
	blacksmith.attack_range = 180.0
	target.damage = 20.0
	target.fire_rate = 1.0
	well._process_support_aura(1.0)
	blacksmith._process_support_aura(1.0)
	var effective_fire_rate: float = float(target.get_effective_fire_rate())
	var effective_damage: float = float(target.get_effective_damage())
	var passed: bool = effective_fire_rate < float(target.fire_rate) and effective_damage > float(target.damage)
	return _result("support_auras", passed, passed, [
		"base_fire_rate=%.2f" % target.fire_rate,
		"effective_fire_rate=%.2f" % effective_fire_rate,
		"base_damage=%.1f" % target.damage,
		"effective_damage=%.1f" % effective_damage,
		"well_targets=%d" % int(well.support_targets.size()),
		"blacksmith_targets=%d" % int(blacksmith.support_targets.size())
	])

func run_trickery_clone_check() -> Dictionary:
	_clear_children()
	var target: Node2D = await _spawn_tower("basic_tower_t1", Vector2(40, 0))
	var trickery: Node2D = await _spawn_tower("trickery_t1", Vector2.ZERO)
	trickery.attack_range = 180.0
	target.damage = 20.0
	var assigned: bool = bool(trickery.try_set_manual_clone_target(target))
	var effective_damage: float = float(target.get_effective_damage())
	var tag: String = str(target.get_active_damage_bonus_tag())
	var passed: bool = assigned and trickery.get_clone_current_target() == target and effective_damage > float(target.damage) and tag == "clone"
	return _result("trickery_clone", passed, passed, [
		"assigned=%s" % str(assigned),
		"clone_target_matches=%s" % str(trickery.get_clone_current_target() == target),
		"base_damage=%.1f" % target.damage,
		"effective_damage=%.1f" % effective_damage,
		"active_damage_bonus_tag=%s" % tag
	])

func run_economy_kill_effect_check() -> Dictionary:
	_clear_children()
	var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var existing_game_manager = host.get_node_or_null("GameManager")
	if existing_game_manager:
		existing_game_manager.queue_free()
		await get_tree().process_frame
	var game_manager := MockGameManager.new()
	game_manager.name = "GameManager"
	host.add_child(game_manager)
	var wave_manager := WAVE_MANAGER_SCRIPT.new()
	wave_manager.name = "WaveManager"
	host.add_child(wave_manager)
	await get_tree().process_frame
	wave_manager._apply_economy_tower_kill_effects("gold_t1", 10)
	for _i in range(6):
		wave_manager._apply_economy_tower_kill_effects("life_t1", 10)
	var passed := game_manager.gold_added == 2 and game_manager.lives_added == 1
	wave_manager.queue_free()
	game_manager.queue_free()
	return _result("economy_kill_effects", passed, passed, [
		"gold_t1_base_reward=10",
		"gold_added=%d" % game_manager.gold_added,
		"life_t1_kills_applied=6",
		"lives_added=%d" % game_manager.lives_added
	])

func run_enemy_status_layer_check() -> Dictionary:
	_clear_children()
	var amp_enemy: Node2D = await _spawn_real_enemy(Vector2.ZERO)
	amp_enemy.hp = 100.0
	amp_enemy.max_hp = 100.0
	amp_enemy.apply_damage_amp(1.5, 1.0)
	amp_enemy.take_damage(10.0, amp_enemy.global_position, "status_test", "single")
	var amp_hp := float(amp_enemy.hp)

	var armor_enemy: Node2D = await _spawn_real_enemy(Vector2(40, 0))
	armor_enemy.hp = 100.0
	armor_enemy.max_hp = 100.0
	armor_enemy.apply_armor_reduction(0.25, 1.0)
	armor_enemy.take_damage(10.0, armor_enemy.global_position, "status_test", "single")
	var armor_hp := float(armor_enemy.hp)

	var dot_enemy: Node2D = await _spawn_real_enemy(Vector2(80, 0))
	dot_enemy.hp = 100.0
	dot_enemy.max_hp = 100.0
	dot_enemy.apply_damage_over_time(5.0, 2.0, "dot_test", "dot")
	dot_enemy._process(1.0)
	var dot_hp := float(dot_enemy.hp)

	var root_enemy: Node2D = await _spawn_real_enemy(Vector2(120, 0))
	root_enemy.base_speed = 100.0
	root_enemy.speed = 100.0
	root_enemy.apply_root(1.0, 1.0)
	var rooted_speed := float(root_enemy.speed)
	root_enemy._process(1.1)
	var restored_speed := float(root_enemy.speed)

	var delayed_enemy: Node2D = await _spawn_real_enemy(Vector2(160, 0))
	delayed_enemy.hp = 100.0
	delayed_enemy.max_hp = 100.0
	delayed_enemy.apply_delayed_damage(20.0, 0.5, "delayed_test", "delayed")
	delayed_enemy._process(0.6)
	var delayed_hp := float(delayed_enemy.hp)

	var passed := (
		is_equal_approx(amp_hp, 85.0)
		and is_equal_approx(armor_hp, 87.5)
		and is_equal_approx(dot_hp, 95.0)
		and rooted_speed < 100.0
		and restored_speed >= 99.0
		and is_equal_approx(delayed_hp, 80.0)
	)
	return _result("enemy_status_layer", passed, passed, [
		"damage_amp_hp_after_10=%.1f" % amp_hp,
		"armor_reduction_hp_after_10=%.1f" % armor_hp,
		"dot_hp_after_1s=%.1f" % dot_hp,
		"rooted_speed=%.1f" % rooted_speed,
		"restored_speed=%.1f" % restored_speed,
		"delayed_damage_hp=%.1f" % delayed_hp
	])

func run_hit_pulse_no_path_displacement_check() -> Dictionary:
	_clear_children()
	var enemy: Node2D = await _spawn_real_enemy(Vector2.ZERO)
	enemy.hp = 500.0
	enemy.max_hp = 500.0
	enemy.base_speed = 100.0
	enemy.speed = 100.0
	enemy.set_process(false)

	# Record root global_position before hit
	var pos_before := enemy.global_position

	# Simulate hit — this triggers _play_hit_pulse() internally
	enemy.take_damage(10.0, enemy.global_position, "test_displacement", "single")

	# Immediately after take_damage the root position must not have moved.
	# The tween fires asynchronously; we check position RIGHT after the call
	# before any frame yields.
	var pos_after_immediate := enemy.global_position
	var root_displaced := pos_before.distance_to(pos_after_immediate) > 0.5

	# Confirm visual_root (child) is also not displaced from origin yet (tween hasn't run)
	var visual_root_node: Node2D = enemy.get("visual_root")
	var visual_root_at_origin := true
	if visual_root_node != null and visual_root_node != enemy:
		visual_root_at_origin = visual_root_node.position.length() < 5.0

	var passed := not root_displaced and visual_root_at_origin
	return _result("hit_pulse_no_path_displacement", passed, passed, [
		"root_pos_before=%s" % str(pos_before),
		"root_pos_after_hit=%s" % str(pos_after_immediate),
		"root_displaced=%s" % str(root_displaced),
		"visual_root_at_origin=%s" % str(visual_root_at_origin)
	])

func run_tower_status_effect_check(tower_id_arg: String, expected_type: String) -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower(tower_id_arg, Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(50, 0))
	tower.current_target = enemy
	tower.shoot()
	var effect_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy: continue
		if not child.has_method("hit_target"): continue
		var effects: Array = child.get("status_effects")
		for eff in effects:
			if eff is Dictionary and str(eff.get("type", "")) == expected_type:
				effect_found = true
				break
		break
	var passed := effect_found
	return _result("%s_%s_status" % [tower_id_arg, expected_type], passed, passed, [
		"tower=%s" % tower_id_arg,
		"expected_status_type=%s" % expected_type,
		"status_found=%s" % str(effect_found)
	])

func run_roots_family_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("roots_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(50, 0))
	tower.current_target = enemy
	tower.shoot()
	var root_found := false
	var dot_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy: continue
		if not child.has_method("hit_target"): continue
		var effects: Array = child.get("status_effects")
		for eff in effects:
			if not eff is Dictionary: continue
			var t := str(eff.get("type", ""))
			if t == "root": root_found = true
			elif t == "dot": dot_found = true
		break
	var passed := root_found and dot_found
	return _result("roots_snare_and_dot", passed, passed, [
		"root_effect_found=%s" % str(root_found),
		"dot_effect_found=%s" % str(dot_found)
	])

func run_muck_family_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("muck_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(50, 0))
	tower.current_target = enemy
	tower.shoot()
	var dot_found := false
	var armor_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy: continue
		if not child.has_method("hit_target"): continue
		var effects: Array = child.get("status_effects")
		for eff in effects:
			if not eff is Dictionary: continue
			var t := str(eff.get("type", ""))
			if t == "dot": dot_found = true
			elif t == "armor_reduction": armor_found = true
		break
	var passed := dot_found and armor_found
	return _result("muck_poison_and_armor", passed, passed, [
		"dot_found=%s" % str(dot_found),
		"armor_reduction_found=%s" % str(armor_found)
	])

func run_quaker_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("quaker_t1", Vector2.ZERO)
	var enemy := _spawn_fake_enemy(Vector2(50, 0))
	tower.current_target = enemy
	tower.shoot()
	var root_found := false
	var amp_found := false
	for child in test_root.get_children():
		if child == tower or child == enemy: continue
		if not child.has_method("hit_target"): continue
		var effects: Array = child.get("status_effects")
		for eff in effects:
			if not eff is Dictionary: continue
			var t := str(eff.get("type", ""))
			if t == "root": root_found = true
			elif t == "damage_amp": amp_found = true
		break
	var passed := root_found and amp_found
	return _result("quaker_seismic_shock", passed, passed, [
		"root_stun_found=%s" % str(root_found),
		"damage_amp_found=%s" % str(amp_found)
	])

func run_impulse_distance_scaling_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("impulse_t1", Vector2.ZERO)
	tower.attack_range = 235.0
	tower.damage = 56.0

	var close_enemy := _spawn_fake_enemy(Vector2(30, 0))
	tower.current_target = close_enemy
	tower.shoot()
	var close_proj: Node2D = null
	for child in test_root.get_children():
		if child == tower or child == close_enemy: continue
		if child.has_method("hit_target"):
			close_proj = child
			break
	var close_dmg := float(close_proj.get("damage")) if close_proj != null else 0.0
	if close_proj != null: close_proj.queue_free()
	_clear_children()

	var far_enemy := _spawn_fake_enemy(Vector2(230, 0))
	tower = await _spawn_tower("impulse_t1", Vector2.ZERO)
	tower.attack_range = 235.0
	tower.damage = 56.0
	tower.current_target = far_enemy
	tower.shoot()
	var far_proj: Node2D = null
	for child in test_root.get_children():
		if child == tower or child == far_enemy: continue
		if child.has_method("hit_target"):
			far_proj = child
			break
	var far_dmg := float(far_proj.get("damage")) if far_proj != null else 0.0

	var passed := close_dmg > 0.0 and far_dmg > close_dmg
	return _result("impulse_distance_scaling", passed, passed, [
		"base_damage=%.1f" % 56.0,
		"close_range_damage=%.1f" % close_dmg,
		"far_range_damage=%.1f" % far_dmg,
		"scales_with_distance=%s" % str(far_dmg > close_dmg)
	])

func run_zealot_streak_check() -> Dictionary:
	_clear_children()
	var tower: Node2D = await _spawn_tower("zealot_t1", Vector2.ZERO)
	tower.damage = 13.0
	var enemy := _spawn_fake_enemy(Vector2(50, 0))
	tower.current_target = enemy

	tower.shoot()
	var first_proj: Node2D = null
	for child in test_root.get_children():
		if child == tower or child == enemy: continue
		if child.has_method("hit_target"):
			first_proj = child
			break
	var first_dmg := float(first_proj.get("damage")) if first_proj != null else 0.0
	if first_proj != null: first_proj.queue_free()

	tower.shoot()
	var second_proj: Node2D = null
	for child in test_root.get_children():
		if child == tower or child == enemy: continue
		if child.has_method("hit_target"):
			second_proj = child
			break
	var second_dmg := float(second_proj.get("damage")) if second_proj != null else 0.0

	var passed := first_dmg > 0.0 and second_dmg > first_dmg
	return _result("zealot_hit_streak", passed, passed, [
		"base_damage=%.1f" % 13.0,
		"first_shot_damage=%.1f" % first_dmg,
		"second_shot_damage=%.1f" % second_dmg,
		"streak_ramps=%s" % str(second_dmg > first_dmg)
	])

func run_laser_pierce_check() -> Dictionary:
	_clear_children()
	var primary_enemy := _spawn_fake_enemy(Vector2(80, 0))
	var pierce_enemy := _spawn_fake_enemy(Vector2(160, 0))
	var off_axis_enemy := _spawn_fake_enemy(Vector2(0, 150))

	var projectile := _spawn_projectile(primary_enemy, 100.0, "single", 0.0)
	projectile.source_id = "laser_t1"
	projectile.global_position = Vector2.ZERO
	projectile.rotation = 0.0
	projectile.hit_target()

	var passed := (
		primary_enemy.damage_calls == 1
		and pierce_enemy.damage_calls == 1
		and off_axis_enemy.damage_calls == 0
		and pierce_enemy.damage_taken < primary_enemy.damage_taken
	)
	return _result("laser_pierce", passed, passed, [
		"primary_enemy_damage=%.1f" % primary_enemy.damage_taken,
		"pierce_enemy_damage=%.1f" % pierce_enemy.damage_taken,
		"off_axis_enemy_damage=%.1f" % off_axis_enemy.damage_taken,
		"pierce_damage_is_reduced=%s" % str(pierce_enemy.damage_taken < primary_enemy.damage_taken),
		"off_axis_not_hit=%s" % str(off_axis_enemy.damage_calls == 0)
	])

func _prepare_test_root() -> void:
	if test_root and is_instance_valid(test_root):
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	test_root = Node2D.new()
	test_root.name = "TowerAbilityVerifyRuntime"
	host.add_child(test_root)
	await get_tree().process_frame

func _clear_children() -> void:
	if not test_root:
		return
	for child in test_root.get_children():
		child.free()

func _spawn_fake_enemy(pos: Vector2) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	test_root.add_child(enemy)
	enemy.global_position = pos
	enemy.add_to_group("enemies")
	return enemy

func _spawn_projectile(target: Node2D, damage: float, attack_type: String, radius: float, slow_percent: float = 0.0, slow_duration: float = 0.0) -> Node2D:
	var projectile := PROJECTILE_SCENE.instantiate()
	test_root.add_child(projectile)
	projectile.global_position = Vector2.ZERO
	projectile.setup(target, damage, 500.0, attack_type, radius, slow_percent, slow_duration, ["land"], "test_source")
	return projectile

func _spawn_real_enemy(pos: Vector2) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate()
	test_root.add_child(enemy)
	await get_tree().process_frame
	enemy.global_position = pos
	enemy.is_active = true
	enemy.add_to_group("enemies")
	enemy.set_process(false)
	return enemy

func _spawn_tower(tower_id: String, pos: Vector2) -> Node2D:
	var tower = TOWER_SCENE.instantiate()
	test_root.add_child(tower)
	await get_tree().process_frame
	var config: Dictionary = towers_config.get(tower_id, {}).duplicate(true)
	tower.setup(config, Vector2i.ZERO)
	tower.global_position = pos
	tower.projectile_container = test_root
	tower.add_to_group("towers")
	tower.add_to_group("placed_towers")
	tower.set_process(false)
	return tower

func _result(mechanic: String, passed: bool, observed: bool, evidence: Array, warnings: Array = []) -> Dictionary:
	return {
		"mechanic": mechanic,
		"runtime_implementation_found": true,
		"effect_observed": observed,
		"tests_passed": passed,
		"warnings": warnings,
		"evidence": evidence
	}

func _fail(mechanic: String, warnings: Array, evidence: Array) -> Dictionary:
	return {
		"mechanic": mechanic,
		"runtime_implementation_found": false,
		"effect_observed": false,
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
	return {"title": "Tower Ability Verification Report", "summary": {"passed": 0, "failed": 1}, "checks": {"access": _fail("debug_gate", ["Tower ability verification is disabled in this build."], [])}}

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
