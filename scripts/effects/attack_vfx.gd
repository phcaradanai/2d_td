## attack_vfx.gd — Lightweight directional tower attack VFX node.
## Created by TowerAttackVFX.spawn_attack_vfx(); always self-frees when done.
##
## All draw functions draw in LOCAL space.  The node's global_rotation is
## set to (target – origin).angle(), so +X in local space always points
## toward the target.  lend = Vector2(distance, 0) is the local-space target.
class_name AttackVFX
extends Node2D

## Maximum simultaneously active attack-VFX nodes.
## Beyond this budget, new spawns are skipped (visuals only — gameplay is unaffected).
const MAX_ACTIVE: int = 60
## Shared counter across all AttackVFX instances.  Incremented in _ready(),
## decremented just before queue_free() so the budget is always accurate.
static var _active_count: int = 0

var vfx_type:  String = "rapid_tracer"
var color:     Color  = Color.WHITE
var distance:  float  = 100.0
var elapsed:   float  = 0.0
var duration:  float  = 0.12

func _ready() -> void:
	AttackVFX._active_count += 1

func setup(p_type: String, p_origin: Vector2, p_target: Vector2,
		   p_color: Color, p_duration: float = 0.0) -> void:
	vfx_type = p_type
	color    = p_color
	global_position = p_origin

	var diff: Vector2 = p_target - p_origin
	distance = diff.length()
	if distance > 0.5:
		global_rotation = diff.angle()

	duration = p_duration if p_duration > 0.0 else _default_dur(p_type)
	queue_redraw()

static func _default_dur(t: String) -> float:
	match t:
		"flame_cone", "steam_burst":                   return 0.22
		"electric_arc", "chain_lightning":             return 0.15
		"magic_enchant", "void_rift":                  return 0.26
		"nature_vine", "poison_spray",\
		"acid_splash",  "shadow_lash":                 return 0.18
		"water_jet":                                   return 0.16
		_:                                             return 0.12

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		AttackVFX._active_count -= 1
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t   := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var a   := 1.0 - t
	var lend := Vector2(distance, 0.0)

	match vfx_type:
		"rapid_tracer":     _draw_rapid_tracer(t, a, lend)
		"cannon_blast":     _draw_cannon_blast(t, a)
		"precision_beam":   _draw_precision_beam(t, a, lend)
		"flame_cone":       _draw_flame_cone(t, a, lend)
		"electric_arc":     _draw_electric_arc( a, lend, false)
		"chain_lightning":  _draw_electric_arc( a, lend, true)
		"magic_enchant":    _draw_magic_enchant(t, a, lend)
		"water_jet":        _draw_water_jet(t, a, lend)
		"frost_beam":       _draw_frost_beam(t, a, lend)
		"poison_spray":     _draw_poison_spray(t, a, lend)
		"spore_puff":       _draw_spore_puff(t, a, lend)
		"void_rift":        _draw_void_rift(t, a, lend)
		"earth_impact":     _draw_earth_impact(t, a)
		"steam_burst":      _draw_steam_burst(t, a, lend)
		"light_pulse":      _draw_light_pulse(t, a, lend)
		"nature_vine":      _draw_nature_vine(t, a, lend)
		"acid_splash":      _draw_acid_splash(t, a, lend)
		"shadow_lash":      _draw_shadow_lash(t, a, lend)
		"trickery_shimmer": _draw_trickery_shimmer(t, a, lend)
		_:                  _draw_rapid_tracer(t, a, lend)

## Color helper — applies alpha to tower element color.
func _c(a: float) -> Color:
	return Color(color.r, color.g, color.b, a)

## Jagged points for lightning-style arcs (deterministic per elapsed tick).
func _jag_pts(lend: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var tick := int(elapsed * 28.0)
	for i in range(1, n):
		var f    := float(i) / n
		var base := lend * f
		var h    := int(tick * 1009 + i * 97) % 21 - 10
		pts.append(base + Vector2(0.0, float(h) * (lend.length() * 0.055)))
	pts.append(lend)
	return pts

# ── Draw implementations ──────────────────────────────────────────────────────

func _draw_rapid_tracer(t: float, a: float, lend: Vector2) -> void:
	# Tracer bolt: short bright line from muzzle + muzzle flash dot.
	var reach := lend * minf(t * 4.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.3), 3.5, true)
	draw_line(Vector2.ZERO, reach, _c(a * 0.8), 1.2, true)
	draw_circle(Vector2.ZERO, 3.5 * (1.0 - t), _c(a))
	draw_circle(Vector2.ZERO, 1.8 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.75))

