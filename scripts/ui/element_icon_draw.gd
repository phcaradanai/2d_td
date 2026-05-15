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
		element_id = v
		queue_redraw()

## Scale factor 0.0–1.0 applied to icon brightness (used for locked/maxed states).
@export var icon_alpha: float = 1.0 :
	set(v):
		icon_alpha = clampf(v, 0.0, 1.0)
		queue_redraw()

# ── Static helpers ──────────────────────────────────────────────────────────

static func get_color(eid: String) -> Color:
	match _normalize(eid):
		"light":     return Color(1.0, 0.88, 0.10)
		"darkness":  return Color(0.55, 0.12, 0.85)
		"water":     return Color(0.15, 0.55, 1.0)
		"fire":      return Color(1.0, 0.18, 0.08)
		"nature":    return Color(0.10, 0.78, 0.25)
		"earth":     return Color(0.68, 0.42, 0.16)
		"__interest__": return Color(0.68, 0.50, 1.0)
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
	match eid:
		"0": return "light"
		"1": return "darkness"
		"2": return "water"
		"3": return "fire"
		"4": return "nature"
		"5": return "earth"
		_:   return eid.to_lower()

# ── Rendering ───────────────────────────────────────────────────────────────

func _draw() -> void:
	var sz  := get_size()
	var c   := sz / 2.0
	var s   : float = min(sz.x, sz.y) * 0.40
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

## Fire: two-layer upward flame shape (orange outer, yellow inner).
func _draw_fire(c: Vector2, s: float) -> void:
	var a := icon_alpha
	# Outer flame — orange
	var outer := PackedVector2Array([
		c + Vector2( 0.00, -s * 1.00),
		c + Vector2( s * 0.52, -s * 0.12),
		c + Vector2( s * 0.74,  s * 0.58),
		c + Vector2( 0.00,  s * 0.74),
		c + Vector2(-s * 0.74,  s * 0.58),
		c + Vector2(-s * 0.52, -s * 0.12),
	])
	draw_colored_polygon(outer, Color(1.0, 0.30, 0.04, 0.92 * a))
	# Inner flame — yellow
	var inner := PackedVector2Array([
		c + Vector2( 0.00, -s * 0.58),
		c + Vector2( s * 0.30,  s * 0.10),
		c + Vector2( s * 0.38,  s * 0.52),
		c + Vector2( 0.00,  s * 0.44),
		c + Vector2(-s * 0.38,  s * 0.52),
		c + Vector2(-s * 0.30,  s * 0.10),
	])
	draw_colored_polygon(inner, Color(1.0, 0.76, 0.06, 0.95 * a))

## Water: teardrop — tapered top point, circular lower body.
func _draw_water(c: Vector2, s: float) -> void:
	var a := icon_alpha
	var pts := PackedVector2Array()
	# Build teardrop as a polygon: bottom arc + converging sides to top point.
	var segs := 14
	for i in range(segs + 1):
		# Bottom half arc: from left to right through the bottom
		var ang := PI + float(i) / float(segs) * PI
		pts.append(c + Vector2(cos(ang) * s * 0.70, sin(ang) * s * 0.70 + s * 0.20))
	# Right side taper up to tip
	pts.append(c + Vector2(s * 0.18, -s * 0.22))
	pts.append(c + Vector2(0.00, -s * 0.95)) # tip
	pts.append(c + Vector2(-s * 0.18, -s * 0.22))
	draw_colored_polygon(pts, Color(0.15, 0.62, 1.0, 0.93 * a))
	# Highlight glint (top-left)
	draw_circle(c + Vector2(-s * 0.22, s * 0.05), s * 0.16, Color(0.72, 0.94, 1.0, 0.50 * a))

## Nature: simple leaf — elongated lozenge rotated 45°, with a center vein.
func _draw_nature(c: Vector2, s: float) -> void:
	var a := icon_alpha
	var pts := PackedVector2Array()
	# Leaf polygon (12 points, ellipse rotated ~45°)
	for i in range(12):
		var ang := float(i) / 12.0 * TAU
		var px := cos(ang) * s * 0.46
		var py := sin(ang) * s * 0.92
		pts.append(c + Vector2(px, py).rotated(-PI * 0.22))
	draw_colored_polygon(pts, Color(0.10, 0.78, 0.25, 0.92 * a))
	# Center vein
	var tip_a := Vector2(0.0, -s * 0.92).rotated(-PI * 0.22)
	var tip_b := Vector2(0.0,  s * 0.92).rotated(-PI * 0.22)
	draw_line(c + tip_a, c + tip_b, Color(0.04, 0.44, 0.12, 0.65 * a), 1.2)

