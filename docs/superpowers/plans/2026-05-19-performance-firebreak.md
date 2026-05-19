# Performance Firebreak Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate 280ms frame spikes by adding a global kill-switch that stops all cosmetic VFX, plus a spike logger and per-site guards at every spawn point.

**Architecture:** A static class `PerformanceFirebreak` holds bool flags; every VFX entry point reads those flags and returns early. A separate `FrameSpikeLogger` prints a single compact line when delta > 50ms. No gameplay logic changes.

**Tech Stack:** GDScript 4, Godot 4.6.2 static class_name globals, Node2D draw API.

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| **Create** | `scripts/services/performance_firebreak.gd` | Global flag singleton — all feature guards read this |
| **Create** | `scripts/services/frame_spike_logger.gd` | Debug-only spike detector |
| **Modify** | `scripts/effects/tower_attack_vfx.gd` | Guard at `spawn_attack_vfx()` entry |
| **Modify** | `scripts/effects/attack_vfx.gd` | Guard in `_process()` to skip redraw; no spawn guard needed (caller guards) |
| **Modify** | `scripts/vfx/core/base_tower_attack_vfx.gd` | Guard in `_process()` |
| **Modify** | `scripts/vfx/core/tower_attack_vfx_service.gd` | Guard at `spawn()` entry |
| **Modify** | `scripts/effects/impact_effect.gd` | Guard at `setup()` entry |
| **Modify** | `scripts/effects/death_pop_effect.gd` | Guard at `_ready()` / skip tween |
| **Modify** | `scripts/effects/damage_number.gd` | Guard at `_ready()` to skip tween + self-free |
| **Modify** | `scripts/effects/creep_status_vfx.gd` | Guard in `_process()` to skip redraws |
| **Modify** | `scripts/effects/enemy_status_icon_vfx.gd` | Guard in `_process()` to skip redraws |
| **Modify** | `scripts/towers/tower_catalog_preview.gd` | Guard `PreviewFxLayer._process()` entirely |
| **Modify** | `scripts/projectiles/projectile.gd` | Guard `_spawn_impact_effect()` |
| **Modify** | `scripts/enemies/enemy.gd` | Guard `spawn_damage_number()` |

---

## Task 1: Create PerformanceFirebreak singleton

**Files:**
- Create: `scripts/services/performance_firebreak.gd`

- [ ] **Step 1: Create the file**

```gdscript
## PerformanceFirebreak — global kill-switch for all cosmetic VFX.
## Set enabled = true to enforce all sub-flags simultaneously.
## Individual flags can be toggled while enabled is false.
class_name PerformanceFirebreak
extends RefCounted

static var enabled := true

static var disable_all_attack_vfx := true
static var disable_catalog_vfx := true
static var disable_damage_numbers := true
static var disable_impact_effects := true
static var disable_death_effects := true
static var disable_status_animations := true
static var disable_aura_visuals := true
static var disable_projectile_visuals := true
static var disable_cosmetic_tweens := true
static var max_active_vfx := 0
static var ui_refresh_interval := 1.0
```

- [ ] **Step 2: Verify Godot can parse the file**

Open Godot → Project → Tools → GDScript → Parse All Scripts (or just run the project).  
Expected: no parse errors for `performance_firebreak.gd`.

- [ ] **Step 3: Commit**

```bash
git add "scripts/services/performance_firebreak.gd"
git commit -m "feat: add PerformanceFirebreak global kill-switch"
```

---

## Task 2: Create FrameSpikeLogger

**Files:**
- Create: `scripts/services/frame_spike_logger.gd`

- [ ] **Step 1: Create the file**

```gdscript
## FrameSpikeLogger — debug-only per-frame spike detector.
## Prints a compact line when delta exceeds SPIKE_THRESHOLD.
## Cooldown prevents log spam.
class_name FrameSpikeLogger
extends Node

const SPIKE_THRESHOLD := 0.05
const COOLDOWN := 2.0

var _cooldown_remaining := 0.0

func _process(delta: float) -> void:
	if not OS.is_debug_build():
		return
	_cooldown_remaining -= delta
	if delta >= SPIKE_THRESHOLD and _cooldown_remaining <= 0.0:
		_cooldown_remaining = COOLDOWN
		var vfx_count := get_tree().get_nodes_in_group("attack_vfx").size()
		var node_count := get_tree().get_node_count()
		var scene_name := get_tree().current_scene.name if get_tree().current_scene else "none"
		print("[SPIKE] delta=%.1fms fps=%d nodes=%d active_vfx=%d scene=%s" % [
			delta * 1000.0,
			Engine.get_frames_per_second(),
			node_count,
			vfx_count,
			scene_name,
		])
```

