## AttackVFXFrameBaker — bakes VFX draw-API animations into ImageTexture frame arrays.
## Uses a SubViewport to render N frames at different elapsed values, then caches them.
## Bakes in WHITE palette so callers tint via modulate — cache stays O(tower_count).
extends Node

const N_FRAMES: int = 8
const BAKE_W: int = 160
const BAKE_H: int = 56

## tower_id → Array[ImageTexture]
var _cache: Dictionary = {}
var _queue: Array[Dictionary] = []
var _baking: bool = false
var _viewport: SubViewport = null

func _ready() -> void:
	name = "AttackVFXFrameBaker"
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(BAKE_W, BAKE_H)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

func has_frames(tower_id: String) -> bool:
	var frames = _cache.get(tower_id, null)
	return frames != null and (frames as Array).size() > 0

func get_frames(tower_id: String) -> Array:
	return _cache.get(tower_id, [])

## Request bake for tower_id. Calls on_done(tower_id, frames) when done (or immediately
## if already cached). Safe to call repeatedly — deduplicates queue entries.
func request_bake(tower_id: String, script: GDScript, on_done: Callable = Callable()) -> void:
	if has_frames(tower_id):
		if on_done.is_valid():
			on_done.call(tower_id, _cache[tower_id])
		return
	for item in _queue:
		if item["tower_id"] == tower_id:
			if on_done.is_valid():
				(item["cbs"] as Array).append(on_done)
			return
	var cbs: Array[Callable] = []
	if on_done.is_valid():
		cbs.append(on_done)
	_queue.append({"tower_id": tower_id, "script": script, "cbs": cbs})
	if not _baking:
		_run_queue()

func _run_queue() -> void:
	_baking = true
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		await _bake_one(item)
	_baking = false

func _bake_one(item: Dictionary) -> void:
	var tower_id: String = item["tower_id"]
	var script: GDScript = item["script"]
	var frames: Array[ImageTexture] = []

	var node: Node2D = script.new() as Node2D
	node.set_meta("pooled", true)
	node.set("static_mode", false)
	_viewport.add_child(node)
	node.set_process(false)
	node.set_physics_process(false)
	# Place at left-center so the VFX trail travels rightward across the viewport.
	node.position = Vector2(0.0, BAKE_H * 0.5)
	node.rotation = 0.0
	node.set("palette_primary", Color.WHITE)
	node.set("palette_secondary", Color(0.88, 0.88, 1.0, 1.0))
	node.set("distance", float(BAKE_W) * 0.88)
	if node.has_method("configure"):
		node.configure({})
	var lifetime: float = maxf(0.06, float(node.get("lifetime") if "lifetime" in node else 0.12))

	for i in range(N_FRAMES):
		# Clamp slightly below 1.0 so alpha-at-end doesn't collapse circles to zero radius.
		var t := float(i) / float(N_FRAMES - 1) * 0.97
		node.set("elapsed", t * lifetime)
		node.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := _viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			frames.append(ImageTexture.create_from_image(img))

	node.queue_free()
	_cache[tower_id] = frames
	for cb: Callable in item["cbs"]:
		if cb.is_valid():
			cb.call(tower_id, frames)
