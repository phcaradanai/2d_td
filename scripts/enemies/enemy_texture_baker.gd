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
		draw_set_transform(body_offset, 0.0, body_scale)
		_ROUTER._dispatch_simple(self, visual_type, 16.0)
		_draw_faux_3q_depth_cue()
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
				return Vector2(0.0, -2.4)
			"swarm", "fast_flyer", "flyer", "disruptor":
				return Vector2(0.0, -3.2)
			"fast", "runner", "hunter":
				return Vector2(0.0, -2.8)
			_:
				return Vector2(0.0, -2.5)

	func _get_faux_3q_body_scale() -> Vector2:
		match visual_type:
			"tank", "bulwark", "shieldbearer":
				return Vector2(1.0, 0.88)
			"swarm", "flyer", "fast_flyer", "armored_flyer", "disruptor":
				return Vector2(1.0, 0.92)
			"fast", "runner", "hunter":
				return Vector2(1.02, 0.90)
			_:
				return Vector2(1.0, 0.90)

	func _get_faux_3q_shadow_profile() -> Dictionary:
		match visual_type:
			"tank", "bulwark", "shieldbearer":
				return {"center": Vector2(0.0, 8.8), "rx": 15.5, "ry": 5.0, "alpha": 0.24}
			"swarm":
				return {"center": Vector2(0.0, 9.5), "rx": 16.0, "ry": 5.2, "alpha": 0.16}
			"flyer", "fast_flyer", "disruptor":
				return {"center": Vector2(0.0, 10.2), "rx": 12.0, "ry": 3.6, "alpha": 0.14}
			"armored_flyer":
				return {"center": Vector2(0.0, 10.0), "rx": 15.5, "ry": 4.5, "alpha": 0.16}
			"fast", "runner", "hunter":
				return {"center": Vector2(0.0, 8.4), "rx": 13.8, "ry": 4.0, "alpha": 0.20}
			_:
				return {"center": Vector2(0.0, 8.2), "rx": 12.8, "ry": 4.0, "alpha": 0.20}

	func _draw_faux_3q_depth_cue() -> void:
		var top_alpha := 0.075
		var lower_alpha := 0.105
		match visual_type:
			"tank", "bulwark", "shieldbearer", "armored_flyer":
				top_alpha = 0.060
				lower_alpha = 0.120
			"swarm", "fast", "runner", "fast_flyer":
				top_alpha = 0.085
				lower_alpha = 0.090
			"cloaked":
				top_alpha = 0.045
				lower_alpha = 0.075

		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.5, -10.5),
			Vector2(5.5, -11.0),
			Vector2(11.5, -3.0),
			Vector2(-5.5, -1.5),
		]), Color(1.0, 1.0, 1.0, top_alpha))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, 4.0),
			Vector2(12.0, 3.4),
			Vector2(8.0, 11.2),
			Vector2(-8.0, 11.6),
		]), Color(0.0, 0.0, 0.0, lower_alpha))

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
