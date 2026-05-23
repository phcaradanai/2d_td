# Level Validation System

The `LevelValidator` system ensures that all campaign levels meet the necessary technical and design standards.

## Validation Checks

The validator (`scripts/debug/level_validator.gd`) performs the following checks for every level loaded in a debug build:

### 1. Path Integrity
-   **Existence**: Checks if paths are defined (legacy `path_cells` or new `paths` dictionary).
-   **Length**: Paths must have at least 2 points.
-   **Alignment**: Consecutive cells in a path must be adjacent (no jumps).
-   **Connectivity**: Each enemy path must be solvable.

### 2. Build Zone Standards
-   **Capacity**: Levels must have enough buildable space (minimum 6-8 spots depending on area).
-   **Path Overlaps**: Buildable foundations must not overlap with enemy routes.
-   **Bounds**: All foundations must be within the battlefield grid.

### 3. Wave Design
-   **Special Enemy Isolation**: Bulwarks and Hunters should not appear alone; they require escorts or groups for balanced difficulty.
-   **Rewards**: Wave rewards should scale appropriately with the level's progress.

### 4. Metadata Consistency
-   **Area IDs**: Levels must be correctly assigned to one of the 4 areas.
-   **Naming**: Unique IDs and descriptive names are required.

## How to Run Validation

Validation runs automatically when:
1.  **Level Load**: Any level is loaded in a debug build of the game.
2.  **Debug Panel**: Using the "Validate All Levels" tool in the developer console.

## Log Format

Results are printed to the console in the following format:
- `[LevelValidation] level=level_13 ok=true paths=1 build_spots=8 waves=5`
- `[LevelValidation] level=level_XX FAILED`
    - `[ERROR] Reason for failure`
- `[WaveDesign] warning: Special enemy isolation warning`
