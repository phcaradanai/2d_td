extends Node

const CosmeticImpactVFXScript := preload("res://systems/cosmetics/cosmetic_impact_vfx.gd")
const CosmeticPerformancePolicyScript := preload("res://systems/cosmetics/cosmetic_performance_policy.gd")

const SLOT_TOWER_SKIN := "tower_skin"
const SLOT_PROJECTILE_SKIN := "projectile_skin"
const SLOT_IMPACT_SKIN := "impact_skin"
const SLOT_AURA_SKIN := "aura_skin"
const SLOT_ATTACK_VFX_SKIN := "attack_vfx_skin"
const IMPACT_POOL_SIZE := 16

var active_projectile_vfx: int = 0
var active_impact_vfx: int = 0
var skipped_impact_vfx: int = 0
var _impact_free_list: Array[Node2D] = []
var _impact_spawn_frame: int = -1
var _impact_spawned_this_frame: int = 0

func _ready() -> void:
	name = "CosmeticApplyService"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(IMPACT_POOL_SIZE):
		var fx := CosmeticImpactVFXScript.new()
		fx.name = "CosmeticImpactVFX"
		fx.visible = false
		fx.finished.connect(_on_impact_finished.bind(fx))
		add_child(fx)
		_impact_free_list.append(fx)
	var inventory := get_node_or_null("/root/CosmeticInventory")
	if inventory != null and inventory.has_signal("equipped_changed"):
		inventory.equipped_changed.connect(func(_tower_id: String, _slot: String, _cosmetic_id: String) -> void:
			refresh_scene_towers()
		)

func get_debug_counters() -> Dictionary:
	var projectile_count := 0
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(projectile) and str(projectile.get("cosmetic_projectile_id")) != "":
			projectile_count += 1
	return {
		"active_projectile_vfx": projectile_count,
		"active_impact_vfx": active_impact_vfx,
		"pooled_impact_free": _impact_free_list.size(),
		"skipped_impact_vfx": skipped_impact_vfx
	}

func get_equipped_id(tower_id: String, slot: String) -> String:
	var inventory := get_node_or_null("/root/CosmeticInventory")
	if inventory != null and inventory.has_method("get_equipped"):
		return str(inventory.get_equipped(tower_id, slot))
	return ""

func get_aura_skin_colors(tower_id: String) -> Dictionary:
	var cosmetic_id := get_equipped_id(tower_id, SLOT_AURA_SKIN)
	var cfg := _registry_get(cosmetic_id)
	if cfg.is_empty():
		return {}
	var out := {}
	if cfg.has("core_color"):
		out["core_color"] = Color.from_string(str(cfg["core_color"]), Color.WHITE)
	if cfg.has("glow_color"):
		out["glow_color"] = Color.from_string(str(cfg["glow_color"]), Color.WHITE)
	if cfg.has("accent_color"):
		out["accent_color"] = Color.from_string(str(cfg["accent_color"]), Color.WHITE)
	return out

func get_attack_vfx_skin_colors(tower_id: String) -> Dictionary:
	var cosmetic_id := get_equipped_id(tower_id, SLOT_ATTACK_VFX_SKIN)
	var cfg := _registry_get(cosmetic_id)
	if cfg.is_empty():
		return {}
	var out := {}
	if cfg.has("primary_color"):
		out["primary_color"] = Color.from_string(str(cfg["primary_color"]), Color.WHITE)
	if cfg.has("secondary_color"):
		out["secondary_color"] = Color.from_string(str(cfg["secondary_color"]), Color.WHITE)
	return out

