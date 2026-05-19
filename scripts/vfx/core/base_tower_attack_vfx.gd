## BaseTowerAttackVFX — base class for all per-tower attack VFX nodes.
## Subclasses override configure() to set lifetime/palette and _draw_vfx() to draw.
## All drawing is in LOCAL space: +X points toward the target.
## lend = Vector2(distance, 0) is the local-space endpoint.
class_name BaseTowerAttackVFX
extends Node2D

static var _active_count: int = 0
const MAX_ACTIVE: int = 60

var lifetime: float = 0.12
var elapsed: float = 0.0
var distance: float = 100.0
var palette_primary: Color = Color.WHITE
var palette_secondary: Color = Color(0.9, 0.9, 1.0, 1.0)

func _ready() -> void:
	BaseTowerAttackVFX._active_count += 1
	add_to_group("attack_vfx")

## Called by TowerAttackVFXService after reparenting.
func setup(origin: Vector2, target_pos: Vector2, tower_color: Color) -> void:
	palette_primary = tower_color
	palette_secondary = tower_color.lightened(0.28)
	global_position = origin
	var diff := target_pos - origin
	distance = diff.length()
	if distance > 0.5:
		global_rotation = diff.angle()
	queue_redraw()

## Override in T1 subclass to set lifetime, palette_primary, palette_secondary.
## Always call super.configure(data) at the end.
func configure(_data: Dictionary) -> void:
	pass

## Override in T1 subclass to draw the VFX.
## Default: rapid tracer bolt.
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_rapid_tracer(t, a, lend)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		BaseTowerAttackVFX._active_count -= 1
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(elapsed / maxf(lifetime, 0.001), 0.0, 1.0)
	var a := 1.0 - t
	var lend := Vector2(distance, 0.0)
	_draw_vfx(t, a, lend)

# ── Color helpers ─────────────────────────────────────────────────────────────

func _c(a: float) -> Color:
	return Color(palette_primary.r, palette_primary.g, palette_primary.b, a)

func _c2(a: float) -> Color:
	return Color(palette_secondary.r, palette_secondary.g, palette_secondary.b, a)

# ── Jagged lightning helper ───────────────────────────────────────────────────

func _jag(lend: Vector2, n: int) -> PackedVector2Array:
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

# ── Draw helpers — one per VFX kind ──────────────────────────────────────────

func _h_rapid_tracer(t: float, a: float, lend: Vector2) -> void:
	var reach := lend * minf(t * 4.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.3), 3.5, true)
	draw_line(Vector2.ZERO, reach, _c(a * 0.8), 1.2, true)
	draw_circle(Vector2.ZERO, 3.5 * (1.0 - t), _c(a))
	draw_circle(Vector2.ZERO, 1.8 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.75))

func _h_cannon_blast(t: float, a: float) -> void:
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

func _h_precision_beam(t: float, a: float, lend: Vector2) -> void:
	var reach := lend * clampf(t * 5.0, 0.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.22), 4.5, true)
	draw_line(Vector2.ZERO, reach, _c(a * 0.85), 1.0, true)
	draw_circle(Vector2.ZERO, 3.0 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.9))

func _h_flame_cone(t: float, a: float, lend: Vector2) -> void:
	var cl := lend.x * 0.46 * (1.0 - t * 0.28)
	for layer in range(3):
		var w  := (12.0 - float(layer) * 3.5) * (1.0 - t * 0.35)
		var ll := cl * (1.0 - float(layer) * 0.08)
		var pts := PackedVector2Array([
			Vector2.ZERO,
			Vector2(ll * 0.3, -w * 0.5),
			Vector2(ll, -w * 0.22),
			Vector2(ll * 1.12, 0.0),
			Vector2(ll, w * 0.22),
			Vector2(ll * 0.3, w * 0.5),
		])
		var intensity := 0.55 - float(layer) * 0.1
		draw_colored_polygon(pts,
			Color(palette_primary.r,
				  palette_primary.g * (0.8 + float(layer) * 0.1),
				  palette_primary.b, a * intensity))

