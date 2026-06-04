extends RefCounted
class_name TowerVisualRenderer

# Central tower visual facade.
# tower.gd calls this file; actual tower silhouettes live in scripts/towers/visuals/*_tower_visual.gd.

const TowerVisualDrawUtilsScript = preload("res://scripts/towers/visuals/common/tower_visual_draw_utils.gd")
const TowerVisualRegistryScript = preload("res://scripts/towers/visuals/tower_visual_registry.gd")

static func draw_base_plate(t: Node2D) -> void:
	var cfg := _get_tower_skin_cfg(t)
	if not cfg.is_empty() and (cfg.has("sprite_paths") or cfg.has("sprite_dir")):
		_draw_animated_sprite_paths(t, cfg)
		return
		
	var cosmetic_script := _get_cosmetic_visual_script(t)
	if cosmetic_script != null and cosmetic_script.has_method("draw_base"):
		cosmetic_script.draw_base(t)
		return
	TowerVisualDrawUtilsScript.draw_base_plate(t)

static func draw_element_core(t: Node2D) -> void:
	TowerVisualDrawUtilsScript.draw_element_core(t)

static func draw_turret_contour(t: Node2D) -> void:
	var cfg := _get_tower_skin_cfg(t)
	if not cfg.is_empty() and (cfg.has("sprite_paths") or cfg.has("sprite_dir")):
		return
		
	var visual_script := _get_visual_script(t)
	if visual_script:
		if visual_script.has_method("draw_contour"):
			visual_script.draw_contour(t)

static func draw_turret_top(t: Node2D) -> void:
	var cfg := _get_tower_skin_cfg(t)
	if not cfg.is_empty() and (cfg.has("sprite_paths") or cfg.has("sprite_dir")):
		return
		
	var lvl = t.tree_tier if "tree_tier" in t else 1
	var el_colors: Array[Color] = []
	if t.has_method("_get_all_element_colors"):
		el_colors = t.call("_get_all_element_colors")

	var main_color: Color
	var secondary_color: Color
	var core_color: Color

	if not el_colors.is_empty():
		main_color = el_colors[0]
		secondary_color = el_colors[1] if el_colors.size() >= 2 else el_colors[0].lightened(0.3)
		core_color = main_color.lightened(0.45)
	else:
		main_color = Color(0.45, 0.55, 0.6, 1.0)
		secondary_color = Color(0.55, 0.65, 0.7, 1.0)
		core_color = Color(0.7, 0.8, 0.85, 1.0)

	var size = 20.0
	var visual_script := _get_visual_script(t)
	if visual_script:
		if visual_script.has_method("draw_top_directional"):
			var pivot := t.get("turret_pivot") as Node2D
			var angle := pivot.rotation if is_instance_valid(pivot) else 0.0
			visual_script.draw_top_directional(t, angle, main_color, secondary_color, core_color, lvl, size, el_colors)
		elif visual_script.has_method("draw_top"):
			visual_script.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

static func cosmetic_script_is_directional(t: Node2D) -> bool:
	var script := _get_cosmetic_visual_script(t)
	return script != null and script.has_method("draw_top_directional")

static func _get_visual_script(t: Node2D) -> Script:
	var cosmetic_script := _get_cosmetic_visual_script(t)
	if cosmetic_script != null:
		return cosmetic_script
	var t_id := str(t.tower_id) if "tower_id" in t else ""
	var v_type := str(t.visual_type) if "visual_type" in t else "basic"
	return TowerVisualRegistryScript.get_visual_script(t_id, v_type)

