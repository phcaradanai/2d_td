# STEP 38A - Enemy Type Foundation Land Air

## Pre-Code Audit

### Current Enemy Script Structure

- Enemy scene: `scenes/enemies/Enemy.tscn`
- Enemy script: `scripts/enemies/enemy.gd`
- Base class: `PathFollow2D`
- Runtime group: enemies add themselves to group `"enemies"` in `_ready()`.
- Config entry point: `setup(config: Dictionary)`.
- Current exposed combat/movement helpers:
  - `is_alive()`
  - `get_path_progress()`
  - `get_current_hp()`
  - `get_hit_origin()`
  - `get_aim_point()`
  - `take_damage(amount, hit_global)`
  - `apply_slow(percent, duration)`

### Current Enemy Config Structure

Current file: `data/enemies.json`

Enemy types are keyed by id:

- `basic`
- `fast`
- `tank`

Each config currently includes:

- `id`
- `name`
- `max_hp`
- `speed`
- `reward_gold`
- `base_damage`
- `visual_type`

No category field exists before this step.

### Current Wave Config Structure

Current wave files: `data/waves/waves_XX.json`

Each wave is a dictionary with:

- `wave`
- `name`
- `completion_reward`
- `groups`

Each group currently uses:

- `enemy_type`
- `count`
- `spawn_delay`

No category field exists before this step. Wave spawning merges every group field except `count` and `spawn_delay` into the enemy config before calling `Enemy.setup()`.

### How Enemy Type Is Currently Represented

Enemy type is represented only as a string id:

- `enemy.enemy_type`
- `enemy.visual_type`
- wave group `enemy_type`
- enemy config id keys such as `basic`, `fast`, `tank`

There is no land/air category yet.

### How Towers Currently Find Valid Targets

Tower script: `scripts/towers/tower.gd`

Current target flow:

- `_process()` calls `update_target()`.
- `update_target()` assigns `current_target = find_target()`.
- `find_target()` gets `get_enemies_in_range()`.
- `get_enemies_in_range()` loops nodes in group `"enemies"` and calls `is_valid_target(enemy)`.
- `is_valid_target()` currently checks:
  - node exists
  - node is alive
  - distance from `get_range_origin()` to enemy position is within `attack_range`

Target mode selection then chooses first, last, nearest, strongest, or weakest from that already-filtered list.

Target filtering should happen in `is_valid_target()` so acquisition, rotation, targeting lines, and shooting all share the same validity rule.

### How Cannon Splash Finds Enemies

Projectile script: `scripts/projectiles/projectile.gd`

For `attack_type == "splash"`:

- projectile reaches its target
- `hit_target()` calls `apply_area_effect(hit_global)`
- `apply_area_effect()` loops all nodes in group `"enemies"`
- enemies inside `splash_radius` take falloff damage

Before this step, splash has no category filtering.

### How Slow Applies Slow

For `attack_type == "slow"`:

- projectile reaches its target
- `apply_area_effect()` loops all nodes in group `"enemies"`
- enemies inside `splash_radius` take low damage
- if the enemy has `apply_slow`, the slow debuff is applied

Before this step, slow has no category filtering.

### How Mission Intel Derives Enemy Traits

Mission Intel in `scripts/ui/level_select.gd` calls `main.get_wave_preview_data(level_id)`.

`scripts/main/main.gd` then:

- loads the real wave config
- calls `summarize_wave_for_preview(wave)`
- normalizes enemy type names with `normalize_enemy_type()`
- derives traits with `derive_wave_traits(enemy_counts, total_count)`

Before this step, traits are based only on normalized enemy type names and total count.

### How Wave Intel Derives Enemy Traits

In-game Wave Intel uses the same preview helpers:

- `get_wave_preview_data(level_id)`
- `get_wave_preview_for_index(level_id, wave_index)`
- `summarize_wave_for_preview(wave)`
- `derive_wave_traits(...)`

So Mission Intel and Wave Intel can be updated together by extending the preview summarizer.

### Planned Changes

Enemy metadata:

- Add stable string constants:
  - `land`
  - `air`
- Add `enemy_category` to enemy instances.
- Add `get_enemy_category()`, `is_air_enemy()`, and `is_land_enemy()`.
- Default missing or unknown categories to `land`.

Wave/enemy config support:

- Add `category` to existing enemy configs as `land`.
- Preserve support for missing category by defaulting to `land`.
- Wave group `category` overrides enemy config category when present.

Tower targeting:

- Add `target_categories`, defaulting to `["land"]`.
- Add `can_target_enemy(enemy)`.
- Call category filtering from `is_valid_target()` so targeting, rotation, lines, and shooting stay synchronized.

Projectile area effects:

- Pass the tower's `target_categories` into spawned projectiles.
- Apply the same category mask in projectile area loops.
- Cannon splash and Slow area effects will affect land enemies only for existing towers.

Intel:

- Extend preview summarization to resolve category from:
  1. wave group `category`
  2. enemy config `category`
  3. default `land`
- Add `Air` to traits when any summarized group is air.
- Avoid showing `Land` everywhere; land remains the assumed default.
- Prefix air summaries as `Air Fast xN`/`Air Normal xN` when category is air.

## Final Update

### Files Changed

- `scripts/enemies/enemy.gd`
- `scripts/managers/wave_manager.gd`
- `scripts/towers/tower.gd`
- `scripts/projectiles/projectile.gd`
- `scripts/main/main.gd`
- `data/enemies.json`
- `data/towers.json`
- `docs/STEP_38A_ENEMY_TYPE_FOUNDATION_LAND_AIR.md`

