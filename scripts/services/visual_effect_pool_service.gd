extends Node
## Pools short-lived decorative VFX nodes. This service never changes gameplay
## math; exhausted pools return null so callers skip only the visual.

const AttackVFXScript := preload("res://scripts/effects/attack_vfx.gd")
const EnemyImpactScript := preload("res://scripts/effects/enemy_impact_vfx.gd")
const StatusIconScript := preload("res://scripts/effects/enemy_status_icon_vfx.gd")
const DiseaseAttackScript := preload("res://scripts/effects/disease_attack_vfx.gd")
const SawbladeAoeScript := preload("res://scripts/effects/sawblade_aoe_effect.gd")
const LightningArcScript := preload("res://scripts/effects/lightning_arc.gd")
const BleedParticleScript := preload("res://scripts/effects/bleed_particle.gd")
const TowerHitVFXScript := preload("res://scripts/effects/tower_hit_vfx.gd")
const DamageNumberScene := preload("res://scenes/effects/DamageNumber.tscn")
const DeathPopScene := preload("res://scenes/effects/DeathPopEffect.tscn")
const SplashEffectScene := preload("res://scenes/effects/SplashEffect.tscn")
const MuzzleFlashScene := preload("res://scenes/effects/MuzzleFlash.tscn")

const KEY_ATTACK_LEGACY := "attack_vfx_legacy"
const KEY_DAMAGE_NUMBER := "damage_number"
const KEY_DEATH_POP := "death_pop"
const KEY_SPLASH := "splash_effect"
const KEY_ENEMY_IMPACT := "enemy_impact"
const KEY_STATUS_ICON := "status_icon"
const KEY_MUZZLE_FLASH := "muzzle_flash"
const KEY_DISEASE_ATTACK := "disease_attack_vfx"
const KEY_SAWBLADE_AOE := "sawblade_aoe"
const KEY_LIGHTNING_ARC := "lightning_arc"
const KEY_BLEED_PARTICLE := "bleed_particle"
const KEY_TOWER_HIT_VFX := "tower_hit_vfx"

const CAP_ATTACK := "attack_vfx"
const CAP_DAMAGE := "damage_number"
const CAP_DEATH := "death_pop"
const CAP_SPLASH := "splash_effect"
const CAP_ENEMY_IMPACT := "enemy_impact"
const CAP_STATUS_ICON := "status_icon"
const CAP_MUZZLE_FLASH := "muzzle_flash"

const BASE_PREWARM := {
	KEY_ATTACK_LEGACY: 24,
	KEY_DAMAGE_NUMBER: 12,
	KEY_DEATH_POP: 28,
	KEY_SPLASH: 8,
	KEY_ENEMY_IMPACT: 16,
	KEY_STATUS_ICON: 36,
	KEY_MUZZLE_FLASH: 6,
	KEY_DISEASE_ATTACK: 12,
	KEY_SAWBLADE_AOE: 4,
	KEY_LIGHTNING_ARC: 12,
	KEY_BLEED_PARTICLE: 18,
	KEY_TOWER_HIT_VFX: 26,
}

var _free_by_key: Dictionary = {}
var _active_by_key: Dictionary = {}
var _cap_key_by_pool_key: Dictionary = {}
var _script_by_key: Dictionary = {}
var _scene_by_key: Dictionary = {}
var _prewarmed_once: bool = false

func _ready() -> void:
	name = "VisualEffectPoolService"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("visual_effect_pool_service")
	prewarm_level_pools()

