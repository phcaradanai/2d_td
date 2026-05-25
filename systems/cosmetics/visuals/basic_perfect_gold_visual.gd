extends RefCounted

const OUTLINE := Color(0.0, 0.0, 0.0, 0.90)
const GOLD_DARK := Color(0.42, 0.25, 0.04, 1.0)
const GOLD := Color(1.0, 0.72, 0.16, 1.0)
const GOLD_HI := Color(1.0, 0.93, 0.55, 1.0)
const WHITE_GLOW := Color(1.0, 0.98, 0.78, 0.72)

static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p)
	return out

static func draw_contour(t: Node2D) -> void:
	t.draw_circle(Vector2.ZERO, 23.0, OUTLINE)
	t.draw_rect(Rect2(-11, -5, 36, 10).grow(2.0), OUTLINE)
	t.draw_colored_polygon(_poly([Vector2(20, -9), Vector2(37, 0), Vector2(20, 9)]), OUTLINE)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	t.draw_circle(Vector2.ZERO, 22.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.14))
	t.draw_arc(Vector2.ZERO, 23.5, 0.0, TAU, 28, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 0.28), 1.1, true)
	t.draw_circle(Vector2.ZERO, 17.0, OUTLINE)
	t.draw_circle(Vector2.ZERO, 14.5, GOLD_DARK)
	t.draw_circle(Vector2.ZERO, 8.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.88))
	for i in range(8):
		var a := float(i) * TAU / 8.0
		t.draw_line(Vector2.RIGHT.rotated(a) * 10.5, Vector2.RIGHT.rotated(a) * 15.5, WHITE_GLOW, 1.0, true)
	t.draw_rect(Rect2(-11, -4.5, 36, 9).grow(1.8), OUTLINE)
	t.draw_rect(Rect2(-11, -4.5, 36, 9), GOLD)
	t.draw_line(Vector2(-8, 0), Vector2(26, 0), GOLD_HI, 1.4, true)
	var head := _poly([Vector2(20, -9), Vector2(37, 0), Vector2(20, 9), Vector2(24, 0)])
	t.draw_colored_polygon(head, OUTLINE)
	t.draw_colored_polygon(_poly([Vector2(21.5, -6), Vector2(33, 0), Vector2(21.5, 6), Vector2(24.5, 0)]), GOLD_HI)
	t.draw_circle(Vector2(-12, 0), 6.2, OUTLINE)
	t.draw_circle(Vector2(-12, 0), 4.4, GOLD_HI)
