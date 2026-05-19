# Visual Comfort Anti-Strobe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce bright, flickery combat VFX while preserving gameplay readability, tower/enemy behavior, wave logic, shield logic, disruptor logic, and balance.

**Architecture:** Add a focused `VisualComfortService` autoload for alpha caps, color policy, and per-key cosmetic throttles. Existing enemy and VFX scripts query the service and existing performance services; `main.gd` remains untouched.

**Tech Stack:** Godot 4.6.2, GDScript, existing `PerformanceBudgetService`, existing `PerformanceFirebreak`.

---

## File Structure

- Create `scripts/services/visual_comfort_service.gd`: central visual comfort constants, default-on toggle, color mapping, flash throttles, FPS-aware cosmetic gates.
- Modify `project.godot`: register the service as the `VisualComfort` autoload. The autoload name differs from `class_name VisualComfortService` because Godot rejects a singleton that hides a global class with the same name.
- Modify `scripts/enemies/enemy.gd`: replace white flash state with soft hit tint state, avoid duplicate hit/pulse/shake tweens, consult visual comfort and performance gates.
- Modify `scripts/enemies/enemy_visual_router.gd`: draw hit/shield/slow overlays with capped alpha and no white strobe.
- Modify `scripts/effects/enemy_beam_vfx.gd`: draw stable thin disruptor links with low-alpha glow and throttled redraws.
- Modify `scripts/effects/enemy_vfx_controller.gd`: use service colors, throttle shield sparks, keep debug/radius visuals subdued.
- Modify `scripts/effects/enemy_aura_vfx.gd`: slow and cap debug aura pulse.
- Modify `scripts/effects/enemy_impact_vfx.gd`: soften shield ripple and remove rotating spark spam.
- Modify `scripts/effects/enemy_status_icon_vfx.gd`: cap icon alpha and reduce pulse frequency.
- Modify `scripts/effects/lightning_arc.gd`: remove rapid re-randomized flicker and cap alpha.

### Task 1: Add VisualComfortService

**Files:**
- Create: `scripts/services/visual_comfort_service.gd`
- Modify: `project.godot`

- [ ] **Step 1: Create the service**

Add a service with these exact responsibilities:

