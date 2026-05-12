# Stage 5D — Hero / Guardian Cleanup Decision

## Decision

The Element TD WC3-like mode should be a pure tower-defense flow. Hero / Guardian gameplay is no longer part of the core mode.

## Rationale

The current design direction is based on Element TD-style progression:

- start from starter towers
- choose elements during the run
- unlock single, dual, and triple element towers
- rely on tower placement, upgrades, selling, interest, and element combinations

A manually deployable Guardian hero creates a separate combat axis that competes with the tower-combination economy and makes wave intel recommendations harder to keep consistent. Stage 5C already removed Guardian recommendations from Wave Intel, so Stage 5D formalizes the decision to remove or disable the remaining runtime hero flow.

## Scope for runtime cleanup

The following runtime references should be removed or disabled in a conservative code pass:

- `current_hero`
- `hero_panel`
- `hero_cooldown`
- `hero_active_duration`
- `hero_is_deployed`
- `_setup_hero_if_enabled()`
- `_setup_hero_ui()`
- `_on_hero_deploy_requested()`
- `_spawn_hero_unit()`
- direct `HeroGuardian.tscn` instancing
- level `hero_config` runtime dependency for Element TD mode

## Non-goals

This stage should not rebalance towers, waves, enemies, interest, or element unlocks.

This stage should not delete historical assets until the runtime references are removed and the game boots cleanly.

## Validation checklist

After runtime cleanup:

```bash
grep -RIn "current_hero\|hero_panel\|hero_cooldown\|hero_active_duration\|hero_is_deployed\|_setup_hero_if_enabled\|_setup_hero_ui\|_on_hero_deploy_requested\|_spawn_hero_unit\|HeroGuardian\|Guardian" scripts scenes data
```

Expected result for Element TD mode:

- no runtime references in `scripts/main/main.gd`
- no Wave Intel recommendation mentioning Guardian
- optional asset files may remain temporarily if unused

## Status

Decision recorded. Runtime cleanup should be applied as a follow-up code patch once the full target file can be edited safely without truncated replacement.