- [ ] **Step 2: Add FrameSpikeLogger to the autoload list OR to a suitable scene root**

Option A (autoload — persists across scenes):  
Project → Project Settings → Autoload → Add `res://scripts/services/frame_spike_logger.gd` with name `FrameSpikeLogger`.

Option B (scene-local — add manually to any scene's root while testing):  
Add a Node child, assign `frame_spike_logger.gd` as its script.

Use Option A so it works everywhere without scene changes.

- [ ] **Step 3: Commit**

```bash
git add "scripts/services/frame_spike_logger.gd"
git commit -m "feat: add FrameSpikeLogger debug spike detector"
```

---

## Task 3: Guard spawn_attack_vfx — the primary VFX entry point

**Files:**
- Modify: `scripts/effects/tower_attack_vfx.gd` (function `spawn_attack_vfx`, roughly line 67)

- [ ] **Step 1: Add firebreak guard as the first check in `spawn_attack_vfx()`**

Find this block near the top of `spawn_attack_vfx()`:
```gdscript
static func spawn_attack_vfx(tower: Node2D, target: Node2D,
							  _context: Dictionary = {}) -> void:
	if not is_instance_valid(tower) or not is_instance_valid(target):
		return
```

Change to:
```gdscript
static func spawn_attack_vfx(tower: Node2D, target: Node2D,
							  _context: Dictionary = {}) -> void:
	if PerformanceFirebreak.disable_all_attack_vfx:
		return
	if not is_instance_valid(tower) or not is_instance_valid(target):
		return
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/tower_attack_vfx.gd"
git commit -m "fix: guard TowerAttackVFX.spawn_attack_vfx behind firebreak flag"
```

---

## Task 4: Guard TowerAttackVFXService.spawn()

**Files:**
- Modify: `scripts/vfx/core/tower_attack_vfx_service.gd` (function `spawn`, line ~5)

- [ ] **Step 1: Add guard as first line of `spawn()`**

```gdscript
static func spawn(tower: Node2D, target: Node2D) -> void:
	if PerformanceFirebreak.disable_all_attack_vfx:
		return
	if not is_instance_valid(tower) or not is_instance_valid(target):
		return
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/vfx/core/tower_attack_vfx_service.gd"
git commit -m "fix: guard TowerAttackVFXService.spawn behind firebreak flag"
```

---

## Task 5: Guard BaseTowerAttackVFX._process() to skip queue_redraw

**Files:**
- Modify: `scripts/vfx/core/base_tower_attack_vfx.gd` (function `_process`, line ~42)

The node still cleans itself up via queue_free — we only skip the cosmetic redraw.

- [ ] **Step 1: Modify `_process()`**

Current:
```gdscript
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		BaseTowerAttackVFX._active_count -= 1
		queue_free()
		return
	queue_redraw()
```

Replace with:
```gdscript
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		BaseTowerAttackVFX._active_count -= 1
		queue_free()
		return
	if not PerformanceFirebreak.disable_all_attack_vfx:
		queue_redraw()
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/vfx/core/base_tower_attack_vfx.gd"
git commit -m "fix: skip queue_redraw in BaseTowerAttackVFX when firebreak active"
```

---

## Task 6: Guard AttackVFX._process() to skip queue_redraw

**Files:**
- Modify: `scripts/effects/attack_vfx.gd` (function `_process`, line ~51)

- [ ] **Step 1: Modify `_process()`**

Current:
```gdscript
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		AttackVFX._active_count -= 1
		queue_free()
		return
	queue_redraw()
```

Replace with:
```gdscript
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		AttackVFX._active_count -= 1
		queue_free()
		return
	if not PerformanceFirebreak.disable_all_attack_vfx:
		queue_redraw()
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/attack_vfx.gd"
git commit -m "fix: skip queue_redraw in AttackVFX when firebreak active"
```

---

## Task 7: Guard ImpactEffect.setup()

**Files:**
- Modify: `scripts/effects/impact_effect.gd` (function `setup`, line ~10)

- [ ] **Step 1: Add guard at top of `setup()`**

Current start of `setup()`:
```gdscript
func setup(p_color: Color = Color.WHITE, scale_factor: float = 1.0, p_attack_type: String = "single", p_glow_color: Color = Color.WHITE, p_accent_color: Color = Color.WHITE) -> void:
	color = p_color
```

Replace start with:
```gdscript
func setup(p_color: Color = Color.WHITE, scale_factor: float = 1.0, p_attack_type: String = "single", p_glow_color: Color = Color.WHITE, p_accent_color: Color = Color.WHITE) -> void:
	if PerformanceFirebreak.disable_impact_effects:
		_on_expire()
		return
	color = p_color
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/impact_effect.gd"
git commit -m "fix: skip ImpactEffect.setup when disable_impact_effects flag set"
```

---

## Task 8: Guard DeathPopEffect._ready()

**Files:**
- Modify: `scripts/effects/death_pop_effect.gd` (function `_ready`, line ~19)

- [ ] **Step 1: Add guard at top of `_ready()`**

Current start of `_ready()`:
```gdscript
func _ready() -> void:
	# Hide legacy ColorRect if it exists
	var rect = get_node_or_null("ColorRect")
```

Replace start with:
```gdscript
func _ready() -> void:
	if PerformanceFirebreak.disable_death_effects:
		queue_free()
		return
	# Hide legacy ColorRect if it exists
	var rect = get_node_or_null("ColorRect")
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/death_pop_effect.gd"
git commit -m "fix: skip DeathPopEffect when disable_death_effects flag set"
```

---

## Task 9: Guard DamageNumber._ready()

**Files:**
- Modify: `scripts/effects/damage_number.gd` (function `_ready`, line ~28)

- [ ] **Step 1: Add guard at top of `_ready()`**

Current start of `_ready()`:
```gdscript
func _ready() -> void:
	DamageNumber._active_count += 1
	if label == null:
```

Replace start with:
```gdscript
func _ready() -> void:
	if PerformanceFirebreak.disable_damage_numbers:
		queue_free()
		return
	DamageNumber._active_count += 1
	if label == null:
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/damage_number.gd"
git commit -m "fix: skip DamageNumber when disable_damage_numbers flag set"
```

---

## Task 10: Guard CreepStatusVFX._process() redraws

**Files:**
- Modify: `scripts/effects/creep_status_vfx.gd` (function `_process`, around line 54)

- [ ] **Step 1: Wrap the visible/redraw block**

Current in `_process()`:
```gdscript
	if visible:
		_redraw_timer -= delta
		if _redraw_timer <= 0.0:
			_redraw_timer = ACTIVE_REDRAW_INTERVAL
			queue_redraw()
```

Replace with:
```gdscript
	if visible and not PerformanceFirebreak.disable_status_animations:
		_redraw_timer -= delta
		if _redraw_timer <= 0.0:
			_redraw_timer = ACTIVE_REDRAW_INTERVAL
			queue_redraw()
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/creep_status_vfx.gd"
git commit -m "fix: skip CreepStatusVFX redraws when disable_status_animations set"
```

---

## Task 11: Guard EnemyStatusIconVFX._process() redraws

**Files:**
- Modify: `scripts/effects/enemy_status_icon_vfx.gd` (function `_process`, line ~20)

- [ ] **Step 1: Wrap redraw trigger**

Current:
```gdscript
func _process(delta: float) -> void:
	time += delta
	redraw_elapsed += delta
	if redraw_elapsed >= REDRAW_INTERVAL:
		redraw_elapsed = 0.0
		queue_redraw()
```

Replace with:
```gdscript
func _process(delta: float) -> void:
	time += delta
	if PerformanceFirebreak.disable_status_animations:
		return
	redraw_elapsed += delta
	if redraw_elapsed >= REDRAW_INTERVAL:
		redraw_elapsed = 0.0
		queue_redraw()
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/effects/enemy_status_icon_vfx.gd"
git commit -m "fix: skip EnemyStatusIconVFX redraws when disable_status_animations set"
```

---

## Task 12: Guard TowerCatalogPreview.PreviewFxLayer._process()

**Files:**
- Modify: `scripts/towers/tower_catalog_preview.gd` (inner class `PreviewFxLayer._process()`, line ~52)

This is the catalog's cosmetic preview layer that calls `queue_redraw()` every frame.

- [ ] **Step 1: Guard the entire body of PreviewFxLayer._process()**

Current:
```gdscript
	func _process(delta: float) -> void:
		if paused:
			return
		_pulse_time += delta
		if _is_support_style():
			queue_redraw()
			return
		if preview_projectile:
```

Replace with:
```gdscript
	func _process(delta: float) -> void:
		if paused or PerformanceFirebreak.disable_catalog_vfx:
			return
		_pulse_time += delta
		if _is_support_style():
			queue_redraw()
			return
		if preview_projectile:
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/towers/tower_catalog_preview.gd"
git commit -m "fix: disable catalog PreviewFxLayer._process when disable_catalog_vfx set"
```

---

## Task 13: Guard projectile._spawn_impact_effect()

**Files:**
- Modify: `scripts/projectiles/projectile.gd` (function `_spawn_impact_effect`, line ~458)

- [ ] **Step 1: Add guard at top of `_spawn_impact_effect()`**

Find:
```gdscript
func _spawn_impact_effect(hit_pos: Vector2, color: Color = Color.WHITE, hit_angle: float = 0.0) -> void:
```

Add as first line of the function body:
```gdscript
func _spawn_impact_effect(hit_pos: Vector2, color: Color = Color.WHITE, hit_angle: float = 0.0) -> void:
	if PerformanceFirebreak.disable_impact_effects:
		return
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/projectiles/projectile.gd"
git commit -m "fix: skip projectile impact effect when disable_impact_effects set"
```

---

## Task 14: Guard enemy.spawn_damage_number()

**Files:**
- Modify: `scripts/enemies/enemy.gd` (function `spawn_damage_number`, line ~2534)

- [ ] **Step 1: Add guard at top of `spawn_damage_number()`**

Find:
```gdscript
func spawn_damage_number(amount: int, hit_global: Vector2, color: Color = Color.WHITE, source_id: String = "") -> void:
```

Add as first line:
```gdscript
func spawn_damage_number(amount: int, hit_global: Vector2, color: Color = Color.WHITE, source_id: String = "") -> void:
	if PerformanceFirebreak.disable_damage_numbers:
		return
```

- [ ] **Step 2: Commit**

```bash
git add "scripts/enemies/enemy.gd"
git commit -m "fix: skip damage numbers when disable_damage_numbers flag set"
```

---

## Task 15: Guard projectile.gd damage number spawn

**Files:**
- Modify: `scripts/projectiles/projectile.gd` (line ~633, where `damage_number_scene.instantiate()` is called)

- [ ] **Step 1: Find and guard the instantiate call**

Find the block (around line 630):
```gdscript
	var effect = damage_number_scene.instantiate()
```

Wrap the entire damage number spawn block with:
```gdscript
	if not PerformanceFirebreak.disable_damage_numbers:
		var effect = damage_number_scene.instantiate()
		# ... rest of existing spawn code
```

Read the surrounding context first to ensure you wrap the full block correctly — it likely ends with `add_child(effect)` and a `setup()` call.

- [ ] **Step 2: Commit**

```bash
git add "scripts/projectiles/projectile.gd"
git commit -m "fix: skip projectile damage number spawn when disable_damage_numbers set"
```

---

## Task 16: Guard enemy death pop spawn

**Files:**
- Modify: `scripts/enemies/enemy.gd` (lines ~2617 and ~2669, two death_pop_scene.instantiate() calls)

- [ ] **Step 1: Find both death pop instantiate calls and wrap each one**

Find line ~2617:
```gdscript
		var effect = death_pop_scene.instantiate()
```
Wrap with:
```gdscript
	if not PerformanceFirebreak.disable_death_effects:
		var effect = death_pop_scene.instantiate()
		# ... rest of spawn block until end of that code path
```

Find line ~2669:
```gdscript
	var effect = death_pop_scene.instantiate()
```
Wrap with:
```gdscript
	if not PerformanceFirebreak.disable_death_effects:
		var effect = death_pop_scene.instantiate()
		# ... rest of spawn block
```

Read `enemy.gd` around lines 2610-2690 to find the full extent of each block before editing.

- [ ] **Step 2: Commit**

```bash
git add "scripts/enemies/enemy.gd"
git commit -m "fix: skip death pop effect spawns when disable_death_effects set"
```

---

## Task 17: Verify firebreak works — VFX count stays 0

- [ ] **Step 1: Run the game**

Open Godot → Play (`F5`). Check that `PerformanceFirebreak.enabled` is `true` (it defaults to `true`).

- [ ] **Step 2: Check active VFX count**

In the Godot debugger, add a watch expression:
```
get_tree().get_nodes_in_group("attack_vfx").size()
```
Or run gameplay for 60 seconds and confirm no nodes appear in the group.

Expected: `0` while `disable_all_attack_vfx = true`.

- [ ] **Step 3: Check spike logger output**

In the Output panel, look for `[SPIKE]` lines. Note the delta and fps values.

- [ ] **Step 4: If VFX nodes still appear, grep for any unguarded spawn site**

```bash
grep -rn "attack_vfx\|AttackVFX\|spawn_attack\|TowerAttackVFX" scripts/ --include="*.gd" | grep -v "PerformanceFirebreak\|#"
```

Any hit that instantiates or spawns a VFX node without checking `PerformanceFirebreak` first is a bug — add the guard.

- [ ] **Step 5: Commit if any fixes were needed**

```bash
git add -p
git commit -m "fix: close unguarded VFX spawn sites found in verification"
```

---

## Task 18: Re-enable visuals one group at a time (after stable 60 FPS confirmed)

**Do not start this task until Task 17 shows stable 60 FPS in the Debugger.**

Re-enable in this order only, one at a time, with a 60-second stability check between each:

- [ ] **Step 1: Enable selected-tower attack preview only**

In `PerformanceFirebreak`:
```gdscript
static var disable_all_attack_vfx := false   # re-enable
static var disable_catalog_vfx := true        # keep off
```

Also update `TowerAttackVFXService.spawn()` to check if the tower is selected before spawning (look for a `selected` property or `is_selected()` method on the tower node — guard with that instead of the blanket flag).

Run for 60 seconds. If FPS stays ≥ 55, proceed.

- [ ] **Step 2: Enable cheap hit flash**

```gdscript
static var disable_impact_effects := false
```

Run for 60 seconds. If FPS stays ≥ 55, proceed.

- [ ] **Step 3: Enable status tint/icon**

```gdscript
static var disable_status_animations := false
```

Run for 60 seconds. If FPS stays ≥ 55, proceed.

- [ ] **Step 4: Enable limited death effects**

```gdscript
static var disable_death_effects := false
```

Run for 60 seconds. Check FPS.

- [ ] **Step 5: Commit final stable configuration**

```bash
git add "scripts/services/performance_firebreak.gd"
git commit -m "feat: re-enable stable VFX groups after firebreak verification"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Task 1 — global emergency performance flag with all required static vars
- ✅ Tasks 3–16 — firebreak guards at every VFX entry point listed in spec
- ✅ Task 12 — catalog `PreviewFxLayer._process()` fully guarded
- ✅ Task 2 — spike logger with cooldown and compact output format
- ✅ Task 17 — verification step (measurement is manual — Godot has no scripted profiler output)
- ✅ Task 18 — incremental re-enable order matches spec exactly
- ⚠️ Spec step 4 (kill repeated errors): not covered by this plan — that's a separate investigation requiring the Godot debugger error list, which varies by run. Recommend doing this in parallel while applying the firebreak.
- ⚠️ Spec step 6 (audit queue_redraw in UI scripts): UI redraw calls in `build_section_header.gd`, `element_icon.gd`, `hud_stat_chip.gd`, etc. are in property setters — they only fire on value change, which is already correct. No changes needed unless profiling shows them in the hot path.
- ⚠️ Spec step 7 (freeze heavy UI rebuilds): `tower_catalog.gd._build_catalog()` runs once in `_ready()`, not on every frame — already correct. `_open_detail_overlay()` rebuilds on click — acceptable.

**Placeholder scan:** No TBD or placeholder text found.

**Type consistency:** `PerformanceFirebreak` class name used consistently across all tasks. `disable_all_attack_vfx`, `disable_catalog_vfx`, etc. match the flag names defined in Task 1.
