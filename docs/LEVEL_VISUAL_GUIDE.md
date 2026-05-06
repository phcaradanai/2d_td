# Level Visual Guide

This guide outlines the visual standards for level presentation to ensure gameplay readability and environmental depth.

## Readability Standards

### Path Identification
-   Enemies always travel along the **thick, themed path**.
-   Paths have a **glowing spine** (orange/yellow/blue depending on theme) to ensure they are the most readable element on the map.
-   **Spawn markers (A, B, C)** and **CORE** labels must be clearly visible.

### Tower Placement (Build Mode)
-   **Buildable Foundations**: Highlighted with a subtle tint and corner brackets.
-   **Blocked Areas**: Highlighted with a subtle red/dark tint when build mode is active.
-   **Hover Feedback**:
    -   Valid cell: Bright green outline + ghost tower.
    -   Invalid cell: Red outline + X-shape + failure reason label.

## Environment Theming

### Area 1: Grasslands
-   **Tone**: Beginner-friendly, bright, welcoming.
-   **Props**: Rocks, bushes, pink/yellow flowers, grass clumps.

### Area 2: Forest
-   **Tone**: Dense, mysterious, shadowed.
-   **Props**: Red mushrooms, dense bushes, exposed tree roots, mossy rocks.

### Area 3: Forest River
-   **Tone**: Lush, wet, serene.
-   **Props**: Wet rocks, reeds, lily pads, water ripples.

### Area 4: Mountain
-   **Tone**: Dangerous, dramatic, epic.
-   **Props**: Sharp stones, pine shrubs, broken ruins, lit torches.

## Placement Rules
-   **Decorations** must never spawn on path cells or buildable foundations.
-   **Blockers** (decorative blocked cells) should be used to create natural barriers and guide tower placement strategy.
-   **Void/Cliff** areas should use the `color_blocked` theme color to signal they are completely unusable.
