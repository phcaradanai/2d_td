extends Node

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

var _affix_defaults: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open("res://data/enemy_affixes.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_affix_defaults = parsed
		f.close()

# Called from EnemySetupService.apply_setup via enemy.setup()
func setup_enemy_affixes(enemy: Node2D, config: Dictionary) -> void:
	enemy.armor_element = config.get("armor_element", "composite")
	enemy.affixes = Array(config.get("affixes", []))
	enemy.is_invulnerable = false
	enemy.is_illusion = bool(config.get("is_illusion", false))
	enemy.gives_gold = bool(config.get("gives_gold", true))
	enemy.can_leak = bool(config.get("can_leak", true))
	enemy.affix_speed_multiplier = 1.0
	enemy.affix_state = {}

	for affix in enemy.affixes:
		var cfg: Dictionary = _affix_defaults.get(affix, {})
		match affix:
			"fast":
				enemy.affix_state["fast"] = {
					"burst_timer": float(cfg.get("burst_cooldown", 3.0)),
					"burst_remaining": 0.0,
					"burst_duration": float(cfg.get("burst_duration", 1.0)),
					"burst_multiplier": float(cfg.get("burst_speed_multiplier", 2.0)),
					"burst_cooldown": float(cfg.get("burst_cooldown", 3.0))
				}
			"healing":
				enemy.affix_state["healing"] = {
					"heal_radius": float(cfg.get("heal_radius", 120.0)),
					"heal_pct": float(cfg.get("heal_pct", 0.15))
				}
			"mechanical":
				enemy.affix_state["mechanical"] = {
					"cycle_timer": float(cfg.get("cycle_time", 12.0)),
					"cycle_time": float(cfg.get("cycle_time", 12.0)),
					"telegraph_duration": float(cfg.get("telegraph_duration", 1.5)),
					"telegraph_timer": 0.0,
					"telegraphing": false,
					"invuln_duration": float(cfg.get("invuln_duration", 3.0)),
					"invuln_remaining": 0.0
				}
			"undead":
				enemy.affix_state["undead"] = {
					"revived": false,
					"revive_hp_pct": float(cfg.get("revive_hp_pct", 0.40)),
					"revive_delay": float(cfg.get("revive_delay", 0.8)),
					"reviving": false,
					"revive_timer": 0.0
				}
			"image":
				enemy.affix_state["image"] = {
					"charge_time": float(cfg.get("charge_time", 8.0)),
					"charge_timer": float(cfg.get("charge_time", 8.0)),
					"charge_ready": false,
					"illusion_duration": float(cfg.get("illusion_duration", 5.0))
				}

# Called each frame from EnemyProcessService; exits immediately if no affixes.
func process_enemy_affixes(enemy: Node2D, delta: float) -> void:
	if enemy.affixes.is_empty():
		return
	for affix in enemy.affixes:
		match affix:
			"fast":       _tick_fast(enemy, delta)
			"mechanical": _tick_mechanical(enemy, delta)
			"undead":     _tick_undead(enemy, delta)
			"image":      _tick_image_charge(enemy, delta)
			# "healing" is death-triggered; no tick needed

# Returns true if death is consumed (undead revive). Caller must skip die().
func try_pre_death(enemy: Node2D) -> bool:
	if not enemy.affixes.has("undead"):
		return false
	var state: Dictionary = enemy.affix_state.get("undead", {})
	if state.get("revived", false) or state.get("reviving", false):
		return false
	state["reviving"] = true
	state["revive_timer"] = state.get("revive_delay", 0.8)
	enemy.affix_state["undead"] = state
	enemy.hp = 1.0
	enemy.is_invulnerable = true
	_play_undead_fake_death_vfx(enemy)
	return true

# Called in take_damage after damage lands, before die(). Triggers image clone.
func on_enemy_damaged(enemy: Node2D, hit_global: Vector2) -> void:
	if not enemy.affixes.has("image"):
		return
	var state: Dictionary = enemy.affix_state.get("image", {})
	if not state.get("charge_ready", false):
		return
	state["charge_ready"] = false
	state["charge_timer"] = state.get("charge_time", 8.0)
	enemy.affix_state["image"] = state
	_spawn_illusion(enemy, hit_global)

# Called inside die() before died.emit. Triggers healing affix death burst.
func on_enemy_death(enemy: Node2D, death_global: Vector2) -> void:
	if not enemy.affixes.has("healing"):
		return
	_heal_nearby_on_death(enemy, death_global)

# ── Per-affix tick ────────────────────────────────────────────────────────────

func _tick_fast(enemy: Node2D, delta: float) -> void:
	var state: Dictionary = enemy.affix_state.get("fast", {})
	var burst_rem: float = state.get("burst_remaining", 0.0)
	if burst_rem > 0.0:
		burst_rem -= delta
		if burst_rem <= 0.0:
			burst_rem = 0.0
			enemy.affix_speed_multiplier = 1.0
			enemy.update_effective_speed()
		state["burst_remaining"] = burst_rem
		enemy.affix_state["fast"] = state
		return
	var burst_timer: float = state.get("burst_timer", 0.0) - delta
	if burst_timer <= 0.0:
		state["burst_remaining"] = state.get("burst_duration", 1.0)
		burst_timer = state.get("burst_cooldown", 3.0)
		enemy.affix_speed_multiplier = state.get("burst_multiplier", 2.0)
		enemy.update_effective_speed()
		_play_fast_burst_vfx(enemy)
	state["burst_timer"] = burst_timer
	enemy.affix_state["fast"] = state

func _tick_mechanical(enemy: Node2D, delta: float) -> void:
	var state: Dictionary = enemy.affix_state.get("mechanical", {})

	var invuln_rem: float = state.get("invuln_remaining", 0.0)
	if invuln_rem > 0.0:
		invuln_rem -= delta
		if invuln_rem <= 0.0:
			invuln_rem = 0.0
			enemy.is_invulnerable = false
			state["cycle_timer"] = state.get("cycle_time", 12.0)
			_clear_mechanical_vfx(enemy)
		state["invuln_remaining"] = invuln_rem
		enemy.affix_state["mechanical"] = state
		return

	if state.get("telegraphing", false):
		var tel_timer: float = state.get("telegraph_timer", 0.0) - delta
		if tel_timer <= 0.0:
			state["telegraphing"] = false
			state["invuln_remaining"] = state.get("invuln_duration", 3.0)
			enemy.is_invulnerable = true
			_play_mechanical_invuln_vfx(enemy)
		state["telegraph_timer"] = tel_timer
		enemy.affix_state["mechanical"] = state
		return

	var cycle_timer: float = state.get("cycle_timer", 0.0) - delta
	if cycle_timer <= 0.0:
		state["telegraphing"] = true
		state["telegraph_timer"] = state.get("telegraph_duration", 1.5)
		_play_mechanical_telegraph_vfx(enemy)
	state["cycle_timer"] = cycle_timer
	enemy.affix_state["mechanical"] = state

func _tick_undead(enemy: Node2D, delta: float) -> void:
	var state: Dictionary = enemy.affix_state.get("undead", {})
	if not state.get("reviving", false):
		return
	var rev_timer: float = state.get("revive_timer", 0.0) - delta
	if rev_timer <= 0.0:
		state["reviving"] = false
		state["revived"] = true
		enemy.hp = enemy.max_hp * state.get("revive_hp_pct", 0.40)
		enemy.is_invulnerable = false
		enemy.is_active = true
		enemy._update_health_visual_state()
		_play_undead_risen_vfx(enemy)
	state["revive_timer"] = rev_timer
	enemy.affix_state["undead"] = state

func _tick_image_charge(enemy: Node2D, delta: float) -> void:
	var state: Dictionary = enemy.affix_state.get("image", {})
	if state.get("charge_ready", false):
		return
	var charge_timer: float = state.get("charge_timer", 0.0) - delta
	if charge_timer <= 0.0:
		state["charge_ready"] = true
		charge_timer = 0.0
	state["charge_timer"] = charge_timer
	enemy.affix_state["image"] = state

# ── Healing on death ──────────────────────────────────────────────────────────

func _heal_nearby_on_death(enemy: Node2D, _death_global: Vector2) -> void:
	var state: Dictionary = enemy.affix_state.get("healing", {})
	var radius: float = state.get("heal_radius", 120.0)
	var heal_amount: float = enemy.max_hp * state.get("heal_pct", 0.15)

	var cache: Node = get_node_or_null("/root/SpatialTargetCache")
	var candidates: Array
	if cache != null and cache.has_method("get_candidates_in_radius"):
		candidates = cache.get_candidates_in_radius(enemy.global_position, radius)
	else:
		var pb: Node = get_node_or_null("/root/PerformanceBudget")
		candidates = pb.get_enemies() if pb and pb.has_method("get_enemies") else \
				enemy.get_tree().get_nodes_in_group("enemies")

	for other in candidates:
		if other == enemy or not is_instance_valid(other):
			continue
		if not other.has_method("is_alive") or not other.is_alive():
			continue
		if other.global_position.distance_to(enemy.global_position) > radius:
			continue
		if other.has_method("heal"):
			other.heal(heal_amount, enemy)

# ── Illusion spawn ────────────────────────────────────────────────────────────

func _spawn_illusion(source: Node2D, _hit_global: Vector2) -> void:
	var path_parent: Node = source.get_parent()
	if not is_instance_valid(path_parent):
		return

	var illusion_config: Dictionary = {
		"id": source.enemy_type,
		"name": source.display_name + " (Illusion)",
		"max_hp": maxf(source.max_hp * 0.3, 10.0),
		"speed": source.base_speed,
		"reward_gold": 0,
		"base_damage": 0,
		"category": source.enemy_category,
		"visual_type": source.visual_type,
		"tags": source.tags.duplicate(),
		"affixes": [],
		"gives_gold": false,
		"can_leak": false,
		"is_illusion": true
	}

	var illusion: Node = ENEMY_SCENE.instantiate()
	if not illusion.has_method("setup"):
		illusion.queue_free()
		return

	illusion.setup(illusion_config)

	if illusion.has_signal("died"):
		illusion.died.connect(func(_e, _g): pass)
	if illusion.has_signal("reached_base"):
		illusion.reached_base.connect(func(_e, _d, _p): pass)

	path_parent.add_child(illusion)
	if illusion is PathFollow2D and source is PathFollow2D:
		illusion.progress = source.progress + randf_range(-15.0, 15.0)

	var state: Dictionary = source.affix_state.get("image", {})
	var dur: float = state.get("illusion_duration", 5.0)
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(illusion):
			illusion.queue_free()
	)

