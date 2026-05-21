## TowerTextureBaker — autoload that bakes tower procedural-draw visuals into
## cached ImageTextures.  Call request_textures(); the callback fires when ready.
##
## Each unique (visual_type + elements + tier) combination is baked once per
## session and stored in a static cache.  Results survive scene changes.
##
## Baking is deferred: one job is processed per frame so the game stays
## responsive.  Towers show their procedural draw for 1-2 frames then switch.
extends Node

# ── Cache (survives scene changes) ──────────────────────────────────────────
var _cache: Dictionary = {}          # key -> {base: ImageTexture, turret: ImageTexture}
var _pending: Array = []             # Array[Dictionary]
var _baking: bool = false

# ── Viewport sizing ──────────────────────────────────────────────────────────
const BAKE_SIZE    := 256            # Viewport pixels — large enough for ±64 world-px (sniper/rail_laser tier 3 reach ~63)
const BAKE_ZOOM    := 2.0            # Camera zoom so visual fills the viewport

# ── Renderer class ────────────────────────────────────────────────────────────
# Full interface mirror of tower.gd / RealTowerVisualPreview so every
# tower_visual_*.gd draw function can call any method it needs.

enum DrawMode { BASE, TURRET }

class _BakeRenderer extends Node2D:
	var draw_mode:        int            = DrawMode.BASE
	var tower_id:         String         = ""
	var visual_type:      String         = "basic"
	var tree_tier:        int            = 1
	var elements:         Array[String]  = []
	var attack_range:     float          = 160.0
	var is_selected:      bool           = false
	var is_hovered:       bool           = false
	var hovered:          bool           = false
	var is_catalog_preview: bool         = true
	var idle_rotation:    float          = 0.0

	const TVR = preload("res://scripts/towers/tower_visual_renderer.gd")

	func configure(p_id: String, p_visual: String, p_elements: Array[String], p_tier: int) -> void:
		tower_id    = p_id
		visual_type = p_visual
		elements    = p_elements.duplicate()
		tree_tier   = p_tier

	func _draw() -> void:
		if draw_mode == DrawMode.BASE:
			TVR.draw_base_plate(self)
		else:
			TVR.draw_turret_contour(self)
			TVR.draw_turret_top(self)

	func mark_visual_dirty() -> void:
		queue_redraw()

	func get_fire_origin() -> Vector2:
		return global_position + _get_visual_muzzle_local_position().rotated(global_rotation) * global_scale

	func _get_all_element_colors() -> Array[Color]:
		var out: Array[Color] = []
		for el in elements:
			out.append(_get_element_color(el))
		return out

	func _get_element_color(el: String) -> Color:
		match el.to_lower():
			"light":             return Color(1.0, 0.9, 0.25)
			"darkness", "dark":  return Color(0.6, 0.2, 0.9)
			"water":             return Color(0.2, 0.55, 1.0)
			"fire":              return Color(1.0, 0.35, 0.1)
			"nature":            return Color(0.25, 0.85, 0.3)
			"earth":             return Color(0.65, 0.42, 0.2)
		return Color(0.45, 0.92, 1.0)

	func _get_tower_color() -> Color:
		if not elements.is_empty():
			return _get_element_color(elements[0])
		match visual_type:
			"basic":     return Color(0.2, 0.8, 1.0)
			"rapid":     return Color(0.0, 1.0, 0.8)
			"cannon":    return Color(1.0, 0.4, 0.1)
			"slow":      return Color(0.6, 1.0, 1.0)
			"sniper":    return Color(0.1, 0.5, 1.0)
			"lightning": return Color(0.5, 0.4, 1.0)
			"trickery":  return Color(0.75, 0.45, 1.0)
		return Color.WHITE

	func _get_tower_visual_family() -> String:
		var id := tower_id.to_lower()
		if id.begins_with("ice_"):          return "ice"
		if id.begins_with("polar_"):        return "polar"
		if id.begins_with("light_") or id == "pure_light": return "light"
		if id.begins_with("life_"):         return "life"
		if id.begins_with("well_"):         return "well"
		if id.begins_with("tidal_"):        return "tidal"
		if id.begins_with("enchantment_"):  return "enchantment"
		if id.begins_with("electricity_"):  return "electricity"
		if id.begins_with("jinx_"):         return "jinx"
		if id.begins_with("periodic_"):     return "periodic"
		if id.begins_with("disease_"):      return "disease"
		if id.begins_with("mushroom_"):     return "mushroom"
		return visual_type

	func _get_visual_muzzle_local_position() -> Vector2:
		var lvl := tree_tier
		match visual_type:
			"basic":                        return Vector2(26 + lvl * 4, 0)
			"rapid":                        return Vector2(22 + lvl * 2, 0)
			"cannon":                       return Vector2(18 + lvl * 4, 0)
			"sniper":                       return Vector2(42 + lvl * 6, 0)
			"forge_anvil":                  return Vector2(28 + lvl * 2, 0)
			"rail_laser":                   return Vector2(42 + lvl * 5, 0)
			"hydro_cannon", "dual_nozzle":  return Vector2(28 + lvl * 3, 0)
			"furnace", "bio_vine", "steam_boiler": return Vector2(24 + lvl * 2, 0)
		return Vector2(28, 0)

