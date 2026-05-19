# Tower Attack VFX — Per-ID Identity System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a 1:1 tower-ID → attack VFX system under `scripts/vfx/` with a custom T1 visual identity per tower family and T2/T3 extension files, replacing the visual_type-keyed dispatch in the existing `TowerAttackVFX`.

**Architecture:** 5 core files (base class, service, registry, pool, status) + 50 T1/special VFX files with full draw implementations + 82 T2/T3 extension files. `tower_attack_vfx.gd` is updated to check the new registry by `tower_id` first, then falls back to the legacy `visual_type` map for unknown towers. All drawing uses `_draw()` primitives — no particles, no scenes, no sprites. Every VFX node auto-expires and self-frees.

**Tech Stack:** GDScript 4.6, Godot 2D `draw_line / draw_circle / draw_arc / draw_polyline / draw_colored_polygon`, `BaseTowerAttackVFX` base class, static `_active_count` budget cap (MAX 60).

---

## Do NOT change

- Tower stats, damage, fire rate, range, targeting, upgrade tree, unlock rules, balance
- Wave logic, enemy logic, save data
- `tower.gd` gameplay code (only the VFX call site at line 1308 changes)
- Existing `attack_vfx.gd` and `tower_attack_vfx.gd` (only add fallback delegation in the latter)

---

## File Map

| Status | File | Responsibility |
|---|---|---|
| **Create dir** | `scripts/vfx/core/` | Core infrastructure |
| **Create dir** | `scripts/vfx/towers/` | Per-tower VFX files |
| **Create dir** | `scripts/vfx/status/` | Status marker VFX |
| **Create** | `scripts/vfx/core/base_tower_attack_vfx.gd` | Base class: lifecycle + all draw helpers |
| **Create** | `scripts/vfx/core/tower_attack_vfx_service.gd` | Static spawn entry point |
| **Create** | `scripts/vfx/core/tower_attack_vfx_registry.gd` | tower_id → GDScript mapping (132 entries) |
| **Create** | `scripts/vfx/core/tower_attack_vfx_pool.gd` | Budget cap wrapper |
| **Create** | `scripts/vfx/status/status_marker_vfx.gd` | Status effect draw on enemies |
| **Create** | `scripts/vfx/towers/*_t1_attack_vfx.gd` | 50 T1/special VFX files (custom draw) |
| **Create** | `scripts/vfx/towers/*_t2_attack_vfx.gd` | 41 T2 files (extend T1) |
| **Create** | `scripts/vfx/towers/*_t3_attack_vfx.gd` | 41 T3 files (extend T1) |
| **Modify** | `scripts/effects/tower_attack_vfx.gd` | Delegate to new service when tower_id matched |

---

## Task 1: Core Infrastructure — 5 files

**Files:**
- Create: `scripts/vfx/core/base_tower_attack_vfx.gd`
- Create: `scripts/vfx/core/tower_attack_vfx_service.gd`
- Create: `scripts/vfx/core/tower_attack_vfx_registry.gd`
- Create: `scripts/vfx/core/tower_attack_vfx_pool.gd`
- Create: `scripts/vfx/status/status_marker_vfx.gd`

- [ ] **Step 1: Create directories**

```bash
mkdir -p "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/core"
mkdir -p "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers"
mkdir -p "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/status"
```

- [ ] **Step 2: Create `scripts/vfx/core/base_tower_attack_vfx.gd`**

This is the foundation. It handles lifecycle (elapsed timer, queue_free, _active_count) and
provides ALL draw helpers that T1 files call. Every VFX file in `scripts/vfx/towers/` extends this.

```gdscript
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
```

- [ ] **Step 3: Create `scripts/vfx/core/tower_attack_vfx_pool.gd`**

```gdscript
## TowerAttackVFXPool — manages the global VFX budget for new per-id VFX nodes.
## Actual node pooling is deferred; budget enforcement is the priority.
class_name TowerAttackVFXPool
extends RefCounted

const MAX_ACTIVE: int = 60

static func can_spawn() -> bool:
	return BaseTowerAttackVFX._active_count < MAX_ACTIVE

static func active_count() -> int:
	return BaseTowerAttackVFX._active_count
```

- [ ] **Step 4: Create `scripts/vfx/core/tower_attack_vfx_service.gd`**

```gdscript
## TowerAttackVFXService — resolves tower_id → VFX script and spawns the node.
## Called from the updated TowerAttackVFX.spawn_attack_vfx().
class_name TowerAttackVFXService
extends RefCounted

static func spawn(tower: Node2D, target: Node2D) -> void:
	if not is_instance_valid(tower) or not is_instance_valid(target):
		return
	if not TowerAttackVFXPool.can_spawn():
		return

	var container: Node = tower.get_tree().current_scene \
		.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container:
		container = tower.get_tree().current_scene
	if not container:
		return

	var origin: Vector2 = tower.get_fire_origin() \
		if tower.has_method("get_fire_origin") else tower.global_position
	var tgt_pos: Vector2 = target.get_hit_origin() \
		if target.has_method("get_hit_origin") else target.global_position

	var tower_id: String = str(tower.get("tower_id")) if "tower_id" in tower else ""
	var script: GDScript = TowerAttackVFXRegistry.get_script(tower_id)
	if script == null:
		return  # caller falls back to legacy system

	var color: Color = tower._get_tower_color() \
		if tower.has_method("_get_tower_color") else Color.WHITE

	var node: Node2D = Node2D.new()
	node.set_script(script)
	container.add_child(node)
	node.setup(origin, tgt_pos, color)
	node.configure({})
```

- [ ] **Step 5: Create `scripts/vfx/core/tower_attack_vfx_registry.gd` (shell — 132 entries added in Task 10)**

```gdscript
## TowerAttackVFXRegistry — maps every tower_id to its VFX GDScript.
## Populated with preload() entries in Task 10 after all tower files exist.
class_name TowerAttackVFXRegistry
extends RefCounted

## Filled in Task 10.
const _SCRIPTS: Dictionary = {}

static func get_script(tower_id: String) -> GDScript:
	return _SCRIPTS.get(tower_id, null)
```

- [ ] **Step 6: Create `scripts/vfx/status/status_marker_vfx.gd`**

