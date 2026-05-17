const B       := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")
const Bulwark := preload("res://scripts/enemies/visuals/bulwark_enemy_visual.gd")

const SB_COLOR := Color(0.3, 0.8, 1.0)

static func draw_simple(enemy: Node2D, size: float) -> void:
	Bulwark.draw_simple(enemy, size, SB_COLOR)

static func draw(enemy: Node2D, size: float) -> void:
	Bulwark.draw(enemy, size, SB_COLOR)
