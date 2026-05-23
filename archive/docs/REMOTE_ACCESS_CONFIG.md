# Remote Access Config / OTA Demo Gate

Developer reference for the backend-driven access config system.  
Change demo limits, unlock the full version, or put the game in maintenance — all without rebuilding the client.

---

## Architecture Overview

```
Backend DB
    └── game_remote_config table
            ↓  GET /api/v1/game/access
RemoteAccessConfigService   (scripts/services/remote_access_config_service.gd)
    ├── caches → user://remote_access_config.json
    ├── falls back to → res://data/default_access_config.json
    └── emits config_updated / fetch_failed
            ↓  bind_remote_config()
LevelAccessService          (scripts/services/level_access_service.gd)
    └── single point-of-truth for all access checks
            ↓
UI / Gameplay code          (level_select.gd, main.gd, wave flow, leaderboard)
```

**Rule:** UI and gameplay only call `LevelAccessService`.  
They never parse remote config directly.

---

## Config Priority (highest → lowest)

| # | Source | When active |
|---|--------|-------------|
| 1 | **Remote** | Successful fetch from backend |
| 2 | **Cache** | `user://remote_access_config.json` — last good fetch |
| 3 | **Default** | `res://data/default_access_config.json` — bundled with build |

The game is immediately playable from cache/default on startup.  
The remote fetch runs in the background and updates rules when it lands.

---

## Bundled Default Config

**`res://data/default_access_config.json`** — edit this to change what ships in the build:

```json
{
  "config_version": 1,
  "mode": "demo",
  "demo_enabled": true,
  "max_demo_level": 1,
  "max_demo_wave": 20,
  "enabled_levels": [1],
  "enabled_modes": ["normal"],
  "allow_save_resume": true,
  "allow_leaderboard_submit": false,
  "allow_sandbox": false,
  "maintenance_enabled": false,
  "force_update": false,
  "min_supported_build": 1,
  "announcement": ""
}
```

---

## Backend Endpoint

```
GET /api/v1/game/access?player_id=<id>&build=<build_number>&platform=<platform>
```

| Query param | Value |
|-------------|-------|
| `player_id` | Anonymized device ID (`OS.get_unique_id()`) or player name |
| `build` | `BUILD_NUMBER` constant in `remote_access_config_service.gd` (default `1`) |
| `platform` | `OS.get_name().to_lower()` — e.g. `windows`, `web`, `android` |

### Expected Response

```json
{
  "server_time": "2026-05-18T04:00:00Z",
  "config_version": 12,
  "access": {
    "mode": "demo",
    "demo_enabled": true,
    "max_demo_level": 1,
    "max_demo_wave": 20,
    "enabled_levels": [1],
    "enabled_modes": ["normal"],
    "allow_save_resume": true,
    "allow_leaderboard_submit": false,
    "allow_sandbox": false,
    "maintenance_enabled": false,
    "force_update": false,
    "min_supported_build": 1,
    "announcement": ""
  },
  "entitlement": {
    "full_version_unlocked": false,
    "owned_products": []
  }
}
```

The game accepts the full object or just the flat `access` dict if there is no wrapper.

---

## Config Field Reference

| Field | Type | Effect |
|-------|------|--------|
| `config_version` | int | Version stamp shown in the status chip |
| `mode` | `"demo"` \| `"full"` | `"full"` bypasses all demo restrictions |
| `demo_enabled` | bool | `false` = full access regardless of other fields |
| `max_demo_level` | int | Highest **level number** playable in demo |
| `max_demo_wave` | int | Highest **wave number** allowed in demo |
| `enabled_levels` | int[] | Exact list of playable level IDs in demo |
| `enabled_modes` | string[] | Reserved for future game-mode gating |
| `allow_save_resume` | bool | Whether Continue is allowed in demo |
| `allow_leaderboard_submit` | bool | Whether demo runs post to leaderboard |
| `allow_sandbox` | bool | Reserved |
| `maintenance_enabled` | bool | **Blocks all play** and shows maintenance modal |
| `force_update` | bool | **Blocks all play** and shows update-required modal |
| `min_supported_build` | int | Force-update if `BUILD_NUMBER < this` |
| `announcement` | string | Text shown inside the maintenance modal |

### Entitlement fields

| Field | Effect |
|-------|--------|
| `full_version_unlocked` | `true` → ignores all demo limits (unless maintenance/force_update) |
| `owned_products` | Reserved array for future DLC / consumable items |

---

## Merge Rules

1. `maintenance_enabled = true` or `force_update = true` → **all play blocked**, no exceptions.
2. `entitlement.full_version_unlocked = true` → all levels and waves open (still blocked by maintenance/force_update).
3. `mode = "full"` or `demo_enabled = false` → same as full unlock.
4. Otherwise enforce `enabled_levels` and `max_demo_wave`.
5. Leaderboard submit: off by default in demo; `allow_leaderboard_submit = true` or full entitlement enables it.
6. Save/resume: rejected if the saved level/wave is beyond demo limits — **save file is never deleted**.

---

## Backend DB Schema (suggestion)