```gdscript
## StatusMarkerVFX — draws compact status icons on enemy creeps.
## One node is attached per creep (via EnemyVFXController or similar).
## Reuses the same node for all status updates — no per-hit spawning.
## Draws in LOCAL space above the enemy body.
extends Node2D
class_name StatusMarkerVFX

const ICON_R  := 5.5
const ICON_GAP := 13.0
const ICON_Y  := -28.0

const C_SLOW   := Color(0.50, 0.95, 1.00, 0.80)
const C_ROOT   := Color(0.15, 0.90, 0.45, 0.80)
const C_BURN   := Color(1.00, 0.32, 0.05, 0.80)
const C_POISON := Color(0.52, 0.12, 0.88, 0.80)
const C_SHOCK  := Color(0.65, 0.55, 1.00, 0.80)
const C_VULN   := Color(0.80, 0.08, 0.88, 0.80)

var owner_enemy: Node = null
var _t: float = 0.0
const _REDRAW_INTERVAL := 0.20
var _redraw_timer: float = 0.0

func setup(enemy: Node) -> void:
	owner_enemy = enemy
	z_index = 20
	add_to_group("status_vfx")
	if enemy.has_signal("enemy_modifier_changed"):
		if not enemy.enemy_modifier_changed.is_connected(_on_modifier_changed):
			enemy.enemy_modifier_changed.connect(_on_modifier_changed)

func _on_modifier_changed(_en: Node, _key: String, _val: Variant) -> void:
	_redraw_timer = 0.0
	visible = _has_any_active()
	queue_redraw()

func _process(delta: float) -> void:
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		queue_free()
		return
	_t += delta * TAU
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = _REDRAW_INTERVAL
		visible = _has_any_active()
	if visible:
		queue_redraw()

func _has_any_active() -> bool:
	if not is_instance_valid(owner_enemy):
		return false
	return (
		float(owner_enemy.get("slow_remaining")) > 0.0
		or float(owner_enemy.get("root_remaining")) > 0.0
		or float(owner_enemy.get("vulnerability_remaining")) > 0.0
		or float(owner_enemy.get("armor_reduction_remaining")) > 0.0
		or not (owner_enemy.get("active_dot_effects") as Array).is_empty()
	)

func _draw() -> void:
	if not is_instance_valid(owner_enemy):
		return
	var states := _read_states()
	var active: Array[Color] = []
	if states["slow"]:   active.append(C_SLOW)
	if states["root"]:   active.append(C_ROOT)
	if states["burn"]:   active.append(C_BURN)
	if states["poison"]: active.append(C_POISON)
	if states["vuln"]:   active.append(C_VULN)
	var total := active.size()
	if total == 0:
		return
	var start_x := -(float(total - 1) * ICON_GAP) * 0.5
	for i in range(total):
		var cx := start_x + float(i) * ICON_GAP
		var pos := Vector2(cx, ICON_Y)
		var col: Color = active[i]
		var pulse := (sin(_t * 1.8 + float(i) * 1.1) * 0.5 + 0.5) * 0.25
		draw_circle(pos, ICON_R + pulse, Color(col.r, col.g, col.b, 0.18))
		draw_arc(pos, ICON_R, 0.0, TAU, 12, col, 1.4, true)
		draw_circle(pos, 2.2, Color(1.0, 1.0, 1.0, col.a * 0.72))

func _read_states() -> Dictionary:
	var s := {
		"slow": false, "root": false, "burn": false, "poison": false, "vuln": false
	}
	if not is_instance_valid(owner_enemy):
		return s
	s["slow"] = float(owner_enemy.get("slow_remaining")) > 0.0
	s["root"] = float(owner_enemy.get("root_remaining")) > 0.0
	s["vuln"] = float(owner_enemy.get("vulnerability_remaining")) > 0.0 \
		or float(owner_enemy.get("armor_reduction_remaining")) > 0.0
	var dots = owner_enemy.get("active_dot_effects")
	if dots is Array:
		for d in dots:
			if not d is Dictionary: continue
			match str(d.get("attack_type", "dot")).to_lower():
				"fire": s["burn"] = true
				_:      s["poison"] = true
	return s
```

- [ ] **Step 7: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add \
    "scripts/vfx/core/base_tower_attack_vfx.gd" \
    "scripts/vfx/core/tower_attack_vfx_pool.gd" \
    "scripts/vfx/core/tower_attack_vfx_service.gd" \
    "scripts/vfx/core/tower_attack_vfx_registry.gd" \
    "scripts/vfx/status/status_marker_vfx.gd"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: add VFX core infrastructure — base class, service, registry shell, pool, status"
```

---

## Task 2: T1 VFX — Fire / Flame / Gunpowder / Quaker / Vapor family

**Files:** Create 7 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/fire_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(1.0, 0.30, 0.05)
	palette_secondary = Color(1.0, 0.70, 0.10)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
```

- [ ] **Step 2: Create `scripts/vfx/towers/flame_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(1.0, 0.35, 0.05)
	palette_secondary = Color(1.0, 0.65, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_flame_cone(t, a, lend)
```

- [ ] **Step 3: Create `scripts/vfx/towers/flamethrower_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(1.0, 0.22, 0.00)
	palette_secondary = Color(1.0, 0.50, 0.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_flame_cone(t, a, lend)
```

- [ ] **Step 4: Create `scripts/vfx/towers/gunpowder_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.50, 0.45, 0.35)
	palette_secondary = Color(1.0, 0.75, 0.30)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
```

- [ ] **Step 5: Create `scripts/vfx/towers/quaker_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.65, 0.35, 0.10)
	palette_secondary = Color(0.85, 0.55, 0.20)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_earth_impact(t, a)
```

- [ ] **Step 6: Create `scripts/vfx/towers/vapor_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.75, 0.85, 1.00)
	palette_secondary = Color(0.55, 0.70, 0.90)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_steam_burst(t, a, lend)
```

- [ ] **Step 7: Create `scripts/vfx/towers/pure_fire_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(1.0, 0.20, 0.00)
	palette_secondary = Color(1.0, 0.55, 0.05)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_flame_cone(t, a, lend)
```

