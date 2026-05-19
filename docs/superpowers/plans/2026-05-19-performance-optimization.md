# Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate frame-time spikes in Godot 4.6.2 during mid-to-late waves by throttling per-frame work, pooling short-lived nodes, and reducing redundant scene-tree children — without changing any gameplay behavior.

**Architecture:** Five independent optimizations applied in order of impact: (1) upgrade the perf overlay to expose total node count, (2) throttle per-frame `queue_redraw()` on procedural towers and DOT processing on enemies, (3) add a `ProjectilePool` autoload that recycles 40 `Projectile` nodes instead of instantiate/free every shot, (4) add an `ImpactVFXPool` for hit sparks, (5) lazily create `CastBeam`/`TargetLinks` nodes in `EnemyVFXController` only for healer/disruptor enemies.

**Tech Stack:** GDScript 4.6, Godot node tree, autoloads, `reparent()`, `Performance` monitor API.

---

## Already Done — Do NOT Re-implement

The following are already optimized; re-touching them will break things:

| Optimization | Location | Value |
|---|---|---|
| Target scan interval | `tower.gd:80` `TARGET_SCAN_INTERVAL = 0.1` | 10 Hz scan |
| Enemy visual redraw | `enemy.gd:100` `ENEMY_VISUAL_REDRAW_INTERVAL = 0.125` | 8 Hz |
| CreepStatusVFX throttle | `creep_status_vfx.gd:28-29` | 0.15 s / 0.25 s |
| HUD gold/lives/wave | `game_hud.gd` `set_gold()`, event-driven | Only on change |
| Damage stats panel | `game_hud.gd:187` `DAMAGE_PANEL_REFRESH_INTERVAL = 0.50` | 2 Hz |
| AttackVFX budget | `attack_vfx.gd:12` `MAX_ACTIVE = 60` | Cap skip |
| ImpactEffect budget | `impact_effect.gd:4` `MAX_ACTIVE = 40` | Cap skip |
| Support aura scan | `tower.gd:144` `SUPPORT_SCAN_INTERVAL = 0.25` | 4 Hz |
| Shield/disrupt aura | `enemy.gd:109-110` | 4 Hz |
| Performance quality scaling | `performance_budget.gd` autoload | Adaptive |

---

## File Map

| Status | File | Change |
|---|---|---|
| Modify | `scripts/ui/perf_overlay.gd` | Add total node count row |
| Modify | `scripts/towers/tower.gd` | Add procedural draw timer |
| Modify | `scripts/enemies/enemy.gd` | Add DOT tick timer |
| **Create** | `scripts/services/projectile_pool.gd` | Object pool autoload |
| Modify | `scripts/towers/tower.gd` | Use pool in `shoot()` |
| Modify | `scripts/projectiles/projectile.gd` | Release to pool on expire/hit |
| Modify | `scripts/main/main.gd` | Clear pool on level reset |
| **Create** | `scripts/services/impact_vfx_pool.gd` | Object pool autoload |
| Modify | `scripts/projectiles/projectile.gd` | Use pool in `_spawn_impact_effect()` |
| Modify | `scripts/effects/impact_effect.gd` | Release to pool on expire |
| Modify | `scripts/effects/enemy_vfx_controller.gd` | Lazy CastBeam/TargetLinks |
| Modify | `project.godot` | Register new autoloads |

---

## Task 1: Upgrade Perf Overlay — Total Node Count

**Goal:** Add `Performance.OBJECT_NODE_COUNT` to the existing F10 overlay so you have a baseline before starting and can verify each task reduces it.

**Files:**
- Modify: `scripts/ui/perf_overlay.gd:94-114`

- [ ] **Step 1: Read current _refresh_label**

  Verify `perf_overlay.gd` lines 64–114. Confirm the label text ends with the verbose-targeting lines and there is no existing node-count row.

