extends Node2D
class_name EnemyVFXController

const VFX_QUALITY_LOW := 0
const VFX_QUALITY_MEDIUM := 1
const VFX_QUALITY_HIGH := 2

const AuraScript := preload("res://scripts/effects/enemy_aura_vfx.gd")
const BeamScript := preload("res://scripts/effects/enemy_beam_vfx.gd")
const ImpactScript := preload("res://scripts/effects/enemy_impact_vfx.gd")
const StatusIconScript := preload("res://scripts/effects/enemy_status_icon_vfx.gd")
const PolisherScript := preload("res://scripts/effects/enemy_model_polisher.gd")
const CreepStatusVFXScript := preload("res://scripts/effects/creep_status_vfx.gd")

static var global_quality: int = VFX_QUALITY_MEDIUM
static var global_exact_radius_visible: bool = false
# [VISUAL-OPT] Aura radius rings hidden by default — replaced by compact role icons.
# Toggle these true in debug builds if range inspection is needed.
static var debug_show_support_radius: bool = false
static var debug_show_active_skill_targets: bool = true
static var debug_show_heal_tick_events: bool = true
static var debug_show_disruptor_radius: bool = false
static var debug_show_shield_coverage: bool = false
static var debug_show_cloaked_state: bool = true

var owner_enemy: Node = null
var visual_root: Node2D = null
var body_root: Node2D = null
var vfx_root: Node2D = null
var passive_aura: Node = null
var active_aura: Node = null
var cast_beam: Node = null
var target_links: Node = null
var status_icon: Node = null
var protected_icon: Node = null
# [VISUAL-OPT] Permanent compact identity symbol for special creep roles.
var role_icon: Node = null
var heal_cast_icon: Node = null
# Dynamic status-effect indicators (slow/root/burn/poison/vuln).
var status_effects_vfx: Node = null
var _last_heal_cast_msec: int = 0
var _heal_cast_hide_remaining: float = 0.0
var role_color: Color = Color(0.25, 0.85, 1.0)
var linked_towers: Array[Node] = []
var signals_connected: bool = false
var configured_key: String = ""

func setup(enemy: Node) -> void:
	owner_enemy = enemy
	name = "EnemyVFXController"
	top_level = false
	z_index = 14
	_ensure_structure()
	_configure_role()
	_connect_enemy_signals()
	set_exact_radius_visible(global_exact_radius_visible)
	set_quality(global_quality)

static func set_global_quality(value: int) -> void:
	global_quality = clampi(value, VFX_QUALITY_LOW, VFX_QUALITY_HIGH)

static func set_global_exact_radius_visible(value: bool) -> void:
	global_exact_radius_visible = value

static func set_global_debug_toggle(toggle_name: String, value: bool) -> void:
	match toggle_name:
		"support_radius":
			debug_show_support_radius = value
		"active_skill_targets":
			debug_show_active_skill_targets = value
		"heal_tick_events":
			debug_show_heal_tick_events = value
		"disruptor_radius":
			debug_show_disruptor_radius = value
		"shield_coverage":
			debug_show_shield_coverage = value
		"cloaked_state":
			debug_show_cloaked_state = value

func set_quality(value: int) -> void:
	global_quality = clampi(value, VFX_QUALITY_LOW, VFX_QUALITY_HIGH)
	if passive_aura:
		passive_aura.quality = global_quality
	if active_aura:
		active_aura.quality = global_quality
	_apply_debug_visibility()

func set_exact_radius_visible(value: bool) -> void:
	global_exact_radius_visible = value
	if passive_aura:
		passive_aura.set_exact_radius_visible(value)
	if active_aura:
		active_aura.set_exact_radius_visible(value)
	_apply_debug_visibility()

func refresh_debug_visibility() -> void:
	_apply_debug_visibility()

func play_heal_cast() -> void:
	if not debug_show_heal_tick_events:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_heal_cast_msec < 180:
		return
	_last_heal_cast_msec = now_msec
	_show_heal_cast_icon()

