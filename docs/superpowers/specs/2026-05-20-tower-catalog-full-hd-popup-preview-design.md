# Tower Catalog Full HD Popup Preview Design

## Goal

Refactor `res://scenes/debug/tower_catalog.tscn` into a Full HD list browser with a single on-demand popup preview for one selected tower at a time.

The default catalog view must remain lightweight and text-first. No tower model or VFX scene may be instantiated until the user explicitly opens the preview popup for one selected tower.

## Design Summary

The catalog will use a 1920x1080 logical layout with a centered main panel and a native modal preview popup.

The main catalog body is list-first:
- left side: text-only tower list
- right side: details panel with selected tower text only
- no tower models in list rows
- no gameplay simulation in the catalog shell

The preview popup is transient:
- only one selected tower preview exists at a time
- opening a new tower preview destroys the previous preview first
- closing the popup fully tears down preview nodes and stops preview processing

## Layout

The scene should be organized around these regions:

- `RootMargin`
  - `MainPanel`
    - `Header`
      - `TitleLabel`
      - `PerfLabel`
    - `Toolbar`
      - search/filter controls
      - mode controls
      - `OpenSelectedButton`
    - `BodySplit`
      - `TowerListPanel`
        - `TowerNameList`
      - `DetailPanel`
        - `SelectedTowerName`
        - `SelectedTowerStats`
        - `HintLabel`
  - `TowerPreviewPopup`
    - `PopupCard`
      - `PopupHeader`
      - `PopupBody`
        - `PreviewStage`
        - `PreviewInfoPanel`
      - `PopupFooter`

The layout should fit within the game window and scale cleanly. The base design target is Full HD, with margins around 32 px and a centered main panel sized roughly 1760x960. The popup target size is 1280x760, clamped down on smaller windows so it never exceeds the viewport.

## Catalog List Behavior

The tower list must remain cheap to build and cheap to keep on screen.

Each row shows text only:
- tower name
- tier
- elements
- attack type or role

Rows must not instantiate any tower model or preview scene.

Selection behavior:
- single click updates the detail text panel only
- double click or `OpenSelectedButton` opens the preview popup

The detail panel remains text only and must not create preview nodes.

## Preview Popup Behavior

The popup contains exactly one tower preview instance at a time.

When opened:
1. clear any previous preview nodes
2. mark the popup as open
3. populate title, stats, and description fields
4. instantiate the selected tower model only if model preview is enabled
5. instantiate attack VFX only if VFX preview is enabled
6. instantiate projectile preview only if projectile preview is enabled
7. instantiate impact preview only if impact preview is enabled
8. center the popup in the viewport
9. keep autoplay paused unless explicitly enabled

Popup controls:
- `Model On/Off`
- `Attack VFX On/Off`
- `Projectile On/Off`
- `Impact On/Off`
- `Auto Play On/Off`
- `Pause`
- `Replay`

The popup must support closing cleanly with Escape or the close button.

## Preview Lifecycle Contract

The popup preview path must be simulation-free.

Preview nodes may render, animate, and replay short visual demonstrations, but they must not run gameplay systems:
- no target search
- no enemy scan
- no damage logic
- no aura scan
- no wave manager
- no enemy registry access

Each previewable node should support the preview contract if it already has a relevant hook:
- `is_catalog_preview = true`
- `set_preview_mode(true)`
- `set_vfx_enabled(bool)`
- `set_projectile_preview_enabled(bool)`
- `set_impact_preview_enabled(bool)`
- `play_preview()`
- `pause_preview()`
- `stop_preview()`

If a node does not support a hook, the catalog must fail safely and continue.

Closing the popup must:
- stop timers
- stop particles
- disable processing
- disable input processing
- queue_free preview nodes
- clear preview references

Switching towers must first tear down the previous preview before creating the next one.

## Performance and Safety

The catalog shell must remain stable at 60 FPS in the editor.

Rules:
- no repeated `queue_redraw()` unless the preview state actually changes
- no preview nodes while the popup is closed
- only one active tower preview subtree at a time
- if FPS falls below 45, the popup should automatically disable VFX, projectile, and impact toggles and show a warning
- list rows and toolbar elements must remain Control-only
- the popup must never leave hidden preview loops running after close

## Fallback Behavior

If the selected preview cannot be created cleanly, the popup should fall back to a text-only warning and summary panel instead of crashing or freezing the catalog.

The fallback must show:
- `Preview unavailable`
- tower name
- tier
- elements
- basic stats

## Acceptance Criteria

The design is complete when:
1. the catalog opens at Full HD without clipping
2. the list is readable and scrollable
3. no tower model appears in the list
4. selecting a tower updates text details only
5. opening the popup shows a centered preview card
6. only the selected tower is previewed
7. model, VFX, projectile, and impact toggles work independently
8. closing the popup removes all preview nodes
9. switching towers frees the previous preview first
10. the debugger stays at 0 errors
11. canvas draw overflow errors do not reappear
12. editor FPS remains close to 60 on Apple M1