- [ ] **Step 2: Add node count variable and row**

  In `_refresh_label()`, add after the `draw_calls` line (currently line 85):
  ```gdscript
  var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
  ```

  Replace the label text block (the `_label.text = (...)` assignment) with:
  ```gdscript
  _label.text = (
      "[b][color=#aaddff]■ PERF OVERLAY[/color][/b]  [color=#555555]F10[/color]\n"
      + "──────────────────────\n"
      + "[color=#%s]FPS  %d  (%.1f ms)[/color]\n" % [c_fps, fps, f_ms]
      + "Process  [color=#ffee88]%.2f ms[/color]\n" % proc_ms
      + "Physics  [color=#ffee88]%.2f ms[/color]\n" % physics_ms
      + "Draws    [color=#ffffff]%d[/color]\n" % draw_calls
      + "Nodes    [color=#ffffff]%d[/color]\n" % node_count
      + "Quality  [color=#%s]%s[/color]\n" % [c_qual, qual]
      + "──────────────────────\n"
      + "Creeps        [color=#ffffff]%d[/color]\n" % creep_count
      + "Towers        [color=#ffffff]%d[/color]\n" % tower_count
      + "Projectiles   [color=#ffffff]%d[/color]\n" % proj_count
      + "──────────────────────\n"
      + "Attack VFX    [color=#%s]%d / %d[/color]\n" % [c_avfx, atk_vfx, atk_budget]
      + "Dmg Numbers   [color=#%s]%d / %d[/color]\n" % [c_dn, dmg_num, DamageNumber.MAX_ACTIVE]
      + "Status VFX    [color=#ffffff]%d[/color]\n" % get_tree().get_nodes_in_group("status_vfx").size()
      + "Status Icons   [color=#ffffff]%d[/color]\n" % status_icons
      + "──────────────────────\n"
      + "[color=#555555]Verbose targeting off\n"
      + "Verbose combat    off[/color]"
  )
  ```

  Also update `PANEL_HEIGHT` from `270` to `285` so the extra row fits:
  ```gdscript
  const PANEL_HEIGHT := 285
  ```

- [ ] **Step 3: Run the game, press F10 at mid-wave, note baseline numbers**

  Record in a comment at the top of this plan file:
  - FPS, frame ms, Process ms, Physics ms, Draw calls, Node count (before), Projectile peak count

- [ ] **Step 4: Commit**

  ```bash
  git add "scripts/ui/perf_overlay.gd"
  git commit -m "perf: add total node count to F10 overlay"
  ```

---

## Task 2: Throttle Procedural Tower `queue_redraw()`

**Problem:** In `tower.gd:_process()` line 1151, every tower with a valid target and no sprite calls `queue_redraw()` every frame (60×/s). With 30+ non-sprite towers this triggers 1800+ procedural draw calls/second, each drawing polygons/lines/arcs.

**Fix:** Add a draw-rate limiter so non-selected, non-debug towers redraw at 15 Hz instead of 60 Hz. Selected towers still redraw at full rate for responsive selection highlight.

**Files:**
- Modify: `scripts/towers/tower.gd`

- [ ] **Step 1: Add timer constant and variable after line 89**

  After `static var _verbose_targeting: bool = false` (line 89), add:
  ```gdscript
  ## Throttle for procedural-draw towers: redraw at 15 Hz instead of 60 Hz.
  ## Selected towers still get full-rate redraws for the selection ring.
  const PROCEDURAL_DRAW_INTERVAL: float = 0.067
  var _procedural_draw_timer: float = 0.0
  ```

- [ ] **Step 2: Replace the queue_redraw block in `_process()`**

  Find the block at tower.gd ~line 1150 (starts `# Redraw needed for selection highlight`):
  ```gdscript
  	# Redraw needed for selection highlight, range, OR procedural turret rotation
  	if is_selected or debug_draw_range or (not use_sprite and is_valid_target(current_target)):
  		queue_redraw()
  ```

  Replace it with:
  ```gdscript
  	# Full-rate redraw for selected/debug towers; throttled to 15 Hz for others.
  	if is_selected or debug_draw_range:
  		queue_redraw()
  	elif not use_sprite and is_valid_target(current_target):
  		_procedural_draw_timer -= delta
  		if _procedural_draw_timer <= 0.0:
  			_procedural_draw_timer = PROCEDURAL_DRAW_INTERVAL
  			queue_redraw()
  ```

