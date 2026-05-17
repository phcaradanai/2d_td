extends RefCounted
class_name TowerVisualDrawUtils

# Shared CanvasItem drawing helpers for tower visual files.
# Visual-only. Do not put gameplay, attack, targeting, or upgrade logic here.

const TOWER_CONTOUR_PX := 1.6
const TOWER_CONTOUR_COLOR := Color(0.0, 0.0, 0.0, 0.78)

static func draw_base_plate(t: Node2D) -> void:
	var lvl = t.tree_tier
	var base_color = Color(0.06, 0.08, 0.12, 1.0)
	var el_colors : Array[Color] = t._get_all_element_colors()
	var accent_color: Color

	# Tint base background slightly toward primary element
	if not el_colors.is_empty():
		accent_color = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.55)
		base_color = base_color.lerp(el_colors[0], 0.08)
	else:
		accent_color = Color(0.35, 0.55, 0.7, 0.35)

	# Main Base Rect
	_draw_contour_rect(t, Rect2(-24, -24, 48, 48))
	t.draw_rect(Rect2(-24, -24, 48, 48), base_color)

	# Element-colored border segments
	# Each element gets an equal portion of the border perimeter
	var border_w := 1.5 if lvl < 3 else 2.0
	if el_colors.is_empty():
		# Neutral: single muted border
		t.draw_rect(Rect2(-24, -24, 48, 48), accent_color, false, border_w)
	elif el_colors.size() == 1:
		# Single element: full border in element color
		var c := Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.7)
		t.draw_rect(Rect2(-24, -24, 48, 48), c, false, border_w)
	elif el_colors.size() == 2:
		# Dual element: top+right = element1, bottom+left = element2
		var c0 := Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.75)
		var c1 := Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.75)
		t.draw_line(Vector2(-24, -24), Vector2(24, -24), c0, border_w)  # top
		t.draw_line(Vector2(24, -24), Vector2(24, 24), c0, border_w)    # right
		t.draw_line(Vector2(24, 24), Vector2(-24, 24), c1, border_w)    # bottom
		t.draw_line(Vector2(-24, 24), Vector2(-24, -24), c1, border_w)  # left
	else:
		# Triple+ element: distribute segments around the border
		var c0 := Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.75)
		var c1 := Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.75)
		var c2 := Color(el_colors[2].r, el_colors[2].g, el_colors[2].b, 0.75)
		t.draw_line(Vector2(-24, -24), Vector2(24, -24), c0, border_w)  # top = el1
		t.draw_line(Vector2(24, -24), Vector2(24, 24), c1, border_w)    # right = el2
		t.draw_line(Vector2(24, 24), Vector2(-24, 24), c2, border_w)    # bottom = el3
		# left side: blend of el1+el3
		var c_left := c0.lerp(c2, 0.5)
		t.draw_line(Vector2(-24, 24), Vector2(-24, -24), c_left, border_w)

	# Corner Ticks — colored per element
	var s = 6.0
	var p = 22.0
	var tick_color := accent_color if el_colors.is_empty() else Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.6)
	var tick_color2 := tick_color
	if el_colors.size() >= 2:
		tick_color2 = Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.6)
	# Top-left & top-right: primary element
	t.draw_line(Vector2(-p, -p), Vector2(-p+s, -p), tick_color)
	t.draw_line(Vector2(-p, -p), Vector2(-p, -p+s), tick_color)
	t.draw_line(Vector2(p, -p), Vector2(p-s, -p), tick_color)
	t.draw_line(Vector2(p, -p), Vector2(p, -p+s), tick_color)
	# Bottom-left & bottom-right: secondary element (or same)
	t.draw_line(Vector2(-p, p), Vector2(-p+s, p), tick_color2)
	t.draw_line(Vector2(-p, p), Vector2(-p, p-s), tick_color2)
	t.draw_line(Vector2(p, p), Vector2(p-s, p), tick_color2)
	t.draw_line(Vector2(p, p), Vector2(p, p-s), tick_color2)

	# Level Details — tier 2+ inner rect tinted toward element
	if lvl >= 2:
		var inner_tint := Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
		if not el_colors.is_empty():
			inner_tint = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.12)
		t.draw_rect(Rect2(-18, -18, 36, 36), inner_tint)
	if lvl >= 3:
		var ring_color := accent_color
		if not el_colors.is_empty():
			ring_color = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.35)
		t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, ring_color, 1.5)

static func _draw_contour_rect(t: Node2D, rect: Rect2) -> void:
	t.draw_rect(rect.grow(TOWER_CONTOUR_PX), TOWER_CONTOUR_COLOR)

static func _draw_contour_circle(t: Node2D, center: Vector2, radius: float) -> void:
	t.draw_circle(center, radius + TOWER_CONTOUR_PX, TOWER_CONTOUR_COLOR)

static func _draw_contour_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	t.draw_line(from, to, TOWER_CONTOUR_COLOR, width + TOWER_CONTOUR_PX * 2.0, true)

static func _draw_contour_poly(t: Node2D, points: PackedVector2Array) -> void:
	t.draw_colored_polygon(_expand_poly_from_center(points, TOWER_CONTOUR_PX), TOWER_CONTOUR_COLOR)

static func _expand_poly_from_center(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		var dir := point.normalized()
		out.append(point + dir * amount)
	return out

static func draw_element_core(t: Node2D) -> void:
	# Draw small element-colored dots in the center of the turret as a visual landmark.
	# 1 element → 1 dot, 2 → 2 dots side-by-side, 3 → triangle of 3 dots.
	var el_colors : Array[Color] = t._get_all_element_colors()
	if el_colors.is_empty():
		return

	var core_r := 3.5  # radius of each core dot
	var glow_r := 5.5  # outer glow ring

	if el_colors.size() == 1:
		# Single element: one bright core
		t.draw_circle(Vector2.ZERO, glow_r, Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.35))
		t.draw_circle(Vector2.ZERO, core_r, el_colors[0])
		t.draw_circle(Vector2.ZERO, 1.5, el_colors[0].lightened(0.6))
	elif el_colors.size() == 2:
		# Dual element: two dots side by side
		var offset_x := 4.5
		for i in range(2):
			var pos := Vector2(-offset_x + i * offset_x * 2, 0)
			t.draw_circle(pos, glow_r - 1.0, Color(el_colors[i].r, el_colors[i].g, el_colors[i].b, 0.3))
			t.draw_circle(pos, core_r - 0.5, el_colors[i])
			t.draw_circle(pos, 1.2, el_colors[i].lightened(0.55))
	else:
		# Triple element: three dots in triangle formation
		var tri_r := 5.0  # distance from center to each dot
		for i in range(mini(el_colors.size(), 3)):
			var angle := -PI / 2.0 + i * TAU / 3.0  # start from top
			var pos := Vector2(cos(angle), sin(angle)) * tri_r
			t.draw_circle(pos, glow_r - 1.5, Color(el_colors[i].r, el_colors[i].g, el_colors[i].b, 0.3))
			t.draw_circle(pos, core_r - 1.0, el_colors[i])
			t.draw_circle(pos, 1.0, el_colors[i].lightened(0.5))
