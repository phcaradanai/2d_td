# Tower Catalog Full HD Popup Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `res://scenes/debug/tower_catalog.tscn` into a Full HD list browser with a single centered popup preview for one selected tower at a time.

**Architecture:** Keep the catalog shell text-first and cheap, with all tower scene work deferred until the user opens a modal preview. The popup is a separate controller/scene pair that owns exactly one preview subtree and tears it down fully on close or tower switch. Preview mode stays simulation-free so the catalog can render model/VFX/projectile/impact samples without touching gameplay systems.

**Tech Stack:** Godot 4.6.2, GDScript, existing debug/catalog scripts, existing tower preview scene, existing draw safety helpers.

---

### Task 1: Rebuild the catalog shell for Full HD list browsing

**Files:**
- Modify: `scenes/debug/tower_catalog.tscn`
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scripts/debug/catalog_render_guard.gd`
- Modify: `tools/refactor/audit_tower_catalog_full_hd_popup.py`

- [ ] **Step 1: Add a failing catalog layout audit**

Create `tools/refactor/audit_tower_catalog_full_hd_popup.py` with explicit checks for the new shell shape and the absence of eager preview instantiation on open.

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
tower_catalog = (ROOT / "scripts/debug/tower_catalog.gd").read_text(encoding="utf-8")
scene = (ROOT / "scenes/debug/tower_catalog.tscn").read_text(encoding="utf-8")

assert "TowerNameList" in scene
assert "DetailPanel" in scene
assert "TowerPreviewPopup" in scene
assert "SelectedTowerPanel" not in scene
assert "TowerCatalogPreview.new()" not in tower_catalog
assert "current_preview" in tower_catalog
assert "_open_preview_popup(" in tower_catalog
assert "_close_preview_popup()" in tower_catalog
```

- [ ] **Step 2: Run the audit and confirm it fails on the current shell**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_full_hd_popup.py
```

Expected: FAIL until the new shell and popup wiring exist.

- [ ] **Step 3: Rebuild the catalog scene tree around the Full HD shell**

Update `scenes/debug/tower_catalog.tscn` to the target layout:

```text
TowerCatalog
├── RootMargin
│   └── MainPanel
│       ├── Header
│       │   ├── TitleLabel
│       │   └── PerfLabel
│       ├── Toolbar
│       │   ├── SearchBox
│       │   ├── ElementFilter
│       │   ├── TierFilter
│       │   ├── TypeFilter
│       │   ├── ModeToggle
│       │   └── OpenSelectedButton
│       └── BodySplit
│           ├── TowerListPanel
│           │   └── TowerNameList
│           └── DetailPanel
│               ├── SelectedTowerName
│               ├── SelectedTowerStats
│               └── HintLabel
└── TowerPreviewPopup
    └── PopupCard
```

Set the root to full-rect anchors, keep the main panel centered, and size the shell for a 1920x1080 logical layout with about 32 px margins. The list remains text-only and uses `ItemList` metadata for the selected tower id.

Add `_fit_catalog_to_viewport()` in `scripts/debug/tower_catalog.gd` so the main panel clamps cleanly inside the current window instead of assuming 1920x1080. The catalog shell should remain readable on smaller windows and preserve the Full HD proportions when the viewport is large enough.

In `scripts/debug/tower_catalog.gd`, keep only text detail updates on row selection:

```gdscript
func _populate_tower_list() -> void:
	for tower_id in sorted_tower_ids:
		var row_text := "%s | %s | %s | %s" % [name, tier_text, element_text, role_text]
		_item_list.add_item(row_text)
		_item_list.set_item_metadata(_item_list.item_count - 1, tower_id)

func _on_tower_selected(index: int) -> void:
	_update_detail_panel_only(index)
```

- [ ] **Step 4: Verify the shell opens without preview work**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_full_hd_popup.py
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" "res://scenes/debug/tower_catalog.tscn" --quit --log-file /private/tmp/godot-catalog-shell.log
```

Expected: audit PASS and headless scene load exit code `0`.

- [ ] **Step 5: Commit**