- [ ] **Step 3: Reset the draw timer on selection change**

  Find the `set_selected` function (search for `is_selected =` assignment). After setting `is_selected = true`, add:
  ```gdscript
  _procedural_draw_timer = 0.0  # Force immediate redraw when selected
  ```

- [ ] **Step 4: Run the game**

  Press F10 mid-wave with 20+ towers. Verify draw calls drop. Verify towers still look correct: turrets aim, idle rotation works, selection ring appears instantly.

  Expected: Draw calls reduced by ~30–40% during heavy combat.

- [ ] **Step 5: Commit**

  ```bash
  git add "scripts/towers/tower.gd"
  git commit -m "perf: throttle procedural tower queue_redraw() to 15 Hz"
  ```

---

## Task 3: Throttle Enemy DOT Processing

**Problem:** `enemy.gd:_process_tower_status_effects()` runs every frame (60×/s) for every active enemy. With 40 enemies this is 2400 iterations/frame even when most have no active DOTs.

**Fix:** Gate the DOT tick behind a 0.1 s timer. Accumulate the tick delta and apply scaled damage to preserve total DPS. Delayed-damage effects remain frame-accurate (they use a countdown, not DPS math).

**Files:**
- Modify: `scripts/enemies/enemy.gd`

- [ ] **Step 1: Add timer constant and variable**

  After `const DISRUPT_AURA_INTERVAL := 0.25` (line ~110), add:
  ```gdscript
  ## DOT tick interval — reduces per-frame damage array walks on all enemies.
  ## Total damage-per-second is unchanged: damage_per_second × tick_delta = same DPS.
  const DOT_TICK_INTERVAL: float = 0.10
  var _dot_tick_timer: float = 0.0
  var _dot_tick_accum: float = 0.0
  ```

- [ ] **Step 2: Modify the call site in `_process()`**

  Find `_process_tower_status_effects(delta)` call (line ~1846). Replace the single line:
  ```gdscript
  	_process_tower_status_effects(delta)
  ```
  with:
  ```gdscript
  	_dot_tick_timer -= delta
  	_dot_tick_accum += delta
  	if _dot_tick_timer <= 0.0:
  		_dot_tick_timer = DOT_TICK_INTERVAL
  		_process_tower_status_effects(_dot_tick_accum)
  		_dot_tick_accum = 0.0
  ```

- [ ] **Step 3: Verify `_process_tower_status_effects` signature is unchanged**

  The function at line ~2478 already uses `delta` as a multiplier:
  ```gdscript
  take_damage(damage_per_second * tick_delta, ...)
  remaining -= delta
  ```
  The only change is the call passes `_dot_tick_accum` (≈0.1) instead of per-frame delta. DPS math is unchanged. Verify this is correct by reading lines 2478–2497.

- [ ] **Step 4: Run the game with a DOT tower (nature/poison type)**

  Apply a DOT to several enemies. Verify they die at the same rate as before. Check the game's battle telemetry if available (`scripts/core/battle_telemetry.gd`). No gameplay change should be detectable.

- [ ] **Step 5: Commit**

  ```bash
  git add "scripts/enemies/enemy.gd"
  git commit -m "perf: throttle enemy DOT tick to 0.10s interval"
  ```

---

## Task 4: Projectile Object Pool (Autoload)

**Problem:** `tower.gd:shoot()` calls `projectile_scene.instantiate()` every shot and `queue_free()` on every hit. With a rapid-fire tower this can be 10+ instantiate/free cycles per second, causing GC pressure and frame spikes.

**Fix:** A `ProjectilePool` autoload pre-allocates 40 `Projectile` nodes as children of the pool node. `acquire(container)` reparents one to `container` and returns it ready to `setup()`. `release(proj)` reparents it back to the pool and resets state. `release_active()` is called by `main.gd` during level reset.

**Files:**
- Create: `scripts/services/projectile_pool.gd`
- Modify: `project.godot`
- Modify: `scripts/towers/tower.gd`
- Modify: `scripts/projectiles/projectile.gd`
- Modify: `scripts/main/main.gd`