func prewarm_level_pools() -> void:
	_prewarm_scene(KEY_DAMAGE_NUMBER, DamageNumberScene, BASE_PREWARM[KEY_DAMAGE_NUMBER], CAP_DAMAGE)
	_prewarm_scene(KEY_DEATH_POP, DeathPopScene, BASE_PREWARM[KEY_DEATH_POP], CAP_DEATH)
	_prewarm_scene(KEY_SPLASH, SplashEffectScene, BASE_PREWARM[KEY_SPLASH], CAP_SPLASH)
	_prewarm_scene(KEY_MUZZLE_FLASH, MuzzleFlashScene, BASE_PREWARM[KEY_MUZZLE_FLASH], CAP_MUZZLE_FLASH)
	_prewarm_script(KEY_ATTACK_LEGACY, AttackVFXScript, BASE_PREWARM[KEY_ATTACK_LEGACY], CAP_ATTACK)
	_prewarm_script(KEY_ENEMY_IMPACT, EnemyImpactScript, BASE_PREWARM[KEY_ENEMY_IMPACT], CAP_ENEMY_IMPACT)
	_prewarm_script(KEY_STATUS_ICON, StatusIconScript, BASE_PREWARM[KEY_STATUS_ICON], CAP_STATUS_ICON)
	_prewarm_script(KEY_DISEASE_ATTACK, DiseaseAttackScript, BASE_PREWARM[KEY_DISEASE_ATTACK], CAP_ATTACK)
	_prewarm_script(KEY_SAWBLADE_AOE, SawbladeAoeScript, BASE_PREWARM[KEY_SAWBLADE_AOE], CAP_ATTACK)
	_prewarm_script(KEY_LIGHTNING_ARC, LightningArcScript, BASE_PREWARM[KEY_LIGHTNING_ARC], CAP_ATTACK)
	_prewarm_script(KEY_BLEED_PARTICLE, BleedParticleScript, BASE_PREWARM[KEY_BLEED_PARTICLE], CAP_ENEMY_IMPACT)
	_prewarm_script(KEY_TOWER_HIT_VFX, TowerHitVFXScript, BASE_PREWARM[KEY_TOWER_HIT_VFX], CAP_ATTACK)
	if not _prewarmed_once:
		_prewarm_registered_tower_attack_vfx()
		_prewarmed_once = true

func acquire_scene(pool_key: String, parent: Node, cap_key: String = "", important: bool = false) -> Node:
	if parent == null or not _can_spawn(pool_key, cap_key, important):
		return null
	if not _free_by_key.has(pool_key) or (_free_by_key[pool_key] as Array).is_empty():
		return null
	var node: Node = (_free_by_key[pool_key] as Array).pop_back()
	_activate_node(pool_key, cap_key, node, parent)
	return node

func acquire_script(script: GDScript, parent: Node, pool_key: String = "", cap_key: String = CAP_ATTACK, important: bool = false) -> Node2D:
	if script == null or parent == null:
		return null
	var resolved_key := pool_key if pool_key != "" else _script_pool_key(script)
	if not _can_spawn(resolved_key, cap_key, important):
		return null
	if not _free_by_key.has(resolved_key) or (_free_by_key[resolved_key] as Array).is_empty():
		return null
	var node: Node2D = (_free_by_key[resolved_key] as Array).pop_back() as Node2D
	_activate_node(resolved_key, cap_key, node, parent)
	return node

func release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if not node.has_meta("pooled"):
		node.call_deferred("free")
		return
	var pool_key := str(node.get_meta("vfx_pool_key", ""))
	if pool_key == "":
		node.call_deferred("free")
		return
	_deactivate_node(pool_key, node)

func release_active() -> void:
	for pool_key in _active_by_key.keys():
		var active: Array = (_active_by_key[pool_key] as Array).duplicate()
		for node in active:
			if is_instance_valid(node):
				release(node)

func get_cap(cap_key: String) -> int:
	var perf_service: Node = get_node_or_null("/root/PerformanceBudgetService")
	var quality_name := "MEDIUM"
	if perf_service != null and perf_service.has_method("get_quality_name"):
		quality_name = str(perf_service.get_quality_name())
	match cap_key:
		CAP_ATTACK:
			if perf_service != null and perf_service.has_method("get_budget"):
				return int(perf_service.get_budget("max_attack_vfx_active"))
			return 44
		CAP_DAMAGE:
			if quality_name == "HIGH":
				return 20
			if quality_name == "LOW":
				return 0
			return 10
		CAP_DEATH:
			if quality_name == "HIGH":
				return 48
			if quality_name == "LOW":
				return 12
			return 28
		CAP_SPLASH:
			if quality_name == "HIGH":
				return 18
			if quality_name == "LOW":
				return 4
			return 10
		CAP_ENEMY_IMPACT:
			if quality_name == "HIGH":
				return 28
			if quality_name == "LOW":
				return 6
			return 16
		CAP_STATUS_ICON:
			if quality_name == "HIGH":
				return 90
			if quality_name == "LOW":
				return 32
			return 60
		CAP_MUZZLE_FLASH:
			if quality_name == "HIGH":
				return 10
			if quality_name == "LOW":
				return 2
			return 5
	return 12

