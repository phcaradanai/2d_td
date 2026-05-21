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
		_ROUTER._dispatch_simple(self, visual_type, 16.0)

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
