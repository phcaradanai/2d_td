extends Node2D
class_name TowerHitVFX

## Lightweight pooled tower impact VFX.
## Draws once, then animates only transform/modulate to avoid per-frame redraw cost.

static var active_count: int = 0

var mode: String = "single"
var radius: float = 0.0
var core_color: Color = Color.WHITE
var glow_color: Color = Color.WHITE
var accent_color: Color = Color.WHITE
var _counted: bool = false
var _active_tween: Tween = null

func setup(
		p_mode: String,
		p_radius: float,
		p_core_color: Color,
		p_glow_color: Color,
		p_accent_color: Color,
		p_angle: float = 0.0,
		p_quality_name: String = "HIGH") -> void:
	if PerformanceFirebreak.disable_all_attack_vfx:
		_release_to_pool()
		return

	mode = p_mode
	radius = _resolve_visual_radius(p_radius)
	core_color = p_core_color
	glow_color = p_glow_color
	accent_color = p_accent_color
	rotation = p_angle
	_begin_lifecycle()

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	var duration := 0.18
	var scale_target := 1.0
	match p_quality_name:
		"LOW":
			duration = 0.12
			scale_target = 0.72
		"BALANCED", "MED":
			duration = 0.15
			scale_target = 0.86

	scale = Vector2.ONE * 0.22
	modulate = Color.WHITE
	queue_redraw()

	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_active_tween.parallel().tween_property(self, "scale", Vector2.ONE * scale_target, duration)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(self, "modulate:a", 0.0, duration + 0.055)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_release_to_pool)

func _begin_lifecycle() -> void:
	if _counted:
		return
	_counted = true
	active_count += 1
	visible = true
	set_process(false)
	set_physics_process(false)

func _release_to_pool() -> void:
	if _counted:
		_counted = false
		active_count = maxi(0, active_count - 1)
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release") and has_meta("pooled"):
		pool.release(self)
	else:
		call_deferred("free")

func reset_for_pool() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	if _counted:
		_counted = false
		active_count = maxi(0, active_count - 1)
	mode = "single"
	radius = 0.0
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE

func _resolve_visual_radius(source_radius: float) -> float:
	if source_radius <= 0.0:
		return 18.0
	# This is a hit readability cue, not the gameplay AoE circle. Keep it compact
	# so cannon / splash towers do not cover the road with large rings.
	return clampf(source_radius * 0.46, 18.0, 56.0)

func _draw() -> void:
	match mode:
		"splash":
			_draw_splash_impact()
		"slow":
			_draw_slow_impact()
		"chain":
			_draw_chain_impact()
		"beam":
			_draw_beam_impact()
		"fire":
			_draw_fire_impact()
		"fire_blast":
			_draw_fire_blast_impact()
		"seismic":
			_draw_seismic_impact()
		"water":
			_draw_water_impact()
		"frost":
			_draw_frost_impact()
		"toxic":
			_draw_toxic_impact()
		"void":
			_draw_void_impact()
		"prism":
			_draw_prism_impact()
		"nature":
			_draw_nature_impact()
		"gold":
			_draw_gold_impact()
		"arcane":
			_draw_arcane_impact()
		_:
			_draw_single_impact()

func _draw_single_impact() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(core_color.r, core_color.g, core_color.b, 0.72))
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + 0.25)
		draw_line(dir * 3.0, dir * 13.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.72), 1.6, true)
	draw_circle(Vector2.ZERO, 1.8, Color.WHITE)

func _draw_splash_impact() -> void:
	var ring := Color(core_color.r, core_color.g, core_color.b, 0.58)
	var soft := Color(glow_color.r, glow_color.g, glow_color.b, 0.14)
	draw_circle(Vector2.ZERO, radius * 0.46, soft)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring, 2.15, true)
	draw_arc(Vector2.ZERO, radius * 0.58, PI * 0.08, PI * 1.52, 28, Color(accent_color.r, accent_color.g, accent_color.b, 0.52), 1.4, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0)
		draw_line(dir * (radius * 0.18), dir * (radius * 0.42), Color(core_color.r, core_color.g, core_color.b, 0.36), 1.5, true)
	draw_circle(Vector2.ZERO, 4.5, Color.WHITE)

