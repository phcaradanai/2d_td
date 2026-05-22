extends Node2D
class_name TowerConstructionComponent

# Construction / upgrade VFX component.
# Draws a progressive "construction skeleton" mirroring the actual tower silhouette.
#
# Strategy:
#   draw_contour(self) draws the tower's natural black outline shapes onto this node.
#   The black outline IS visible as a dark skeleton against the colored glow behind it.
#   A colored primary glow (cyan build / gold upgrade) fills the tower AABB before the
#   contour, making the skeleton appear to "emerge" from the glow.
#   self_modulate controls the overall alpha of ALL draw calls on this node for each
#   contour pass — it is set once before queue_redraw() is processed, not mid-draw.
#
# Phases (build, cyan):
#   0.00 → 0.60  Scan: glow + contour ghost + scan line + sparks + ring
#   0.60 → 1.00  Materialize: alpha ramps to full, burst ring expands
#
# Phases (upgrade, gold):
#   0.00 → 0.38  Old tower dissolves (separate pass via _from_contour_alpha)
#   0.00 → 0.60  Same scan phase but sweep direction reversed
#   0.60 → 1.00  Same materialize phase
#
# Performance:
#   Contour script cached on start() — zero per-redraw lookup.
#   Redraw throttled to ~18 fps. Time-driven via get_ticks_msec().
#   No new nodes. No particles. No tweens per frame.

signal finished(mode: String, payload: Dictionary)

# ── State ──────────────────────────────────────────────────────────────────────
var active: bool = false
var mode: String = ""
var duration: float = 0.0
var remaining: float = 0.0
var payload: Dictionary = {}
var _redraw_timer: float = 0.0

# ── Cached contour scripts (set once in start()) ───────────────────────────────
var _contour_script       # target tower visual script
var _from_contour_script  # old tower visual script (upgrade dissolve)

# ── Proxy properties ───────────────────────────────────────────────────────────────────
# draw_contour(self) passes this node as 't'. Visual scripts read t.tree_tier,
# t.elements, t.visual_type directly (not via .get()). We mirror the parent
# tower's values here so those accesses don't crash.
var tree_tier: int = 1
var elements: Array = []
var visual_type: String = ""
var tower_id: String = ""
var idle_rotation: float = 0.0
var static_preview: bool = false
var preview_mode: bool = false
var is_static_preview: bool = false



# ── Timing ────────────────────────────────────────────────────────────────────
const REDRAW_INTERVAL := 0.055   # ~18 fps

# ── Palettes ──────────────────────────────────────────────────────────────────
const BUILD_PRIMARY   := Color(0.30, 0.95, 1.00, 1.0)
const BUILD_DIM       := Color(0.10, 0.55, 0.70, 1.0)
const UPGRADE_PRIMARY := Color(1.00, 0.72, 0.26, 1.0)
const UPGRADE_DIM     := Color(0.65, 0.40, 0.08, 1.0)

# ── Preloads ──────────────────────────────────────────────────────────────────
const TowerVisualRegistryScript = preload("res://scripts/towers/visuals/tower_visual_registry.gd")


# ══════════════════════════════════════════════════════════════════════════════
# Public API — same signature as before; callers unchanged
# ══════════════════════════════════════════════════════════════════════════════

func start(p_mode: String, p_duration: float, p_payload: Dictionary = {}) -> void:
	mode     = p_mode
	duration = maxf(0.01, p_duration)
	remaining = duration
	payload  = p_payload.duplicate(true)
	active   = true
	_redraw_timer = 0.0
	visible  = true
	set_process(true)
	_cache_contour_scripts()
	# Reset modulate in case it was left tinted by a previous session.
	self_modulate = Color.WHITE
	modulate      = Color.WHITE
	queue_redraw()


func cancel() -> void:
	active  = false
	mode    = ""
	payload.clear()
	_contour_script      = null
	_from_contour_script = null
	self_modulate = Color.WHITE
	modulate      = Color.WHITE
	visible = false
	set_process(false)
	queue_redraw()


func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(1.0 - (remaining / duration), 0.0, 1.0)


# ══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	z_index = 140
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		set_process(false)
		return
	remaining = maxf(0.0, remaining - delta)
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL

		# ── Set node alpha BEFORE queue_redraw so Godot applies it to the
		#    whole frame's draw commands for this node. ──────────────────────
		var p := progress()
		var is_upg := (mode == "upgrade")
		var primary: Color = UPGRADE_PRIMARY if is_upg else BUILD_PRIMARY

		# During scan phase: ramp from ghost to solid via self_modulate.
		# This controls how visible the contour AND all other draw calls are.
		if p < 0.60:
			self_modulate = Color(primary.r, primary.g, primary.b,
				lerpf(0.30, 0.75, p / 0.60))
		else:
			self_modulate = Color(primary.r, primary.g, primary.b,
				lerpf(0.75, 1.0, (p - 0.60) / 0.40))

		queue_redraw()

	if remaining > 0.0:
		return
	var finished_mode    := mode
	var finished_payload := payload.duplicate(true)
	cancel()
	finished.emit(finished_mode, finished_payload)


# ══════════════════════════════════════════════════════════════════════════════
# Contour cache
# ══════════════════════════════════════════════════════════════════════════════

