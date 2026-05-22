## BaseTowerAttackVFX — base class for all per-tower attack VFX nodes.
## Subclasses override configure() to set lifetime/palette and _draw_vfx() to draw.
## All drawing is in LOCAL space: +X points toward the target.
## lend = Vector2(distance, 0) is the local-space endpoint.
class_name BaseTowerAttackVFX
extends Node2D

static var _active_count: int = 0
const MAX_ACTIVE: int = 80   # per-tower model: 1 slot/tower, scales with placed towers

var lifetime: float = 0.10
var elapsed: float = 0.0
var distance: float = 100.0
var palette_primary: Color = Color.WHITE
var palette_secondary: Color = Color(0.9, 0.9, 1.0, 1.0)
var _counted: bool = false
var max_visual_reach: float = 10000.0

# ── Static-mode (baker-style) ────────────────────────────────────────────────
# Each tower owns one VFX node permanently. show_shot_static() draws ONCE via
# queue_redraw(), then a Tween fades modulate.a — no _process loop, no repeated
# queue_redraw(). This mirrors how TowerTextureBaker works for tower visuals.
var static_mode: bool = false
var _shot_tween: Tween = null

## Baker-style entry point for owned VFX nodes.
## Draws exactly once; Tween handles the fade — no _process / queue_redraw loop.
func show_shot_static(origin: Vector2, target_pos: Vector2, tower_color: Color) -> void:
	if PerformanceFirebreak.disable_all_attack_vfx:
		return
	palette_primary  = tower_color
	palette_secondary = tower_color.lightened(0.28)
	global_position  = origin
	var diff := target_pos - origin
	distance = diff.length()
	if distance > 0.5:
		global_rotation = diff.angle()
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible  = true
	queue_redraw()   # single draw call — static_mode draws at t=1,a=1
	if _shot_tween:
		_shot_tween.kill()
	_shot_tween = create_tween()
	_shot_tween.tween_property(self, "modulate:a", 0.0, lifetime)
	_shot_tween.tween_callback(_on_static_shot_done)

func _on_static_shot_done() -> void:
	visible  = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)  # reset for next shot

func _ready() -> void:
	add_to_group("attack_vfx")
	if static_mode:
		visible = false
		set_process(false)
		return
	if not has_meta("pooled"):
		_begin_pooled_lifecycle()

## Called by TowerAttackVFXService (pool path) after reparenting.
func setup(origin: Vector2, target_pos: Vector2, tower_color: Color) -> void:
	_begin_pooled_lifecycle()
	palette_primary = tower_color
	palette_secondary = tower_color.lightened(0.28)
	elapsed = 0.0
	global_position = origin
	var diff := target_pos - origin
	distance = diff.length()
	if distance > 0.5:
		global_rotation = diff.angle()
	queue_redraw()

## Override in subclass to set lifetime/palette. Called once at node creation.
func configure(_data: Dictionary) -> void:
	pass

## Override in subclass to draw the VFX.
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_rapid_tracer(t, a, lend)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		_release_to_pool()
		return
	if not PerformanceFirebreak.disable_all_attack_vfx:
		queue_redraw()

func _begin_pooled_lifecycle() -> void:
	if _counted:
		return
	_counted = true
	BaseTowerAttackVFX._active_count += 1
	visible = true
	set_process(true)

func _release_to_pool() -> void:
	if _counted:
		_counted = false
		BaseTowerAttackVFX._active_count = maxi(0, BaseTowerAttackVFX._active_count - 1)
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release"):
		pool.release(self)
	else:
		call_deferred("free")

func reset_for_pool() -> void:
	elapsed = 0.0
	distance = 100.0
	lifetime = 0.12
	palette_primary = Color.WHITE
	palette_secondary = Color(0.9, 0.9, 1.0, 1.0)

func _draw() -> void:
	var lend := _get_visual_lend()
	if static_mode:
		# Draw at full extent (t=1) and full alpha (a=1).
		# modulate.a is handled by the Tween — no per-frame alpha logic needed.
		_draw_vfx(1.0, 1.0, lend)
	else:
		var t := clampf(elapsed / maxf(lifetime, 0.001), 0.0, 1.0)
		_draw_vfx(t, 1.0 - t, lend)

