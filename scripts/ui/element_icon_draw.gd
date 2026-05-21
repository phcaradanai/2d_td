extends Control
class_name ElementIconDraw

## ElementIconDraw
## [DEPLOY-FIX] Font-free element icon renderer for web/desktop/editor parity.
## Draws element symbols using Canvas2D draw calls only.
## No unicode glyphs, no emoji, no icon fonts — safe for all export targets.
##
## Usage:
##   var icon := ElementIconDraw.new()
##   icon.element_id = "fire"
##   icon.custom_minimum_size = Vector2(36, 36)
##   parent.add_child(icon)
##
## Static helpers:
##   ElementIconDraw.get_color("fire")       → Color(1.0, 0.18, 0.08)
##   ElementIconDraw.get_short_code("fire")  → "F"
##   ElementIconDraw.get_display_name("fire")        → "Fire"

@export var element_id: String = "" :
	set(v):
		if v == element_id:
			return
		element_id = v
		queue_redraw()

## Scale factor 0.0–1.0 applied to icon brightness (used for locked/maxed states).
@export var icon_alpha: float = 1.0 :
	set(v):
		var clamped := clampf(v, 0.0, 1.0)
		if absf(clamped - icon_alpha) < 0.001:
			return
		icon_alpha = clamped
		queue_redraw()

# ── Static helpers ──────────────────────────────────────────────────────────

static func get_color(eid: String) -> Color:
	match _normalize(eid):
		"light":     return Color(1.0, 0.86, 0.12)
		"darkness":  return Color(0.62, 0.18, 0.95)
		"water":     return Color(0.12, 0.70, 1.0)
		"fire":      return Color(1.0, 0.26, 0.06)
		"nature":    return Color(0.18, 0.86, 0.28)
		"earth":     return Color(0.78, 0.50, 0.20)
		"__interest__": return Color(0.74, 0.56, 1.0)
		_:           return Color.WHITE

## Single-letter safe ASCII code — never a raw numeric ID.
static func get_short_code(eid: String) -> String:
	match _normalize(eid):
		"light":     return "L"
		"darkness":  return "D"
		"water":     return "W"
		"fire":      return "F"
		"nature":    return "Na"
		"earth":     return "E"
		"__interest__": return "$"
		_:           return "?"

static func get_display_name(eid: String) -> String:
	match _normalize(eid):
		"light":     return "Light"
		"darkness":  return "Darkness"
		"water":     return "Water"
		"fire":      return "Fire"
		"nature":    return "Nature"
		"earth":     return "Earth"
		"__interest__": return "Interest"
		_:           return eid.capitalize() if eid != "" else "?"

## Normalise numeric legacy IDs (0–5) to canonical string names.
## Guards against raw array indices appearing in UI.
static func _normalize(eid: String) -> String:
	var value := eid.to_lower().strip_edges()
	match value:
		"0": return "light"
		"1": return "darkness"
		"2": return "water"
		"3": return "fire"
		"4": return "nature"
		"5": return "earth"
		"interest", "interest_bonus", "bonus_interest": return "__interest__"
		_:   return value

# ── Rendering ───────────────────────────────────────────────────────────────

func _draw() -> void:
	var sz  := get_size()
	var c   := sz / 2.0
	var s   : float = min(sz.x, sz.y) * 0.38
	if s <= 0.0:
		return
	match _normalize(element_id):
		"fire":      _draw_fire(c, s)
		"water":     _draw_water(c, s)
		"nature":    _draw_nature(c, s)
		"earth":     _draw_earth(c, s)
		"light":     _draw_light(c, s)
		"darkness":  _draw_darkness(c, s)
		"__interest__": _draw_interest(c, s)
		_:           _draw_fallback(c, s)

# ── Per-element draw helpers ─────────────────────────────────────────────────

func _with_alpha(color: Color, alpha_mul: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha_mul * icon_alpha)

func _outline_color(alpha_mul: float = 1.0) -> Color:
	return Color(0.0, 0.0, 0.0, 0.72 * alpha_mul * icon_alpha)

