extends RefCounted
class_name TowerVisualDrawUtils

# Shared CanvasItem drawing helpers for tower visual files.
# Visual-only. Do not put gameplay, attack, targeting, or upgrade logic here.

const TOWER_CONTOUR_PX := 1.6
const TOWER_CONTOUR_COLOR := Color(0.0, 0.0, 0.0, 0.78)
const BASE_COLOR := Color(0.06, 0.08, 0.12, 1.0)
const NEUTRAL_ACCENT := Color(0.35, 0.55, 0.7, 0.35)
const BASE_RECT := Rect2(-24, -24, 48, 48)
const INNER_RECT := Rect2(-18, -18, 36, 36)
const CORE_SINGLE := [Vector2.ZERO]
const CORE_DUAL := [Vector2(-4.5, 0), Vector2(4.5, 0)]
const CORE_TRIPLE := [
	Vector2(0, -5),
	Vector2(4.330127, 2.5),
	Vector2(-4.330127, 2.5),
]
const CORNER_TICKS := [
	[Vector2(-22, -22), Vector2(-16, -22)],
	[Vector2(-22, -22), Vector2(-22, -16)],
	[Vector2(22, -22), Vector2(16, -22)],
	[Vector2(22, -22), Vector2(22, -16)],
	[Vector2(-22, 22), Vector2(-16, 22)],
	[Vector2(-22, 22), Vector2(-22, 16)],
	[Vector2(22, 22), Vector2(16, 22)],
	[Vector2(22, 22), Vector2(22, 16)],
]

static var _element_color_cache: Dictionary = {}
static var _base_plate_cache: Dictionary = {}
static var _element_core_layout_cache: Dictionary = {
	1: CORE_SINGLE,
	2: CORE_DUAL,
	3: CORE_TRIPLE,
}

static func _element_signature(t: Node2D) -> String:
	var parts: Array[String] = []
	var raw_elements: Array = t.get("elements") if t.get("elements") != null else []
	for element in raw_elements:
		parts.append(str(element))
	return "|".join(parts)

static func _get_element_color(element_id: String) -> Color:
	match element_id:
		"light": return Color(1.0, 0.88, 0.1)
		"darkness": return Color(0.55, 0.12, 0.85)
		"water": return Color(0.15, 0.55, 1.0)
		"fire": return Color(1.0, 0.18, 0.08)
		"nature": return Color(0.1, 0.78, 0.25)
		"earth": return Color(0.68, 0.42, 0.16)
		_: return Color.WHITE

static func _get_element_colors(t: Node2D) -> Array:
	var signature := _element_signature(t)
	if _element_color_cache.has(signature):
		return _element_color_cache[signature]
	var colors: Array[Color] = []
	var raw_elements: Array = t.get("elements") if t.get("elements") != null else []
	for element in raw_elements:
		colors.append(_get_element_color(str(element)))
	_element_color_cache[signature] = colors
	return colors

static func _get_base_plate_cache(t: Node2D) -> Dictionary:
	var lvl: int = int(t.get("tree_tier"))
	var signature := "%d:%s" % [lvl, _element_signature(t)]
	if _base_plate_cache.has(signature):
		return _base_plate_cache[signature]

	var el_colors := _get_element_colors(t)
	var base_color := BASE_COLOR
	var accent_color := NEUTRAL_ACCENT
	if not el_colors.is_empty():
		accent_color = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.55)
		base_color = base_color.lerp(el_colors[0], 0.08)

	var border_w := 1.5 if lvl < 3 else 2.0
	var tick_primary := accent_color
	var tick_secondary := tick_primary
	var border_colors: Array[Color] = []
	if el_colors.is_empty():
		border_colors = [accent_color]
	else:
		for c in el_colors:
			border_colors.append(Color(c.r, c.g, c.b, 0.75))
		tick_primary = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.6)
		tick_secondary = tick_primary
		if el_colors.size() >= 2:
			tick_secondary = Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.6)

	var data := {
		"level": lvl,
		"element_colors": el_colors,
		"base_color": base_color,
		"accent_color": accent_color,
		"border_w": border_w,
		"border_colors": border_colors,
		"tick_primary": tick_primary,
		"tick_secondary": tick_secondary,
		"inner_tint": Color(accent_color.r, accent_color.g, accent_color.b, 0.12),
		"ring_color": Color(accent_color.r, accent_color.g, accent_color.b, 0.35),
	}
	_base_plate_cache[signature] = data
	return data

