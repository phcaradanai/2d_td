# Polish Review Report

Date: 2026-05-07
Project: Clone Tower Defend
Engine checked: Godot 4.6.2

## Executive Summary

The project is a playable Godot tower defense prototype with a strong amount of implemented content: 20 level files, 7 tower types, local saves, score/stars, leaderboard scaffolding, hero deployment, wave intel, audio settings, and web export files. The biggest polish opportunity is not missing ambition; it is consolidation. Several systems have grown faster than the public docs, release gates, and UI responsiveness.

For a refinement pass, prioritize:

1. Make the shipped experience match the current feature set.
2. Remove release-time warnings and debug/autoplay exposure.
3. Tighten UX around level select, tower loadout, wave intel, and end-of-run feedback.
4. Reduce noisy runtime output and isolate dev-only tooling.
5. Add a repeatable smoke test/validation path for all 20 levels.

## What Looks Strong

- Core data-driven structure is healthy: towers, enemies, levels, and waves are JSON-backed.
- Headless Godot launch succeeds.
- The tower catalog has clear roles: basic, rapid, cannon, slow, sniper, lightning, sawblade.
- Higher-level mechanics are already present: restricted build cells, multi-path maps, hero deployment, score/stars, local leaderboard service, and audio unlock handling for web.
- There are existing debug tools for balance solving and autoplay verification, which is valuable for a tower defense project.

## Highest Priority Polish Issues

### 1. README and Public Positioning Are Outdated

`README.md` says the prototype has 3 playable levels and 4 towers, but the current project has 20 level files and 7 tower definitions. It also still lists several completed-looking systems as TODOs, including hero, score, and leaderboard.

Why it matters:
- Players/testers will expect a smaller game than the build presents.
- Future polish work gets harder because it is unclear which systems are intended, experimental, or release-ready.

Recommended refinement:
- Update README feature counts and controls.
- Split TODO into `Implemented`, `In Progress`, and `Backlog`.
- Add a short "Current Build Scope" section: 20 levels, 4 areas, 7 towers, hero enabled from level 11.

### 2. Release Startup Has Warnings

Headless launch completes, but startup reports:

- Three invalid scene UIDs in `scenes/main/Main.tscn`.
- An Ogg Vorbis metadata warning for `assets/audio/music/menu_theme.ogg`.
- Resource leak messages on quit.

Why it matters:
- These warnings are not necessarily player-breaking, but they reduce confidence before a web/release build.
- Invalid UID warnings are easy to ignore until a scene path changes or export/import cache gets stale.

Recommended refinement:
- Re-save or re-import affected scenes in Godot so `Main.tscn` UID references are refreshed.
- Re-encode `menu_theme.ogg` or clear malformed comments.
- Run `Godot --headless --path . --quit --verbose` and inspect leaked objects if the leak persists after a clean scene save.

### 3. Debug Tooling Is Too Close to Release Gameplay

`scripts/main/main.gd` exports `enable_debug_tools` with a default of `true`, and `is_debug_auto_play_allowed()` returns true when that flag is true. Debug actions bind F9/F10, and large solver/autoplay functions live inside the main scene script.

Why it matters:
- Release exports can accidentally keep solver/autoplay pathways available.
- `main.gd` is 2,529 lines, with gameplay, UI orchestration, validation, balance solving, and autoplay execution in one place.
- This makes future polish risky because small UI/gameplay changes may accidentally affect dev tooling.

Recommended refinement:
- Default `enable_debug_tools` to false.
- Gate all solver/autoplay entry points behind `OS.is_debug_build()` unless explicitly running an internal build.
- Move auto-clear and solver bridge code from `main.gd` into a dedicated debug coordinator.
- Keep the debug panel scene out of normal release instantiation if not needed.

### 4. Level Select Layout Is Desktop-First

`scripts/ui/level_select.gd` dynamically creates a 5-column level grid and a fixed 380px right-side intel column. This will feel crowded on smaller browser sizes or embedded itch.io frames.

Why it matters:
- Web players often run the game in constrained windows.
- Level select is one of the first real product-quality impressions.

Recommended refinement:
- Add responsive breakpoints: collapse mission intel below the level grid under ~1100px width.
- Reduce area grid columns from 5 to 3 or 2 on narrow widths.
- Replace emoji-only lock/perfect indicators with theme-consistent icons or text+icon styling, since emoji rendering varies by platform.
- Make selected mission state more explicit than just bright modulation.

### 5. Gameplay Feedback Is Powerful but Noisy

The game has many good feedback systems: damage numbers, impact effects, recoil, muzzle flashes, result animation, wave intel, and audio. Some pieces still look like debug-era implementation:

- Many `print()` calls are unconditional in runtime paths.
- Sniper and sawblade still use placeholder SFX choices.
- Result panel has a looping record-feedback tween that is not stored separately, which can stack if results are shown repeatedly.
- Tower buttons update labels with price, but no detailed shop affordance shows role, target category, or why a tower is disabled/unavailable.

Recommended refinement:
- Introduce a small logger helper or stricter debug print convention.
- Add unique SFX for sniper and sawblade.
- Store/kill the result feedback tween on repeat displays.
- Enrich tower shop hover/selection states with role, damage type, target category, and cost.

## Gameplay and Balance Review Notes

### Content Progression

The project currently has:

- Levels 1-10: mostly legacy/free-build structure.
- Levels 11-20: hero-enabled progression.
- Levels 12-20: restricted build-cell maps.
- Levels 11-20: bulwark/hunter enemies.

This is a coherent content arc, but it needs clearer player-facing teaching:

- Level 11 should explicitly teach hero deployment.
- Level 12 should explicitly teach restricted foundations.
- The first bulwark and hunter appearances should have wave intel that names their mechanic in plain language.

### Tower Loadout

Loadout selection exists, but max loadout is 8 while there are only 7 available towers. This makes the constraint mostly decorative.

Recommended choices:
- If loadout strategy matters, set max to 4 or 5 and make recommendations meaningful.
- If all towers are meant to be available, remove the max-count framing for now and polish the shop instead.

### Land/Air Foundation

Tower/enemy targeting supports `land` and `air`, but `data/enemies.json` currently only defines land enemies. Sniper/lightning can target land and air, so the foundation is in place, but air content is not yet represented.

Recommended refinement:
- Either keep air out of UI copy until air enemies exist, or add a first air enemy and anti-air teaching level.
- Ensure wave intel and tower recommendations reflect actual target categories.

## Technical Maintainability Notes

### Main Script Size

`scripts/main/main.gd` is doing too much. It handles:

- State transitions.
- World layout.
- Level loading.
- Wave preview processing.
- Hero deployment.
- UI coordination.
- Debug panel operations.
- Balance solver/autoplay execution.

Recommended refinement:
- Extract `HeroController`, `WaveIntelService`, `DebugAutoClearController`, and possibly `GameFlowController`.
- Keep `main.gd` as orchestration glue, not the owner of every feature.

### Runtime Node Creation

Several UI and effect elements are created dynamically in scripts. This is fine for quick iteration, but it makes visual QA harder.

Recommended refinement:
- Move stable UI pieces into scenes when their structure is settled.
- Keep dynamic generation for repeated lists/cards only.
- Ensure dynamically created tweens are killed or naturally one-shot.

### Data Validation

JSON syntax is valid across levels, waves, towers, and enemies. The next polish step is semantic validation:

- Every `waves_path` exists.
- Every wave enemy type exists.
- Every recommended tower/role matches known towers.
- Buildable cells are in bounds and not too close to paths.
- Every level has a teaching/polish tag: tutorial, normal, challenge, boss/finale.

## Suggested Refinement Roadmap

### Pass 1: Release Hygiene

- Update README and publish checklist to current scope.
- Fix `Main.tscn` invalid UID warnings.
- Re-encode or clean `menu_theme.ogg`.
- Default debug tools off for release.
- Remove or gate unconditional runtime `print()` calls.

### Pass 2: First-Time Player Polish

- Improve level select responsiveness.
- Add first-time teaching copy for hero, restricted foundations, bulwark, and hunter.
- Make tower shop show roles and target categories.
- Clarify loadout rules or remove the max loadout framing.

### Pass 3: Combat Feel

- Add unique sniper and sawblade SFX.
- Tune hit/impact sounds so rapid towers do not spam harshly.
- Add subtle enemy spawn/base leak feedback.
- Review effect density for sawblade/lightning during busy waves.

### Pass 4: Validation and Balance

- Add a one-command validation script for all 20 levels.
- Run auto-clear/solver reports for levels 1-20, not only 1-10.
- Add a lightweight smoke test checklist for web export.
- Record intended difficulty per level and compare against clear rates/solver gold.

## Verification Performed

- `jq empty` passed for all level, wave, tower, and enemy JSON files.
- Godot version confirmed: `4.6.2.stable.official.71f334935`.
- Headless launch completed successfully with warnings noted above.
- Current git worktree was dirty before this report was added; existing changes were not modified.

## Recommended Next Work Item

Start with release hygiene. It is the smallest pass with the highest confidence gain: update docs, fix startup warnings, gate debug tools, and reduce console noise. After that, tackle level select responsiveness and teaching moments, because those will most directly improve player perception.
