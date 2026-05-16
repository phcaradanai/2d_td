extends Control
class_name ElementIcon

const NeonStyle = preload("res://scripts/ui/neon_terminal_style.gd")

const STATE_UNLOCKED := "unlocked"
const STATE_LOCKED := "locked"
const STATE_PLACEHOLDER := "placeholder"

static var _color_cache: Dictionary = {}

@export var elements: Array[String] = []:
	set(value):
		elements = _normalize_elements(value)
		queue_redraw()

@export var state: String = STATE_UNLOCKED:
	set(value):
		state = value
		queue_redraw()

@export_range(0, 3, 1) var placeholder_count: int = 0:
	set(value):
		placeholder_count = clampi(value, 0, 3)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(raw_elements: Array, is_unlocked: bool = true, placeholders: int = 0) -> void:
	elements = _normalize_elements(raw_elements)
	placeholder_count = clampi(placeholders, 0, 3)
	state = STATE_UNLOCKED if is_unlocked else STATE_LOCKED
	if placeholder_count > 0:
		state = STATE_PLACEHOLDER
	tooltip_text = get_element_tooltip_text()
	queue_redraw()

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
	var size: Vector2 = get_size()
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.48
	if radius <= 1.0:
		return
	if state == STATE_PLACEHOLDER:
		_draw_placeholders(center, radius)
		return
	if elements.is_empty():
		_draw_token_frame(center, radius, Color(0.55, 0.67, 0.74, 1.0))
		_draw_neutral(center, radius * 0.64)
		return
	var count: int = mini(elements.size(), 3)
	if count == 1:
		_draw_token_frame(center, radius, color_for(elements[0]))
		_draw_symbol(elements[0], center, radius * 0.60)
		return
	var slots := _combo_slots(center, radius, count)
	for i in range(count):
		var element_id := elements[i]
		_draw_token_frame(slots[i], radius * 0.48, color_for(element_id))
		_draw_symbol(element_id, slots[i], radius * 0.31)

func _draw_placeholders(center: Vector2, radius: float) -> void:
	var count: int = maxi(placeholder_count, 1)
	var slots := _combo_slots(center, radius, count)
	for slot in slots:
		_draw_dashed_circle(slot, radius * 0.42, Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.35))
		draw_circle(slot, radius * 0.045, Color(NeonStyle.CYAN.r, NeonStyle.CYAN.g, NeonStyle.CYAN.b, 0.75))

func _combo_slots(center: Vector2, radius: float, count: int) -> Array[Vector2]:
	if count <= 1:
		return [center]
	if count == 2:
		return [center + Vector2(-radius * 0.36, 0.0), center + Vector2(radius * 0.36, 0.0)]
	return [
		center + Vector2(-radius * 0.48, radius * 0.12),
		center + Vector2(0.0, -radius * 0.28),
		center + Vector2(radius * 0.48, radius * 0.12),
	]

func _alpha() -> float:
	if state == STATE_LOCKED:
		return 0.48
	return 1.0

func _tone(color: Color, alpha_mul: float = 1.0) -> Color:
	var out := color
	if state == STATE_LOCKED:
		out = Color(
			lerpf(out.r, NeonStyle.INK_3.r, 0.62),
			lerpf(out.g, NeonStyle.INK_3.g, 0.62),
			lerpf(out.b, NeonStyle.INK_3.b, 0.62),
			out.a
		)
	out.a *= _alpha() * alpha_mul
	return out

func _outline(alpha_mul: float = 1.0) -> Color:
	return Color(0.01, 0.02, 0.04, 0.82 * _alpha() * alpha_mul)

func _draw_token_frame(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := (float(i) / 6.0) * TAU - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.92)
	draw_colored_polygon(points, Color(0.02, 0.04, 0.07, 0.56 * _alpha()))
	_draw_closed_polyline(points, _tone(color, 0.74), maxf(1.0, radius * 0.070))
	_draw_closed_polyline(points, Color(NeonStyle.INK_1.r, NeonStyle.INK_1.g, NeonStyle.INK_1.b, 0.10 * _alpha()), 1.0)

func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color) -> void:
	var segments := 12
	for i in range(segments):
		if i % 2 == 1:
			continue
		var start := float(i) / float(segments) * TAU
		var end := float(i + 1) / float(segments) * TAU
		draw_arc(center, radius, start, end, 5, color, 2.0, true)

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

func _draw_poly(points: PackedVector2Array, fill: Color, line: Color = Color.TRANSPARENT) -> void:
	draw_colored_polygon(points, _tone(fill))
	if line.a > 0.0:
		_draw_closed_polyline(points, _tone(line), 1.2)

