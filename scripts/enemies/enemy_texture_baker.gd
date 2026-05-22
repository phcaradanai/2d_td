## EnemyTextureBaker — bakes each (visual_type × health_state) combination into a
## cached ImageTexture once per session. Enemies swap to Sprite2D after baking,
## reducing ~15 draw calls per enemy to 1 Sprite2D + 0-3 dynamic overlay calls.
##
## Pattern mirrors TowerTextureBaker exactly.
extends Node

# ── Cache ────────────────────────────────────────────────────────────────────
var _cache: Dictionary = {}   # "vt|health" → ImageTexture
var _pending: Array    = []   # Array[Dictionary]
var _baking: bool      = false

# ── Viewport sizing ──────────────────────────────────────────────────────────
const BAKE_SIZE := 128    # viewport px — ±32 world units at BAKE_ZOOM 2.0
const BAKE_ZOOM := 2.0    # enemy SIZE=16 → body ≈ ±14 px → fits with margin

# ── Renderer ─────────────────────────────────────────────────────────────────
const ROUTER = preload("res://scripts/enemies/enemy_visual_router.gd")

class _BakeRenderer extends Node2D:
	var visual_type:         String = "basic"
	var health_visual_state: int    = 0
	var active_slow_percent: float  = 0.0
	var shield_remaining:    float  = 0.0
	var is_flashing:         bool   = false
	var hit_flash_color:     Color  = Color.WHITE
	var hit_flash_alpha:     float  = 0.0
	var pulse_time:          float  = 0.5   # fixed pose
	var PERFORMANCE_VISUAL_MODE: bool = true
	var enemy_type:          String = ""
	var tags:                Array  = []
	var swarm_pack_density:  float  = 1.0
	var swarm_core_flicker_time: float = 0.0

	const _ROUTER = preload("res://scripts/enemies/enemy_visual_router.gd")

	func configure(p_vt: String, p_health: int) -> void:
		visual_type         = p_vt
		health_visual_state = p_health
		enemy_type          = p_vt

	func _draw() -> void:
		_draw_faux_3q_shadow()
		var body_offset := _get_faux_3q_body_offset()
		var body_scale := _get_faux_3q_body_scale()
		draw_set_transform(body_offset + _get_faux_3q_side_offset(), 0.0, body_scale)
		_draw_faux_3q_side_mass()
		draw_set_transform(body_offset, 0.0, body_scale)
		_ROUTER._dispatch_simple(self, visual_type, 16.0)
		_draw_faux_3q_depth_cue()
		_draw_faux_3q_form_planes()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_faux_3q_shadow() -> void:
		var shadow := _get_faux_3q_shadow_profile()
		var center: Vector2 = shadow.get("center", Vector2(0.0, 8.0))
		var rx := float(shadow.get("rx", 13.0))
		var ry := float(shadow.get("ry", 4.2))
		var alpha := float(shadow.get("alpha", 0.22))
		var points := PackedVector2Array()
		for i in range(22):
			var a := float(i) / 22.0 * TAU
			points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, alpha))
		var core := PackedVector2Array()
		for i in range(18):
			var a := float(i) / 18.0 * TAU
			core.append(center + Vector2(cos(a) * rx * 0.58, sin(a) * ry * 0.62))
		draw_colored_polygon(core, Color(0.0, 0.0, 0.0, alpha * 0.72))

	func _get_faux_3q_body_offset() -> Vector2:
		match visual_type:
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				return Vector2(0.0, -3.2)
			"swarm", "fast_flyer", "flyer", "disruptor":
				return Vector2(0.0, -4.0)
			"fast", "runner", "hunter":
				return Vector2(0.0, -3.6)
			_:
				return Vector2(0.0, -3.3)

	func _get_faux_3q_body_scale() -> Vector2:
		match visual_type:
			"tank", "bulwark", "shieldbearer":
				return Vector2(1.03, 0.82)
			"swarm", "flyer", "fast_flyer", "armored_flyer", "disruptor":
				return Vector2(1.02, 0.86)
			"fast", "runner", "hunter":
				return Vector2(1.05, 0.84)
			_:
				return Vector2(1.02, 0.84)

	func _get_faux_3q_side_offset() -> Vector2:
		match visual_type:
			"tank", "bulwark", "shieldbearer":
				return Vector2(0.0, 5.4)
			"swarm", "flyer", "fast_flyer", "disruptor":
				return Vector2(0.0, 4.4)
			"fast", "runner", "hunter":
				return Vector2(0.0, 4.8)
			_:
				return Vector2(0.0, 5.0)

	func _get_faux_3q_shadow_profile() -> Dictionary:
		match visual_type:
			"tank", "bulwark", "shieldbearer":
				return {"center": Vector2(0.0, 10.2), "rx": 16.2, "ry": 4.7, "alpha": 0.26}
			"swarm":
				return {"center": Vector2(0.0, 10.5), "rx": 16.0, "ry": 4.9, "alpha": 0.18}
			"flyer", "fast_flyer", "disruptor":
				return {"center": Vector2(0.0, 11.0), "rx": 12.4, "ry": 3.3, "alpha": 0.15}
			"armored_flyer":
				return {"center": Vector2(0.0, 10.8), "rx": 15.8, "ry": 4.2, "alpha": 0.17}
			"fast", "runner", "hunter":
				return {"center": Vector2(0.0, 9.8), "rx": 14.2, "ry": 3.8, "alpha": 0.22}
			_:
				return {"center": Vector2(0.0, 9.6), "rx": 13.2, "ry": 3.8, "alpha": 0.22}

	func _draw_faux_3q_side_mass() -> void:
		var p := _get_faux_3q_body_profile()
		var w := float(p.get("w", 15.0))
		var h := float(p.get("h", 13.0))
		var alpha := float(p.get("alpha", 0.24))
		var side := Color(0.0, 0.0, 0.0, alpha)
		var side_deep := Color(0.0, 0.0, 0.0, minf(alpha + 0.10, 0.38))
		var side_warm := Color(0.08, 0.035, 0.018, minf(alpha * 0.42, 0.13))

		match visual_type:
			"fast", "runner", "hunter", "fast_flyer":
				draw_colored_polygon(PackedVector2Array([
					Vector2(w * 0.98, 0.0),
					Vector2(w * 0.18, -h * 0.32),
					Vector2(-w * 0.76, -h * 0.20),
					Vector2(-w * 0.52, h * 0.34),
					Vector2(w * 0.12, h * 0.48),
					Vector2(w * 0.86, h * 0.20),
				]), side)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-w * 0.52, h * 0.24),
					Vector2(w * 0.14, h * 0.36),
					Vector2(w * 0.84, h * 0.12),
					Vector2(w * 0.58, h * 0.50),
					Vector2(-w * 0.38, h * 0.60),
				]), side_deep)
			"swarm":
				for c in [Vector2(-w * 0.38, -h * 0.16), Vector2(w * 0.38, -h * 0.16), Vector2(0.0, h * 0.30)]:
					_draw_flat_ellipse(c + Vector2(0.0, h * 0.16), w * 0.34, h * 0.26, side)
				_draw_flat_ellipse(Vector2(0.0, h * 0.34), w * 0.78, h * 0.22, side_deep)
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				draw_colored_polygon(PackedVector2Array([
					Vector2(-w * 0.82, -h * 0.20),
					Vector2(w * 0.82, -h * 0.20),
					Vector2(w * 0.76, h * 0.48),
					Vector2(w * 0.42, h * 0.70),
					Vector2(-w * 0.42, h * 0.70),
					Vector2(-w * 0.76, h * 0.48),
				]), side)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-w * 0.72, h * 0.24),
					Vector2(w * 0.72, h * 0.24),
					Vector2(w * 0.52, h * 0.72),
					Vector2(-w * 0.52, h * 0.72),
				]), side_deep)
			_:
				draw_colored_polygon(PackedVector2Array([
					Vector2(0.0, -h * 0.66),
					Vector2(w * 0.64, -h * 0.32),
					Vector2(w * 0.82, h * 0.10),
					Vector2(w * 0.50, h * 0.62),
					Vector2(0.0, h * 0.78),
					Vector2(-w * 0.50, h * 0.62),
					Vector2(-w * 0.82, h * 0.10),
					Vector2(-w * 0.64, -h * 0.32),
				]), side)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-w * 0.58, h * 0.18),
					Vector2(w * 0.58, h * 0.18),
					Vector2(w * 0.44, h * 0.70),
					Vector2(0.0, h * 0.86),
					Vector2(-w * 0.44, h * 0.70),
				]), side_deep)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.42, h * 0.52),
			Vector2(w * 0.42, h * 0.52),
			Vector2(w * 0.30, h * 0.68),
			Vector2(-w * 0.30, h * 0.68),
		]), side_warm)

	func _draw_flat_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in range(16):
			var a := float(i) / 16.0 * TAU
			points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(points, color)

	func _get_faux_3q_body_profile() -> Dictionary:
		match visual_type:
			"tank", "bulwark", "shieldbearer":
				return {"w": 17.5, "h": 15.5, "alpha": 0.26}
			"armored_flyer":
				return {"w": 16.5, "h": 14.5, "alpha": 0.22}
			"swarm":
				return {"w": 16.5, "h": 13.8, "alpha": 0.17}
			"fast", "runner", "hunter", "fast_flyer":
				return {"w": 16.0, "h": 13.0, "alpha": 0.22}
			"flyer", "disruptor":
				return {"w": 14.5, "h": 12.5, "alpha": 0.18}
			_:
				return {"w": 15.0, "h": 13.0, "alpha": 0.23}

	func _draw_faux_3q_depth_cue() -> void:
		var top_alpha := 0.12
		var lower_alpha := 0.16
		match visual_type:
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				top_alpha = 0.10
				lower_alpha = 0.19
			"swarm", "fast", "runner", "fast_flyer":
				top_alpha = 0.13
				lower_alpha = 0.13
			"cloaked":
				top_alpha = 0.07
				lower_alpha = 0.10

		draw_colored_polygon(PackedVector2Array([
			Vector2(-10.8, -11.2),
			Vector2(3.8, -11.8),
			Vector2(10.8, -5.6),
			Vector2(6.0, -2.2),
			Vector2(-6.5, -2.0),
		]), Color(1.0, 1.0, 1.0, top_alpha))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.6, 1.8),
			Vector2(12.2, 1.0),
			Vector2(9.2, 11.8),
			Vector2(-8.4, 12.2),
		]), Color(0.0, 0.0, 0.0, lower_alpha))
		draw_colored_polygon(PackedVector2Array([
			Vector2(5.0, -7.0),
			Vector2(12.4, -2.0),
			Vector2(11.4, 7.0),
			Vector2(5.4, 2.2),
		]), Color(0.0, 0.0, 0.0, lower_alpha * 0.42))

	func _draw_faux_3q_form_planes() -> void:
		match visual_type:
			"fast":
				_draw_arrow_form_planes(
					Color(0.74, 1.0, 0.54, 0.28),
					Color(0.015, 0.10, 0.045, 0.34),
					Color(0.08, 0.30, 0.12, 0.22),
					1.00
				)
			"runner":
				_draw_arrow_form_planes(
					Color(0.86, 1.0, 0.46, 0.30),
					Color(0.03, 0.12, 0.035, 0.36),
					Color(0.95, 0.38, 0.08, 0.18),
					1.02
				)
			"hunter":
				_draw_arrow_form_planes(
					Color(1.0, 0.34, 0.76, 0.25),
					Color(0.055, 0.010, 0.090, 0.38),
					Color(0.62, 0.04, 0.96, 0.18),
					1.05
				)
			"splitter":
				_draw_crystal_form_planes(
					Color(1.0, 0.62, 0.16, 0.26),
					Color(0.24, 0.055, 0.012, 0.34),
					Color(1.0, 0.25, 0.06, 0.18),
					1.03
				)
			"basic", "healer", "cloaked", "disruptor":
				_draw_crystal_form_planes(
					_get_type_top_plane_color(),
					_get_type_lower_plane_color(),
					_get_type_side_plane_color(),
					0.94
				)
			"flyer", "fast_flyer", "armored_flyer":
				_draw_diamond_form_planes(
					_get_type_top_plane_color(),
					_get_type_lower_plane_color(),
					_get_type_side_plane_color(),
					0.92
				)
			"tank", "bulwark", "shieldbearer":
				_draw_block_form_planes(
					_get_type_top_plane_color(),
					_get_type_lower_plane_color(),
					_get_type_side_plane_color(),
					1.05
				)
			"swarm":
				_draw_swarm_form_planes()
			_:
				_draw_crystal_form_planes(
					Color(0.88, 1.0, 1.0, 0.18),
					Color(0.0, 0.0, 0.0, 0.24),
					Color(0.0, 0.10, 0.14, 0.16),
					0.92
				)

	func _draw_arrow_form_planes(top: Color, lower: Color, side: Color, scale: float) -> void:
		var s := scale
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.8, -5.8) * s,
			Vector2(2.0, -7.1) * s,
			Vector2(12.6, -1.0) * s,
			Vector2(3.1, -1.0) * s,
			Vector2(-8.2, -2.9) * s,
		]), top)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.4, 2.4) * s,
			Vector2(2.6, 2.0) * s,
			Vector2(11.2, 0.2) * s,
			Vector2(5.5, 6.6) * s,
			Vector2(-7.4, 5.0) * s,
		]), lower)
		draw_colored_polygon(PackedVector2Array([
			Vector2(4.0, -1.2) * s,
			Vector2(13.2, 0.0) * s,
			Vector2(4.8, 4.3) * s,
			Vector2(1.4, 1.2) * s,
		]), side)
		draw_line(Vector2(-6.8, -2.4) * s, Vector2(6.4, -0.5) * s, Color(1.0, 1.0, 1.0, top.a * 0.58), 0.85, true)
		draw_line(Vector2(-7.2, 4.7) * s, Vector2(6.4, 5.4) * s, Color(0.0, 0.0, 0.0, lower.a * 0.72), 1.0, true)

	func _draw_crystal_form_planes(top: Color, lower: Color, side: Color, scale: float) -> void:
		var s := scale
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7.8, -9.6) * s,
			Vector2(4.2, -10.2) * s,
			Vector2(9.8, -3.0) * s,
			Vector2(0.8, -0.6) * s,
			Vector2(-8.8, -3.2) * s,
		]), top)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.8, 2.2) * s,
			Vector2(0.0, 4.0) * s,
			Vector2(9.6, 1.5) * s,
			Vector2(5.8, 10.6) * s,
			Vector2(-5.8, 10.8) * s,
		]), lower)
		draw_colored_polygon(PackedVector2Array([
			Vector2(3.5, -4.0) * s,
			Vector2(10.5, -1.4) * s,
			Vector2(8.5, 7.4) * s,
			Vector2(1.0, 4.0) * s,
		]), side)
		draw_line(Vector2(-6.0, -4.0) * s, Vector2(4.8, -2.0) * s, Color(1.0, 1.0, 1.0, top.a * 0.48), 0.75, true)

	func _draw_diamond_form_planes(top: Color, lower: Color, side: Color, scale: float) -> void:
		var s := scale
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, -11.2) * s,
			Vector2(9.5, -1.8) * s,
			Vector2(0.0, 1.0) * s,
			Vector2(-9.5, -1.8) * s,
		]), top)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.6, 0.8) * s,
			Vector2(0.0, 3.6) * s,
			Vector2(9.6, 0.8) * s,
			Vector2(0.0, 11.0) * s,
		]), lower)
		draw_colored_polygon(PackedVector2Array([
			Vector2(1.0, -0.6) * s,
			Vector2(10.5, -1.8) * s,
			Vector2(0.8, 9.8) * s,
			Vector2(0.0, 3.6) * s,
		]), side)

	func _draw_block_form_planes(top: Color, lower: Color, side: Color, scale: float) -> void:
		var s := scale
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10.8, -8.2) * s,
			Vector2(9.2, -8.5) * s,
			Vector2(12.0, -2.2) * s,
			Vector2(2.5, 0.8) * s,
			Vector2(-11.2, -1.5) * s,
		]), top)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, 1.0) * s,
			Vector2(12.0, 0.6) * s,
			Vector2(9.2, 10.0) * s,
			Vector2(-8.8, 10.0) * s,
		]), lower)
		draw_colored_polygon(PackedVector2Array([
			Vector2(5.5, -5.4) * s,
			Vector2(12.4, -1.8) * s,
			Vector2(10.4, 8.4) * s,
			Vector2(4.2, 2.8) * s,
		]), side)

	func _draw_swarm_form_planes() -> void:
		for c in [Vector2(-6.0, -3.0), Vector2(6.0, -3.0), Vector2(0.0, 5.2)]:
			_draw_flat_ellipse(c + Vector2(-1.2, -2.0), 4.0, 2.0, Color(0.88, 1.0, 0.70, 0.16))
			_draw_flat_ellipse(c + Vector2(0.8, 2.2), 4.2, 1.9, Color(0.0, 0.06, 0.03, 0.18))

	func _get_type_top_plane_color() -> Color:
		match visual_type:
			"healer":
				return Color(0.78, 1.0, 0.78, 0.22)
			"cloaked":
				return Color(0.72, 0.74, 1.0, 0.13)
			"disruptor":
				return Color(0.82, 0.58, 1.0, 0.20)
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				return Color(1.0, 0.64, 0.22, 0.20)
			"flyer", "fast_flyer":
				return Color(0.62, 1.0, 1.0, 0.18)
			_:
				return Color(0.82, 1.0, 1.0, 0.18)

	func _get_type_lower_plane_color() -> Color:
		match visual_type:
			"healer":
				return Color(0.02, 0.10, 0.035, 0.24)
			"cloaked":
				return Color(0.01, 0.01, 0.05, 0.18)
			"disruptor":
				return Color(0.035, 0.0, 0.07, 0.28)
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				return Color(0.14, 0.055, 0.015, 0.32)
			"flyer", "fast_flyer":
				return Color(0.0, 0.045, 0.070, 0.21)
			_:
				return Color(0.0, 0.030, 0.040, 0.24)

	func _get_type_side_plane_color() -> Color:
		match visual_type:
			"healer":
				return Color(0.05, 0.20, 0.07, 0.15)
			"cloaked":
				return Color(0.08, 0.08, 0.18, 0.10)
			"disruptor":
				return Color(0.20, 0.04, 0.34, 0.16)
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				return Color(0.42, 0.18, 0.04, 0.14)
			"flyer", "fast_flyer":
				return Color(0.04, 0.22, 0.28, 0.12)
			_:
				return Color(0.04, 0.18, 0.20, 0.12)

