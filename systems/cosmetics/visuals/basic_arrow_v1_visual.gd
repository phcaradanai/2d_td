extends RefCounted

const BASE_TEX = preload("res://assets/sprites/towers/arrow/base/version_01/version_01.png")
const TURRET_TEX = preload("res://assets/sprites/towers/arrow/turret/version_01/version_01.png")

static func _get_config(t: Node2D) -> Dictionary:
	var id := ""
	if "tower_skin_id" in t: id = str(t.get("tower_skin_id"))
	elif "cosmetic_skin_id" in t: id = str(t.get("cosmetic_skin_id"))
	elif t.has_method("_get_equipped_cosmetic_id"): id = str(t.call("_get_equipped_cosmetic_id", "tower_skin"))
	elif "tower_id" in t:
		var svc := t.get_node_or_null("/root/CosmeticApplyService")
		if svc != null and svc.has_method("get_equipped_cosmetic"):
			id = str(svc.get_equipped_cosmetic(t.tower_id, "tower_skin"))
	
	if id == "": return {}
	
	if "registry" in t and t.registry != null and t.registry.has_method("get_cosmetic"):
		return t.registry.get_cosmetic(id)
	
	var reg := t.get_node_or_null("/root/CosmeticRegistry")
	if reg != null and reg.has_method("get_cosmetic"):
		return reg.get_cosmetic(id)
		
	return {}

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
	pass

static func draw_top_directional(t: Node2D, angle: float, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	if TURRET_TEX:
		var cfg := _get_config(t)
		var s := float(cfg.get("turret_scale", cfg.get("sprite_scale", 1.0)))
		var ox := float(cfg.get("turret_offset_x", 0.0))
		var oy := float(cfg.get("turret_offset_y", 0.0))
		var scale_vec := Vector2(s, s)
		var offset_vec := Vector2(ox, oy)
		var half := TURRET_TEX.get_size() * scale_vec * 0.5
		
		# Translate to the pivot position BEFORE rotating.
		# offset_vec stays fixed in canvas space regardless of angle,
		# so the disc center never orbits the tower origin.
		t.draw_set_transform(offset_vec, angle, Vector2.ONE)
		t.draw_texture_rect(TURRET_TEX, Rect2(-half, TURRET_TEX.get_size() * scale_vec), false)
		t.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	draw_top_directional(t, 0.0, main_color, secondary_color, core_color, lvl, size, el_colors)
