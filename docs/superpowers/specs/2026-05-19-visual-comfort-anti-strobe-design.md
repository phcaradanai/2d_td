# Visual Comfort Anti-Strobe Design

## Context

This patch reduces aggressive combat flashing in Godot 4.6.2 without changing tower damage, enemy stats, targeting, wave logic, shield logic, disruptor logic, rewards, or balance. The current hotspots are enemy hit feedback, disruptor target links, shield aura/impact feedback, status icons, and generic lightning-style line effects.

The approved visual direction is: soft element-colored hit tint, thin stable disruptor links, compact shield icon/rim, low-alpha shield ripple with cooldown, and debug-only radius visuals.

## Architecture

Add `scripts/services/visual_comfort_service.gd` with `class_name VisualComfortService`. It is a small visual policy service: constants, color mapping, flash throttling, and performance-aware checks. It does not own gameplay state and does not alter damage or targeting decisions.

Register it as an autoload named `VisualComfort` so existing scripts can query `/root/VisualComfort` without expanding `main.gd`. The singleton name intentionally differs from `class_name VisualComfortService` because Godot rejects an autoload that hides a global class with the same name.

Expose the required constants:

- `HIT_FLASH_ALPHA_MAX := 0.22`
- `HIT_FLASH_DURATION := 0.08`
- `HIT_FLASH_COOLDOWN := 0.18`
- `LINK_ALPHA_MAX := 0.28`
- `SHIELD_ALPHA_MAX := 0.24`
- `STATUS_ICON_ALPHA := 0.75`
- `MAX_FLASHES_PER_SECOND := 3`
- `SOFT_GLOW_ALPHA := 0.18`

Expose the required methods:

- `allow_flash(key: String) -> bool`
- `get_hit_flash_color(element_or_damage_type: String) -> Color`
- `get_link_color(effect_type: String) -> Color`
- `get_shield_color(shield_type: String) -> Color`

The service also provides small helpers for performance-aware cosmetic gates where useful, such as checking the existing `PerformanceBudgetService.current_fps`. Below 58 FPS it should suppress repeated low-priority flashes and shield ripples. Below 52 FPS it should suppress hit flashes and leave only status icons/basic tint.

## Creep Hit Feedback

`scripts/enemies/enemy.gd` keeps damage math unchanged. `take_damage()` will still apply shield reduction, vulnerability, armor reduction, telemetry, damage stats, status reactions, and death behavior as it does today.

Replace the current `is_flashing` white redraw state with a soft color/alpha state, for example:

- `hit_flash_color: Color`
- `hit_flash_alpha: float`
- `_hit_flash_tween: Tween`
- `_hit_pulse_tween: Tween`
- `_hit_shake_tween: Tween`

`flash_body()` will ask `VisualComfortService.allow_flash("hit_%s" % get_instance_id())`. If allowed, it sets an element/damage-type tint from `get_hit_flash_color(source_id or attack_type)` and fades alpha back to zero over `HIT_FLASH_DURATION`. If a hit tween is already running, it does not create another duplicate tween. At low FPS or while visual comfort mode is active and the key is cooling down, it skips the flash.

`_play_hit_pulse()` remains cosmetic only but becomes budget-aware. It should not stack scale/shake tweens. If visual comfort mode or performance firebreak disables cosmetic tweens, it should skip or use a minimal single queued redraw.

`scripts/enemies/enemy_visual_router.gd` will draw the hit overlay as an element-colored low-alpha circle/arc, not pure white. Shield and slow overlays will use capped alpha and slower breathing.

## Disruptor Links

`scripts/effects/enemy_beam_vfx.gd` becomes a stable link renderer. It should:

- Draw one thin main line with alpha capped by `LINK_ALPHA_MAX`.
- Optionally draw a faint outer glow capped by `SOFT_GLOW_ALPHA`.
- Avoid random brightness, jagged per-frame offsets, and blink.
- Redraw on a modest interval or when endpoints move enough, instead of every frame.
- Fade links in/out smoothly where practical.

`scripts/effects/enemy_vfx_controller.gd` will pass `VisualComfortService.get_link_color("disruptor")` instead of hot magenta. Tower reload-slow icons remain available but use subdued alpha.

`scripts/effects/lightning_arc.gd` will stop regenerating jagged segments every 0.04 seconds. If it remains in use for chain effects, it should generate once, draw with capped alpha, and fade out calmly.

## Shield Bearer Feedback

Shield readability should come from compact role/protected icons and a subtle rim, not combat-spamming rings.

`scripts/effects/enemy_aura_vfx.gd` remains debug/radius-oriented and hidden by default. When visible, pulse frequency is reduced to 0.5-0.8 Hz and alpha is capped by `SHIELD_ALPHA_MAX`. Exact radius display remains debug-only.

`scripts/effects/enemy_vfx_controller.gd` will throttle `play_shield_spark()` per enemy using `VisualComfortService.allow_flash("shield_%s" % owner_enemy.get_instance_id())` or a longer local cooldown around 0.25-0.4 seconds. If FPS is below 58, shield ripples are suppressed. If a shield icon is already visible, repeated shield ticks should not spawn additional impact nodes.

`scripts/effects/enemy_impact_vfx.gd` will reduce shield spark alpha, segment count, and motion. It becomes a small soft ripple, not a rotating burst.

## Status Icons

`scripts/effects/enemy_status_icon_vfx.gd` keeps compact role icons. Pulse strength is reduced, alpha is capped by `STATUS_ICON_ALPHA`, and redraw cadence stays at or below 4 Hz. In visual comfort mode, icons should read mostly static with gentle breathing, not blinking.

## Duplicate Feedback Priority

Visual comfort mode defaults ON. In that mode, the same hit event should not show every possible feedback layer at once. Priority is:

1. Status icon/tint.
2. One soft hit tint.
3. Selected/identity tower effect.
4. Impact burst only if budget allows.

Existing `PerformanceFirebreak` and `PerformanceBudgetService` gates remain authoritative for global VFX suppression. The new service coordinates colors, alpha caps, and per-key throttles; it does not replace those services.

## Testing

Run:

- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
- `python3 tools/refactor/audit_project_guardrails.py`
- Relevant refactor audits for touched architecture boundaries.

Manual smoke:

- Spawn or play a dense combat wave.
- Confirm creeps do not flash bright white when hit.
- Confirm disruptor links are thin, stable, low-alpha, and non-flickery.
- Confirm shield bearer protection is readable through icon/rim without repeated screen-filling rings.
- Confirm no gameplay/balance files are retuned.

## Approval

The user approved the recommended visual direction in the Superpowers visual companion on 2026-05-19.
