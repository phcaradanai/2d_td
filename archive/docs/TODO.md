# Production Readiness TODO

## Phase 1 — Bug Fixes (code only, no editor)
- [x] **P1-1** `audio_manager.gd`: add `_exit_tree()` to stop music player and clear sfx_cache/music_cache
- [x] **P1-2** `spatial_target_cache.gd`: switch `_cell_key()` from string formatting to integer hash (64-bit pack)
- [x] **P1-3** *(editor-only)* Resave `MainMenu.tscn`, `LevelSelect.tscn`, `DebugPanel.tscn` to fix 3 invalid UIDs in Main.tscn

## Phase 2 — Activate Affix System in Wave Data
- [x] **P2-1** `armor_element` confirmed present in all 15 enemy types in `enemies.json`
- [x] **P2-2** Injected `affixes` into wave groups across waves_04 through waves_20 (fast/healing/mechanical/undead/image staggered by level)

## Phase 3 — Boss Enemy
- [x] **P3-1** Added `boss` (Apex Sentinel) to `enemies.json`: 1800hp, composite armor, affixes=[mechanical,undead]
- [x] **P3-2** Boss spawn added to final wave of all 20 level wave files (1x early, 2x mid, 3x late)
- [x] **P3-3** Boss death effect: gold color burst, max importance (largest shake + burst)

## Phase 4 — Tutorial (Wave 1 guided flow)
- [x] **P4-1** `TutorialService` autoload: 4-step state machine (BUILD_HINT→PLACE_HINT→WAVE_HINT→DONE)
- [x] **P4-2** Connected to build_manager.tower_placed, game_hud.tower_build_selected, game_hud.start_wave_requested via node_added
- [x] **P4-3** Programmatic CanvasLayer overlay (layer 128) with neon-border panel + RichTextLabel
- [x] **P4-4** Skip button + `user://tutorial_done` flag prevents repeat

## Phase 5 — Meta Progression (Stars per Level)
- [x] **P5-1** Star calculation exists in `game_manager.calculate_stars()` (3=perfect, 2=cleared, 1=survived)
- [x] **P5-2** Stars stored in `save_manager` per-level (`best_stars`, `last_stars`) — already implemented
- [x] **P5-3** Stars displayed in `level_select.gd` via `star_icon.gd` — already implemented

## Phase 6 — Polish & Stability
- [ ] **P6-1** Difficulty selector on level select (Easy/Normal/Hard multiplies enemy HP/speed) — deferred, complex
- [x] **P6-2** Wave clear fanfare exists: `show_wave_feedback("Wave Cleared! +N Gold")` with camera shake
- [x] **P6-3** Final parse check passed — 0 script errors across all modified files

---
Legend: P0=blocker P1=important P2=content P3-P6=features
Last updated: 2026-05-23