func _draw_slow_impact() -> void:
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(glow_color.r, glow_color.g, glow_color.b, 0.66), 2.0, true)
	draw_arc(Vector2.ZERO, 24.0, -PI * 0.25, PI * 1.1, 24, Color(core_color.r, core_color.g, core_color.b, 0.32), 1.2, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0)
		draw_line(dir * 5.0, dir * 14.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.58), 1.0, true)
	draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

func _draw_chain_impact() -> void:
	draw_circle(Vector2.ZERO, 4.8, Color(core_color.r, core_color.g, core_color.b, 0.70))
	for i in range(5):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 5.0 + 0.15)
		var side := dir.rotated(PI * 0.5)
		var a := dir * 4.0
		var b := dir * 10.0 + side * 2.3
		var c := dir * 15.0 - side * 1.7
		draw_polyline(PackedVector2Array([a, b, c]), Color(glow_color.r, glow_color.g, glow_color.b, 0.76), 1.35, true)

func _draw_beam_impact() -> void:
	draw_line(Vector2(-16.0, 0.0), Vector2(18.0, 0.0), Color(glow_color.r, glow_color.g, glow_color.b, 0.74), 3.0, true)
	draw_line(Vector2(-10.0, -5.5), Vector2(11.0, 5.5), Color(core_color.r, core_color.g, core_color.b, 0.52), 1.3, true)
	draw_line(Vector2(-10.0, 5.5), Vector2(11.0, -5.5), Color(accent_color.r, accent_color.g, accent_color.b, 0.48), 1.1, true)
	draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

func _draw_fire_impact() -> void:
	var flame := PackedVector2Array([
		Vector2(-10.0, -5.0),
		Vector2(2.0, -11.0),
		Vector2(15.0, 0.0),
		Vector2(2.0, 11.0),
		Vector2(-10.0, 5.0),
	])
	draw_colored_polygon(flame, Color(glow_color.r, glow_color.g, glow_color.b, 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, -2.8),
		Vector2(4.0, -5.0),
		Vector2(10.0, 0.0),
		Vector2(4.0, 5.0),
		Vector2(-5.0, 2.8),
	]), Color(core_color.r, core_color.g, core_color.b, 0.68))
	draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

func _draw_fire_blast_impact() -> void:
	var r := maxf(radius, 24.0)
	draw_circle(Vector2.ZERO, r * 0.34, Color(glow_color.r, glow_color.g, glow_color.b, 0.18))
	draw_arc(Vector2.ZERO, r * 0.72, -0.2, TAU - 0.2, 34, Color(core_color.r, core_color.g, core_color.b, 0.58), 2.0, true)
	for i in range(7):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 7.0 + 0.12)
		var inner := dir * (r * 0.12)
		var outer := dir * (r * (0.36 + float(i % 3) * 0.045))
		draw_line(inner, outer, Color(accent_color.r, accent_color.g, accent_color.b, 0.45), 1.4, true)
	draw_circle(Vector2.ZERO, 3.2, Color.WHITE)

func _draw_seismic_impact() -> void:
	var r := maxf(radius, 28.0)
	draw_arc(Vector2.ZERO, r * 0.88, PI * 0.05, PI * 1.85, 42, Color(core_color.r, core_color.g, core_color.b, 0.50), 2.3, true)
	draw_arc(Vector2.ZERO, r * 0.42, -PI * 0.2, PI * 1.2, 24, Color(glow_color.r, glow_color.g, glow_color.b, 0.28), 1.2, true)
	for i in range(6):
		var angle := float(i) * TAU / 6.0 + 0.08
		var dir := Vector2.RIGHT.rotated(angle)
		var side := dir.rotated(PI * 0.5)
		var a := dir * (r * 0.10)
		var b := dir * (r * 0.34) + side * (2.0 if i % 2 == 0 else -2.0)
		var c := dir * (r * 0.58)
		draw_polyline(PackedVector2Array([a, b, c]), Color(accent_color.r, accent_color.g, accent_color.b, 0.58), 1.7, true)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)

