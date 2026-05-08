# Battle Telemetry System

The Battle Telemetry system is a decoupled, signal-driven data collection engine designed for gameplay balance analysis and QA. It records granular session metrics without impacting core gameplay performance.

## Data Structure

Telemetry data is stored in a JSON format under `user://telemetry/`. Each level session generates a unique report.

### Core Metrics
- **Level Metadata**: ID, Name, Start/End timestamps, Duration.
- **Result State**: Victory/Defeat, Stars earned, Lives remaining.
- **Economy**: Gold earned, Gold spent, Gold remaining.
- **Combat Stats**: 
  - Damage and kills aggregated by tower type.
  - Damage aggregated by attack type (Single, Splash, Chain, Aura).
  - Enemy spawn/kill/leak counts by type.
- **Hero Performance**: Active time, Damage, Kills, Deploy count.
- **Event Logs**: Detailed logs for every tower built, upgraded, or sold, and every enemy leak.

## Wave Stats
Each wave is tracked individually with:
- Start/End time.
- Enemy composition (Spawned/Killed/Leaked).
- Damage contribution by tower type during that specific wave.

## Integration Guide

### Logging Events
- `log_damage(source_type, amount, attack_type, enemy_type)`
- `log_enemy_leak(enemy_type, hp_rem, pos, progress, lives_after)`
- `log_tower_built(tower_type, cell, world_pos, cost)`
- `log_hero_deployed(pos, cost)`

### Debug Mode
In debug builds, the **Result Screen** displays a "Balance Report" overlay containing:
- MVP Tower (Highest damage contribution).
- Most dangerous enemy type (Highest leak count).
- Economic efficiency.
- Hero impact summary.

## Automated Balance Analysis

In debug builds, the system automatically analyzes session performance to provide design recommendations.

### Difficulty Ratings
- **Too Easy**: `gold_remaining_ratio > 40%`. Suggests the economy is too generous or enemy HP is too low.
- **Slightly Easy**: `gold_remaining_ratio > 25%`. Suggests minor tuning is needed.
- **Good**: Balanced resource utilization and pressure.
- **Too Hard**: Player defeat or extremely low remaining capital.

### Critical Metrics
- **Gold Remaining Ratio**: `gold_remaining / (gold_start + gold_earned_total)`.
- **Tower Dominance**: Flags if a single tower type contributes `> 55%` of total damage.
- **Wave Pressure**: Detected by "Danger Waves" (waves with the most leaks).
- **Hero Relevance**: Flags if the level was cleared without using the Hero.

### Interpretation
The report is visible in the console as `[BALANCE_ANALYSIS]` and in the Result Screen under the "View Balance Report" popup. Use these insights to adjust wave composition or tower pricing before final production.