```bash
git add scenes/debug/tower_catalog.tscn scripts/debug/tower_catalog.gd scripts/debug/catalog_render_guard.gd tools/refactor/audit_tower_catalog_full_hd_popup.py
git commit -m "feat: rebuild tower catalog as Full HD list shell"
```

### Task 2: Add the modal TowerPreviewPopup and single-preview lifecycle

**Files:**
- Create: `scenes/debug/tower_preview_popup.tscn`
- Create: `scripts/debug/tower_preview_popup.gd`
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`

- [ ] **Step 1: Add a failing audit for popup lifecycle and single-preview ownership**

Extend `tools/refactor/audit_tower_catalog_full_hd_popup.py` so it requires a popup controller and rejects multiple preview owners.

```python
assert "func _open_preview_popup(tower_id: String)" in tower_catalog
assert "func _close_preview_popup()" in tower_catalog
assert "var current_preview: Node = null" in tower_catalog
assert "TowerPreviewPopup" in scene
assert "popup_open" in tower_catalog
```

- [ ] **Step 2: Implement the popup scene/controller pair**

Create `scripts/debug/tower_preview_popup.gd` as the modal controller and `scenes/debug/tower_preview_popup.tscn` as the UI layout. The popup owns one preview host and one selected tower at a time.

Make the popup root a native `PopupPanel` or `Window` so centering, modal focus, and escape-close behavior come from Godot instead of custom overlay code. Add `_fit_popup_to_viewport()` in the popup controller so it targets 1280x760 at Full HD and scales down to roughly 90% of the viewport when the window is smaller than 1366x768.

The controller should expose a small API that `tower_catalog.gd` can call:

```gdscript
func open_for_tower(tower_id: String, tower_cfg: Dictionary) -> void:
	_clear_preview_nodes()
	visible = true
	popup_open = true
	_spawn_selected_model(tower_id)
	_apply_preview_toggles()

func close_popup() -> void:
	_clear_preview_nodes()
	popup_open = false
	hide()
```

The popup scene should contain the structure from the spec:
`PopupCard`, `PopupHeader`, `PopupBody`, `PreviewStage`, `PreviewInfoPanel`, and `PopupFooter` with the five toggle controls plus `Pause` and `Replay`.

- [ ] **Step 3: Wire catalog selection and explicit open behavior**

In `scripts/debug/tower_catalog.gd`, selection updates the detail panel only. Opening the popup happens via double click or `OpenSelectedButton`.

```gdscript
func _on_tower_activated(index: int) -> void:
	_open_preview_popup(_item_list.get_item_metadata(index))

func _open_preview_popup(tower_id: String) -> void:
	_close_preview_popup()
	current_preview = _preview_popup.open_for_tower(tower_id, _towers_config[tower_id])
```

Closing a popup must stop preview timers, particles, processing, and input before queue-freeing the preview subtree.

- [ ] **Step 4: Verify only one preview can exist**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_full_hd_popup.py
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" "res://scenes/debug/tower_preview_popup.tscn" --quit --log-file /private/tmp/godot-catalog-popup.log
```

Expected: audit PASS and headless popup load exit code `0`.

- [ ] **Step 5: Commit**

```bash
git add scenes/debug/tower_preview_popup.tscn scripts/debug/tower_preview_popup.gd scripts/debug/tower_catalog.gd scripts/towers/tower_catalog_preview.gd tools/refactor/audit_tower_catalog_full_hd_popup.py
git commit -m "feat: add modal tower preview popup"
```

### Task 3: Make the popup preview simulation-free and performance-safe

**Files:**
- Modify: `scripts/towers/tower.gd`
- Modify: `scripts/towers/tower_visual_renderer.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`
- Modify: `scripts/towers/visuals/common/tower_visual_draw_utils.gd`
- Modify: `scripts/debug/tower_preview_popup.gd`

- [ ] **Step 1: Add a failing audit for preview-safety guards**

Extend `tools/refactor/audit_tower_catalog_full_hd_popup.py` so it checks that preview mode, toggle hooks, and clean teardown paths exist.