func get_attack_vfx_skin_sprite_data(tower_id: String) -> Dictionary:
	var cosmetic_id := get_equipped_id(tower_id, SLOT_ATTACK_VFX_SKIN)
	var cfg := _registry_get(cosmetic_id)
	if cfg.is_empty() or (not cfg.has("sprite_dir") and not cfg.has("sprite_paths")):
		return {}
	var out := {}
	if cfg.has("sprite_paths"):
		out["sprite_paths"] = cfg["sprite_paths"]
	if cfg.has("sprite_dir"):
		out["sprite_dir"] = str(cfg["sprite_dir"])
	out["sprite_prefix"] = str(cfg.get("sprite_prefix", ""))
	out["sprite_count"] = int(cfg.get("sprite_count", 0))
	out["sprite_start_index"] = int(cfg.get("sprite_start_index", 0))
	out["sprite_scale"] = float(cfg.get("sprite_scale", 0.25))
	return out

func get_tower_skin_visual_script(tower_id: String) -> GDScript:
	var cosmetic_id := get_equipped_id(tower_id, SLOT_TOWER_SKIN)
	if cosmetic_id == "":
		return null
	var cfg := _registry_get(cosmetic_id)
	var path := str(cfg.get("visual_script", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as GDScript

func apply_projectile_cosmetic(projectile: Node, tower_id: String) -> void:
	if projectile == null:
		return
	var cosmetic_id := get_equipped_id(tower_id, SLOT_PROJECTILE_SKIN)
	var cfg := _registry_get(cosmetic_id)
	if cfg.is_empty():
		if projectile.has_method("setup_cosmetic"):
			projectile.setup_cosmetic("", {})
		return
	if projectile.has_method("setup_cosmetic"):
		projectile.setup_cosmetic(cosmetic_id, cfg)

func spawn_impact(parent: Node, tower_id: String, hit_pos: Vector2, hit_angle: float = 0.0) -> bool:
	var cosmetic_id := get_equipped_id(tower_id, SLOT_IMPACT_SKIN)
	var cfg := _registry_get(cosmetic_id)
	if cfg.is_empty():
		return false
	if not _can_spawn_impact():
		skipped_impact_vfx += 1
		return false
	if _impact_free_list.is_empty():
		skipped_impact_vfx += 1
		return false
	var fx: Node2D = _impact_free_list.pop_back()
	fx.reparent(parent)
	fx.global_position = hit_pos
	fx.rotation = hit_angle
	fx.visible = true
	active_impact_vfx += 1
	var runtime_cfg := cfg.duplicate(true)
	runtime_cfg["_redraw_interval"] = CosmeticPerformancePolicyScript.impact_redraw_interval(self)
	runtime_cfg["_low_detail"] = CosmeticPerformancePolicyScript.should_use_low_detail(self)
	fx.setup(runtime_cfg)
	return true

func refresh_scene_towers() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for tower in tree.get_nodes_in_group("towers"):
		if not is_instance_valid(tower):
			continue
		if tower.has_method("apply_level_visuals"):
			tower.apply_level_visuals()

func _registry_get(cosmetic_id: String) -> Dictionary:
	if cosmetic_id == "":
		return {}
	var registry := get_node_or_null("/root/CosmeticRegistry")
	if registry != null and registry.has_method("get_cosmetic"):
		return registry.get_cosmetic(cosmetic_id)
	return {}

func _on_impact_finished(fx: Node2D) -> void:
	if not is_instance_valid(fx):
		return
	active_impact_vfx = maxi(0, active_impact_vfx - 1)
	fx.visible = false
	fx.reparent(self)
	_impact_free_list.append(fx)

func _can_spawn_impact() -> bool:
	var max_active := CosmeticPerformancePolicyScript.max_active_impacts(self)
	if max_active <= 0 or active_impact_vfx >= max_active:
		return false
	var frame := Engine.get_process_frames()
	if frame != _impact_spawn_frame:
		_impact_spawn_frame = frame
		_impact_spawned_this_frame = 0
	var max_per_frame := CosmeticPerformancePolicyScript.max_impact_spawns_per_frame(self)
	if _impact_spawned_this_frame >= max_per_frame:
		return false
	_impact_spawned_this_frame += 1
	return true
