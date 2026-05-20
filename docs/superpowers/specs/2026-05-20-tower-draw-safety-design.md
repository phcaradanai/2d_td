# Tower Draw Safety Design

## Goal
Eliminate CanvasItem draw RID overflow and element-limit spam in tower visuals and catalog/debug tower previews without changing gameplay balance, tower behavior, or tower identity.

The fix must keep gameplay towers readable, keep catalog/debug scenes stable with all towers visible, and avoid per-frame procedural draw churn that can saturate Godot 4.6.2's CanvasItem limits.

## Scope
This work applies to:

- `scripts/towers/visuals/common/tower_visual_draw_utils.gd`
- `scripts/towers/visuals/by_id/*_visual.gd`
- `scripts/towers/tower.gd`
- tower catalog / preview wiring

It does not change:

- damage math
- targeting outcome
- wave balance
- tower unlocks, costs, or upgrades
- gameplay simulation

## Design

### 1. Shared draw firewall
`tower_visual_draw_utils.gd` becomes the single place that guards CanvasItem draw calls.

It will provide safe wrappers for line, polyline, polygon, circle, and rect drawing. Each wrapper will:

- return early if the target is null or invalid
- reject NaN / INF coordinates
- reject absurd coordinates outside a fixed safe range
- clamp point counts to a bounded maximum
- skip invalid or degenerate shapes
- consume a per-visual draw budget before drawing

The shared budget will be conservative:

- `MAX_POLYLINE_POINTS_PER_SHAPE = 24`
- `MAX_CIRCLE_SEGMENTS = 16`
- `MAX_DETAIL_SEGMENTS = 12`
- `MAX_DRAW_CALLS_PER_TOWER_VISUAL = 80`
- `MAX_DRAW_CALLS_PER_CATALOG_CARD = 35`

If the budget is exhausted, optional decorative details are skipped rather than partially drawn.

### 2. Tower visual detail levels
Each by-id tower visual will expose a `DetailQuality` enum:

- `LOW`
- `MEDIUM`
- `HIGH`

Defaults:

- gameplay towers: `MEDIUM`
- catalog cards: `LOW`
- selected / hovered card only: `HIGH`

LOW mode must preserve silhouette and identity, but trim:

- dense arc strokes
- repeated polyline rings
- extra decorative dots / rivets
- optional glow layers

MEDIUM keeps the current gameplay-readable look.
HIGH is reserved for the selected preview card or any explicit detail request.

### 3. Rank badge caching
`tower.gd` currently draws the rank badge procedurally. That will be replaced with a cached draw path keyed by:

- tower tier
- accent color
- scale

The badge should redraw only when rank or visual state changes, not every frame. The cache may be implemented as:

- a small texture snapshot, or
- a retained cached `CanvasItem` path if that proves simpler and stable

### 4. Dirty-flag redraws
Tower redraws will be driven by dirty flags instead of per-frame `queue_redraw()`:

- `visual_dirty`
- `selection_dirty`
- `rank_dirty`
- `preview_zoom_dirty`

`queue_redraw()` will only happen when one of those state flags changes, or when a brief selected-preview animation explicitly needs it.

### 5. Catalog safety mode
Tower catalog and debug preview scenes will default to static LOW detail.

Only the selected or hovered card may:

- animate
- render higher detail
- show optional VFX previews

Off-screen catalog rows must stop processing and stop requesting redraws.

### 6. Emergency fallback
If catalog FPS falls below 45, or the draw guard detects repeated budget pressure, the catalog will hard-drop to LOW detail until the budget recovers.

Emergency LOW mode will:

- disable decorative strokes
- disable animated redraws
- keep only base silhouettes and essential element icons
- preserve click/selection behavior

## Data Flow

1. Tower scene or catalog preview asks the visual renderer to draw.
2. The visual utility layer validates geometry and enforces budget.
3. By-id visual scripts render through the safe wrappers.
4. `tower.gd` updates rank badge and tower body only when dirty.
5. Catalog preview controller applies LOW / MEDIUM / HIGH detail based on selection, hover, and safety mode.

## Error Handling

The draw wrappers will fail closed:

- invalid geometry is skipped
- impossible point counts are skipped
- oversized coordinates are skipped
- budget overflow skips optional details

No per-frame warnings or prints will be emitted from the draw hot path.

## Testing

Verification will include:

- headless Godot load of the project
- opening `tower_catalog.tscn` without draw spam
- opening the catalog for an extended idle period
- checking debug output for:
  - `Element limit reached`
  - `Parameter "mem" is null`
  - `!vertex_buffer_owner.owns(buf)`
- confirming gameplay towers still render clearly
- checking that total draw calls and process time drop materially in the catalog

## Acceptance

The change is complete when:

1. opening `tower_catalog.tscn` for two minutes produces no CanvasItem draw error spam
2. the listed draw errors do not appear in the debugger
3. gameplay visuals remain recognizable and tower identity stays intact
4. catalog/debug scenes remain stable with all towers visible
5. idle catalog performance stays at or above 60 FPS on Apple M1