static func _get_tower_skin_cfg(t: Node2D) -> Dictionary:
	var skin_id := ""
	if "tower_skin_id" in t:
		skin_id = str(t.tower_skin_id)
	elif "cosmetic_skin_id" in t:
		skin_id = str(t.cosmetic_skin_id)
	
	if skin_id == "":
		var cosmetic_service := t.get_node_or_null("/root/CosmeticApplyService")
		if cosmetic_service != null and cosmetic_service.has_method("get_equipped_id"):
			var t_id := str(t.tower_id) if "tower_id" in t else ""
			if t_id != "":
				skin_id = cosmetic_service.get_equipped_id(t_id, "tower_skin")
			
	if skin_id == "":
		return {}
		
	if "registry" in t and t.registry != null and t.registry.has_method("get_cosmetic"):
		return t.registry.get_cosmetic(skin_id)
		
	var registry := t.get_node_or_null("/root/CosmeticRegistry")
	if registry != null and registry.has_method("get_cosmetic"):
		return registry.get_cosmetic(skin_id)
		
	return {}

static func _get_cosmetic_visual_script(t: Node2D) -> Script:
	var direct_skin_id := ""
	if "tower_skin_id" in t:
		direct_skin_id = str(t.tower_skin_id)
	elif "cosmetic_skin_id" in t:
		direct_skin_id = str(t.cosmetic_skin_id)
	if direct_skin_id != "":
		var direct_script := _load_cosmetic_visual_script(t, direct_skin_id)
		if direct_script != null:
			return direct_script
	var cosmetic_service := t.get_node_or_null("/root/CosmeticApplyService")
	if cosmetic_service != null and cosmetic_service.has_method("get_tower_skin_visual_script"):
		var t_id := str(t.tower_id) if "tower_id" in t else ""
		if t_id != "":
			var cosmetic_script: Script = cosmetic_service.get_tower_skin_visual_script(t_id)
			if cosmetic_script != null:
				return cosmetic_script
	return null

static func _load_cosmetic_visual_script(t: Node2D, cosmetic_id: String) -> Script:
	var cfg := {}
	if "registry" in t and t.registry != null and t.registry.has_method("get_cosmetic"):
		cfg = t.registry.get_cosmetic(cosmetic_id)
	else:
		var registry := t.get_node_or_null("/root/CosmeticRegistry")
		if registry != null and registry.has_method("get_cosmetic"):
			cfg = registry.get_cosmetic(cosmetic_id)
	var path := str(cfg.get("visual_script", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Script

static func _draw_animated_sprite_paths(t: Node2D, cfg: Dictionary, extra_scale: float = 1.0) -> void:
	var cosmetic_id := str(cfg.get("id", ""))
	var node_name := "CosmeticAnim_" + cosmetic_id
	var anim_node := t.get_node_or_null(node_name) as AnimatedSprite2D
	
	if not is_instance_valid(anim_node):
		anim_node = AnimatedSprite2D.new()
		anim_node.name = node_name
		
		var frames := SpriteFrames.new()
		var fps := float(cfg.get("fps", 8.0))
		frames.set_animation_speed("default", fps)
		frames.set_animation_loop("default", true)
		
		var textures: Array[Texture2D] = []
		var CosmeticSpriteRendererScript = load("res://systems/cosmetics/cosmetic_sprite_renderer.gd")
		if CosmeticSpriteRendererScript != null and CosmeticSpriteRendererScript.has_method("collect_textures"):
			textures = CosmeticSpriteRendererScript.collect_textures(cfg)
			
		if textures.is_empty():
			anim_node.free()
			return
			
		for tex in textures:
			frames.add_frame("default", tex)
			
		anim_node.sprite_frames = frames
		anim_node.play("default")
		anim_node.centered = true
		
		var timer := Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		timer.timeout.connect(func():
			if is_instance_valid(t):
				var current_cfg := _get_tower_skin_cfg(t)
				if current_cfg.is_empty() or str(current_cfg.get("id", "")) != cosmetic_id:
					if is_instance_valid(anim_node) and not anim_node.is_queued_for_deletion():
						anim_node.queue_free()
		)
		anim_node.add_child(timer)
		t.add_child.call_deferred(anim_node)
		
	var scale_factor := float(cfg.get("sprite_scale", 1.0)) * extra_scale
	print("DEBUG: _draw_animated_sprite_paths called for ", cosmetic_id, " scale=", scale_factor)
	anim_node.scale = Vector2(scale_factor, scale_factor)