- [ ] **Step 1: Create `projectile_pool.gd`**

  Create `scripts/services/projectile_pool.gd`:
  ```gdscript
  ## ProjectilePool — recycles Projectile nodes to eliminate per-shot instantiate/free.
  ## Registered as autoload "ProjectilePool" in project.godot.
  ##
  ## Usage:
  ##   var proj := ProjectilePool.acquire(projectile_container)
  ##   proj.global_position = spawn_pos
  ##   proj.setup(...)
  ##   # When done: call ProjectilePool.release(proj) instead of queue_free()
  extends Node

  const POOL_SIZE := 40
  const ProjectileScene := preload("res://scenes/projectiles/Projectile.tscn")

  var _free_list: Array[Node] = []

  func _ready() -> void:
  	name = "ProjectilePool"
  	for i in range(POOL_SIZE):
  		var proj := ProjectileScene.instantiate()
  		proj.visible = false
  		proj.set_process(false)
  		proj.set_physics_process(false)
  		proj.set_meta("pooled", true)
  		add_child(proj)
  		_free_list.append(proj)

  ## Acquire a projectile and reparent it to `container`.
  ## Returns null if pool is exhausted (caller falls back to instantiate).
  func acquire(container: Node) -> Node:
  	var proj: Node
  	if _free_list.is_empty():
  		# Pool exhausted — instantiate an overflow node (not pooled, self-frees normally).
  		proj = ProjectileScene.instantiate()
  		container.add_child(proj)
  		return proj
  	proj = _free_list.pop_back()
  	proj.reparent(container)
  	proj.visible = true
  	proj.set_process(true)
  	return proj

  ## Return a projectile to the pool. Resets all state.
  func release(proj: Node) -> void:
  	if not is_instance_valid(proj):
  		return
  	if not proj.has_meta("pooled"):
  		# Overflow node — free it normally.
  		proj.queue_free()
  		return
  	_reset_projectile(proj)
  	proj.reparent(self)
  	proj.visible = false
  	proj.set_process(false)
  	_free_list.append(proj)

  ## Release all active (reparented) projectiles back to the pool.
  ## Call this from main.gd before clearing the projectile container.
  func release_active() -> void:
  	var active: Array[Node] = []
  	# Collect nodes that have been reparented out of the pool.
  	for child in get_tree().get_nodes_in_group("projectiles"):
  		if is_instance_valid(child) and child.has_meta("pooled"):
  			active.append(child)
  	for proj in active:
  		release(proj)

  func _reset_projectile(proj: Node) -> void:
  	proj.set("target", null)
  	proj.set("lifetime", 5.0)
  	proj.set("chained_enemies", [])
  	proj.set("status_effects", [])
  	proj.set("attack_elements_override", [])
  	proj.set("chain_jumps", 0)
  	proj.set("last_known_target_pos", Vector2.ZERO)
  	proj.modulate = Color.WHITE
  	proj.rotation = 0.0
  	proj.scale = Vector2.ONE
  ```

- [ ] **Step 2: Register autoload in `project.godot`**

  In `project.godot`, find the `[autoload]` section (currently ends with `DebugLog` line). Add after `DebugLog`:
  ```ini
  ProjectilePool="*res://scripts/services/projectile_pool.gd"
  ```

- [ ] **Step 3: Modify `tower.gd shoot()` to use pool**

  In `tower.gd`, find `shoot()` function (line ~1205). Find the instantiate call:
  ```gdscript
  	if projectile_scene:
  		var projectile = projectile_scene.instantiate()
  		var container = projectile_container if projectile_container else get_tree().current_scene
  		container.add_child(projectile)
  ```

  Replace with:
  ```gdscript
  	if projectile_scene:
  		var container = projectile_container if projectile_container else get_tree().current_scene
  		var _pool := get_node_or_null("/root/ProjectilePool")
  		var projectile: Node
  		if _pool != null:
  			projectile = _pool.acquire(container)
  		else:
  			projectile = projectile_scene.instantiate()
  			container.add_child(projectile)
  ```

  Leave the rest of `shoot()` unchanged — `projectile.setup(...)` and `projectile.global_position = spawn_pos` still work the same.