```python
tower_gd = (ROOT / "scripts/towers/tower.gd").read_text(encoding="utf-8")
popup_gd = (ROOT / "scripts/debug/tower_preview_popup.gd").read_text(encoding="utf-8")
preview_gd = (ROOT / "scripts/towers/tower_catalog_preview.gd").read_text(encoding="utf-8")

assert "preview_mode: bool = false" in tower_gd
assert "set_preview_mode(true)" in popup_gd or "set_preview_mode(true)" in preview_gd
assert "set_vfx_enabled" in popup_gd or "set_vfx_enabled" in preview_gd
assert "set_projectile_preview_enabled" in popup_gd or "set_projectile_preview_enabled" in preview_gd
assert "set_impact_preview_enabled" in popup_gd or "set_impact_preview_enabled" in preview_gd
assert "stop_preview()" in popup_gd or "stop_preview()" in preview_gd
```

- [ ] **Step 2: Gate gameplay logic behind preview mode**

In `scripts/towers/tower.gd`, early-return from targeting, firing, aura scans, damage application, projectile spawning, and other gameplay-heavy `_process()` paths when `preview_mode` is active.

Minimal shape:

```gdscript
func _process(delta: float) -> void:
	if preview_mode:
		return
	# normal gameplay logic
```

Tower visuals must stay on dirty redraws only. No continuous `queue_redraw()` calls are allowed in the catalog preview path unless the visual state actually changes.

- [ ] **Step 3: Teach the preview renderer and popup to toggle model/VFX/projectile/impact independently**

Update `scripts/towers/tower_catalog_preview.gd` so it can safely enable or disable each preview subtree without leaving hidden processes running. The popup controller should delegate each toggle to the preview widget, then create or clear the projectile/impact helper nodes based on the current toggle state.

```gdscript
func set_vfx_enabled(enabled: bool) -> void:
	show_effects_preview = enabled
	queue_redraw()

func set_projectile_preview_enabled(enabled: bool) -> void:
	show_projectile_preview = enabled
	queue_redraw()
```

The impact toggle does not need a dedicated preview-widget method if the popup controller owns the impact helper node lifecycle directly. In that case, the controller should spawn the helper only when `ImpactToggle` is on and destroy it immediately when the toggle turns off.

If a hook does not exist on a preview node, the popup must skip it and continue.

- [ ] **Step 4: Keep draw wrappers and fallback behavior stable under preview load**

In `scripts/towers/visuals/common/tower_visual_draw_utils.gd`, keep the safe wrappers as the only draw path used by the catalog preview. Do not reintroduce raw procedural draw calls in the popup path.

The popup must fall back to text-only `"Preview unavailable"` content if preview construction fails instead of freezing or crashing the catalog.

- [ ] **Step 5: Run the full verification set**

Run:

```bash
python3 tools/refactor/audit_tower_catalog_full_hd_popup.py
python3 tools/refactor/audit_tower_draw_safety.py
git diff --check
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/oyl/my_folders/projects/clone tower defend" --quit --log-file /private/tmp/godot-catalog-preview-safe.log
```

Expected: both audits PASS, diff check PASS, headless project load exit code `0`.

- [ ] **Step 6: Commit**

```bash
git add scripts/towers/tower.gd scripts/towers/tower_visual_renderer.gd scripts/towers/tower_catalog_preview.gd scripts/towers/visuals/common/tower_visual_draw_utils.gd scripts/debug/tower_preview_popup.gd tools/refactor/audit_tower_catalog_full_hd_popup.py
git commit -m "feat: keep tower catalog preview simulation-free"
```

## Self-Review

Coverage check:
- Task 1 covers the Full HD shell, text-only list, and viewport fit.
- Task 2 covers the modal popup scene, single-preview ownership, and popup open/close lifecycle.
- Task 3 covers preview safety, simulation gating, draw safety, and final verification.

Placeholder scan:
- No TBDs, TODOs, or vague validation steps remain.

Type consistency:
- `current_preview`, `popup_open`, `_open_preview_popup()`, `_close_preview_popup()`, and `_populate_tower_list()` are used consistently across tasks.
- The popup controller owns preview teardown, while the catalog shell owns list selection and explicit open/close wiring.
