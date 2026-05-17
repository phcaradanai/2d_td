## CreepStatusVFX
## Lightweight status indicator layer attached to each creep.
## Reads existing enemy status state — zero new gameplay logic.
## All visuals are pure _draw() primitives: no particles, no spawned timers.
## One Node2D per creep, one _draw() call per frame when active.

extends Node2D
class_name CreepStatusVFX

# ── Layout constants ──────────────────────────────────────────────────────────
const ICON_R    := 5.5    # icon glyph half-size
const ICON_GAP  := 13.0   # horizontal spacing between icons
const ICON_Y    := -26.0  # vertical offset above enemy center
const RING_R    := 14.0   # body-ring radius

# ── Status colors — alpha ≤ 0.75 so creep body stays readable ────────────────
const C_SLOW   := Color(0.50, 0.95, 1.00, 0.75)   # cyan-white  — slow / freeze
const C_ROOT   := Color(0.15, 0.90, 0.45, 0.75)   # teal-green  — root / snare
const C_BURN   := Color(1.00, 0.32, 0.05, 0.75)   # orange-red  — fire DoT
const C_POISON := Color(0.52, 0.12, 0.88, 0.75)   # purple      — nature/dark DoT
const C_VULN   := Color(0.80, 0.08, 0.88, 0.75)   # magenta     — vulnerability

var owner_enemy: Node = null
var _t: float = 0.0          # animation clock (advances with delta)
## Visibility is re-evaluated every VISIBILITY_CHECK_INTERVAL seconds.
## The animation clock (_t) still advances every frame for smooth glyphs.
## Immediate re-evaluation is triggered by enemy_modifier_changed signal.
const VISIBILITY_CHECK_INTERVAL := 0.15
var _visibility_timer: float = 0.0

# ── Setup / teardown ─────────────────────────────────────────────────────────

func setup(enemy: Node) -> void:
	owner_enemy = enemy
	z_index = 15
	add_to_group("status_vfx")
	# Immediate redraw when a modifier changes (slow, root, vuln, armor).
	if enemy.has_signal("enemy_modifier_changed"):
		if not enemy.enemy_modifier_changed.is_connected(_on_modifier_changed):
			enemy.enemy_modifier_changed.connect(_on_modifier_changed)

func _on_modifier_changed(_en: Node, _key: String, _val: Variant) -> void:
	# Force an immediate visibility re-check and redraw when a status changes.
	_visibility_timer = 0.0
	visible = _has_any_active()
	queue_redraw()

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		queue_free()
		return
	_t += delta * TAU   # one full cycle per second; scales correctly at x2/x3
	# Re-check visibility at throttled interval — not every frame — to avoid
	# ~5 property reads × 30+ creeps × 60 fps = 9000+ reads/sec.
	# Immediate re-check is triggered by _on_modifier_changed on signal.
	_visibility_timer -= delta
	if _visibility_timer <= 0.0:
		_visibility_timer = VISIBILITY_CHECK_INTERVAL
		visible = _has_any_active()
	if visible:
		queue_redraw()   # smooth icon animation while active

# ── State helpers ─────────────────────────────────────────────────────────────

func _has_any_active() -> bool:
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		return false
	if float(owner_enemy.get("slow_remaining")) > 0.0:          return true
	if float(owner_enemy.get("root_remaining")) > 0.0:           return true
	if float(owner_enemy.get("vulnerability_remaining")) > 0.0:  return true
	if float(owner_enemy.get("armor_reduction_remaining")) > 0.0: return true
	var dots = owner_enemy.get("active_dot_effects")
	return (dots is Array) and not dots.is_empty()