func _draw_cannon_blast(t: float, a: float) -> void:
	# Expanding disk + forward-concentrated rays.
	var r := 7.0 + t * 16.0
	draw_circle(Vector2.ZERO, r, _c(a * 0.25))
	draw_arc(Vector2.ZERO, r, -0.65, 0.65, 12, _c(a * 0.75), 2.5, true)
	for i in range(5):
		var spread := -0.4 + float(i) * 0.2
		var rlen   := (18.0 + float(i % 2) * 8.0) * (1.0 - t * 0.45)
		draw_line(Vector2.ZERO,
			Vector2(cos(spread) * rlen, sin(spread) * rlen),
			_c(a * (0.9 - float(i) * 0.1)), 2.2 - float(i % 2) * 0.5, true)
	draw_circle(Vector2.ZERO, 4.5 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.65))

func _draw_precision_beam(t: float, a: float, lend: Vector2) -> void:
	# Sniper tracer: narrow beam reaching target, glow under.
	var reach := lend * clampf(t * 5.0, 0.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.22), 4.5, true)
	draw_line(Vector2.ZERO, reach, _c(a * 0.85), 1.0, true)
	draw_circle(Vector2.ZERO, 3.0 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.9))

func _draw_flame_cone(t: float, a: float, lend: Vector2) -> void:
	# Layered fire cone from muzzle toward target.
	var cl := lend.x * 0.46 * (1.0 - t * 0.28)
	# Three cone layers (outer → inner, darker → brighter)
	for layer in range(3):
		var w  := (12.0 - float(layer) * 3.5) * (1.0 - t * 0.35)
		var ll := cl * (1.0 - float(layer) * 0.08)
		var pts := PackedVector2Array([
			Vector2.ZERO,
			Vector2(ll * 0.5, -w),
			Vector2(ll, 0.0),
			Vector2(ll * 0.5, w)
		])
		draw_colored_polygon(pts, _c(a * (0.7 - float(layer) * 0.14)))
	# Inner hot core
	var ipts := PackedVector2Array([
		Vector2.ZERO,
		Vector2(cl * 0.38, -4.0 * (1.0 - t)),
		Vector2(cl * 0.72, 0.0),
		Vector2(cl * 0.38,  4.0 * (1.0 - t))
	])
	draw_colored_polygon(ipts, Color(1.0, 0.96, 0.55, a * 0.78))
	# Ember sparks (4 fixed offsets — no randf to stay deterministic/cheap)
	for i in range(4):
		var ef  := 0.18 + float(i) * 0.2
		var ey  := (float(i % 2) * 2.0 - 1.0) * 3.5
		draw_circle(Vector2(cl * ef, ey), 2.2 * (1.0 - t), Color(1.0, 0.62, 0.1, a * 0.65))

func _draw_electric_arc(a: float, lend: Vector2, heavy: bool) -> void:
	# Jagged lightning from muzzle to target, flickers via deterministic tick hash.
	var n_pts := clampi(int(distance / 22.0) + 2, 3, 8)
	var pts   := _jag_pts(lend, n_pts)
	if pts.size() < 2:
		return
	var gw := 7.5 if heavy else 5.0
	var cw := 2.5 if heavy else 1.8
	draw_polyline(pts, _c(a * 0.28), gw, true)
	draw_polyline(pts, _c(a * 0.92), cw, true)
	draw_circle(Vector2.ZERO, 3.5 * a, Color(1.0, 1.0, 1.0, a * 0.75))
	draw_circle(lend, 3.0 * a, _c(a * 0.7))

func _draw_magic_enchant(t: float, a: float, lend: Vector2) -> void:
	# Expanding rune ring at origin + thin beam + small glyph circle at target.
	var rr := 5.5 + t * 20.0
	draw_circle(Vector2.ZERO, rr, _c(a * 0.18))
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 24, _c(a * 0.5), 1.5, true)
	# Six rotating glyph nodes
	for i in range(6):
		var ang := i * TAU / 6.0 + t * 3.2
		var p   := Vector2(cos(ang), sin(ang)) * rr
		draw_circle(p, 1.8, _c(a * 0.85))
	# Tether beam
	draw_line(Vector2.ZERO, lend, _c(a * 0.38), 2.2, true)
	draw_line(Vector2.ZERO, lend, _c(a * 0.65), 0.9, true)
	# Impact rune
	draw_arc(lend, 6.0 * (1.0 - t * 0.55), 0.0, TAU, 12, _c(a * 0.7), 1.5, true)
	draw_circle(lend, 2.0 * (1.0 - t), _c(a * 0.85))