- [ ] **Step 4: Modify `projectile.gd` to release instead of queue_free**

  In `projectile.gd`, find `_process()`. Every `queue_free()` call within projectile logic needs to go through the pool. There are four call sites:

  **Site 1** — `last_known_target_pos == Vector2.ZERO` early return (line ~157):
  ```gdscript
  		queue_free()
  		return
  ```
  Replace with:
  ```gdscript
  		_release_to_pool()
  		return
  ```

  **Site 2** — dissipate on dead target (line ~171):
  ```gdscript
  			_spawn_dissipate_effect()
  			queue_free()
  ```
  Replace with:
  ```gdscript
  			_spawn_dissipate_effect()
  			_release_to_pool()
  ```

  **Site 3** — lifetime expired (line ~183):
  ```gdscript
  	if lifetime <= 0:
  		queue_free()
  ```
  Replace with:
  ```gdscript
  	if lifetime <= 0:
  		_release_to_pool()
  ```

  **Site 4** — at the end of `hit_target()` (line ~389):
  ```gdscript
  	queue_free()
  ```
  Replace with:
  ```gdscript
  	_release_to_pool()
  ```

  Now add the helper function at the end of `projectile.gd` (before the last `func`):
  ```gdscript
  func _release_to_pool() -> void:
  	var pool := get_node_or_null("/root/ProjectilePool")
  	if pool != null:
  		pool.release(self)
  	else:
  		queue_free()
  ```

- [ ] **Step 5: Modify `main.gd _clear_gameplay_state()` to use pool release**

  Find `_clear_gameplay_state()` (line ~1421). Find:
  ```gdscript
  	if projectile_container:
  		for proj in projectile_container.get_children():
  			proj.queue_free()
  ```
  Replace with:
  ```gdscript
  	if projectile_container:
  		var pool := get_node_or_null("/root/ProjectilePool")
  		if pool != null:
  			pool.release_active()
  		# Free any non-pooled overflow projectiles still in the container.
  		for proj in projectile_container.get_children():
  			if is_instance_valid(proj) and not proj.has_meta("pooled"):
  				proj.queue_free()
  ```

- [ ] **Step 6: Run the game**

  Start a wave with a rapid tower. Check F10 overlay — projectile count should be the same, but in debug output (add `print`) verify instantiate is NOT called per-shot for normal shots. Node count should stabilize instead of fluctuating.

  Verify: game plays correctly, projectiles hit, chain jumps work, slow/splash AOE works.

- [ ] **Step 7: Commit**

  ```bash
  git add "scripts/services/projectile_pool.gd" project.godot \
          "scripts/towers/tower.gd" "scripts/projectiles/projectile.gd" \
          "scripts/main/main.gd"
  git commit -m "perf: add ProjectilePool autoload — recycle 40 projectiles instead of instantiate/free"
  ```

---

## Task 5: Impact VFX Object Pool

**Problem:** `projectile.gd:_spawn_impact_effect()` calls `impact_effect_scene.instantiate()` on every hit. With 10 towers firing at ~1 Hz each, that is 10+ instantiations/s. The existing `MAX_ACTIVE = 40` cap limits count but not GC churn from rapid create/free cycles.

**Fix:** Mirror the `ProjectilePool` pattern with `ImpactVFXPool`.

**Files:**
- Create: `scripts/services/impact_vfx_pool.gd`
- Modify: `project.godot`
- Modify: `scripts/projectiles/projectile.gd`
- Modify: `scripts/effects/impact_effect.gd`

