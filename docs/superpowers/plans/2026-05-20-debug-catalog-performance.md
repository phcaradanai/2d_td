# Debug Catalog Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the tower catalog and debug galleries avoid eager full-quality previews so catalog browsing can target stable 60 FPS.

**Architecture:** Add focused debug-only helpers for VFX mode, performance monitoring, and virtualized tower card pooling. Keep `tower_catalog.gd` as coordinator, add low-cost activation controls to `TowerCatalogPreview`, and make enemy/effect galleries static in their grids with live previews only in detail overlays.

**Tech Stack:** Godot 4.6.2 GDScript, Python guardrail audit, existing debug scenes and scripts.

---

### Task 1: Add A Failing Performance Audit

**Files:**
- Create: `tools/refactor/audit_debug_catalog_performance.py`
- Inspect: `scripts/debug/tower_catalog.gd`
- Inspect: `scripts/debug/tower_effect_catalog_controller.gd`
- Inspect: `scripts/enemies/enemy_collection.gd`
- Inspect: `scripts/effects/effect_collection.gd`

- [ ] **Step 1: Write the failing audit**

Create an audit that checks for `TowerCatalogVirtualList`, `CatalogPerformanceMonitor`, a default selected-only VFX mode, active preview count labeling, and absence of eager effect gallery autoplay timers.

- [ ] **Step 2: Run audit to verify it fails**

Run: `python3 tools/refactor/audit_debug_catalog_performance.py`

Expected: FAIL because the implementation does not yet exist.

- [ ] **Step 3: Keep the audit focused**

The audit must check source boundaries only. It must not run gameplay or inspect balance data.

### Task 2: Add Debug Performance Helpers

**Files:**
- Create: `scripts/debug/catalog_vfx_mode.gd`
- Create: `scripts/debug/catalog_performance_monitor.gd`

- [ ] **Step 1: Implement VFX mode constants**

Add constants `VFX_OFF`, `VFX_SELECTED_ONLY`, `VFX_ALL`, and `DEFAULT_MODE`.

- [ ] **Step 2: Implement performance monitor**

Add a small `Node` that accepts labels and an active-preview callable, samples Godot `Performance` counters, and writes FPS, process ms, drawn objects, node count, and active previews.

- [ ] **Step 3: Run audit**

Run: `python3 tools/refactor/audit_debug_catalog_performance.py`

Expected: still FAIL until tower catalog is wired.

### Task 3: Make Tower Previews Pausable And Low Cost

**Files:**
- Modify: `scripts/towers/tower_catalog_preview.gd`

- [ ] **Step 1: Add low-cost controls**

Add `static_preview`, `set_active(active)`, `set_static_preview(enabled)`, and `set_vfx_enabled(enabled)`.

- [ ] **Step 2: Disable preview processing when inactive**

When inactive, pause the `SubViewport`, disable process on preview-only layers, and avoid redraw churn.

- [ ] **Step 3: Run Godot parse**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`

Expected: PASS.

### Task 4: Add Tower Catalog Virtualization

**Files:**
- Create: `scripts/debug/tower_catalog_virtual_list.gd`
- Modify: `scripts/debug/tower_effect_catalog_card.gd`
- Modify: `scripts/debug/tower_catalog.gd`

- [ ] **Step 1: Add virtual list controller**

Implement a fixed-size row pool driven by `ScrollContainer.scroll_vertical`, content spacer height, and row rebinding.

- [ ] **Step 2: Add reusable card binding**

Update card script with `bind_entry`, `deactivate`, hover state, selected state, and VFX mode handling.

- [ ] **Step 3: Wire tower catalog**

Replace eager `ContentVBox` population with virtual entries, pooled rows, the three-mode VFX toolbar, and the performance monitor labels.

- [ ] **Step 4: Run audit**

Run: `python3 tools/refactor/audit_debug_catalog_performance.py`

Expected: only enemy/effect gallery checks may still fail.

### Task 5: Reduce Enemy And Effect Gallery Grid Cost

**Files:**
- Modify: `scripts/enemies/enemy_collection.gd`
- Modify: `scripts/effects/effect_collection.gd`

- [ ] **Step 1: Stop enemy grid processing**

Use static grid cards and create live `Enemy` preview only in the detail overlay.

- [ ] **Step 2: Stop effect grid autoplay**

Do not spawn looping effect nodes or per-card replay timers in the gallery grid. Keep live effect replay in detail only.

- [ ] **Step 3: Run audit**

Run: `python3 tools/refactor/audit_debug_catalog_performance.py`

Expected: PASS.

### Task 6: Final Verification

**Files:**
- Verify all touched files.

- [ ] **Step 1: Run Godot headless parse**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`

Expected: PASS.

- [ ] **Step 2: Run relevant audits**

Run: `python3 tools/refactor/audit_debug_catalog_performance.py`

Run: `python3 tools/refactor/audit_main_small_split.py`

Run: `python3 tools/refactor/audit_project_guardrails.py`

Expected: PASS.

- [ ] **Step 3: Inspect diff**

Run: `git diff --stat` and `git diff --check`.

Expected: no whitespace errors and changes limited to debug/catalog performance files plus plan/spec docs.