static func draw_base_plate(t: Node2D) -> void:
	var data := _get_base_plate_cache(t)
	var lvl: int = data["level"]
	var el_colors: Array = data["element_colors"]
	var border_colors: Array = data["border_colors"]

	# Main Base Rect
	_draw_contour_rect(t, BASE_RECT)
	t.draw_rect(BASE_RECT, data["base_color"])

	# Element-colored border segments
	# Each element gets an equal portion of the border perimeter
	var border_w: float = data["border_w"]
	if el_colors.is_empty():
		# Neutral: single muted border
		t.draw_rect(BASE_RECT, data["accent_color"], false, border_w)
	elif el_colors.size() == 1:
		# Single element: full border in element color
		t.draw_rect(BASE_RECT, border_colors[0], false, border_w)
	elif el_colors.size() == 2:
		# Dual element: top+right = element1, bottom+left = element2
		var c0: Color = border_colors[0]
		var c1: Color = border_colors[1]
		t.draw_line(Vector2(-24, -24), Vector2(24, -24), c0, border_w)  # top
		t.draw_line(Vector2(24, -24), Vector2(24, 24), c0, border_w)    # right
		t.draw_line(Vector2(24, 24), Vector2(-24, 24), c1, border_w)    # bottom
		t.draw_line(Vector2(-24, 24), Vector2(-24, -24), c1, border_w)  # left
	else:
		# Triple+ element: distribute segments around the border
		var c0: Color = border_colors[0]
		var c1: Color = border_colors[1]
		var c2: Color = border_colors[2]
		t.draw_line(Vector2(-24, -24), Vector2(24, -24), c0, border_w)  # top = el1
		t.draw_line(Vector2(24, -24), Vector2(24, 24), c1, border_w)    # right = el2
		t.draw_line(Vector2(24, 24), Vector2(-24, 24), c2, border_w)    # bottom = el3
		# left side: blend of el1+el3
		var c_left := c0.lerp(c2, 0.5)
		t.draw_line(Vector2(-24, 24), Vector2(-24, -24), c_left, border_w)

	# Corner Ticks — colored per element
	var tick_color: Color = data["tick_primary"]
	var tick_color2: Color = data["tick_secondary"]
	# Top-left & top-right: primary element
	for i in range(4):
		t.draw_line(CORNER_TICKS[i][0], CORNER_TICKS[i][1], tick_color)
	# Bottom-left & bottom-right: secondary element (or same)
	for i in range(4, 8):
		t.draw_line(CORNER_TICKS[i][0], CORNER_TICKS[i][1], tick_color2)

	# Level Details — tier 2+ inner rect tinted toward element
	if lvl >= 2:
		t.draw_rect(INNER_RECT, data["inner_tint"])
	if lvl >= 3:
		t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, data["ring_color"], 1.5)

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
	var el_colors := _get_element_colors(t)
	if el_colors.is_empty():
		return

	var core_r := 3.5  # radius of each core dot
	var glow_r := 5.5  # outer glow ring
	var layout: Array = _element_core_layout_cache[mini(el_colors.size(), 3)]

	if el_colors.size() == 1:
		# Single element: one bright core
		var pos: Vector2 = layout[0]
		t.draw_circle(pos, glow_r, Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.35))
		t.draw_circle(pos, core_r, el_colors[0])
		t.draw_circle(pos, 1.5, el_colors[0].lightened(0.6))
	elif el_colors.size() == 2:
		# Dual element: two dots side by side
		for i in range(2):
			var pos: Vector2 = layout[i]
			t.draw_circle(pos, glow_r - 1.0, Color(el_colors[i].r, el_colors[i].g, el_colors[i].b, 0.3))
			t.draw_circle(pos, core_r - 0.5, el_colors[i])
			t.draw_circle(pos, 1.2, el_colors[i].lightened(0.55))
	else:
		# Triple element: three dots in triangle formation
		for i in range(mini(el_colors.size(), 3)):
			var pos: Vector2 = layout[i]
			t.draw_circle(pos, glow_r - 1.5, Color(el_colors[i].r, el_colors[i].g, el_colors[i].b, 0.3))
			t.draw_circle(pos, core_r - 1.0, el_colors[i])
			t.draw_circle(pos, 1.0, el_colors[i].lightened(0.5))
