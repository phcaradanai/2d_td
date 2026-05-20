# Targeting Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce tower targeting cost by making scans staggered, cache-backed, and bucketed while preserving the same target selection outcome.

**Architecture:** Keep the tower decision rules in `scripts/towers/tower.gd`, but move enemy discovery into a small spatial cache service keyed by `grid_size`. Towers will retarget on staggered intervals based on tower speed class and instance id, query only nearby buckets, then run the existing exact validation and scoring pass on the smaller candidate list. Telemetry will count scans and candidates in `PerformanceBudget` and display them in `PerfOverlay`.

**Tech Stack:** Godot 4.6 GDScript, autoload services, existing debug/perf overlay.

---

### Task 1: Add the spatial targeting cache service

**Files:**
- Create: `scripts/services/spatial_target_cache.gd`
- Modify: `project.godot`
- Modify: `scripts/services/targeting_service.gd`
- Modify: `scripts/enemies/enemy.gd`
- Modify: `scripts/enemies/enemy_collection.gd`
- Test: `tools/refactor/audit_targeting_cache.py`

- [ ] **Step 1: Write the failing audit**

```python
#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
targeting = (root / "scripts/towers/tower.gd").read_text()
assert "SpatialTargetCache" in targeting
```

- [ ] **Step 2: Run the audit and confirm it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: fail because `SpatialTargetCache` is not wired in yet.

- [ ] **Step 3: Add the service scaffold**

```gdscript
extends Node
class_name SpatialTargetCache

func register_enemy(enemy: Node2D) -> void:
	pass

func unregister_enemy(enemy: Node2D) -> void:
	pass

func update_enemy_bucket(enemy: Node2D) -> void:
	pass

func get_candidates(center: Vector2, radius: float) -> Array[Node2D]:
	return []
```

- [ ] **Step 4: Re-run the audit and confirm it passes**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: pass once the autoload and symbol exist.

- [ ] **Step 5: Commit**

```bash
git add project.godot scripts/services/spatial_target_cache.gd scripts/services/targeting_service.gd scripts/enemies/enemy.gd scripts/enemies/enemy_collection.gd tools/refactor/audit_targeting_cache.py
git commit -m "feat: add spatial targeting cache scaffold"
```

### Task 2: Register and update enemies in the cache

**Files:**
- Modify: `scripts/enemies/enemy.gd`
- Modify: `scripts/enemies/enemy_collection.gd`
- Modify: `scripts/navigation/grid_pathfinding_manager.gd`
- Modify: `scripts/services/spatial_target_cache.gd`
- Modify: `scripts/services/targeting_service.gd`

- [ ] **Step 1: Write the failing audit**

```python
from pathlib import Path

text = Path("scripts/enemies/enemy.gd").read_text()
assert "register_enemy" in text
assert "update_enemy_bucket" in text
```

- [ ] **Step 2: Run the audit and confirm it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: fail until enemy registration and bucket updates exist.

- [ ] **Step 3: Add the registration hooks**

```gdscript
func _ready() -> void:
	var cache := get_node_or_null("/root/SpatialTargetCache")
	if cache != null:
		cache.register_enemy(self)

func _exit_tree() -> void:
	var cache := get_node_or_null("/root/SpatialTargetCache")
	if cache != null:
		cache.unregister_enemy(self)
```

- [ ] **Step 4: Update buckets when enemies move**

```gdscript
func _process_dynamic_pathing(delta: float) -> void:
	# existing movement logic stays unchanged
	# update the cache after global_position changes
	var cache := get_node_or_null("/root/SpatialTargetCache")
	if cache != null:
		cache.update_enemy_bucket(self)
```

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/enemy.gd scripts/enemies/enemy_collection.gd scripts/navigation/grid_pathfinding_manager.gd scripts/services/spatial_target_cache.gd scripts/services/targeting_service.gd
git commit -m "feat: keep targeting cache updated with enemy motion"
```

### Task 3: Switch towers to interval-based bucket queries

**Files:**
- Modify: `scripts/towers/tower.gd`
- Modify: `scripts/services/spatial_target_cache.gd`
- Modify: `scripts/services/performance_budget_service.gd`
- Modify: `scripts/core/performance_budget.gd`

- [ ] **Step 1: Write the failing audit**

```python
from pathlib import Path

