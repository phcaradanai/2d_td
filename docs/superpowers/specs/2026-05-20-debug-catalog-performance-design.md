# Debug Catalog Performance Design
Date: 2026-05-20

## Goal

Optimize `scenes/debug/tower_catalog.tscn` and the debug gallery scenes so they stay responsive at 60 FPS by avoiding eager live preview instantiation. The catalog should target fewer than 8,000 drawn objects, fewer than 2,500 nodes, and less than 12 ms process time on Apple M1 hardware without changing gameplay logic, tower balance, enemy behavior, or effect behavior in real gameplay.

## Constraints

- Do not change damage, range, fire rate, targeting, auras, projectiles, enemy status logic, wave logic, unlock rules, or balance data.
- Do not add feature logic to `main.gd`.
- Keep catalog performance code isolated in focused debug/UI/service files.
- Do not instantiate or animate every tower/effect at full quality at the same time.
- Do not run target search, attack simulation, aura updates, projectile updates, or status effect updates in catalog grid items.
- Use live attack VFX only for the selected or hovered preview when the VFX mode permits it.
- Keep tower visual lookup behavior unchanged: by-id visuals still resolve first, with `visual_type` as fallback.

## Architecture

The tower catalog becomes a virtualized scroll surface. Instead of building one live card per tower, `tower_catalog.gd` builds a flat list of lightweight catalog entries and hands them to a focused virtual list controller. The virtual list owns a small pool of reusable card controls sized to the visible viewport plus a small overscan margin. As the user scrolls or filters, pooled cards are rebound to new tower entries.

Grid cards use low-cost static previews by default. A static preview may be a cached `Texture2D` snapshot when available, or a simplified static tower body rendered by `TowerCatalogPreview` with processing and VFX disabled. Attack VFX and looping preview effects are not active in ordinary grid cards. The side detail panel remains the place for full inspection and real VFX replay.

The existing enemy and effect galleries receive the same policy at a smaller scale: gallery cards show static low-cost content, while live animated enemy/effect previews are created only in the detail overlay for the selected item. Timers and looped effects are stopped when detail closes.

## Components

### `scripts/debug/catalog_performance_monitor.gd`

Small debug service that samples performance counters on a timer and formats labels for:

- FPS from `Engine.get_frames_per_second()`
- Process ms from `Performance.TIME_PROCESS`
- Total Objects Drawn from `Performance.RENDER_TOTAL_OBJECTS_IN_FRAME`
- Node count from `Performance.OBJECT_NODE_COUNT`
- Active preview count from the virtualized catalog controller

The service is read-only and does not tune gameplay or engine settings.

### `scripts/debug/catalog_vfx_mode.gd`

Small config-like script with constants for:

- `VFX_OFF`
- `VFX_SELECTED_ONLY`
- `VFX_ALL`

The default mode is `VFX_SELECTED_ONLY`. `VFX_ALL` is treated as an explicit stress/debug mode, not the default browsing mode.

### `scripts/debug/tower_catalog_virtual_list.gd`

Focused controller for tower catalog virtualization:

- Accepts entry metadata, scroll container, content root, and a card factory callback.
- Maintains estimated card row height and total spacer height so the scroll bar represents all filtered entries.
- Creates only visible pooled card controls plus overscan.
- Rebinds pooled cards on scroll, resize, filter, and zoom changes.
- Exposes active preview count for the perf monitor.
- Calls `deactivate()` on cards before recycling them so processing, animations, particles, beams, timers, and VFX nodes are paused or freed.

### `scripts/debug/tower_effect_catalog_card.gd`

The existing card script becomes the reusable card binding surface:

- `bind_entry(tower_id, cfg, vfx_mode, selected, hovered)`
- `deactivate()`
- `set_vfx_mode(mode)`
- `set_selected(selected)`
- `set_hovered(hovered)`

Cards must not perform gameplay targeting or attack simulation. Grid-card VFX may only run when `VFX_ALL` is selected, or when the card is selected/hovered and the mode is `VFX_SELECTED_ONLY`.

### `scripts/towers/tower_catalog_preview.gd`

Preview gains explicit low-cost controls:

- Static mode disables `PreviewFxLayer._process`, projectile preview, effect preview, and range redraw churn.
- `set_active(active)` pauses the SubViewport update mode and disables process on preview-only children when the card is off-screen.
- `set_vfx_enabled(enabled)` toggles only preview VFX layers, not gameplay logic.
- Optional snapshot support can use `ViewportTexture` or generated `ImageTexture` to replace repeated decorative child nodes where the code path is straightforward.

## VFX Mode Behavior

The toolbar replaces the existing binary attack VFX toggle with an `OptionButton`:

- `VFX Off`: grid cards and side panel do not spawn attack VFX; existing catalog VFX nodes are cleared.
- `Selected Only`: default. Static grid cards are cheap; selected or hovered card may show preview VFX; side panel replay works for the selected tower.
- `All`: visible pooled grid cards may show VFX. Off-screen entries still do not exist and do not process.

Status and support preview buttons in the side panel remain explicit actions. They do not start global loops across all cards.

## Filtering And Scrolling

Filters still compose with AND. Filtering rebuilds the virtual entry list and resets or clamps scroll position. Hidden entries are not represented by invisible live cards; they are removed from the virtual data set until filters change.

Rows are based on the existing family/tier structure so visual grouping stays familiar. Section labels and separators are represented as lightweight entries in the virtual list. Tower preview entries are the only entries that can acquire a pooled preview card.

## Enemy And Effect Galleries

`EnemyGallery.tscn` keeps static card labels and simple draw-only silhouettes in the grid. It no longer keeps every preview enemy processing. Selecting an enemy creates the live detail enemy; closing detail frees it.

`EffectGallery.tscn` keeps static labels and non-looping card thumbnails. It no longer starts one replay timer per gallery card. Selecting an effect creates the live detail effect and one replay timer; closing detail stops the timer and frees the effect.

## Testing

Add focused non-gameplay tests or audit scripts that can run headlessly:

- Tower catalog source audit confirms the scene uses `TowerCatalogVirtualList`.
- Audit confirms the toolbar includes the three VFX modes and defaults to selected-only.
- Audit confirms eager `_make_tower_card` loops are no longer used to create every card under `ContentVBox`.
- Audit confirms enemy/effect galleries do not create per-card autoplay timers or live effect loops in the gallery grid.
- Godot headless parse must pass.

## Rollout Notes

This is a debug-tool performance refactor. It intentionally preserves gameplay systems and balance. If runtime profiling still exceeds the budget after virtualization, the next targeted step is expanding cached `Texture2D` snapshots for tower preview bodies behind the same card interface, without changing catalog behavior.