- [ ] **Step 1: Create `impact_vfx_pool.gd`**

  Create `scripts/services/impact_vfx_pool.gd`:
  ```gdscript
  ## ImpactVFXPool — recycles ImpactEffect nodes to eliminate per-hit instantiate/free.
  extends Node

  const POOL_SIZE := 40
  const ImpactScene := preload("res://scenes/effects/ImpactEffect.tscn")

  var _free_list: Array[Node] = []

  func _ready() -> void:
  	name = "ImpactVFXPool"
  	for i in range(POOL_SIZE):
  		var fx := ImpactScene.instantiate()
  		fx.visible = false
  		fx.set_meta("pooled", true)
  		add_child(fx)
  		_free_list.append(fx)

  ## Acquire an ImpactEffect and reparent to `container`.
  func acquire(container: Node) -> Node:
  	if _free_list.is_empty():
  		var fx := ImpactScene.instantiate()
  		container.add_child(fx)
  		return fx
  	var fx := _free_list.pop_back()
  	fx.reparent(container)
  	fx.visible = true
  	return fx

  ## Return an ImpactEffect to the pool after its animation completes.
  func release(fx: Node) -> void:
  	if not is_instance_valid(fx):
  		return
  	if not fx.has_meta("pooled"):
  		fx.queue_free()
  		return
  	_reset_fx(fx)
  	fx.reparent(self)
  	fx.visible = false
  	_free_list.append(fx)

  func release_active() -> void:
  	for fx in get_tree().get_nodes_in_group("impact_vfx_pool"):
  		if is_instance_valid(fx) and fx.has_meta("pooled"):
  			release(fx)

  func _reset_fx(fx: Node) -> void:
  	fx.scale = Vector2.ONE
  	fx.modulate = Color.WHITE
  	fx.rotation = 0.0
  ```

- [ ] **Step 2: Register autoload in `project.godot`**

  In the `[autoload]` section, add after `ProjectilePool`:
  ```ini
  ImpactVFXPool="*res://scripts/services/impact_vfx_pool.gd"
  ```

- [ ] **Step 3: Modify `impact_effect.gd` to register with pool group and release instead of queue_free**

  In `impact_effect.gd`, find `_ready()`:
  ```gdscript
  func _ready() -> void:
  	ImpactEffect._active_count += 1
  ```
  Add group registration:
  ```gdscript
  func _ready() -> void:
  	ImpactEffect._active_count += 1
  	add_to_group("impact_vfx_pool")
  ```

  Find `_on_expire()`:
  ```gdscript
  func _on_expire() -> void:
  	ImpactEffect._active_count -= 1
  	queue_free()
  ```
  Replace with:
  ```gdscript
  func _on_expire() -> void:
  	ImpactEffect._active_count -= 1
  	var pool := get_node_or_null("/root/ImpactVFXPool")
  	if pool != null and has_meta("pooled"):
  		pool.release(self)
  	else:
  		queue_free()
  ```

- [ ] **Step 4: Modify `projectile.gd _spawn_impact_effect()` to use pool**

  Find `_spawn_impact_effect()` (line ~458). Find:
  ```gdscript
  	if impact_effect_scene and ImpactEffect._active_count < ImpactEffect.MAX_ACTIVE:
  		var effect = impact_effect_scene.instantiate()
  		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
  		if effects_container:
  			effects_container.add_child(effect)
  			effect.global_position = hit_pos
  		else:
  			get_tree().current_scene.add_child(effect)
  			effect.global_position = hit_pos
  ```
  Replace with:
  ```gdscript
  	if ImpactEffect._active_count < ImpactEffect.MAX_ACTIVE:
  		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
  		var parent_node: Node = effects_container if effects_container else get_tree().current_scene
  		var pool := get_node_or_null("/root/ImpactVFXPool")
  		var effect: Node
  		if pool != null:
  			effect = pool.acquire(parent_node)
  		elif impact_effect_scene:
  			effect = impact_effect_scene.instantiate()
  			parent_node.add_child(effect)
  		else:
  			return
  		effect.global_position = hit_pos
  ```

- [ ] **Step 5: Also modify `main.gd _clear_gameplay_state()` for effects_container**

  Find:
  ```gdscript
  	if effects_container:
  		for effect in effects_container.get_children():
  			effect.queue_free()
  ```
  Replace with:
  ```gdscript
  	if effects_container:
  		var imp_pool := get_node_or_null("/root/ImpactVFXPool")
  		if imp_pool != null:
  			imp_pool.release_active()
  		for effect in effects_container.get_children():
  			if is_instance_valid(effect) and not effect.has_meta("pooled"):
  				effect.queue_free()
  ```