```gdscript
extends Node
class_name VisualComfortService

const HIT_FLASH_ALPHA_MAX := 0.22
const HIT_FLASH_DURATION := 0.08
const HIT_FLASH_COOLDOWN := 0.18
const LINK_ALPHA_MAX := 0.28
const SHIELD_ALPHA_MAX := 0.24
const STATUS_ICON_ALPHA := 0.75
const MAX_FLASHES_PER_SECOND := 3
const SOFT_GLOW_ALPHA := 0.18

var visual_comfort_mode := true
var _last_flash_msec: Dictionary = {}

func allow_flash(key: String) -> bool:
	if not visual_comfort_mode:
		return true
	if _current_fps() < 52.0:
		return false
	var now := Time.get_ticks_msec()
	var last := int(_last_flash_msec.get(key, -100000))
	var min_gap := int(ceil(1000.0 / float(MAX_FLASHES_PER_SECOND)))
	min_gap = maxi(min_gap, int(round(HIT_FLASH_COOLDOWN * 1000.0)))
	if now - last < min_gap:
		return false
	_last_flash_msec[key] = now
	return true

func get_hit_flash_color(element_or_damage_type: String) -> Color:
	var key := element_or_damage_type.strip_edges().to_lower()
	if key.contains("fire") or key.contains("burn") or key.contains("flame"):
		return Color(1.0, 0.48, 0.16, HIT_FLASH_ALPHA_MAX)
	if key.contains("poison") or key.contains("nature") or key.contains("disease") or key.contains("spore"):
		return Color(0.48, 0.95, 0.34, HIT_FLASH_ALPHA_MAX)
	if key.contains("ice") or key.contains("frost") or key.contains("slow") or key.contains("water"):
		return Color(0.40, 0.86, 1.0, HIT_FLASH_ALPHA_MAX)
	if key.contains("dark") or key.contains("void") or key.contains("jinx") or key.contains("curse"):
		return Color(0.70, 0.45, 1.0, HIT_FLASH_ALPHA_MAX)
	if key.contains("light") or key.contains("holy") or key.contains("laser"):
		return Color(1.0, 0.82, 0.36, HIT_FLASH_ALPHA_MAX)
	return Color(1.0, 0.62, 0.26, HIT_FLASH_ALPHA_MAX)

func get_link_color(effect_type: String) -> Color:
	var key := effect_type.strip_edges().to_lower()
	if key.contains("disrupt") or key.contains("emp"):
		return Color(0.48, 0.78, 1.0, LINK_ALPHA_MAX)
	if key.contains("shield"):
		return Color(0.45, 0.82, 1.0, LINK_ALPHA_MAX)
	return Color(0.62, 0.74, 0.92, LINK_ALPHA_MAX)

func get_shield_color(shield_type: String) -> Color:
	var key := shield_type.strip_edges().to_lower()
	if key.contains("gold") or key.contains("holy"):
		return Color(1.0, 0.78, 0.34, SHIELD_ALPHA_MAX)
	return Color(0.42, 0.78, 1.0, SHIELD_ALPHA_MAX)

func should_skip_hit_flash() -> bool:
	return visual_comfort_mode and _current_fps() < 52.0

func allow_shield_ripple(key: String) -> bool:
	if visual_comfort_mode and _current_fps() < 58.0:
		return false
	return allow_flash(key)

func get_hit_flash_duration() -> float:
	return HIT_FLASH_DURATION

func get_link_alpha_max() -> float:
	return LINK_ALPHA_MAX

func get_shield_alpha_max() -> float:
	return SHIELD_ALPHA_MAX

func get_status_icon_alpha() -> float:
	return STATUS_ICON_ALPHA

func get_soft_glow_alpha() -> float:
	return SOFT_GLOW_ALPHA

func _current_fps() -> float:
	var perf := get_node_or_null("/root/PerformanceBudgetService")
	if perf != null:
		return float(perf.current_fps)
	return float(Engine.get_frames_per_second())
```

- [ ] **Step 2: Register the autoload**

Add this line to `[autoload]` in `project.godot`:

```ini
VisualComfort="*res://scripts/services/visual_comfort_service.gd"
```

- [ ] **Step 3: Parse check**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit
```

Expected: exits 0 with no script parse errors.

### Task 2: Replace Enemy Hit Flash

**Files:**
- Modify: `scripts/enemies/enemy.gd`
- Modify: `scripts/enemies/enemy_visual_router.gd`

- [ ] **Step 1: Add cosmetic state to enemy.gd**

Add near the existing visual state vars:

```gdscript
var hit_flash_color: Color = Color(1.0, 0.62, 0.26, 0.0)
var hit_flash_alpha: float = 0.0
var _hit_flash_tween: Tween = null
var _hit_pulse_tween: Tween = null
var _hit_shake_tween: Tween = null
```

- [ ] **Step 2: Pass source context into flash_body**

Change the `take_damage()` call from:

```gdscript
flash_body()
```

to:

```gdscript
flash_body(source_id if source_id != "" else p_attack_type)
```

- [ ] **Step 3: Replace flash_body implementation**

Replace `flash_body()` with:

```gdscript
func flash_body(damage_context: String = "") -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and comfort.has_method("should_skip_hit_flash") and comfort.should_skip_hit_flash():
		return
	if comfort != null and comfort.has_method("allow_flash"):
		if not comfort.allow_flash("hit_%s" % get_instance_id()):
			return
	if not is_visible_in_tree():
		return

	if _hit_flash_tween != null and _hit_flash_tween.is_valid() and _hit_flash_tween.is_running():
		return

	if comfort != null and comfort.has_method("get_hit_flash_color"):
		hit_flash_color = comfort.get_hit_flash_color(damage_context)
	else:
		hit_flash_color = Color(1.0, 0.62, 0.26, 0.20)
	hit_flash_alpha = minf(hit_flash_color.a, 0.22)
	is_flashing = hit_flash_alpha > 0.01
	queue_redraw()

	var duration := 0.08
	if comfort != null and comfort.has_method("get_hit_flash_duration"):
		duration = float(comfort.get_hit_flash_duration())
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "hit_flash_alpha", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hit_flash_tween.tween_callback(func():
		is_flashing = false
		queue_redraw()
	)