- [ ] **Step 8: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — fire/flame/gunpowder/quaker/vapor family"
```

---

## Task 3: T1 VFX — Electric / Chain / Hail / Windstorm / Periodic family

**Files:** Create 5 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/electricity_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.15
	palette_primary  = Color(0.50, 0.40, 1.00)
	palette_secondary = Color(0.90, 0.80, 1.00)
func _draw_vfx(_t: float, a: float, lend: Vector2) -> void:
	_h_electric_arc(a, lend, true)
```

- [ ] **Step 2: Create `scripts/vfx/towers/jinx_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.15
	palette_primary  = Color(0.90, 0.20, 1.00)
	palette_secondary = Color(1.00, 0.50, 1.00)
func _draw_vfx(_t: float, a: float, lend: Vector2) -> void:
	_h_electric_arc(a, lend, true)
```

- [ ] **Step 3: Create `scripts/vfx/towers/hail_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.15
	palette_primary  = Color(0.65, 0.85, 1.00)
	palette_secondary = Color(0.90, 0.95, 1.00)
func _draw_vfx(_t: float, a: float, lend: Vector2) -> void:
	_h_electric_arc(a, lend, false)
```

- [ ] **Step 4: Create `scripts/vfx/towers/windstorm_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.65, 0.88, 1.00)
	palette_secondary = Color(0.85, 0.95, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_steam_burst(t, a, lend)
```

- [ ] **Step 5: Create `scripts/vfx/towers/periodic_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.15
	palette_primary  = Color(0.85, 0.95, 1.00)
	palette_secondary = Color(1.00, 1.00, 1.00)
func _draw_vfx(_t: float, a: float, lend: Vector2) -> void:
	_h_electric_arc(a, lend, true)
```

- [ ] **Step 6: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — electricity/jinx/hail/windstorm/periodic family"
```

---

## Task 4: T1 VFX — Ice / Water / Hydro / Polar / Muck / Drowning / Tidal / Pure-Water family

**Files:** Create 8 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/ice_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.55, 0.90, 1.00)
	palette_secondary = Color(0.85, 0.95, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_frost_beam(t, a, lend)
```

- [ ] **Step 2: Create `scripts/vfx/towers/water_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(0.20, 0.60, 1.00)
	palette_secondary = Color(0.40, 0.80, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_water_jet(t, a, lend)
```

- [ ] **Step 3: Create `scripts/vfx/towers/hydro_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(0.10, 0.55, 1.00)
	palette_secondary = Color(0.30, 0.80, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_water_jet(t, a, lend)
```

- [ ] **Step 4: Create `scripts/vfx/towers/polar_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.70, 0.90, 1.00)
	palette_secondary = Color(1.00, 1.00, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_frost_beam(t, a, lend)
```

- [ ] **Step 5: Create `scripts/vfx/towers/muck_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.35, 0.28, 0.20)
	palette_secondary = Color(0.50, 0.40, 0.25)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
```

- [ ] **Step 6: Create `scripts/vfx/towers/drowning_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.25, 0.35, 0.85)
	palette_secondary = Color(0.10, 0.50, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_shadow_lash(t, a, lend)
```

- [ ] **Step 7: Create `scripts/vfx/towers/tidal_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.35, 0.85, 1.00)
	palette_secondary = Color(0.70, 0.95, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_water_jet(t, a, lend)
```

- [ ] **Step 8: Create `scripts/vfx/towers/pure_water_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(0.20, 0.70, 1.00)
	palette_secondary = Color(0.55, 0.90, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_frost_beam(t, a, lend)
```

- [ ] **Step 9: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — ice/water/hydro/polar/muck/drowning/tidal/pure-water family"
```

---

## Task 5: T1 VFX — Nature / Vine / Roots / Mushroom / Disease / Poison / Corrosion / Life / Pure-Nature

**Files:** Create 9 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/nature_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.22, 0.95, 0.34)
	palette_secondary = Color(0.45, 1.00, 0.30)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_nature_vine(t, a, lend)
```

- [ ] **Step 2: Create `scripts/vfx/towers/roots_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.25
	palette_primary  = Color(0.30, 0.75, 0.20)
	palette_secondary = Color(0.15, 0.55, 0.08)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_nature_vine(t, a, lend)
```

- [ ] **Step 3: Create `scripts/vfx/towers/mushroom_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.65, 0.50, 0.85)
	palette_secondary = Color(0.45, 0.28, 0.70)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_spore_puff(t, a, lend)
```

- [ ] **Step 4: Create `scripts/vfx/towers/disease_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.42, 1.00, 0.22)
	palette_secondary = Color(0.20, 0.70, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_spore_puff(t, a, lend)
```

- [ ] **Step 5: Create `scripts/vfx/towers/poison_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.52, 0.12, 0.88)
	palette_secondary = Color(0.75, 0.25, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_poison_spray(t, a, lend)
```

- [ ] **Step 6: Create `scripts/vfx/towers/corrosion_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.55, 1.00, 0.20)
	palette_secondary = Color(0.30, 0.80, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_acid_splash(t, a, lend)
```

- [ ] **Step 7: Create `scripts/vfx/towers/life_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.45, 1.00, 0.60)
	palette_secondary = Color(0.80, 1.00, 0.85)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_support_pulse(t, a)
```

- [ ] **Step 8: Create `scripts/vfx/towers/pure_nature_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.12, 0.85, 0.25)
	palette_secondary = Color(0.35, 1.00, 0.45)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_nature_vine(t, a, lend)
```

- [ ] **Step 9: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — nature/roots/mushroom/disease/poison/corrosion/life/pure-nature"
```

---

## Task 6: T1 VFX — Laser / Light / Quark / Gold / Nova / Impulse / Zealot / Pure-Light family

**Files:** Create 8 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/laser_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.10
	palette_primary  = Color(0.10, 0.90, 1.00)
	palette_secondary = Color(1.00, 1.00, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_precision_beam(t, a, lend)
```

- [ ] **Step 2: Create `scripts/vfx/towers/light_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(1.00, 0.92, 0.25)
	palette_secondary = Color(1.00, 1.00, 0.80)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_precision_beam(t, a, lend)
```