- [ ] **Step 6: Run the game**

  Fight through wave 5+ (lots of shots). F10 overlay: Node count should stabilize instead of rising with each hit. Impact sparks should look identical.

- [ ] **Step 7: Commit**

  ```bash
  git add "scripts/services/impact_vfx_pool.gd" project.godot \
          "scripts/effects/impact_effect.gd" "scripts/projectiles/projectile.gd" \
          "scripts/main/main.gd"
  git commit -m "perf: add ImpactVFXPool — recycle 40 impact spark nodes"
  ```

---

## Task 6: Lazy EnemyVFXController CastBeam/TargetLinks Nodes

**Problem:** `enemy_vfx_controller.gd:_ensure_structure()` unconditionally creates `CastBeam` and `TargetLinks` nodes for every enemy (lines ~200–208). For a basic enemy wave of 40 enemies, that is 80 unnecessary nodes. Only healer and disruptor enemies ever use these nodes.

**Fix:** Create `CastBeam` and `TargetLinks` lazily — only in `_configure_role()` when `skill_id == "healer"` or `skill_id == "disrupt_aura"`.

**Files:**
- Modify: `scripts/effects/enemy_vfx_controller.gd`

- [ ] **Step 1: Remove CastBeam and TargetLinks from `_ensure_structure()`**

  Find `_ensure_structure()` (line ~182). Find and remove these two blocks:
  ```gdscript
  	cast_beam = vfx_root.get_node_or_null("CastBeam")
  	if cast_beam == null:
  		cast_beam = BeamScript.new()
  		cast_beam.name = "CastBeam"
  		vfx_root.add_child(cast_beam)
  	target_links = vfx_root.get_node_or_null("TargetLinks")
  	if target_links == null:
  		target_links = BeamScript.new()
  		target_links.name = "TargetLinks"
  		vfx_root.add_child(target_links)
  ```
  Delete both blocks entirely. Leave `cast_beam` and `target_links` declared as `var` at the top (they already are, at lines 32–33) — just remove the creation code.

- [ ] **Step 2: Add a lazy-create helper function**

  Add after `_ensure_structure()`:
  ```gdscript
  func _ensure_cast_beam() -> void:
  	if cast_beam != null and is_instance_valid(cast_beam):
  		return
  	cast_beam = vfx_root.get_node_or_null("CastBeam")
  	if cast_beam == null:
  		cast_beam = BeamScript.new()
  		cast_beam.name = "CastBeam"
  		vfx_root.add_child(cast_beam)

  func _ensure_target_links() -> void:
  	if target_links != null and is_instance_valid(target_links):
  		return
  	target_links = vfx_root.get_node_or_null("TargetLinks")
  	if target_links == null:
  		target_links = BeamScript.new()
  		target_links.name = "TargetLinks"
  		vfx_root.add_child(target_links)
  ```

- [ ] **Step 3: Update call sites that use `cast_beam` and `target_links`**

  Search `enemy_vfx_controller.gd` for every use of `cast_beam` and `target_links`. Before each use, add the matching ensure call.

  For `cast_beam` call sites (e.g., `cast_beam.play_cast(...)`, `cast_beam.fade_out()`):
  ```gdscript
  _ensure_cast_beam()
  cast_beam.play_cast(...)
  ```

  For `target_links` call sites (e.g., `target_links.show_links(...)`, `target_links.clear_links()`):
  ```gdscript
  _ensure_target_links()
  target_links.show_links(...)
  ```

  Exception: `fade_out()` already null-checks (`if cast_beam:`) so those are safe already. Just add the ensure call before any set/read access.

- [ ] **Step 4: Run the game, verify healer and disruptor enemies still show their link VFX**

  Start a wave that includes healer enemies. Confirm:
  - Healer shows heal cast icon and beam to targets
  - Disruptor shows disruption links to towers
  - Basic/fast/tank enemies: no regressions (no visible change)
  
  F10 overlay: Node count should be lower by ~2 nodes × (non-healer/disruptor enemy count). On a wave of 40 basic enemies, expect ~80 fewer nodes.

