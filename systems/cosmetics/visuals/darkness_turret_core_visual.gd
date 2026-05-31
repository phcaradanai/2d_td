extends RefCounted

# Cosmetic tower skin for Darkness Tower I using the darkness_turret_ripped sprite set.
# Visual-only: no gameplay state, no spawned nodes, no particles.

const BASE_TEX_PATH := "res://assets/sprites/darkness_turret_ripped/frames_trimmed/idle_01.png"

const SPRITE_SIZE := Vector2(39.0, 39.0)
const BASE_SCALE := 1.16

static var _base_tex: Texture2D = null

static func draw_base(t: Node2D) -> void:
	var tex := _get_base_texture()
	if tex == null:
		return
	t.draw_texture_rect(
		tex,
		_centered_rect(BASE_SCALE),
		false,
		Color.WHITE
	)

static func draw_contour(_t: Node2D) -> void:
	pass

static func draw_top(_t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	pass

static func _centered_rect(scale: float) -> Rect2:
	var size := SPRITE_SIZE * scale
	return Rect2(size * -0.5, size)

static func _get_base_texture() -> Texture2D:
	if _base_tex != null:
		return _base_tex
	var img := Image.load_from_file(BASE_TEX_PATH)
	if img != null and not img.is_empty():
		_base_tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(BASE_TEX_PATH):
		_base_tex = load(BASE_TEX_PATH) as Texture2D
	return _base_tex
