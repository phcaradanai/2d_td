extends RefCounted

# Tower skin: Neutral Cannon Ripped T1
# Source: user-provided frame export under assets/sprites/neutral_cannon_t1_ripped.
# Scope: static cosmetic drawing only; no gameplay logic or runtime node creation.

const BASE_TEXTURE := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/tower_base/tower_base_00.png")
const TURRET_TEXTURE := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_00.png")

const CELL_SIZE := Vector2(256.0, 256.0)
const CELL_ORIGIN := Vector2(-128.0, -128.0)
const BASE_SCALE := 0.255
const TURRET_SCALE := 0.255

static func _draw_texture_cell(t: Node2D, texture: Texture2D, scale: float) -> void:
	if texture == null:
		return
	t.draw_texture_rect(
		texture,
		Rect2(CELL_ORIGIN * scale, CELL_SIZE * scale),
		false
	)

static func draw_base(t: Node2D) -> void:
	_draw_texture_cell(t, BASE_TEXTURE, BASE_SCALE)

static func draw_contour(t: Node2D) -> void:
	TowerVisualDrawUtils._draw_contour_circle(t, Vector2(-2.0, 8.0), 15.0)
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(-25.0, -12.0, 43.0, 19.0))
	TowerVisualDrawUtils._draw_contour_rect(t, Rect2(10.0, -11.0, 20.0, 15.0))

static func draw_top(
		t: Node2D,
		_main_color: Color,
		_secondary_color: Color,
		_core_color: Color,
		_lvl: int,
		_size: float,
		_el_colors: Array[Color]
) -> void:
	_draw_texture_cell(t, TURRET_TEXTURE, TURRET_SCALE)