func _draw_water_impact() -> void:
	var r := maxf(radius, 26.0)
	draw_arc(Vector2.ZERO, r * 0.82, PI * 0.10, PI * 1.92, 44, Color(core_color.r, core_color.g, core_color.b, 0.56), 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.50, -PI * 0.24, PI * 1.15, 28, Color(glow_color.r, glow_color.g, glow_color.b, 0.34), 1.4, true)
	for i in range(5):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 5.0 + 0.35)
		draw_circle(dir * (r * 0.34), 1.8, Color(accent_color.r, accent_color.g, accent_color.b, 0.58))
	draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

func _draw_frost_impact() -> void:
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, Color(glow_color.r, glow_color.g, glow_color.b, 0.62), 1.7, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + PI * 0.08)
		var side := dir.rotated(PI * 0.5)
		var tip := dir * 17.0
		var left := dir * 6.5 + side * 2.4
		var right := dir * 6.5 - side * 2.4
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(core_color.r, core_color.g, core_color.b, 0.42))
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

func _draw_toxic_impact() -> void:
	var r := maxf(radius, 22.0)
	draw_circle(Vector2.ZERO, r * 0.22, Color(glow_color.r, glow_color.g, glow_color.b, 0.24))
	draw_arc(Vector2.ZERO, r * 0.56, 0.0, TAU, 26, Color(core_color.r, core_color.g, core_color.b, 0.46), 1.4, true)
	var offsets := [
		Vector2(8.0, -3.0),
		Vector2(-7.0, -5.0),
		Vector2(-5.0, 6.0),
		Vector2(5.0, 7.0),
		Vector2(13.0, 4.0)
	]
	for offset in offsets:
		draw_circle(offset, 1.6, Color(accent_color.r, accent_color.g, accent_color.b, 0.72))
	draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

func _draw_void_impact() -> void:
	draw_circle(Vector2.ZERO, 5.2, Color(0.02, 0.0, 0.045, 0.78))
	draw_arc(Vector2.ZERO, 12.5, 0.0, TAU, 32, Color(glow_color.r, glow_color.g, glow_color.b, 0.70), 1.8, true)
	draw_arc(Vector2.ZERO, 18.5, PI * 0.22, PI * 1.70, 32, Color(core_color.r, core_color.g, core_color.b, 0.34), 1.1, true)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + 0.42)
		draw_line(dir * 5.0, dir * 15.5, Color(accent_color.r, accent_color.g, accent_color.b, 0.52), 1.1, true)
	draw_circle(Vector2.ZERO, 1.8, Color.WHITE)

func _draw_prism_impact() -> void:
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0)
		draw_line(Vector2.ZERO, dir * 17.0, Color(core_color.r, core_color.g, core_color.b, 0.62), 1.35, true)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 6, Color(glow_color.r, glow_color.g, glow_color.b, 0.72), 1.4, true)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

func _draw_nature_impact() -> void:
	for i in range(5):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 5.0 - PI * 0.5)
		var side := dir.rotated(PI * 0.5)
		var tip := dir * 15.0
		var left := dir * 5.0 + side * 3.2
		var right := dir * 5.0 - side * 3.2
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(core_color.r, core_color.g, core_color.b, 0.42))
	draw_arc(Vector2.ZERO, 13.0, PI * 0.15, PI * 1.55, 20, Color(glow_color.r, glow_color.g, glow_color.b, 0.44), 1.2, true)
	draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

func _draw_gold_impact() -> void:
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 8, Color(core_color.r, core_color.g, core_color.b, 0.72), 1.6, true)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + PI * 0.25)
		draw_rect(Rect2(dir.x * 9.0 - 1.6, dir.y * 9.0 - 1.6, 3.2, 3.2), Color(accent_color.r, accent_color.g, accent_color.b, 0.62))
	draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

func _draw_arcane_impact() -> void:
	var r := maxf(radius, 22.0)
	draw_arc(Vector2.ZERO, r * 0.50, 0.0, TAU, 3, Color(core_color.r, core_color.g, core_color.b, 0.48), 1.5, true)
	draw_arc(Vector2.ZERO, r * 0.34, PI * 0.25, PI * 1.58, 5, Color(glow_color.r, glow_color.g, glow_color.b, 0.58), 1.1, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + 0.18)
		draw_circle(dir * (r * 0.26), 1.2, Color(accent_color.r, accent_color.g, accent_color.b, 0.68))
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
