# Demo Gate / Level Access System

Developer reference for the demo mode gate, level locking, and full-version unlock.

---

## Overview

The demo gate restricts which levels and waves a player can access in a demo build. All limits are config-driven — no gameplay balance, tower stats, or wave data is touched.

| Default (demo) | Full version |
|---|---|
| Level 1 only | All 20 levels |
| Waves 1 – 20 only | All waves |
| No leaderboard submit | Leaderboard submit allowed |

---

## Key Files

| File | Purpose |
|---|---|
| `data/level_access_config.json` | Runtime config — edit to change demo limits |
| `scripts/services/level_access_service.gd` | Service node — all access logic lives here |
| `scripts/ui/demo_gate_modal.gd` | Modal UI for locked-level and demo-complete screens |
| `scripts/main/main.gd` | Wires the service; enforces at load, wave cap, save/resume |
| `scripts/ui/level_select.gd` | Enforces in the level selection UI |

---

## Config File

**`data/level_access_config.json`**

```json
{
  "demo_enabled": true,
  "max_demo_level": 1,
  "max_demo_wave": 20,
  "allow_leaderboard_submit": false,
  "allowed_modes_demo": ["normal"]
}
```

| Key | Type | Effect |
|---|---|---|
| `demo_enabled` | bool | `false` disables all gating (acts like full version) |
| `max_demo_level` | int | Highest level number playable in demo |
| `max_demo_wave` | int | Highest wave number playable in demo |
| `allow_leaderboard_submit` | bool | Whether demo runs submit to the leaderboard |
| `allowed_modes_demo` | array | Reserved for future game-mode gating |

**To open all levels and waves without touching code:** set `"demo_enabled": false`.

---

## Unlocking the Full Version

### At runtime (code)

```gdscript
# Get the service node from anywhere in the scene tree:
var access = get_tree().current_scene.get_node("LevelAccessService")

# Unlock everything:
access.set_full_version_unlocked(true)

# Check status:
access.is_full_version_unlocked()  # → true
```

### In a debug / dev session

A convenience method is available **only in debug builds** (`OS.is_debug_build() == true`):

```gdscript
var access = get_tree().current_scene.get_node("LevelAccessService")
access.unlock_full_version_for_debug()   # no-op in release builds
access.reset_to_demo_for_debug()         # revert back to demo
```

You can also call this from the Godot editor's **Remote** debugger or from the existing `DebugPanel` if you wire a button to it.

### Via config (simplest for local testing)

Set `"demo_enabled": false` in `data/level_access_config.json` and relaunch. No code changes needed.

---

## Service API

`LevelAccessService` is a `Node` child of the main scene named `"LevelAccessService"`.

```gdscript
# Can the player start this level?
can_play_level(level_id: int) -> bool

# Can the player play this wave on this level?
can_play_wave(level_id: int, wave_number: int) -> bool

# Has the demo wave cap just been reached?
is_demo_wave_cap_reached(wave_number: int) -> bool

# May this run submit to the leaderboard?
can_submit_leaderboard() -> bool

# Full-version flag getter/setter
is_full_version_unlocked() -> bool
set_full_version_unlocked(value: bool) -> void

# Human-readable reason a level/wave is blocked (empty string = not blocked)
get_locked_reason(level_id: int, wave_number: int = -1) -> String
```

`level_id` is the integer extracted from the level filename, e.g. `"level_05"` → `5`.

---

## Enforcement Points

All blocks are tagged `[DemoGate]` in the source so they are easy to grep for.

```
grep -r "\[DemoGate\]" scripts/
```

| Location | What is enforced |
|---|---|
| `main.gd :: start_game()` | Blocks starting a locked level; shows locked modal |
| `main.gd :: _restore_run_from_save()` | Blocks continuing a save that requires the full version; does **not** delete the save |
| `main.gd :: _on_wave_completed()` | After clearing wave `max_demo_wave`, stops the run and shows the Demo Complete modal |
| `main.gd :: _on_game_over()` | Skips leaderboard submit when `can_submit_leaderboard()` is false |
| `main.gd :: _on_victory()` | Same leaderboard gate |
| `level_select.gd :: _update_dynamic_level_card()` | Premium-locked card visual; clicking opens the locked modal |
| `level_select.gd :: _update_play_button_state()` | Play button disabled with "FULL VERSION REQUIRED" label |

---

## Adding a Purchase Backend

When a real purchase or entitlement system is ready:

1. After the purchase is confirmed, call:
   ```gdscript
   level_access_service.set_full_version_unlocked(true)
   ```
2. Persist the flag through `SaveManager` or your own settings file (the service does not auto-persist it — persistence is the responsibility of the purchase layer).
3. Connect `DemoGateModal.unlock_requested` signal to your purchase flow. It is emitted when the player presses "UNLOCK FULL VERSION" in either modal.

No other files need to change.

---

## Modal Behaviour

Two screens share `scripts/ui/demo_gate_modal.gd`:

**Locked level** — triggered when a player taps a premium-locked card or when `start_game()` is blocked:
- Title: FULL VERSION
- Body: level name + reason text
- CTA: UNLOCK FULL VERSION → emits `unlock_requested`
- Secondary: BACK TO MENU → emits `back_to_menu`

**Demo complete** — triggered 2 s after clearing `max_demo_wave`:
- Title: DEMO COMPLETE
- Stats: Level, Waves Cleared, Gold Remaining, Lives Remaining
- CTA: UNLOCK FULL VERSION → emits `unlock_requested`
- Secondary: BACK TO MENU → emits `back_to_menu`

The modal is a `CanvasLayer` at layer 128 (above HUD at 99, below DebugPanel at 500).

---

## Acceptance Checklist

- [ ] Fresh demo build: Level 1 is playable
- [ ] Level 2+ card is visible but shows amber locked state with "Full Version / Unlock to Play"
- [ ] Clicking a locked card opens the locked modal (does not start the level)
- [ ] Direct call to `start_game("res://data/levels/level_02.json")` is blocked
- [ ] Waves 1–20 play normally; after clearing Wave 20 the Demo Complete modal appears
- [ ] Wave 21 never starts after the demo cap
- [ ] A save from beyond the demo limit is blocked at Continue but not deleted
- [ ] Setting `full_version_unlocked = true` unlocks all levels and waves immediately
- [ ] No tower, enemy, or wave stats are changed
- [ ] No FPS regression (modal is procedural UI, no heavy VFX)
