extends Control
class_name CreditCostDisplay

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")
const CreditIconDraw = preload("res://scripts/ui/credit_icon_draw.gd")

var cost: int = 0
var affordable: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64.0, 34.0)

func configure(new_cost: int, can_afford: bool) -> void:
	var changed := cost != new_cost or affordable != can_afford
	cost = new_cost
	affordable = can_afford
	if changed:
		queue_redraw()

func _draw() -> void:
	var alpha := 1.0 if affordable else 0.66
	var text := str(cost)
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var icon_radius := 7.5
	var gap := 6.0
	var total_width := icon_radius * 2.0 + gap + text_size.x
	var start_x := maxf(0.0, size.x - total_width)
	var center_y := size.y * 0.5
	var icon_center := Vector2(start_x + icon_radius, center_y)
	CreditIconDraw.draw_coin(self, icon_center, alpha, icon_radius)
	var text_color := Color(NeonStyle.WARN.r, NeonStyle.WARN.g, NeonStyle.WARN.b, alpha)
	if not affordable:
		text_color = Color(NeonStyle.DANGER.r, NeonStyle.DANGER.g * 0.72 + NeonStyle.WARN.g * 0.28, NeonStyle.DANGER.b, 0.82)
	draw_string(
		font,
		Vector2(icon_center.x + icon_radius + gap, center_y + 5.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_size.x + 2.0,
		font_size,
		text_color
	)
