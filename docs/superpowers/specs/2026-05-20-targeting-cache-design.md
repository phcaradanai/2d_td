# Targeting Cache Implementation Spec

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this spec task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce tower targeting cost by moving scans to a staggered, cache-backed cadence without changing target selection outcomes.

**Architecture:** Keep tower decision logic in `scripts/towers/tower.gd`, but stop letting each tower walk the full enemy list every frame. Extend the existing `TargetingService` / `PerformanceBudget` cache path with a spatial bucket index keyed to `grid_size`, then have towers query only nearby buckets on their retarget tick. Exact target validation still happens after candidate reduction, so gameplay results remain unchanged. `PerformanceBudget` owns the counters and the debug overlay renders them.

**Tech Stack:** Godot 4.6 GDScript, existing autoload services, existing debug overlay.

---

### Task 1: Add a spatial enemy index service

**Files:**
- Create: `scripts/services/spatial_target_cache.gd`
- Modify: `project.godot`
- Modify: `scripts/services/targeting_service.gd`
- Modify: `scripts/enemies/enemy.gd`
- Modify: `scripts/enemies/enemy_collection.gd`
- Test: `tools/refactor/audit_targeting_cache.py`

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
text = (root / "scripts/towers/tower.gd").read_text()
assert "SpatialTargetCache" in text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: FAIL because the spatial cache service does not exist yet.

- [ ] **Step 3: Write minimal implementation**

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

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: PASS once the new service is present and autoloaded.

- [ ] **Step 5: Commit**

```bash
git add project.godot scripts/services/spatial_target_cache.gd scripts/services/targeting_service.gd scripts/enemies/enemy.gd scripts/enemies/enemy_collection.gd tools/refactor/audit_targeting_cache.py
git commit -m "feat: add spatial targeting cache scaffold"
```

### Task 2: Retarget on fixed intervals

**Files:**
- Modify: `scripts/towers/tower.gd`
- Modify: `scripts/services/performance_budget_service.gd`
- Modify: `scripts/core/performance_budget.gd`
- Modify: `scripts/ui/perf_overlay.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# Add a small audit assertion that tower.gd uses the requested intervals.
assert("_calculate_retarget_interval" in tower_text)
assert("0.08" in tower_text)
assert("0.12" in tower_text)
assert("0.18" in tower_text)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: FAIL until the interval logic is updated.

- [ ] **Step 3: Write minimal implementation**

```gdscript
func _calculate_retarget_interval() -> float:
	if _is_support_aura() or _is_trickery_clone_support():
		return 0.18
	if visual_type == "rapid" or fire_rate > 0.0 and fire_rate <= 0.18:
		return 0.08
	if visual_type in ["cannon", "heavy_mortar", "forge_anvil", "stone_bastion"]:
		return 0.18
	return 0.12
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: PASS after the interval map and staggered timer reset are in place.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/tower.gd scripts/services/performance_budget_service.gd scripts/core/performance_budget.gd scripts/ui/perf_overlay.gd tools/refactor/audit_targeting_cache.py
git commit -m "feat: stagger tower retarget cadence"
```

### Task 3: Replace full scans with bucketed candidate lookup

**Files:**
- Modify: `scripts/towers/tower.gd`
- Modify: `scripts/services/spatial_target_cache.gd`
- Modify: `scripts/services/targeting_service.gd`
- Modify: `scripts/core/performance_budget.gd`

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
from pathlib import Path

text = Path("scripts/towers/tower.gd").read_text()
assert "get_candidates(" in text
assert "get_enemies_in_range" in text
assert "get_nodes_in_group(\"enemies\")" not in text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: FAIL until tower range queries use bucket candidates.

- [ ] **Step 3: Write minimal implementation**

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

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: PASS once towers query cached candidates instead of all enemies.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/tower.gd scripts/services/spatial_target_cache.gd scripts/services/targeting_service.gd scripts/core/performance_budget.gd tools/refactor/audit_targeting_cache.py
git commit -m "feat: bucket tower target queries"
```

### Task 4: Add targeting telemetry

**Files:**
- Modify: `scripts/core/performance_budget.gd`
- Modify: `scripts/ui/perf_overlay.gd`
- Modify: `scripts/services/spatial_target_cache.gd`

- [ ] **Step 1: Write the failing test**

```python
text = Path("scripts/ui/perf_overlay.gd").read_text()
assert "target_scans_per_second" in text
assert "avg_candidates_per_scan" in text
assert "active_towers_scanning" in text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: FAIL until the overlay shows the requested counters.

- [ ] **Step 3: Write minimal implementation**

```gdscript
var target_scans_per_second: int = 0
var avg_candidates_per_scan: float = 0.0
var active_towers_scanning: int = 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: PASS once the counters are populated and rendered.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/performance_budget.gd scripts/ui/perf_overlay.gd scripts/services/spatial_target_cache.gd tools/refactor/audit_targeting_cache.py
git commit -m "feat: add targeting telemetry"
```

### Task 5: Verify runtime behavior

**Files:**
- Test: `tools/refactor/audit_targeting_cache.py`

- [ ] **Step 1: Run the full audit**

Run: `python3 tools/refactor/audit_targeting_cache.py`
Expected: PASS.

- [ ] **Step 2: Run Godot headless smoke tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
Expected: exit `0` with no parse/runtime errors.

- [ ] **Step 3: Check the debug overlay**

Run: open the game and verify the overlay shows `target_scans_per_second`, `avg_candidates_per_scan`, and `active_towers_scanning`.

## Scope Notes

This work changes search cost, not targeting outcome. Towers still use exact range checks and the same priority rules after candidate reduction. If a current target remains valid and in range, it stays locked; only dead, leaked, out-of-range, or mode-changed targets trigger a scan.

## Decisions

- Bucket size is `grid_size` by default, with one primary bucket per grid cell and a small neighbor expansion for tower radius overlap.
- `PerformanceBudget` owns the final telemetry counters; `TargetingService` and `SpatialTargetCache` only feed it.
- `get_enemies_in_range()` returns an unordered candidate list from the cache; the existing scoring pass determines the final target order.