# ── VFX helpers ───────────────────────────────────────────────────────────────

func _play_fast_burst_vfx(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or enemy.is_illusion:
		return
	var vc: Node = enemy.get_node_or_null("EnemyVFXController")
	if vc and vc.has_method("play_runner_burst"):
		vc.play_runner_burst()
	if enemy.has_method("_spawn_impact_particle"):
		enemy._spawn_impact_particle(Color(0.0, 1.0, 0.7, 0.5))

func _play_mechanical_telegraph_vfx(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var state: Dictionary = enemy.affix_state.get("mechanical", {})
	var tel_dur: float = state.get("telegraph_duration", 1.5)
	var tween := enemy.create_tween().set_loops()
	tween.tween_property(enemy, "modulate", Color(1.2, 1.1, 0.3, 1.0), 0.18)
	tween.tween_property(enemy, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
	get_tree().create_timer(tel_dur).timeout.connect(func():
		if tween.is_valid():
			tween.kill()
	)

func _play_mechanical_invuln_vfx(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.modulate = Color(0.5, 0.85, 1.0, 0.8)

func _clear_mechanical_vfx(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _play_undead_fake_death_vfx(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.modulate = Color(0.7, 0.7, 1.0, 0.45)

func _play_undead_risen_vfx(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if enemy.has_method("_spawn_impact_particle"):
		enemy._spawn_impact_particle(Color(0.7, 0.3, 1.0, 0.7))