func _can_spawn(pool_key: String, cap_key: String, important: bool) -> bool:
	var resolved_cap: String = cap_key if cap_key != "" else str(_cap_key_by_pool_key.get(pool_key, ""))
	var cap := get_cap(resolved_cap)
	if cap <= 0 and not important:
		return false
	var active: Array = _active_by_key.get(pool_key, [])
	if active.size() >= max(1, cap):
		return false
	return true

func _activate_node(pool_key: String, cap_key: String, node: Node, parent: Node) -> void:
	node.set_meta("vfx_pool_key", pool_key)
	node.set_meta("vfx_cap_key", cap_key)
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_process(true)
	node.set_physics_process(false)
	if node.get_parent() != parent:
		node.reparent(parent)
	if not _active_by_key.has(pool_key):
		_active_by_key[pool_key] = []
	(_active_by_key[pool_key] as Array).append(node)

func _deactivate_node(pool_key: String, node: Node) -> void:
	if _active_by_key.has(pool_key):
		(_active_by_key[pool_key] as Array).erase(node)
	_reset_node(node)
	if node.get_parent() != self:
		node.reparent(self)
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	if not _free_by_key.has(pool_key):
		_free_by_key[pool_key] = []
	(_free_by_key[pool_key] as Array).append(node)

func _reset_node(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).modulate = Color.WHITE
	if node is Node2D:
		var node_2d := node as Node2D
		node_2d.position = Vector2.ZERO
		node_2d.rotation = 0.0
		node_2d.scale = Vector2.ONE
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()

func _prewarm_scene(pool_key: String, scene: PackedScene, count: int, cap_key: String) -> void:
	_scene_by_key[pool_key] = scene
	_cap_key_by_pool_key[pool_key] = cap_key
	_ensure_lists(pool_key)
	var free_list: Array = _free_by_key[pool_key]
	while free_list.size() < count:
		var node: Node = scene.instantiate()
		node.set_meta("pooled", true)
		node.set_meta("vfx_pool_key", pool_key)
		node.set_meta("vfx_cap_key", cap_key)
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		free_list.append(node)

func _prewarm_script(pool_key: String, script: GDScript, count: int, cap_key: String) -> void:
	_script_by_key[pool_key] = script
	_cap_key_by_pool_key[pool_key] = cap_key
	_ensure_lists(pool_key)
	var free_list: Array = _free_by_key[pool_key]
	while free_list.size() < count:
		var node := Node2D.new()
		node.set_script(script)
		node.set_meta("pooled", true)
		node.set_meta("vfx_pool_key", pool_key)
		node.set_meta("vfx_cap_key", cap_key)
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		free_list.append(node)

func _prewarm_registered_tower_attack_vfx() -> void:
	for script in TowerAttackVFXRegistry.get_all_vfx_scripts():
		if script is GDScript:
			_prewarm_script(_script_pool_key(script), script, 1, CAP_ATTACK)

func _ensure_lists(pool_key: String) -> void:
	if not _free_by_key.has(pool_key):
		_free_by_key[pool_key] = []
	if not _active_by_key.has(pool_key):
		_active_by_key[pool_key] = []

## Per-tower acquisition: never returns null, never checks global cap.
## Creates a new node on demand if the free list is exhausted.
## Used by TowerAttackVFXService so every tower always gets its own VFX slot.
func acquire_for_tower(script: GDScript, parent: Node) -> Node2D:
	if script == null or parent == null:
		return null
	var key := _script_pool_key(script)
	_ensure_lists(key)
	if not _script_by_key.has(key):
		_script_by_key[key] = script
	if not _cap_key_by_pool_key.has(key):
		_cap_key_by_pool_key[key] = CAP_ATTACK

	var free_list: Array = _free_by_key[key]
	var node: Node2D
	if free_list.is_empty():
		# Pool exhausted — create a fresh node so the tower is never silent.
		node = Node2D.new()
		node.set_script(script)
		node.set_meta("pooled", true)
		node.set_meta("vfx_pool_key", key)
		node.set_meta("vfx_cap_key", CAP_ATTACK)
		add_child(node)
	else:
		node = free_list.pop_back() as Node2D
	_activate_node(key, CAP_ATTACK, node, parent)
	return node

func _script_pool_key(script: GDScript) -> String:
	var path := script.resource_path
	if path == "":
		return "script_%s" % script.get_instance_id()
	return "script:%s" % path