func play_heal_received(_amount: float) -> void:
	# Healing is already represented by one pooled cast icon on the healer.
	# Avoid spawning per-target impact nodes during dense support waves.
	pass

func play_shield_spark(raw_damage: float, final_damage: float) -> void:
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		return
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and comfort.has_method("allow_shield_ripple"):
		if not comfort.allow_shield_ripple("shield_%s" % owner_enemy.get_instance_id()):
			return
	var text := "%.0f>%.0f" % [raw_damage, final_damage] if OS.is_debug_build() else ""
	var color := Color(0.42, 0.78, 1.0, 0.24)
	if comfort != null and comfort.has_method("get_shield_color"):
		color = comfort.get_shield_color("shield")
	_spawn_impact("shield_spark", color, 0.34, 0.0, text)

func play_split_burst(child_type: String, count: int) -> void:
	_spawn_impact("split_burst", Color(0.9, 0.45, 1.0), 0.62, 0.0, "%s x%d" % [child_type, count])

func play_runner_burst() -> void:
	_spawn_impact("impact", Color(0.05, 1.0, 0.74), 0.34)

func mark_cloaked_deferred(_preferred: Node) -> void:
	_show_status("cloaked", Color(0.75, 0.75, 1.0), "")

func mark_cloaked_targetable() -> void:
	_show_status("cloaked", Color(0.9, 0.95, 1.0), "")
	if owner_enemy is CanvasItem:
		var old := (owner_enemy as CanvasItem).modulate
		var tween := create_tween()
		tween.tween_property(owner_enemy, "modulate", Color(old.r, old.g, old.b, max(old.a, 0.75)), 0.08)
		tween.tween_property(owner_enemy, "modulate", old, 0.24)

func set_protected_icon(active: bool) -> void:
	if active:
		if protected_icon == null or not is_instance_valid(protected_icon):
			protected_icon = _acquire_status_icon(vfx_root, "ShieldStatus", Vector2(0, -31))
			if protected_icon == null:
				return
			protected_icon.setup("shield", Color(0.35, 0.9, 1.0))
			_apply_debug_visibility()
	else:
		if protected_icon and is_instance_valid(protected_icon):
			_release_status_icon(protected_icon)
		protected_icon = null

func update_disrupted_towers(towers: Array) -> void:
	for old_tower in linked_towers:
		if not towers.has(old_tower):
			_remove_tower_icon(old_tower)
	linked_towers = towers.duplicate()
	_ensure_target_links()
	if target_links:
		target_links.show_links(owner_enemy as Node2D, linked_towers, _get_link_color("disruptor"))
		target_links.visible = debug_show_active_skill_targets
	_sync_tower_icons()

func clear_disrupted_tower(tower: Node) -> void:
	linked_towers.erase(tower)
	_ensure_target_links()
	if target_links:
		target_links.show_links(owner_enemy as Node2D, linked_towers, _get_link_color("disruptor"))
		target_links.visible = debug_show_active_skill_targets
	_remove_tower_icon(tower)

func clear_all_disrupted_towers() -> void:
	for tower in linked_towers:
		_remove_tower_icon(tower)
	linked_towers.clear()
	_ensure_target_links()
	if target_links:
		target_links.clear_links()

func fade_out() -> void:
	clear_all_disrupted_towers()
	if passive_aura:
		passive_aura.fade_out()
	if active_aura:
		active_aura.fade_out()
	# Immediately hide status indicators — creep is dying.
	if status_effects_vfx and is_instance_valid(status_effects_vfx):
		status_effects_vfx.visible = false
	_release_owned_status_icons()