func _h_electric_arc(a: float, lend: Vector2, heavy: bool) -> void:
	var segs := 8 if heavy else 5
	var pts := _jag(lend, segs)
	if pts.size() >= 2:
		draw_polyline(pts, _c(a * 0.4), 3.5 if heavy else 2.5, true)
		draw_polyline(pts, Color(1.0, 1.0, 1.0, a * 0.72), 1.2 if heavy else 0.9, true)
	draw_circle(Vector2.ZERO, 4.0 * (1.0 - minf(a, 0.6)), _c(a * 0.65))
	draw_circle(lend, 3.0 * (1.0 - minf(a, 0.7)), Color(1.0, 1.0, 1.0, a * 0.8))

func _h_magic_enchant(t: float, a: float, lend: Vector2) -> void:
	var ring_r := 6.0 + t * 10.0
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 20, _c(a * 0.65), 2.2, true)
	for i in range(4):
		var ang := float(i) * TAU / 4.0 + t * 3.5
		draw_circle(Vector2(cos(ang), sin(ang)) * ring_r, 2.5 * (1.0 - t * 0.5), _c2(a * 0.85))
	draw_line(Vector2.ZERO, lend * 0.6, _c(a * 0.3), 2.0, true)

func _h_water_jet(t: float, a: float, lend: Vector2) -> void:
	for i in range(3):
		var off   := float(i - 1) * 3.5
		var reach := lend * (0.72 + float(i % 2) * 0.18) * (1.0 - t * 0.15)
		draw_line(Vector2.ZERO, reach + Vector2(0.0, off),
			_c(a * (0.62 - float(i % 2) * 0.12)), 2.8 - float(i) * 0.4, true)
	draw_circle(lend * 0.82, 4.5 * (1.0 - t), _c(a * 0.55))

func _h_frost_beam(t: float, a: float, lend: Vector2) -> void:
	var reach := lend * clampf(t * 4.5, 0.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.3), 5.0, true)
	draw_line(Vector2.ZERO, reach, _c(a * 0.75), 1.8, true)
	draw_line(Vector2.ZERO, reach, Color(1.0, 1.0, 1.0, a * 0.4), 0.8, true)
	for i in range(3):
		var f  := 0.25 + float(i) * 0.22
		var sp := Vector2(lend.x * f, (float(i % 2) * 2.0 - 1.0) * 3.5)
		draw_circle(sp, 2.2 * (1.0 - t), _c(a * 0.72))

func _h_poison_spray(t: float, a: float, lend: Vector2) -> void:
	for i in range(5):
		var spread := -0.38 + float(i) * 0.19
		var rf     := (0.62 + float(i % 2) * 0.28) * (1.0 - t * 0.18)
		var ep     := Vector2(lend.x * rf, lend.x * rf * tan(spread))
		draw_line(Vector2.ZERO, ep, _c(a * (0.75 - float(i) * 0.05)), 1.6, true)
		draw_circle(ep, 2.8 * (1.0 - t), _c(a * 0.8))

func _h_spore_puff(t: float, a: float, lend: Vector2) -> void:
	for i in range(4):
		var f   := float(i) / 4.0
		var off := Vector2(lend.x * (0.08 + f * 0.58), (float(i % 2) * 2.0 - 1.0) * 5.5)
		var r   := (3.0 + float(i) * 2.2) * (0.45 + t * 0.55)
		draw_circle(off, r, _c(a * (0.38 - float(i) * 0.05)))
		draw_arc(off, r, 0.0, TAU, 8, _c(a * 0.55), 1.0, true)

func _h_void_rift(t: float, a: float, lend: Vector2) -> void:
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

func _h_earth_impact(t: float, a: float) -> void:
	for i in range(6):
		var spread := -0.55 + float(i) * 0.22
		var sl     := (13.0 + float(i % 3) * 6.0) * (1.0 - t * 0.3)
		draw_line(Vector2.ZERO,
			Vector2(cos(spread) * sl, sin(spread) * sl),
			_c(a * 0.82), 3.0 - float(i % 3) * 0.6, true)
	draw_circle(Vector2.ZERO, 6.0 * (1.0 - t * 0.75), _c(a * 0.88))
	draw_circle(Vector2.ZERO, 3.2 * (1.0 - t * 0.75), Color(1.0, 0.85, 0.62, a * 0.65))