- [ ] **Step 3: Create `scripts/vfx/towers/quark_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.10
	palette_primary  = Color(0.35, 0.85, 1.00)
	palette_secondary = Color(0.65, 0.95, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_precision_beam(t, a, lend)
```

- [ ] **Step 4: Create `scripts/vfx/towers/gold_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(1.00, 0.82, 0.10)
	palette_secondary = Color(1.00, 0.95, 0.50)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_light_pulse(t, a, lend)
```

- [ ] **Step 5: Create `scripts/vfx/towers/nova_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.16
	palette_primary  = Color(1.00, 0.65, 0.25)
	palette_secondary = Color(1.00, 0.85, 0.55)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_light_pulse(t, a, lend)
```

- [ ] **Step 6: Create `scripts/vfx/towers/impulse_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(0.55, 0.70, 1.00)
	palette_secondary = Color(1.00, 0.60, 0.20)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_rapid_tracer(t, a, lend)
```

- [ ] **Step 7: Create `scripts/vfx/towers/zealot_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(0.10, 0.80, 1.00)
	palette_secondary = Color(1.00, 0.30, 0.10)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_rapid_tracer(t, a, lend)
```

- [ ] **Step 8: Create `scripts/vfx/towers/pure_light_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.10
	palette_primary  = Color(1.00, 0.95, 0.55)
	palette_secondary = Color(1.00, 1.00, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_precision_beam(t, a, lend)
```

- [ ] **Step 9: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — laser/light/quark/gold/nova/impulse/zealot/pure-light"
```

---

## Task 7: T1 VFX — Void / Dark / Magic / Voodoo / Oblivion / Trickery / Enchantment / Pure-Darkness

**Files:** Create 8 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/darkness_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.45, 0.10, 0.85)
	palette_secondary = Color(0.80, 0.20, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
```

- [ ] **Step 2: Create `scripts/vfx/towers/magic_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.85, 0.15, 0.55)
	palette_secondary = Color(1.00, 0.35, 0.75)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
```

- [ ] **Step 3: Create `scripts/vfx/towers/voodoo_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.75, 0.15, 0.35)
	palette_secondary = Color(1.00, 0.35, 0.55)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
```

- [ ] **Step 4: Create `scripts/vfx/towers/oblivion_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.22
	palette_primary  = Color(0.65, 0.20, 1.00)
	palette_secondary = Color(0.90, 0.50, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
```

- [ ] **Step 5: Create `scripts/vfx/towers/trickery_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.18
	palette_primary  = Color(0.75, 0.45, 1.00)
	palette_secondary = Color(0.45, 0.08, 0.75)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_trickery_shimmer(t, a, lend)
```

- [ ] **Step 6: Create `scripts/vfx/towers/enchantment_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.26
	palette_primary  = Color(0.55, 1.00, 0.65)
	palette_secondary = Color(1.00, 0.95, 0.60)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_magic_enchant(t, a, lend)
```

- [ ] **Step 7: Create `scripts/vfx/towers/pure_darkness_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.26
	palette_primary  = Color(0.35, 0.05, 0.65)
	palette_secondary = Color(0.60, 0.10, 0.90)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_void_rift(t, a, lend)
```

- [ ] **Step 8: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — darkness/magic/voodoo/oblivion/trickery/enchantment/pure-darkness"
```

---

## Task 8: T1 VFX — Support / Earth / Cannon / Flesh Golem / Pure-Earth + Basic + Neutral + Flesh

**Files:** Create 10 files in `scripts/vfx/towers/`

- [ ] **Step 1: Create `scripts/vfx/towers/blacksmith_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(1.00, 0.55, 0.10)
	palette_secondary = Color(1.00, 0.85, 0.30)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_support_pulse(t, a)
```

- [ ] **Step 2: Create `scripts/vfx/towers/well_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.25, 0.80, 0.65)
	palette_secondary = Color(0.50, 1.00, 0.85)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_support_pulse(t, a)
```

- [ ] **Step 3: Create `scripts/vfx/towers/earth_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.78, 0.52, 0.20)
	palette_secondary = Color(0.55, 0.35, 0.10)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_earth_impact(t, a)
```

- [ ] **Step 4: Create `scripts/vfx/towers/flesh_golem_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.55, 0.70, 0.35)
	palette_secondary = Color(0.30, 0.60, 0.20)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
```

- [ ] **Step 5: Create `scripts/vfx/towers/pure_earth_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.65, 0.45, 0.18)
	palette_secondary = Color(0.85, 0.65, 0.30)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_earth_impact(t, a)
```

- [ ] **Step 6: Create `scripts/vfx/towers/basic_tower_t1_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.12
	palette_primary  = Color(0.20, 0.80, 1.00)
	palette_secondary = Color(0.60, 0.92, 1.00)
func _draw_vfx(t: float, a: float, lend: Vector2) -> void:
	_h_rapid_tracer(t, a, lend)
```

- [ ] **Step 7: Create `scripts/vfx/towers/neutral_cannon_tower_attack_vfx.gd`**

```gdscript
extends "res://scripts/vfx/core/base_tower_attack_vfx.gd"
func configure(_data: Dictionary) -> void:
	lifetime = 0.20
	palette_primary  = Color(0.80, 0.65, 0.35)
	palette_secondary = Color(1.00, 0.85, 0.45)
func _draw_vfx(t: float, a: float, _lend: Vector2) -> void:
	_h_cannon_blast(t, a)
```

- [ ] **Step 8: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: T1 VFX — blacksmith/well/earth/flesh-golem/pure-earth/basic/neutral-cannon"
```

---

## Task 9: Batch-generate all T2/T3 files (82 files)

**Files:** Create 82 files in `scripts/vfx/towers/`

- [ ] **Step 1: Run the generator script**

Save this as a temp file and run it from the project root:

```python
#!/usr/bin/env python3
# generate_t2_t3_vfx.py — run from project root
import os

FAMILIES = [
    "blacksmith", "corrosion", "darkness", "disease", "drowning",
    "earth", "electricity", "enchantment", "fire", "flame",
    "flamethrower", "flesh_golem", "gold", "gunpowder", "hail",
    "hydro", "ice", "impulse", "jinx", "laser", "life", "light",
    "magic", "muck", "mushroom", "nature", "nova", "oblivion",
    "poison", "polar", "quaker", "quark", "roots", "tidal",
    "trickery", "vapor", "voodoo", "water", "well", "windstorm", "zealot",
]

OUT_DIR = "scripts/vfx/towers"
os.makedirs(OUT_DIR, exist_ok=True)

for family in FAMILIES:
    for tier in ("t2", "t3"):
        tower_id  = f"{family}_{tier}"
        t1_path   = f"res://scripts/vfx/towers/{family}_t1_attack_vfx.gd"
        filename  = os.path.join(OUT_DIR, f"{tower_id}_attack_vfx.gd")
        content   = (
            f'## {tower_id}_attack_vfx.gd\n'
            f'## Inherits T1 identity. Override configure() or _draw_vfx() for dedicated T{tier[-1]} design.\n'
            f'extends "{t1_path}"\n\n'
            f'func configure(data: Dictionary) -> void:\n'
            f'\tsuper.configure(data)\n'
        )
        with open(filename, "w") as f:
            f.write(content)

print(f"Generated {len(FAMILIES) * 2} files in {OUT_DIR}/")
```

Run it:
```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
python3 generate_t2_t3_vfx.py
```

Expected output: `Generated 82 files in scripts/vfx/towers/`

- [ ] **Step 2: Verify file count**

```bash
ls "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers/" | grep -E "_t[23]_attack_vfx\.gd" | wc -l
```

Expected output: `82`

- [ ] **Step 3: Clean up generator script**

```bash
rm "/Users/oyl/my_folders/projects/clone tower defend/generate_t2_t3_vfx.py"
```

- [ ] **Step 4: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add "scripts/vfx/towers/"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: batch-generate all T2/T3 VFX extension files (82 files, extend T1)"
```

---

## Task 10: Fill registry with all 132 entries

**Files:**
- Modify: `scripts/vfx/core/tower_attack_vfx_registry.gd`

Replace the shell from Task 1 with the complete registry containing all 132 preload entries.

- [ ] **Step 1: Verify all 132 source files exist**

```bash
python3 -c "
import os, json

with open('/Users/oyl/my_folders/projects/clone tower defend/data/towers_tree.json') as f:
    data = json.load(f)

ids = []
def collect(node):
    if isinstance(node, dict):
        if 'id' in node: ids.append(node['id'])
        for v in node.values(): collect(v)
    elif isinstance(node, list):
        [collect(i) for i in node]
collect(data)
ids = sorted(set(ids))

missing = []
base = '/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers'
for tid in ids:
    path = os.path.join(base, tid + '_attack_vfx.gd')
    if not os.path.exists(path):
        missing.append(tid)

if missing:
    print('MISSING:', missing)
else:
    print(f'All {len(ids)} VFX files present.')
"
```

Expected output: `All 132 VFX files present.`

- [ ] **Step 2: Write the complete registry**

Overwrite `scripts/vfx/core/tower_attack_vfx_registry.gd` with all 132 entries:

```gdscript
## TowerAttackVFXRegistry — maps every tower_id to its VFX GDScript.
## Lookup order: exact tower_id match only.
class_name TowerAttackVFXRegistry
extends RefCounted

