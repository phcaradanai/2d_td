# Tower Catalog List-First Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `tower_catalog.tscn` open instantly by replacing the eager tower grid with a text-only tower list and a single on-demand preview instance.

**Architecture:** The catalog will become a two-stage browser. The left side is a lightweight list of towers with no preview scenes instantiated at startup. The right side is a preview host that stays empty until a row is selected; each selection destroys the previous preview, creates exactly one new preview, and keeps all gameplay-heavy systems disabled in preview mode.

**Tech Stack:** Godot 4.6.2, GDScript, existing debug/catalog scripts, existing tower preview scene, existing draw safety helpers.

---

### Task 1: Replace the catalog browser with a text-only tower list

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scenes/debug/tower_catalog.tscn`
- Modify: `scripts/debug/catalog_render_guard.gd`

- [ ] **Step 1: Add a failing check for eager preview instantiation**

Create or extend a small audit in `tools/refactor/audit_tower_catalog_list_first.py` that asserts `tower_catalog.gd` does not instantiate `TowerCatalogPreview` during initial catalog build and that the default browser widget is a text list, not a tower preview grid.

```python
assert "TowerCatalogPreview.new()" not in tower_catalog_build_path
assert "_populate_tower_name_list" in tower_catalog_text
```

- [ ] **Step 2: Run the audit and confirm the current code fails**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
```

Expected: FAIL, because the current catalog still builds preview cards.

- [ ] **Step 3: Implement the list-only browser**

Replace the existing card/grid population path with a text list. Keep only:

```gdscript
func _populate_tower_name_list() -> void:
	for tower_id in sorted_tower_ids:
		var row_text := "%s | T%s | %s | %s" % [name, tier_text, element_text, role_text]
		_item_list.add_item(row_text)
		_item_list.set_item_metadata(_item_list.item_count - 1, tower_id)
```

The default scene must not instantiate `TowerCatalogPreview` or any tower scene in `_ready()` or the initial catalog build path.

- [ ] **Step 4: Run the audit and confirm it passes**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/debug/tower_catalog.gd scenes/debug/tower_catalog.tscn scripts/debug/catalog_render_guard.gd tools/refactor/audit_tower_catalog_list_first.py
git commit -m "feat: make tower catalog list-first"
```

### Task 2: Add single-preview lifecycle management

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`
- Modify: `scripts/towers/tower.gd`

- [ ] **Step 1: Add a failing check for multiple live previews**

Extend the catalog audit so it asserts there is exactly one live preview slot and that the catalog stores a single `current_preview` reference.

```python
assert "var current_preview: Node = null" in tower_catalog_text
assert "_clear_preview()" in tower_catalog_text
assert "_show_tower_preview(" in tower_catalog_text
```

- [ ] **Step 2: Run the audit and confirm it fails before the refactor**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
```

Expected: FAIL until the single-preview lifecycle exists.

- [ ] **Step 3: Implement preview replacement**

Add these functions in `tower_catalog.gd`:

```gdscript
func _clear_preview() -> void:
	if current_preview == null:
		return
	current_preview.set_process(false)
	current_preview.set_physics_process(false)
	current_preview.set_process_input(false)
	if current_preview.has_method("stop_preview"):
		current_preview.stop_preview()
	current_preview.queue_free()
	current_preview = null

func _show_tower_preview(tower_id: String) -> void:
	_clear_preview()
	# Instantiate only the selected tower preview here.