func _ensure_structure() -> void:
	visual_root = get_node_or_null("VisualRoot")
	if visual_root == null:
		visual_root = Node2D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	body_root = visual_root.get_node_or_null("BodyRoot")
	if body_root == null:
		body_root = Node2D.new()
		body_root.name = "BodyRoot"
		visual_root.add_child(body_root)
	vfx_root = visual_root.get_node_or_null("VFXRoot")
	if vfx_root == null:
		vfx_root = Node2D.new()
		vfx_root.name = "VFXRoot"
		vfx_root.z_index = 1
		visual_root.add_child(vfx_root)
	# Status-effect indicator layer (slow/root/burn/poison/vuln icons + rings).
	status_effects_vfx = vfx_root.get_node_or_null("StatusEffectsVFX")
	if status_effects_vfx == null:
		status_effects_vfx = CreepStatusVFXScript.new()
		status_effects_vfx.name = "StatusEffectsVFX"
		status_effects_vfx.visible = false   # hidden until a status is active
		vfx_root.add_child(status_effects_vfx)
	# Setup is deferred so owner_enemy is guaranteed to be set by then.
	if owner_enemy != null and status_effects_vfx.has_method("setup"):
		status_effects_vfx.setup(owner_enemy)

func _ensure_target_links() -> void:
	if target_links != null and is_instance_valid(target_links):
		return
	target_links = vfx_root.get_node_or_null("TargetLinks")
	if target_links == null:
		target_links = BeamScript.new()
		target_links.name = "TargetLinks"
		vfx_root.add_child(target_links)

func _configure_role() -> void:
	if owner_enemy == null:
		return
	var enemy_type := str(owner_enemy.get("enemy_type"))
	var visual_type := str(owner_enemy.get("visual_type"))
	var tags: Array = owner_enemy.get("tags")
	var skill_id := str(owner_enemy.get("skill_id"))
	var skill_params: Dictionary = owner_enemy.get("skill_params")
	var key := "%s|%s|%s|%s" % [enemy_type, visual_type, skill_id, str(skill_params)]
	if configured_key == key:
		return
	configured_key = key
	if passive_aura and is_instance_valid(passive_aura):
		passive_aura.queue_free()
		passive_aura = null
	if status_icon and is_instance_valid(status_icon):
		_release_status_icon(status_icon)
		status_icon = null
	# [VISUAL-OPT] Hide previous role identity icon before reconfiguring.
	if role_icon and is_instance_valid(role_icon):
		_release_status_icon(role_icon)
		role_icon = null
	role_color = PolisherScript.role_color(enemy_type, visual_type, tags, skill_id)
	if skill_id == "healer":
		# [VISUAL-OPT] Aura hidden by default; replaced by compact cross/plus icon.
		_create_passive_aura("heal", float(skill_params.get("radius", 0.0)))
		_create_role_icon("healer_id", Color(0.4, 1.0, 0.6))
	elif skill_id == "disrupt_aura":
		# [VISUAL-OPT] Aura hidden by default; replaced by compact jammer icon.
		_create_passive_aura("emp", float(skill_params.get("radius", 0.0)))
		_create_role_icon("disruptor_id", Color(1.0, 0.55, 0.15))
	elif skill_id == "shield_aura" or owner_enemy.get("is_bulwark"):
		# [VISUAL-OPT] Shield dome radius hidden by default; replaced by compact shield icon.
		_create_passive_aura("shield", float(skill_params.get("radius", owner_enemy.get("shield_radius"))))
		_create_role_icon("bulwark_id", Color(0.3, 0.75, 1.0))
	if str(owner_enemy.get("enemy_category")) == "air":
		_show_status("air", Color(0.45, 0.9, 1.0), "")
	if enemy_type == "cloaked" or skill_id == "stealth":
		_show_status("cloaked", Color(0.72, 0.72, 1.0), "")

func _create_passive_aura(kind: String, radius: float) -> void:
	if radius <= 0.0:
		return
	passive_aura = AuraScript.new()
	passive_aura.name = "PassiveAura"
	passive_aura.setup(kind, radius, global_quality)
	passive_aura.set_exact_radius_visible(global_exact_radius_visible)
	vfx_root.add_child(passive_aura)
	_apply_debug_visibility()

# [VISUAL-OPT] Compact identity icon above the creep body, always visible.
func _create_role_icon(icon_type: String, color: Color) -> void:
	if role_icon == null or not is_instance_valid(role_icon):
		role_icon = _acquire_status_icon(vfx_root, "RoleIcon", Vector2(0, -24))
		if role_icon == null:
			return
	role_icon.visible = true
	role_icon.setup(icon_type, color)