func _read_state() -> Dictionary:
	var s := {
		"slow": false, "root": false,
		"burn": false, "poison": false, "vuln": false,
	}
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		return s
	s["slow"]  = float(owner_enemy.get("slow_remaining")) > 0.0
	s["root"]  = float(owner_enemy.get("root_remaining")) > 0.0
	s["vuln"]  = float(owner_enemy.get("vulnerability_remaining")) > 0.0 \
		or float(owner_enemy.get("armor_reduction_remaining")) > 0.0
	var dots = owner_enemy.get("active_dot_effects")
	if dots is Array:
		for d in dots:
			if not d is Dictionary: continue
			match str(d.get("attack_type", "dot")).to_lower():
				"fire":             s["burn"]   = true
				"nature", "dark":   s["poison"] = true
				_:                  s["poison"] = true
	return s

# ── Main draw ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		return
	var st := _read_state()

	_draw_body_ring(st)
	_draw_icons(st)

# ── Body ring (colored arc around enemy silhouette) ───────────────────────────

func _draw_body_ring(st: Dictionary) -> void:
	var r := RING_R
	# Root: solid teal ring
	if st["root"]:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32,
				Color(C_ROOT.r, C_ROOT.g, C_ROOT.b, 0.38), 2.2, true)
	# Slow: dashed rotating frost segments
	elif st["slow"]:
		for i in 6:
			var a0 := float(i) * TAU / 6.0 + _t * 0.06
			draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 12.5, 7,
					Color(C_SLOW.r, C_SLOW.g, C_SLOW.b, 0.32), 1.8, true)
	# Burn: pulsing orange ring
	if st["burn"]:
		var p := 0.22 + 0.10 * sin(_t * 0.38)
		draw_arc(Vector2.ZERO, r + 2.5, 0.0, TAU, 28,
				Color(C_BURN.r, C_BURN.g, C_BURN.b, p), 1.8, true)
	# Poison: subtle purple ring
	if st["poison"]:
		draw_arc(Vector2.ZERO, r + 1.5, 0.0, TAU, 24,
				Color(C_POISON.r, C_POISON.g, C_POISON.b, 0.22), 1.4, true)
	# Vulnerability: 4 arc segments
	if st["vuln"]:
		for i in 4:
			var a := float(i) * TAU / 4.0 + PI / 8.0 + _t * 0.04
			draw_arc(Vector2.ZERO, r + 3.8, a, a + TAU / 5.2, 9,
					Color(C_VULN.r, C_VULN.g, C_VULN.b, 0.28), 1.4, true)

# ── Icon row ──────────────────────────────────────────────────────────────────

func _draw_icons(st: Dictionary) -> void:
	# Priority: root > slow > burn > poison > vuln  (max 3 shown)
	var order: Array[String] = ["root", "slow", "burn", "poison", "vuln"]
	var visible_icons: Array[String] = []
	for key in order:
		if st.get(key, false) and visible_icons.size() < 3:
			visible_icons.append(key)

	var n := visible_icons.size()
	if n == 0:
		return

	var x0 := -(n - 1) * ICON_GAP * 0.5
	for i in n:
		var pos := Vector2(x0 + float(i) * ICON_GAP, ICON_Y)
		var col := _col(visible_icons[i])
		# Soft glow backing
		draw_circle(pos, ICON_R + 3.5, Color(col.r, col.g, col.b, 0.10))
		# Icon glyph
		match visible_icons[i]:
			"root":   _glyph_lock(pos, C_ROOT)
			"slow":   _glyph_snowflake(pos, C_SLOW)
			"burn":   _glyph_flame(pos, C_BURN)
			"poison": _glyph_skull(pos, C_POISON)
			"vuln":   _glyph_broken_shield(pos, C_VULN)

func _col(key: String) -> Color:
	match key:
		"root":   return C_ROOT
		"slow":   return C_SLOW
		"burn":   return C_BURN
		"poison": return C_POISON
		"vuln":   return C_VULN
	return Color.WHITE

# ── Icon glyphs (pure draw calls) ────────────────────────────────────────────

