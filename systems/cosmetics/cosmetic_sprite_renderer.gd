extends RefCounted
class_name CosmeticSpriteRenderer

static func collect_textures(cfg: Dictionary) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var texture_path := str(cfg.get("texture_path", ""))
	if texture_path != "":
		var single := load_texture(texture_path)
		if single != null:
			textures.append(single)
			return textures
	var raw_paths = cfg.get("sprite_paths", [])
	if raw_paths is Array:
		for raw_path in raw_paths:
			var tex := load_texture(str(raw_path))
			if tex != null:
				textures.append(tex)
	var sprite_dir := str(cfg.get("sprite_dir", ""))
	var sprite_count := int(cfg.get("sprite_count", 0))
	var sprite_prefix := str(cfg.get("sprite_prefix", ""))
	if sprite_dir != "" and sprite_count > 0:
		var start_index := int(cfg.get("sprite_start_index", 0))
		for i in range(sprite_count):
			var path := sprite_dir + sprite_prefix + "%02d.png" % (i + start_index)
			var tex := load_texture(path)
			if tex != null:
				textures.append(tex)
	return textures

static func draw_frame(canvas: CanvasItem, cfg: Dictionary, textures: Array[Texture2D], progress: float, alpha: float = 1.0) -> bool:
	if textures.is_empty():
		return false
	var frame_idx := mini(int(clampf(progress, 0.0, 0.999) * textures.size()), textures.size() - 1)
	var tex := textures[frame_idx]
	if tex == null:
		return false
	draw_texture(canvas, cfg, tex, alpha)
	return true

static func draw_texture(canvas: CanvasItem, cfg: Dictionary, tex: Texture2D, alpha: float = 1.0) -> void:
	var tex_scale := float(cfg.get("sprite_scale", 0.25))
	var half := tex.get_size() * tex_scale * 0.5
	canvas.draw_texture_rect(tex, Rect2(-half, tex.get_size() * tex_scale), false, Color(1.0, 1.0, 1.0, alpha))

static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	var source_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var img := Image.load_from_file(source_path)
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	return null