func _draw_water_jet(t: float, a: float, lend: Vector2) -> void:
	# Three wavy parallel streams + droplets.
	for lane in range(3):
		var oy  := (float(lane) - 1.0) * 4.0
		var pts := PackedVector2Array()
		var seg := clampi(int(lend.length() / 16.0) + 2, 3, 7)
		for i in range(seg + 1):
			var f    := float(i) / seg
			var wave := sin(f * TAU * 1.5 + t * 8.0 + float(lane) * 1.1) * 2.8
			pts.append(Vector2(lend.x * f, oy + wave))
		if pts.size() >= 2:
			draw_polyline(pts, _c(a * (0.65 - float(lane) * 0.14)), 2.8 - float(lane) * 0.7, true)
	for i in range(4):
		var f  := float(i) / 4.0
		var dy := (float(i % 2) * 2.0 - 1.0) * 4.5
		draw_circle(Vector2(lend.x * f, dy), 2.2 * (1.0 - t * 0.4), _c(a * 0.75))

func _draw_frost_beam(t: float, a: float, lend: Vector2) -> void:
	# Wide icy beam with crystal edge segments.
	draw_line(Vector2.ZERO, lend, _c(a * 0.22), 8.0, true)
	draw_line(Vector2.ZERO, lend, _c(a * 0.68), 2.5, true)
	draw_line(Vector2.ZERO, lend, Color(1.0, 1.0, 1.0, a * 0.4), 1.0, true)
	# Crystal perpendicular ticks
	for i in range(4):
		var f  := float(i + 1) / 5.0
		var bx := lend.x * f
		var h  := 4.5 * (1.0 - t)
		draw_line(Vector2(bx, -h), Vector2(bx, h), _c(a * 0.55), 1.2)

func _draw_poison_spray(t: float, a: float, lend: Vector2) -> void:
	# Fan of 5 streaks toward target + endpoint blobs.
	for i in range(5):
		var spread := -0.38 + float(i) * 0.19
		var rf     := (0.62 + float(i % 2) * 0.28) * (1.0 - t * 0.18)
		var ep     := Vector2(lend.x * rf, lend.x * rf * tan(spread))
		draw_line(Vector2.ZERO, ep, _c(a * (0.75 - float(i) * 0.05)), 1.6, true)
		draw_circle(ep, 2.8 * (1.0 - t), _c(a * 0.8))

func _draw_spore_puff(t: float, a: float, lend: Vector2) -> void:
	# Four small expanding circles fanning forward.
	for i in range(4):
		var f   := float(i) / 4.0
		var off := Vector2(lend.x * (0.08 + f * 0.58), (float(i % 2) * 2.0 - 1.0) * 5.5)
		var r   := (3.0 + float(i) * 2.2) * (0.45 + t * 0.55)
		draw_circle(off, r, _c(a * (0.38 - float(i) * 0.05)))
		draw_arc(off, r, 0.0, TAU, 8, _c(a * 0.55), 1.0, true)

func _draw_void_rift(t: float, a: float, lend: Vector2) -> void:
	# Pulsing ring at origin + inward tendrils + dark beam to target.
	var rr := 4.0 + t * 13.0
	draw_circle(Vector2.ZERO, rr, _c(a * 0.22))
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 20, _c(a * 0.68), 2.0, true)
	for i in range(6):
		var ang   := i * TAU / 6.0 + t * 2.2
		var outer := Vector2(cos(ang), sin(ang)) * (rr + 5.0)
		var inner := Vector2(cos(ang), sin(ang)) * rr
		draw_line(outer, inner, _c(a * 0.55), 1.0)
	draw_line(Vector2.ZERO, lend * 0.55, _c(a * 0.48), 2.2, true)
	draw_circle(lend * 0.55, 3.5 * (1.0 - t), _c(a * 0.65))

func _draw_earth_impact(t: float, a: float) -> void:
	# Fan of stone shards + gravel core.
	for i in range(6):
		var spread := -0.55 + float(i) * 0.22
		var sl     := (13.0 + float(i % 3) * 6.0) * (1.0 - t * 0.3)
		var w      := 3.0 - float(i % 3) * 0.6
		draw_line(Vector2.ZERO,
			Vector2(cos(spread) * sl, sin(spread) * sl), _c(a * 0.82), w, true)
	draw_circle(Vector2.ZERO, 6.0 * (1.0 - t * 0.75), _c(a * 0.88))
	draw_circle(Vector2.ZERO, 3.2 * (1.0 - t * 0.75), Color(1.0, 0.85, 0.62, a * 0.65))

