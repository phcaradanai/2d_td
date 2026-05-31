extends RefCounted

# Animated tower skin for Darkness Tower I.
# Frame paths are read from the cosmetic JSON ("idle_sprite_paths" / "attack_sprite_paths")
# so they can be changed without touching this script.
# draw_top_directional is declared so the baker skips baking and the live
# procedural draw path stays active for per-frame animation.

const IDLE_FRAME_MS := 125    # 8 fps
const ATTACK_FRAME_MS := 83   # ~12 fps

# Cache keyed by cosmetic_id so a skin swap invalidates automatically.
static var _texture_cache: Dictionary = {}   # cosmetic_id -> {idle, attack, scale}

static func draw_base(t: Node2D) -> void:
	var entry := _get_cache_entry(t)
	if entry.is_empty():
		return
	var t_msec := Time.get_ticks_msec()
	var has_target: bool = bool(t.get("cached_target_valid") if "cached_target_valid" in t else false)
	var frames: Array = entry["attack"] if has_target else entry["idle"]
	if frames.is_empty():
		return
	var frame := (t_msec / (ATTACK_FRAME_MS if has_target else IDLE_FRAME_MS)) % frames.size()
	var tex: Texture2D = frames[frame]
	if tex == null:
		return
	var scale: float = entry["scale"]
	var size := tex.get_size() * scale
	t.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color.WHITE)

static func draw_contour(_t: Node2D) -> void:
	pass

static func draw_top(_t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	pass

# Presence of this method makes cosmetic_script_is_directional() return true,
# bypassing the bake system so draw_base is called live every frame.
static func draw_top_directional(t: Node2D, _angle: float, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

static func _get_cache_entry(t: Node2D) -> Dictionary:
	var skin_id := _get_equipped_skin_id(t)
	if skin_id == "":
		return {}
	if _texture_cache.has(skin_id):
		return _texture_cache[skin_id]
	var cfg := _get_skin_cfg(t, skin_id)
	var entry := {
		"idle": _load_frames(cfg.get("idle_sprite_paths", [])),
		"attack": _load_frames(cfg.get("attack_sprite_paths", [])),
		"scale": float(cfg.get("sprite_scale", 1.0)),
	}
	_texture_cache[skin_id] = entry
	return entry

static func _get_equipped_skin_id(t: Node2D) -> String:
	var svc := t.get_node_or_null("/root/CosmeticApplyService")
	if svc != null and svc.has_method("get_equipped_id"):
		return str(svc.get_equipped_id(str(t.get("tower_id") if "tower_id" in t else ""), "tower_skin"))
	return ""

static func _get_skin_cfg(t: Node2D, skin_id: String) -> Dictionary:
	var registry := t.get_node_or_null("/root/CosmeticRegistry")
	if registry != null and registry.has_method("get_cosmetic"):
		return registry.get_cosmetic(skin_id)
	return {}

static func _load_frames(paths: Array) -> Array:
	var out: Array = []
	for raw in paths:
		var path := str(raw)
		var tex := _load_tex(path)
		if tex != null:
			out.append(tex)
	return out

static func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	var source := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var img := Image.load_from_file(source)
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