func _get_visual_lend() -> Vector2:
	return Vector2(minf(distance, max_visual_reach), 0.0)

func _compact_lend(lend: Vector2, max_len: float = 88.0) -> Vector2:
	return Vector2(minf(lend.x, max_len), 0.0)

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
	draw_line(Vector2.ZERO, reach, _c(a * 0.10), 2.5, true)   # slim halo
	draw_line(Vector2.ZERO, reach, _c(a * 0.92), 1.5, true)   # crisp core
	draw_circle(Vector2.ZERO, 2.8 * (1.0 - t), _c(a * 0.9))
	draw_circle(Vector2.ZERO, 1.4 * (1.0 - t), _c2(a * 0.95)) # element-colored core

func _h_cannon_blast(t: float, a: float) -> void:
	var r := 7.0 + t * 16.0
	draw_circle(Vector2.ZERO, r, _c(a * 0.12))                # softer fill
	draw_arc(Vector2.ZERO, r, -0.65, 0.65, 12, _c(a * 0.80), 2.2, true)
	for i in range(5):
		var spread := -0.4 + float(i) * 0.2
		var rlen   := (18.0 + float(i % 2) * 8.0) * (1.0 - t * 0.45)
		draw_line(Vector2.ZERO,
			Vector2(cos(spread) * rlen, sin(spread) * rlen),
			_c(a * (0.9 - float(i) * 0.1)), 2.0 - float(i % 2) * 0.4, true)
	draw_circle(Vector2.ZERO, 4.0 * (1.0 - t), _c2(a * 0.72)) # element-colored core

func _h_precision_beam(t: float, a: float, lend: Vector2) -> void:
	var reach := lend * clampf(t * 5.0, 0.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.10), 3.0, true)   # narrow halo
	draw_line(Vector2.ZERO, reach, _c(a * 0.90), 1.2, true)   # bright core
	draw_circle(Vector2.ZERO, 2.8 * (1.0 - t), _c(a * 0.9))  # element-colored

func _h_flame_cone(t: float, a: float, lend: Vector2) -> void:
	var visual := _compact_lend(lend, 96.0)
	var cl := visual.x * 0.46 * (1.0 - t * 0.28)
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
		draw_polyline(pts, _c(a * 0.20), 2.8 if heavy else 2.0, true)  # softer glow
		draw_polyline(pts, Color(1.0, 1.0, 1.0, a * 0.75), 1.2 if heavy else 0.9, true)
	draw_circle(Vector2.ZERO, 3.5 * (1.0 - minf(a, 0.6)), _c(a * 0.72))
	draw_circle(lend, 2.5 * (1.0 - minf(a, 0.7)), _c2(a * 0.85))     # element-colored hit

func _h_magic_enchant(t: float, a: float, lend: Vector2) -> void:
	var ring_r := 6.0 + t * 10.0
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 20, _c(a * 0.65), 2.2, true)
	for i in range(4):
		var ang := float(i) * TAU / 4.0 + t * 3.5
		draw_circle(Vector2(cos(ang), sin(ang)) * ring_r, 2.5 * (1.0 - t * 0.5), _c2(a * 0.85))
	draw_line(Vector2.ZERO, lend * 0.6, _c(a * 0.3), 2.0, true)

func _h_water_jet(t: float, a: float, lend: Vector2) -> void:
	for i in range(3):
		var off   := float(i - 1) * 3.0
		var reach := lend * (0.72 + float(i % 2) * 0.18) * (1.0 - t * 0.15)
		draw_line(Vector2.ZERO, reach + Vector2(0.0, off),
			_c(a * (0.75 - float(i % 2) * 0.15)), 2.2 - float(i) * 0.3, true)
	draw_circle(lend * 0.82, 3.8 * (1.0 - t), _c(a * 0.65))