func _close(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if points.size() > 0:
		out.append(points[0])
	return out

func _stroke_polygon(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(_close(points), color, width, true)

func _draw_poly_symbol(points: PackedVector2Array, fill: Color, stroke_width: float = 2.0) -> void:
	_stroke_polygon(points, _outline_color(), stroke_width + 1.4)
	draw_colored_polygon(points, _with_alpha(fill, 1.0))
	_stroke_polygon(points, _with_alpha(fill.lightened(0.28), 0.85), stroke_width)

## Fire: two-layer upward flame shape (orange outer, yellow inner).
func _draw_fire(c: Vector2, s: float) -> void:
	# Outer flame — orange
	var outer := PackedVector2Array([
		c + Vector2( 0.00, -s * 1.00),
		c + Vector2( s * 0.52, -s * 0.12),
		c + Vector2( s * 0.74,  s * 0.58),
		c + Vector2( 0.00,  s * 0.74),
		c + Vector2(-s * 0.74,  s * 0.58),
		c + Vector2(-s * 0.52, -s * 0.12),
	])
	_draw_poly_symbol(outer, Color(1.0, 0.30, 0.04, 0.96), 1.4)
	# Inner flame — yellow
	var inner := PackedVector2Array([
		c + Vector2( 0.00, -s * 0.58),
		c + Vector2( s * 0.30,  s * 0.10),
		c + Vector2( s * 0.38,  s * 0.52),
		c + Vector2( 0.00,  s * 0.44),
		c + Vector2(-s * 0.38,  s * 0.52),
		c + Vector2(-s * 0.30,  s * 0.10),
	])
	draw_colored_polygon(inner, _with_alpha(Color(1.0, 0.76, 0.06, 0.98), 1.0))

## Water: teardrop — tapered top point, circular lower body.
func _draw_water(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	var segs := 16
	pts.append(c + Vector2(0.0, -s * 1.02))
	pts.append(c + Vector2(s * 0.36, -s * 0.42))
	for i in range(segs + 1):
		var ang := -0.22 + float(i) / float(segs) * (PI + 0.44)
		pts.append(c + Vector2(cos(ang) * s * 0.66, sin(ang) * s * 0.58 + s * 0.18))
	pts.append(c + Vector2(-s * 0.36, -s * 0.42))
	_draw_poly_symbol(pts, Color(0.12, 0.70, 1.0, 0.95), 1.4)
	# Highlight glint (top-left)
	draw_circle(c + Vector2(-s * 0.18, s * 0.02), s * 0.14, _with_alpha(Color(0.80, 0.96, 1.0, 0.58), 1.0))

## Nature: simple leaf — elongated lozenge rotated 45°, with a center vein.
func _draw_nature(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	# Leaf polygon (12 points, ellipse rotated ~45°)
	for i in range(12):
		var ang := float(i) / 12.0 * TAU
		var px := cos(ang) * s * 0.46
		var py := sin(ang) * s * 0.92
		pts.append(c + Vector2(px, py).rotated(-PI * 0.22))
	_draw_poly_symbol(pts, Color(0.18, 0.86, 0.28, 0.95), 1.4)
	# Center vein
	var tip_a := Vector2(0.0, -s * 0.92).rotated(-PI * 0.22)
	var tip_b := Vector2(0.0,  s * 0.92).rotated(-PI * 0.22)
	draw_line(c + tip_a, c + tip_b, _with_alpha(Color(0.02, 0.38, 0.11, 0.72), 1.0), 1.3, true)
	draw_line(c, c + Vector2(s * 0.27, -s * 0.06).rotated(-PI * 0.22), _with_alpha(Color(0.02, 0.38, 0.11, 0.46), 1.0), 1.0, true)

## Earth: flat gem/hexagon — upper narrow + lower wide facets.
func _draw_earth(c: Vector2, s: float) -> void:
	# Outer hex/gem shape (6 points, slightly squashed)
	var outer := PackedVector2Array()
	for i in range(6):
		var ang := float(i) / 6.0 * TAU - PI / 2.0
		outer.append(c + Vector2(cos(ang) * s * 0.88, sin(ang) * s * 0.82))
	_draw_poly_symbol(outer, Color(0.78, 0.50, 0.20, 0.95), 1.5)
	# Inner facet highlight (top two-thirds)
	var inner := PackedVector2Array([
		c + Vector2( 0.00, -s * 0.62),
		c + Vector2( s * 0.46, -s * 0.20),
		c + Vector2( s * 0.46,  s * 0.26),
		c + Vector2( 0.00,  s * 0.18),
		c + Vector2(-s * 0.46,  s * 0.26),
		c + Vector2(-s * 0.46, -s * 0.20),
	])
	draw_colored_polygon(inner, _with_alpha(Color(0.96, 0.68, 0.34, 0.70), 1.0))
	draw_line(c + Vector2(-s * 0.46, -s * 0.20), c + Vector2(s * 0.46, s * 0.26), _with_alpha(Color(0.28, 0.16, 0.06, 0.34), 1.0), 1.0, true)

## Light: 4-pointed star with a bright center core.
func _draw_light(c: Vector2, s: float) -> void:
	# 4-pointed star (8 vertices: 4 outer tips + 4 inner)
	var pts := PackedVector2Array()
	for i in range(8):
		var ang := float(i) / 8.0 * TAU - PI / 4.0
		var r := s * 0.92 if i % 2 == 0 else s * 0.30
		pts.append(c + Vector2.RIGHT.rotated(ang) * r)
	_draw_poly_symbol(pts, Color(1.0, 0.86, 0.12, 0.96), 1.4)
	# Bright center disc
	draw_circle(c, s * 0.24, _with_alpha(Color(1.0, 0.98, 0.72, 0.96), 1.0))

## Darkness: crescent moon — polygon approximation of outer minus inner arc.
func _draw_darkness(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.82 + 2.0, _outline_color())
	draw_circle(c, s * 0.82, _with_alpha(Color(0.62, 0.18, 0.95, 0.96), 1.0))
	draw_circle(c + Vector2(s * 0.34, -s * 0.04), s * 0.70, Color(0.035, 0.045, 0.085, 0.96 * icon_alpha))
	draw_circle(c + Vector2(-s * 0.28, -s * 0.26), s * 0.09, _with_alpha(Color(0.86, 0.70, 1.0, 0.78), 1.0))

## Interest bonus: small coin/currency diamond symbol.
func _draw_interest(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2( 0.0, -s * 0.95),
		c + Vector2( s * 0.72,  0.0),
		c + Vector2( 0.0,  s * 0.95),
		c + Vector2(-s * 0.72,  0.0),
	])
	_draw_poly_symbol(pts, Color(0.74, 0.56, 1.0, 0.94), 1.4)
	draw_arc(c, s * 0.35, 0.0, TAU, 18, _with_alpha(Color(1.0, 0.92, 1.0, 0.78), 1.0), 1.6, true)
	draw_line(c + Vector2(-s * 0.22, 0.0), c + Vector2(s * 0.22, 0.0), _with_alpha(Color(1.0, 0.92, 1.0, 0.72), 1.0), 1.2, true)

## Fallback: shows first ASCII letter of the element name in a circle.
## Never shows a raw number even if element_id is unknown.
func _draw_fallback(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.82 + 1.5, _outline_color())
	draw_circle(c, s * 0.82, _with_alpha(Color(0.35, 0.40, 0.50, 0.72), 1.0))
	var code := get_short_code(element_id)
	# Only draw text if it's safe ASCII (not a bare number)
	if code.is_valid_identifier() or code == "?" or code == "$":
		draw_string(
			ThemeDB.fallback_font,
			c - Vector2(s * 0.25, -s * 0.30),
			code,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			int(s * 1.1),
			_with_alpha(Color(1.0, 1.0, 1.0, 0.92), 1.0)
		)
