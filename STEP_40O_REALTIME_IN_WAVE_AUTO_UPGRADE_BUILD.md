# STEP 40O: Real-Time In-Wave Auto Upgrade and Build System

## 1. Current Auto Clear Run State Machine
The current system uses `AutoPlayState` to manage transitions:
- `IDLE`: Waiting for a plan.
- `STARTING_LEVEL`: Initializing the level scene.
- `APPLYING_INITIAL_ACTIONS`: Placing starting towers.
- `BEFORE_WAVE_ACTIONS`: Upgrading/Building before starting a wave.
- `STARTING_WAVE`: Triggering the wave manager.
- `WAVE_RUNNING`: Monitoring active enemies.
- `AFTER_WAVE_ACTIONS`: Handling post-wave rewards/upgrades.
- `PREPARING_NEXT_WAVE`: Advancing the wave counter.
- `SUCCESS` / `FAILED`: Terminal states.

## 2. Current Money/Gold Gain Timing
Gold is credited immediately upon enemy death in `GameManager` (triggered by `Enemy`). Post-wave rewards are added when the `WaveManager` emits `wave_completed`.

## 3. Current Enemy Kill Reward Logic
Each enemy type has a `reward` value defined in `enemies.json`. When an enemy's health reaches 0, it calls `game_manager.add_gold(reward)`.

## 4. Current Tower Upgrade API
- `tower.get_upgrade_cost()`: Returns the cost for the next level.
- `tower.upgrade()`: Increments level and applies stat changes.
- `tower.can_upgrade()`: Checks if the tower has more levels.

## 5. Current Tower Build API
- `build_manager.validate_placement(cell)`: Checks legality and cost.
- `build_manager.place_tower(cell, config)`: Spawns the tower.

## 6. Current Wave-Running State
- `wave_manager.is_wave_running`: True while enemies are spawning or active.
- `wave_manager.active_enemy_count`: Number of enemies currently on screen.

## 7. Current Enemy Progress/Path Tracking
Enemies use `PathFollow2D`. Progress is tracked via `progress` (absolute distance) or `progress_ratio` (0.0 to 1.0).

## 8. Why Between-Wave-Only Upgrades are Insufficient
Waiting for a wave to end before spending newly acquired gold is inefficient and risky. Skilled players react to threats in real-time. If an enemy is about to leak and gold is available, immediate action is required to maintain a Perfect Clear (20/20 lives).

## 9. New Real-Time Decision Loop Design
The `WAVE_RUNNING` state now actively monitors the battlefield every **0.25 seconds**.
- **Leak Risk Detection**: Evaluates distance to base and enemy speed.
- **In-Wave Actions**: Spends gold on the most effective upgrade or build to counter the current threat.
- **Action Cooldown**: A 0.75s gap between actions prevents spamming and ensures logical progression.
- **Fail-Fast**: Any HP loss immediately terminates the run to save time during verification/solving.