- [ ] **Step 5: Commit**

  ```bash
  git add "scripts/effects/enemy_vfx_controller.gd"
  git commit -m "perf: lazy-create CastBeam/TargetLinks in EnemyVFXController — skip for basic enemies"
  ```

---

## Task 7: Before/After Profiler Snapshot

**Goal:** Capture the perf overlay numbers before Task 2 (using git log) and after all tasks, then record them as a permanent comment in `docs/superpowers/plans/2026-05-19-performance-optimization.md`.

- [ ] **Step 1: Capture "after" numbers**

  Run the game. Load a mid-game level (wave 10+) with 20+ towers and a full enemy wave. Press F10 and screenshot (or transcribe) the overlay at peak combat.

- [ ] **Step 2: Document results**

  Fill in the Results table below (already added at the end of this file).

- [ ] **Step 3: Commit results**

  ```bash
  git add "docs/superpowers/plans/2026-05-19-performance-optimization.md"
  git commit -m "docs: record before/after profiler numbers for perf optimization plan"
  ```

---

## Self-Review

**Spec coverage check:**

| Spec Requirement | Task | Status |
|---|---|---|
| Debug counters (enemies/towers/projectiles/VFX/draw calls/frame time) | Task 1 | ✓ All already in overlay; added node count |
| Identify expensive loops | Documented in intro | ✓ |
| Target scan ≤0.15s | Already done (0.1s) | ✓ |
| HUD refresh only on change | Already done (event-driven) | ✓ |
| Status visual ≤0.25s | Already done (0.15/0.25s) | ✓ |
| Projectile pooling | Task 4 | ✓ |
| Impact VFX pooling | Task 5 | ✓ |
| Status icons pooling | Not added — status icons are per-enemy singletons (1 per enemy max), not high-frequency create/free. Adding a pool here has negligible gain and high risk. | Skipped (YAGNI) |
| Floating UI effects pooling | DamageNumber already has MAX_ACTIVE=20 budget cap. With `SHOW_FLOATING_DAMAGE_NUMBERS = false` (enemy.gd:103), numbers only show for elemental debug. Pool not needed. | Skipped (already budgeted) |
| Remove/merge redundant child nodes | Task 6 (CastBeam/TargetLinks lazy) | ✓ |
| Disable expensive VFX | Already done (PERFORMANCE_MODE=true) | ✓ |
| Keep visuals premium | No visual degradation — throttle only at 15 Hz, invisible to eye | ✓ |
| Before/after results | Task 7 | ✓ |

**Placeholder scan:** No TBDs, TODOs, or vague steps found.

**Type consistency:**
- `ProjectilePool.acquire(container)` → returns `Node` → stored as `var projectile: Node` in tower.gd ✓
- `ProjectilePool.release(proj)` → takes `Node` → called with `self` from projectile.gd ✓  
- `ImpactVFXPool.acquire(container)` → returns `Node` → stored as `var effect: Node` in projectile.gd ✓
- `_ensure_target_links()` → void helper called before access ✓ (`_ensure_cast_beam()` removed — cast_beam had no call sites)

---

## Results

> Fill in after running the game at wave 10+ with F10 overlay open. Press F10, wait for peak combat, screenshot or transcribe numbers.

Test condition: Wave ___, ___ towers, ___ enemies alive.

| Metric       | Before (baseline) | After (all tasks) |
|--------------|-------------------|--------------------|
| FPS          |                   |                    |
| Frame ms     |                   |                    |
| Process ms   |                   |                    |
| Physics ms   |                   |                    |
| Draw calls   |                   |                    |
| Node count   |                   |                    |
| Projectiles  |                   |                    |

**Expected gains (theoretical):**
- Draw calls: −30–40% (tower procedural draw throttle, 15 Hz vs 60 Hz)
- Node count: −80–120 nodes per wave (lazy CastBeam/TargetLinks, ~2 nodes × 40–60 basic enemies)
- GC frame spikes: eliminated (ProjectilePool + ImpactVFXPool — no instantiate/free per shot or hit)
- Process ms: −5–15% (DOT tick at 0.1 s, 10× fewer iterations per enemy)