func _glyph_snowflake(c: Vector2, col: Color) -> void:
	var s := ICON_R
	# 6-arm snowflake, slowly rotating
	for i in 6:
		var a := float(i) * TAU / 6.0 + _t * 0.06
		var tip := c + Vector2.RIGHT.rotated(a) * s
		draw_line(c, tip, col, 1.5, true)
		# Crossbar on each arm
		var mid := c + Vector2.RIGHT.rotated(a) * (s * 0.55)
		var perp := Vector2.RIGHT.rotated(a + PI * 0.5) * (s * 0.32)
		draw_line(mid - perp, mid + perp, col, 1.2, true)
	draw_circle(c, 1.6, col)

func _glyph_lock(c: Vector2, col: Color) -> void:
	var s := ICON_R * 0.88
	# Padlock body
	draw_rect(Rect2(c.x - s * 0.78, c.y - s * 0.18, s * 1.56, s * 1.05),
			Color(col.r, col.g, col.b, 0.45))
	draw_rect(Rect2(c.x - s * 0.78, c.y - s * 0.18, s * 1.56, s * 1.05),
			col, false, 1.4)
	# Shackle arc above body
	draw_arc(c + Vector2(0.0, -s * 0.22), s * 0.62, PI, 0.0, 10, col, 2.0, true)
	# Keyhole centre dot
	draw_circle(c + Vector2(0.0, s * 0.25), 1.4, Color(0.0, 0.0, 0.0, 0.55))

func _glyph_flame(c: Vector2, col: Color) -> void:
	var s := ICON_R
	var fl := sin(_t * 0.60) * 1.1   # flicker
	var outer := PackedVector2Array([
		c + Vector2(0.0,    -s * 1.15 - fl),
		c + Vector2(s * 0.72, -s * 0.15 + fl * 0.3),
		c + Vector2(s * 0.50,  s * 0.68),
		c + Vector2(-s * 0.50, s * 0.68),
		c + Vector2(-s * 0.72, -s * 0.15 + fl * 0.3),
	])
	draw_colored_polygon(outer, Color(col.r, col.g, col.b, 0.60))
	# Inner hot-spot
	var inner := PackedVector2Array([
		c + Vector2(0.0,     -s * 0.42 - fl * 0.5),
		c + Vector2(s * 0.38,  s * 0.32),
		c + Vector2(-s * 0.38, s * 0.32),
	])
	draw_colored_polygon(inner, Color(1.0, 0.92, 0.35, 0.60))

func _glyph_skull(c: Vector2, col: Color) -> void:
	var s := ICON_R
	# Skull dome
	draw_circle(c, s, Color(col.r, col.g, col.b, 0.52))
	draw_circle(c, s, col, false, 1.2)
	# Eye sockets
	draw_circle(c + Vector2(-s * 0.36, -s * 0.10), s * 0.25, Color(0.0, 0.0, 0.0, 0.70))
	draw_circle(c + Vector2( s * 0.36, -s * 0.10), s * 0.25, Color(0.0, 0.0, 0.0, 0.70))
	# Teeth (3 small rectangles)
	for i in 3:
		var tx := c.x - s * 0.52 + float(i) * s * 0.52
		draw_rect(Rect2(tx, c.y + s * 0.34, s * 0.34, s * 0.40),
				Color(0.0, 0.0, 0.0, 0.60))

func _glyph_broken_shield(c: Vector2, col: Color) -> void:
	var s := ICON_R
	var pts := PackedVector2Array([
		c + Vector2(0.0,   -s),
		c + Vector2(s,     -s * 0.30),
		c + Vector2(s,      s * 0.30),
		c + Vector2(0.0,    s),
		c + Vector2(-s,     s * 0.30),
		c + Vector2(-s,    -s * 0.30),
	])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.14))
	draw_polyline(pts + PackedVector2Array([pts[0]]), col, 1.4, true)
	# Diagonal crack
	draw_line(c + Vector2(-s * 0.15, -s * 0.65),
			  c + Vector2( s * 0.38,  s * 0.60),
			  Color(1.0, 1.0, 1.0, 0.50), 1.4, true)
