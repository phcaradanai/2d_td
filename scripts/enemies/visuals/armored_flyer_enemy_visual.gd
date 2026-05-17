const B     := preload("res://scripts/enemies/visuals/enemy_visual_base.gd")
const Flyer := preload("res://scripts/enemies/visuals/flyer_enemy_visual.gd")

static func draw_simple(enemy: Node2D, size: float) -> void:
	Flyer._draw_diamond_simple(enemy, size, B.COLOR_NEON_TANK)

static func draw(enemy: Node2D, size: float) -> void:
	Flyer._draw_drone(enemy, size, B.COLOR_NEON_TANK, false)
