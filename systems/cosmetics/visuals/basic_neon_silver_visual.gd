extends RefCounted

const OUTLINE := Color(0.0, 0.0, 0.0, 0.88)
const SILVER_DARK := Color(0.12, 0.14, 0.16, 1.0)
const SILVER := Color(0.68, 0.76, 0.82, 1.0)
const SILVER_HI := Color(0.88, 0.94, 0.98, 1.0)
const CYAN := Color(0.18, 0.95, 1.0, 0.92)

static func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p)
	return out

static func draw_contour(t: Node2D) -> void:
	t.draw_circle(Vector2.ZERO, 22.0, OUTLINE)
	t.draw_rect(Rect2(-9, -5, 34, 10).grow(2.0), OUTLINE)
	t.draw_colored_polygon(_poly([Vector2(20, -8), Vector2(36, 0), Vector2(20, 8)]), OUTLINE)

static func draw_top(t: Node2D, _main_color: Color, _secondary_color: Color, _core_color: Color, _lvl: int, _size: float, _el_colors: Array[Color]) -> void:
	t.draw_circle(Vector2.ZERO, 21.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.10))
	t.draw_circle(Vector2.ZERO, 17.0, OUTLINE)
	t.draw_circle(Vector2.ZERO, 14.5, SILVER_DARK)
	t.draw_arc(Vector2.ZERO, 18.0, -0.65, 0.65, 14, Color(CYAN.r, CYAN.g, CYAN.b, 0.46), 1.4, true)
	t.draw_arc(Vector2.ZERO, 18.0, PI - 0.65, PI + 0.65, 14, Color(CYAN.r, CYAN.g, CYAN.b, 0.34), 1.2, true)
	t.draw_rect(Rect2(-10, -4, 35, 8).grow(1.8), OUTLINE)
	t.draw_rect(Rect2(-10, -4, 35, 8), SILVER)
	t.draw_line(Vector2(-6, 0), Vector2(25, 0), SILVER_HI, 1.2, true)
	t.draw_line(Vector2(-6, -6), Vector2(20, -2), CYAN, 1.2, true)
	t.draw_line(Vector2(-6, 6), Vector2(20, 2), CYAN, 1.2, true)
	var head := _poly([Vector2(20, -8), Vector2(36, 0), Vector2(20, 8), Vector2(24, 0)])
	t.draw_colored_polygon(head, OUTLINE)
	t.draw_colored_polygon(_poly([Vector2(21.5, -5.5), Vector2(32, 0), Vector2(21.5, 5.5), Vector2(24.5, 0)]), SILVER_HI)
	t.draw_circle(Vector2(-10, 0), 5.5, OUTLINE)
	t.draw_circle(Vector2(-10, 0), 3.8, CYAN)
