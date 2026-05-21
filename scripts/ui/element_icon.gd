extends Control
class_name ElementIcon

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

const STATE_UNLOCKED := "unlocked"
const STATE_LOCKED := "locked"
const STATE_PLACEHOLDER := "placeholder"

static var _color_cache: Dictionary = {}
static var element_icon_cache_hits: int = 0    # Redraws suppressed by equality guard
static var element_icon_cache_misses: int = 0  # Redraws actually queued

@export var elements: Array[String] = []:
	set(value):
		var normalized := _normalize_elements(value)
		if normalized == elements:
			element_icon_cache_hits += 1
			return
		element_icon_cache_misses += 1
		elements = normalized
		queue_redraw()

@export var state: String = STATE_UNLOCKED:
	set(value):
		if value == state:
			element_icon_cache_hits += 1
			return
		element_icon_cache_misses += 1
		state = value
		queue_redraw()

@export_range(0, 3, 1) var placeholder_count: int = 0:
	set(value):
		var clamped := clampi(value, 0, 3)
		if clamped == placeholder_count:
			element_icon_cache_hits += 1
			return
		element_icon_cache_misses += 1
		placeholder_count = clamped
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(raw_elements: Array, is_unlocked: bool = true, placeholders: int = 0) -> void:
	var new_elements := _normalize_elements(raw_elements)
	var new_placeholder_count := clampi(placeholders, 0, 3)
	var new_state := STATE_PLACEHOLDER if new_placeholder_count > 0 else (STATE_UNLOCKED if is_unlocked else STATE_LOCKED)
	# Setters have equality guards and call queue_redraw only when values change.
	elements = new_elements
	placeholder_count = new_placeholder_count
	state = new_state
	tooltip_text = get_element_tooltip_text()

func get_element_tooltip_text() -> String:
	if state == STATE_PLACEHOLDER:
		return "Element slots"
	if elements.is_empty():
		return "Neutral"
	var names: Array[String] = []
	for element_id in elements:
		names.append(ElementIconDraw.get_display_name(element_id))
	return " + ".join(names)

static func color_for(element_id: String) -> Color:
	var normalized := ElementIconDraw._normalize(element_id)
	if not _color_cache.has(normalized):
		_color_cache[normalized] = NeonStyle.element_color(normalized)
	return _color_cache[normalized]

static func _normalize_elements(raw_elements: Array) -> Array[String]:
	var out: Array[String] = []
	for raw in raw_elements:
		var normalized := ElementIconDraw._normalize(str(raw))
		if not normalized.is_empty() and not out.has(normalized):
			out.append(normalized)
	return out

func _draw() -> void:
	var box_size: Vector2 = get_size()
	var center: Vector2 = box_size * 0.5
	var radius: float = minf(box_size.x, box_size.y) * 0.50
	if radius <= 1.0:
		return
	if state == STATE_PLACEHOLDER:
		_draw_placeholders(center, radius)
		return
	if elements.is_empty():
		_draw_token_frame(center, radius, Color(0.58, 0.70, 0.76, 1.0))
		_draw_neutral(center, radius * 0.64)
		return
	var count: int = mini(elements.size(), 3)
	if count == 1:
		_draw_token_frame(center, radius, color_for(elements[0]))
		_draw_symbol(elements[0], center, radius * 0.78)
		return
	var slots := _combo_slots(center, radius, count)
	for i in range(count):
		var element_id := elements[i]
		_draw_token_frame(slots[i], radius * 0.48, color_for(element_id))
		_draw_symbol(element_id, slots[i], radius * 0.40)

func _draw_placeholders(center: Vector2, radius: float) -> void:
	var count: int = maxi(placeholder_count, 1)
	var slots := _combo_slots(center, radius, count)
	for slot in slots:
		_draw_dashed_circle(slot, radius * 0.42, Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.34))
		draw_circle(slot, radius * 0.045, Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.72))
	if count >= 2:
		for i in range(count - 1):
			draw_line(slots[i], slots[i + 1], Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.22), maxf(1.0, radius * 0.045), true)