# ── SubViewport ───────────────────────────────────────────────────────────────
var _vp:   SubViewport  = null
var _root: Node2D       = null
var _cam:  Camera2D     = null

func _ready() -> void:
	name = "EnemyTextureBaker"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _ensure_viewport() -> void:
	if _vp != null and is_instance_valid(_vp):
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.render_target_clear_mode  = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_vp)
	_cam = Camera2D.new()
	_cam.zoom    = Vector2(BAKE_ZOOM, BAKE_ZOOM)
	_cam.enabled = true
	_vp.add_child(_cam)
	_cam.make_current()
	_root = Node2D.new()
	_root.name = "RendererRoot"
	_vp.add_child(_root)

# ── Public API ────────────────────────────────────────────────────────────────

## Request a baked body texture. callback(ImageTexture) fires when ready.
## Returns immediately from cache if already baked.
func request_texture(visual_type: String, health_state: int, callback: Callable) -> void:
	var key := _cache_key(visual_type, health_state)
	if _cache.has(key):
		callback.call(_cache[key])
		return
	for job in _pending:
		if job["key"] == key:
			job["callbacks"].append(callback)
			return
	_pending.append({
		"key":        key,
		"vt":         visual_type,
		"health":     health_state,
		"callbacks":  [callback],
	})
	set_process(true)