func _show_heal_cast_icon() -> void:
	if heal_cast_icon == null or not is_instance_valid(heal_cast_icon):
		heal_cast_icon = _acquire_status_icon(vfx_root, "HealCastIcon", Vector2(0, -38))
		if heal_cast_icon == null:
			return
	heal_cast_icon.visible = true
	heal_cast_icon.setup("heal_cast", Color(0.55, 1.0, 0.72))
	_heal_cast_hide_remaining = 0.34

func _connect_enemy_signals() -> void:
	if owner_enemy == null:
		return
	if signals_connected:
		return
	if owner_enemy.has_signal("healer_heal_tick"):
		owner_enemy.healer_heal_tick.connect(_on_healer_heal_tick)
	if owner_enemy.has_signal("enemy_healed"):
		owner_enemy.enemy_healed.connect(_on_enemy_healed)
	if owner_enemy.has_signal("shield_applied"):
		owner_enemy.shield_applied.connect(_on_shield_applied)
	if owner_enemy.has_signal("disrupted_tower"):
		owner_enemy.disrupted_tower.connect(_on_disrupted_tower)
	if owner_enemy.has_signal("disruption_removed"):
		owner_enemy.disruption_removed.connect(_on_disruption_removed)
	if owner_enemy.has_signal("split_triggered"):
		owner_enemy.split_triggered.connect(_on_split_triggered)
	if owner_enemy.has_signal("stealth_targeting_deferred"):
		owner_enemy.stealth_targeting_deferred.connect(_on_stealth_deferred)
	if owner_enemy.has_signal("enemy_modifier_changed"):
		owner_enemy.enemy_modifier_changed.connect(_on_enemy_modifier_changed)
	signals_connected = true

func _process(delta: float) -> void:
	if _heal_cast_hide_remaining <= 0.0:
		return
	_heal_cast_hide_remaining -= delta
	if _heal_cast_hide_remaining <= 0.0 and heal_cast_icon and is_instance_valid(heal_cast_icon):
		_release_status_icon(heal_cast_icon)
		heal_cast_icon = null

func _acquire_status_icon(parent: Node, icon_name: String, icon_position: Vector2) -> Node:
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_script"):
		return null
	var icon := pool.acquire_script(StatusIconScript, parent, "status_icon", "status_icon") as Node
	if icon == null:
		return null
	icon.name = icon_name
	if icon is Node2D:
		(icon as Node2D).position = icon_position
	return icon

func _release_status_icon(icon: Node) -> void:
	if icon == null or not is_instance_valid(icon):
		return
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release"):
		pool.release(icon)
	else:
		icon.visible = false

func _release_owned_status_icons() -> void:
	if protected_icon and is_instance_valid(protected_icon):
		_release_status_icon(protected_icon)
	protected_icon = null
	if status_icon and is_instance_valid(status_icon):
		_release_status_icon(status_icon)
	status_icon = null
	if role_icon and is_instance_valid(role_icon):
		_release_status_icon(role_icon)
	role_icon = null
	if heal_cast_icon and is_instance_valid(heal_cast_icon):
		_release_status_icon(heal_cast_icon)
	heal_cast_icon = null

func _on_healer_heal_tick(_healer: Node, targets: Array, _amount: float) -> void:
	if targets.is_empty():
		return
	play_heal_cast()

func _on_enemy_healed(target: Node, _healer: Node, amount: float, hp_before: float, hp_after: float) -> void:
	if hp_after <= hp_before or not is_instance_valid(target):
		return
	if target.has_method("get_vfx_controller"):
		var target_vfx = target.get_vfx_controller()
		if target_vfx:
			target_vfx.play_heal_received(amount)

func _on_shield_applied(_target: Variant, raw_damage: float, final_damage: float, _source: Variant) -> void:
	if final_damage < raw_damage:
		play_shield_spark(raw_damage, final_damage)

func _on_disrupted_tower(tower: Node, _penalty: float, _source: Node) -> void:
	if not linked_towers.has(tower):
		linked_towers.append(tower)
	update_disrupted_towers(linked_towers)