text = Path("scripts/towers/tower.gd").read_text()
assert "0.08" in text
assert "0.12" in text
assert "0.18" in text
assert "SpatialTargetCache" in text
assert "get_candidates(" in text
```

- [ ] **Step 2: Run the audit and confirm it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: fail until tower retarget cadence and candidate lookup are updated.

- [ ] **Step 3: Update retarget cadence**

```gdscript
func _calculate_retarget_interval() -> float:
	if _is_support_aura() or _is_trickery_clone_support():
		return 0.18
	if visual_type == "rapid" or (fire_rate > 0.0 and fire_rate <= 0.18):
		return 0.08
	if visual_type in ["cannon", "heavy_mortar", "forge_anvil", "stone_bastion", "seismic_drill"]:
		return 0.18
	return 0.12
```

- [ ] **Step 4: Replace full scans with bucket candidates**

```gdscript
func get_enemies_in_range() -> Array:
	_enemies_in_range_cache.clear()
	if preview_mode or CatalogPreviewMode.is_preview_node(self):
		return _enemies_in_range_cache
	var cache := get_node_or_null("/root/SpatialTargetCache")
	var candidates: Array = cache.get_candidates(get_range_origin(), attack_range) if cache else []
	for enemy in candidates:
		if _is_valid_cached_target(enemy):
			_enemies_in_range_cache.append(enemy)
	return _enemies_in_range_cache
```

- [ ] **Step 5: Keep the current target if it is still valid**

```gdscript
func _should_retarget(cached_target_valid: bool, had_target: bool) -> bool:
	if had_target and not cached_target_valid:
		return true
	if current_target == null:
		return shoot_cooldown <= 0.0 or retarget_timer <= 0.0
	return retarget_timer <= 0.0
```

- [ ] **Step 6: Commit**

```bash
git add scripts/towers/tower.gd scripts/services/spatial_target_cache.gd scripts/services/performance_budget_service.gd scripts/core/performance_budget.gd
git commit -m "feat: stagger tower targeting queries"
```

### Task 4: Add targeting telemetry and overlay counters

**Files:**
- Modify: `scripts/core/performance_budget.gd`
- Modify: `scripts/ui/perf_overlay.gd`
- Modify: `scripts/services/spatial_target_cache.gd`

- [ ] **Step 1: Write the failing audit**

```python
from pathlib import Path

text = Path("scripts/ui/perf_overlay.gd").read_text()
assert "target_scans_per_second" in text
assert "avg_candidates_per_scan" in text
assert "active_towers_scanning" in text
```

- [ ] **Step 2: Run the audit and confirm it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: fail until telemetry is wired through.

- [ ] **Step 3: Add counters to PerformanceBudget**

```gdscript
var target_scans_per_second: int = 0
var avg_candidates_per_scan: float = 0.0
var active_towers_scanning: int = 0
```

- [ ] **Step 4: Update the overlay**

```gdscript
_label.text += "\nTarget scans [color=#ffffff]%d/s[/color]" % target_scans_per_second
_label.text += "\nAvg candidates [color=#ffffff]%.1f[/color]" % avg_candidates_per_scan
_label.text += "\nScanning towers [color=#ffffff]%d[/color]" % active_towers_scanning
```

- [ ] **Step 5: Commit**

```bash
git add scripts/core/performance_budget.gd scripts/ui/perf_overlay.gd scripts/services/spatial_target_cache.gd
git commit -m "feat: add targeting telemetry"
```

### Task 5: Verify runtime behavior

**Files:**
- Test: `tools/refactor/audit_targeting_cache.py`

- [ ] **Step 1: Run the audit**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: pass.

- [ ] **Step 2: Run Godot headless**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
Expected: exit `0` with no parse/runtime errors.

- [ ] **Step 3: Smoke test the game**

Run the game and confirm:
`_update_target`, `_find_target`, and `get_enemies_in_range` are no longer major profiler items.
Target selection remains unchanged in outcome.

## Notes

- `SpatialTargetCache` should use `grid_size` as the bucket size.
- Candidate ordering stays with the existing tower scoring code.
- The implementation should not touch projectile, damage, or balance logic.