## Pre-bake all 45 combinations at startup so swaps are instant during gameplay.
func prewarm_all(done_callback: Callable = Callable()) -> void:
	const TYPES := [
		"basic","fast","tank","bulwark","hunter","swarm",
		"runner","shieldbearer","healer","splitter","cloaked",
		"flyer","fast_flyer","armored_flyer","disruptor",
	]
	const HEALTH_STATES := [0, 1, 2]
	var total := TYPES.size() * HEALTH_STATES.size()
	var done  := 0
	for vt in TYPES:
		for hs in HEALTH_STATES:
			request_texture(vt, hs, func(_tex) -> void:
				done += 1
				if done == total and done_callback.is_valid():
					done_callback.call()
			)

func _process(_delta: float) -> void:
	if _pending.is_empty():
		set_process(false)
		return
	if _baking:
		return
	_baking = true
	_bake_job(_pending.pop_front())

func _bake_job(job: Dictionary) -> void:
	_ensure_viewport()
	for child in _root.get_children():
		child.queue_free()

	var vt:        String = job["vt"]
	var health:    int    = job["health"]
	var key:       String = job["key"]
	var callbacks: Array  = job["callbacks"]

	var r := _BakeRenderer.new()
	r.configure(vt, health)
	_root.add_child(r)
	r.queue_redraw()

	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame

	var img: Image = _vp.get_texture().get_image()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	r.queue_free()

	var tex: ImageTexture = null
	if img != null and not img.is_empty():
		tex = ImageTexture.create_from_image(img)
		_cache[key] = tex

	for cb in callbacks:
		if cb.is_valid():
			cb.call(tex)

	_baking = false
	set_process(not _pending.is_empty())

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _cache_key(vt: String, health: int) -> String:
	return "%s|%d" % [vt, health]