```sql
-- Remote config store
CREATE TABLE game_remote_config (
    config_key   TEXT PRIMARY KEY,   -- e.g. "global" or "platform_web"
    config_json  JSONB NOT NULL,
    version      INT  NOT NULL DEFAULT 1,
    is_active    BOOL NOT NULL DEFAULT TRUE,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Optional per-player entitlements
CREATE TABLE player_entitlements (
    player_id    TEXT        NOT NULL,
    product_code TEXT        NOT NULL,   -- e.g. "full_version"
    is_active    BOOL        NOT NULL DEFAULT TRUE,
    granted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ,            -- NULL = no expiry
    PRIMARY KEY (player_id, product_code)
);
```

The API endpoint joins these two tables — returns the active config row merged with the player's entitlements.

---

## Changing Config Without Rebuilding

To change the demo wave cap from 20 to 10:

```sql
UPDATE game_remote_config
SET config_json = config_json || '{"max_demo_wave": 10}',
    version     = version + 1,
    updated_at  = NOW()
WHERE config_key = 'global';
```

Next time the game starts (or returns to menu), it fetches the new config and enforces Wave 10 as the cap — no rebuild needed.

To unlock the full version globally:

```sql
UPDATE game_remote_config
SET config_json = config_json || '{"mode": "full", "demo_enabled": false}',
    version     = version + 1,
    updated_at  = NOW()
WHERE config_key = 'global';
```

To enable maintenance mode:

```sql
UPDATE game_remote_config
SET config_json = config_json || '{"maintenance_enabled": true, "announcement": "Updating servers. Back in 30 min."}',
    version     = version + 1,
    updated_at  = NOW()
WHERE config_key = 'global';
```

---

## Godot-Side Developer Controls

### Point the game at a different API (dev / staging)

Create `user://remote_access_config_dev.json`:
```json
{ "api_base_url": "http://localhost:8080" }
```

The service reads this file on startup and overrides the bundled URL.

### Force full version in a debug session

```gdscript
var rac = get_tree().current_scene.get_node("RemoteAccessConfigService")
rac.force_full_version_for_debug()   # debug builds only

# Or through LevelAccessService:
var las = get_tree().current_scene.get_node("LevelAccessService")
las.unlock_full_version_for_debug()
las.reset_to_demo_for_debug()
```

Both helpers are no-ops in release builds.

### Trigger a manual refresh (e.g. from a settings button)

```gdscript
var rac = get_tree().current_scene.get_node("RemoteAccessConfigService")
rac.fetch_remote_config()   # queues an HTTP GET; emits config_updated when done
```

### Completely disable remote fetching (offline-only build)

Set `BUNDLED_API_URL = ""` in `remote_access_config_service.gd`.  
The service will skip the fetch and serve default/cache only.

---

## Status Indicator (Main Menu)

A small label in the bottom-right of the main menu shows:

| Text | Colour | Meaning |
|------|--------|---------|
| `Access Config: Online v12` | cyan | Successfully fetched from backend |
| `Access Config: Cached v12` | amber | Using last cached response (offline) |
| `Access Config: Default` | muted grey | No cache, using bundled default |

This is updated automatically after each fetch attempt.

---

## Enforcement Points

All blocks are tagged `[DemoGate]` in the source.

```
grep -r "\[DemoGate\]" scripts/
```

| Location | What is enforced |
|---|---|
| `main.gd :: _ready` | Initialises `RemoteAccessConfigService`, binds to `LevelAccessService`, triggers first fetch |
| `main.gd :: _refresh_ui_for_phase (MENU)` | Calls `_check_blocking_access_states()` — shows maintenance/force-update modal |
| `main.gd :: _on_access_config_updated` | Refreshes status chip and level-select cards on every config change |
| `main.gd :: start_game()` | Blocks starting a locked level |
| `main.gd :: _restore_run_from_save()` | Blocks continuing a save that requires the full version |
| `main.gd :: _on_wave_completed()` | Shows Demo Complete modal at `max_demo_wave` |
| `main.gd :: _on_game_over() / _on_victory()` | Gates leaderboard submit |
| `level_select.gd :: _update_dynamic_level_card` | Premium lock visual on cards |
| `level_select.gd :: _update_play_button_state` | Play button disabled for locked levels |

---

## Acceptance Tests

| Test | Pass condition |
|------|----------------|
| Backend sets `max_demo_wave: 10` | After restart/refresh, Wave 11 is blocked — no rebuild |
| Backend sets `mode: "full"` | All levels and waves open after refresh |
| Offline, cache exists | Game plays normally using cached rules |
| Offline, no cache | Game plays using bundled default config |
| `full_version_unlocked: true` in entitlement | All levels and waves open |
| `maintenance_enabled: true` | Maintenance modal shown, all play blocked |
| `force_update: true` | Update-required modal shown, all play blocked |
| Demo save (level 2, wave 25) on demo config | Continue blocked, save not deleted |
| Demo run completes wave 20 | Demo Complete modal shown, wave 21 never starts |
| Demo leaderboard submit | Rejected client-side when `allow_leaderboard_submit: false` |
| FPS test | No per-frame logic in any new service; no regression |