func _cache_contour_scripts() -> void:
	_contour_script      = null
	_from_contour_script = null
	var by_id: Dictionary = TowerVisualRegistryScript.BY_ID

	# Copy proxy properties from parent tower so draw_contour(self) doesn't crash
	var tower := get_parent()
	if tower != null and is_instance_valid(tower):
		var tv = tower.get("tree_tier")
		tree_tier   = int(tv) if tv != null else 1
		var ev = tower.get("elements")
		elements    = ev.duplicate() if ev is Array else []
		var vv = tower.get("visual_type")
		visual_type = str(vv) if vv != null else ""
		var tid = tower.get("tower_id")
		tower_id = str(tid) if tid != null else ""

	# Target tower ID
	var draw_id := ""
	if mode == "upgrade":
		draw_id = str(payload.get("target_tower_id", ""))
	if draw_id.is_empty():
		if tower != null and is_instance_valid(tower):
			var tid = tower.get("tower_id")
			if tid != null:
				draw_id = str(tid)
	if not draw_id.is_empty() and by_id.has(draw_id):
		_contour_script = by_id[draw_id]

	# Old tower (upgrade only)
	if mode == "upgrade":
		var from_id := str(payload.get("from_tower_id", ""))
		if not from_id.is_empty() and by_id.has(from_id):
			_from_contour_script = by_id[from_id]


# ══════════════════════════════════════════════════════════════════════════════
# Draw
# ══════════════════════════════════════════════════════════════════════════════
#
# self_modulate is already set in _process() before queue_redraw() so that it
# applies uniformly to ALL draw calls below. We do NOT set it mid-draw.

func _draw() -> void:
	if not active:
		return

	var p      := progress()
	var is_upg := (mode == "upgrade")
	var primary: Color = UPGRADE_PRIMARY if is_upg else BUILD_PRIMARY

	# ── 1. Colored glow blob behind the tower skeleton ─────────────────────
	# Drawn first so the black contour shapes land on top of it, creating a
	# "glowing hologram wireframe" appearance.
	draw_circle(Vector2.ZERO, 26.0, Color(primary.r, primary.g, primary.b, 0.18))
	draw_circle(Vector2.ZERO, 18.0, Color(primary.r, primary.g, primary.b, 0.10))

	# ── 2. Tower contour skeleton ──────────────────────────────────────────
	# The visual script's draw_contour() uses TowerVisualDrawUtils which draws
	# TOWER_CONTOUR_COLOR (nearly-black, 0.78 alpha) shapes. These land on top
	# of the colored glow, forming a visible dark-on-color wireframe skeleton.
	# Overall alpha is controlled by self_modulate set in _process().
	if _contour_script != null:
		_contour_script.draw_contour(self)

	# ── 3. Old-tower ghost (upgrade dissolve, separate alpha ramp) ─────────
	# We draw a faint overlay of the old tower shape during the first 38% of
	# the upgrade to give a "morphing" feel. We approximate its alpha with a
	# bright colored overlay arc (not the black contour) to avoid z-fighting.
	if is_upg and p < 0.38:
		var ghost_a := lerpf(0.35, 0.0, p / 0.38)
		if _from_contour_script != null:
			# Draw a muted version: use draw_set_transform color trick —
			# instead of tinting the contour (not possible mid-draw),
			# we draw a soft fill circle that represents the "fading ghost volume."
			draw_circle(Vector2.ZERO, 20.0, Color(primary.r, primary.g, primary.b, ghost_a * 0.5))
			# And a thin ring outline where the old tower perimeter was.
			draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24,
				Color(primary.r, primary.g, primary.b, ghost_a), 1.5, true)



	# ── 8. Assembly burst ring (materialize phase) ──────────────────────────
	if p > 0.62:
		var bt := (p - 0.62) / 0.38
		draw_arc(Vector2.ZERO, lerpf(10.0, 44.0, bt), 0.0, TAU, 36,
			Color(primary.r, primary.g, primary.b, lerpf(0.80, 0.0, bt)), 2.5, true)

	# ── 9. Completion flash ─────────────────────────────────────────────────
	if p > 0.88:
		var ft := (p - 0.88) / 0.12
		draw_circle(Vector2.ZERO, lerpf(20.0, 38.0, ft),
			Color(primary.r, primary.g, primary.b, lerpf(0.40, 0.0, ft)))


# ── Proxy method for visuals ──────────────────────────────────────────────────
func _get_tower_visual_family() -> String:
	var id := tower_id.to_lower()
	if id.begins_with("ice_"):
		return "ice"
	if id.begins_with("polar_"):
		return "polar"
	if id.begins_with("light_") or id == "pure_light":
		return "light"
	if id.begins_with("life_"):
		return "life"
	if id.begins_with("well_"):
		return "well"
	if id.begins_with("tidal_"):
		return "tidal"
	if id.begins_with("enchantment_"):
		return "enchantment"
	if id.begins_with("electricity_"):
		return "electricity"
	if id.begins_with("jinx_"):
		return "jinx"
	if id.begins_with("periodic_"):
		return "periodic"
	if id.begins_with("disease_"):
		return "disease"
	if id.begins_with("mushroom_"):
		return "mushroom"
	return visual_type