const _SCRIPTS: Dictionary = {
	"basic_tower_t1":    preload("res://scripts/vfx/towers/basic_tower_t1_attack_vfx.gd"),
	"blacksmith_t1":     preload("res://scripts/vfx/towers/blacksmith_t1_attack_vfx.gd"),
	"blacksmith_t2":     preload("res://scripts/vfx/towers/blacksmith_t2_attack_vfx.gd"),
	"blacksmith_t3":     preload("res://scripts/vfx/towers/blacksmith_t3_attack_vfx.gd"),
	"corrosion_t1":      preload("res://scripts/vfx/towers/corrosion_t1_attack_vfx.gd"),
	"corrosion_t2":      preload("res://scripts/vfx/towers/corrosion_t2_attack_vfx.gd"),
	"corrosion_t3":      preload("res://scripts/vfx/towers/corrosion_t3_attack_vfx.gd"),
	"darkness_t1":       preload("res://scripts/vfx/towers/darkness_t1_attack_vfx.gd"),
	"darkness_t2":       preload("res://scripts/vfx/towers/darkness_t2_attack_vfx.gd"),
	"darkness_t3":       preload("res://scripts/vfx/towers/darkness_t3_attack_vfx.gd"),
	"disease_t1":        preload("res://scripts/vfx/towers/disease_t1_attack_vfx.gd"),
	"disease_t2":        preload("res://scripts/vfx/towers/disease_t2_attack_vfx.gd"),
	"disease_t3":        preload("res://scripts/vfx/towers/disease_t3_attack_vfx.gd"),
	"drowning_t1":       preload("res://scripts/vfx/towers/drowning_t1_attack_vfx.gd"),
	"drowning_t2":       preload("res://scripts/vfx/towers/drowning_t2_attack_vfx.gd"),
	"drowning_t3":       preload("res://scripts/vfx/towers/drowning_t3_attack_vfx.gd"),
	"earth_t1":          preload("res://scripts/vfx/towers/earth_t1_attack_vfx.gd"),
	"earth_t2":          preload("res://scripts/vfx/towers/earth_t2_attack_vfx.gd"),
	"earth_t3":          preload("res://scripts/vfx/towers/earth_t3_attack_vfx.gd"),
	"electricity_t1":    preload("res://scripts/vfx/towers/electricity_t1_attack_vfx.gd"),
	"electricity_t2":    preload("res://scripts/vfx/towers/electricity_t2_attack_vfx.gd"),
	"electricity_t3":    preload("res://scripts/vfx/towers/electricity_t3_attack_vfx.gd"),
	"enchantment_t1":    preload("res://scripts/vfx/towers/enchantment_t1_attack_vfx.gd"),
	"enchantment_t2":    preload("res://scripts/vfx/towers/enchantment_t2_attack_vfx.gd"),
	"enchantment_t3":    preload("res://scripts/vfx/towers/enchantment_t3_attack_vfx.gd"),
	"fire_t1":           preload("res://scripts/vfx/towers/fire_t1_attack_vfx.gd"),
	"fire_t2":           preload("res://scripts/vfx/towers/fire_t2_attack_vfx.gd"),
	"fire_t3":           preload("res://scripts/vfx/towers/fire_t3_attack_vfx.gd"),
	"flame_t1":          preload("res://scripts/vfx/towers/flame_t1_attack_vfx.gd"),
	"flame_t2":          preload("res://scripts/vfx/towers/flame_t2_attack_vfx.gd"),
	"flame_t3":          preload("res://scripts/vfx/towers/flame_t3_attack_vfx.gd"),
	"flamethrower_t1":   preload("res://scripts/vfx/towers/flamethrower_t1_attack_vfx.gd"),
	"flamethrower_t2":   preload("res://scripts/vfx/towers/flamethrower_t2_attack_vfx.gd"),
	"flamethrower_t3":   preload("res://scripts/vfx/towers/flamethrower_t3_attack_vfx.gd"),
	"flesh_golem_t1":    preload("res://scripts/vfx/towers/flesh_golem_t1_attack_vfx.gd"),
	"flesh_golem_t2":    preload("res://scripts/vfx/towers/flesh_golem_t2_attack_vfx.gd"),
	"flesh_golem_t3":    preload("res://scripts/vfx/towers/flesh_golem_t3_attack_vfx.gd"),
	"gold_t1":           preload("res://scripts/vfx/towers/gold_t1_attack_vfx.gd"),
	"gold_t2":           preload("res://scripts/vfx/towers/gold_t2_attack_vfx.gd"),
	"gold_t3":           preload("res://scripts/vfx/towers/gold_t3_attack_vfx.gd"),
	"gunpowder_t1":      preload("res://scripts/vfx/towers/gunpowder_t1_attack_vfx.gd"),
	"gunpowder_t2":      preload("res://scripts/vfx/towers/gunpowder_t2_attack_vfx.gd"),
	"gunpowder_t3":      preload("res://scripts/vfx/towers/gunpowder_t3_attack_vfx.gd"),
	"hail_t1":           preload("res://scripts/vfx/towers/hail_t1_attack_vfx.gd"),
	"hail_t2":           preload("res://scripts/vfx/towers/hail_t2_attack_vfx.gd"),
	"hail_t3":           preload("res://scripts/vfx/towers/hail_t3_attack_vfx.gd"),
	"hydro_t1":          preload("res://scripts/vfx/towers/hydro_t1_attack_vfx.gd"),
	"hydro_t2":          preload("res://scripts/vfx/towers/hydro_t2_attack_vfx.gd"),
	"hydro_t3":          preload("res://scripts/vfx/towers/hydro_t3_attack_vfx.gd"),
	"ice_t1":            preload("res://scripts/vfx/towers/ice_t1_attack_vfx.gd"),
	"ice_t2":            preload("res://scripts/vfx/towers/ice_t2_attack_vfx.gd"),
	"ice_t3":            preload("res://scripts/vfx/towers/ice_t3_attack_vfx.gd"),
	"impulse_t1":        preload("res://scripts/vfx/towers/impulse_t1_attack_vfx.gd"),
	"impulse_t2":        preload("res://scripts/vfx/towers/impulse_t2_attack_vfx.gd"),
	"impulse_t3":        preload("res://scripts/vfx/towers/impulse_t3_attack_vfx.gd"),
	"jinx_t1":           preload("res://scripts/vfx/towers/jinx_t1_attack_vfx.gd"),
	"jinx_t2":           preload("res://scripts/vfx/towers/jinx_t2_attack_vfx.gd"),
	"jinx_t3":           preload("res://scripts/vfx/towers/jinx_t3_attack_vfx.gd"),
	"laser_t1":          preload("res://scripts/vfx/towers/laser_t1_attack_vfx.gd"),
	"laser_t2":          preload("res://scripts/vfx/towers/laser_t2_attack_vfx.gd"),
	"laser_t3":          preload("res://scripts/vfx/towers/laser_t3_attack_vfx.gd"),
	"life_t1":           preload("res://scripts/vfx/towers/life_t1_attack_vfx.gd"),
	"life_t2":           preload("res://scripts/vfx/towers/life_t2_attack_vfx.gd"),
	"life_t3":           preload("res://scripts/vfx/towers/life_t3_attack_vfx.gd"),
	"light_t1":          preload("res://scripts/vfx/towers/light_t1_attack_vfx.gd"),
	"light_t2":          preload("res://scripts/vfx/towers/light_t2_attack_vfx.gd"),
	"light_t3":          preload("res://scripts/vfx/towers/light_t3_attack_vfx.gd"),
	"magic_t1":          preload("res://scripts/vfx/towers/magic_t1_attack_vfx.gd"),
	"magic_t2":          preload("res://scripts/vfx/towers/magic_t2_attack_vfx.gd"),
	"magic_t3":          preload("res://scripts/vfx/towers/magic_t3_attack_vfx.gd"),
	"muck_t1":           preload("res://scripts/vfx/towers/muck_t1_attack_vfx.gd"),
	"muck_t2":           preload("res://scripts/vfx/towers/muck_t2_attack_vfx.gd"),
	"muck_t3":           preload("res://scripts/vfx/towers/muck_t3_attack_vfx.gd"),
	"mushroom_t1":       preload("res://scripts/vfx/towers/mushroom_t1_attack_vfx.gd"),
	"mushroom_t2":       preload("res://scripts/vfx/towers/mushroom_t2_attack_vfx.gd"),
	"mushroom_t3":       preload("res://scripts/vfx/towers/mushroom_t3_attack_vfx.gd"),
	"nature_t1":         preload("res://scripts/vfx/towers/nature_t1_attack_vfx.gd"),
	"nature_t2":         preload("res://scripts/vfx/towers/nature_t2_attack_vfx.gd"),
	"nature_t3":         preload("res://scripts/vfx/towers/nature_t3_attack_vfx.gd"),
	"neutral_cannon_tower": preload("res://scripts/vfx/towers/neutral_cannon_tower_attack_vfx.gd"),
	"nova_t1":           preload("res://scripts/vfx/towers/nova_t1_attack_vfx.gd"),
	"nova_t2":           preload("res://scripts/vfx/towers/nova_t2_attack_vfx.gd"),
	"nova_t3":           preload("res://scripts/vfx/towers/nova_t3_attack_vfx.gd"),
	"oblivion_t1":       preload("res://scripts/vfx/towers/oblivion_t1_attack_vfx.gd"),
	"oblivion_t2":       preload("res://scripts/vfx/towers/oblivion_t2_attack_vfx.gd"),
	"oblivion_t3":       preload("res://scripts/vfx/towers/oblivion_t3_attack_vfx.gd"),
	"periodic_t1":       preload("res://scripts/vfx/towers/periodic_t1_attack_vfx.gd"),
	"poison_t1":         preload("res://scripts/vfx/towers/poison_t1_attack_vfx.gd"),
	"poison_t2":         preload("res://scripts/vfx/towers/poison_t2_attack_vfx.gd"),
	"poison_t3":         preload("res://scripts/vfx/towers/poison_t3_attack_vfx.gd"),
	"polar_t1":          preload("res://scripts/vfx/towers/polar_t1_attack_vfx.gd"),
	"polar_t2":          preload("res://scripts/vfx/towers/polar_t2_attack_vfx.gd"),
	"polar_t3":          preload("res://scripts/vfx/towers/polar_t3_attack_vfx.gd"),
	"pure_darkness":     preload("res://scripts/vfx/towers/pure_darkness_attack_vfx.gd"),
	"pure_earth":        preload("res://scripts/vfx/towers/pure_earth_attack_vfx.gd"),
	"pure_fire":         preload("res://scripts/vfx/towers/pure_fire_attack_vfx.gd"),
	"pure_light":        preload("res://scripts/vfx/towers/pure_light_attack_vfx.gd"),
	"pure_nature":       preload("res://scripts/vfx/towers/pure_nature_attack_vfx.gd"),
	"pure_water":        preload("res://scripts/vfx/towers/pure_water_attack_vfx.gd"),
	"quaker_t1":         preload("res://scripts/vfx/towers/quaker_t1_attack_vfx.gd"),
	"quaker_t2":         preload("res://scripts/vfx/towers/quaker_t2_attack_vfx.gd"),
	"quaker_t3":         preload("res://scripts/vfx/towers/quaker_t3_attack_vfx.gd"),
	"quark_t1":          preload("res://scripts/vfx/towers/quark_t1_attack_vfx.gd"),
	"quark_t2":          preload("res://scripts/vfx/towers/quark_t2_attack_vfx.gd"),
	"quark_t3":          preload("res://scripts/vfx/towers/quark_t3_attack_vfx.gd"),
	"roots_t1":          preload("res://scripts/vfx/towers/roots_t1_attack_vfx.gd"),
	"roots_t2":          preload("res://scripts/vfx/towers/roots_t2_attack_vfx.gd"),
	"roots_t3":          preload("res://scripts/vfx/towers/roots_t3_attack_vfx.gd"),
	"tidal_t1":          preload("res://scripts/vfx/towers/tidal_t1_attack_vfx.gd"),
	"tidal_t2":          preload("res://scripts/vfx/towers/tidal_t2_attack_vfx.gd"),
	"tidal_t3":          preload("res://scripts/vfx/towers/tidal_t3_attack_vfx.gd"),
	"trickery_t1":       preload("res://scripts/vfx/towers/trickery_t1_attack_vfx.gd"),
	"trickery_t2":       preload("res://scripts/vfx/towers/trickery_t2_attack_vfx.gd"),
	"trickery_t3":       preload("res://scripts/vfx/towers/trickery_t3_attack_vfx.gd"),
	"vapor_t1":          preload("res://scripts/vfx/towers/vapor_t1_attack_vfx.gd"),
	"vapor_t2":          preload("res://scripts/vfx/towers/vapor_t2_attack_vfx.gd"),
	"vapor_t3":          preload("res://scripts/vfx/towers/vapor_t3_attack_vfx.gd"),
	"voodoo_t1":         preload("res://scripts/vfx/towers/voodoo_t1_attack_vfx.gd"),
	"voodoo_t2":         preload("res://scripts/vfx/towers/voodoo_t2_attack_vfx.gd"),
	"voodoo_t3":         preload("res://scripts/vfx/towers/voodoo_t3_attack_vfx.gd"),
	"water_t1":          preload("res://scripts/vfx/towers/water_t1_attack_vfx.gd"),
	"water_t2":          preload("res://scripts/vfx/towers/water_t2_attack_vfx.gd"),
	"water_t3":          preload("res://scripts/vfx/towers/water_t3_attack_vfx.gd"),
	"well_t1":           preload("res://scripts/vfx/towers/well_t1_attack_vfx.gd"),
	"well_t2":           preload("res://scripts/vfx/towers/well_t2_attack_vfx.gd"),
	"well_t3":           preload("res://scripts/vfx/towers/well_t3_attack_vfx.gd"),
	"windstorm_t1":      preload("res://scripts/vfx/towers/windstorm_t1_attack_vfx.gd"),
	"windstorm_t2":      preload("res://scripts/vfx/towers/windstorm_t2_attack_vfx.gd"),
	"windstorm_t3":      preload("res://scripts/vfx/towers/windstorm_t3_attack_vfx.gd"),
	"zealot_t1":         preload("res://scripts/vfx/towers/zealot_t1_attack_vfx.gd"),
	"zealot_t2":         preload("res://scripts/vfx/towers/zealot_t2_attack_vfx.gd"),
	"zealot_t3":         preload("res://scripts/vfx/towers/zealot_t3_attack_vfx.gd"),
}

