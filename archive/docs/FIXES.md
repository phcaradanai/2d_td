# Fixes Log

## [2026-05-08] Battle Telemetry Pass
- **BattleTelemetry Overhaul**: Rebuilt `battle_telemetry.gd` to support detailed wave-by-wave tracking, hero active time, and tower upgrade logs.
- **GameManager Integration**: Fixed missing level names and added correct `end_level` parameters for score and stars.
- **WaveManager Integration**: Added detailed leak event logging including enemy HP, path progress, and position.
- **Tower/Projectile/Enemy Sync**: Synchronized damage reporting to include `attack_type` (Single, Splash, Chain, Aura) for better balance analysis.
- **ResultPanel Debug Display**: Fixed result screen debug balance report overlap and empty popup issues by moving telemetry UI to a dedicated debug-only popup with localized data snapshotting.