func _draw_neutral(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := (float(i) / 6.0) * TAU - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_draw_poly(points, Color(0.58, 0.70, 0.76, 0.82), Color(0.86, 0.96, 1.0, 0.76))
	draw_circle(center, radius * 0.38, _tone(Color(0.90, 0.98, 1.0, 0.75)))
	draw_circle(center, radius * 0.16, Color(0.03, 0.05, 0.08, 0.72 * _alpha()))

func _draw_light(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := float(i) / 10.0 * TAU - PI / 2.0
		var r := radius if i % 2 == 0 else radius * 0.38
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	_draw_poly(points, Color(1.0, 0.84, 0.14, 0.96), Color(1.0, 0.96, 0.62, 0.82))
	draw_circle(center, radius * 0.22, _tone(Color(1.0, 1.0, 0.82, 0.90)))

func _draw_darkness(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, _outline())
	draw_circle(center, radius * 0.92, _tone(Color(0.65, 0.26, 0.98, 0.96)))
	draw_circle(center + Vector2(radius * 0.34, -radius * 0.04), radius * 0.78, Color(0.02, 0.03, 0.06, 0.96 * _alpha()))
	draw_circle(center + Vector2(-radius * 0.26, -radius * 0.28), radius * 0.11, _tone(Color(0.88, 0.74, 1.0, 0.78)))

func _draw_water(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.58, radius * 0.08),
		center + Vector2(radius * 0.42, radius * 0.74),
		center + Vector2(0.0, radius * 0.94),
		center + Vector2(-radius * 0.42, radius * 0.74),
		center + Vector2(-radius * 0.58, radius * 0.08),
	])
	_draw_poly(points, Color(0.12, 0.70, 1.0, 0.96), Color(0.72, 0.94, 1.0, 0.78))
	draw_circle(center + Vector2(-radius * 0.16, radius * 0.08), radius * 0.14, _tone(Color(0.80, 0.96, 1.0, 0.58)))

func _draw_fire(center: Vector2, radius: float) -> void:
	var outer := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.56, -radius * 0.08),
		center + Vector2(radius * 0.70, radius * 0.56),
		center + Vector2(0.0, radius * 0.86),
		center + Vector2(-radius * 0.70, radius * 0.56),
		center + Vector2(-radius * 0.56, -radius * 0.08),
	])
	_draw_poly(outer, Color(1.0, 0.30, 0.04, 0.96), Color(1.0, 0.62, 0.20, 0.82))
	var inner := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.52),
		center + Vector2(radius * 0.32, radius * 0.12),
		center + Vector2(radius * 0.26, radius * 0.55),
		center + Vector2(0.0, radius * 0.42),
		center + Vector2(-radius * 0.26, radius * 0.55),
		center + Vector2(-radius * 0.32, radius * 0.12),
	])
	draw_colored_polygon(inner, _tone(Color(1.0, 0.78, 0.12, 0.95)))

func _draw_nature(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var base := Vector2(cos(angle) * radius * 0.52, sin(angle) * radius)
		points.append(center + base.rotated(-PI * 0.22))
	_draw_poly(points, Color(0.24, 0.88, 0.36, 0.96), Color(0.62, 1.0, 0.66, 0.70))
	draw_line(center + Vector2(0.0, -radius * 0.86).rotated(-PI * 0.22), center + Vector2(0.0, radius * 0.86).rotated(-PI * 0.22), _tone(Color(0.02, 0.34, 0.10, 0.62)), 1.1, true)

func _draw_earth(center: Vector2, radius: float) -> void:
	var crystal := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.58, -radius * 0.28),
		center + Vector2(radius * 0.42, radius * 0.76),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.42, radius * 0.76),
		center + Vector2(-radius * 0.58, -radius * 0.28),
	])
	_draw_poly(crystal, Color(0.86, 0.58, 0.32, 0.96), Color(1.0, 0.78, 0.50, 0.72))
	draw_line(center + Vector2(0.0, -radius * 0.86), center + Vector2(0.0, radius * 0.78), _tone(Color(1.0, 0.88, 0.68, 0.55)), 1.1, true)
	draw_line(center + Vector2(-radius * 0.48, -radius * 0.20), center + Vector2(0.0, radius * 0.78), _tone(Color(0.30, 0.16, 0.08, 0.32)), 1.0, true)

func _draw_interest(center: Vector2, radius: float) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.74, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.74, 0.0),
	])
	_draw_poly(diamond, Color(0.78, 0.57, 0.92, 0.96), Color(1.0, 0.88, 1.0, 0.74))
	draw_arc(center, radius * 0.38, 0.0, TAU, 18, _tone(Color(1.0, 0.94, 1.0, 0.78)), 1.4, true)