## Earth: flat gem/hexagon — upper narrow + lower wide facets.
func _draw_earth(c: Vector2, s: float) -> void:
	var a := icon_alpha
	# Outer hex/gem shape (6 points, slightly squashed)
	var outer := PackedVector2Array()
	for i in range(6):
		var ang := float(i) / 6.0 * TAU - PI / 2.0
		outer.append(c + Vector2(cos(ang) * s * 0.88, sin(ang) * s * 0.82))
	draw_colored_polygon(outer, Color(0.68, 0.42, 0.16, 0.92 * a))
	# Inner facet highlight (top two-thirds)
	var inner := PackedVector2Array([
		c + Vector2( 0.00, -s * 0.62),
		c + Vector2( s * 0.46, -s * 0.20),
		c + Vector2( s * 0.46,  s * 0.26),
		c + Vector2( 0.00,  s * 0.18),
		c + Vector2(-s * 0.46,  s * 0.26),
		c + Vector2(-s * 0.46, -s * 0.20),
	])
	draw_colored_polygon(inner, Color(0.88, 0.60, 0.28, 0.72 * a))

## Light: 4-pointed star with a bright center core.
func _draw_light(c: Vector2, s: float) -> void:
	var a := icon_alpha
	# 4-pointed star (8 vertices: 4 outer tips + 4 inner)
	var pts := PackedVector2Array()
	for i in range(8):
		var ang := float(i) / 8.0 * TAU - PI / 4.0
		var r := s * 0.92 if i % 2 == 0 else s * 0.30
		pts.append(c + Vector2.RIGHT.rotated(ang) * r)
	draw_colored_polygon(pts, Color(1.0, 0.88, 0.10, 0.93 * a))
	# Bright center disc
	draw_circle(c, s * 0.22, Color(1.0, 0.97, 0.72, 0.95 * a))

## Darkness: crescent moon — polygon approximation of outer minus inner arc.
func _draw_darkness(c: Vector2, s: float) -> void:
	var a := icon_alpha
	var pts := PackedVector2Array()
	# Outer arc (full outer edge of crescent, counter-clockwise ~270°)
	var outer_segs := 18
	var arc_start := PI * 0.62
	var arc_span  := TAU * 0.76
	for i in range(outer_segs + 1):
		var ang := arc_start + float(i) / float(outer_segs) * arc_span
		pts.append(c + Vector2.RIGHT.rotated(ang) * s * 0.92)
	# Inner arc (inner concave edge, traced backwards, offset to the right)
	var offset := Vector2(s * 0.34, 0.0)
	for i in range(outer_segs + 1):
		var ang := arc_start + arc_span - float(i) / float(outer_segs) * arc_span
		pts.append(c + offset + Vector2.RIGHT.rotated(ang) * s * 0.66)
	draw_colored_polygon(pts, Color(0.55, 0.12, 0.85, 0.95 * a))

## Interest bonus: small coin/currency diamond symbol.
func _draw_interest(c: Vector2, s: float) -> void:
	var a := icon_alpha
	var pts := PackedVector2Array([
		c + Vector2( 0.0, -s * 0.95),
		c + Vector2( s * 0.72,  0.0),
		c + Vector2( 0.0,  s * 0.95),
		c + Vector2(-s * 0.72,  0.0),
	])
	draw_colored_polygon(pts, Color(0.68, 0.50, 1.0, 0.88 * a))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.85, 0.70, 1.0, 0.80 * a), 1.2)
	draw_circle(c, s * 0.22, Color(1.0, 0.92, 1.0, 0.80 * a))

## Fallback: shows first ASCII letter of the element name in a circle.
## Never shows a raw number even if element_id is unknown.
func _draw_fallback(c: Vector2, s: float) -> void:
	var a := icon_alpha
	draw_circle(c, s * 0.8, Color(0.35, 0.40, 0.50, 0.55 * a))
	var code := get_short_code(element_id)
	# Only draw text if it's safe ASCII (not a bare number)
	if code.is_valid_identifier() or code == "?":
		draw_string(
			ThemeDB.fallback_font,
			c - Vector2(s * 0.22, -s * 0.30),
			code,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			int(s * 1.1),
			Color(1.0, 1.0, 1.0, 0.90 * a)
		)
