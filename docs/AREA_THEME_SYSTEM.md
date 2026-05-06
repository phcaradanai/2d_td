# Area Theme System

The Area Theme System provides data-driven environment visuals for the Tower Defense campaign. Each area (group of 5 levels) is assigned a unique theme that defines the ground colors, path styles, and decorative elements.

## Theme Definitions

Themes are defined in `scripts/map/theme_manager.gd` using the `AreaTheme` resource.

| Area | Theme ID | Description | Key Visuals |
| :--- | :--- | :--- | :--- |
| 1 | `area_grasslands` | Grasslands / Meadow Plains | Bright green grass, yellow flowers, tan dirt paths. |
| 2 | `area_forest` | Forest | Darker green floor, mud trails, mushrooms, and roots. |
| 3 | `area_forest_river` | Forest River / Wetlands | Teal water, wet rocks, wood bridge/path mix. |
| 4 | `area_mountain` | Mountain / Highlands | Gray stone, carved road, pine trees, and torches. |

## Layered Rendering

The environment is rendered in distinct layers in `scripts/map/map_visual_layer.gd`:

1.  **Base Ground**: Solid background color defined by the theme.
2.  **Tactical Grid**: Subtle overlay for positioning awareness.
3.  **Path Base**: Organic, thick polyline representing the enemy route.
4.  **Special Tiles**: Foundations (buildable) and Blockers (non-buildable) with theme-specific patterns.
5.  **Decorations**: Procedural props (rocks, bushes, etc.) spawned based on the theme's pool.
6.  **Path Overlays**: Glowing spine and boundary lines for readability.
7.  **Markers**: Spawn portals and Core/Base markers.

## Visual Fidelity

-   **Path Blending**: Paths use thick drawing to feel like organic roads rather than sharp boxes.
-   **Procedural Props**: Decorations are generated deterministically per level, ensuring visual variety while maintaining consistency across runs.
-   **Build Mode Integration**: When in build mode, the environment provides clear tactical feedback (foundations, blocked tints, range guides).