# ── SubViewport management ───────────────────────────────────────────────────

var _vp: SubViewport      = null
var _renderer_root: Node2D = null
var _cam: Camera2D         = null

func _ready() -> void:
	name = "TowerTextureBaker"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)   # only active while baking

func _ensure_viewport() -> void:
	if _vp != null and is_instance_valid(_vp):
		return
	_vp = SubViewport.new()
	_vp.name            = "BakerViewport"
	_vp.size            = Vector2i(BAKE_SIZE, BAKE_SIZE)
	_vp.transparent_bg  = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.render_target_clear_mode  = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_vp)

	_cam = Camera2D.new()
	_cam.zoom    = Vector2(BAKE_ZOOM, BAKE_ZOOM)
	_cam.enabled = true
	_vp.add_child(_cam)
	_cam.make_current()

	_renderer_root = Node2D.new()
	_renderer_root.name = "RendererRoot"
	_vp.add_child(_renderer_root)

# ── Public API ───────────────────────────────────────────────────────────────

## Request base+turret textures.  `callback(result: Dictionary)` fires with:
##   result = { "base": ImageTexture, "turret": ImageTexture }
## or result = {} on failure (tower should keep procedural draw).
func request_textures(
		tower_id: String,
		visual_type: String,
		elements: Array[String],
		tier: int,
		callback: Callable
) -> void:
	var key := _cache_key(tower_id, visual_type, elements, tier)
	if _cache.has(key):
		callback.call(_cache[key])
		return
	# Deduplicate pending requests for the same key.
	for job in _pending:
		if job["key"] == key:
			job["callbacks"].append(callback)
			return
	_pending.append({
		"key":       key,
		"tower_id":  tower_id,
		"visual":    visual_type,
		"elements":  elements.duplicate(),
		"tier":      tier,
		"callbacks": [callback],
	})
	set_process(true)

func _process(_delta: float) -> void:
	if _pending.is_empty():
		set_process(false)
		return
	if _baking:
		return
	_baking = true
	var job: Dictionary = _pending.pop_front()
	_bake_job(job)

func _bake_job(job: Dictionary) -> void:
	_ensure_viewport()

	# Clear previous renderer children.
	for child in _renderer_root.get_children():
		child.queue_free()

	var tower_id:   String        = job["tower_id"]
	var visual:     String        = job["visual"]
	var elements:   Array[String] = job["elements"]
	var tier:       int           = job["tier"]
	var callbacks:  Array         = job["callbacks"]
	var cache_key:  String        = job["key"]

	# Bake base first, then turret.
	_bake_layer(DrawMode.BASE, tower_id, visual, elements, tier, func(base_tex: ImageTexture) -> void:
		_bake_layer(DrawMode.TURRET, tower_id, visual, elements, tier, func(turret_tex: ImageTexture) -> void:
			var result := {}
			if base_tex != null:
				result["base"] = base_tex
			if turret_tex != null:
				result["turret"] = turret_tex
			if not result.is_empty():
				_cache[cache_key] = result
			for cb in callbacks:
				if cb.is_valid():
					cb.call(result)
			_baking = false
			set_process(not _pending.is_empty())
		)
	)

func _bake_layer(
		mode: int,
		tower_id: String,
		visual: String,
		elements: Array[String],
		tier: int,
		done: Callable
) -> void:
	# Clear renderer root.
	for child in _renderer_root.get_children():
		child.queue_free()
	await get_tree().process_frame   # let queue_free settle

	var r := _BakeRenderer.new()
	r.draw_mode = mode
	r.configure(tower_id, visual, elements, tier)
	_renderer_root.add_child(r)
	r.queue_redraw()

	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame   # render
	await get_tree().process_frame   # ensure capture is ready

	var img: Image = _vp.get_texture().get_image()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var tex: ImageTexture = null
	if img != null and not img.is_empty():
		tex = ImageTexture.create_from_image(img)

	# Remove renderer.
	r.queue_free()
	done.call(tex)

# ── Helpers ──────────────────────────────────────────────────────────────────

static func _cache_key(tower_id: String, visual_type: String, elements: Array[String], tier: int) -> String:
	var sorted := elements.duplicate()
	sorted.sort()
	return "%s|%s|%s|%d" % [tower_id, visual_type, "+".join(sorted), tier]