func _h_frost_beam(t: float, a: float, lend: Vector2) -> void:
	var reach := lend * clampf(t * 4.5, 0.0, 1.0)
	draw_line(Vector2.ZERO, reach, _c(a * 0.12), 3.5, true)   # thinner fog layer
	draw_line(Vector2.ZERO, reach, _c(a * 0.80), 1.8, true)
	draw_line(Vector2.ZERO, reach, _c2(a * 0.45), 0.8, true)  # icy secondary highlight
	for i in range(3):
		var f  := 0.25 + float(i) * 0.22
		var sp := Vector2(lend.x * f, (float(i % 2) * 2.0 - 1.0) * 3.5)
		draw_circle(sp, 2.2 * (1.0 - t), _c(a * 0.72))

func _h_poison_spray(t: float, a: float, lend: Vector2) -> void:
	var visual := _compact_lend(lend, 90.0)
	for i in range(5):
		var spread := -0.38 + float(i) * 0.19
		var rf     := (0.62 + float(i % 2) * 0.28) * (1.0 - t * 0.18)
		var ep     := Vector2(visual.x * rf, visual.x * rf * tan(spread))
		draw_line(Vector2.ZERO, ep, _c(a * (0.75 - float(i) * 0.05)), 1.6, true)
		draw_circle(ep, 2.8 * (1.0 - t), _c(a * 0.8))

func _h_spore_puff(t: float, a: float, lend: Vector2) -> void:
	var visual := _compact_lend(lend, 84.0)
	for i in range(4):
		var f   := float(i) / 4.0
		var off := Vector2(visual.x * (0.08 + f * 0.58), (float(i % 2) * 2.0 - 1.0) * 5.5)
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
	draw_line(Vector2.ZERO, lend, _c(a * 0.22), 2.0, true)
	draw_line(Vector2.ZERO, lend, _c2(a * 0.36), 0.9, true)
	draw_circle(lend, 3.5 * (1.0 - t), _c(a * 0.65))

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
	var visual := _compact_lend(lend, 84.0)
	for i in range(3):
		var f := float(i) / 3.0
		var c := Vector2(visual.x * (0.18 + f * 0.3), 0.0)
		var r := (5.5 + float(i) * 4.5) * (0.28 + t * 0.72)
		draw_circle(c, r, Color(palette_primary.r, palette_primary.g,
			palette_primary.b, a * (0.28 - float(i) * 0.06)))
		draw_arc(c, r, 0.0, TAU, 12, _c(a * (0.55 - float(i) * 0.12)), 1.5, true)

func _h_light_pulse(t: float, a: float, lend: Vector2) -> void:
	var sr := 11.0 * (1.0 - t)
	for i in range(4):
		draw_line(Vector2.ZERO,
			Vector2(cos(i * PI * 0.5), sin(i * PI * 0.5)) * sr, _c(a * 0.75), 1.5, true)
	draw_circle(Vector2.ZERO, 3.8 * (1.0 - t), _c(a * 0.80))  # element-colored (was white)
	draw_circle(Vector2.ZERO, 2.0 * (1.0 - t), _c(a))
	draw_line(Vector2.ZERO, lend, _c(a * 0.14), 2.8, true)     # narrower halo
	draw_line(Vector2.ZERO, lend, _c2(a * 0.45), 1.0, true)    # secondary color core

func _h_nature_vine(t: float, a: float, lend: Vector2) -> void:
	var n_seg := clampi(int(lend.length() / 18.0) + 2, 3, 7)
	var pts   := PackedVector2Array()
	for i in range(n_seg + 1):
		var f    := float(i) / n_seg
		var wave := sin(f * TAU * 1.3 + t * 4.5) * 5.5
		pts.append(Vector2(lend.x * f, wave))
	if pts.size() >= 2:
		draw_polyline(pts, _c(a * 0.18), 3.2, true)  # thinner shadow
		draw_polyline(pts, _c(a * 0.80), 1.6, true)
	for i in range(3):
		var lp := Vector2(lend.x * (0.22 + float(i) * 0.26), 0.0)
		draw_circle(lp, 2.5 * (1.0 - t * 0.45), _c(a * 0.72))

func _h_acid_splash(t: float, a: float, lend: Vector2) -> void:
	var visual := _compact_lend(lend, 90.0)
	for i in range(5):
		var spread := -0.42 + float(i) * 0.21
		var dl     := (visual.length() * 0.5 + float(i % 2) * 18.0) * (1.0 - t * 0.28)
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