func _h_steam_burst(t: float, a: float, lend: Vector2) -> void:
	for i in range(3):
		var f := float(i) / 3.0
		var c := Vector2(lend.x * (0.18 + f * 0.3), 0.0)
		var r := (5.5 + float(i) * 4.5) * (0.28 + t * 0.72)
		draw_circle(c, r, Color(palette_primary.r, palette_primary.g,
			palette_primary.b, a * (0.28 - float(i) * 0.06)))
		draw_arc(c, r, 0.0, TAU, 12, _c(a * (0.55 - float(i) * 0.12)), 1.5, true)

func _h_light_pulse(t: float, a: float, lend: Vector2) -> void:
	var sr := 11.0 * (1.0 - t)
	for i in range(4):
		draw_line(Vector2.ZERO,
			Vector2(cos(i * PI * 0.5), sin(i * PI * 0.5)) * sr, _c(a * 0.72), 1.5, true)
	draw_circle(Vector2.ZERO, 4.5 * (1.0 - t), Color(1.0, 1.0, 1.0, a * 0.88))
	draw_circle(Vector2.ZERO, 2.2 * (1.0 - t), _c(a))
	draw_line(Vector2.ZERO, lend, _c(a * 0.32), 3.2, true)
	draw_line(Vector2.ZERO, lend, Color(1.0, 1.0, 1.0, a * 0.38), 1.0, true)

func _h_nature_vine(t: float, a: float, lend: Vector2) -> void:
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
		var lp := Vector2(lend.x * (0.22 + float(i) * 0.26), 0.0)
		draw_circle(lp, 2.8 * (1.0 - t * 0.45), _c(a * 0.65))

func _h_acid_splash(t: float, a: float, lend: Vector2) -> void:
	for i in range(5):
		var spread := -0.42 + float(i) * 0.21
		var dl     := (lend.length() * 0.5 + float(i % 2) * 18.0) * (1.0 - t * 0.28)
		var ep     := Vector2(cos(spread) * dl, sin(spread) * dl)
		draw_line(Vector2.ZERO, ep, _c(a * 0.58), 2.0, true)
		draw_circle(ep, 2.8 * (1.0 - t), _c(a * 0.82))
	draw_arc(Vector2.ZERO, 4.0 + t * 7.0, 0.0, TAU, 12, _c(a * 0.48), 1.5, true)

func _h_shadow_lash(t: float, a: float, lend: Vector2) -> void:
	for lane in range(2):
		var pts := PackedVector2Array()
		var oy  := (float(lane) * 2.0 - 1.0) * 3.2
		for i in range(5):
			var f     := float(i) / 4.0
			var arc_y := sin(f * PI) * (9.0 + float(lane) * 4.0) * (1.0 - t * 0.45)
			pts.append(Vector2(lend.x * f, oy + arc_y * (float(lane) * 2.0 - 1.0)))
		if pts.size() >= 2:
			draw_polyline(pts, _c(a * (0.78 - float(lane) * 0.18)),
				2.5 - float(lane) * 0.5, true)

func _h_trickery_shimmer(t: float, a: float, lend: Vector2) -> void:
	var ac := Color(0.55, 0.12, 0.85, a * 0.72)
	for i in range(6):
		var f  := float(i) / 6.0
		var sp := Vector2(lend.x * f, (float(i % 2) * 2.0 - 1.0) * 7.0 * (1.0 - f))
		draw_circle(sp, 2.8 * (1.0 - t * 0.65), ac if i % 2 == 0 else _c(a * 0.82))
	draw_line(Vector2.ZERO, lend * 0.75, _c(a * 0.28), 1.5, true)

func _h_support_pulse(t: float, a: float) -> void:
	## Radial ring burst — for support/aura towers at activation moment.
	var r := 4.0 + t * 18.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, _c(a * 0.55), 2.0, true)
	for i in range(4):
		var ang := float(i) * TAU / 4.0
		draw_circle(Vector2(cos(ang), sin(ang)) * r, 2.0 * (1.0 - t), _c(a * 0.72))