```

`_show_tower_preview()` must create exactly one preview node, add it to the preview host, and not create any other tower preview instances.

- [ ] **Step 4: Wire preview reset into the preview scene**

Update `TowerCatalogPreview` so it can be safely torn down and recreated without leaving running timers, VFX processing, or repeated redraws. The preview scene must enter a stopped state before `queue_free()`.

- [ ] **Step 5: Run Godot headless**

Run:

```bash
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" --quit --log-file /private/tmp/godot-catalog-preview.log
```

Expected: exit code `0`.

- [ ] **Step 6: Commit**

```bash
git add scripts/debug/tower_catalog.gd scripts/towers/tower_catalog_preview.gd scripts/towers/tower.gd
git commit -m "feat: make tower catalog use one preview at a time"
```

### Task 3: Make preview mode safe by default

**Files:**
- Modify: `scripts/towers/tower.gd`
- Modify: `scripts/towers/tower_visual_renderer.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`
- Modify: `scripts/towers/visuals/common/tower_visual_draw_utils.gd`

- [ ] **Step 1: Add a failing check for preview simulation**

Extend the audit so it fails if the catalog preview path leaves targeting, path queries, enemy registry access, projectile spawning, or aura scanning enabled.

```python
assert "preview_mode" in tower_text
assert "set_preview_mode(true)" in preview_text
assert "set_vfx_enabled" in preview_text
```

- [ ] **Step 2: Run the audit and confirm the current implementation is not yet safe enough**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
```

Expected: FAIL until the preview path is fully guarded.

- [ ] **Step 3: Gate gameplay logic behind preview mode**

Ensure `tower.gd` exits early from gameplay-heavy `_process()` and targeting code whenever preview mode is active. The selected tower preview may animate visually, but it must not search targets, calculate damage, spawn projectiles, or tick status/aura logic.

- [ ] **Step 4: Keep draw updates dirty-only**

Ensure tower visuals only call `queue_redraw()` when selected tower, tier, zoom, or VFX toggle changes. No continuous redraw loop may remain in the catalog path.

- [ ] **Step 5: Run Godot headless and the draw safety audit**

Run:

```bash
python3 tools/refactor/audit_tower_draw_safety.py
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" --quit --log-file /private/tmp/godot-catalog-safe-preview.log
```

Expected: both commands pass, and the project exits cleanly.

- [ ] **Step 6: Commit**

```bash
git add scripts/towers/tower.gd scripts/towers/tower_visual_renderer.gd scripts/towers/tower_catalog_preview.gd scripts/towers/visuals/common/tower_visual_draw_utils.gd
git commit -m "feat: keep tower catalog previews simulation-free"
```

### Task 4: Add fallback text preview for load failures

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`

- [ ] **Step 1: Add a failing check for preview fallback**

Update the catalog audit so it checks for a text-only fallback path when a tower preview scene fails to load or initialize.

```python
assert "Preview unavailable" in tower_catalog_text
assert "_show_preview_fallback" in tower_catalog_text
```

- [ ] **Step 2: Run the audit and confirm it fails before the fallback exists**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
```

Expected: FAIL.

- [ ] **Step 3: Implement the fallback panel**

If preview instantiation fails, clear the preview host and show only a text panel with:
`Preview unavailable`, tower name, tier, elements, and other static stats.

- [ ] **Step 4: Run the audit and headless boot again**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" --quit --log-file /private/tmp/godot-catalog-fallback.log
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/debug/tower_catalog.gd scripts/towers/tower_catalog_preview.gd
git commit -m "feat: add safe fallback for tower catalog previews"
```

### Task 5: Verify the catalog no longer freezes on open

**Files:**
- Modify: `tools/refactor/audit_tower_catalog_list_first.py`

- [ ] **Step 1: Add a runtime smoke check**

Make the audit verify the catalog opens with list-only default state, preview count of zero on startup, and no eager preview construction.

```python
assert "current_preview" in tower_catalog_text
assert "_populate_tower_name_list" in tower_catalog_text
assert "_show_tower_preview" in tower_catalog_text
```

- [ ] **Step 2: Run the full verification set**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_list_first.py
python3 tools/refactor/audit_tower_draw_safety.py
git diff --check
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" "res://scenes/debug/tower_catalog.tscn" --quit --log-file /private/tmp/godot-catalog-final.log
```

Expected: all commands pass and `tower_catalog.tscn` exits immediately without freeze.

- [ ] **Step 3: Commit**

```bash
git add tools/refactor/audit_tower_catalog_list_first.py
git commit -m "test: lock tower catalog list-first preview safety"
```