static func get_script(tower_id: String) -> GDScript:
	return _SCRIPTS.get(tower_id, null)
```

- [ ] **Step 3: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add \
    "scripts/vfx/core/tower_attack_vfx_registry.gd"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: fill VFX registry with all 132 tower_id → script entries"
```

---

## Task 11: Wire new service into existing `tower_attack_vfx.gd`

**Files:**
- Modify: `scripts/effects/tower_attack_vfx.gd`

The existing call site in `tower.gd` line 1308 is `TowerAttackVFX.spawn_attack_vfx(self, current_target)`.
We update `spawn_attack_vfx` to delegate to `TowerAttackVFXService` when a registry match exists.
If no match, the legacy visual_type-based dispatch runs unchanged.

- [ ] **Step 1: Read the current `spawn_attack_vfx` function**

Read `scripts/effects/tower_attack_vfx.gd` lines 82–127 to confirm the current structure before editing.

- [ ] **Step 2: Modify `spawn_attack_vfx` to check registry first**

Find the line `var vfx_type := resolve_vfx_type(tower)` (around line 115) and add the registry delegation BEFORE it:

Replace this block in `spawn_attack_vfx`:
```gdscript
	var vfx_type := resolve_vfx_type(tower)

	# Element-aware color (calls tower's own helper; falls back to white).
	var color: Color = Color.WHITE
	if tower.has_method("_get_tower_color"):
		color = tower._get_tower_color()

	# Spawn lightweight Node2D with the VFX script.
	var node: Node2D = Node2D.new()
	node.set_script(_VFX_SCRIPT)
	container.add_child(node)
	node.setup(vfx_type, origin, tgt_pos, color)
```

