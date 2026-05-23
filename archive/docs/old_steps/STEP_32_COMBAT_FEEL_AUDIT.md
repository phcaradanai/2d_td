# STEP_32_COMBAT_FEEL_AUDIT.md

## 1. Existing Combat Feedback
- **Tower Fire**: Plays SFX, spawns projectile. No visual recoil or muzzle flash.
- **Projectile Visuals**: Procedural shapes (`_draw_bolt`, `_draw_shell`). Static trails only.
- **Projectile Impact**: Spawns `ImpactEffect` (cross burst) or `SplashEffect` (circle).
- **Enemy Hit**: `flash_body()` (white overlay circle for 0.08s).
- **Floating Damage Numbers**: `DamageNumber.gd` spawns at `hit_global + Vector2(0, -20)`.
- **Death**: `DeathPopEffect.gd` (expanding circle).
- **Base Hit**: Red `ImpactEffect` + Camera Shake.

## 2. Existing Combat Scripts
- `tower.gd`: Handles firing logic, aiming, and rotation.
- `projectile.gd`: Handles movement and impact logic.
- `enemy.gd`: Handles health, death, and flash visuals.
- `main.gd`: Handles base damage response and camera shake.

## 3. Existing Effect Root
- **Standard**: `WorldRoot/MapRoot/EffectsContainer`.
- **Cleanup**: Correctly cleared in `Main._clear_gameplay_state()` via container cleanup.
- **Coordinate Space**: Map-local space (affected by map scale, which is correct for gameplay alignment).

## 4. Existing Coordinate Usage
- **Muzzle Flash**: N/A (Planned for `get_fire_origin()`).
- **Hit Spark**: `projectile.gd` uses `target.get_aim_point()`.
- **Damage Number**: `enemy.gd` uses `global_position`.
- **Base Hit**: `main.gd` uses `base_damage_point.global_position`.

## 5. Current Gameplay Risks
- **Overlapping Effects**: High fire rate towers (Rapid) can spam `ImpactEffect` nodes, potentially impacting performance if not efficient.
- **Visual Noise**: Large splash radii might obscure enemies.
- **Tween Stacking**: Tower recoil tweens must be handled carefully to avoid stacking if fire rate is faster than tween duration.

## 6. Planned Step 32 Fixes & Improvements

### A. Tower Feedback
- **Muzzle Flash**: Spawn a quick procedural flash at `get_fire_origin()`.
- **Fire Recoil**: Add a small backward tween to the `turret_pivot` or `turret_sprite`.
- **Firing Light**: Add a subtle light burst (Glow node) when firing.

### B. Projectile Feedback
- **Smooth Trails**: Implement a simple `Line2D` trail for projectiles to emphasize speed and direction.
- **Impact Sparks**: Enhance `ImpactEffect` with multi-particle bursts or varying colors based on tower type.

### C. Enemy Feedback
- **Impact Direction**: Make hit flashes or sparks directional based on projectile angle.
- **Squash & Stretch**: Add subtle hit-reactions (scale bounce) to enemies.
- **Death Polish**: Enhance `DeathPopEffect` with more "debris" (procedural bits).

### D. Base Feedback
- **Base Critical Flash**: Enhance the visual warning when the base takes damage (screen-edge vignette or more aggressive shake).

---

## Step 31 Coordinate Contract Protection
- **RangeOrigin**: Must stay at `global_position` (base center).
- **FireOrigin**: Must stay at `muzzle.global_position`.
- **AimPoint**: Must stay at `enemy.global_position` (center).
- **Distance Check**: Must use world-space `distance_to()`.
