extends RefCounted
class_name CreditIconDraw

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

static func draw_coin(target: CanvasItem, center: Vector2, alpha: float = 1.0, radius: float = 8.0) -> void:
	var c := Color(NeonStyle.WARN.r, NeonStyle.WARN.g, NeonStyle.WARN.b, alpha)
	target.draw_circle(center, radius, Color(c.r, c.g, c.b, 0.18 * alpha))
	target.draw_arc(center, radius * 0.875, 0.0, TAU, 24, c, maxf(1.0, radius * 0.20), true)
	target.draw_arc(center, radius * 0.50, 0.0, TAU, 18, Color(c.r, c.g, c.b, 0.75 * alpha), maxf(1.0, radius * 0.125), true)