func _combo_slots(center: Vector2, radius: float, count: int) -> Array[Vector2]:
	if count <= 1:
		return [center]
	if count == 2:
		return [center + Vector2(-radius * 0.36, 0.0), center + Vector2(radius * 0.36, 0.0)]
	return [
		center + Vector2(-radius * 0.48, radius * 0.12),
		center + Vector2(0.0, -radius * 0.30),
		center + Vector2(radius * 0.48, radius * 0.12),
	]

func _alpha() -> float:
	# Locked icons must stay readable at gameplay size.
	# The row can be dimmed by the caller, but the element identity should not disappear.
	return 0.68 if state == STATE_LOCKED else 1.0

func _tone(color: Color, alpha_mul: float = 1.0) -> Color:
	var out := color
	if state == STATE_LOCKED:
		# Keep most saturation so the icon still reads as Light/Dark/Water/etc.
		out = Color(
			lerpf(out.r, NeonStyle.INK_3.r, 0.22),
			lerpf(out.g, NeonStyle.INK_3.g, 0.22),
			lerpf(out.b, NeonStyle.INK_3.b, 0.22),
			out.a
		)
	out.a *= _alpha() * alpha_mul
	return out

func _outline(alpha_mul: float = 1.0) -> Color:
	return Color(0.01, 0.02, 0.04, 0.86 * _alpha() * alpha_mul)

func _draw_token_frame(center: Vector2, radius: float, color: Color) -> void:
	# Clean premium octagon token: readable rim + dark fill + very small glow.
	# Avoid noisy nested outlines because these icons are viewed at 32-44 px.
	var glow := _regular_poly(center, radius * 1.02, 8, PI / 8.0)
	var outer := _regular_poly(center, radius * 0.94, 8, PI / 8.0)
	var inner := _regular_poly(center, radius * 0.80, 8, PI / 8.0)
	var fill_color := Color(0.012, 0.024, 0.040, 0.88 * _alpha())
	draw_colored_polygon(glow, _tone(color, 0.13))
	draw_colored_polygon(outer, Color(0.020, 0.040, 0.062, 0.82 * _alpha()))
	draw_colored_polygon(inner, fill_color)
	_draw_closed_polyline(outer, _tone(color, 0.78), maxf(1.25, radius * 0.075))
	_draw_closed_polyline(inner, _tone(color, 0.25), maxf(1.0, radius * 0.035))

func _regular_poly(center: Vector2, radius: float, sides: int, poly_rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / float(sides)) * TAU - PI / 2.0 + poly_rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color) -> void:
	var segments := 16
	for i in range(segments):
		if i % 2 == 1:
			continue
		var start := float(i) / float(segments) * TAU
		var end := float(i + 1) / float(segments) * TAU
		draw_arc(center, radius, start, end, 6, color, 2.0, true)

func _draw_symbol(element_id: String, center: Vector2, radius: float) -> void:
	match ElementIconDraw._normalize(element_id):
		"light": _draw_light(center, radius)
		"darkness": _draw_darkness(center, radius)
		"water": _draw_water(center, radius)
		"fire": _draw_fire(center, radius)
		"nature": _draw_nature(center, radius)
		"earth": _draw_earth(center, radius)
		"__interest__": _draw_interest(center, radius)
		_: _draw_neutral(center, radius)

func _draw_poly(points: PackedVector2Array, fill: Color, line: Color = Color.TRANSPARENT, line_width: float = 1.2) -> void:
	draw_colored_polygon(points, _tone(fill))
	if line.a > 0.0:
		_draw_closed_polyline(points, _tone(line), line_width)

func _draw_soft_disc(center: Vector2, radius: float, color: Color) -> void:
	# Small static glow only; symbols themselves carry the readability.
	draw_circle(center, radius, _tone(color, 0.14))

func _draw_neutral(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.05, Color(0.68, 0.86, 0.96, 1.0))
	var base := PackedVector2Array([
		center + Vector2(-radius * 0.62, radius * 0.40),
		center + Vector2(radius * 0.62, radius * 0.40),
		center + Vector2(radius * 0.38, radius * 0.68),
		center + Vector2(-radius * 0.38, radius * 0.68),
	])
	_draw_poly(base, Color(0.55, 0.67, 0.74, 0.88), Color(0.85, 0.96, 1.0, 0.70))
	draw_rect(Rect2(center + Vector2(-radius * 0.11, -radius * 0.40), Vector2(radius * 0.22, radius * 0.78)), _tone(Color(0.72, 0.86, 0.93, 0.86)))
	draw_circle(center + Vector2(0.0, -radius * 0.52), radius * 0.24, _tone(Color(0.88, 0.98, 1.0, 0.82)))
	draw_line(center + Vector2(-radius * 0.48, radius * 0.10), center + Vector2(radius * 0.48, radius * 0.10), _outline(0.65), maxf(1.0, radius * 0.10), true)
	draw_circle(center + Vector2(0.0, -radius * 0.52), radius * 0.09, _outline(0.70))

