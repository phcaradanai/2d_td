## For level design Hard balance rules:
1. Do not reduce fun to increase clearability.
2. Do not solve balance by making waves empty.
3. Do not use single-type waves after tutorial levels.
4. Cloaked enemies must be paired with visible enemies.
5. Healers must be paired with tanks/frontliners.
6. Armored enemies should be paired with pressure or disruption enemies.
7. Later levels must have higher enemy density, not lower.
8. Perfect-clear must be verified by actual runtime replay.
9. If a level is impossible, adjust counter-play, rewards, enemy stats, or tower options before reducing enemy count.
10. If a dominant tower appears, fix composition/counter pressure instead of simply nerfing or thinning waves.

## Alias godot
use /Applications/Godot.app/Contents/MacOS/Godot

## README FIRST
Before making changes, read docs/MILESTONES.md and docs/AGENT_GUARDRAILS.md first. Follow the completed milestone guardrails and do not break already-stabilized systems.

## Hard Architecture Rule: Small Service-Based Changes

`main.gd` and other large Godot scripts are already too large and should not keep growing with new feature logic.

Whenever adding a new feature, fixing a bug, or improving UI/VFX/audio/gameplay systems, agents must prefer a small service/controller/config-file approach instead of adding more logic directly into `main.gd`.

### Core Rules

1. Do not add large new systems directly into `main.gd`.
2. Do not turn any existing file into another god-file.
3. Every new feature should be split into small focused files when practical.
4. Each new file must have one clear responsibility.
5. `main.gd` should only perform minimal wiring:
   - create/register service
   - bind dependencies
   - forward references
   - connect signals
   - call high-level APIs
6. Keep feature policy, state machines, UI behavior, config maps, pooling logic, and data rules outside `main.gd` whenever possible.
7. Prefer dependency injection, context binding, or existing project service patterns over direct cross-file coupling.
8. Avoid circular dependencies.
9. Avoid global singletons unless the project already uses that pattern or the feature clearly benefits from it.
10. If modifying a large file is unavoidable, keep the change minimal and explain why in the commit notes.

## Tower 

Tower visual must resolve by tower_id first.
visual_type is only fallback for towers not yet migrated.
Every new tower or redesigned tower must have its own by_id visual file.
No gameplay logic is allowed inside tower visual files.
Visual files may only draw shape, core, accent, idle hint, and static preview-safe VFX.

### Required Pattern

When adding a feature, first decide whether it belongs in one of these categories:

- `scripts/services/`
  For reusable logic, gameplay services, audio systems, save/load systems, analytics, pooling, settings state, balancing helpers.

- `scripts/controllers/`
  For scene-level coordination, game flow, wave flow, build flow, element pick flow, HUD coordination.

- `scripts/ui/`
  For popup behavior, panels, HUD widgets, buttons, cards, tooltip behavior, catalog screens.

- `scripts/config/`
  For constants, balance tables, audio policy, tower metadata, wave metadata, visual policy, theme tokens.

- `scripts/components/`
  For reusable node-level behavior attached to towers, enemies, projectiles, VFX, or UI nodes.

### Examples

Bad:

```gdscript
# main.gd
var combat_audio_cooldowns := {}
var combat_audio_priority := {}
var audio_player_pool := []

func play_tower_sound(...):
	# hundreds of lines of audio policy here
```
## Coding Rules

1.do not make god file. use service/controller pattern instead.

