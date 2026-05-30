extends RefCounted

# Opt-in flag: tower renderer will pass the live turret angle and skip texture baking.
const DIRECTIONAL_SPRITE := true

const _T0 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_00.png")
const _T1 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_01.png")
const _T2 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_02.png")
const _T3 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_03.png")
const _T4 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_04.png")
const _T5 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_05.png")
const _T6 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_06.png")
const _T7 := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/turret_rotation/turret_rotation_07.png")

const BASE_TEXTURE := preload("res://assets/sprites/neutral_cannon_t1_ripped/frames_fixed_256/tower_base/tower_base_00.png")

const CELL_SIZE   := Vector2(256.0, 256.0)
const CELL_ORIGIN := Vector2(-128.0, -128.0)
const BASE_SCALE   := 0.255
const TURRET_SCALE := 0.255

# Shift all frames by N steps if barrel alignment is still off (each step = 45°).
const FRAME_OFFSET := 4

static func _draw_texture_cell(t: Node2D, texture: Texture2D, scale: float) -> void:
	if texture == null:
		return
	t.draw_texture_rect(texture, Rect2(CELL_ORIGIN * scale, CELL_SIZE * scale), false)

static func draw_base(t: Node2D) -> void:
	_draw_texture_cell(t, BASE_TEXTURE, BASE_SCALE)

static func draw_contour(_t: Node2D) -> void:
	pass  # sprite has baked outlines; no procedural contour needed

# Called by the renderer when DIRECTIONAL_SPRITE is set — angle is the live turret rotation.
static func draw_top_directional(
		t: Node2D,
		angle: float,
		_main_color: Color,
		_secondary_color: Color,
		_core_color: Color,
		_lvl: int,
		_size: float,
		_el_colors: Array[Color]
) -> void:
	# Lower half (0 < angle < π): mirror upper-half frame with vertical flip.
	var needs_flip: bool = angle > 0.001 and angle < PI - 0.001
	var lookup: float = -angle if needs_flip else angle
	var frame_idx: int = (roundi(lookup / (TAU / 8.0)) + FRAME_OFFSET + 8) % 8
	var frames := [_T0, _T1, _T2, _T3, _T4, _T5, _T6, _T7]
	var scale_v := Vector2(1.0, -1.0) if needs_flip else Vector2.ONE
	t.draw_set_transform(Vector2.ZERO, 0.0, scale_v)
	_draw_texture_cell(t, frames[frame_idx], TURRET_SCALE)

# Fallback for baker / preview canvas that don't pass an angle — shows frame 0.
static func draw_top(
		t: Node2D,
		main_color: Color,
		secondary_color: Color,
		core_color: Color,
		lvl: int,
		size: float,
		el_colors: Array[Color]
) -> void:
	draw_top_directional(t, 0.0, main_color, secondary_color, core_color, lvl, size, el_colors)