func _draw_light(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.12, Color(1.0, 0.86, 0.12, 1.0))
	var star := PackedVector2Array()
	for i in range(16):
		var angle := float(i) / 16.0 * TAU - PI / 2.0
		var r := radius if i % 2 == 0 else radius * 0.38
		star.append(center + Vector2(cos(angle), sin(angle)) * r)
	_draw_poly(star, Color(1.0, 0.78, 0.08, 0.97), Color(1.0, 0.96, 0.58, 0.84), maxf(1.0, radius * 0.06))
	draw_circle(center, radius * 0.26, _tone(Color(1.0, 1.0, 0.82, 0.94)))
	draw_circle(center, radius * 0.09, _tone(Color(1.0, 0.70, 0.12, 0.94)))

func _draw_darkness(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.10, Color(0.64, 0.22, 1.0, 1.0))
	# Crescent with clean symmetry: purple moon cut by dark disc.
	draw_circle(center + Vector2(-radius * 0.08, 0.0), radius * 0.84, _tone(Color(0.66, 0.27, 1.0, 0.96)))
	draw_circle(center + Vector2(radius * 0.23, -radius * 0.03), radius * 0.72, Color(0.015, 0.026, 0.045, 0.97 * _alpha()))
	draw_arc(center + Vector2(-radius * 0.08, 0.0), radius * 0.84, PI * 0.55, PI * 1.45, 24, _tone(Color(0.88, 0.68, 1.0, 0.72)), maxf(1.0, radius * 0.05), true)
	draw_circle(center + Vector2(radius * 0.18, -radius * 0.46), radius * 0.07, _tone(Color(0.94, 0.82, 1.0, 0.82)))

func _draw_water(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.08, Color(0.05, 0.66, 1.0, 1.0))
	var drop := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.46, -radius * 0.10),
		center + Vector2(radius * 0.34, radius * 0.58),
		center + Vector2(0.0, radius * 0.86),
		center + Vector2(-radius * 0.34, radius * 0.58),
		center + Vector2(-radius * 0.46, -radius * 0.10),
	])
	_draw_poly(drop, Color(0.10, 0.70, 1.0, 0.97), Color(0.72, 0.94, 1.0, 0.82), maxf(1.0, radius * 0.05))
	draw_circle(center + Vector2(-radius * 0.13, radius * 0.10), radius * 0.15, _tone(Color(0.86, 0.98, 1.0, 0.62)))
	draw_arc(center + Vector2(0.0, radius * 0.30), radius * 0.35, 0.18, PI - 0.18, 12, _tone(Color(0.80, 0.96, 1.0, 0.40)), 1.0, true)

func _draw_fire(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.10, Color(1.0, 0.24, 0.02, 1.0))
	var outer := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.42, -radius * 0.32),
		center + Vector2(radius * 0.64, radius * 0.18),
		center + Vector2(radius * 0.38, radius * 0.78),
		center + Vector2(0.0, radius * 0.94),
		center + Vector2(-radius * 0.38, radius * 0.78),
		center + Vector2(-radius * 0.64, radius * 0.18),
		center + Vector2(-radius * 0.42, -radius * 0.32),
	])
	_draw_poly(outer, Color(1.0, 0.27, 0.04, 0.98), Color(1.0, 0.62, 0.20, 0.82), maxf(1.0, radius * 0.05))
	var inner := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.48),
		center + Vector2(radius * 0.26, radius * 0.04),
		center + Vector2(radius * 0.18, radius * 0.55),
		center + Vector2(0.0, radius * 0.38),
		center + Vector2(-radius * 0.18, radius * 0.55),
		center + Vector2(-radius * 0.26, radius * 0.04),
	])
	draw_colored_polygon(inner, _tone(Color(1.0, 0.78, 0.10, 0.96)))
	draw_line(center + Vector2(0.0, -radius * 0.42), center + Vector2(0.0, radius * 0.48), _tone(Color(1.0, 0.92, 0.40, 0.34)), 1.0, true)