```

- [ ] **Step 4: Make hit pulse tween-safe**

At the start of `_play_hit_pulse()`, add:

```gdscript
	if PerformanceFirebreak.disable_cosmetic_tweens:
		return
	if not is_visible_in_tree():
		return
	if _hit_pulse_tween != null and _hit_pulse_tween.is_valid() and _hit_pulse_tween.is_running():
		return
```

Change the local `var tween = create_tween()` to:

```gdscript
	_hit_pulse_tween = create_tween()
	var tween := _hit_pulse_tween
```

Before creating the shake tween, add:

```gdscript
		if _hit_shake_tween != null and _hit_shake_tween.is_valid() and _hit_shake_tween.is_running():
			return
```

Change the local shake tween to:

```gdscript
		_hit_shake_tween = create_tween()
		var shake_tween := _hit_shake_tween
```

- [ ] **Step 5: Draw soft hit overlay**

In `scripts/enemies/enemy_visual_router.gd`, replace both white flash overlay branches with color pulled from:

```gdscript
var hit_color: Color = enemy.get("hit_flash_color")
var hit_alpha: float = clampf(float(enemy.get("hit_flash_alpha")), 0.0, 0.22)
```

Simple mode should draw one soft circle:

```gdscript
if flash and hit_alpha > 0.01:
	enemy.draw_circle(Vector2.ZERO, size * 1.35, Color(hit_color.r, hit_color.g, hit_color.b, hit_alpha))
```

Full mode should draw one soft circle plus one faint arc:

```gdscript
if flash and hit_alpha > 0.01:
	enemy.draw_circle(Vector2.ZERO, size * 1.35, Color(hit_color.r, hit_color.g, hit_color.b, hit_alpha))
	enemy.draw_arc(Vector2.ZERO, size * 1.45, 0, TAU, 24, Color(hit_color.r, hit_color.g, hit_color.b, hit_alpha * 0.75), 1.25)
```

### Task 3: Stabilize Disruptor Links and Lightning Arcs

**Files:**
- Modify: `scripts/effects/enemy_beam_vfx.gd`
- Modify: `scripts/effects/enemy_vfx_controller.gd`
- Modify: `scripts/effects/lightning_arc.gd`

- [ ] **Step 1: Use service link color in controller**

In `update_disrupted_towers()` and `clear_disrupted_tower()`, replace `Color(1.0, 0.15, 0.8)` with:

```gdscript
_get_link_color("disruptor")
```

Add helper:

```gdscript
func _get_link_color(effect_type: String) -> Color:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and comfort.has_method("get_link_color"):
		return comfort.get_link_color(effect_type)
	return Color(0.48, 0.78, 1.0, 0.28)
```

- [ ] **Step 2: Throttle beam redraws**

In `enemy_beam_vfx.gd`, add:

```gdscript
var _redraw_elapsed: float = 0.0
const LINK_REDRAW_INTERVAL := 0.10
```

In `_process(delta)`, for link mode, increment `_redraw_elapsed` and only call `queue_redraw()` when it reaches the interval.

- [ ] **Step 3: Draw stable low-alpha link**

Replace `_draw_links()` body with a straight stable line:

```gdscript
func _draw_links() -> void:
	var alpha_max := 0.28
	var glow_alpha := 0.18
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		alpha_max = float(comfort.get("LINK_ALPHA_MAX"))
		glow_alpha = float(comfort.get("SOFT_GLOW_ALPHA"))
	for target in links:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var local_target := to_local((target as Node2D).global_position)
		var c := Color(beam_color.r, beam_color.g, beam_color.b, minf(beam_color.a, alpha_max))
		draw_line(Vector2.ZERO, local_target, Color(c.r, c.g, c.b, glow_alpha), 3.0, true)
		draw_line(Vector2.ZERO, local_target, c, 1.25, true)