With:
```gdscript
	# New per-id system: try registry first.
	var tower_id: String = str(tower.get("tower_id")) if "tower_id" in tower else ""
	if tower_id != "" and TowerAttackVFXRegistry.get_script(tower_id) != null:
		TowerAttackVFXService.spawn(tower, target)
		return

	# Legacy visual_type dispatch (unchanged — runs for unknown tower_ids).
	var vfx_type := resolve_vfx_type(tower)

	# Element-aware color (calls tower's own helper; falls back to white).
	var color: Color = Color.WHITE
	if tower.has_method("_get_tower_color"):
		color = tower._get_tower_color()

	# Spawn lightweight Node2D with the VFX script.
	var node: Node2D = Node2D.new()
	node.set_script(_VFX_SCRIPT)
	container.add_child(node)
	node.setup(vfx_type, origin, tgt_pos, color)
```

- [ ] **Step 3: Verify the budget guard runs BEFORE the registry check**

Confirm in the file that the `AttackVFX._active_count >= AttackVFX.MAX_ACTIVE` guard (currently around line 112) is still executed BEFORE the new `tower_id` check. `TowerAttackVFXService.spawn()` has its own `TowerAttackVFXPool.can_spawn()` check using `BaseTowerAttackVFX._active_count`, so both caps are enforced independently — this is correct.

- [ ] **Step 4: Commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add \
    "scripts/effects/tower_attack_vfx.gd"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "feat: wire new per-id VFX registry into TowerAttackVFX — tower_id-first dispatch"
```

---

## Task 12: Integration smoke test

- [ ] **Step 1: Verify file counts are correct**

```bash
echo "T1/special files:" && ls "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers/" | grep -vE "_t[23]_attack_vfx" | wc -l
echo "T2 files:" && ls "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers/" | grep "_t2_attack_vfx" | wc -l
echo "T3 files:" && ls "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers/" | grep "_t3_attack_vfx" | wc -l
echo "Total:" && ls "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/towers/" | grep "_attack_vfx" | wc -l
```

Expected:
```
T1/special files: 50
T2 files: 41
T3 files: 41
Total: 132
```

- [ ] **Step 2: Verify registry entries match file count**

```bash
grep -c "preload" "/Users/oyl/my_folders/projects/clone tower defend/scripts/vfx/core/tower_attack_vfx_registry.gd"
```

Expected output: `132`

- [ ] **Step 3: Verify no gameplay files changed**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" diff HEAD~12 -- \
    scripts/core/ scripts/managers/ scripts/enemies/ scripts/main/main.gd \
    data/ | head -5
```

Expected: empty output (no gameplay files changed).

- [ ] **Step 4: Verify `tower.gd` was not changed**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" log --oneline -- "scripts/towers/tower.gd" | head -3
```

Confirm the most recent commit touching `tower.gd` is NOT from this feature.

- [ ] **Step 5: Final commit**

```bash
git -C "/Users/oyl/my_folders/projects/clone tower defend" add \
    "docs/superpowers/plans/2026-05-19-tower-attack-vfx-identity.md"
git -C "/Users/oyl/my_folders/projects/clone tower defend" \
    commit -m "docs: record tower attack VFX identity system plan"
```

---

## Self-Review

**Spec coverage:**

| Requirement | Task | Status |
|---|---|---|
| `res://scripts/vfx/core/base_tower_attack_vfx.gd` | Task 1 | ✓ |
| `res://scripts/vfx/core/tower_attack_vfx_service.gd` | Task 1 | ✓ |
| `res://scripts/vfx/core/tower_attack_vfx_registry.gd` | Task 1 + 10 | ✓ |
| `res://scripts/vfx/core/tower_attack_vfx_pool.gd` | Task 1 | ✓ |
| `res://scripts/vfx/status/status_marker_vfx.gd` | Task 1 | ✓ |
| One file per tower_id in `scripts/vfx/towers/` | Tasks 2-9 | ✓ 132 files |
| T1 = custom VFX identity | Tasks 2-8 | ✓ all 50 T1/specials |
| T2/T3 extend T1 (not generic fallback) | Task 9 | ✓ extend `*_t1_attack_vfx.gd` |
| Do NOT fallback T2/T3 to visual_type family | Task 9 | ✓ generator uses `{family}_t1` path |
| No gameplay changes | All tasks | ✓ only VFX files + tower_attack_vfx.gd delegation |
| Integration: tower_id-first lookup | Task 11 | ✓ |

**Placeholder scan:** No TBDs, incomplete sections, or vague steps found.

**Type consistency:**
- `BaseTowerAttackVFX` — class_name used in `TowerAttackVFXPool.can_spawn()` and `TowerAttackVFXService.spawn()` ✓
- `TowerAttackVFXRegistry.get_script(tower_id)` → `GDScript` used in both service and delegation ✓  
- `node.setup(origin, tgt_pos, color)` — signature matches `BaseTowerAttackVFX.setup()` ✓
- `node.configure({})` — signature matches `BaseTowerAttackVFX.configure()` ✓
- `_h_*` helpers referenced in T1 files all defined in `base_tower_attack_vfx.gd` ✓