func _draw_nature(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.10, Color(0.24, 0.86, 0.34, 1.0))
	# Leaf is drawn around an explicit center vein so it reads cleanly at small size.
	var leaf := PackedVector2Array([
		center + Vector2(-radius * 0.66, radius * 0.36),
		center + Vector2(-radius * 0.32, -radius * 0.22),
		center + Vector2(radius * 0.70, -radius * 0.64),
		center + Vector2(radius * 0.48, radius * 0.20),
		center + Vector2(-radius * 0.10, radius * 0.70),
	])
	_draw_poly(leaf, Color(0.25, 0.86, 0.34, 0.97), Color(0.64, 1.0, 0.66, 0.76), maxf(1.0, radius * 0.05))
	draw_line(center + Vector2(-radius * 0.50, radius * 0.38), center + Vector2(radius * 0.50, -radius * 0.42), _tone(Color(0.04, 0.34, 0.10, 0.64)), maxf(1.0, radius * 0.055), true)
	draw_line(center + Vector2(-radius * 0.04, radius * 0.00), center + Vector2(-radius * 0.28, -radius * 0.02), _tone(Color(0.04, 0.34, 0.10, 0.36)), 1.0, true)
	draw_line(center + Vector2(radius * 0.12, -radius * 0.14), center + Vector2(radius * 0.02, -radius * 0.38), _tone(Color(0.04, 0.34, 0.10, 0.36)), 1.0, true)

func _draw_earth(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.08, Color(0.86, 0.55, 0.30, 1.0))
	var crystal := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.52, -radius * 0.38),
		center + Vector2(radius * 0.42, radius * 0.62),
		center + Vector2(0.0, radius * 0.94),
		center + Vector2(-radius * 0.42, radius * 0.62),
		center + Vector2(-radius * 0.52, -radius * 0.38),
	])
	_draw_poly(crystal, Color(0.78, 0.48, 0.26, 0.98), Color(1.0, 0.78, 0.52, 0.76), maxf(1.0, radius * 0.05))
	var left_facet := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.90),
		center + Vector2(0.0, radius * 0.80),
		center + Vector2(-radius * 0.38, radius * 0.55),
		center + Vector2(-radius * 0.47, -radius * 0.30),
	])
	draw_colored_polygon(left_facet, _tone(Color(0.54, 0.30, 0.16, 0.38)))
	draw_line(center + Vector2(0.0, -radius * 0.84), center + Vector2(0.0, radius * 0.80), _tone(Color(1.0, 0.88, 0.68, 0.48)), 1.1, true)
	draw_line(center + Vector2(-radius * 0.44, -radius * 0.26), center + Vector2(0.0, radius * 0.80), _tone(Color(0.25, 0.13, 0.07, 0.36)), 1.0, true)
	draw_line(center + Vector2(radius * 0.44, -radius * 0.26), center + Vector2(0.0, radius * 0.80), _tone(Color(1.0, 0.86, 0.62, 0.30)), 1.0, true)

func _draw_interest(center: Vector2, radius: float) -> void:
	_draw_soft_disc(center, radius * 1.12, Color(0.74, 0.48, 1.0, 1.0))
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.76, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.76, 0.0),
	])
	_draw_poly(diamond, Color(0.75, 0.48, 0.94, 0.98), Color(1.0, 0.88, 1.0, 0.78), maxf(1.0, radius * 0.05))
	draw_line(center + Vector2(0.0, -radius * 0.86), center + Vector2(0.0, radius * 0.86), _tone(Color(1.0, 0.94, 1.0, 0.48)), 1.0, true)
	draw_line(center + Vector2(-radius * 0.62, 0.0), center + Vector2(radius * 0.62, 0.0), _tone(Color(0.36, 0.16, 0.58, 0.42)), 1.0, true)
	draw_arc(center, radius * 0.40, 0.0, TAU, 24, _tone(Color(1.0, 0.92, 0.32, 0.86)), maxf(1.0, radius * 0.06), true)
