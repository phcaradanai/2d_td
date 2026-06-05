extends RefCounted

const BASE_TEX = preload("res://assets/sprites/towers/cannon/base/version_01/tower_base_00.png")
const CannonTowerVisual = preload("res://scripts/towers/visuals/fallback/cannon_tower_visual.gd")

static func _get_scale(t: Node2D) -> Vector2:
	var id := ""
	if "tower_skin_id" in t: id = str(t.get("tower_skin_id"))
	elif "cosmetic_skin_id" in t: id = str(t.get("cosmetic_skin_id"))
	elif t.has_method("_get_equipped_cosmetic_id"): id = str(t.call("_get_equipped_cosmetic_id", "tower_skin"))
	elif "tower_id" in t:
		var svc := t.get_node_or_null("/root/CosmeticApplyService")
		if svc != null and svc.has_method("get_equipped_cosmetic"):
			id = str(svc.get_equipped_cosmetic(t.tower_id, "tower_skin"))
			
	if id == "": return Vector2.ONE
	
	var cfg: Dictionary = {}
	if "registry" in t and t.registry != null and t.registry.has_method("get_cosmetic"):
		cfg = t.registry.get_cosmetic(id)
	else:
		var reg := t.get_node_or_null("/root/CosmeticRegistry")
		if reg != null and reg.has_method("get_cosmetic"):
			cfg = reg.get_cosmetic(id)
			return reg.get_cosmetic(id)
	return {}

static func _get_scale(t: Node2D) -> Vector2:
	var cfg := _get_config(t)
	var s := float(cfg.get("sprite_scale", 1.0))
	return Vector2(s, s)

static func draw_base(t: Node2D) -> void:
	if BASE_TEX:
		var cfg := _get_config(t)
		var s := float(cfg.get("base_scale", cfg.get("sprite_scale", 1.0)))
		var ox := float(cfg.get("base_offset_x", 0.0))
		var oy := float(cfg.get("base_offset_y", 0.0))
		var scale_vec := Vector2(s, s)
		var half := BASE_TEX.get_size() * scale_vec * 0.5
		t.draw_texture_rect(BASE_TEX, Rect2(-half + Vector2(ox, oy), BASE_TEX.get_size() * scale_vec), false)

static func draw_contour(t: Node2D) -> void:
	if CannonTowerVisual:
		CannonTowerVisual.draw_contour(t)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	if CannonTowerVisual:
		CannonTowerVisual.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)