```

- [ ] **Step 4: Remove lightning arc flicker**

In `lightning_arc.gd`, remove the `flicker_timer` regeneration branch from `_process()`. Cap alpha in `_draw()`:

```gdscript
var alpha = (1.0 - (elapsed / duration)) * 0.28
```

Keep the glow alpha under `0.18`.

### Task 4: Soften Shield and Status VFX

**Files:**
- Modify: `scripts/effects/enemy_vfx_controller.gd`
- Modify: `scripts/effects/enemy_aura_vfx.gd`
- Modify: `scripts/effects/enemy_impact_vfx.gd`
- Modify: `scripts/effects/enemy_status_icon_vfx.gd`
- Modify: `scripts/enemies/enemy_visual_router.gd`

- [ ] **Step 1: Throttle shield spark**

In `play_shield_spark()`, add:

```gdscript
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		return
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and comfort.has_method("allow_shield_ripple"):
		if not comfort.allow_shield_ripple("shield_%s" % owner_enemy.get_instance_id()):
			return
```

Use:

```gdscript
Color(0.42, 0.78, 1.0, 0.24)
```

for shield spark color.

- [ ] **Step 2: Cap aura pulse**

In `enemy_aura_vfx.gd`, change pulse speed to `time * 0.7`, cap alpha to `0.24`, and reduce role tick alpha to at most `0.18`.

- [ ] **Step 3: Soften shield spark drawing**

In `_draw_shield_spark()`, use one ripple arc and no rotating lines:

```gdscript
func _draw_shield_spark(t: float, a: float) -> void:
	var alpha := minf(color.a, 0.24) * a
	draw_arc(Vector2.ZERO, 12.0 + t * 8.0, -PI * 0.15, PI * 1.15, 18, Color(color.r, color.g, color.b, alpha), 1.5)
	if OS.is_debug_build() and debug_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(8, -18), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(color.r, color.g, color.b, minf(a, 0.65)))
```

- [ ] **Step 4: Reduce status icon pulse**

In `enemy_status_icon_vfx.gd`, change pulse to:

```gdscript
var pulse := 0.86 + sin(time * 2.4) * 0.08
```

Clamp icon draw alpha to the service cap or `0.75`.

- [ ] **Step 5: Cap shield overlays in router**

In `enemy_visual_router.gd`, simple shield overlay alpha should be `0.22`; full shield overlay should use slow pulse `sin(pulse_time * 0.7)` and alpha no greater than `0.24`.

### Task 5: Verification

**Files:**
- No code changes unless a verification failure identifies a parse/runtime issue.

- [ ] **Step 1: Run Godot parse/boot check**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit
```

Expected: exits 0.

- [ ] **Step 2: Run guardrail audits**

Run:

```bash
python3 tools/refactor/audit_project_guardrails.py
python3 tools/refactor/audit_main_small_split.py
python3 tools/refactor/audit_controller_stability.py
```

Expected: all exit 0.

- [ ] **Step 3: Manual smoke notes**

Boot a dense combat scene if available and check:

- Creeps do not flash white.
- Disruptor links are thin and stable.
- Shield bearer protection reads through icon/rim/ripple without repeated rings.
- Debugger shows no repeated errors.

## Self-Review

- Spec coverage: service, hit flash, disruptor links, shield feedback, global default-on comfort mode, duplicate feedback, tween safety, and performance gates are covered.
- Placeholder scan: no `TBD`, `TODO`, or undefined future steps.
- Type consistency: GDScript property names match the planned files and existing Godot 4 tween APIs.