### Enemy Category Model

Enemies now support two stable categories:

- `land`
- `air`

`scripts/enemies/enemy.gd` now exposes:

- `enemy_category`
- `get_enemy_category()`
- `is_air_enemy()`
- `is_land_enemy()`

Missing or invalid category values safely normalize to `land`.

Existing enemy configs in `data/enemies.json` now explicitly declare:

- Basic: `land`
- Fast: `land`
- Tank: `land`

This is metadata only. No enemy stats or movement behavior were changed.

### Tower Target Category Model

Towers now support:

- `target_categories`
- `can_target_enemy(enemy)`

Existing towers in `data/towers.json` all declare:

- `target_categories: ["land"]`

This preserves current gameplay and creates the foundation for an anti-air tower in Step 38B.

### Target Acquisition Filter

`scripts/towers/tower.gd` now applies category filtering inside `is_valid_target()`.

Because `is_valid_target()` is shared by target acquisition, rotation, firing checks, and targeting-line visibility, invalid categories are rejected consistently:

- towers do not select invalid targets
- towers do not rotate toward invalid targets
- targeting lines do not draw to invalid targets
- projectiles do not spawn for invalid targets

Range checking remains the same conceptually, using the tower range origin against the enemy aim/hit point.

### Cannon Splash Filter

`scripts/projectiles/projectile.gd` now receives the firing tower's target category mask.

For Cannon splash:

- area damage still uses the existing splash radius and falloff
- each enemy in radius must pass `can_affect_enemy(enemy)`
- current Cannon towers affect land enemies only
- future air splash can be added by giving a tower/projectile an air-capable mask

### Slow Area Filter

Slow projectiles use the same category mask.

For Slow area:

- damage still applies as before to valid targets in radius
- slow debuff still uses the existing percent/duration
- enemies outside the tower's target categories are ignored

Current Slow towers affect land enemies only.

### Wave Config Category Support

`scripts/managers/wave_manager.gd` now resolves category with this priority:

1. wave group `category`
2. enemy config `category`
3. default `land`

Existing wave files do not need category fields. They continue to spawn land enemies because existing enemy configs are land and missing category also defaults to land.

Temporary future wave syntax is supported:

```json
{
  "enemy_type": "fast",
  "category": "air",
  "count": 8,
  "spawn_delay": 0.3
}
```

### Mission And Wave Intel Category Support

`scripts/main/main.gd` preview helpers now resolve enemy category while summarizing waves.

Air support:

- air groups add the `Air` trait
- air groups can display as `Air Fast x8`, `Air Normal xN`, etc.
- land remains implicit and is not shown as a noisy trait on current levels

Mission Intel and in-game Wave Intel both use these helpers, so both can recognize future air waves.

### Manual And Headless Test Results

Test 1: Existing Level 1

- Existing enemies default to land through enemy config/default category.
- Existing land-only towers can still target land.
- No Level 1 wave data was changed.

Test 2: Existing Level 7

- Level 7 Fast waves remain land by enemy config/default category.
- Basic/Rapid/Cannon/Slow can target them.
- Wave Intel preview code still reads the real wave config and now also supports category metadata.

Test 3: Target filter default

Temporary headless probe result:

- `tower_targets_land=true`
- `tower_targets_air=false`

This confirms existing land enemies remain targetable and temporary air enemies are ignored by land-only towers.

Test 4: Temporary air test

Temporary headless probe used a synthetic air Fast wave summary.

Result:

- `air_preview_summary=Air Fast x8`
- `air_preview_traits=Air,Fast`

No production levels were modified to include air enemies.

Test 5: Cannon splash filter

Temporary headless probe result:

- `splash_land_damage=15.0`
- `splash_air_damage=0.0`

This confirms land-only Cannon splash affects land and skips air.

Test 6: Slow filter

Temporary headless probe result:

- `slow_land_applications=1`
- `slow_air_applications=0`

This confirms land-only Slow affects land and skips air.

Test 7: Regression

Commands run:

- `Godot --headless --check-only --script res://scripts/enemies/enemy.gd`
- `Godot --headless --check-only --script res://scripts/managers/wave_manager.gd`
- `Godot --headless --check-only --script res://scripts/towers/tower.gd`
- `Godot --headless --check-only --script res://scripts/projectiles/projectile.gd`
- `Godot --headless --check-only --script res://scripts/main/main.gd`
- `jq empty data/enemies.json data/towers.json`
- `Godot --headless --path . --quit-after 3`

Results:

- Changed scripts parse successfully.
- Updated JSON files validate.
- Headless project startup succeeds.
- Existing unrelated startup warnings remain:
  - macOS CA certificate warning
  - invalid scene ext_resource UID warnings that fall back to text paths
  - existing Ogg Vorbis comment warning
  - resource cleanup warnings on forced quit

### Future Step 38B Plan

Recommended next step:

- Add an Anti-Air tower or air-capable tower upgrade.
- Give that tower `target_categories: ["air"]` or `["land", "air"]`.
- Add one controlled air enemy config.
- Add one controlled air test wave or level.
- Keep current land towers land-only unless a deliberate design change is made.

### Definition Of Done Status

Completed:

- Enemies have land/air category support.
- Existing enemies default to land.
- Towers have target category support.
- Existing towers target land by default.
- Target acquisition filters by category.
- Cannon splash respects target categories.
- Slow area effect respects target categories.
- Wave spawning can assign enemy category.
- Missing category safely defaults to land.
- Temporary air enemy/category test does not crash.
- Mission/Wave Intel can recognize Air trait when present.
- No production level was changed to introduce untargetable enemies.