func _on_disruption_removed(tower: Node, _source: Node) -> void:
	clear_disrupted_tower(tower)

func _on_split_triggered(_source: Node, child_type: String, count: int) -> void:
	play_split_burst(child_type, count)

func _on_stealth_deferred(_cloaked_enemy: Node, preferred_target: Node) -> void:
	mark_cloaked_deferred(preferred_target)

func _on_enemy_modifier_changed(enemy: Node, modifier_name: String, value: Variant) -> void:
	if enemy != owner_enemy:
		return
	if modifier_name == "shield_reduction":
		set_protected_icon(float(value) > 0.0)
	elif modifier_name == "formation_speed_multiplier" and float(value) >= 0.99:
		play_runner_burst()

func _spawn_impact(mode: String, color: Color, duration: float, amount: float = 0.0, debug_text: String = "") -> void:
	var perf_service := get_node_or_null("/root/PerformanceBudgetService")
	if perf_service != null and perf_service.has_method("get_budget") and not bool(perf_service.get_budget("allow_minor_impacts")):
		return
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool == null or not pool.has_method("acquire_script"):
		return
	var impact: Node2D = null
	if mode == "split_burst":
		var container := get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if container == null:
			container = get_tree().current_scene
		impact = pool.acquire_script(ImpactScript, container, "enemy_impact", "enemy_impact") as Node2D
		if impact != null and owner_enemy is Node2D:
			impact.global_position = (owner_enemy as Node2D).global_position
	else:
		impact = pool.acquire_script(ImpactScript, vfx_root, "enemy_impact", "enemy_impact") as Node2D
	if impact == null:
		return
	impact.name = "ImpactVFX"
	impact.setup(mode, color, duration, amount, debug_text)

func _get_link_color(effect_type: String) -> Color:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and comfort.has_method("get_link_color"):
		return comfort.get_link_color(effect_type)
	return Color(0.48, 0.78, 1.0, 0.28)

func _show_status(icon_type: String, color: Color, text: String) -> void:
	if status_icon == null or not is_instance_valid(status_icon):
		status_icon = _acquire_status_icon(vfx_root, "StateIcon", Vector2(0, -42))
		if status_icon == null:
			return
	status_icon.setup(icon_type, color, text if OS.is_debug_build() else "")
	_apply_debug_visibility()

func _sync_tower_icons() -> void:
	for tower in linked_towers:
		if not is_instance_valid(tower) or not (tower is Node2D):
			continue
		var icon := tower.get_node_or_null("EnemyVFXReloadSlowIcon")
		if icon == null:
			icon = _acquire_status_icon(tower as Node, "EnemyVFXReloadSlowIcon", Vector2(0, -46))
			if icon == null:
				continue
		if icon.has_method("setup"):
			icon.setup("reload_slow", Color(1.0, 0.2, 0.72), "reload slowed")
		icon.visible = debug_show_active_skill_targets

func _remove_tower_icon(tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	var icon := tower.get_node_or_null("EnemyVFXReloadSlowIcon")
	if icon:
		_release_status_icon(icon)

func _apply_debug_visibility() -> void:
	if passive_aura and is_instance_valid(passive_aura):
		match str(passive_aura.kind):
			"heal":
				passive_aura.visible = debug_show_support_radius
			"emp":
				passive_aura.visible = debug_show_disruptor_radius
			"shield":
				passive_aura.visible = debug_show_shield_coverage
			_:
				passive_aura.visible = true
	if target_links and is_instance_valid(target_links):
		target_links.visible = debug_show_active_skill_targets
	if status_icon and is_instance_valid(status_icon):
		status_icon.visible = debug_show_cloaked_state or str(status_icon.icon_type) != "cloaked"
	if protected_icon and is_instance_valid(protected_icon):
		protected_icon.visible = debug_show_shield_coverage
	# [VISUAL-OPT] Role identity icon is always visible — it replaces the area aura.
	if role_icon and is_instance_valid(role_icon):
		role_icon.visible = true
