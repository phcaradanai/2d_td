# Enemy VFX Verification Report

Generated with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s scratch/test_enemy_feature_verification.gd
```

Latest result: `PASS` (`8` passed, `0` failed).

## Runtime Consistency Checks

- Healer: passive radius aura matches `skill_params.radius`, heal cast beam triggers from `healer_heal_tick`, and heal received FX appears only on targets whose HP increased.
- Model polish: support units have calmer orbiters and clean circuit rings; shield units gained heavier armor plates and projector nodes; disruptor drones gained antennae/interference fins; splitters now show low-HP fracture warning; swarm units use tiny shard fragments; air units have hover shadows/rings.
- Disruptor: EMP aura radius matches `skill_params.radius`, affected towers receive reload-slow indicators only while the fire-rate modifier is active, and indicators are removed when the modifier clears.
- Shieldbearer and Bulwark: shield aura radius matches `skill_params.radius`, protected units show a shield icon while covered, and shield sparks trigger only when damage is actually reduced.
- Cloaked: stealth shimmer/status feedback follows tower targeting logic, including masked feedback when visible enemies are preferred and brighten feedback when cloaked enemies become targetable.
- Splitter: split burst is tied to the `split_triggered` event and child spawn count, with duplicate death calls prevented.
- Air enemies: air status icon and hover/shadow treatment are present, while ground-only targeting remains debug-verifiable.
- Speed roles: fast, runner, hunter, and fast flyer have lightweight burst/trail feedback tied to movement/formation release state.

## Performance Modes

- `LOW`: line/polygon aura and major trigger FX only.
- `MEDIUM`: default particles/glow-style procedural FX.
- `HIGH`: richer procedural beam/aura treatment where available.

Swarm units remain lightweight and avoid per-unit lights.

## Debug Toggles

The internal Debug Panel exposes:

- `Show Support Radius`
- `Show Active Skill Targets`
- `Show Heal Tick Events`
- `Show Disruptor Radius`
- `Show Shield Coverage`
- `Show Cloaked State`
- `Show Lightweight/Full FX mode`
