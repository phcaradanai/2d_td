# STEP 31: COORDINATE & EFFECT AUDIT

## 1. Existing Coordinate Problems Found

### A. Feedback Loops in Rotation
- **Tower.gd**: Rotation is currently calculated from `MuzzlePoint.global_position` to target. Since the muzzle moves with the turret, this can create a feedback loop or slight misalignment.
- **Correction**: Use the tower's pivot or base global position as the rotation source.

### B. Inconsistent Distance Calculations
- **Projectile.gd**: `apply_splash_damage` uses `to_local(enemy_global).length()`. This is unsafe if the projectile's transform is not identical to the map's transform (which it isn't, due to MapRoot scaling).
- **Enemy.gd**: Path progress is handled correctly by `PathFollow2D`, but hit/death effects are inconsistently placed in different containers.

### C. Container Inconsistency
- **Death Effects**: Spawned in `WorldRoot/EffectsContainer`.
- **Impact/Splash Effects**: Spawned in `WorldRoot/MapRoot/EffectsContainer`.
- **Result**: Visual offset between different types of effects when `MapRoot` is scaled.

### D. Hardcoded Logic
- **Muzzle Offset**: Hardcoded in `Tower.gd` based on `visual_type`. This should be more robust or exposed as a standard property.

---

## 2. Global Position usage in Audited Nodes

| Node | Current Usage | Rule |
| :--- | :--- | :--- |
| **Tower** | Used for targeting and rotation calculations. | MUST be the source for `get_fire_origin()` and `get_targeting_origin()`. |
| **Enemy** | Used for `reached_base` signal and `take_damage` hit position. | MUST always report hit/death positions in world space. |
| **Projectile** | Used for movement vector and hit detection. | MUST use global distance for splash checks. |
| **Effects** | Set at spawn time from source global positions. | MUST always be parented to `MapRoot/EffectsContainer` for map-aligned visuals. |

---

## 3. Drawing System Audit

- **_draw()**: Used in Towers (Range/Turret), Enemies, and Projectiles. Uses local coordinates.
- **Line2D**: Used for Tower targeting lines and Path visual. Uses local points.
- **To-Local Conversion**: Tower targeting line currently uses `to_local()` correctly but depends on `AimVisual` being at `(0,0)`.

---

## 4. Fix Plan

1.  **Standardize Tower API**:
    - Add `get_fire_origin()`, `get_targeting_origin()`, and `get_attack_range()` to `Tower.gd`.
2.  **Centralize Effect Spawning**:
    - Standardize all gameplay effects to `WorldRoot/MapRoot/EffectsContainer`.
3.  **Correct Distance Math**:
    - Replace `to_local().length()` with `(p1 - p2).length()` for all gameplay checks.
4.  **Polish Aiming & Rotation**:
    - Fix rotation pivot to be stable.
    - Ensure `Line2D` and `TargetMarker` always use `to_local(global_target)`.
5.  **Runtime Cleanup**:
    - Ensure level restarts clear all containers and reset `GameManager` stats correctly.