func _draw_steam_burst(t: float, a: float, lend: Vector2) -> void:
	# Three expanding puff discs directed forward.
	for i in range(3):
		var f := float(i) / 3.0
		var c := Vector2(lend.x * (0.18 + f * 0.3), 0.0)
		var r := (5.5 + float(i) * 4.5) * (0.28 + t * 0.72)
		draw_circle(c, r, Color(color.r, color.g, color.b, a * (0.28 - float(i) * 0.06)))
		draw_arc(c, r, 0.0, TAU, 12, _c(a * (0.55 - float(i) * 0.12)), 1.5, true)

func _draw_light_pulse(t: float, a: float, lend: Vector2) -> void:
	# 4-point star at muzzle + radiant beam toward target.
	var sr := 11.0 * (1.0 - t)
	for i in range(4):
		var ang := i * PI * 0.5
		draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * sr, _c(a * 0.72), 1.5, true)
	draw_circle(Vector2.ZERO, 4.5 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.88))
	draw_circle(Vector2.ZERO, 2.2 * (1.0 - t), _c(a))
	draw_line(Vector2.ZERO, lend, _c(a * 0.32), 3.2, true)
	draw_line(Vector2.ZERO, lend, Color(1.0, 1.0, 1.0, a * 0.38), 1.0, true)

func _draw_nature_vine(t: float, a: float, lend: Vector2) -> void:
	# Wavy organic vine tendril toward target.
	var n_seg := clampi(int(lend.length() / 18.0) + 2, 3, 7)
	var pts   := PackedVector2Array()
	for i in range(n_seg + 1):
		var f    := float(i) / n_seg
		var wave := sin(f * TAU * 1.3 + t * 4.5) * 5.5
		pts.append(Vector2(lend.x * f, wave))
	if pts.size() >= 2:
		draw_polyline(pts, _c(a * 0.32), 3.8, true)
		draw_polyline(pts, _c(a * 0.72), 1.6, true)
	for i in range(3):
		var f  := 0.22 + float(i) * 0.26
		var lp := Vector2(lend.x * f, 0.0)
		draw_circle(lp, 2.8 * (1.0 - t * 0.45), _c(a * 0.65))

func _draw_acid_splash(t: float, a: float, lend: Vector2) -> void:
	# Forward spray with drip circles + origin sizzle ring.
	for i in range(5):
		var spread := -0.42 + float(i) * 0.21
		var dl     := (lend.length() * 0.5 + float(i % 2) * 18.0) * (1.0 - t * 0.28)
		var ep     := Vector2(cos(spread) * dl, sin(spread) * dl)
		draw_line(Vector2.ZERO, ep, _c(a * 0.58), 2.0, true)
		draw_circle(ep, 2.8 * (1.0 - t), _c(a * 0.82))
	draw_arc(Vector2.ZERO, 4.0 + t * 7.0, 0.0, TAU, 12, _c(a * 0.48), 1.5, true)

func _draw_shadow_lash(t: float, a: float, lend: Vector2) -> void:
	# Two dark arcing whip lines toward target.
	for lane in range(2):
		var pts := PackedVector2Array()
		var oy  := (float(lane) * 2.0 - 1.0) * 3.2
		var ns  := 5
		for i in range(ns):
			var f     := float(i) / (ns - 1)
			var arc_y := sin(f * PI) * (9.0 + float(lane) * 4.0) * (1.0 - t * 0.45)
			pts.append(Vector2(lend.x * f, oy + arc_y * (float(lane) * 2.0 - 1.0)))
		if pts.size() >= 2:
			draw_polyline(pts, _c(a * (0.78 - float(lane) * 0.18)),
				2.5 - float(lane) * 0.5, true)

func _draw_trickery_shimmer(t: float, a: float, lend: Vector2) -> void:
	# Dual-color sparkle trail (gold primary + purple accent).
	var ac := Color(0.55, 0.12, 0.85, a * 0.72)
	for i in range(6):
		var f  := float(i) / 6.0
		var sp := Vector2(lend.x * f, (float(i % 2) * 2.0 - 1.0) * 7.0 * (1.0 - f))
		draw_circle(sp, 2.8 * (1.0 - t * 0.65), ac if i % 2 == 0 else _c(a * 0.82))
	draw_line(Vector2.ZERO, lend * 0.75, _c(a * 0.28), 1.5, true)
